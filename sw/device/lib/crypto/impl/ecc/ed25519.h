// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_ECC_ED25519_H_
#define OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_ECC_ED25519_H_

#include <stddef.h>
#include <stdint.h>

#include "sw/device/lib/base/hardened.h"
#include "sw/device/lib/crypto/drivers/acc.h"

#ifdef __cplusplus
extern "C" {
#endif  // __cplusplus

enum {
  /**
   * Length of a Ed25519 curve point coordinate in bits (modulo p).
   */
  kEd25519SecretBits = 256,
  /**
   * Length of a Ed25519 curve point coordinate in bytes.
   */
  kEd25519SecretBytes = kEd25519SecretBits / 8,
  /**
   * Length of a Ed25519 curve point coordinate in words.
   */
  kEd25519SecretWords = kEd25519SecretBytes / sizeof(uint32_t),
  /**
   * Length of a Ed25519 curve point coordinate in bits (modulo p).
   */
  kEd25519HashBits = 512,
  /**
   * Length of a Ed25519 curve point coordinate in bytes.
   */
  kEd25519HashBytes = kEd25519HashBits / 8,
  /**
   * Length of a Ed25519 curve point coordinate in words.
   */
  kEd25519HashWords = kEd25519HashBytes / sizeof(uint32_t),
  /**
   * Length of a Ed25519 curve point coordinate in bits (modulo p).
   */
  kEd25519PreHashBits = 512,
  /**
   * Length of a Ed25519 curve point coordinate in bytes.
   */
  kEd25519PreHashBytes = kEd25519PreHashBits / 8,
  /**
   * Length of a Ed25519 curve point coordinate in words.
   */
  kEd25519PreHashWords = kEd25519PreHashBytes / sizeof(uint32_t),
  /**
   * Length of a Ed25519 curve point coordinate in bits (modulo p).
   */
  kEd25519ScalarBits = 256,
  /**
   * Length of a Ed25519 curve point coordinate in bytes.
   */
  kEd25519ScalarBytes = kEd25519ScalarBits / 8,
  /**
   * Length of a Ed25519 curve point coordinate in words.
   */
  kEd25519ScalarWords = kEd25519ScalarBytes / sizeof(uint32_t),
  /**
   * Length of a element in the Ed25519 scalar field.
   */
  kEd25519PointBits = 256,
  /**
   * Length of a secret scalar in bytes.
   */
  kEd25519PointBytes = kEd25519PointBits / 8,
  /**
   * Length of secret scalar in words.
   */
  kEd25519PointWords = kEd25519PointBytes / sizeof(uint32_t),
  /**
   * Length of Ed25519 context in bits, including the flag.
   */
  kEd25519ContextBits = 2048,
  /**
   * Length of Ed25519 context in bytes, including the flag.
   */
  kEd25519ContextBytes = kEd25519ContextBits / 8,
  /**
   * Length of Ed25519 context in words, including the flag.
   */
  kEd25519ContextWords = kEd25519ContextBytes / sizeof(uint32_t),
  /**
   * A successful Ed25519 signature verification result.
   */
  kEd25519VerifySuccess = 0xf77fe650,
  /**
   * A failed Ed25519 signature verification result.
   */
  kEd25519VerifyFailure = 0xeda2bfaf,
};

/**
 * A type that holds an Ed25519 private key.
 */
typedef struct ed25519_secret {
  uint32_t data[kEd25519SecretWords];
} ed25519_secret_t;

/**
 * A type that holds an encoded Ed25519 point.
 *
 * The point stored in the data field should be encoded as described in RFC 8032
 * section 5.2.2.
 */
typedef struct ed25519_point {
  uint32_t data[kEd25519SecretWords];
} ed25519_point_t;

/**
 * A type that holds a Ed25519 signature.
 *
 * The signature stored here should be encoded as described in RFC 8032 section
 * 5.2.6. Specifically, r should be encoded as described in section 5.2.2, and s
 * should be encoded as a reduced little-endian scalar.
 */
typedef struct ed25519_signature {
  /**
   * First part of the Ed25519 signature, the point R.
   */
  uint32_t r[kEd25519PointWords];
  /**
   * First part of the Ed25519 signature, the scalar S.
   */
  uint32_t s[kEd25519ScalarWords];
} ed25519_signature_t;
;

/**
 * Start an async Ed25519ph signature generation operation on ACC.
 *
 * Returns an `OTCRYPTO_ASYNC_INCOMPLETE` error if ACC is busy.
 *
 * @param prehashed_message Prehashed (SHA-512) message to sign.
 * @param hash_h SHA-512 hash of the Ed25519 private key to sign with.
 * @param context Context to use for signing.
 * @param context_length Length of the provided context.
 * @param[out] session_token ACC session token for the operation.
 * @return Result of the operation (OK or error).
 */
OT_WARN_UNUSED_RESULT
status_t ed25519_sign_start(
    const uint32_t prehashed_message[kEd25519PreHashWords],
    const uint32_t hash_h[kEd25519HashWords],
    const uint32_t context[kEd25519ContextWords], const uint32_t context_length,
    uint32_t *session_token);

/**
 * Finish an async Ed25519 signature generation operation on ACC.
 *
 * See the documentation of `p256_ecdsa_sign` for details.
 *
 * Blocks until ACC is idle.
 *
 * @param session_token ACC session token for the operation.
 * @param[out] result Buffer in which to store the generated signature.
 * @return Result of the operation (OK or error).
 */
OT_WARN_UNUSED_RESULT
status_t ed25519_sign_finalize(uint32_t session_token,
                               ed25519_signature_t *result);

/**
 * Start an async Ed25519 signature verification operation on ACC.
 *
 * This function expects the scalar value k as computed in RFC 8032 section
 * 5.2.6 step 2 to be pre-computed and provided as a little-endian value to this
 * function; see that section of the RFC for details.
 *
 * @param signature Signature to verify.
 * @param prehashed_message Prehashed (SHA-512) message to sign.
 * @param hash_k Pre-computed scalar value k for verification.
 * @param context Context to use for signing.
 * @param context_length Length of the provided context.
 * @param[out] session_token ACC session token for the operation.
 * @return Result of the operation (OK or error).
 */
OT_WARN_UNUSED_RESULT
status_t ed25519_verify_start(
    const ed25519_signature_t *signature,
    const uint32_t prehashed_message[kEd25519PreHashWords],
    const uint32_t hash_k[kEd25519HashWords], const ed25519_point_t *public_key,
    const uint32_t context[kEd25519ContextWords], const uint32_t context_length,
    uint32_t *session_token);

/**
 * Finish an async Ed25519 signature verification operation on ACC.
 *
 * @param signature Signature to be verified.
 * @param session_token ACC session token for the operation.
 * @param[out] result Result of verification.
 * @return Result of the operation (OK or error).
 */
OT_WARN_UNUSED_RESULT
status_t ed25519_verify_finalize(const ed25519_signature_t *signature,
                                 uint32_t session_token,
                                 hardened_bool_t *result);

#ifdef __cplusplus
}  // extern "C"
#endif  // __cplusplus

#endif  // OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_ECC_ED25519_H_
