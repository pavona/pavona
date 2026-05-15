// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

use anyhow::Result;
use arrayvec::ArrayVec;
use clap::Parser;
use serde::Deserialize;
use std::fs;
use std::time::Duration;

use cryptotest_commands::commands::CryptotestCommand;
use cryptotest_commands::ed25519_commands::{
    CryptotestEd25519Message, CryptotestEd25519PublicKey, CryptotestEd25519SiggenData,
    CryptotestEd25519SiggenOutput, CryptotestEd25519SignMode, CryptotestEd25519Signature,
    CryptotestEd25519VerifyOutput, Ed25519Subcommand,
};

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
    ed25519_json: Vec<String>,
}

#[derive(Debug, Deserialize)]
struct Ed25519TestCase {
    #[serde(default)]
    vendor: String,
    #[serde(default)]
    test_case_id: usize,
    algorithm: String,
    operation: String,
    sign_mode: String,
    message: Vec<u8>,
    #[serde(default)]
    public_key: Vec<u8>,
    #[serde(default)]
    signature: Vec<u8>,
    #[serde(default)]
    private_key: Vec<u8>,
    #[serde(default)]
    context: Vec<u8>,
    #[serde(default)]
    expected_signature: Vec<u8>,
    result: bool,
}

fn run_ed25519_verify(
    test_case: &Ed25519TestCase,
    opts: &Opts,
    spi_console: &SpiConsoleDevice,
) -> Result<bool> {
    Ed25519Subcommand::Ed25519Sigver.send(spi_console)?;

    let sign_mode = match test_case.sign_mode.as_str() {
        "eddsa" => CryptotestEd25519SignMode::Eddsa,
        "hash_eddsa" => CryptotestEd25519SignMode::HashEddsa,
        _ => panic!("Unknown sign mode: {}", test_case.sign_mode),
    };
    sign_mode.send(spi_console)?;

    let mut input = ArrayVec::new();
    input.try_extend_from_slice(&test_case.message)?;
    CryptotestEd25519Message {
        input,
        input_len: test_case.message.len(),
    }
    .send(spi_console)?;

    let mut signature = ArrayVec::new();
    signature.try_extend_from_slice(&test_case.signature)?;
    CryptotestEd25519Signature {
        signature,
        signature_len: test_case.signature.len(),
    }
    .send(spi_console)?;

    let mut pk = ArrayVec::new();
    pk.try_extend_from_slice(&test_case.public_key)?;
    CryptotestEd25519PublicKey {
        pk,
        pk_len: test_case.public_key.len(),
    }
    .send(spi_console)?;

    let output = CryptotestEd25519VerifyOutput::recv(spi_console, opts.timeout, false, false)?;
    Ok(match output {
        CryptotestEd25519VerifyOutput::Success => true,
        CryptotestEd25519VerifyOutput::Failure => false,
        CryptotestEd25519VerifyOutput::IntValue(i) => {
            panic!("Invalid Ed25519 verify result: {}", i)
        }
    })
}

fn run_ed25519_sign(
    test_case: &Ed25519TestCase,
    opts: &Opts,
    spi_console: &SpiConsoleDevice,
) -> Result<bool> {
    Ed25519Subcommand::Ed25519Siggen.send(spi_console)?;

    let sign_mode = match test_case.sign_mode.as_str() {
        "eddsa" => CryptotestEd25519SignMode::Eddsa,
        "hash_eddsa" => CryptotestEd25519SignMode::HashEddsa,
        _ => panic!("Unknown sign mode: {}", test_case.sign_mode),
    };
    sign_mode.send(spi_console)?;

    let mut sk = ArrayVec::new();
    sk.try_extend_from_slice(&test_case.private_key)?;
    let mut pk = ArrayVec::new();
    pk.try_extend_from_slice(&test_case.public_key)?;
    let mut message = ArrayVec::new();
    message.try_extend_from_slice(&test_case.message)?;
    let mut context = ArrayVec::new();
    context.try_extend_from_slice(&test_case.context)?;
    CryptotestEd25519SiggenData {
        sk,
        sk_len: test_case.private_key.len(),
        pk,
        pk_len: test_case.public_key.len(),
        message,
        message_len: test_case.message.len(),
        context,
        context_len: test_case.context.len(),
    }
    .send(spi_console)?;

    let output = CryptotestEd25519SiggenOutput::recv(spi_console, opts.timeout, false, false)?;
    Ok(output.success == test_case.result
        && output.signature[..output.signature_len] == *test_case.expected_signature)
}

fn run_ed25519_testcase(
    test_case: &Ed25519TestCase,
    opts: &Opts,
    spi_console: &SpiConsoleDevice,
    failures: &mut Vec<String>,
) -> Result<()> {
    log::info!(
        "vendor: {}, test case: {}, operation: {}",
        test_case.vendor,
        test_case.test_case_id,
        test_case.operation
    );
    assert_eq!(test_case.algorithm.as_str(), "ed25519");

    CryptotestCommand::Ed25519.send(spi_console)?;

    let success = match test_case.operation.as_str() {
        "verify" => run_ed25519_verify(test_case, opts, spi_console)?,
        "sign" => run_ed25519_sign(test_case, opts, spi_console)?,
        _ => panic!("Unsupported Ed25519 operation: {}", test_case.operation),
    };

    if test_case.result != success {
        log::info!(
            "FAILED test #{}: expected = {}, actual = {}",
            test_case.test_case_id,
            test_case.result,
            success
        );
        failures.push(format!(
            "ed25519 {} #{}",
            test_case.operation, test_case.test_case_id
        ));
    }
    Ok(())
}

fn test_ed25519(opts: &Opts, transport: &TransportWrapper) -> Result<()> {
    let spi = transport.spi("BOOTSTRAP")?;
    let spi_console_device = SpiConsoleDevice::new(&*spi, None, /*ignore_frame_num=*/ false)?;
    let _ = UartConsole::wait_for(&spi_console_device, r"Running ", opts.timeout)?;

    let mut test_counter = 0u32;
    let mut failures = vec![];
    let test_vector_files = &opts.ed25519_json;
    for file in test_vector_files {
        let raw_json = fs::read_to_string(file)?;
        let ed25519_tests: Vec<Ed25519TestCase> = serde_json::from_str(&raw_json)?;

        for ed25519_test in &ed25519_tests {
            test_counter += 1;
            log::info!("Test counter: {}", test_counter);
            run_ed25519_testcase(ed25519_test, opts, &spi_console_device, &mut failures)?;
        }
    }
    assert_eq!(
        0,
        failures.len(),
        "Failed {} out of {} tests. Failures: {:?}",
        failures.len(),
        test_counter,
        failures
    );
    Ok(())
}

fn main() -> Result<()> {
    let opts = Opts::parse();
    opts.init.init_logging();

    let transport = opts.init.init_target()?;
    execute_test!(test_ed25519, &opts, &transport);
    Ok(())
}
