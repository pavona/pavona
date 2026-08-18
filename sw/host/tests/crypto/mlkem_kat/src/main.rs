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

    #[command(flatten)]
    acvp: AcvpOpts,
}

#[derive(Debug, Deserialize)]
struct MlkemTestCase {
    vendor: String,
    test_case_id: u64,
    operation: String,
    parameter_set: usize,
    #[serde(flatten)]
    acvp: AcvpIds,
    /// The group's encapDecap function, which selects the response shape.
    #[serde(default)]
    function: String,
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
    /// Absent where the outcome is the answer, as in the ACVP key checks.
    #[serde(default)]
    result: Option<bool>,
}

impl MlkemTestCase {
    /// The response fields for this mode; in encapDecap the group's function selects the shape.
    fn response_fields(&self, outputs: &MlkemOutputs) -> Fields {
        let mut fields = Fields::new();
        match (self.acvp.mode.as_str(), self.function.as_str()) {
            ("keyGen", _) => {
                fields.insert("ek".to_string(), json!(hex(&outputs.ek)));
                fields.insert("dk".to_string(), json!(hex(&outputs.dk)));
            }
            ("encapDecap", "encapsulation") => {
                fields.insert("c".to_string(), json!(hex(&outputs.c)));
                fields.insert("k".to_string(), json!(hex(&outputs.k)));
            }
            ("encapDecap", "decapsulation") => {
                fields.insert("k".to_string(), json!(hex(&outputs.k)));
            }
            ("encapDecap", "encapsulationKeyCheck" | "decapsulationKeyCheck") => {
                fields.insert("testPassed".to_string(), json!(outputs.success));
            }
            (mode, function) => {
                panic!("Unsupported ACVP ML-KEM mode/function: {mode}/{function}")
            }
        }
        fields
    }
}

// What the device returned; only the operation's own fields are set.
#[derive(Default)]
struct MlkemOutputs {
    success: bool,
    ek: Vec<u8>,
    dk: Vec<u8>,
    c: Vec<u8>,
    k: Vec<u8>,
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
    responses: &mut ResponseBuilder,
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
                ek: out.ek.to_vec(),
                dk: out.dk.to_vec(),
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
                ek: out.ek.to_vec(),
                k: out.k.to_vec(),
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
                c: out.c.to_vec(),
                k: out.k.to_vec(),
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
                k: out.k.to_vec(),
                ..Default::default()
            }
        }
        _ => panic!("Unsupported ML-KEM operation: {}", test_case.operation),
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
        check_output("ek", id, &outputs.ek, &test_case.expected_ek);
        check_output("dk", id, &outputs.dk, &test_case.expected_dk);
        check_output("c", id, &outputs.c, &test_case.expected_c);
        check_output("k", id, &outputs.k, &test_case.expected_k);
    }

    if test_case.vendor == "acvp" {
        let fields = test_case.response_fields(&outputs);
        responses.add(&test_case.acvp, test_case.test_case_id, fields);
    }

    Ok(())
}

fn test_mlkem(opts: &Opts, transport: &TransportWrapper) -> Result<()> {
    let spi = transport.spi("BOOTSTRAP")?;
    let spi_console_device = SpiConsoleDevice::new(&*spi, None, /*ignore_frame_num=*/ false)?;
    let _ = UartConsole::wait_for(&spi_console_device, r"Running [^\r\n]*", opts.timeout)?;

    let cases: Vec<MlkemTestCase> = read_vectors(opts.acvp.vectors(&opts.mlkem_json))?;

    let mut responses = ResponseBuilder::new();
    for (counter, case) in cases.iter().enumerate() {
        log::info!("Test counter: {}", counter + 1);
        run_mlkem_testcase(case, opts, &spi_console_device, &mut responses)?;
    }
    responses.finish(&opts.acvp)
}

fn main() -> Result<()> {
    let opts = Opts::parse();
    opts.init.init_logging();

    let transport = opts.init.init_target()?;
    execute_test!(test_mlkem, &opts, &transport);
    Ok(())
}
