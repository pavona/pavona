// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

use anyhow::Result;
use arrayvec::ArrayVec;
use clap::Parser;
use num_bigint_dig::BigInt;
use num_traits::Num;
use p256::U256;
use p256::ecdsa::signature::hazmat::PrehashVerifier;
use p256::elliptic_curve::scalar::ScalarPrimitive as ScalarPrimitiveP256;
use p384::U384;
use p384::elliptic_curve::scalar::ScalarPrimitive as ScalarPrimitiveP384;
use serde::Deserialize;
use serde_json::json;
use sha2::digest::generic_array::GenericArray;
use sha2::{Digest, Sha256, Sha384, Sha512};
use std::time::Duration;

use cryptotest_acvp::{AcvpIds, AcvpOpts, Fields, ResponseBuilder, hex, read_vectors};
use cryptotest_commands::commands::CryptotestCommand;
use cryptotest_commands::ecdsa_commands::{
    CryptotestEcdsaCoordinate, CryptotestEcdsaCurve, CryptotestEcdsaHashAlg,
    CryptotestEcdsaMessage, CryptotestEcdsaOperation, CryptotestEcdsaPrivateKey,
    CryptotestEcdsaSignature, CryptotestEcdsaVerifyOutput,
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
    ecdsa_json: Vec<String>,

    #[command(flatten)]
    acvp: AcvpOpts,
}

fn scalar_zero() -> String {
    String::from("00")
}

#[derive(Debug, Deserialize)]
struct EcdsaTestCase {
    vendor: String,
    test_case_id: u64,
    #[serde(flatten)]
    acvp: AcvpIds,
    operation: String,
    curve: String,
    hash_alg: String,
    message: Vec<u8>,
    #[serde(default = "scalar_zero")]
    qx: String,
    #[serde(default = "scalar_zero")]
    qy: String,
    #[serde(default = "scalar_zero")]
    r: String,
    #[serde(default = "scalar_zero")]
    s: String,
    #[serde(default = "scalar_zero")]
    d: String,
    result: bool,
}

#[derive(Default)]
struct EcdsaOutputs {
    success: bool,
    r: Vec<u8>,
    s: Vec<u8>,
}

const ECDSA_CMD_MAX_SIGNATURE_SCALAR_BYTES_P256: usize = 32;
const ECDSA_CMD_MAX_COORDINATE_BYTES_P256: usize = 32;
const ECDSA_CMD_MAX_SIGNATURE_SCALAR_BYTES_P384: usize = 48;
const ECDSA_CMD_MAX_COORDINATE_BYTES_P384: usize = 48;

// These values were generated randomly for testing purposes.
// Each value must be less than the modulus for its respective curve.
const RANDOM_MASK_P256: &str = "9665cc1c4e9e15354e3fc319ca7de255f2122dc3c16da15e6a83ce1d7a912df0";
const RANDOM_MASK_P384: &str = "e183091e94141f38b570747cec9e2f11da33a9ec7dbcb71187953db7b4e4e3358b020247f2fbcbcb4bf004d2e815f176";

fn p256_verify_signature(
    message: &[u8],
    qx: &mut Vec<u8>,
    qy: &mut Vec<u8>,
    r: &[u8],
    s: &[u8],
) -> bool {
    // Convert qx and qy to big-endian (resize to full length beforehand in case there are leading
    // zero(es))
    qx.resize(ECDSA_CMD_MAX_COORDINATE_BYTES_P256, 0u8);
    qy.resize(ECDSA_CMD_MAX_COORDINATE_BYTES_P256, 0u8);
    qx.reverse();
    qy.reverse();
    // Zero-fill the remaining space for the public key parameters, because
    // p256 requires an exact size
    // Verify the signature with the public key
    p256::ecdsa::VerifyingKey::from_encoded_point(&p256::EncodedPoint::from_affine_coordinates(
        &GenericArray::from(
            <[u8; ECDSA_CMD_MAX_COORDINATE_BYTES_P256]>::try_from(qx.as_slice()).unwrap(),
        ),
        &GenericArray::from(
            <[u8; ECDSA_CMD_MAX_COORDINATE_BYTES_P256]>::try_from(qy.as_slice()).unwrap(),
        ),
        // Don't compress the public key (purely for speed, since we only use
        // it internally)
        false,
    ))
    .expect("Qx and Qy did not form a valid public key")
    .verify_prehash(
        message,
        &p256::ecdsa::Signature::from_scalars(
            GenericArray::from(
                <[u8; ECDSA_CMD_MAX_SIGNATURE_SCALAR_BYTES_P256]>::try_from(r).unwrap(),
            ),
            GenericArray::from(
                <[u8; ECDSA_CMD_MAX_SIGNATURE_SCALAR_BYTES_P256]>::try_from(s).unwrap(),
            ),
        )
        .expect("Invalid signature format"),
    )
    .is_ok()
}

