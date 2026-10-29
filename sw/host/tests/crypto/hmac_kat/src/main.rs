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
use cryptotest_commands::commands::CryptotestCommand;
use cryptotest_commands::hmac_commands::{
    CryptotestHmacHashAlg, CryptotestHmacKey, CryptotestHmacMessage, CryptotestHmacTag,
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
    hmac_json: Vec<String>,

    #[command(flatten)]
    acvp: AcvpOpts,
}

#[derive(Debug, Deserialize)]
struct HmacTestCase {
    vendor: String,
    test_case_id: u64,
    #[serde(flatten)]
    acvp: AcvpIds,
    key: Vec<u8>,
    message: Vec<u8>,
    #[serde(default)]
    tag: Vec<u8>,
    /// Length of the MAC in bytes that an ACVP test asks for.
    #[serde(default)]
    mac_len: usize,
    /// Absent where the outcome is the answer, as in an ACVP prompt.
    #[serde(default)]
    result: Option<bool>,
}

const HMAC_CMD_MAX_MESSAGE_BYTES: usize = 512;
const HMAC_CMD_MAX_KEY_BYTES: usize = 512;

fn run_hmac_testcase(
    test_case: &HmacTestCase,
    opts: &Opts,
    spi_console: &SpiConsoleDevice,
    fail_counter: &mut u32,
    responses: &mut ResponseBuilder,
) -> Result<()> {
    log::info!(
        "vendor: {}, algorithm: {}, test case: {}",
        test_case.vendor,
        test_case.acvp.algorithm,
        test_case.test_case_id
    );
    CryptotestCommand::Hmac.send(spi_console)?;

    assert!(
        test_case.key.len() <= HMAC_CMD_MAX_KEY_BYTES,
        "Key too long for device firmware configuration (got = {}, max = {})",
        test_case.key.len(),
        HMAC_CMD_MAX_KEY_BYTES,
    );
    assert!(
        test_case.message.len() <= HMAC_CMD_MAX_MESSAGE_BYTES,
        "Message too long for device firmware configuration (got = {}, max = {})",
        test_case.message.len(),
        HMAC_CMD_MAX_MESSAGE_BYTES,
    );

    match test_case.acvp.algorithm.as_str() {
        "HMAC-SHA2-256" => CryptotestHmacHashAlg::Sha256,
        "HMAC-SHA2-384" => CryptotestHmacHashAlg::Sha384,
        "HMAC-SHA2-512" => CryptotestHmacHashAlg::Sha512,
        "HMAC-SHA3-256" => CryptotestHmacHashAlg::Sha3_256,
        "HMAC-SHA3-384" => CryptotestHmacHashAlg::Sha3_384,
        "HMAC-SHA3-512" => CryptotestHmacHashAlg::Sha3_512,
        _ => panic!("Unsupported HMAC algorithm: {}", test_case.acvp.algorithm),
    }
    .send(spi_console)?;

    CryptotestHmacKey {
        key: ArrayVec::try_from(test_case.key.as_slice()).unwrap(),
        key_len: test_case.key.len(),
    }
    .send(spi_console)?;

    CryptotestHmacMessage {
        message: ArrayVec::try_from(test_case.message.as_slice()).unwrap(),
        message_len: test_case.message.len(),
    }
    .send(spi_console)?;

    let hmac_tag = CryptotestHmacTag::recv(spi_console, opts.timeout, false, false)?;
    if let Some(want) = test_case.result {
        let success = if test_case.tag.len() > hmac_tag.tag_len {
            // If we got a shorter tag back then the test asks for, we can't accept the tag, even
            // if the beginning bytes match.
            false
        } else {
            // Some of the NIST test cases only specify the beginning bytes of the expected tag,
            // so we only check up to what the test specifies.
            test_case.tag[..] == hmac_tag.tag[..test_case.tag.len()]
        };
        if want != success {
            log::info!(
                "FAILED test #{}: expected = {}, actual = {}",
                test_case.test_case_id,
                want,
                success
            );
            *fail_counter += 1;
        }
    }

    if test_case.vendor == "acvp" {
        // The registrations claim only full-length MACs, which is what the
        // cryptolib computes. NIST's sample vector sets ask for truncated MACs,
        // so the harness truncates the MAC for vectors that come with answers.
        ensure!(
            test_case.mac_len == hmac_tag.tag_len
                || (test_case.mac_len < hmac_tag.tag_len && test_case.result.is_some()),
            "{} test #{} asks for a {}-byte MAC, which the registration does not claim",
            test_case.acvp.algorithm,
            test_case.test_case_id,
            test_case.mac_len,
        );
        let mut fields = Fields::new();
        let mac = &hmac_tag.tag[..test_case.mac_len];
        fields.insert("mac".to_string(), json!(hex(mac)));
        responses.add(&test_case.acvp, test_case.test_case_id, fields);
    }
    Ok(())
}

fn test_hmac(opts: &Opts, transport: &TransportWrapper) -> Result<()> {
    let spi = transport.spi("BOOTSTRAP")?;
    let spi_console_device = SpiConsoleDevice::new(&*spi, None, /*ignore_frame_num=*/ false)?;
    let _ = UartConsole::wait_for(&spi_console_device, r"Running ", opts.timeout)?;

    let cases: Vec<HmacTestCase> = read_vectors(opts.acvp.vectors(&opts.hmac_json))?;

    let mut fail_counter = 0u32;
    let mut responses = ResponseBuilder::new();
    for (counter, case) in cases.iter().enumerate() {
        log::info!("Test counter: {}", counter + 1);
        run_hmac_testcase(
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
    execute_test!(test_hmac, &opts, &transport);
    Ok(())
}
