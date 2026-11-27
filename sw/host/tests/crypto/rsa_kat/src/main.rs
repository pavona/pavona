// Copyright lowRISC contributors.
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

use anyhow::{Error, Result};
use arrayvec::ArrayVec;
use clap::Parser;
use num_bigint_dig::prime::probably_prime;
use num_bigint_dig::{BigInt, BigUint};
use serde::Deserialize;
use serde_json::json;
use sha2::{Digest as Sha2Digest, Sha256, Sha384, Sha512};
use sha3::{
    Sha3_224, Sha3_256, Sha3_384, Sha3_512, Shake128, Shake256,
    digest::{ExtendableOutput, Update as Sha3Update},
};
use std::collections::HashMap;
use std::fs;
use std::io::Read;
use std::time::Duration;

use cryptotest_acvp::{AcvpIds, AcvpOpts, Fields, ResponseBuilder, hex};
use cryptotest_commands::commands::CryptotestCommand;
use cryptotest_commands::rsa_commands::{
    CryptotestRsaCiphertext, CryptotestRsaDecryptOutput, CryptotestRsaExpectedLength,
    CryptotestRsaHashAlg, CryptotestRsaLabel, CryptotestRsaMessage, CryptotestRsaOperation,
    CryptotestRsaPadding, CryptotestRsaPrivateKey, CryptotestRsaPublicKey, CryptotestRsaRawMessage,
    CryptotestRsaSecurityLevel, CryptotestRsaSignature, CryptotestRsaVerifyOutput,
};
use rsa::{Oaep, Pkcs1v15Sign, Pss, RsaPrivateKey, RsaPublicKey};

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
    rsa_json: Vec<String>,

    #[command(flatten)]
    acvp: AcvpOpts,
}

#[derive(Debug, Deserialize)]
struct RsaTestCase {
    vendor: String,
    test_case_id: usize,
    #[serde(flatten)]
    acvp: AcvpIds,
    operation: String,
    padding: String,
    security_level: usize,
    #[serde(default)]
    hash_alg: String,
    #[serde(default)]
    message: Vec<u8>,
    #[serde(default)]
    label: Vec<u8>,
    #[serde(default)]
    n: Vec<u8>,
    #[serde(default)]
    p: Vec<u8>,
    #[serde(default)]
    q: Vec<u8>,
    #[serde(default)]
    e: u32,
    #[serde(default)]
    d: Vec<u8>,
    #[serde(default)]
    d_p: Vec<u8>,
    #[serde(default)]
    d_q: Vec<u8>,
    #[serde(default)]
    i_q: Vec<u8>,
    #[serde(default)]
    signature: Vec<u8>,
    #[serde(default)]
    ciphertext: Vec<u8>,
    /// Absent where the outcome is the answer, as in an ACVP prompt.
    #[serde(default)]
    result: Option<bool>,
}

/// Verifies a signature from the device with the `rsa` crate.
fn signature_is_valid(
    padding: &CryptotestRsaPadding,
    hash_alg: &CryptotestRsaHashAlg,
    n: BigUint,
    e: u32,
    digest: &[u8],
    signature: &[u8],
) -> bool {
    let public = RsaPublicKey::new(n, BigUint::from(e)).expect("Invalid public key");
    match padding {
        CryptotestRsaPadding::Pkcs15 => {
            let scheme = match hash_alg {
                CryptotestRsaHashAlg::Sha256 => Pkcs1v15Sign::new::<sha2::Sha256>(),
                CryptotestRsaHashAlg::Sha384 => Pkcs1v15Sign::new::<sha2::Sha384>(),
                CryptotestRsaHashAlg::Sha512 => Pkcs1v15Sign::new::<sha2::Sha512>(),
                CryptotestRsaHashAlg::Sha3_224 => Pkcs1v15Sign::new::<sha3::Sha3_224>(),
                CryptotestRsaHashAlg::Sha3_256 => Pkcs1v15Sign::new::<sha3::Sha3_256>(),
                CryptotestRsaHashAlg::Sha3_384 => Pkcs1v15Sign::new::<sha3::Sha3_384>(),
                CryptotestRsaHashAlg::Sha3_512 => Pkcs1v15Sign::new::<sha3::Sha3_512>(),
                _ => panic!("SHAKE-based hashes are currently unsupported."),
            };
            public.verify(scheme, digest, signature)
        }
        CryptotestRsaPadding::Pss => {
            let scheme = match hash_alg {
                CryptotestRsaHashAlg::Sha256 => Pss::new::<sha2::Sha256>(),
                CryptotestRsaHashAlg::Sha384 => Pss::new::<sha2::Sha384>(),
                CryptotestRsaHashAlg::Sha512 => Pss::new::<sha2::Sha512>(),
                CryptotestRsaHashAlg::Sha3_224 => Pss::new::<sha3::Sha3_224>(),
                CryptotestRsaHashAlg::Sha3_256 => Pss::new::<sha3::Sha3_256>(),
                CryptotestRsaHashAlg::Sha3_384 => Pss::new::<sha3::Sha3_384>(),
                CryptotestRsaHashAlg::Sha3_512 => Pss::new::<sha3::Sha3_512>(),
                _ => panic!("SHAKE-based hashes are currently unsupported"),
            };
            public.verify(scheme, digest, signature)
        }
        _ => panic!("Unsupported padding scheme for sign/verify operations"),
    }
    .is_ok()
}

