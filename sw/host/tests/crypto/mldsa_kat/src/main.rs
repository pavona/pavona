// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

use anyhow::Result;
use arrayvec::ArrayVec;
use clap::Parser;
use std::fs;
use std::time::Duration;

use serde::Deserialize;

use cryptotest_commands::commands::CryptotestCommand;
use cryptotest_commands::mldsa_commands::{
    CryptotestMldsaKeygenData, CryptotestMldsaKeygenSignData, CryptotestMldsaOutput,
    CryptotestMldsaSiggenData, CryptotestMldsaSigverData, MldsaSubcommand,
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

    #[arg(long, value_parser = humantime::parse_duration, default_value = "10s")]
    timeout: Duration,

    #[arg(long, num_args = 1..)]
    mldsa_json: Vec<String>,
}

#[derive(Debug, Deserialize)]
struct MldsaTestCase {
    vendor: String,
    test_case_id: usize,
    operation: String,
    parameter_set: usize,
    #[serde(default)]
    seed: Vec<u8>,
    #[serde(default)]
    sk: Vec<u8>,
    #[serde(default)]
    pk: Vec<u8>,
    #[serde(default)]
    message: Vec<u8>,
    #[serde(default)]
    context: Vec<u8>,
    #[serde(default)]
    rnd: Vec<u8>,
    #[serde(default)]
    signature: Vec<u8>,
    #[serde(default)]
    expected_hash: Vec<u8>,
    result: bool,
}

// Buffer sizes based on ML-DSA-87 (largest parameter set),
// oversized where needed for invalid test vectors.
const MAX_SEED: usize = 64; // all parameter sets: 32
const MAX_SK: usize = 4928; // ML-DSA-87: 4896
const MAX_PK: usize = 2624; // ML-DSA-87: 2592
const MAX_MSG: usize = 8448; // ML-DSA-87: 8192
const MAX_CTX: usize = 256; // FIPS 204: 255
const MAX_SIG: usize = 4672; // ML-DSA-87: 4627
const MAX_RND: usize = 32;
const HASH_BYTES: usize = 32;

