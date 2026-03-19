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
use cryptotest_commands::mlkem_commands::{
    CryptotestMlkemDecapsData, CryptotestMlkemEncapsData, CryptotestMlkemKeygenData,
    CryptotestMlkemKeygenDecapsData, CryptotestMlkemOutput, MlkemSubcommand,
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
    mlkem_json: Vec<String>,
}

#[derive(Debug, Deserialize)]
struct MlkemTestCase {
    vendor: String,
    test_case_id: usize,
    operation: String,
    parameter_set: usize,
    #[serde(default)]
    seed: Vec<u8>,
    #[serde(default)]
    ek: Vec<u8>,
    #[serde(default)]
    dk: Vec<u8>,
    #[serde(default)]
    c: Vec<u8>,
    #[serde(default)]
    expected_hash: Vec<u8>,
    result: bool,
}

// Buffer sizes based on ML-KEM-1024 (largest parameter set),
// oversized where needed for invalid test vectors.
const MAX_SEED: usize = 128; // ML-KEM-1024: 64
const MAX_EK: usize = 2048; // ML-KEM-1024: 1568
const MAX_DK: usize = 3200; // ML-KEM-1024: 3168
const MAX_CT: usize = 1600; // ML-KEM-1024: 1568
const HASH_BYTES: usize = 32;

fn run_mlkem_testcase(
    test_case: &MlkemTestCase,
    opts: &Opts,
    spi_console: &SpiConsoleDevice,
) -> Result<()> {
    log::info!(
        "vendor: {}, test case: {}",
        test_case.vendor,
        test_case.test_case_id
    );

    CryptotestCommand::Mlkem.send(spi_console)?;

    match test_case.operation.as_str() {
        "keygen" => {
            MlkemSubcommand::MlkemKeygen.send(spi_console)?;
            let mut seed: ArrayVec<u8, MAX_SEED> = ArrayVec::new();
            seed.try_extend_from_slice(&test_case.seed)?;
            CryptotestMlkemKeygenData {
                parameter_set: test_case.parameter_set as u32,
                seed,
                seed_len: test_case.seed.len(),
            }
            .send(spi_console)?;
        }
        "keygen_decaps" => {
            MlkemSubcommand::MlkemKeygenDecaps.send(spi_console)?;
            let mut seed: ArrayVec<u8, MAX_SEED> = ArrayVec::new();
            seed.try_extend_from_slice(&test_case.seed)?;
            let mut c: ArrayVec<u8, MAX_CT> = ArrayVec::new();
            c.try_extend_from_slice(&test_case.c)?;
            CryptotestMlkemKeygenDecapsData {
                parameter_set: test_case.parameter_set as u32,
                seed,
                seed_len: test_case.seed.len(),
                c,
                c_len: test_case.c.len(),
            }
            .send(spi_console)?;
        }
        "encaps" => {
            MlkemSubcommand::MlkemEncaps.send(spi_console)?;
            let mut seed: ArrayVec<u8, MAX_SEED> = ArrayVec::new();
            seed.try_extend_from_slice(&test_case.seed)?;
            let mut ek: ArrayVec<u8, MAX_EK> = ArrayVec::new();
            ek.try_extend_from_slice(&test_case.ek)?;
            CryptotestMlkemEncapsData {
                parameter_set: test_case.parameter_set as u32,
                seed,
                seed_len: test_case.seed.len(),
                ek,
                ek_len: test_case.ek.len(),
            }
            .send(spi_console)?;
        }
        "decaps" => {
            MlkemSubcommand::MlkemDecaps.send(spi_console)?;
            let mut dk: ArrayVec<u8, MAX_DK> = ArrayVec::new();
            dk.try_extend_from_slice(&test_case.dk)?;
            let mut c: ArrayVec<u8, MAX_CT> = ArrayVec::new();
            c.try_extend_from_slice(&test_case.c)?;
            CryptotestMlkemDecapsData {
                parameter_set: test_case.parameter_set as u32,
                dk,
                dk_len: test_case.dk.len(),
                c,
                c_len: test_case.c.len(),
            }
            .send(spi_console)?;
        }
        _ => panic!("Unsupported ML-KEM operation: {}", test_case.operation),
    }

    let output = CryptotestMlkemOutput::recv(spi_console, opts.timeout, false)?;

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

fn test_mlkem(opts: &Opts, transport: &TransportWrapper) -> Result<()> {
    let spi = transport.spi("BOOTSTRAP")?;
    let spi_console_device = SpiConsoleDevice::new(&*spi, None)?;
    let _ = UartConsole::wait_for(&spi_console_device, r"Running [^\r\n]*", opts.timeout)?;

    let mut test_counter = 0u32;
    let test_vector_files = &opts.mlkem_json;
    for file in test_vector_files {
        let raw_json = fs::read_to_string(file)?;
        let tests: Vec<MlkemTestCase> = serde_json::from_str(&raw_json)?;

        for test in &tests {
            test_counter += 1;
            log::info!("Test counter: {}", test_counter);
            run_mlkem_testcase(test, opts, &spi_console_device)?;
        }
    }
    Ok(())
}

fn main() -> Result<()> {
    let opts = Opts::parse();
    opts.init.init_logging();

    let transport = opts.init.init_target()?;
    execute_test!(test_mlkem, &opts, &transport);
    Ok(())
}
