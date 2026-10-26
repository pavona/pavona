// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

use anyhow::Result;
use arrayvec::ArrayVec;
use clap::Parser;
use std::fs;
use std::time::Duration;

use serde::Deserialize;

use cryptotest_commands::commands::CryptotestCommand;
use cryptotest_commands::drbg_commands::{CryptotestDrbgInput, CryptotestDrbgOutput};

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
    drbg_json: Vec<String>,
}

#[derive(Debug, Deserialize)]
struct DrbgTestCase {
    vendor: String,
    test_case_id: usize,
    entropy: Vec<u8>,
    personalization_string: Vec<u8>,
    reseed: bool,
    #[serde(default)]
    reseed_entropy: Vec<u8>,
    #[serde(default)]
    reseed_additional_input: Vec<u8>,
    additional_input_1: Vec<u8>,
    additional_input_2: Vec<u8>,
    output: Vec<u8>,
    result: bool,
}

fn run_drbg_testcase(
    test_case: &DrbgTestCase,
    opts: &Opts,
    spi_console: &SpiConsoleDevice,
    fail_counter: &mut u32,
) -> Result<()> {
    log::info!(
        "vendor: {}, test case: {}",
        test_case.vendor,
        test_case.test_case_id
    );

    CryptotestCommand::Drbg.send(spi_console)?;

    let entropy = Vec::from(test_case.entropy.as_slice());
    let perso_string = Vec::from(test_case.personalization_string.as_slice());
    let reseed_entropy = Vec::from(test_case.reseed_entropy.as_slice());
    let reseed_addl = Vec::from(test_case.reseed_additional_input.as_slice());
    let addl_1 = Vec::from(test_case.additional_input_1.as_slice());
    let addl_2 = Vec::from(test_case.additional_input_2.as_slice());

    // Send everything
    CryptotestDrbgInput {
        entropy: ArrayVec::try_from(entropy.as_slice()).unwrap(),
        entropy_len: entropy.len(),
        personalization_string: ArrayVec::try_from(perso_string.as_slice()).unwrap(),
        personalization_string_len: perso_string.len(),
        reseed: if test_case.reseed { 1 } else { 0 },
        reseed_entropy: ArrayVec::try_from(reseed_entropy.as_slice()).unwrap(),
        reseed_entropy_len: reseed_entropy.len(),
        reseed_additional_input: ArrayVec::try_from(reseed_addl.as_slice()).unwrap(),
        reseed_additional_input_len: reseed_addl.len(),
        additional_input_1: ArrayVec::try_from(addl_1.as_slice()).unwrap(),
        additional_input_1_len: addl_1.len(),
        additional_input_2: ArrayVec::try_from(addl_2.as_slice()).unwrap(),
        additional_input_2_len: addl_2.len(),
        output_len: test_case.output.len(),
    }
    .send(spi_console)?;

    // Get output
    let drbg_output = CryptotestDrbgOutput::recv(spi_console, opts.timeout, false, false)?;
    let output = Vec::from(&drbg_output.output[..drbg_output.output_len]);

    // Output byte length not a multiple of 4 is currently unsupported.
    if output.len() % 4 != 0 {
        panic!("Output length in bytes was not a multiple of 4.");
    }
    let success = test_case.output == output;
    if test_case.result != success {
        log::info!(
            "FAILED test #{}: expected = {}, actual = {}",
            test_case.test_case_id,
            test_case.result,
            success
        );
        *fail_counter += 1;
    }
    Ok(())
}

fn test_drbg(opts: &Opts, transport: &TransportWrapper) -> Result<()> {
    let spi = transport.spi("BOOTSTRAP")?;
    let spi_console_device = SpiConsoleDevice::new(&*spi, None, /*ignore_frame_num=*/ false)?;
    let _ = UartConsole::wait_for(&spi_console_device, r"Running ", opts.timeout)?;

    let mut test_counter = 0u32;
    let mut fail_counter = 0u32;
    let test_vector_files = &opts.drbg_json;
    for file in test_vector_files {
        let raw_json = fs::read_to_string(file)?;
        let drbg_tests: Vec<DrbgTestCase> = serde_json::from_str(&raw_json)?;

        for drbg_test in &drbg_tests {
            test_counter += 1;
            log::info!("Test counter: {}", test_counter);
            run_drbg_testcase(drbg_test, opts, &spi_console_device, &mut fail_counter)?;
        }
    }
    assert_eq!(
        0, fail_counter,
        "Failed {} out of {} tests.",
        fail_counter, test_counter
    );
    Ok(())
}

fn main() -> Result<()> {
    let opts = Opts::parse();
    opts.init.init_logging();

    let transport = opts.init.init_target()?;
    execute_test!(test_drbg, &opts, &transport);
    Ok(())
}
