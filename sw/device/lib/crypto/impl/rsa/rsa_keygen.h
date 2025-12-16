// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_RSA_RSA_KEYGEN_H_
#define OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_RSA_RSA_KEYGEN_H_

#include <stddef.h>
#include <stdint.h>

#include "sw/device/lib/base/hardened.h"
#include "sw/device/lib/crypto/impl/rsa/rsa_datatypes.h"
#include "sw/device/lib/crypto/impl/status.h"

#ifdef __cplusplus
extern "C" {
#endif  // __cplusplus

/**
 * Starts an RSA-2048 key generation operation; returns immediately.
 *
 * The key exponent is always F4=65537; no other exponents are supported.
 *
 * Returns an `OTCRYPTO_ASYNC_INCOMPLETE` error if OTBN is busy.
 *
 * @return Result of the operation (OK or error).
 */
OT_WARN_UNUSED_RESULT
status_t rsa_keygen_2048_start(void);

/**
 * Waits for an RSA-2048 key generation to complete.
 *
 * Should be invoked only after `rsa_keygen_2048_start`. Blocks until OTBN is
 * done processing.
 *
 * @param[out] public_key Generated public key (n, e).
 * @param[out] private_key Generated private key (p, q, d_p, d_q, i_q).
 * @return Result of the operation (OK or error).
 */
OT_WARN_UNUSED_RESULT
status_t rsa_keygen_2048_finalize(rsa_2048_public_key_t *public_key,
                                  rsa_2048_private_key_t *private_key);

/**
 * Starts an RSA-3072 key generation operation; returns immediately.
 *
 * The key exponent is always F4=65537; no other exponents are supported.
 *
 * Returns an `OTCRYPTO_ASYNC_INCOMPLETE` error if OTBN is busy.
 *
 * @return Result of the operation (OK or error).
 */
OT_WARN_UNUSED_RESULT
status_t rsa_keygen_3072_start(void);

/**
 * Waits for an RSA-3072 key generation to complete.
 *
 * Should be invoked only after `rsa_keygen_3072_start`. Blocks until OTBN is
 * done processing.
 *
 * @param[out] public_key Generated public key (n, e).
 * @param[out] private_key Generated private key (p, q, d_p, d_q, i_q).
 * @return Result of the operation (OK or error).
 */
OT_WARN_UNUSED_RESULT
status_t rsa_keygen_3072_finalize(rsa_3072_public_key_t *public_key,
                                  rsa_3072_private_key_t *private_key);

/**
 * Starts an RSA-4096 key generation operation; returns immediately.
 *
 * The key exponent is always F4=65537; no other exponents are supported.
 *
 * Returns an `OTCRYPTO_ASYNC_INCOMPLETE` error if OTBN is busy.
 *
 * @return Result of the operation (OK or error).
 */
OT_WARN_UNUSED_RESULT
status_t rsa_keygen_4096_start(void);

/**
 * Waits for an RSA-4096 key generation to complete.
 *
 * Should be invoked only after `rsa_keygen_4096_start`. Blocks until OTBN is
 * done processing.
 *
 * @param[out] public_key Generated public key (n, e).
 * @param[out] private_key Generated private key (p, q, d_p, d_q, i_q).
 * @return Result of the operation (OK or error).
 */
OT_WARN_UNUSED_RESULT
status_t rsa_keygen_4096_finalize(rsa_4096_public_key_t *public_key,
                                  rsa_4096_private_key_t *private_key);

/**
 * Starts an RSA-2048 key-from-cofactor operation; returns immediately.
 *
 * The key exponent must be F4=65537; no other exponents are supported. This
 * routine does not perform any checks on the generated keypair (e.g. primality
 * checks or even range checks).
 *
 * Returns an `OTCRYPTO_ASYNC_INCOMPLETE` error if OTBN is busy.
 *
 * @param public_key Public key (n, e).
 * @param cofactor One of the prime cofactors (p or q).
 * @return Result of the operation (OK or error).
 */
OT_WARN_UNUSED_RESULT
status_t rsa_keygen_from_cofactor_2048_start(
    const rsa_2048_public_key_t *public_key, const rsa_2048_short_t *cofactor);

/**
 * Waits for an RSA-2048 key-from-cofactor operation to complete.
 *
 * Should be invoked only after `rsa_keygen_from_cofactor_2048_start`. Blocks
 * until OTBN is done processing.
 *
 * The public key returned by this function is recomputed by OTBN; callers may
 * find it helpful to compare the public key modulus returned to the one that
 * was passed to OTBN originally in order to check for errors.
 *
 * @param[out] public_key Generated public key (n, e).
 * @param[out] private_key Generated private key (p, q, d_p, d_q, i_q).
 * @return Result of the operation (OK or error).
 */
OT_WARN_UNUSED_RESULT
status_t rsa_keygen_from_cofactor_2048_finalize(
    rsa_2048_public_key_t *public_key, rsa_2048_private_key_t *private_key);

/**
 * Starts an RSA-3072 key-from-cofactor operation; returns immediately.
 *
 * The key exponent must be F4=65537; no other exponents are supported. This
 * routine does not perform any checks on the generated keypair (e.g. primality
 * checks or even range checks).
 *
 * Returns an `OTCRYPTO_ASYNC_INCOMPLETE` error if OTBN is busy.
 *
 * @param public_key Public key (n, e).
 * @param cofactor One of the prime cofactors (p or q).
 * @return Result of the operation (OK or error).
 */
OT_WARN_UNUSED_RESULT
status_t rsa_keygen_from_cofactor_3072_start(
    const rsa_3072_public_key_t *public_key, const rsa_3072_short_t *cofactor);

/**
 * Waits for an RSA-3072 key-from-cofactor operation to complete.
 *
 * Should be invoked only after `rsa_keygen_from_cofactor_3072_start`. Blocks
 * until OTBN is done processing.
 *
 * The public key returned by this function is recomputed by OTBN; callers may
 * find it helpful to compare the public key modulus returned to the one that
 * was passed to OTBN originally in order to check for errors.
 *
 * @param[out] public_key Generated public key (n, e).
 * @param[out] private_key Generated private key (p, q, d_p, d_q, i_q).
 * @return Result of the operation (OK or error).
 */
OT_WARN_UNUSED_RESULT
status_t rsa_keygen_from_cofactor_3072_finalize(
    rsa_3072_public_key_t *public_key, rsa_3072_private_key_t *private_key);

/**
 * Starts an RSA-4096 key-from-cofactor operation; returns immediately.
 *
 * The key exponent must be F4=65537; no other exponents are supported. This
 * routine does not perform any checks on the generated keypair (e.g. primality
 * checks or even range checks).
 *
 * Returns an `OTCRYPTO_ASYNC_INCOMPLETE` error if OTBN is busy.
 *
 * @param public_key Public key (n, e).
 * @param cofactor One of the prime cofactors (p or q).
 * @return Result of the operation (OK or error).
 */
OT_WARN_UNUSED_RESULT
status_t rsa_keygen_from_cofactor_4096_start(
    const rsa_4096_public_key_t *public_key, const rsa_4096_short_t *cofactor);

/**
 * Waits for an RSA-4096 key-from-cofactor operation to complete.
 *
 * Should be invoked only after `rsa_keygen_from_cofactor_4096_start`. Blocks
 * until OTBN is done processing.
 *
 * The public key returned by this function is recomputed by OTBN; callers may
 * find it helpful to compare the public key modulus returned to the one that
 * was passed to OTBN originally in order to check for errors.
 *
 * @param[out] public_key Generated public key (n, e).
 * @param[out] private_key Generated private key (p, q, d_p, d_q, i_q).
 * @return Result of the operation (OK or error).
 */
OT_WARN_UNUSED_RESULT
status_t rsa_keygen_from_cofactor_4096_finalize(
    rsa_4096_public_key_t *public_key, rsa_4096_private_key_t *private_key);

/**
 * Checks the validity of a RSA-2048 private key with respect to a given
 * RSA-2048 public key.
 *
 * Returns an `OTCRYPTO_ASYNC_INCOMPLETE` error if OTBN is busy.
 *
 * This method performs a series of checks to ensure that a private key is
 * internally consistent with a given public key. Namely, it checks that
 *
 *  (a) the public modulus is the product of the primes in the private key,
 *  (b) the private exponent, as determined by the private exponent CRT,
 *      components in the private key, is the inverse of the public exponent
 *      modulo the Carmichael function of the public modulus,
 *  (c) the higher limbs of this reconstructed private exponent are non-zero, as
 *      required in FIPS 186-5 section A.1.1,
 *  (d) the CRT coefficient in the private key is the inverse of the second
 *      modulus cofactor modulo the first.
 *
 * Additionally, if the hardened `check_primes` flag is set, then this routine
 * also checks that both primes pass Miller-Rabin primality tests and that
 * the primes aren't too close.
 *
 * As part of performing these checks, check values are computed using the OTBN
 * which are verified on the Ibex by performing hardened comparisons to expected
 * values.
 *
 * @param public_key Public key (n, e).
 * @param private_key Private key (p, q, d_p, d_q, i_q).
 * @param check_primes Whether to perform checks on the private key primes.
 * @return Result of the operation (OK or error).
 */
OT_WARN_UNUSED_RESULT
status_t rsa_key_check_2048_start(const rsa_2048_public_key_t *public_key,
                                  const rsa_2048_private_key_t *private_key,
                                  hardened_bool_t check_primes);

/*
 * Waits for an RSA-2048 private key check to complete.
 *
 * Should be invoked only after `rsa_key_check_2048_start`. Blocks until OTBN is
 * done processing.
 *
 * The `check_primes` flag should be provided exactly as it was to
 * `rsa_key_check_2048_start` in order to ensure that the correct set of check
 * values returned from the OTBN as a result of `rsa_key_check_2048_start` are
 * verified by the Ibex.
 *
 * @param public_key Public key (n, e).
 * @param private_key Private key (p, q, d_p, d_q, i_q).
 * @param check_primes Whether to perform checks on the private key primes.
 * @param[out] key_valid Whether the provided private key is valid.
 * @return Result of the operation (OK or error).
 */
OT_WARN_UNUSED_RESULT
status_t rsa_key_check_2048_finalize(const rsa_2048_public_key_t *public_key,
                                     const rsa_2048_private_key_t *private_key,
                                     hardened_bool_t check_primes,
                                     hardened_bool_t *key_valid);

/**
 * Checks the validity of a RSA-3072 private key with respect to a given
 * RSA-3072 public key.
 *
 * Returns an `OTCRYPTO_ASYNC_INCOMPLETE` error if OTBN is busy.
 *
 * This method performs a series of checks to ensure that a private key is
 * internally consistent with a given public key. Namely, it checks that
 *
 *  (a) the public modulus is the product of the primes in the private key,
 *  (b) the private exponent, as determined by the private exponent CRT,
 *      components in the private key, is the inverse of the public exponent
 *      modulo the Carmichael function of the public modulus,
 *  (c) the higher limbs of this reconstructed private exponent are non-zero, as
 *      required in FIPS 186-5 section A.1.1,
 *  (d) the CRT coefficient in the private key is the inverse of the second
 *      modulus cofactor modulo the first.
 *
 * Additionally, if the hardened `check_primes` flag is set, then this routine
 * also checks that both primes pass Miller-Rabin primality tests and that
 * the primes aren't too close.
 *
 * As part of performing these checks, check values are computed using the OTBN
 * which are verified on the Ibex by performing hardened comparisons to expected
 * values.
 *
 * @param public_key Public key (n, e).
 * @param private_key Private key (p, q, d_p, d_q, i_q).
 * @param check_primes Whether to perform checks on the private key primes.
 * @return Result of the operation (OK or error).
 */
OT_WARN_UNUSED_RESULT
status_t rsa_key_check_3072_start(const rsa_3072_public_key_t *public_key,
                                  const rsa_3072_private_key_t *private_key,
                                  hardened_bool_t check_primes);

/*
 * Waits for an RSA-3072 private key check to complete.
 *
 * Should be invoked only after `rsa_key_check_3072_start`. Blocks until OTBN is
 * done processing.
 *
 * The `check_primes` flag should be provided exactly as it was to
 * `rsa_key_check_3072_start` in order to ensure that the correct set of check
 * values returned from the OTBN as a result of `rsa_key_check_3072_start` are
 * verified by the Ibex.
 *
 * @param public_key Public key (n, e).
 * @param private_key Private key (p, q, d_p, d_q, i_q).
 * @param check_primes Whether to perform checks on the private key primes.
 * @param[out] key_valid Whether the provided private key is valid.
 * @return Result of the operation (OK or error).
 */
OT_WARN_UNUSED_RESULT
status_t rsa_key_check_3072_finalize(const rsa_3072_public_key_t *public_key,
                                     const rsa_3072_private_key_t *private_key,
                                     hardened_bool_t check_primes,
                                     hardened_bool_t *key_valid);

/**
 * Checks the validity of a RSA-4096 private key with respect to a given
 * RSA-4096 public key.
 *
 * Returns an `OTCRYPTO_ASYNC_INCOMPLETE` error if OTBN is busy.
 *
 * This method performs a series of checks to ensure that a private key is
 * internally consistent with a given public key. Namely, it checks that
 *
 *  (a) the public modulus is the product of the primes in the private key,
 *  (b) the private exponent, as determined by the private exponent CRT,
 *      components in the private key, is the inverse of the public exponent
 *      modulo the Carmichael function of the public modulus,
 *  (c) the higher limbs of this reconstructed private exponent are non-zero, as
 *      required in FIPS 186-5 section A.1.1,
 *  (d) the CRT coefficient in the private key is the inverse of the second
 *      modulus cofactor modulo the first.
 *
 * Additionally, if the hardened `check_primes` flag is set, then this routine
 * also checks that both primes pass Miller-Rabin primality tests and that
 * the primes aren't too close.
 *
 * As part of performing these checks, check values are computed using the OTBN
 * which are verified on the Ibex by performing hardened comparisons to expected
 * values.
 *
 * @param public_key Public key (n, e).
 * @param private_key Private key (p, q, d_p, d_q, i_q).
 * @param check_primes Whether to perform checks on the private key primes.
 * @return Result of the operation (OK or error).
 */
OT_WARN_UNUSED_RESULT
status_t rsa_key_check_4096_start(const rsa_4096_public_key_t *public_key,
                                  const rsa_4096_private_key_t *private_key,
                                  hardened_bool_t check_primes);

/*
 * Waits for an RSA-4096 private key check to complete.
 *
 * Should be invoked only after `rsa_key_check_4096_start`. Blocks until OTBN is
 * done processing.
 *
 * The `check_primes` flag should be provided exactly as it was to
 * `rsa_key_check_4096_start` in order to ensure that the correct set of check
 * values returned from the OTBN as a result of `rsa_key_check_4096_start` are
 * verified by the Ibex.
 *
 * @param public_key Public key (n, e).
 * @param private_key Private key (p, q, d_p, d_q, i_q).
 * @param check_primes Whether to perform checks on the private key primes.
 * @param[out] key_valid Whether the provided private key is valid.
 * @return Result of the operation (OK or error).
 */
OT_WARN_UNUSED_RESULT
status_t rsa_key_check_4096_finalize(const rsa_4096_public_key_t *public_key,
                                     const rsa_4096_private_key_t *private_key,
                                     hardened_bool_t check_primes,
                                     hardened_bool_t *key_valid);

#ifdef __cplusplus
}  // extern "C"
#endif  // __cplusplus

#endif  // OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_RSA_RSA_KEYGEN_H_
