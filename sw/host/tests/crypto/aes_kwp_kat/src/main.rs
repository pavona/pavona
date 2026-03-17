// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

use anyhow::Result;
use arrayvec::ArrayVec;
use clap::Parser;
use std::fs;
use std::time::Duration;

use serde::Deserialize;

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
}

#[derive(Debug, Deserialize)]
struct AesKwpTestCase {
    vendor: String,
    test_case_id: usize,
    operation: String,
    key_len: usize,
    key: Vec<u8>,
    plaintext: Vec<u8>,
    ciphertext: Vec<u8>,
    result: bool,
}

const AES_KWP_CMD_MAX_MSG_BYTES: usize = 520;
const AES_KWP_CMD_MAX_KEY_BYTES: usize = 256 / 8;

fn run_aes_kwp_testcase(
    test_case: &AesKwpTestCase,
    opts: &Opts,
    spi_console: &SpiConsoleDevice,
) -> Result<()> {
    log::info!(
        "vendor: {}, test case: {}",
        test_case.vendor,
        test_case.test_case_id
    );
    CryptotestCommand::AesKwp.send(spi_console)?;
    AesKwpSubcommand::AesKwpOp.send(spi_console)?;

    match test_case.operation.as_str() {
        "encrypt" => CryptotestAesKwpOperation::Wrap.send(spi_console)?,
        "decrypt" => CryptotestAesKwpOperation::Unwrap.send(spi_console)?,
        _ => panic!("Invalid AES-KWP operation"),
    }

    let mut key: ArrayVec<u8, AES_KWP_CMD_MAX_KEY_BYTES> = ArrayVec::new();
    key.try_extend_from_slice(&test_case.key)?;

    // Configure input and expected output based on operation.
    let input_length;
    let mut input: ArrayVec<u8, AES_KWP_CMD_MAX_MSG_BYTES> = ArrayVec::new();
    let expected_output;
    let expected_success;
    match test_case.operation.as_str() {
        "encrypt" => {
            input.try_extend_from_slice(&test_case.plaintext)?;
            input_length = test_case.plaintext.len();
            expected_output = &test_case.ciphertext;
            expected_success = test_case.result;
        }
        "decrypt" => {
            input.try_extend_from_slice(&test_case.ciphertext)?;
            input_length = test_case.ciphertext.len();
            expected_output = &test_case.plaintext;
            expected_success = test_case.result;
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

    let output = CryptotestAesKwpOutput::recv(spi_console, opts.timeout, false)?;

    // Check if the success flag matches.
    assert_eq!(output.success, expected_success);

    if expected_success {
        // Only check output if the operation succeeded, as failed
        // unwrap testvectors don't have an expected output.
        //
        // For unwrap, aes_kwp_unwrap returns the plaintext padded to
        // the next 8-byte boundary. The actual plaintext length is
        // decoded and verified internally (from the KWP header) but
        // not exposed to the caller. We compare only up to the
        // expected plaintext length from the test vector.
        assert_eq!(output.output[..expected_output.len()], expected_output[..],);
        // Verify output length is plaintext padded to 8-byte boundary.
        let expected_padded_len = expected_output.len().div_ceil(8) * 8;
        assert_eq!(output.output_len, expected_padded_len);
        // Verify padding bytes are zero.
        for &b in &output.output[expected_output.len()..output.output_len] {
            assert_eq!(b, 0);
        }
    }

    Ok(())
}

fn test_aes_kwp(opts: &Opts, transport: &TransportWrapper) -> Result<()> {
    let spi = transport.spi("BOOTSTRAP")?;
    let spi_console_device = SpiConsoleDevice::new(&*spi, None)?;
    let _ = UartConsole::wait_for(&spi_console_device, r"Running [^\r\n]*", opts.timeout)?;

    let mut test_counter = 0u32;
    let test_vector_files = &opts.aes_kwp_json;
    for file in test_vector_files {
        let raw_json = fs::read_to_string(file)?;
        let tests: Vec<AesKwpTestCase> = serde_json::from_str(&raw_json)?;

        for test in &tests {
            test_counter += 1;
            log::info!("Test counter: {}", test_counter);
            run_aes_kwp_testcase(test, opts, &spi_console_device)?;
        }
    }
    Ok(())
}

fn main() -> Result<()> {
    let opts = Opts::parse();
    opts.init.init_logging();

    let transport = opts.init.init_target()?;
    execute_test!(test_aes_kwp, &opts, &transport);
    Ok(())
}
