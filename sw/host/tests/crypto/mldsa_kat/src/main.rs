// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

use anyhow::Result;
use arrayvec::ArrayVec;
use clap::Parser;
use std::time::Duration;

use serde::Deserialize;
use serde_json::json;

use cryptotest_acvp::{
    AcvpIds, AcvpOpts, Fields, ResponseBuilder, check_output, hex, read_vectors,
};
use cryptotest_commands::commands::CryptotestCommand;
use cryptotest_commands::mldsa_commands::{
    CryptotestMldsaKeygenData, CryptotestMldsaKeygenOutput, CryptotestMldsaKeygenSignData,
    CryptotestMldsaKeygenSignOutput, CryptotestMldsaSiggenData, CryptotestMldsaSiggenOutput,
    CryptotestMldsaSigverData, CryptotestMldsaSigverOutput, MldsaSignMode, MldsaSubcommand,
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

    #[command(flatten)]
    acvp: AcvpOpts,
}

#[derive(Debug, Deserialize)]
struct MldsaTestCase {
    vendor: String,
    test_case_id: u64,
    operation: String,
    parameter_set: usize,
    #[serde(flatten)]
    acvp: AcvpIds,
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
    expected_pk: Vec<u8>,
    #[serde(default)]
    expected_sk: Vec<u8>,
    #[serde(default)]
    expected_signature: Vec<u8>,
    /// Absent where the outcome is the answer, as in ACVP sigVer.
    #[serde(default)]
    result: Option<bool>,
    #[serde(default)]
    sign_mode: String,
}

impl MldsaTestCase {
    /// The response fields for this mode.
    fn response_fields(&self, outputs: &MldsaOutputs) -> Fields {
        let mut fields = Fields::new();
        match self.acvp.mode.as_str() {
            "keyGen" => {
                fields.insert("pk".to_string(), json!(hex(&outputs.pk)));
                fields.insert("sk".to_string(), json!(hex(&outputs.sk)));
            }
            "sigGen" => {
                fields.insert("signature".to_string(), json!(hex(&outputs.signature)));
            }
            "sigVer" => {
                fields.insert("testPassed".to_string(), json!(outputs.success));
            }
            other => panic!("Unsupported ACVP ML-DSA mode: {other}"),
        }
        fields
    }
}

// What the device returned; only the operation's own fields are set.
#[derive(Default)]
struct MldsaOutputs {
    success: bool,
    pk: Vec<u8>,
    sk: Vec<u8>,
    signature: Vec<u8>,
}

fn mldsa_sign_mode(sign_mode: &str) -> MldsaSignMode {
    match sign_mode {
        "" | "pure" => MldsaSignMode::Pure,
        "hash_mldsa_sha2_256" => MldsaSignMode::HashMldsaSha2_256,
        "hash_mldsa_sha2_384" => MldsaSignMode::HashMldsaSha2_384,
        "hash_mldsa_sha2_512" => MldsaSignMode::HashMldsaSha2_512,
        "hash_mldsa_sha3_224" => MldsaSignMode::HashMldsaSha3_224,
        "hash_mldsa_sha3_256" => MldsaSignMode::HashMldsaSha3_256,
        "hash_mldsa_sha3_384" => MldsaSignMode::HashMldsaSha3_384,
        "hash_mldsa_sha3_512" => MldsaSignMode::HashMldsaSha3_512,
        "hash_mldsa_shake128" => MldsaSignMode::HashMldsaShake128,
        "hash_mldsa_shake256" => MldsaSignMode::HashMldsaShake256,
        "external_mu" => MldsaSignMode::ExternalMu,
        _ => panic!("Unsupported ML-DSA sign_mode: {}", sign_mode),
    }
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

fn run_mldsa_testcase(
    test_case: &MldsaTestCase,
    opts: &Opts,
    spi_console: &SpiConsoleDevice,
    responses: &mut ResponseBuilder,
) -> Result<()> {
    log::info!(
        "vendor: {}, test case: {}",
        test_case.vendor,
        test_case.test_case_id
    );

    CryptotestCommand::Mldsa.send(spi_console)?;

    let outputs = match test_case.operation.as_str() {
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
            let out = CryptotestMldsaKeygenOutput::recv(spi_console, opts.timeout, false, false)?;
            MldsaOutputs {
                success: out.success,
                pk: out.pk.to_vec(),
                sk: out.sk.to_vec(),
                ..Default::default()
            }
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
                sign_mode: mldsa_sign_mode(&test_case.sign_mode),
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
            let out =
                CryptotestMldsaKeygenSignOutput::recv(spi_console, opts.timeout, false, false)?;
            MldsaOutputs {
                success: out.success,
                pk: out.pk.to_vec(),
                signature: out.signature.to_vec(),
                ..Default::default()
            }
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
                sign_mode: mldsa_sign_mode(&test_case.sign_mode),
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
            let out = CryptotestMldsaSiggenOutput::recv(spi_console, opts.timeout, false, false)?;
            MldsaOutputs {
                success: out.success,
                signature: out.signature.to_vec(),
                ..Default::default()
            }
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
                sign_mode: mldsa_sign_mode(&test_case.sign_mode),
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
            let out = CryptotestMldsaSigverOutput::recv(spi_console, opts.timeout, false, false)?;
            MldsaOutputs {
                success: out.success,
                ..Default::default()
            }
        }
        _ => panic!("Unsupported ML-DSA operation: {}", test_case.operation),
    };

    if let Some(want) = test_case.result {
        assert_eq!(
            outputs.success, want,
            "test #{}: expected success={}, got={}",
            test_case.test_case_id, want, outputs.success
        );
    }

    if test_case.result == Some(true) {
        let id = test_case.test_case_id;
        check_output("pk", id, &outputs.pk, &test_case.expected_pk);
        check_output("sk", id, &outputs.sk, &test_case.expected_sk);
        check_output(
            "signature",
            id,
            &outputs.signature,
            &test_case.expected_signature,
        );
    }

    if test_case.vendor == "acvp" {
        let fields = test_case.response_fields(&outputs);
        responses.add(&test_case.acvp, test_case.test_case_id, fields);
    }

    Ok(())
}

fn test_mldsa(opts: &Opts, transport: &TransportWrapper) -> Result<()> {
    let spi = transport.spi("BOOTSTRAP")?;
    let spi_console_device = SpiConsoleDevice::new(&*spi, None, /*ignore_frame_num=*/ false)?;
    let _ = UartConsole::wait_for(&spi_console_device, r"Running [^\r\n]*", opts.timeout)?;

    let cases: Vec<MldsaTestCase> = read_vectors(opts.acvp.vectors(&opts.mldsa_json))?;

    let mut responses = ResponseBuilder::new();
    for (counter, case) in cases.iter().enumerate() {
        log::info!("Test counter: {}", counter + 1);
        run_mldsa_testcase(case, opts, &spi_console_device, &mut responses)?;
    }
    responses.finish(&opts.acvp)
}

fn main() -> Result<()> {
    let opts = Opts::parse();
    opts.init.init_logging();

    let transport = opts.init.init_target()?;
    execute_test!(test_mldsa, &opts, &transport);
    Ok(())
}
