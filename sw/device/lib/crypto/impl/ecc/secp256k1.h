// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_ECC_SECP256K1_H_
#define OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_ECC_SECP256K1_H_

#include <stddef.h>
#include <stdint.h>

#include "sw/device/lib/base/hardened.h"
#include "sw/device/lib/crypto/drivers/acc.h"

#ifdef __cplusplus
extern "C" {
#endif  // __cplusplus

enum {
  /**
   * Length of a secp256k1 curve point coordinate in bits (modulo p).
   */
  kSecp256k1CoordBits = 256,
  /**
   * Length of a secp256k1 curve point coordinate in bytes.
   */
  kSecp256k1CoordBytes = kSecp256k1CoordBits / 8,
  /**
   * Length of a secp256k1 curve point coordinate in words.
   */
  kSecp256k1CoordWords = kSecp256k1CoordBytes / sizeof(uint32_t),
  /**
   * Length of an element in the secp256k1 scalar field (modulo the curve order
   * n).
   */
  kSecp256k1ScalarBits = 256,
  /**
   * Length of a secret scalar share in bytes.
   */
  kSecp256k1ScalarBytes = kSecp256k1ScalarBits / 8,
  /**
   * Length of secret scalar share in words.
   */
  kSecp256k1ScalarWords = kSecp256k1ScalarBytes / sizeof(uint32_t),
  /**
   * Length of a masked secret scalar share.
   *
   * This implementation uses extra redundant bits for side-channel protection.
   */
  kSecp256k1MaskedScalarShareBits = kSecp256k1ScalarBits + 64,
  /**
   * Length of a masked secret scalar share in bytes.
   */
  kSecp256k1MaskedScalarShareBytes = kSecp256k1MaskedScalarShareBits / 8,
  /**
   * Length of masked secret scalar share in words.
   */
  kSecp256k1MaskedScalarShareWords =
      kSecp256k1MaskedScalarShareBytes / sizeof(uint32_t),
};

/**
 * A type that holds a masked value from the secp256k1 scalar field.
 *
 * This struct is used to represent secret keys, which are integers modulo n.
 * The key d is represented in two 320-bit shares, d0 and d1, such that d = (d0
 * + d1) mod n. Mathematically, d0 and d1 could also be reduced modulo n, but
 * the extra bits provide side-channel protection.
 */
typedef struct secp256k1_masked_scalar {
  /**
   * First share of the secret scalar.
   */
  uint32_t share0[kSecp256k1MaskedScalarShareWords];
  /**
   * Second share of the secret scalar.
   */
  uint32_t share1[kSecp256k1MaskedScalarShareWords];
} secp256k1_masked_scalar_t;

/**
 * A type that holds a secp256k1 curve point.
 */
typedef struct secp256k1_point {
  /**
   * Affine x-coordinate.
   */
  uint32_t x[kSecp256k1CoordWords];
  /**
   * Affine y-coordinate.
   */
  uint32_t y[kSecp256k1CoordWords];
} secp256k1_point_t;

/**
 * A type that holds an ECDSA/secp256k1 signature.
 *
 * The signature consists of two integers r and s, computed modulo n.
 */
typedef struct secp256k1_ecdsa_signature_t {
  /**
   * First component of the ECDSA signature (r).
   */
  uint32_t r[kSecp256k1ScalarWords];
  /**
   * Second component of the ECDSA signature (s).
   */
  uint32_t s[kSecp256k1ScalarWords];
} secp256k1_ecdsa_signature_t;

/**
 * A type that holds a blinded ECDH shared secret key.
 *
 * The key is boolean-masked (XOR of the two shares).
 */
typedef struct secp256k1_ecdh_shared_key {
  /**
   * First share of the shared secret.
   */
  uint32_t share0[kSecp256k1CoordWords];
  /**
   * Second share of the shared secret.
   */
  uint32_t share1[kSecp256k1CoordWords];
} secp256k1_ecdh_shared_key_t;

/**
 * Start an async secp256k1 keypair generation operation on ACC.
 *
 * Appropriate for both ECDSA and ECDH; the key-generation process is the same.
 *
 * Returns an `OTCRYPTO_ASYNC_INCOMPLETE` error if ACC is busy.
 *
 * @param[out] session_token ACC session token for the operation.
 * @return Result of the operation (OK or error).
 */
OT_WARN_UNUSED_RESULT
status_t secp256k1_keygen_start(uint32_t *session_token);

/**
 * Finish an async secp256k1 keypair generation operation on ACC.
 *
 * Blocks until ACC is idle.
 *
 * @param session_token ACC session token for the operation.
 * @param[out] private_key Generated private key.
 * @param[out] public_key Generated public key.
 * @return Result of the operation (OK or error).
 */
OT_WARN_UNUSED_RESULT
status_t secp256k1_keygen_finalize(uint32_t session_token,
                                   secp256k1_masked_scalar_t *private_key,
                                   secp256k1_point_t *public_key);

/**
 * Start an async secp256k1 sideloaded keypair generation operation on ACC.
 *
 * Appropriate for both ECDSA and ECDH; the key-generation process is the same.
 *
 * Expects a sideloaded key from keymgr to be already loaded on ACC. Returns
 * an `OTCRYPTO_ASYNC_INCOMPLETE` error if ACC is busy.
 *
 * @param[out] session_token ACC session token for the operation.
 * @return Result of the operation (OK or error).
 */
OT_WARN_UNUSED_RESULT
status_t secp256k1_sideload_keygen_start(uint32_t *session_token);

/**
 * Finish an async secp256k1 sideloaded keypair generation operation on ACC.
 *
 * This routine will only read back the public key, instead of both public and
 * private as with `secp256k1_keygen_finalize`. Blocks until ACC is idle.
 *
 * @param session_token ACC session token for the operation.
 * @param[out] public_key Public key.
 * @return Result of the operation (OK or error).
 */
OT_WARN_UNUSED_RESULT
status_t secp256k1_sideload_keygen_finalize(uint32_t session_token,
                                            secp256k1_point_t *public_key);

/**
 * Start a secp256k1 public key on-curve check on ACC.
 *
 * Blocks until ACC is idle.
 *
 * @param[in] public_key Generated public key.
 * @param[out] session_token ACC session token for the operation.
 * @return Result of the operation (OK or error).
 */
OT_WARN_UNUSED_RESULT
status_t secp256k1_public_key_check_start(secp256k1_point_t *public_key,
                                          uint32_t *session_token);

/**
 * Finish a secp256k1 public key on-curve check on ACC.
 *
 * Blocks until ACC is idle.
 *
 * @param session_token ACC session token for the operation.
 * @param[out] result Result of on-curve check.
 * @return Result of the operation (OK or error).
 */
OT_WARN_UNUSED_RESULT
status_t secp256k1_public_key_check_finalize(uint32_t session_token,
                                             hardened_bool_t *result);

/**
 * Start an async ECDSA/secp256k1 signature generation operation on ACC.
 *
 * Returns an `OTCRYPTO_ASYNC_INCOMPLETE` error if ACC is busy.
 *
 * @param digest Digest of the message to sign.
 * @param private_key Secret key to sign the message with.
 * @param[out] session_token ACC session token for the operation.
 * @return Result of the operation (OK or error).
 */
OT_WARN_UNUSED_RESULT
status_t secp256k1_ecdsa_sign_start(
    const uint32_t digest[kSecp256k1ScalarWords],
    const secp256k1_masked_scalar_t *private_key, uint32_t *session_token);

/**
 * Start an async ECDSA/secp256k1 signature generation operation on ACC.
 *
 * Expects a sideloaded key from keymgr to be already loaded on ACC. Returns
 * an `OTCRYPTO_ASYNC_INCOMPLETE` error if ACC is busy.
 *
 * @param digest Digest of the message to sign.
 * @param[out] session_token ACC session token for the operation.
 * @return Result of the operation (OK or error).
 */
OT_WARN_UNUSED_RESULT
status_t secp256k1_ecdsa_sideload_sign_start(
    const uint32_t digest[kSecp256k1ScalarWords], uint32_t *session_token);

/**
 * Finish an async ECDSA/secp256k1 signature generation operation on ACC.
 *
 * See the documentation of `secp256k1_ecdsa_sign` for details.
 *
 * Blocks until ACC is idle.
 *
 * @param session_token ACC session token for the operation.
 * @param[out] result Buffer in which to store the generated signature.
 * @return Result of the operation (OK or error).
 */
OT_WARN_UNUSED_RESULT
status_t secp256k1_ecdsa_sign_finalize(uint32_t session_token,
                                       secp256k1_ecdsa_signature_t *result);

/**
 * Start an async ECDSA/secp256k1 signature verification operation on ACC.
 *
 * See the documentation of `secp256k1_ecdsa_verify` for details.
 *
 * Returns an `OTCRYPTO_ASYNC_INCOMPLETE` error if ACC is busy.
 *
 * @param signature Signature to be verified.
 * @param digest Digest of the message to check the signature against.
 * @param public_key Key to check the signature against.
 * @param[out] session_token ACC session token for the operation.
 * @return Result of the operation (OK or error).
 */
OT_WARN_UNUSED_RESULT
status_t secp256k1_ecdsa_verify_start(
    const secp256k1_ecdsa_signature_t *signature,
    const uint32_t digest[kSecp256k1ScalarWords],
    const secp256k1_point_t *public_key, uint32_t *session_token);

/**
 * Finish an async ECDSA/secp256k1 signature verification operation on ACC.
 *
 * See the documentation of `secp256k1_ecdsa_verify` for details.
 *
 * Blocks until ACC is idle.
 *
 * If the signature is valid, writes `kHardenedBoolTrue` to `result`;
 * otherwise, writes `kHardenedBoolFalse`.
 *
 * Note: the caller must check the `result` buffer in order to determine if a
 * signature passed verification. If a signature is invalid, but nothing goes
 * wrong during computation (e.g. hardware errors, failed preconditions), the
 * status will be OK but `result` will be `kHardenedBoolFalse`.
 *
 * @param signature Signature to be verified.
 * @param session_token ACC session token for the operation.
 * @param[out] result Output buffer (true if signature is valid, false
 * otherwise)
 * @return Result of the operation (OK or error).
 */
OT_WARN_UNUSED_RESULT
status_t secp256k1_ecdsa_verify_finalize(
    const secp256k1_ecdsa_signature_t *signature, uint32_t session_token,
    hardened_bool_t *result);

/**
 * Start an async ECDH/secp256k1 shared key generation operation on ACC.
 *
 * Returns an `OTCRYPTO_ASYNC_INCOMPLETE` error if ACC is busy.
 *
 * @param private_key Private key (d).
 * @param public_key Public key (Q).
 * @param[out] session_token ACC session token for the operation.
 * @return Result of the operation (OK or error).
 */
OT_WARN_UNUSED_RESULT
status_t secp256k1_ecdh_start(const secp256k1_masked_scalar_t *private_key,
                              const secp256k1_point_t *public_key,
                              uint32_t *session_token);

/**
 * Finish an async ECDH/secp256k1 shared key generation operation on ACC.
 *
 * Blocks until ACC is idle.
 *
 * @param session_token ACC session token for the operation.
 * @param[out] shared_key Shared secret key (x-coordinate of d*Q).
 * @return Result of the operation (OK or error).
 */
OT_WARN_UNUSED_RESULT
status_t secp256k1_ecdh_finalize(uint32_t session_token,
                                 secp256k1_ecdh_shared_key_t *shared_key);

/**
 * Start an async ECDH/secp256k1 shared key generation operation on ACC.
 *
 * Uses a private key generated from a key manager seed. The key manager should
 * already have sideloaded the key into ACC before this operation is called.
 *
 * Returns an `OTCRYPTO_ASYNC_INCOMPLETE` error if ACC is busy.
 *
 * @param public_key Public key (Q).
 * @param[out] session_token ACC session token for the operation.
 * @return Result of the operation (OK or error).
 */
OT_WARN_UNUSED_RESULT
status_t secp256k1_sideload_ecdh_start(const secp256k1_point_t *public_key,
                                       uint32_t *session_token);

/**
 * Finish an async ECDH/secp256k1 shared key generation operation on ACC.
 *
 * Uses a private key generated from a key manager seed. The key manager should
 * already have sideloaded the key into ACC before this operation is called.
 *
 * Blocks until ACC is idle.
 *
 * @param session_token ACC session token for the operation.
 * @param[out] shared_key Shared secret key (x-coordinate of d*Q).
 * @return Result of the operation (OK or error).
 */
OT_WARN_UNUSED_RESULT
status_t secp256k1_sideload_ecdh_finalize(
    uint32_t session_token, secp256k1_ecdh_shared_key_t *shared_key);

#ifdef __cplusplus
}  // extern "C"
#endif  // __cplusplus

#endif  // OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_ECC_SECP256K1_H_