fn p384_verify_signature(
    message: &[u8],
    qx: &mut Vec<u8>,
    qy: &mut Vec<u8>,
    r: &[u8],
    s: &[u8],
) -> bool {
    // Convert qx and qy to big-endian (resize to full length beforehand in case there are leading
    // zero(es))
    qx.resize(ECDSA_CMD_MAX_COORDINATE_BYTES_P384, 0u8);
    qy.resize(ECDSA_CMD_MAX_COORDINATE_BYTES_P384, 0u8);
    qx.reverse();
    qy.reverse();
    // Zero-fill the remaining space for the public key parameters, because
    // p384 requires an exact size
    // Verify the signature with the public key
    p384::ecdsa::VerifyingKey::from_encoded_point(&p384::EncodedPoint::from_affine_coordinates(
        &GenericArray::from(
            <[u8; ECDSA_CMD_MAX_COORDINATE_BYTES_P384]>::try_from(qx.as_slice()).unwrap(),
        ),
        &GenericArray::from(
            <[u8; ECDSA_CMD_MAX_COORDINATE_BYTES_P384]>::try_from(qy.as_slice()).unwrap(),
        ),
        // Don't compress the public key (purely for speed, since we only use
        // it internally)
        false,
    ))
    .expect("Qx and Qy did not form a valid public key")
    .verify_prehash(
        message,
        &p384::ecdsa::Signature::from_scalars(
            GenericArray::from(
                <[u8; ECDSA_CMD_MAX_SIGNATURE_SCALAR_BYTES_P384]>::try_from(r).unwrap(),
            ),
            GenericArray::from(
                <[u8; ECDSA_CMD_MAX_SIGNATURE_SCALAR_BYTES_P384]>::try_from(s).unwrap(),
            ),
        )
        .expect("Invalid signature format"),
    )
    .is_ok()
}

