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
    CryptotestMlkemDecapsData, CryptotestMlkemDecapsOutput, CryptotestMlkemEncapsData,
    CryptotestMlkemEncapsOutput, CryptotestMlkemKeygenData, CryptotestMlkemKeygenDecapsData,
    CryptotestMlkemKeygenDecapsOutput, CryptotestMlkemKeygenOutput, MlkemSubcommand,
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
    expected_ek: Vec<u8>,
    #[serde(default)]
    expected_dk: Vec<u8>,
    #[serde(default)]
    expected_c: Vec<u8>,
    #[serde(default)]
    expected_k: Vec<u8>,
    result: bool,
}

// Raw outputs returned by the device. Only the fields the operation produces
// are populated.
#[derive(Default)]
struct MlkemOutputs {
    success: bool,
    ek: Vec<u8>,
    dk: Vec<u8>,
    c: Vec<u8>,
    k: Vec<u8>,
}

fn check_output(name: &str, tc_id: usize, actual: &[u8], expected: &[u8]) {
    if expected.is_empty() {
        return;
    }
    assert_eq!(actual, expected, "test #{}: {} mismatch", tc_id, name);
}

// Buffer sizes based on ML-KEM-1024 (largest parameter set),
// oversized where needed for invalid test vectors.
const MAX_SEED: usize = 128; // ML-KEM-1024: 64
const MAX_EK: usize = 2048; // ML-KEM-1024: 1568
const MAX_DK: usize = 3200; // ML-KEM-1024: 3168
const MAX_CT: usize = 1600; // ML-KEM-1024: 1568

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

    let outputs = match test_case.operation.as_str() {
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
            let out = CryptotestMlkemKeygenOutput::recv(spi_console, opts.timeout, false, false)?;
            MlkemOutputs {
                success: out.success,
                ek: out.ek[..out.ek_len].to_vec(),
                dk: out.dk[..out.dk_len].to_vec(),
                ..Default::default()
            }
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
            let out =
                CryptotestMlkemKeygenDecapsOutput::recv(spi_console, opts.timeout, false, false)?;
            MlkemOutputs {
                success: out.success,
                ek: out.ek[..out.ek_len].to_vec(),
                k: out.k[..out.k_len].to_vec(),
                ..Default::default()
            }
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
            let out = CryptotestMlkemEncapsOutput::recv(spi_console, opts.timeout, false, false)?;
            MlkemOutputs {
                success: out.success,
                c: out.c[..out.c_len].to_vec(),
                k: out.k[..out.k_len].to_vec(),
                ..Default::default()
            }
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
            let out = CryptotestMlkemDecapsOutput::recv(spi_console, opts.timeout, false, false)?;
            MlkemOutputs {
                success: out.success,
                k: out.k[..out.k_len].to_vec(),
                ..Default::default()
            }
        }
        _ => panic!("Unsupported ML-KEM operation: {}", test_case.operation),
    };

    assert_eq!(
        outputs.success, test_case.result,
        "test #{}: expected success={}, got={}",
        test_case.test_case_id, test_case.result, outputs.success
    );

    if test_case.result {
        let id = test_case.test_case_id;
        check_output("ek", id, &outputs.ek, &test_case.expected_ek);
        check_output("dk", id, &outputs.dk, &test_case.expected_dk);
        check_output("c", id, &outputs.c, &test_case.expected_c);
        check_output("k", id, &outputs.k, &test_case.expected_k);
    }

    Ok(())
}

fn test_mlkem(opts: &Opts, transport: &TransportWrapper) -> Result<()> {
    let spi = transport.spi("BOOTSTRAP")?;
    let spi_console_device = SpiConsoleDevice::new(&*spi, None, /*ignore_frame_num=*/ false)?;
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
