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
use cryptotest_commands::kdf_hmac_commands::{
    CryptotestKdfHmacHashAlg, CryptotestKdfHmacInput, CryptotestKdfHmacMode,
    CryptotestKdfHmacOutput,
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
    kdf_hmac_json: Vec<String>,

    #[command(flatten)]
    acvp: AcvpOpts,
}

#[derive(Debug, Deserialize)]
struct KdfHmacTestCase {
    vendor: String,
    test_case_id: u64,
    #[serde(flatten)]
    acvp: AcvpIds,
    kdf_mode: String,
    mac_mode: String,
    key_in: Vec<u8>,
    fixed_data: Vec<u8>,
    key_out_len: usize,
    #[serde(default)]
    key_out: Vec<u8>,
    /// Absent where the outcome is the answer, as in an ACVP prompt.
    #[serde(default)]
    result: Option<bool>,
}

const KDF_HMAC_CMD_MAX_KEY_IN_BYTES: usize = 64;
const KDF_HMAC_CMD_MAX_FIXED_DATA_BYTES: usize = 64;
const KDF_HMAC_CMD_MAX_KEY_OUT_BYTES: usize = 128;

fn run_kdf_hmac_testcase(
    test_case: &KdfHmacTestCase,
    opts: &Opts,
    spi_console: &SpiConsoleDevice,
    fail_counter: &mut u32,
    responses: &mut ResponseBuilder,
) -> Result<()> {
    log::info!(
        "vendor: {}, mode: {}, mac: {}, test case: {}",
        test_case.vendor,
        test_case.kdf_mode,
        test_case.mac_mode,
        test_case.test_case_id
    );
    CryptotestCommand::KdfHmac.send(spi_console)?;

    assert!(
        test_case.key_in.len() <= KDF_HMAC_CMD_MAX_KEY_IN_BYTES,
        "Key too long for device firmware configuration (got = {}, max = {})",
        test_case.key_in.len(),
        KDF_HMAC_CMD_MAX_KEY_IN_BYTES,
    );
    assert!(
        test_case.fixed_data.len() <= KDF_HMAC_CMD_MAX_FIXED_DATA_BYTES,
        "Fixed data too long for device firmware configuration (got = {}, max = {})",
        test_case.fixed_data.len(),
        KDF_HMAC_CMD_MAX_FIXED_DATA_BYTES,
    );
    assert!(
        test_case.key_out_len <= KDF_HMAC_CMD_MAX_KEY_OUT_BYTES,
        "Derived key too long for device firmware configuration (got = {}, max = {})",
        test_case.key_out_len,
        KDF_HMAC_CMD_MAX_KEY_OUT_BYTES,
    );

    match test_case.kdf_mode.as_str() {
        "counter" => CryptotestKdfHmacMode::Counter,
        "feedback" => CryptotestKdfHmacMode::Feedback,
        _ => panic!("Unsupported KDF mode: {}", test_case.kdf_mode),
    }
    .send(spi_console)?;

    match test_case.mac_mode.as_str() {
        "HMAC-SHA2-256" => CryptotestKdfHmacHashAlg::Sha256,
        "HMAC-SHA2-384" => CryptotestKdfHmacHashAlg::Sha384,
        "HMAC-SHA2-512" => CryptotestKdfHmacHashAlg::Sha512,
        _ => panic!("Unsupported KDF MAC: {}", test_case.mac_mode),
    }
    .send(spi_console)?;

    CryptotestKdfHmacInput {
        key_in: ArrayVec::try_from(test_case.key_in.as_slice()).unwrap(),
        key_in_len: test_case.key_in.len(),
        fixed_data: ArrayVec::try_from(test_case.fixed_data.as_slice()).unwrap(),
        fixed_data_len: test_case.fixed_data.len(),
        key_out_len: test_case.key_out_len,
    }
    .send(spi_console)?;

    let output = CryptotestKdfHmacOutput::recv(spi_console, opts.timeout, false, false)?;
    let key_out = &output.key_out[..output.key_out_len];
    let success = key_out == test_case.key_out.as_slice();
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
        fields.insert("fixedData".to_string(), json!(hex(&test_case.fixed_data)));
        fields.insert("keyOut".to_string(), json!(hex(key_out)));
        responses.add(&test_case.acvp, test_case.test_case_id, fields);
    }
    Ok(())
}

fn test_kdf_hmac(opts: &Opts, transport: &TransportWrapper) -> Result<()> {
    let spi = transport.spi("BOOTSTRAP")?;
    let spi_console_device = SpiConsoleDevice::new(&*spi, None, /*ignore_frame_num=*/ false)?;
    let _ = UartConsole::wait_for(&spi_console_device, r"Running ", opts.timeout)?;

    let cases: Vec<KdfHmacTestCase> = read_vectors(opts.acvp.vectors(&opts.kdf_hmac_json))?;

    let mut fail_counter = 0u32;
    let mut responses = ResponseBuilder::new();
    for (counter, case) in cases.iter().enumerate() {
        log::info!("Test counter: {}", counter + 1);
        run_kdf_hmac_testcase(
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
    execute_test!(test_kdf_hmac, &opts, &transport);
    Ok(())
}
