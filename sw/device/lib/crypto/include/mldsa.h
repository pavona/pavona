// Copyright The mldsa-native project authors
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_LIB_CRYPTO_INCLUDE_MLDSA_H_
#define OPENTITAN_SW_DEVICE_LIB_CRYPTO_INCLUDE_MLDSA_H_

#include "datatypes.h"

#ifdef __cplusplus
extern "C" {
#endif  // __cplusplus

/**
 * Signature mode for ML-DSA.
 *
 * Values are hardened.
 */
typedef enum otcrypto_mldsa_sign_mode {
  // Signature mode ML-DSA (pure).
  kOtcryptoMldsaSignModeMldsa = 0x37f,
  // TODO: Add HashML-DSA mode (mldsa-native supports it, just needs
  // integration).
} otcrypto_mldsa_sign_mode_t;

enum {
  kOtcryptoMldsa44PublicKeyBytes = 1312,
  kOtcryptoMldsa44SecretKeyBytes = 2560,
  kOtcryptoMldsa44SignatureBytes = 2420,
  kOtcryptoMldsa44SeedBytes = 32,

  kOtcryptoMldsa65PublicKeyBytes = 1952,
  kOtcryptoMldsa65SecretKeyBytes = 4032,
  kOtcryptoMldsa65SignatureBytes = 3309,
  kOtcryptoMldsa65SeedBytes = 32,

  kOtcryptoMldsa87PublicKeyBytes = 2592,
  kOtcryptoMldsa87SecretKeyBytes = 4896,
  kOtcryptoMldsa87SignatureBytes = 4627,
  kOtcryptoMldsa87SeedBytes = 32,

  // Work buffer sizes in 32-bit words
  kOtcryptoMldsa44WorkBufferKeypairWords = 32992 / sizeof(uint32_t),
  kOtcryptoMldsa44WorkBufferSignWords = 32448 / sizeof(uint32_t),
  kOtcryptoMldsa44WorkBufferVerifyWords = 22464 / sizeof(uint32_t),

  kOtcryptoMldsa65WorkBufferKeypairWords = 46304 / sizeof(uint32_t),
  kOtcryptoMldsa65WorkBufferSignWords = 44768 / sizeof(uint32_t),
  kOtcryptoMldsa65WorkBufferVerifyWords = 30720 / sizeof(uint32_t),

  kOtcryptoMldsa87WorkBufferKeypairWords = 62688 / sizeof(uint32_t),
  kOtcryptoMldsa87WorkBufferSignWords = 59104 / sizeof(uint32_t),
  kOtcryptoMldsa87WorkBufferVerifyWords = 41216 / sizeof(uint32_t),
};

/**
 * Generates a fresh random ML-DSA-44 key pair.
 *
 * The caller should allocate and partially populate the key structs, including
 * populating the key configuration and allocating space for the keyblob and
 * public key data. The key modes should both indicate ML-DSA-44. The key
 * blob for the secret key should have a length of 2x
 * ceil(kOtcryptoMldsa44SecretKeyBytes / sizeof(uint32_t)) = 1280 words.
 *
 * @param[out] public_key Generated public key.
 * @param[out] secret_key Generated secret key.
 * @param work Work buffer (`kOtcryptoMldsa44WorkBufferKeypairWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mldsa44_keygen(
    otcrypto_unblinded_key_t *public_key, otcrypto_blinded_key_t *secret_key,
    uint32_t work[kOtcryptoMldsa44WorkBufferKeypairWords]);

/**
 * ML-DSA-44 deterministic keypair generation.
 *
 * Generates a public/secret key pair from a given seed.
 *
 * The caller should allocate and partially populate the key structs, including
 * populating the key configuration and allocating space for the keyblob and
 * public key data. The key modes should both indicate ML-DSA-44. The key
 * blob for the secret key should have a length of 2x
 * ceil(kOtcryptoMldsa44SecretKeyBytes / sizeof(uint32_t)) = 1280 words.
 *
 * @param seed Input seed (`kOtcryptoMldsa44SeedBytes` bytes).
 * @param[out] public_key Generated public key.
 * @param[out] secret_key Generated secret key.
 * @param work Work buffer (`kOtcryptoMldsa44WorkBufferKeypairWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mldsa44_keypair_derand(
    otcrypto_const_byte_buf_t seed, otcrypto_unblinded_key_t *public_key,
    otcrypto_blinded_key_t *secret_key,
    uint32_t work[kOtcryptoMldsa44WorkBufferKeypairWords]);

/**
 * ML-DSA-44 signature generation.
 *
 * Generates a signature on a message using fresh randomness.
 *
 * @param secret_key Secret key.
 * @param message Message to sign.
 * @param context Context string (optional, may be empty).
 * @param sign_mode Signature mode.
 * @param[out] signature Pointer to the generated signature.
 * @param work Work buffer (`kOtcryptoMldsa44WorkBufferSignWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mldsa44_sign(
    const otcrypto_blinded_key_t *secret_key, otcrypto_const_byte_buf_t message,
    otcrypto_const_byte_buf_t context, otcrypto_mldsa_sign_mode_t sign_mode,
    otcrypto_byte_buf_t signature,
    uint32_t work[kOtcryptoMldsa44WorkBufferSignWords]);

/**
 * ML-DSA-44 deterministic signature generation.
 *
 * Generates a signature on a message using deterministic randomness.
 *
 * @param secret_key Secret key.
 * @param message Message to sign.
 * @param context Context string (optional, may be empty).
 * @param sign_mode Signature mode.
 * @param rnd Randomness for signing (`kOtcryptoMldsa44SeedBytes` bytes).
 * @param[out] signature Pointer to the generated signature.
 * @param work Work buffer (`kOtcryptoMldsa44WorkBufferSignWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mldsa44_sign_derand(
    const otcrypto_blinded_key_t *secret_key, otcrypto_const_byte_buf_t message,
    otcrypto_const_byte_buf_t context, otcrypto_mldsa_sign_mode_t sign_mode,
    otcrypto_const_byte_buf_t rnd, otcrypto_byte_buf_t signature,
    uint32_t work[kOtcryptoMldsa44WorkBufferSignWords]);

/**
 * ML-DSA-44 signature verification.
 *
 * Verifies a signature on a message.
 *
 * @param public_key Public key.
 * @param message Message that was signed.
 * @param context Context string used during signing.
 * @param sign_mode Signature mode.
 * @param signature Signature to verify.
 * @param[out] verification_result Result of verification (success or failure).
 * @param work Work buffer (`kOtcryptoMldsa44WorkBufferVerifyWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mldsa44_verify(
    const otcrypto_unblinded_key_t *public_key,
    otcrypto_const_byte_buf_t message, otcrypto_const_byte_buf_t context,
    otcrypto_mldsa_sign_mode_t sign_mode, otcrypto_const_byte_buf_t signature,
    hardened_bool_t *verification_result,
    uint32_t work[kOtcryptoMldsa44WorkBufferVerifyWords]);

/**
 * Generates a fresh random ML-DSA-65 key pair.
 *
 * The caller should allocate and partially populate the key structs, including
 * populating the key configuration and allocating space for the keyblob and
 * public key data. The key modes should both indicate ML-DSA-65. The key
 * blob for the secret key should have a length of 2x
 * ceil(kOtcryptoMldsa65SecretKeyBytes / sizeof(uint32_t)) = 2016 words.
 *
 * @param[out] public_key Generated public key.
 * @param[out] secret_key Generated secret key.
 * @param work Work buffer (`kOtcryptoMldsa65WorkBufferKeypairWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mldsa65_keygen(
    otcrypto_unblinded_key_t *public_key, otcrypto_blinded_key_t *secret_key,
    uint32_t work[kOtcryptoMldsa65WorkBufferKeypairWords]);

/**
 * ML-DSA-65 deterministic keypair generation.
 *
 * Generates a public/secret key pair from a given seed.
 *
 * The caller should allocate and partially populate the key structs, including
 * populating the key configuration and allocating space for the keyblob and
 * public key data. The key modes should both indicate ML-DSA-65. The key
 * blob for the secret key should have a length of 2x
 * ceil(kOtcryptoMldsa65SecretKeyBytes / sizeof(uint32_t)) = 2016 words.
 *
 * @param seed Input seed (`kOtcryptoMldsa65SeedBytes` bytes).
 * @param[out] public_key Generated public key.
 * @param[out] secret_key Generated secret key.
 * @param work Work buffer (`kOtcryptoMldsa65WorkBufferKeypairWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mldsa65_keypair_derand(
    otcrypto_const_byte_buf_t seed, otcrypto_unblinded_key_t *public_key,
    otcrypto_blinded_key_t *secret_key,
    uint32_t work[kOtcryptoMldsa65WorkBufferKeypairWords]);

/**
 * ML-DSA-65 signature generation.
 *
 * Generates a signature on a message using fresh randomness.
 *
 * @param secret_key Secret key.
 * @param message Message to sign.
 * @param context Context string (optional, may be empty).
 * @param sign_mode Signature mode.
 * @param[out] signature Pointer to the generated signature.
 * @param work Work buffer (`kOtcryptoMldsa65WorkBufferSignWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mldsa65_sign(
    const otcrypto_blinded_key_t *secret_key, otcrypto_const_byte_buf_t message,
    otcrypto_const_byte_buf_t context, otcrypto_mldsa_sign_mode_t sign_mode,
    otcrypto_byte_buf_t signature,
    uint32_t work[kOtcryptoMldsa65WorkBufferSignWords]);

/**
 * ML-DSA-65 deterministic signature generation.
 *
 * Generates a signature on a message using deterministic randomness.
 *
 * @param secret_key Secret key.
 * @param message Message to sign.
 * @param context Context string (optional, may be empty).
 * @param sign_mode Signature mode.
 * @param rnd Randomness for signing (`kOtcryptoMldsa65SeedBytes` bytes).
 * @param[out] signature Pointer to the generated signature.
 * @param work Work buffer (`kOtcryptoMldsa65WorkBufferSignWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mldsa65_sign_derand(
    const otcrypto_blinded_key_t *secret_key, otcrypto_const_byte_buf_t message,
    otcrypto_const_byte_buf_t context, otcrypto_mldsa_sign_mode_t sign_mode,
    otcrypto_const_byte_buf_t rnd, otcrypto_byte_buf_t signature,
    uint32_t work[kOtcryptoMldsa65WorkBufferSignWords]);

/**
 * ML-DSA-65 signature verification.
 *
 * Verifies a signature on a message.
 *
 * @param public_key Public key.
 * @param message Message that was signed.
 * @param context Context string used during signing.
 * @param sign_mode Signature mode.
 * @param signature Signature to verify.
 * @param[out] verification_result Result of verification (success or failure).
 * @param work Work buffer (`kOtcryptoMldsa65WorkBufferVerifyWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mldsa65_verify(
    const otcrypto_unblinded_key_t *public_key,
    otcrypto_const_byte_buf_t message, otcrypto_const_byte_buf_t context,
    otcrypto_mldsa_sign_mode_t sign_mode, otcrypto_const_byte_buf_t signature,
    hardened_bool_t *verification_result,
    uint32_t work[kOtcryptoMldsa65WorkBufferVerifyWords]);

/**
 * Generates a fresh random ML-DSA-87 key pair.
 *
 * The caller should allocate and partially populate the key structs, including
 * populating the key configuration and allocating space for the keyblob and
 * public key data. The key modes should both indicate ML-DSA-87. The key
 * blob for the secret key should have a length of 2x
 * ceil(kOtcryptoMldsa87SecretKeyBytes / sizeof(uint32_t)) = 2448 words.
 *
 * @param[out] public_key Generated public key.
 * @param[out] secret_key Generated secret key.
 * @param work Work buffer (`kOtcryptoMldsa87WorkBufferKeypairWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mldsa87_keygen(
    otcrypto_unblinded_key_t *public_key, otcrypto_blinded_key_t *secret_key,
    uint32_t work[kOtcryptoMldsa87WorkBufferKeypairWords]);

/**
 * ML-DSA-87 deterministic keypair generation.
 *
 * Generates a public/secret key pair from a given seed.
 *
 * The caller should allocate and partially populate the key structs, including
 * populating the key configuration and allocating space for the keyblob and
 * public key data. The key modes should both indicate ML-DSA-87. The key
 * blob for the secret key should have a length of 2x
 * ceil(kOtcryptoMldsa87SecretKeyBytes / sizeof(uint32_t)) = 2448 words.
 *
 * @param seed Input seed (`kOtcryptoMldsa87SeedBytes` bytes).
 * @param[out] public_key Generated public key.
 * @param[out] secret_key Generated secret key.
 * @param work Work buffer (`kOtcryptoMldsa87WorkBufferKeypairWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mldsa87_keypair_derand(
    otcrypto_const_byte_buf_t seed, otcrypto_unblinded_key_t *public_key,
    otcrypto_blinded_key_t *secret_key,
    uint32_t work[kOtcryptoMldsa87WorkBufferKeypairWords]);

/**
 * ML-DSA-87 signature generation.
 *
 * Generates a signature on a message using fresh randomness.
 *
 * @param secret_key Secret key.
 * @param message Message to sign.
 * @param context Context string (optional, may be empty).
 * @param sign_mode Signature mode.
 * @param[out] signature Pointer to the generated signature.
 * @param work Work buffer (`kOtcryptoMldsa87WorkBufferSignWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mldsa87_sign(
    const otcrypto_blinded_key_t *secret_key, otcrypto_const_byte_buf_t message,
    otcrypto_const_byte_buf_t context, otcrypto_mldsa_sign_mode_t sign_mode,
    otcrypto_byte_buf_t signature,
    uint32_t work[kOtcryptoMldsa87WorkBufferSignWords]);

/**
 * ML-DSA-87 deterministic signature generation.
 *
 * Generates a signature on a message using deterministic randomness.
 *
 * @param secret_key Secret key.
 * @param message Message to sign.
 * @param context Context string (optional, may be empty).
 * @param sign_mode Signature mode.
 * @param rnd Randomness for signing (`kOtcryptoMldsa87SeedBytes` bytes).
 * @param[out] signature Pointer to the generated signature.
 * @param work Work buffer (`kOtcryptoMldsa87WorkBufferSignWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mldsa87_sign_derand(
    const otcrypto_blinded_key_t *secret_key, otcrypto_const_byte_buf_t message,
    otcrypto_const_byte_buf_t context, otcrypto_mldsa_sign_mode_t sign_mode,
    otcrypto_const_byte_buf_t rnd, otcrypto_byte_buf_t signature,
    uint32_t work[kOtcryptoMldsa87WorkBufferSignWords]);

/**
 * ML-DSA-87 signature verification.
 *
 * Verifies a signature on a message.
 *
 * @param public_key Public key.
 * @param message Message that was signed.
 * @param context Context string used during signing.
 * @param sign_mode Signature mode.
 * @param signature Signature to verify.
 * @param[out] verification_result Result of verification (success or failure).
 * @param work Work buffer (`kOtcryptoMldsa87WorkBufferVerifyWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mldsa87_verify(
    const otcrypto_unblinded_key_t *public_key,
    otcrypto_const_byte_buf_t message, otcrypto_const_byte_buf_t context,
    otcrypto_mldsa_sign_mode_t sign_mode, otcrypto_const_byte_buf_t signature,
    hardened_bool_t *verification_result,
    uint32_t work[kOtcryptoMldsa87WorkBufferVerifyWords]);

#ifdef __cplusplus
}  // extern "C"
#endif  // __cplusplus

#endif  // OPENTITAN_SW_DEVICE_LIB_CRYPTO_INCLUDE_MLDSA_H_