fn run_mldsa_testcase(
    test_case: &MldsaTestCase,
    opts: &Opts,
    spi_console: &SpiConsoleDevice,
) -> Result<()> {
    log::info!(
        "vendor: {}, test case: {}",
        test_case.vendor,
        test_case.test_case_id
    );

    CryptotestCommand::Mldsa.send(spi_console)?;

    match test_case.operation.as_str() {
        "keygen" => {
            MldsaSubcommand::MldsaKeygen.send(spi_console)?;
            let mut seed: ArrayVec<u8, MAX_SEED> = ArrayVec::new();
            seed.try_extend_from_slice(&test_case.seed)?;
            CryptotestMldsaKeygenData {
                parameter_set: test_case.parameter_set as u32,
                seed,
                seed_len: test_case.seed.len(),
            }
            .send(spi_console)?;
        }
        "keygen_sign" => {
            MldsaSubcommand::MldsaKeygenSign.send(spi_console)?;
            let mut seed: ArrayVec<u8, MAX_SEED> = ArrayVec::new();
            seed.try_extend_from_slice(&test_case.seed)?;
            let mut message: ArrayVec<u8, MAX_MSG> = ArrayVec::new();
            message.try_extend_from_slice(&test_case.message)?;
            let mut context: ArrayVec<u8, MAX_CTX> = ArrayVec::new();
            context.try_extend_from_slice(&test_case.context)?;
            let mut rnd: ArrayVec<u8, MAX_RND> = ArrayVec::new();
            rnd.try_extend_from_slice(&test_case.rnd)?;
            CryptotestMldsaKeygenSignData {
                parameter_set: test_case.parameter_set as u32,
                seed,
                seed_len: test_case.seed.len(),
                message,
                message_len: test_case.message.len(),
                context,
                context_len: test_case.context.len(),
                rnd,
                rnd_len: test_case.rnd.len(),
            }
            .send(spi_console)?;
        }
        "siggen" => {
            MldsaSubcommand::MldsaSiggen.send(spi_console)?;
            let mut sk: ArrayVec<u8, MAX_SK> = ArrayVec::new();
            sk.try_extend_from_slice(&test_case.sk)?;
            let mut message: ArrayVec<u8, MAX_MSG> = ArrayVec::new();
            message.try_extend_from_slice(&test_case.message)?;
            let mut context: ArrayVec<u8, MAX_CTX> = ArrayVec::new();
            context.try_extend_from_slice(&test_case.context)?;
            let mut rnd: ArrayVec<u8, MAX_RND> = ArrayVec::new();
            rnd.try_extend_from_slice(&test_case.rnd)?;
            CryptotestMldsaSiggenData {
                parameter_set: test_case.parameter_set as u32,
                sk,
                sk_len: test_case.sk.len(),
                message,
                message_len: test_case.message.len(),
                context,
                context_len: test_case.context.len(),
                rnd,
                rnd_len: test_case.rnd.len(),
            }
            .send(spi_console)?;
        }
        "sigver" => {
            MldsaSubcommand::MldsaSigver.send(spi_console)?;
            let mut pk: ArrayVec<u8, MAX_PK> = ArrayVec::new();
            pk.try_extend_from_slice(&test_case.pk)?;
            let mut message: ArrayVec<u8, MAX_MSG> = ArrayVec::new();
            message.try_extend_from_slice(&test_case.message)?;
            let mut context: ArrayVec<u8, MAX_CTX> = ArrayVec::new();
            context.try_extend_from_slice(&test_case.context)?;
            let mut signature: ArrayVec<u8, MAX_SIG> = ArrayVec::new();
            signature.try_extend_from_slice(&test_case.signature)?;
            CryptotestMldsaSigverData {
                parameter_set: test_case.parameter_set as u32,
                pk,
                pk_len: test_case.pk.len(),
                message,
                message_len: test_case.message.len(),
                context,
                context_len: test_case.context.len(),
                signature,
                signature_len: test_case.signature.len(),
            }
            .send(spi_console)?;
        }
        _ => panic!("Unsupported ML-DSA operation: {}", test_case.operation),
    }

    let output = CryptotestMldsaOutput::recv(spi_console, opts.timeout, false)?;

    assert_eq!(
        output.success, test_case.result,
        "test #{}: expected success={}, got={}",
        test_case.test_case_id, test_case.result, output.success
    );

    // Verify hash if expected (valid tests with pre-computed hash).
    if test_case.result && !test_case.expected_hash.is_empty() {
        assert_eq!(
            output.hash[..HASH_BYTES],
            test_case.expected_hash[..],
            "test #{}: hash mismatch",
            test_case.test_case_id
        );
    }

    Ok(())
}

fn test_mldsa(opts: &Opts, transport: &TransportWrapper) -> Result<()> {
    let spi = transport.spi("BOOTSTRAP")?;
    let spi_console_device = SpiConsoleDevice::new(&*spi, None)?;
    let _ = UartConsole::wait_for(&spi_console_device, r"Running [^\r\n]*", opts.timeout)?;

    let mut test_counter = 0u32;
    let test_vector_files = &opts.mldsa_json;
    for file in test_vector_files {
        let raw_json = fs::read_to_string(file)?;
        let tests: Vec<MldsaTestCase> = serde_json::from_str(&raw_json)?;

        for test in &tests {
            test_counter += 1;
            log::info!("Test counter: {}", test_counter);
            run_mldsa_testcase(test, opts, &spi_console_device)?;
        }
    }
    Ok(())
}

fn main() -> Result<()> {
    let opts = Opts::parse();
    opts.init.init_logging();

    let transport = opts.init.init_target()?;
    execute_test!(test_mldsa, &opts, &transport);
    Ok(())
}
