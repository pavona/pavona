// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

use anyhow::Result;
use arrayvec::ArrayVec;
use clap::Parser;
use std::time::Duration;

use serde::Deserialize;
use serde_json::json;

use cryptotest_acvp::{AcvpIds, AcvpOpts, Fields, ResponseBuilder, hex, read_vectors};
use cryptotest_commands::aes_kwp_commands::{
    AesKwpSubcommand, CryptotestAesKwpData, CryptotestAesKwpOperation, CryptotestAesKwpOutput,
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

    #[arg(long, num_args = 1..)]
    aes_kwp_json: Vec<String>,

    #[command(flatten)]
    acvp: AcvpOpts,
}

#[derive(Debug, Deserialize)]
struct AesKwpTestCase {
    vendor: String,
    test_case_id: u64,
    #[serde(flatten)]
    acvp: AcvpIds,
    operation: String,
    key_len: usize,
    key: Vec<u8>,
    /// The input when wrapping, and the expected output when unwrapping.
    #[serde(default)]
    plaintext: Vec<u8>,
    /// The input when unwrapping, and the expected output when wrapping.
    #[serde(default)]
    ciphertext: Vec<u8>,
    /// Absent where the outcome is the answer, as in an ACVP prompt.
    #[serde(default)]
    result: Option<bool>,
}

const AES_KWP_CMD_MAX_MSG_BYTES: usize = 520;
const AES_KWP_CMD_MAX_KEY_BYTES: usize = 256 / 8;

fn run_aes_kwp_testcase(
    test_case: &AesKwpTestCase,
    opts: &Opts,
    spi_console: &SpiConsoleDevice,
    responses: &mut ResponseBuilder,
) -> Result<()> {
    log::info!(
        "vendor: {}, test case: {}",
        test_case.vendor,
        test_case.test_case_id
    );
    CryptotestCommand::AesKwp.send(spi_console)?;
    AesKwpSubcommand::AesKwpOp.send(spi_console)?;

    match test_case.operation.as_str() {
        "encrypt" => {
            CryptotestAesKwpOperation::Wrap.send(spi_console)?;
        }
        "decrypt" => {
            CryptotestAesKwpOperation::Unwrap.send(spi_console)?;
        }
        _ => panic!("Invalid AES-KWP operation"),
    }

    let mut key: ArrayVec<u8, AES_KWP_CMD_MAX_KEY_BYTES> = ArrayVec::new();
    key.try_extend_from_slice(&test_case.key)?;

    // Configure input and expected output based on operation.
    let input_length;
    let mut input: ArrayVec<u8, AES_KWP_CMD_MAX_MSG_BYTES> = ArrayVec::new();
    let expected_output;
    match test_case.operation.as_str() {
        "encrypt" => {
            input.try_extend_from_slice(&test_case.plaintext)?;
            input_length = test_case.plaintext.len();
            expected_output = &test_case.ciphertext;
        }
        "decrypt" => {
            input.try_extend_from_slice(&test_case.ciphertext)?;
            input_length = test_case.ciphertext.len();
            expected_output = &test_case.plaintext;
        }
        _ => panic!("Invalid AES-KWP operation"),
    }

    CryptotestAesKwpData {
        key,
        key_length: test_case.key_len / 8,
        input,
        input_length,
    }
    .send(spi_console)?;

    let output = CryptotestAesKwpOutput::recv(spi_console, opts.timeout, false, false)?;
    let actual_output = &output.output[..output.output_len];

    if let Some(expected_success) = test_case.result {
        // Check if the success flag matches.
        assert_eq!(output.success, expected_success);

        if expected_success {
            // Only check output if the operation succeeded, as failed
            // unwrap testvectors don't have an expected output.
            assert_eq!(actual_output, expected_output.as_slice());
        }
    }

    if test_case.vendor == "acvp" {
        let mut fields = Fields::new();
        match (test_case.operation.as_str(), output.success) {
            ("encrypt", _) => {
                fields.insert("ct".to_string(), json!(hex(actual_output)));
            }
            ("decrypt", true) => {
                fields.insert("pt".to_string(), json!(hex(actual_output)));
            }
            ("decrypt", false) => {
                fields.insert("testPassed".to_string(), json!(false));
            }
            (operation, _) => panic!("Invalid AES-KWP operation: {operation}"),
        }
        responses.add(&test_case.acvp, test_case.test_case_id, fields);
    }

    Ok(())
}

fn test_aes_kwp(opts: &Opts, transport: &TransportWrapper) -> Result<()> {
    let spi = transport.spi("BOOTSTRAP")?;
    let spi_console_device = SpiConsoleDevice::new(&*spi, None, /*ignore_frame_num=*/ false)?;
    let _ = UartConsole::wait_for(&spi_console_device, r"Running [^\r\n]*", opts.timeout)?;

    let cases: Vec<AesKwpTestCase> = read_vectors(opts.acvp.vectors(&opts.aes_kwp_json))?;

    let mut responses = ResponseBuilder::new();
    for (counter, case) in cases.iter().enumerate() {
        log::info!("Test counter: {}", counter + 1);
        run_aes_kwp_testcase(case, opts, &spi_console_device, &mut responses)?;
    }
    responses.finish(&opts.acvp)
}

fn main() -> Result<()> {
    let opts = Opts::parse();
    opts.init.init_logging();

    let transport = opts.init.init_target()?;
    execute_test!(test_aes_kwp, &opts, &transport);
    Ok(())
}