fn padding_mode(padding: &str) -> CryptotestRsaPadding {
    match padding {
        "oaep" => CryptotestRsaPadding::Oaep,
        "pkcs1_1.5" => CryptotestRsaPadding::Pkcs15,
        "pss" => CryptotestRsaPadding::Pss,
        _ => panic!("Unsupported RSA padding mode"),
    }
}

fn security_level(bits: usize) -> CryptotestRsaSecurityLevel {
    match bits {
        2048 => CryptotestRsaSecurityLevel::Rsa2048,
        3072 => CryptotestRsaSecurityLevel::Rsa3072,
        4096 => CryptotestRsaSecurityLevel::Rsa4096,
        _ => panic!("Unsupported RSA security level"),
    }
}

/// Generates a key on the device for the size and padding of a test case.
fn generate_key(
    test_case: &RsaTestCase,
    opts: &Opts,
    spi_console: &SpiConsoleDevice,
) -> Result<CryptotestRsaPrivateKey> {
    CryptotestCommand::Rsa.send(spi_console)?;
    CryptotestRsaOperation::Keygen.send(spi_console)?;
    padding_mode(&test_case.padding).send(spi_console)?;
    security_level(test_case.security_level).send(spi_console)?;
    CryptotestRsaPrivateKey::recv(spi_console, opts.timeout, false, false)
}

/// Builds the device private key from the test case parameters.
fn test_case_key(test_case: &RsaTestCase) -> CryptotestRsaPrivateKey {
    // Convert parameters to unsigned little-endian
    let le = |x: &[u8]| BigInt::from_signed_bytes_be(x).to_bytes_le().1;
    let n = le(&test_case.n);
    let p = le(&test_case.p);
    let q = le(&test_case.q);
    let d = le(&test_case.d);
    let d_p = le(&test_case.d_p);
    let d_q = le(&test_case.d_q);
    let i_q = le(&test_case.i_q);
    CryptotestRsaPrivateKey {
        n: ArrayVec::try_from(n.as_slice())
            .expect("RSA parameter n too long for device firmware configuration."),
        n_len: n.len(),
        p: ArrayVec::try_from(p.as_slice())
            .expect("RSA parameter p too long for device firmware configuration."),
        p_len: p.len(),
        q: ArrayVec::try_from(q.as_slice())
            .expect("RSA parameter q too long for device firmware configuration."),
        q_len: q.len(),
        d: ArrayVec::try_from(d.as_slice())
            .expect("RSA parameter d too long for device firmware configuration."),
        d_len: d.len(),
        d_p: ArrayVec::try_from(d_p.as_slice())
            .expect("RSA parameter d_p too long for device firmware configuration."),
        d_p_len: d_p.len(),
        d_q: ArrayVec::try_from(d_q.as_slice())
            .expect("RSA parameter d_q too long for device firmware configuration."),
        d_q_len: d_q.len(),
        i_q: ArrayVec::try_from(i_q.as_slice())
            .expect("RSA parameter i_q too long for device firmware configuration."),
        i_q_len: i_q.len(),
        e: test_case.e,
    }
}

