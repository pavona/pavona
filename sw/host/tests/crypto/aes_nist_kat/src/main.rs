// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

use anyhow::{Result, ensure};
use arrayvec::ArrayVec;
use clap::Parser;
use std::time::Duration;

use serde::Deserialize;
use serde_json::json;

use cryptotest_acvp::{AcvpIds, AcvpOpts, Fields, ResponseBuilder, hex, read_vectors};
use cryptotest_commands::aes_commands::{
    AesSubcommand, CryptotestAesData, CryptotestAesMctOutput, CryptotestAesMode,
    CryptotestAesOperation, CryptotestAesOutput, CryptotestAesPadding,
};
use cryptotest_commands::commands::CryptotestCommand;

use opentitanlib::app::TransportWrapper;
use opentitanlib::console::spi::SpiConsoleDevice;
use opentitanlib::execute_test;
use opentitanlib::test_utils::init::InitializeTest;
use opentitanlib::test_utils::rpc::{ConsoleRecv, ConsoleSend};
use opentitanlib::uart::console::UartConsole;

#[derive(Debug, Parser)]
struct Opts {
    #[command(flatten)]
    init: InitializeTest,

    // Console receive timeout.
    #[arg(long, value_parser = humantime::parse_duration, default_value = "10s")]
    timeout: Duration,

    // Console receive timeout for a Monte Carlo test.
    #[arg(long, value_parser = humantime::parse_duration, default_value = "600s")]
    mct_timeout: Duration,

    #[arg(long, num_args = 1..)]
    aes_json: Vec<String>,

    #[command(flatten)]
    acvp: AcvpOpts,
}

#[derive(Debug, Deserialize)]
struct MctResult {
    key: Vec<u8>,
    iv: Vec<u8>,
    plaintext: Vec<u8>,
    ciphertext: Vec<u8>,
}

#[derive(Debug, Deserialize)]
struct AesTestCase {
    #[serde(default)]
    vendor: String,
    #[serde(default)]
    test_case_id: u64,
    #[serde(flatten)]
    acvp: AcvpIds,
    #[serde(default)]
    test_type: String,
    operation: String,
    mode: String,
    key: Vec<u8>,
    iv: Option<Vec<u8>>,
    /// The expected output of an encryption, or the input of a decryption.
    #[serde(default)]
    ciphertext: Vec<u8>,
    /// The input of an encryption, or the expected output of a decryption.
    #[serde(default)]
    plaintext: Vec<u8>,
    #[serde(default)]
    mct_results: Vec<MctResult>,
}

const AES_CMD_MAX_MSG_BYTES: usize = 16000;
const AES_CMD_MAX_KEY_BYTES: usize = 256 / 8;
const AES_BLOCK_BYTES: usize = 128 / 8;
const AES_MCT_ITERATIONS: usize = 100;

fn aes_mode(mode: &str) -> CryptotestAesMode {
    match mode {
        "cbc" => CryptotestAesMode::Cbc,
        "cfb128" => CryptotestAesMode::Cfb,
        "ecb" => CryptotestAesMode::Ecb,
        "ofb" => CryptotestAesMode::Ofb,
        _ => panic!("Invalid AES mode"),
    }
}

fn aes_operation(operation: &str) -> CryptotestAesOperation {
    match operation {
        "encrypt" => CryptotestAesOperation::Encrypt,
        "decrypt" => CryptotestAesOperation::Decrypt,
        _ => panic!("Invalid AES operation"),
    }
}

fn aes_data(test_case: &AesTestCase, input: &[u8]) -> Result<CryptotestAesData> {
    let mut iv: ArrayVec<u8, AES_BLOCK_BYTES> = ArrayVec::new();
    match &test_case.iv {
        Some(iv_val) => iv.try_extend_from_slice(iv_val)?,
        None => iv = ArrayVec::from([0; AES_BLOCK_BYTES]),
    }
    let mut key: ArrayVec<u8, AES_CMD_MAX_KEY_BYTES> = ArrayVec::new();
    key.try_extend_from_slice(&test_case.key)?;
    let mut data: ArrayVec<u8, AES_CMD_MAX_MSG_BYTES> = ArrayVec::new();
    data.try_extend_from_slice(input)?;
    Ok(CryptotestAesData {
        key_length: key.len(),
        key,
        iv,
        input: data,
        input_len: input.len(),
    })
}

