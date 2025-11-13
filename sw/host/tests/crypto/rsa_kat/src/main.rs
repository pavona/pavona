// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

use anyhow::{Error, Result};
use arrayvec::ArrayVec;
use clap::Parser;
use num_bigint_dig::{BigInt, BigUint};
use serde::Deserialize;
use sha2::{Digest as Sha2Digest, Sha256, Sha384, Sha512};
use sha3::{
    Sha3_224, Sha3_256, Sha3_384, Sha3_512, Shake128, Shake256,
    digest::{ExtendableOutput, Update as Sha3Update},
};
use std::fs;
use std::io::Read;
use std::time::Duration;

use cryptotest_commands::commands::CryptotestCommand;
use cryptotest_commands::rsa_commands::{
    CryptotestRsaCiphertext, CryptotestRsaDecryptOutput, CryptotestRsaExpectedLength,
    CryptotestRsaHashAlg, CryptotestRsaLabel, CryptotestRsaMessageDigest, CryptotestRsaOperation,
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
}

#[derive(Debug, Deserialize)]
struct RsaTestCase {
    vendor: String,
    test_case_id: usize,
    algorithm: String,
    operation: String,
    padding: String,
    security_level: usize,
    hash_alg: String,
    message: Vec<u8>,
    #[serde(default)]
    label: Vec<u8>,
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
    result: bool,
}