fn run_rsa_keygen(
    test_case: &RsaTestCase,
    opts: &Opts,
    spi_console: &SpiConsoleDevice,
    failures: &mut Vec<String>,
    responses: &mut ResponseBuilder,
) -> Result<()> {
    let key = generate_key(test_case, opts, spi_console)?;
    let n = BigUint::from_bytes_le(&key.n[..key.n_len]);
    let p = BigUint::from_bytes_le(&key.p[..key.p_len]);
    let q = BigUint::from_bytes_le(&key.q[..key.q_len]);
    let d_p = BigUint::from_bytes_le(&key.d_p[..key.d_p_len]);
    let d_q = BigUint::from_bytes_le(&key.d_q[..key.d_q_len]);
    let i_q = BigUint::from_bytes_le(&key.i_q[..key.i_q_len]);
    // Check the key the way the ACVP server checks keyGen responses.
    let bits = test_case.security_level;
    let one = BigUint::from(1u32);
    let e = BigUint::from(key.e);
    let prime_is_valid =
        |f: &BigUint| f.bits() == bits / 2 && f * f > (&one << (bits - 1)) && probably_prime(f, 20);
    let distance = if p > q { &p - &q } else { &q - &p };
    let valid = key.e == 65537
        && n.bits() == bits
        && n == &p * &q
        && prime_is_valid(&p)
        && prime_is_valid(&q)
        && distance > (&one << (bits / 2 - 100))
        && (&e * &d_p) % (&p - &one) == one
        && (&e * &d_q) % (&q - &one) == one
        && (&q * &i_q) % &p == one;
    if !valid {
        log::info!("FAILED test #{}: invalid key", test_case.test_case_id);
        failures.push(format!(
            "{} RSA-{} keygen #{}",
            test_case.vendor, test_case.security_level, test_case.test_case_id
        ));
    }
    if test_case.vendor == "acvp" {
        let mut fields = Fields::new();
        for (name, value) in [
            ("n", &n),
            ("p", &p),
            ("q", &q),
            ("dmp1", &d_p),
            ("dmq1", &d_q),
            ("iqmp", &i_q),
        ] {
            fields.insert(name.to_string(), json!(hex(&value.to_bytes_be())));
        }
        responses.add(&test_case.acvp, test_case.test_case_id as u64, fields);
    }
    Ok(())
}

