// Copyright The mlkem-native project authors
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_LIB_CRYPTO_INCLUDE_MLKEM_H_
#define OPENTITAN_SW_DEVICE_LIB_CRYPTO_INCLUDE_MLKEM_H_

#include "datatypes.h"

#ifdef __cplusplus
extern "C" {
#endif  // __cplusplus

enum {
  kOtcryptoMlkem512PublicKeyBytes = 800,
  kOtcryptoMlkem512SecretKeyBytes = 1632,
  kOtcryptoMlkem512CiphertextBytes = 768,
  kOtcryptoMlkem512SharedSecretBytes = 32,
  kOtcryptoMlkem512KeygenSeedBytes = 64,

  kOtcryptoMlkem768PublicKeyBytes = 1184,
  kOtcryptoMlkem768SecretKeyBytes = 2400,
  kOtcryptoMlkem768CiphertextBytes = 1088,
  kOtcryptoMlkem768SharedSecretBytes = 32,
  kOtcryptoMlkem768KeygenSeedBytes = 64,

  kOtcryptoMlkem1024PublicKeyBytes = 1568,
  kOtcryptoMlkem1024SecretKeyBytes = 3168,
  kOtcryptoMlkem1024CiphertextBytes = 1568,
  kOtcryptoMlkem1024SharedSecretBytes = 32,
  kOtcryptoMlkem1024KeygenSeedBytes = 64,

  // Work buffer sizes in 32-bit words
  kOtcryptoMlkem512WorkBufferKeypairWords = 5824 / sizeof(uint32_t),
  kOtcryptoMlkem512WorkBufferEncapsWords = 8384 / sizeof(uint32_t),
  kOtcryptoMlkem512WorkBufferDecapsWords = 9152 / sizeof(uint32_t),

  kOtcryptoMlkem768WorkBufferKeypairWords = 10176 / sizeof(uint32_t),
  kOtcryptoMlkem768WorkBufferEncapsWords = 13248 / sizeof(uint32_t),
  kOtcryptoMlkem768WorkBufferDecapsWords = 14336 / sizeof(uint32_t),

  kOtcryptoMlkem1024WorkBufferKeypairWords = 15552 / sizeof(uint32_t),
  kOtcryptoMlkem1024WorkBufferEncapsWords = 19136 / sizeof(uint32_t),
  kOtcryptoMlkem1024WorkBufferDecapsWords = 20704 / sizeof(uint32_t),
};

/**
 * Generates a fresh random ML-KEM-512 key pair.
 *
 * The caller should allocate and partially populate the key structs, including
 * populating the key configuration and allocating space for the keyblob and
 * public key data. The key modes should both indicate ML-KEM-512. The key
 * blob for the private key should have a length of 2x
 * ceil(kOtCryptoMlkem512SecretKeybytes / sizeof(uint32_t)) = 816 words.
 *
 * @param[out] pk public key dest, len >= `kOtcryptoMlKemPublicKeyBytes`.
 * @param[out] sk secret key dest, unmasked len `kOtcryptoMlKemSecretKeyBytes`.
 * @param work Work buffer (`kOtcryptoMlkem512WorkBufferKeypairWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mlkem512_keygen(
    otcrypto_unblinded_key_t *public_key, otcrypto_blinded_key_t *secret_key,
    uint32_t work[kOtcryptoMlkem512WorkBufferKeypairWords]);

/**
 * Generates an ML-KEM-512 key pair based on caller-provided randomness.
 *
 * The caller should allocate and partially populate the key structs, including
 * populating the key configuration and allocating space for the keyblob and
 * public key data. The key modes should both indicate ML-KEM-512. The key
 * blob for the private key should have a length of 2x
 * ceil(kOtCryptoMlkem512SecretKeybytes / sizeof(uint32_t)) = 816 words.
 *
 * @param randomness seed for keygen, len `kOtcryptoMlkem512KeygenSeedBytes`.
 * @param[out] pk public key dest, len >= `kOtcryptoMlKemPublicKeyBytes`.
 * @param[out] sk secret key dest, unmasked len `kOtcryptoMlKemSecretKeyBytes`.
 * @param work Work buffer (`kOtcryptoMlkem512WorkBufferKeypairWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mlkem512_keygen_derand(
    otcrypto_const_byte_buf_t randomness, otcrypto_unblinded_key_t *public_key,
    otcrypto_blinded_key_t *secret_key,
    uint32_t work[kOtcryptoMlkem512WorkBufferKeypairWords]);

/**
 * Generates ciphertext and shared secret for the given public key.
 *
 * The caller should allocate and partially populate the destination shared
 * secret key struct, including populating the key configuration and allocating
 * space for the keyblob and public key data. The key length should be
 * `kOtcryptoMlkem512SharedSecretBytes` and the key blob should have a length
 * of 2x that value rounded up to the next 32-bit word boundary.
 *
 * @param pk public key for which to generate ciphertext/shared secret
 * @param[out] ciphertext buffer of len `kOtcryptoMlkem512CiphertextBytes`.
 * @param[out] shared_secret dest key, len `kOtcryptoMlkem512SharedSecretBytes`.
 * @param work Work buffer (`kOtcryptoMlkem512WorkBufferEncapsWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mlkem512_encapsulate(
    const otcrypto_unblinded_key_t *public_key, otcrypto_byte_buf_t ciphertext,
    otcrypto_blinded_key_t *shared_secret,
    uint32_t work[kOtcryptoMlkem512WorkBufferEncapsWords]);

/**
 * Generates ciphertext and shared secret for the given public key.
 *
 * The caller should allocate and partially populate the destination shared
 * secret key struct, including populating the key configuration and allocating
 * space for the keyblob and public key data. The key length should be
 * `kOtcryptoMlkem512SharedSecretBytes` and the key blob should have a length
 * of 2x that value rounded up to the next 32-bit word boundary.
 *
 * @param public_key public key for which to generate ciphertext/shared secret.
 * @param randomness seed for encapsulate, len 32 bytes.
 * @param[out] ciphertext buffer of len `kOtcryptoMlkem512CiphertextBytes`.
 * @param[out] shared_secret dest key, len `kOtcryptoMlkem512SharedSecretBytes`.
 * @param work Work buffer (`kOtcryptoMlkem512WorkBufferEncapsWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mlkem512_encapsulate_derand(
    const otcrypto_unblinded_key_t *public_key,
    otcrypto_const_byte_buf_t randomness, otcrypto_byte_buf_t ciphertext,
    otcrypto_blinded_key_t *shared_secret,
    uint32_t work[kOtcryptoMlkem512WorkBufferEncapsWords]);

/**
 * Generates shared secret for the given ciphertext and private key.
 *
 * The caller should allocate and partially populate the destination shared
 * secret key struct, including populating the key configuration and allocating
 * space for the keyblob and public key data. The key length should be
 * `kOtcryptoMlkem512SharedSecretBytes` and the key blob should have a length
 * of 2x that value rounded up to the next 32-bit word boundary.
 *
 * @param secret_key decapsulation key for which ciphertext was created.
 * @param ciphertext buffer of len `kOtcryptoMlkem512CiphertextBytes`.
 * @param[out] shared_secret dest key, len `kOtcryptoMlkem512SharedSecretBytes`.
 * @param work Work buffer (`kOtcryptoMlkem512WorkBufferDecapsWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mlkem512_decapsulate(
    const otcrypto_blinded_key_t *secret_key,
    otcrypto_const_byte_buf_t ciphertext, otcrypto_blinded_key_t *shared_secret,
    uint32_t work[kOtcryptoMlkem512WorkBufferDecapsWords]);

/**
 * Generates a fresh random ML-KEM-768 key pair.
 *
 * The caller should allocate and partially populate the key structs, including
 * populating the key configuration and allocating space for the keyblob and
 * public key data. The key modes should both indicate ML-KEM-768. The key
 * blob for the private key should have a length of 2x
 * ceil(kOtCryptoMlkem768SecretKeybytes / sizeof(uint32_t)) = 1200 words.
 *
 * @param[out] pk public key dest, len >= `kOtcryptoMlKemPublicKeyBytes`.
 * @param[out] sk secret key dest, unmasked len `kOtcryptoMlKemSecretKeyBytes`.
 * @param work Work buffer (`kOtcryptoMlkem768WorkBufferKeypairWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mlkem768_keygen(
    otcrypto_unblinded_key_t *public_key, otcrypto_blinded_key_t *secret_key,
    uint32_t work[kOtcryptoMlkem768WorkBufferKeypairWords]);

/**
 * Generates an ML-KEM-768 key pair based on caller-provided randomness.
 *
 * The caller should allocate and partially populate the key structs, including
 * populating the key configuration and allocating space for the keyblob and
 * public key data. The key modes should both indicate ML-KEM-768. The key
 * blob for the private key should have a length of 2x
 * ceil(kOtCryptoMlkem768SecretKeybytes / sizeof(uint32_t)) = 1200 words.
 *
 * @param randomness seed for keygen, len `kOtcryptoMlkem768KeygenSeedBytes`.
 * @param[out] pk public key dest, len >= `kOtcryptoMlKemPublicKeyBytes`.
 * @param[out] sk secret key dest, unmasked len `kOtcryptoMlKemSecretKeyBytes`.
 * @param work Work buffer (`kOtcryptoMlkem768WorkBufferKeypairWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mlkem768_keygen_derand(
    otcrypto_const_byte_buf_t randomness, otcrypto_unblinded_key_t *public_key,
    otcrypto_blinded_key_t *secret_key,
    uint32_t work[kOtcryptoMlkem768WorkBufferKeypairWords]);

/**
 * Generates ciphertext and shared secret for the given public key.
 *
 * The caller should allocate and partially populate the destination shared
 * secret key struct, including populating the key configuration and allocating
 * space for the keyblob and public key data. The key length should be
 * `kOtcryptoMlkem768SharedSecretBytes` and the key blob should have a length
 * of 2x that value rounded up to the next 32-bit word boundary.
 *
 * @param pk public key for which to generate ciphertext/shared secret
 * @param[out] ciphertext buffer of len `kOtcryptoMlkem768CiphertextBytes`.
 * @param[out] shared_secret dest key, len `kOtcryptoMlkem768SharedSecretBytes`.
 * @param work Work buffer (`kOtcryptoMlkem768WorkBufferEncapsWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mlkem768_encapsulate(
    const otcrypto_unblinded_key_t *public_key, otcrypto_byte_buf_t ciphertext,
    otcrypto_blinded_key_t *shared_secret,
    uint32_t work[kOtcryptoMlkem768WorkBufferEncapsWords]);

/**
 * Generates ciphertext and shared secret for the given public key.
 *
 * The caller should allocate and partially populate the destination shared
 * secret key struct, including populating the key configuration and allocating
 * space for the keyblob and public key data. The key length should be
 * `kOtcryptoMlkem768SharedSecretBytes` and the key blob should have a length
 * of 2x that value rounded up to the next 32-bit word boundary.
 *
 * @param public_key public key for which to generate ciphertext/shared secret.
 * @param randomness seed for encapsulate, len 32 bytes.
 * @param[out] ciphertext buffer of len `kOtcryptoMlkem768CiphertextBytes`.
 * @param[out] shared_secret dest key, len `kOtcryptoMlkem768SharedSecretBytes`.
 * @param work Work buffer (`kOtcryptoMlkem768WorkBufferEncapsWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mlkem768_encapsulate_derand(
    const otcrypto_unblinded_key_t *public_key,
    otcrypto_const_byte_buf_t randomness, otcrypto_byte_buf_t ciphertext,
    otcrypto_blinded_key_t *shared_secret,
    uint32_t work[kOtcryptoMlkem768WorkBufferEncapsWords]);

/**
 * Generates shared secret for the given ciphertext and private key.
 *
 * The caller should allocate and partially populate the destination shared
 * secret key struct, including populating the key configuration and allocating
 * space for the keyblob and public key data. The key length should be
 * `kOtcryptoMlkem768SharedSecretBytes` and the key blob should have a length
 * of 2x that value rounded up to the next 32-bit word boundary.
 *
 * @param secret_key decapsulation key for which ciphertext was created.
 * @param ciphertext buffer of len `kOtcryptoMlkem768CiphertextBytes`.
 * @param[out] shared_secret dest key, len `kOtcryptoMlkem768SharedSecretBytes`.
 * @param work Work buffer (`kOtcryptoMlkem768WorkBufferDecapsWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mlkem768_decapsulate(
    const otcrypto_blinded_key_t *secret_key,
    otcrypto_const_byte_buf_t ciphertext, otcrypto_blinded_key_t *shared_secret,
    uint32_t work[kOtcryptoMlkem768WorkBufferDecapsWords]);

/**
 * Generates a fresh random ML-KEM-1024 key pair.
 *
 * The caller should allocate and partially populate the key structs, including
 * populating the key configuration and allocating space for the keyblob and
 * public key data. The key modes should both indicate ML-KEM-1024. The key
 * blob for the private key should have a length of 2x
 * ceil(kOtCryptoMlkem1024SecretKeybytes / sizeof(uint32_t)) = 1584 words.
 *
 * @param[out] pk public key dest, len >= `kOtcryptoMlKemPublicKeyBytes`.
 * @param[out] sk secret key dest, unmasked len `kOtcryptoMlKemSecretKeyBytes`.
 * @param work Work buffer (`kOtcryptoMlkem1024WorkBufferKeypairWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mlkem1024_keygen(
    otcrypto_unblinded_key_t *public_key, otcrypto_blinded_key_t *secret_key,
    uint32_t work[kOtcryptoMlkem1024WorkBufferKeypairWords]);

/**
 * Generates an ML-KEM-1024 key pair based on caller-provided randomness.
 *
 * The caller should allocate and partially populate the key structs, including
 * populating the key configuration and allocating space for the keyblob and
 * public key data. The key modes should both indicate ML-KEM-1024. The key
 * blob for the private key should have a length of 2x
 * ceil(kOtCryptoMlkem1024SecretKeybytes / sizeof(uint32_t)) = 1584 words.
 *
 * @param randomness seed for keygen, len `kOtcryptoMlkem1024KeygenSeedBytes`.
 * @param[out] pk public key dest, len >= `kOtcryptoMlKemPublicKeyBytes`.
 * @param[out] sk secret key dest, unmasked len `kOtcryptoMlKemSecretKeyBytes`.
 * @param work Work buffer (`kOtcryptoMlkem1024WorkBufferKeypairWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mlkem1024_keygen_derand(
    otcrypto_const_byte_buf_t randomness, otcrypto_unblinded_key_t *public_key,
    otcrypto_blinded_key_t *secret_key,
    uint32_t work[kOtcryptoMlkem1024WorkBufferKeypairWords]);

/**
 * Generates ciphertext and shared secret for the given public key.
 *
 * The caller should allocate and partially populate the destination shared
 * secret key struct, including populating the key configuration and allocating
 * space for the keyblob and public key data. The key length should be
 * `kOtcryptoMlkem1024SharedSecretBytes` and the key blob should have a length
 * of 2x that value rounded up to the next 32-bit word boundary.
 *
 * @param pk public key for which to generate ciphertext/shared secret
 * @param[out] ciphertext buffer of len `kOtcryptoMlkem1024CiphertextBytes`.
 * @param[out] shared_secret dest key, len
 * `kOtcryptoMlkem1024SharedSecretBytes`.
 * @param work Work buffer (`kOtcryptoMlkem1024WorkBufferEncapsWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mlkem1024_encapsulate(
    const otcrypto_unblinded_key_t *public_key, otcrypto_byte_buf_t ciphertext,
    otcrypto_blinded_key_t *shared_secret,
    uint32_t work[kOtcryptoMlkem1024WorkBufferEncapsWords]);

/**
 * Generates ciphertext and shared secret for the given public key.
 *
 * The caller should allocate and partially populate the destination shared
 * secret key struct, including populating the key configuration and allocating
 * space for the keyblob and public key data. The key length should be
 * `kOtcryptoMlkem1024SharedSecretBytes` and the key blob should have a length
 * of 2x that value rounded up to the next 32-bit word boundary.
 *
 * @param public_key public key for which to generate ciphertext/shared secret.
 * @param randomness seed for encapsulate, len 32 bytes.
 * @param[out] ciphertext buffer of len `kOtcryptoMlkem1024CiphertextBytes`.
 * @param[out] shared_secret dest key, len
 * `kOtcryptoMlkem1024SharedSecretBytes`.
 * @param work Work buffer (`kOtcryptoMlkem1024WorkBufferEncapsWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mlkem1024_encapsulate_derand(
    const otcrypto_unblinded_key_t *public_key,
    otcrypto_const_byte_buf_t randomness, otcrypto_byte_buf_t ciphertext,
    otcrypto_blinded_key_t *shared_secret,
    uint32_t work[kOtcryptoMlkem1024WorkBufferEncapsWords]);

/**
 * Generates shared secret for the given ciphertext and private key.
 *
 * The caller should allocate and partially populate the destination shared
 * secret key struct, including populating the key configuration and allocating
 * space for the keyblob and public key data. The key length should be
 * `kOtcryptoMlkem1024SharedSecretBytes` and the key blob should have a length
 * of 2x that value rounded up to the next 32-bit word boundary.
 *
 * @param secret_key decapsulation key for which ciphertext was created.
 * @param ciphertext buffer of len `kOtcryptoMlkem1024CiphertextBytes`.
 * @param[out] shared_secret dest key, len
 * `kOtcryptoMlkem1024SharedSecretBytes`.
 * @param work Work buffer (`kOtcryptoMlkem1024WorkBufferDecapsWords` words).
 * @return Status code (OK or error).
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_mlkem1024_decapsulate(
    const otcrypto_blinded_key_t *secret_key,
    otcrypto_const_byte_buf_t ciphertext, otcrypto_blinded_key_t *shared_secret,
    uint32_t work[kOtcryptoMlkem1024WorkBufferDecapsWords]);

#ifdef __cplusplus
}  // extern "C"
#endif  // __cplusplus

#endif  // OPENTITAN_SW_DEVICE_LIB_CRYPTO_INCLUDE_MLKEM_H_