fn run_aes_mct(
    test_case: &AesTestCase,
    opts: &Opts,
    spi_console: &SpiConsoleDevice,
    fail_counter: &mut u32,
    responses: &mut ResponseBuilder,
) -> Result<()> {
    let encrypt = test_case.operation == "encrypt";
    let input = if encrypt {
        &test_case.plaintext
    } else {
        &test_case.ciphertext
    };
    CryptotestCommand::Aes.send(spi_console)?;
    AesSubcommand::AesMct.send(spi_console)?;
    aes_mode(&test_case.mode).send(spi_console)?;
    aes_operation(&test_case.operation).send(spi_console)?;
    aes_data(test_case, input)?.send(spi_console)?;
    let output = CryptotestAesMctOutput::recv(spi_console, opts.mct_timeout, false, false)?;

    let key_len = test_case.key.len();
    ensure!(
        output.keys_len == AES_MCT_ITERATIONS * key_len
            && output.ivs_len == AES_MCT_ITERATIONS * AES_BLOCK_BYTES
            && output.inputs_len == AES_MCT_ITERATIONS * AES_BLOCK_BYTES
            && output.outputs_len == AES_MCT_ITERATIONS * AES_BLOCK_BYTES,
        "MCT #{}: the device did not return {} outer iterations",
        test_case.test_case_id,
        AES_MCT_ITERATIONS
    );
    let mct_result = |key: &[u8], iv: &[u8], pt: &[u8], ct: &[u8]| {
        let mut result = json!({"key": hex(key), "pt": hex(pt), "ct": hex(ct)});
        if test_case.mode != "ecb" {
            result["iv"] = json!(hex(iv));
        }
        result
    };
    let keys = output.keys[..output.keys_len].chunks(key_len);
    let ivs = output.ivs[..output.ivs_len].chunks(AES_BLOCK_BYTES);
    let inputs = output.inputs[..output.inputs_len].chunks(AES_BLOCK_BYTES);
    let outputs = output.outputs[..output.outputs_len].chunks(AES_BLOCK_BYTES);
    let results: Vec<_> = keys
        .zip(ivs)
        .zip(inputs)
        .zip(outputs)
        .map(|(((key, iv), input), output)| {
            if encrypt {
                mct_result(key, iv, input, output)
            } else {
                mct_result(key, iv, output, input)
            }
        })
        .collect();
    let expected: Vec<_> = test_case
        .mct_results
        .iter()
        .map(|r| mct_result(&r.key, &r.iv, &r.plaintext, &r.ciphertext))
        .collect();
    if !expected.is_empty() && results != expected {
        log::info!("FAILED MCT #{}", test_case.test_case_id);
        *fail_counter += 1;
        return Ok(());
    }

    if test_case.vendor == "acvp" {
        let mut fields = Fields::new();
        fields.insert("resultsArray".to_string(), json!(results));
        responses.add(&test_case.acvp, test_case.test_case_id, fields);
    }
    Ok(())
}

fn run_aes_testcase(
    test_case: &AesTestCase,
    opts: &Opts,
    spi_console: &SpiConsoleDevice,
    fail_counter: &mut u32,
    responses: &mut ResponseBuilder,
) -> Result<()> {
    if test_case.test_type == "mct" {
        return run_aes_mct(test_case, opts, spi_console, fail_counter, responses);
    }
    CryptotestCommand::Aes.send(spi_console)?;
    AesSubcommand::AesBlock.send(spi_console)?;
    aes_mode(&test_case.mode).send(spi_console)?;
    aes_operation(&test_case.operation).send(spi_console)?;
    CryptotestAesPadding::Null.send(spi_console)?;

    // Configure input and output based on operation
    let encrypt = test_case.operation == "encrypt";
    let (input, expected_output) = if encrypt {
        (&test_case.plaintext, &test_case.ciphertext)
    } else {
        (&test_case.ciphertext, &test_case.plaintext)
    };
    aes_data(test_case, input)?.send(spi_console)?;
    let aes_output = CryptotestAesOutput::recv(spi_console, opts.timeout, false, false)?;
    let output = &aes_output.output[0..input.len()];
    if !expected_output.is_empty() && output != expected_output.as_slice() {
        log::info!("FAILED test #{}", test_case.test_case_id);
        *fail_counter += 1;
    }

    if test_case.vendor == "acvp" {
        let mut fields = Fields::new();
        let name = if encrypt { "ct" } else { "pt" };
        fields.insert(name.to_string(), json!(hex(output)));
        responses.add(&test_case.acvp, test_case.test_case_id, fields);
    }
    Ok(())
}

fn test_aes(opts: &Opts, transport: &TransportWrapper) -> Result<()> {
    let spi = transport.spi("BOOTSTRAP")?;
    let spi_console_device = SpiConsoleDevice::new(&*spi, None, /*ignore_frame_num=*/ false)?;
    let _ = UartConsole::wait_for(&spi_console_device, r"Running ", opts.timeout)?;

    let cases: Vec<AesTestCase> = read_vectors(opts.acvp.vectors(&opts.aes_json))?;

    let mut fail_counter = 0u32;
    let mut responses = ResponseBuilder::new();
    for (counter, case) in cases.iter().enumerate() {
        log::info!("Test counter: {}", counter + 1);
        run_aes_testcase(
            case,
            opts,
            &spi_console_device,
            &mut fail_counter,
            &mut responses,
        )?;
    }
    assert_eq!(
        0,
        fail_counter,
        "Failed {} out of {} tests.",
        fail_counter,
        cases.len()
    );
    responses.finish(&opts.acvp)
}

fn main() -> Result<()> {
    let opts = Opts::parse();
    opts.init.init_logging();

    let transport = opts.init.init_target()?;
    execute_test!(test_aes, &opts, &transport);
    Ok(())
}