fn run_rsa_testcase(
    test_case: &RsaTestCase,
    opts: &Opts,
    spi_console: &SpiConsoleDevice,
    failures: &mut Vec<String>,
    responses: &mut ResponseBuilder,
    keys: &mut HashMap<(usize, String), CryptotestRsaPrivateKey>,
) -> Result<()> {
    log::info!(
        "vendor: {}, test case: {}",
        test_case.vendor,
        test_case.test_case_id
    );
    if test_case.operation == "keygen" {
        return run_rsa_keygen(test_case, opts, spi_console, failures, responses);
    }
    // sigGen signs with one generated key per size and padding.
    let key_id = (test_case.security_level, test_case.padding.clone());
    if test_case.operation == "keygen_sign" && !keys.contains_key(&key_id) {
        keys.insert(key_id.clone(), generate_key(test_case, opts, spi_console)?);
    }
    // Send algorithm name
    CryptotestCommand::Rsa.send(spi_console)?;

    // Send RSA operation
    let operation = match test_case.operation.as_str() {
        "sign" => CryptotestRsaOperation::Sign,
        "verify" => CryptotestRsaOperation::Verify,
        "encrypt" => CryptotestRsaOperation::Encrypt,
        "decrypt" => CryptotestRsaOperation::Decrypt,
        "keygen_sign" => CryptotestRsaOperation::Sign,
        _ => panic!("Unsupported RSA operation"),
    };
    operation.send(spi_console)?;

    // Send padding mode
    let padding = padding_mode(&test_case.padding);
    padding.send(spi_console)?;

    // Send security level
    security_level(test_case.security_level).send(spi_console)?;

    // Get the hash function and hash the message to check signatures on the host (unfortunately
    // this code is challenging to deduplicate because the `Digest` trait is not object safe).
    let (hash_alg, message_digest): (CryptotestRsaHashAlg, Vec<u8>) =
        match test_case.hash_alg.as_str() {
            "sha-256" => {
                let mut hasher = Sha256::new();
                Sha2Digest::update(&mut hasher, test_case.message.as_slice());
                (CryptotestRsaHashAlg::Sha256, hasher.finalize().to_vec())
            }
            "sha-384" => {
                let mut hasher = Sha384::new();
                Sha2Digest::update(&mut hasher, test_case.message.as_slice());
                (CryptotestRsaHashAlg::Sha384, hasher.finalize().to_vec())
            }
            "sha-512" => {
                let mut hasher = Sha512::new();
                Sha2Digest::update(&mut hasher, test_case.message.as_slice());
                (CryptotestRsaHashAlg::Sha512, hasher.finalize().to_vec())
            }
            "sha3-224" => {
                let mut hasher = Sha3_224::new();
                Sha3Update::update(&mut hasher, test_case.message.as_slice());
                (CryptotestRsaHashAlg::Sha3_224, hasher.finalize().to_vec())
            }
            "sha3-256" => {
                let mut hasher = Sha3_256::new();
                Sha3Update::update(&mut hasher, test_case.message.as_slice());
                (CryptotestRsaHashAlg::Sha3_256, hasher.finalize().to_vec())
            }
            "sha3-384" => {
                let mut hasher = Sha3_384::new();
                Sha3Update::update(&mut hasher, test_case.message.as_slice());
                (CryptotestRsaHashAlg::Sha3_384, hasher.finalize().to_vec())
            }
            "sha3-512" => {
                let mut hasher = Sha3_512::new();
                Sha3Update::update(&mut hasher, test_case.message.as_slice());
                (CryptotestRsaHashAlg::Sha3_512, hasher.finalize().to_vec())
            }
            "shake-128" => {
                let mut hasher = Shake128::default();
                Sha3Update::update(&mut hasher, test_case.message.as_slice());
                let mut buf = vec![];
                let mut reader = hasher.finalize_xof();
                reader.read_to_end(&mut buf)?;
                (CryptotestRsaHashAlg::Shake128, buf)
            }
            "shake-256" => {
                let mut hasher = Shake256::default();
                Sha3Update::update(&mut hasher, test_case.message.as_slice());
                let mut buf = vec![];
                let mut reader = hasher.finalize_xof();
                reader.read_to_end(&mut buf)?;
                (CryptotestRsaHashAlg::Shake256, buf)
            }
            _ => panic!("Invalid RSA message hash mode"),
        };

    // Send message hash algorithm
    hash_alg.send(spi_console)?;

    // From here, the rest of the state to send and receive depends on
    // what operation we're performing.
    let success = match operation {
        CryptotestRsaOperation::Sign => {
            let private_key = match keys.get(&key_id) {
                Some(key) if test_case.operation == "keygen_sign" => key.clone(),
                _ => test_case_key(test_case),
            };
            CryptotestRsaMessage {
                message: ArrayVec::try_from(test_case.message.as_slice())
                    .expect("Message was too long for device firmware configuration."),
                message_len: test_case.message.len(),
            }
            .send(spi_console)?;
            private_key.send(spi_console)?;
            // RSA signing in cryptolib is nondeterministic, so we cannot compare against the
            // provided signature. Instead, we check that the `rsa` crate verifies it.
            let signature = CryptotestRsaSignature::recv(spi_console, opts.timeout, false, false)?;
            let signature: Vec<u8> = signature.signature[..signature.signature_len]
                .iter()
                .rev()
                .cloned()
                .collect();
            let n = BigUint::from_bytes_le(&private_key.n[..private_key.n_len]);
            if test_case.vendor == "acvp" {
                let mut group_fields = Fields::new();
                group_fields.insert("n".to_string(), json!(hex(&n.to_bytes_be())));
                group_fields.insert(
                    "e".to_string(),
                    json!(hex(&BigUint::from(private_key.e).to_bytes_be())),
                );
                responses.set_group_fields(&test_case.acvp, group_fields);
                let mut fields = Fields::new();
                fields.insert("signature".to_string(), json!(hex(&signature)));
                responses.add(&test_case.acvp, test_case.test_case_id as u64, fields);
            }
            signature_is_valid(
                &padding,
                &hash_alg,
                n,
                private_key.e,
                &message_digest,
                &signature,
            )
        }
        CryptotestRsaOperation::Verify => {
            // Convert parameters to unsigned little-endian
            let n = BigUint::from_bytes_be(test_case.n.as_slice()).to_bytes_le();
            let signature: Vec<_> = test_case.signature.iter().cloned().rev().collect();
            CryptotestRsaMessage {
                message: ArrayVec::try_from(test_case.message.as_slice())
                    .expect("Message was too long for device firmware configuration."),
                message_len: test_case.message.len(),
            }
            .send(spi_console)?;
            CryptotestRsaPublicKey {
                n: ArrayVec::try_from(n.as_slice())
                    .expect("RSA parameter n too long for device firmware configuration."),
                n_len: n.len(),
                e: test_case.e,
            }
            .send(spi_console)?;
            CryptotestRsaSignature {
                signature: ArrayVec::try_from(signature.as_slice())
                    .expect("RSA signature too long for device firmware configuration."),
                signature_len: test_case.signature.len(),
            }
            .send(spi_console)?;
            match CryptotestRsaVerifyOutput::recv(spi_console, opts.timeout, false, false)? {
                CryptotestRsaVerifyOutput::Success => true,
                CryptotestRsaVerifyOutput::Failure => false,
                CryptotestRsaVerifyOutput::IntValue(i) => {
                    panic!("Invalid RSA verify result: {}", i)
                }
            }
        }
        CryptotestRsaOperation::Encrypt => {
            //Convert parameters to unsigned little-endian
            let n_bigint = BigInt::from_signed_bytes_be(test_case.n.as_slice());
            let n = n_bigint.to_bytes_le().1;
            CryptotestRsaRawMessage {
                message: ArrayVec::try_from(test_case.message.as_slice())
                    .expect("Message was too long for device firmware configuration."),
                message_len: test_case.message.len(),
            }
            .send(spi_console)?;
            // Send label
            // TODO the Rust RSA decyrption only supports labels that
            // are valid UTF-8 strings, so we fall back to using an
            // empty label if we get a label that doesn't conform to
            // this pattern.
            let label_str = std::str::from_utf8(test_case.label.as_slice()).unwrap_or("");
            CryptotestRsaLabel {
                label: ArrayVec::try_from(label_str.as_bytes())
                    .expect("Label was too long for device firmware configuration."),
                label_len: label_str.len(),
            }
            .send(spi_console)?;
            // Send expected ciphertext length
            CryptotestRsaExpectedLength {
                expected_len: test_case.ciphertext.len(),
            }
            .send(spi_console)?;
            // Send public key
            CryptotestRsaPublicKey {
                n: ArrayVec::try_from(n.as_slice())
                    .expect("RSA parameter n too long for device firmware configuration."),
                n_len: n.len(),
                e: test_case.e,
            }
            .send(spi_console)?;
            let ciphertext =
                CryptotestRsaCiphertext::recv(spi_console, opts.timeout, false, false)?;
            // Verify we can decrypt the ciphertext
            let private = RsaPrivateKey::from_components(
                n_bigint
                    .to_biguint()
                    .expect("RSA parameter n cannot be negative."),
                BigUint::from(test_case.e),
                BigInt::from_signed_bytes_be(test_case.d.as_slice())
                    .to_biguint()
                    .expect("RSA parameter d cannot be negative."),
                // Emtpy array == recover the primes p and q from n, e, and d.
                Vec::new(),
            )
            .expect("Test vector parameters did not form a valid RSA private key");
            // Convert ciphertext to big-endian
            let mut ciphertext = Vec::from(&ciphertext.ciphertext[..ciphertext.ciphertext_len]);
            ciphertext.reverse();
            private
                .decrypt(
                    match padding {
                        CryptotestRsaPadding::Oaep => match hash_alg {
                            CryptotestRsaHashAlg::Sha256 => {
                                Oaep::new_with_label::<sha2::Sha256, _>(label_str)
                            }
                            CryptotestRsaHashAlg::Sha384 => {
                                Oaep::new_with_label::<sha2::Sha384, _>(label_str)
                            }
                            CryptotestRsaHashAlg::Sha512 => {
                                Oaep::new_with_label::<sha2::Sha512, _>(label_str)
                            }
                            CryptotestRsaHashAlg::Sha3_256 => {
                                Oaep::new_with_label::<sha3::Sha3_256, _>(label_str)
                            }
                            CryptotestRsaHashAlg::Sha3_384 => {
                                Oaep::new_with_label::<sha3::Sha3_384, _>(label_str)
                            }
                            CryptotestRsaHashAlg::Sha3_512 => {
                                Oaep::new_with_label::<sha3::Sha3_512, _>(label_str)
                            }
                            _ => panic!("SHAKE-based hashes are currently unsupported."),
                        },
                        _ => panic!(
                            "Unsupported padding mode for RSA encrypt/decrypt mode: {}",
                            test_case.padding
                        ),
                    },
                    &ciphertext,
                )
                .map_err(Error::new)
                .and_then(|plaintext| {
                    if test_case.message.eq(&plaintext) {
                        Ok(())
                    } else {
                        Err(Error::msg("Incorrect plaintext"))
                    }
                })
                .is_ok()
        }
        CryptotestRsaOperation::Decrypt => {
            let ciphertext: Vec<_> = test_case.ciphertext.iter().cloned().rev().collect();
            // Send ciphertext
            CryptotestRsaCiphertext {
                ciphertext: ArrayVec::try_from(ciphertext.as_slice())
                    .expect("RSA ciphertext too long for device firmware configuration."),
                ciphertext_len: ciphertext.len(),
            }
            .send(spi_console)?;
            // Send label
            CryptotestRsaLabel {
                label: ArrayVec::try_from(test_case.label.as_slice())
                    .expect("Label was too long for device firmware configuration."),
                label_len: test_case.label.len(),
            }
            .send(spi_console)?;
            // Send expected plaintext length
            CryptotestRsaExpectedLength {
                expected_len: test_case.message.len(),
            }
            .send(spi_console)?;
            // Send private key
            test_case_key(test_case).send(spi_console)?;
            let output = CryptotestRsaDecryptOutput::recv(spi_console, opts.timeout, false, false)?;
            output.success != 0
                && output.plaintext[..output.plaintext_len].eq(test_case.message.as_slice())
        }
        _ => unreachable!("Invalid value for RSA operation"),
    };
    if let Some(result) = test_case.result
        && result != success
    {
        log::info!(
            "FAILED test #{}: expected = {}, actual = {}",
            test_case.test_case_id,
            result,
            success
        );
        failures.push(format!(
            "{} RSA-{} {} {} {} #{}",
            test_case.vendor,
            test_case.security_level,
            test_case.padding,
            test_case.operation,
            test_case.hash_alg,
            test_case.test_case_id
        ));
    }
    if test_case.vendor == "acvp" && test_case.operation == "verify" {
        let mut fields = Fields::new();
        fields.insert("testPassed".to_string(), json!(success));
        responses.add(&test_case.acvp, test_case.test_case_id as u64, fields);
    }
    Ok(())
}