fn run_ecdsa_testcase(
    test_case: &EcdsaTestCase,
    opts: &Opts,
    spi_console: &SpiConsoleDevice,
    failures: &mut Vec<String>,
    responses: &mut ResponseBuilder,
) -> Result<()> {
    log::info!(
        "vendor: {}, test case: {}",
        test_case.vendor,
        test_case.test_case_id
    );
    let mut qx: Vec<u8> = BigInt::from_str_radix(&test_case.qx, 16)
        .unwrap()
        .to_bytes_le()
        .1;
    let mut qy: Vec<u8> = BigInt::from_str_radix(&test_case.qy, 16)
        .unwrap()
        .to_bytes_le()
        .1;
    let r: Vec<u8> = BigInt::from_str_radix(&test_case.r, 16)
        .unwrap()
        .to_bytes_le()
        .1;
    let s: Vec<u8> = BigInt::from_str_radix(&test_case.s, 16)
        .unwrap()
        .to_bytes_le()
        .1;

    // Get the hash function and hash the message to get the digest (unfortunately this code is
    // challenging to deduplicate because the `Digest` trait is not object safe).
    let (hash_alg, message_digest): (CryptotestEcdsaHashAlg, Vec<u8>) =
        match test_case.hash_alg.as_str() {
            "sha-256" => {
                let mut hasher = Sha256::new();
                hasher.update(test_case.message.as_slice());
                (CryptotestEcdsaHashAlg::Sha256, hasher.finalize().to_vec())
            }
            "sha-384" => {
                let mut hasher = Sha384::new();
                hasher.update(test_case.message.as_slice());
                (CryptotestEcdsaHashAlg::Sha384, hasher.finalize().to_vec())
            }
            "sha-512" => {
                let mut hasher = Sha512::new();
                hasher.update(test_case.message.as_slice());
                (CryptotestEcdsaHashAlg::Sha512, hasher.finalize().to_vec())
            }
            "sha3-256" => {
                let mut hasher = sha3::Sha3_256::new();
                hasher.update(test_case.message.as_slice());
                (CryptotestEcdsaHashAlg::Sha3_256, hasher.finalize().to_vec())
            }
            "sha3-384" => {
                let mut hasher = sha3::Sha3_384::new();
                hasher.update(test_case.message.as_slice());
                (CryptotestEcdsaHashAlg::Sha3_384, hasher.finalize().to_vec())
            }
            "sha3-512" => {
                let mut hasher = sha3::Sha3_512::new();
                hasher.update(test_case.message.as_slice());
                (CryptotestEcdsaHashAlg::Sha3_512, hasher.finalize().to_vec())
            }
            _ => panic!("Invalid ECDSA hash mode"),
        };

    // Determine the curve and check the lengths of the other arguments based on the curve choice.
    // Depending on our choice of curve, calculate the two components of the masked private key.
    let (operation, curve, d0, d1) = match test_case.curve.as_str() {
        "p256" => {
            assert!(
                qx.len() <= ECDSA_CMD_MAX_COORDINATE_BYTES_P256,
                "ECDSA qx value was too long for curve p256 (got: {}, max: {})",
                qx.len(),
                ECDSA_CMD_MAX_COORDINATE_BYTES_P256,
            );
            assert!(
                qy.len() <= ECDSA_CMD_MAX_COORDINATE_BYTES_P256,
                "ECDSA qy value was too long for curve p256 (got: {}, max: {})",
                qy.len(),
                ECDSA_CMD_MAX_COORDINATE_BYTES_P256,
            );
            assert!(
                r.len() <= ECDSA_CMD_MAX_SIGNATURE_SCALAR_BYTES_P256,
                "ECDSA signature value r was too long for curve p256 (got: {}, max: {})",
                r.len(),
                ECDSA_CMD_MAX_SIGNATURE_SCALAR_BYTES_P256,
            );
            assert!(
                s.len() <= ECDSA_CMD_MAX_SIGNATURE_SCALAR_BYTES_P256,
                "ECDSA signature value s was too long for curve p256 (got: {}, max: {})",
                s.len(),
                ECDSA_CMD_MAX_SIGNATURE_SCALAR_BYTES_P256,
            );
            let (operation, d0, d1) = match test_case.operation.as_str() {
                "siggen" => {
                    // Calculate masked private key

                    // Pad private key `d` to 32 bytes
                    let mut padded_d = String::with_capacity(64);
                    for _ in 0..(64 - test_case.d.len()) {
                        padded_d.push('0');
                    }
                    padded_d.push_str(&test_case.d);
                    let d = p256::Scalar::from(
                        ScalarPrimitiveP256::new(U256::from_be_hex(&padded_d)).unwrap(),
                    );
                    let d0 = p256::Scalar::from(
                        ScalarPrimitiveP256::new(U256::from_be_hex(RANDOM_MASK_P256)).unwrap(),
                    );
                    // Automatically performs subtraction modulo the order (modulus) of P-256
                    let d1 = d - d0;
                    // Get big-endian encodings
                    let mut d0_bytes = d0.to_bytes();
                    let mut d1_bytes = d1.to_bytes();
                    // Reverse to get little-endian encodings
                    d0_bytes.reverse();
                    d1_bytes.reverse();
                    (
                        CryptotestEcdsaOperation::Sign,
                        d0_bytes.to_vec(),
                        d1_bytes.to_vec(),
                    )
                }
                "sigver" => (CryptotestEcdsaOperation::Verify, vec![], vec![]),
                _ => panic!("Unsupported ECDSA operation: {}", test_case.operation),
            };
            (operation, CryptotestEcdsaCurve::P256, d0, d1)
        }
        "p384" => {
            assert!(
                qx.len() <= ECDSA_CMD_MAX_COORDINATE_BYTES_P384,
                "ECDSA qx value was too long for curve p384 (got: {}, max: {})",
                qx.len(),
                ECDSA_CMD_MAX_COORDINATE_BYTES_P384,
            );
            assert!(
                qy.len() <= ECDSA_CMD_MAX_COORDINATE_BYTES_P384,
                "ECDSA qy value was too long for curve p384 (got: {}, max: {})",
                qy.len(),
                ECDSA_CMD_MAX_COORDINATE_BYTES_P384,
            );
            assert!(
                r.len() <= ECDSA_CMD_MAX_SIGNATURE_SCALAR_BYTES_P384,
                "ECDSA signature value r was too long for curve p384 (got: {}, max: {})",
                r.len(),
                ECDSA_CMD_MAX_SIGNATURE_SCALAR_BYTES_P384,
            );
            assert!(
                s.len() <= ECDSA_CMD_MAX_SIGNATURE_SCALAR_BYTES_P384,
                "ECDSA signature value s was too long for curve p384 (got: {}, max: {})",
                s.len(),
                ECDSA_CMD_MAX_SIGNATURE_SCALAR_BYTES_P384,
            );
            let (operation, d0, d1) = match test_case.operation.as_str() {
                "siggen" => {
                    // Calculate masked private key

                    // Pad private key `d` to 48 bytes
                    let mut padded_d = String::with_capacity(96);
                    for _ in 0..(96 - test_case.d.len()) {
                        padded_d.push('0');
                    }
                    padded_d.push_str(&test_case.d);
                    let d = p384::Scalar::from(
                        ScalarPrimitiveP384::new(U384::from_be_hex(&padded_d)).unwrap(),
                    );
                    let d0 = p384::Scalar::from(
                        ScalarPrimitiveP384::new(U384::from_be_hex(RANDOM_MASK_P384)).unwrap(),
                    );
                    // Automatically performs subtraction modulo the order (modulus) of P-384
                    let d1 = d - d0;
                    // Get big-endian encodings
                    let mut d0_bytes = d0.to_bytes();
                    let mut d1_bytes = d1.to_bytes();
                    // Reverse to get little-endian encodings
                    d0_bytes.reverse();
                    d1_bytes.reverse();
                    (
                        CryptotestEcdsaOperation::Sign,
                        d0_bytes.to_vec(),
                        d1_bytes.to_vec(),
                    )
                }
                "sigver" => (CryptotestEcdsaOperation::Verify, vec![], vec![]),
                _ => panic!("Unsupported ECDSA operation: {}", test_case.operation),
            };
            (operation, CryptotestEcdsaCurve::P384, d0, d1)
        }
        _ => panic!("Invalid ECDSA curve name"),
    };

    // Send everything
    CryptotestCommand::Ecdsa.send(spi_console)?;
    operation.send(spi_console)?;
    hash_alg.send(spi_console)?;
    curve.send(spi_console)?;

    // Size of `input` is determined at compile-time by type inference
    let mut input = ArrayVec::new();
    // Fill the buffer until we run out of bytes, truncating the rightmost bytes if we have too
    // many
    let msg_len = message_digest.len();
    let mut message_digest_iter = message_digest.iter();
    while !input.is_full() {
        input.push(*message_digest_iter.next().unwrap_or(&0u8));
    }
    // `unwrap()` operations are safe here because we checked the sizes above.
    let msg = CryptotestEcdsaMessage {
        input,
        input_len: msg_len,
    };
    msg.send(spi_console)?;

    CryptotestEcdsaSignature {
        r: ArrayVec::try_from(r.as_slice()).unwrap(),
        r_len: r.len(),
        s: ArrayVec::try_from(s.as_slice()).unwrap(),
        s_len: s.len(),
    }
    .send(spi_console)?;

    CryptotestEcdsaCoordinate {
        coordinate: ArrayVec::try_from(qx.as_slice()).unwrap(),
        coordinate_len: qx.len(),
    }
    .send(spi_console)?;

    CryptotestEcdsaCoordinate {
        coordinate: ArrayVec::try_from(qy.as_slice()).unwrap(),
        coordinate_len: qy.len(),
    }
    .send(spi_console)?;

    CryptotestEcdsaPrivateKey {
        d0: ArrayVec::try_from(d0.as_slice()).unwrap(),
        d0_len: d0.len(),
        d1: ArrayVec::try_from(d1.as_slice()).unwrap(),
        d1_len: d1.len(),
        unmasked_len: d0.len(),
    }
    .send(spi_console)?;

    let outputs = match operation {
        CryptotestEcdsaOperation::Sign => {
            let mut output_signature =
                CryptotestEcdsaSignature::recv(spi_console, opts.timeout, false, false)?;
            // Truncate signature values to correct size for curve and convert to big-endian
            output_signature.r.truncate(output_signature.r_len);
            output_signature.s.truncate(output_signature.s_len);
            output_signature.r.reverse();
            output_signature.s.reverse();
            EcdsaOutputs {
                r: output_signature.r.to_vec(),
                s: output_signature.s.to_vec(),
                ..Default::default()
            }
        }
        CryptotestEcdsaOperation::Verify => {
            let ecdsa_output =
                CryptotestEcdsaVerifyOutput::recv(spi_console, opts.timeout, false, false)?;
            let success = match ecdsa_output {
                CryptotestEcdsaVerifyOutput::Success => true,
                CryptotestEcdsaVerifyOutput::Failure => false,
                CryptotestEcdsaVerifyOutput::IntValue(i) => {
                    panic!("Invalid ECDSA verify result: {}", i)
                }
            };
            EcdsaOutputs {
                success,
                ..Default::default()
            }
        }
        CryptotestEcdsaOperation::IntValue(_) => {
            unreachable!("Should be caught above")
        }
    };

    let success = match operation {
        CryptotestEcdsaOperation::Sign => match test_case.curve.as_str() {
            "p256" => {
                p256_verify_signature(&message_digest, &mut qx, &mut qy, &outputs.r, &outputs.s)
            }
            "p384" => {
                p384_verify_signature(&message_digest, &mut qx, &mut qy, &outputs.r, &outputs.s)
            }
            &_ => panic!("Unsupported ECC curve"),
        },
        CryptotestEcdsaOperation::Verify => outputs.success,
        CryptotestEcdsaOperation::IntValue(_) => {
            unreachable!("Should be caught above")
        }
    };
    if test_case.result != success {
        log::info!(
            "FAILED test #{}: expected = {}, actual = {}",
            test_case.test_case_id,
            test_case.result,
            success
        );
        failures.push(format!(
            "{} {} {} {} #{}",
            test_case.vendor,
            test_case.curve,
            test_case.operation,
            test_case.hash_alg,
            test_case.test_case_id
        ));
    }

    if test_case.vendor == "acvp" {
        let mut fields = Fields::new();
        match operation {
            CryptotestEcdsaOperation::Sign => {
                fields.insert("r".to_string(), json!(hex(&outputs.r)));
                fields.insert("s".to_string(), json!(hex(&outputs.s)));
            }
            CryptotestEcdsaOperation::Verify => {
                fields.insert("testPassed".to_string(), json!(&outputs.success));
            }
            CryptotestEcdsaOperation::IntValue(_) => {
                unreachable!("Should be caught above")
            }
        }
        responses.add(&test_case.acvp, test_case.test_case_id, fields);
    }

    Ok(())
}

fn test_ecdsa(opts: &Opts, transport: &TransportWrapper) -> Result<()> {
    let spi = transport.spi("BOOTSTRAP")?;
    let spi_console_device = SpiConsoleDevice::new(&*spi, None, /*ignore_frame_num=*/ false)?;
    let _ = UartConsole::wait_for(&spi_console_device, r"Running ", opts.timeout)?;

    let cases: Vec<EcdsaTestCase> = read_vectors(opts.acvp.vectors(&opts.ecdsa_json))?;
    let mut failures = vec![];
    let mut responses = ResponseBuilder::new();
    for (counter, case) in cases.iter().enumerate() {
        log::info!("Test counter: {}", counter + 1);
        run_ecdsa_testcase(
            case,
            opts,
            &spi_console_device,
            &mut failures,
            &mut responses,
        )?;
    }
    assert_eq!(
        0,
        failures.len(),
        "Failed {} out of {} tests. Failures: {:?}",
        failures.len(),
        cases.len(),
        failures
    );
    responses.finish(&opts.acvp)
}

fn main() -> Result<()> {
    let opts = Opts::parse();
    opts.init.init_logging();

    let transport = opts.init.init_target()?;
    execute_test!(test_ecdsa, &opts, &transport);
    Ok(())
}
