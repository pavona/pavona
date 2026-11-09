// Copyright The mldsa-native project authors
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_LIB_CRYPTO_INCLUDE_MLDSA_H_
#define OPENTITAN_SW_DEVICE_LIB_CRYPTO_INCLUDE_MLDSA_H_

#include "datatypes.h"

/**
 * ML-DSA secret-key blob format (ML-DSA-44/65/87; K/L per parameter set).
 *
 * The unprotected ACC implementation and the software implementation store the
 * secret key in the plain FIPS 204 format:
 *
 *   keyblob = rho(32) || K(32) || tr(64) || s1(L*pe) || s2(K*pe) || t0(K*416)
 *
 * The hardened ACC implementation stores the key masked, in a component-major
 * layout: the public key material, then the two Boolean shares of each
 * bit-sliced secret polynomial (interleaved), then the two shares of K:
 *
 *   keyblob = sk_public(128 + K*416) || s1s2_shares(2*(L+K)*pe) || K_shares(64)
 *
 * where:
 *   sk_public   = rho(32) || 0(32) || tr(64) || t0(K*416): the FIPS 204 public
 *                 key material (rho, tr, t0), unmasked; the 32-byte K slot is
 *                 zeroed (K is carried masked in K_shares)
 *   s1s2_shares = per eta polynomial [share0|share1], each `pe` bytes (Boolean
 *                 shares of the bit-sliced s1/s2, L+K polynomials)
 *   K_shares    = K_share0(32) || K_share1(32)  (Boolean shares, K0 ^ K1 == K)
 *
 * A bit-sliced polynomial holds the b-bit values eta - c of its 256
 * coefficients c (b = 3 for eta=2, 4 for eta=4) as b bit planes of 32 bytes:
 * bit p of byte j in plane i is bit i of the value for coefficient 8*j + p.
 *
 * `pe` is POLYETA_PACKEDBYTES (96 for eta=2, 128 for eta=4). The masked blob is
 * 128 + K*416 + 2*(L+K)*pe + 64 bytes (3392/5504/6400 for ML-DSA-44/65/87), and
 * is also the ACC's DMEM layout, so keygen and signing DMA it straight to/from
 * the accelerator without host-side repacking.
 */