fn run_rsa_testcase(
    test_case: &RsaTestCase,
    opts: &Opts,
    spi_console: &SpiConsoleDevice,
    failures: &mut Vec<String>,
) -> Result<()> {
    log::info!(
        "vendor: {}, test case: {}",
        test_case.vendor,
        test_case.test_case_id
    );
    assert_eq!(test_case.algorithm.as_str(), "rsa");

    // Send algorithm name
    CryptotestCommand::Rsa.send(spi_console)?;

    // Send RSA operation
    let operation = match test_case.operation.as_str() {
        "sign" => CryptotestRsaOperation::Sign,
        "verify" => CryptotestRsaOperation::Verify,
        "encrypt" => CryptotestRsaOperation::Encrypt,
        "decrypt" => CryptotestRsaOperation::Decrypt,
        _ => panic!("Unsupported RSA operation"),
    };
    operation.send(spi_console)?;

    // Send padding mode
    let padding = match test_case.padding.as_str() {
        "oaep" => CryptotestRsaPadding::Oaep,
        "pkcs1_1.5" => CryptotestRsaPadding::Pkcs15,
        "pss" => CryptotestRsaPadding::Pss,
        _ => panic!("Unsupported RSA padding mode"),
    };
    padding.send(spi_console)?;

    // Send security level
    match test_case.security_level {
        2048 => CryptotestRsaSecurityLevel::Rsa2048,
        3072 => CryptotestRsaSecurityLevel::Rsa3072,
        4096 => CryptotestRsaSecurityLevel::Rsa4096,
        _ => panic!("Unsupported RSA security level"),
    }
    .send(spi_console)?;

    // Get the hash function and hash the message to get the digest (unfortunately this code is
    // challenging to deduplicate because the `Digest` trait is not object safe).
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

    // Size of `input` is determined at compile-time by type inference
    let mut message_digest_buf = ArrayVec::new();
    // Fill the buffer until we run out of bytes, truncating the rightmost bytes if we have too
    // many
    let message_digest_len = message_digest.len();
    let mut message_digest_iter = message_digest.iter();
    while !message_digest_buf.is_full() {
        message_digest_buf.push(*message_digest_iter.next().unwrap_or(&0u8));
    }
    // From here, the rest of the state to send and receive depends on
    // what operation we're performing.
    let success = match operation {
        CryptotestRsaOperation::Sign => {
            // Convert parameters to unsigned little-endian
            let n_bigint = BigInt::from_signed_bytes_be(test_case.n.as_slice());
            let n = n_bigint.to_bytes_le().1;
            let p_bigint = BigInt::from_signed_bytes_be(test_case.p.as_slice());
            let p = p_bigint.to_bytes_le().1;
            let q_bigint = BigInt::from_signed_bytes_be(test_case.q.as_slice());
            let q = q_bigint.to_bytes_le().1;
            let d_bigint = BigInt::from_signed_bytes_be(test_case.d.as_slice());
            let d = d_bigint.to_bytes_le().1;
            let d_p_bigint = BigInt::from_signed_bytes_be(test_case.d_p.as_slice());
            let d_p = d_p_bigint.to_bytes_le().1;
            let d_q_bigint = BigInt::from_signed_bytes_be(test_case.d_q.as_slice());
            let d_q = d_q_bigint.to_bytes_le().1;
            let i_q_bigint = BigInt::from_signed_bytes_be(test_case.i_q.as_slice());
            let i_q = i_q_bigint.to_bytes_le().1;

            CryptotestRsaMessageDigest {
                message_digest: message_digest_buf,
                message_digest_len,
            }
            .send(spi_console)?;
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
            .send(spi_console)?;
            // RSA signing in cryptolib is nondeterministic, so we cannot compare against the
            // provided signature. Instead, we use a known-good implementation to check that we can
            // verify the returned signature.
            let signature = CryptotestRsaSignature::recv(spi_console, opts.timeout, false)?;
            let signature = BigUint::from_bytes_le(&signature.signature[..signature.signature_len])
                .to_bytes_be();
            let public = RsaPublicKey::new(
                n_bigint
                    .to_biguint()
                    .expect("RSA parameter n cannot be negative"),
                BigUint::from(test_case.e),
            )
            .expect("Invalid public key");
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
                    public.verify(scheme, message_digest.as_slice(), signature.as_slice())
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
                    public.verify(scheme, message_digest.as_slice(), signature.as_slice())
                }
                _ => panic!("Unsupported padding scheme for sign/verify operations"),
            }
            .is_ok()
        }
        CryptotestRsaOperation::Verify => {
            // Convert parameters to unsigned little-endian
            let n = BigInt::from_signed_bytes_be(test_case.n.as_slice())
                .to_bytes_le()
                .1;
            let signature: Vec<_> = test_case.signature.iter().cloned().rev().collect();
            CryptotestRsaMessageDigest {
                message_digest: message_digest_buf,
                message_digest_len,
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
            match CryptotestRsaVerifyOutput::recv(spi_console, opts.timeout, false)? {
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
            let ciphertext = CryptotestRsaCiphertext::recv(spi_console, opts.timeout, false)?;
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
            // Convert parameters to unsigned little-endian
            let n_bigint = BigInt::from_signed_bytes_be(test_case.n.as_slice());
            let n = n_bigint.to_bytes_le().1;
            let p_bigint = BigInt::from_signed_bytes_be(test_case.p.as_slice());
            let p = p_bigint.to_bytes_le().1;
            let q_bigint = BigInt::from_signed_bytes_be(test_case.q.as_slice());
            let q = q_bigint.to_bytes_le().1;
            let d_bigint = BigInt::from_signed_bytes_be(test_case.d.as_slice());
            let d = d_bigint.to_bytes_le().1;
            let d_p_bigint = BigInt::from_signed_bytes_be(test_case.d_p.as_slice());
            let d_p = d_p_bigint.to_bytes_le().1;
            let d_q_bigint = BigInt::from_signed_bytes_be(test_case.d_q.as_slice());
            let d_q = d_q_bigint.to_bytes_le().1;
            let i_q_bigint = BigInt::from_signed_bytes_be(test_case.i_q.as_slice());
            let i_q = i_q_bigint.to_bytes_le().1;
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
            .send(spi_console)?;
            let output = CryptotestRsaDecryptOutput::recv(spi_console, opts.timeout, false)?;
            output.success != 0
                && output.plaintext[..output.plaintext_len].eq(test_case.message.as_slice())
        }
        _ => unreachable!("Invalid value for RSA operation"),
    };
    if test_case.result != success {
        log::info!(
            "FAILED test #{}: expected = {}, actual = {}",
            test_case.test_case_id,
            test_case.result,
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
    Ok(())
}

fn test_rsa(opts: &Opts, transport: &TransportWrapper) -> Result<()> {
    let spi = transport.spi("BOOTSTRAP")?;
    let spi_console_device = SpiConsoleDevice::new(&*spi, None)?;
    let _ = UartConsole::wait_for(&spi_console_device, r"Running [^\r\n]*", opts.timeout)?;

    let mut test_counter = 0u32;
    let mut failures = vec![];
    let test_vector_files = &opts.rsa_json;
    for file in test_vector_files {
        let raw_json = fs::read_to_string(file)?;
        let rsa_tests: Vec<RsaTestCase> = serde_json::from_str(&raw_json)?;

        for rsa_test in &rsa_tests {
            test_counter += 1;
            log::info!("Test counter: {}", test_counter);
            run_rsa_testcase(rsa_test, opts, &spi_console_device, &mut failures)?;
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
    Ok(())
}

fn main() -> Result<()> {
    let opts = Opts::parse();
    opts.init.init_logging();

    let transport = opts.init.init_target()?;
    execute_test!(test_rsa, &opts, &transport);
    Ok(())
}
