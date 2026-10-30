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
use cryptotest_commands::commands::CryptotestCommand;
use cryptotest_commands::hkdf_commands::{
    CryptotestHkdfHashAlg, CryptotestHkdfInput, CryptotestHkdfOutput,
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
    hkdf_json: Vec<String>,

    #[command(flatten)]
    acvp: AcvpOpts,
}

#[derive(Debug, Deserialize)]
struct HkdfTestCase {
    vendor: String,
    test_case_id: u64,
    #[serde(flatten)]
    acvp: AcvpIds,
    operation: String,
    hash_alg: String,
    ikm: Vec<u8>,
    salt: Vec<u8>,
    info: Vec<u8>,
    okm_len: usize,
    /// The expected key when deriving, the key to check when validating.
    #[serde(default)]
    okm: Vec<u8>,
    /// Absent where the outcome is the answer, as in an ACVP prompt.
    #[serde(default)]
    result: Option<bool>,
}

const HKDF_CMD_MAX_IKM_BYTES: usize = 8192;
const HKDF_CMD_MAX_SALT_BYTES: usize = 512;
const HKDF_CMD_MAX_INFO_BYTES: usize = 16420;
const HKDF_CMD_MAX_OKM_BYTES: usize = 128;

fn run_hkdf_testcase(
    test_case: &HkdfTestCase,
    opts: &Opts,
    spi_console: &SpiConsoleDevice,
    fail_counter: &mut u32,
    responses: &mut ResponseBuilder,
) -> Result<()> {
    log::info!(
        "vendor: {}, hash: {}, test case: {}",
        test_case.vendor,
        test_case.hash_alg,
        test_case.test_case_id
    );
    CryptotestCommand::Hkdf.send(spi_console)?;

    assert!(
        test_case.ikm.len() <= HKDF_CMD_MAX_IKM_BYTES,
        "IKM too long for device firmware configuration (got = {}, max = {})",
        test_case.ikm.len(),
        HKDF_CMD_MAX_IKM_BYTES,
    );
    assert!(
        test_case.salt.len() <= HKDF_CMD_MAX_SALT_BYTES,
        "Salt too long for device firmware configuration (got = {}, max = {})",
        test_case.salt.len(),
        HKDF_CMD_MAX_SALT_BYTES,
    );
    assert!(
        test_case.info.len() <= HKDF_CMD_MAX_INFO_BYTES,
        "Info too long for device firmware configuration (got = {}, max = {})",
        test_case.info.len(),
        HKDF_CMD_MAX_INFO_BYTES,
    );
    assert!(
        test_case.okm_len <= HKDF_CMD_MAX_OKM_BYTES,
        "OKM too long for device firmware configuration (got = {}, max = {})",
        test_case.okm_len,
        HKDF_CMD_MAX_OKM_BYTES,
    );

    match test_case.hash_alg.as_str() {
        "SHA2-256" => CryptotestHkdfHashAlg::Sha256,
        "SHA2-384" => CryptotestHkdfHashAlg::Sha384,
        "SHA2-512" => CryptotestHkdfHashAlg::Sha512,
        _ => panic!("Unsupported HKDF hash algorithm: {}", test_case.hash_alg),
    }
    .send(spi_console)?;

    CryptotestHkdfInput {
        ikm: ArrayVec::try_from(test_case.ikm.as_slice()).unwrap(),
        ikm_len: test_case.ikm.len(),
        salt: ArrayVec::try_from(test_case.salt.as_slice()).unwrap(),
        salt_len: test_case.salt.len(),
        info: ArrayVec::try_from(test_case.info.as_slice()).unwrap(),
        info_len: test_case.info.len(),
        okm_len: test_case.okm_len,
    }
    .send(spi_console)?;

    let output = CryptotestHkdfOutput::recv(spi_console, opts.timeout, false, false)?;
    let okm = &output.okm[..output.okm_len];
    // A derived key matches the expected one, a validated key the device's.
    let success = okm == test_case.okm.as_slice();
    if let Some(want) = test_case.result
        && want != success
    {
        log::info!(
            "FAILED test #{}: expected = {}, actual = {}",
            test_case.test_case_id,
            want,
            success
        );
        *fail_counter += 1;
    }

    if test_case.vendor == "acvp" {
        let mut fields = Fields::new();
        if test_case.operation == "validate" {
            fields.insert("testPassed".to_string(), json!(success));
        } else {
            fields.insert("dkm".to_string(), json!(hex(okm)));
        }
        responses.add(&test_case.acvp, test_case.test_case_id, fields);
    }
    Ok(())
}

fn test_hkdf(opts: &Opts, transport: &TransportWrapper) -> Result<()> {
    let spi = transport.spi("BOOTSTRAP")?;
    let spi_console_device = SpiConsoleDevice::new(&*spi, None, /*ignore_frame_num=*/ false)?;
    let _ = UartConsole::wait_for(&spi_console_device, r"Running ", opts.timeout)?;

    let cases: Vec<HkdfTestCase> = read_vectors(opts.acvp.vectors(&opts.hkdf_json))?;

    let mut fail_counter = 0u32;
    let mut responses = ResponseBuilder::new();
    for (counter, case) in cases.iter().enumerate() {
        log::info!("Test counter: {}", counter + 1);
        run_hkdf_testcase(
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
    execute_test!(test_hkdf, &opts, &transport);
    Ok(())
}