fn test_rsa(opts: &Opts, transport: &TransportWrapper) -> Result<()> {
    let spi = transport.spi("BOOTSTRAP")?;
    let spi_console_device = SpiConsoleDevice::new(&*spi, None, /*ignore_frame_num=*/ false)?;
    let _ = UartConsole::wait_for(&spi_console_device, r"Running ", opts.timeout)?;

    let mut test_counter = 0u32;
    let mut failures = vec![];
    let mut responses = ResponseBuilder::new();
    let mut keys = HashMap::new();
    let test_vector_files = opts.acvp.vectors(&opts.rsa_json);
    for file in test_vector_files {
        let raw_json = fs::read_to_string(file)?;
        let rsa_tests: Vec<RsaTestCase> = serde_json::from_str(&raw_json)?;

        for rsa_test in &rsa_tests {
            test_counter += 1;
            log::info!("Test counter: {}", test_counter);
            run_rsa_testcase(
                rsa_test,
                opts,
                &spi_console_device,
                &mut failures,
                &mut responses,
                &mut keys,
            )?;
        }
    }
    assert_eq!(
        0,
        failures.len(),
        "Failed {} out of {} tests. Failures: {:?}",
        failures.len(),
        test_counter,
        failures
    );
    responses.finish(&opts.acvp)
}

fn main() -> Result<()> {
    let opts = Opts::parse();
    opts.init.init_logging();

    let transport = opts.init.init_target()?;
    execute_test!(test_rsa, &opts, &transport);
    Ok(())
}
