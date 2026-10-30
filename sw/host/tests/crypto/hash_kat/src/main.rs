// Copyright lowRISC contributors (OpenTitan project).
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
use cryptotest_commands::hash_commands::{
    CryptotestHashAlgorithm, CryptotestHashMctOutput, CryptotestHashMessage, CryptotestHashOutput,
    CryptotestHashShakeDigestLength,
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

    // Console receive timeout for a Monte Carlo test.
    #[arg(long, value_parser = humantime::parse_duration, default_value = "600s")]
    mct_timeout: Duration,

    #[arg(long, num_args = 1..)]
    hash_json: Vec<String>,

    #[command(flatten)]
    acvp: AcvpOpts,
}

#[derive(Debug, Deserialize)]
struct HashTestCase {
    vendor: String,
    test_case_id: u64,
    #[serde(flatten)]
    acvp: AcvpIds,
    #[serde(default)]
    operation: String,
    message: Vec<u8>,
    // Customization string used for cSHAKE only
    #[serde(default)]
    customization_string: Vec<u8>,
    #[serde(default)]
    digest: Vec<u8>,
    #[serde(default)]
    output_len: usize,
    #[serde(default)]
    mct_digests: Vec<Vec<u8>>,
    /// Absent where the outcome is the answer, as in an ACVP prompt.
    #[serde(default)]
    result: Option<bool>,
}

const HASH_CMD_MAX_MESSAGE_BYTES: usize = 17068;
const HASH_CMD_MAX_CUSTOMIZATION_STRING_BYTES: usize = 16;

fn hash_algorithm(name: &str) -> CryptotestHashAlgorithm {
    match name {
        "SHA2-256" => CryptotestHashAlgorithm::Sha256,
        "SHA2-384" => CryptotestHashAlgorithm::Sha384,
        "SHA2-512" => CryptotestHashAlgorithm::Sha512,
        "SHA3-224" => CryptotestHashAlgorithm::Sha3_224,
        "SHA3-256" => CryptotestHashAlgorithm::Sha3_256,
        "SHA3-384" => CryptotestHashAlgorithm::Sha3_384,
        "SHA3-512" => CryptotestHashAlgorithm::Sha3_512,
        "SHAKE-128" => CryptotestHashAlgorithm::Shake128,
        "SHAKE-256" => CryptotestHashAlgorithm::Shake256,
        "cSHAKE-128" => CryptotestHashAlgorithm::Cshake128,
        "cSHAKE-256" => CryptotestHashAlgorithm::Cshake256,
        _ => panic!("Unsupported hash algorithm: {name}"),
    }
}

fn run_hash_mct(
    test_case: &HashTestCase,
    opts: &Opts,
    spi_console: &SpiConsoleDevice,
    fail_counter: &mut u32,
    responses: &mut ResponseBuilder,
) -> Result<()> {
    CryptotestCommand::HashMct.send(spi_console)?;
    hash_algorithm(&test_case.acvp.algorithm).send(spi_console)?;
    CryptotestHashMessage {
        message: ArrayVec::try_from(test_case.message.as_slice()).unwrap(),
        message_len: test_case.message.len(),
        customization_string: ArrayVec::new(),
        customization_string_len: 0,
    }
    .send(spi_console)?;
    let output = CryptotestHashMctOutput::recv(spi_console, opts.mct_timeout, false, false)?;

    let digests: Vec<&[u8]> = output.digests.chunks(output.digest_len).collect();
    if !test_case.mct_digests.is_empty() && digests != test_case.mct_digests {
        log::info!(
            "FAILED {} MCT #{}",
            test_case.acvp.algorithm,
            test_case.test_case_id
        );
        *fail_counter += 1;
        return Ok(());
    }

    if test_case.vendor == "acvp" {
        let results: Vec<_> = digests.iter().map(|md| json!({"md": hex(md)})).collect();
        let mut fields = Fields::new();
        fields.insert("resultsArray".to_string(), json!(results));
        responses.add(&test_case.acvp, test_case.test_case_id, fields);
    }
    Ok(())
}