#ifdef __cplusplus
extern "C" {
#endif  // __cplusplus

/**
 * Signature mode for ML-DSA.
 *
 * HashML-DSA with SHA2-224, SHA-512/224, or SHA-512/256 is not supported: the
 * cryptolib does not implement those hash functions (the HMAC/SHA-2 hardware
 * only supports SHA2-256/384/512 digest sizes).
 *
 * Values are hardened.
 *
 * Encoding generated with:
 * $ ./util/design/sparse-fsm-encode.py -d 5 -m 11 -n 16 \
 *     -s 3557426301 --language=c --avoid-zero
 *
 * Minimum Hamming distance: 5
 * Maximum Hamming distance: 14
 * Minimum Hamming weight: 6
 * Maximum Hamming weight: 10
 */
typedef enum otcrypto_mldsa_sign_mode {
  // Signature mode ML-DSA (pure).
  kOtcryptoMldsaSignModeMldsa = 0x037f,
  // Signature mode HashML-DSA with SHA2-256.
  kOtcryptoMldsaSignModeHashMldsaSha2_256 = 0x7413,
  // Signature mode HashML-DSA with SHA2-384.
  kOtcryptoMldsaSignModeHashMldsaSha2_384 = 0x47d5,
  // Signature mode HashML-DSA with SHA2-512.
  kOtcryptoMldsaSignModeHashMldsaSha2_512 = 0x6ad0,
  // Signature mode HashML-DSA with SHA3-224.
  kOtcryptoMldsaSignModeHashMldsaSha3_224 = 0xd752,
  // Signature mode HashML-DSA with SHA3-256.
  kOtcryptoMldsaSignModeHashMldsaSha3_256 = 0x2db4,
  // Signature mode HashML-DSA with SHA3-384.
  kOtcryptoMldsaSignModeHashMldsaSha3_384 = 0x4863,
  // Signature mode HashML-DSA with SHA3-512.
  kOtcryptoMldsaSignModeHashMldsaSha3_512 = 0x51a7,
  // Signature mode HashML-DSA with SHAKE128.
  kOtcryptoMldsaSignModeHashMldsaShake128 = 0xfc8b,
  // Signature mode HashML-DSA with SHAKE256.
  kOtcryptoMldsaSignModeHashMldsaShake256 = 0xe703,
  // Signature mode ML-DSA with an externally-precomputed message
  // representative `mu` (FIPS 204 external-mu variant). `message` must be
  // exactly 64 bytes and `context` must be empty.
  kOtcryptoMldsaSignModeExternalMu = 0xa8ac,
} otcrypto_mldsa_sign_mode_t;

enum {
  kOtcryptoMldsa44PublicKeyBytes = 1312,
  kOtcryptoMldsa44SecretKeyBytes = 2560,
  kOtcryptoMldsa44MaskedSecretKeyBytes = 128 + 4 * 416 + 2 * 8 * 96 + 64,
  kOtcryptoMldsa44SignatureBytes = 2420,
  kOtcryptoMldsa44SeedBytes = 32,
  kOtcryptoMldsa44SeedWords = kOtcryptoMldsa44SeedBytes / sizeof(uint32_t),

  kOtcryptoMldsa65PublicKeyBytes = 1952,
  kOtcryptoMldsa65SecretKeyBytes = 4032,
  kOtcryptoMldsa65MaskedSecretKeyBytes = 128 + 6 * 416 + 2 * 11 * 128 + 64,
  kOtcryptoMldsa65SignatureBytes = 3309,
  kOtcryptoMldsa65SeedBytes = 32,
  kOtcryptoMldsa65SeedWords = kOtcryptoMldsa65SeedBytes / sizeof(uint32_t),

  kOtcryptoMldsa87PublicKeyBytes = 2592,
  kOtcryptoMldsa87SecretKeyBytes = 4896,
  kOtcryptoMldsa87MaskedSecretKeyBytes = 128 + 8 * 416 + 2 * 15 * 96 + 64,
  kOtcryptoMldsa87SignatureBytes = 4627,
  kOtcryptoMldsa87SeedBytes = 32,
  kOtcryptoMldsa87SeedWords = kOtcryptoMldsa87SeedBytes / sizeof(uint32_t),

// Work buffer sizes in 32-bit words. The ACC backends stage inputs and outputs
// in DMEM and need no caller work buffer; only the software backend does.
#ifdef ACC_HAS_PQC
  kOtcryptoMldsa44WorkBufferKeypairWords = 0,
  kOtcryptoMldsa44WorkBufferSignWords = 0,
  kOtcryptoMldsa44WorkBufferVerifyWords = 0,

  kOtcryptoMldsa65WorkBufferKeypairWords = 0,
  kOtcryptoMldsa65WorkBufferSignWords = 0,
  kOtcryptoMldsa65WorkBufferVerifyWords = 0,

  kOtcryptoMldsa87WorkBufferKeypairWords = 0,
  kOtcryptoMldsa87WorkBufferSignWords = 0,
  kOtcryptoMldsa87WorkBufferVerifyWords = 0,
#else
  // Work buffer sizes in 32-bit words
  kOtcryptoMldsa44WorkBufferKeypairWords = 11584 / sizeof(uint32_t),
  kOtcryptoMldsa44WorkBufferSignWords = 13120 / sizeof(uint32_t),
  kOtcryptoMldsa44WorkBufferVerifyWords = 9120 / sizeof(uint32_t),

  kOtcryptoMldsa65WorkBufferKeypairWords = 14656 / sizeof(uint32_t),
  kOtcryptoMldsa65WorkBufferSignWords = 17248 / sizeof(uint32_t),
  kOtcryptoMldsa65WorkBufferVerifyWords = 10208 / sizeof(uint32_t),

  kOtcryptoMldsa87WorkBufferKeypairWords = 18752 / sizeof(uint32_t),
  kOtcryptoMldsa87WorkBufferSignWords = 21344 / sizeof(uint32_t),
  kOtcryptoMldsa87WorkBufferVerifyWords = 12512 / sizeof(uint32_t),
#endif
};

/**
 * Generates a fresh random ML-DSA-44 key pair.
 *
 * The caller should allocate and partially populate the key structs, including
 * populating the key configuration and allocating space for the keyblob and
 * public key data. The key modes should both indicate ML-DSA-44. The key
 * blob for the secret key should have a length of
 * ceil(kOtcryptoMldsa44SecretKeyBytes / sizeof(uint32_t)) = 640 words, or
 * ceil(kOtcryptoMldsa44MaskedSecretKeyBytes / sizeof(uint32_t)) = 848 words
 * for the masked key of a hardened build.
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
 * blob for the secret key should have a length of
 * ceil(kOtcryptoMldsa44SecretKeyBytes / sizeof(uint32_t)) = 640 words, or
 * ceil(kOtcryptoMldsa44MaskedSecretKeyBytes / sizeof(uint32_t)) = 848 words
 * for the masked key of a hardened build.
 *
 * If an unhardened backend is used (either the Ibex-only implementation
 * or the unhardened ACC implementation), then `seed` must have a length of
 * `kOtcryptoMldsa44SeedBytes`. If a hardened implementation is used instead,
 * `seed` must be of length `2 * kOtcryptoMldsa44SeedBytes` with the first and
 * last `kOtcryptoMldsa44SeedBytes` bytes representing binary shares of the key
 * generation seed.
 *
 * @param seed Input seed (`kOtcryptoMldsa44SeedBytes` bytes if using an
 *             unhardened implementation, otherwise
 *             `2 * kOtcryptoMldsa44SeedBytes` bytes).
 * @param[out] public_key Generated public key.
 * @param[out] secret_key Generated secret key.
 * @param work Work buffer (`kOtcryptoMldsa44WorkBufferKeypairWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mldsa44_keypair_derand(
    otcrypto_const_aligned_byte_buf_t seed,
    otcrypto_unblinded_key_t *public_key, otcrypto_blinded_key_t *secret_key,
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
 * @param[out] signature Generated signature, exactly
 *     `kOtcryptoMldsa44SignatureBytes` bytes long.
 * @param work Work buffer (`kOtcryptoMldsa44WorkBufferSignWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mldsa44_sign(
    const otcrypto_blinded_key_t *secret_key, otcrypto_const_byte_buf_t message,
    otcrypto_const_byte_buf_t context, otcrypto_mldsa_sign_mode_t sign_mode,
    otcrypto_aligned_byte_buf_t signature,
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
 * @param[out] signature Generated signature, exactly
 *     `kOtcryptoMldsa44SignatureBytes` bytes long.
 * @param work Work buffer (`kOtcryptoMldsa44WorkBufferSignWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mldsa44_sign_derand(
    const otcrypto_blinded_key_t *secret_key, otcrypto_const_byte_buf_t message,
    otcrypto_const_byte_buf_t context, otcrypto_mldsa_sign_mode_t sign_mode,
    otcrypto_const_aligned_byte_buf_t rnd,
    otcrypto_aligned_byte_buf_t signature,
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
    otcrypto_mldsa_sign_mode_t sign_mode,
    otcrypto_const_aligned_byte_buf_t signature,
    hardened_bool_t *verification_result,
    uint32_t work[kOtcryptoMldsa44WorkBufferVerifyWords]);

/**
 * Generates a fresh random ML-DSA-65 key pair.
 *
 * The caller should allocate and partially populate the key structs, including
 * populating the key configuration and allocating space for the keyblob and
 * public key data. The key modes should both indicate ML-DSA-65. The key
 * blob for the secret key should have a length of
 * ceil(kOtcryptoMldsa65SecretKeyBytes / sizeof(uint32_t)) = 1008 words, or
 * ceil(kOtcryptoMldsa65MaskedSecretKeyBytes / sizeof(uint32_t)) = 1376
 * words for the masked key of a hardened build.
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
 * blob for the secret key should have a length of
 * ceil(kOtcryptoMldsa65SecretKeyBytes / sizeof(uint32_t)) = 1008 words, or
 * ceil(kOtcryptoMldsa65MaskedSecretKeyBytes / sizeof(uint32_t)) = 1376
 * words for the masked key of a hardened build.
 *
 * If an unhardened backend is used (either the Ibex-only implementation
 * or the unhardened ACC implementation), then `seed` must have a length of
 * `kOtcryptoMldsa65SeedBytes`. If a hardened implementation is used instead,
 * `seed` must be of length `2 * kOtcryptoMldsa65SeedBytes` with the first and
 * last `kOtcryptoMldsa65SeedBytes` bytes representing binary shares of the key
 * generation seed.
 *
 * @param seed Input seed (`kOtcryptoMldsa65SeedBytes` bytes if using an
 *             unhardened implementation, otherwise
 *             `2 * kOtcryptoMldsa65SeedBytes` bytes).
 * @param[out] public_key Generated public key.
 * @param[out] secret_key Generated secret key.
 * @param work Work buffer (`kOtcryptoMldsa65WorkBufferKeypairWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mldsa65_keypair_derand(
    otcrypto_const_aligned_byte_buf_t seed,
    otcrypto_unblinded_key_t *public_key, otcrypto_blinded_key_t *secret_key,
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
 * @param[out] signature Generated signature, exactly
 *     `kOtcryptoMldsa65SignatureBytes` bytes long.
 * @param work Work buffer (`kOtcryptoMldsa65WorkBufferSignWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mldsa65_sign(
    const otcrypto_blinded_key_t *secret_key, otcrypto_const_byte_buf_t message,
    otcrypto_const_byte_buf_t context, otcrypto_mldsa_sign_mode_t sign_mode,
    otcrypto_aligned_byte_buf_t signature,
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
 * @param[out] signature Generated signature, exactly
 *     `kOtcryptoMldsa65SignatureBytes` bytes long.
 * @param work Work buffer (`kOtcryptoMldsa65WorkBufferSignWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mldsa65_sign_derand(
    const otcrypto_blinded_key_t *secret_key, otcrypto_const_byte_buf_t message,
    otcrypto_const_byte_buf_t context, otcrypto_mldsa_sign_mode_t sign_mode,
    otcrypto_const_aligned_byte_buf_t rnd,
    otcrypto_aligned_byte_buf_t signature,
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
    otcrypto_mldsa_sign_mode_t sign_mode,
    otcrypto_const_aligned_byte_buf_t signature,
    hardened_bool_t *verification_result,
    uint32_t work[kOtcryptoMldsa65WorkBufferVerifyWords]);

/**
 * Generates a fresh random ML-DSA-87 key pair.
 *
 * The caller should allocate and partially populate the key structs, including
 * populating the key configuration and allocating space for the keyblob and
 * public key data. The key modes should both indicate ML-DSA-87. The key
 * blob for the secret key should have a length of
 * ceil(kOtcryptoMldsa87SecretKeyBytes / sizeof(uint32_t)) = 1224 words, or
 * ceil(kOtcryptoMldsa87MaskedSecretKeyBytes / sizeof(uint32_t)) = 1600
 * words for the masked key of a hardened build.
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
 * blob for the secret key should have a length of
 * ceil(kOtcryptoMldsa87SecretKeyBytes / sizeof(uint32_t)) = 1224 words, or
 * ceil(kOtcryptoMldsa87MaskedSecretKeyBytes / sizeof(uint32_t)) = 1600
 * words for the masked key of a hardened build.
 *
 * If an unhardened backend is used (either the Ibex-only implementation
 * or the unhardened ACC implementation), then `seed` must have a length of
 * `kOtcryptoMldsa87SeedBytes`. If a hardened implementation is used instead,
 * `seed` must be of length `2 * kOtcryptoMldsa87SeedBytes` with the first and
 * last `kOtcryptoMldsa87SeedBytes` bytes representing binary shares of the key
 * generation seed.
 *
 * @param seed Input seed (`kOtcryptoMldsa87SeedBytes` bytes if using an
 *             unhardened implementation, otherwise
 *             `2 * kOtcryptoMldsa87SeedBytes` bytes).
 * @param[out] public_key Generated public key.
 * @param[out] secret_key Generated secret key.
 * @param work Work buffer (`kOtcryptoMldsa87WorkBufferKeypairWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mldsa87_keypair_derand(
    otcrypto_const_aligned_byte_buf_t seed,
    otcrypto_unblinded_key_t *public_key, otcrypto_blinded_key_t *secret_key,
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
 * @param[out] signature Generated signature, exactly
 *     `kOtcryptoMldsa87SignatureBytes` bytes long.
 * @param work Work buffer (`kOtcryptoMldsa87WorkBufferSignWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mldsa87_sign(
    const otcrypto_blinded_key_t *secret_key, otcrypto_const_byte_buf_t message,
    otcrypto_const_byte_buf_t context, otcrypto_mldsa_sign_mode_t sign_mode,
    otcrypto_aligned_byte_buf_t signature,
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
 * @param[out] signature Generated signature, exactly
 *     `kOtcryptoMldsa87SignatureBytes` bytes long.
 * @param work Work buffer (`kOtcryptoMldsa87WorkBufferSignWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mldsa87_sign_derand(
    const otcrypto_blinded_key_t *secret_key, otcrypto_const_byte_buf_t message,
    otcrypto_const_byte_buf_t context, otcrypto_mldsa_sign_mode_t sign_mode,
    otcrypto_const_aligned_byte_buf_t rnd,
    otcrypto_aligned_byte_buf_t signature,
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
    otcrypto_mldsa_sign_mode_t sign_mode,
    otcrypto_const_aligned_byte_buf_t signature,
    hardened_bool_t *verification_result,
    uint32_t work[kOtcryptoMldsa87WorkBufferVerifyWords]);

#ifdef __cplusplus
}  // extern "C"
#endif  // __cplusplus

#endif  // OPENTITAN_SW_DEVICE_LIB_CRYPTO_INCLUDE_MLDSA_H_