fn run_hash_testcase(
    test_case: &HashTestCase,
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
    if test_case.operation == "mct" {
        return run_hash_mct(test_case, opts, spi_console, fail_counter, responses);
    }
    CryptotestCommand::Hash.send(spi_console)?;

    assert!(
        test_case.message.len() <= HASH_CMD_MAX_MESSAGE_BYTES,
        "Message too long for device firmware configuration (got = {}, max = {})",
        test_case.message.len(),
        HASH_CMD_MAX_MESSAGE_BYTES,
    );
    assert!(
        test_case.customization_string.len() <= HASH_CMD_MAX_CUSTOMIZATION_STRING_BYTES,
        "Customization string too long for device firmware configuration (got = {}, max = {})",
        test_case.customization_string.len(),
        HASH_CMD_MAX_CUSTOMIZATION_STRING_BYTES,
    );

    // Send algorithm type
    hash_algorithm(&test_case.acvp.algorithm).send(spi_console)?;

    // Send required digest size for SHAKE tests (this value is
    // ignored for SHA2/3)
    CryptotestHashShakeDigestLength {
        length: if test_case.output_len > 0 {
            test_case.output_len
        } else {
            test_case.digest.len()
        },
    }
    .send(spi_console)?;

    // Send hash preimage
    CryptotestHashMessage {
        message: ArrayVec::try_from(test_case.message.as_slice()).unwrap(),
        message_len: test_case.message.len(),
        customization_string: ArrayVec::try_from(test_case.customization_string.as_slice())
            .unwrap(),
        customization_string_len: test_case.customization_string.len(),
    }
    .send(spi_console)?;

    // Get hash output
    let hash_output = CryptotestHashOutput::recv(spi_console, opts.timeout, false, false)?;
    // Stepwise hashing is currently supported by SHA2 only.
    let mut failed = false;
    match test_case.acvp.algorithm.as_str() {
        "SHA2-256" | "SHA2-384" | "SHA2-512" => {
            vec![
                ("oneshot", &hash_output.oneshot_digest),
                ("stepwise", &hash_output.stepwise_digest),
            ]
        }
        _ => vec![("oneshot", &hash_output.oneshot_digest)],
    }
    .into_iter()
    .for_each(|(mode, digest)| {
        let Some(want) = test_case.result else {
            return;
        };
        let success = if test_case.digest.len() > hash_output.digest_len {
            // If we got a shorter digest back then the test asks for, we
            // can't accept the digest, even if the beginning bytes match.
            false
        } else {
            // Some test cases only specify the beginning bytes of the
            // expected digest, so we only check up to what the test
            // specifies.
            test_case.digest[..] == digest[..test_case.digest.len()]
        };
        if want != success {
            log::info!(
                "FAILED {} test #{} in {} mode: expected = {}, actual = {}",
                test_case.acvp.algorithm,
                test_case.test_case_id,
                mode,
                want,
                success
            );
            failed = true;
        }
    });
    if failed {
        *fail_counter += 1;
    }

    if test_case.vendor == "acvp" {
        let mut fields = Fields::new();
        let md = &hash_output.oneshot_digest[..hash_output.digest_len];
        fields.insert("md".to_string(), json!(hex(md)));
        responses.add(&test_case.acvp, test_case.test_case_id, fields);
    }
    Ok(())
}

fn test_hash(opts: &Opts, transport: &TransportWrapper) -> Result<()> {
    let spi = transport.spi("BOOTSTRAP")?;
    let spi_console_device = SpiConsoleDevice::new(&*spi, None, /*ignore_frame_num=*/ false)?;
    let _ = UartConsole::wait_for(&spi_console_device, r"Running ", opts.timeout)?;

    let cases: Vec<HashTestCase> = read_vectors(opts.acvp.vectors(&opts.hash_json))?;

    let mut fail_counter = 0u32;
    let mut responses = ResponseBuilder::new();
    for (counter, case) in cases.iter().enumerate() {
        log::info!("Test counter: {}", counter + 1);
        run_hash_testcase(
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
    execute_test!(test_hash, &opts, &transport);
    Ok(())
}
