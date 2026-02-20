// Copyright The mlkem-native project authors
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/crypto/include/mlkem.h"

#include "sw/device/lib/base/math.h"
#include "sw/device/lib/crypto/drivers/entropy.h"
#include "sw/device/lib/crypto/impl/integrity.h"
#include "sw/device/lib/crypto/impl/keyblob.h"
#include "sw/device/lib/crypto/impl/mlkem/mlkem_native_alloc.h"
#include "sw/device/lib/crypto/impl/mlkem/mlkem_native_monobuild.h"
#include "sw/device/lib/crypto/impl/status.h"

// Module ID for status codes.
#define MODULE_ID MAKE_MODULE_ID('m', 'l', 'k')

// Static assertions to verify buffer sizes match mlkem-native
_Static_assert(kOtcryptoMlkem512WorkBufferKeypairWords * sizeof(uint32_t) ==
                   MLK_TOTAL_ALLOC_512_KEYPAIR,
               "ML-KEM-512 keypair work buffer size mismatch");
_Static_assert(kOtcryptoMlkem512WorkBufferEncapsWords * sizeof(uint32_t) ==
                   MLK_TOTAL_ALLOC_512_ENCAPS,
               "ML-KEM-512 encaps work buffer size mismatch");
_Static_assert(kOtcryptoMlkem512WorkBufferDecapsWords * sizeof(uint32_t) ==
                   MLK_TOTAL_ALLOC_512_DECAPS,
               "ML-KEM-512 decaps work buffer size mismatch");

_Static_assert(kOtcryptoMlkem768WorkBufferKeypairWords * sizeof(uint32_t) ==
                   MLK_TOTAL_ALLOC_768_KEYPAIR,
               "ML-KEM-768 keypair work buffer size mismatch");
_Static_assert(kOtcryptoMlkem768WorkBufferEncapsWords * sizeof(uint32_t) ==
                   MLK_TOTAL_ALLOC_768_ENCAPS,
               "ML-KEM-768 encaps work buffer size mismatch");
_Static_assert(kOtcryptoMlkem768WorkBufferDecapsWords * sizeof(uint32_t) ==
                   MLK_TOTAL_ALLOC_768_DECAPS,
               "ML-KEM-768 decaps work buffer size mismatch");

_Static_assert(kOtcryptoMlkem1024WorkBufferKeypairWords * sizeof(uint32_t) ==
                   MLK_TOTAL_ALLOC_1024_KEYPAIR,
               "ML-KEM-1024 keypair work buffer size mismatch");
_Static_assert(kOtcryptoMlkem1024WorkBufferEncapsWords * sizeof(uint32_t) ==
                   MLK_TOTAL_ALLOC_1024_ENCAPS,
               "ML-KEM-1024 encaps work buffer size mismatch");
_Static_assert(kOtcryptoMlkem1024WorkBufferDecapsWords * sizeof(uint32_t) ==
                   MLK_TOTAL_ALLOC_1024_DECAPS,
               "ML-KEM-1024 decaps work buffer size mismatch");

// ML-KEM-512 functions

otcrypto_status_t otcrypto_mlkem512_keygen_derand(
    otcrypto_const_byte_buf_t randomness, otcrypto_unblinded_key_t *public_key,
    otcrypto_blinded_key_t *secret_key,
    uint32_t work[kOtcryptoMlkem512WorkBufferKeypairWords]) {
  if (randomness.len != 2 * MLKEM512_BYTES) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (public_key->key_length != MLKEM512_PUBLICKEYBYTES) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.key_length != MLKEM512_SECRETKEYBYTES) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.key_mode != kOtcryptoKeyModeMlkem512) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.security_level !=
      kOtcryptoKeySecurityLevelPassiveRemote) {
    // Reject high-security keys; the underlying implementation is not masked
    // against power side channels.
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.hw_backed != kHardenedBoolFalse) {
    return OTCRYPTO_NOT_IMPLEMENTED;
  }

  // Write the unmasked secret key into the first share of the keyblob.
  uint32_t *sk_share0;
  uint32_t *sk_share1;
  HARDENED_TRY(keyblob_to_shares(secret_key, &sk_share0, &sk_share1));
  memset(sk_share1, 0, MLKEM512_SECRETKEYBYTES);

  mlk_alloc_ctx_t ctx = {.base = work,
                         .size_words = kOtcryptoMlkem512WorkBufferKeypairWords,
                         .offset_words = 0};
  int result = mlkem512_keypair_derand((unsigned char *)public_key->key,
                                       (unsigned char *)sk_share0,
                                       randomness.data, &ctx);
  if (result != 0) {
    memset(sk_share0, 0, MLKEM512_SECRETKEYBYTES);
    return OTCRYPTO_FATAL_ERR;
  }

  public_key->checksum = integrity_unblinded_checksum(public_key);
  secret_key->checksum = integrity_blinded_checksum(secret_key);

  return OTCRYPTO_OK;
}

otcrypto_status_t otcrypto_mlkem512_encapsulate_derand(
    const otcrypto_unblinded_key_t *public_key,
    otcrypto_const_byte_buf_t randomness, otcrypto_byte_buf_t ciphertext,
    otcrypto_blinded_key_t *shared_secret,
    uint32_t work[kOtcryptoMlkem512WorkBufferEncapsWords]) {
  if (public_key->key_length != MLKEM512_PUBLICKEYBYTES) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (public_key->key_mode != kOtcryptoKeyModeMlkem512) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (randomness.len != MLKEM512_BYTES) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (ciphertext.len != MLKEM512_CIPHERTEXTBYTES) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (shared_secret->config.key_length != MLKEM512_BYTES) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (shared_secret->config.hw_backed != kHardenedBoolFalse) {
    // Shared secret cannot be a hardware-backed key.
    return OTCRYPTO_BAD_ARGS;
  }
  if (shared_secret->config.security_level !=
      kOtcryptoKeySecurityLevelPassiveRemote) {
    // Reject high-security keys; the underlying implementation is not masked
    // against power side channels.
    return OTCRYPTO_BAD_ARGS;
  }
  if (integrity_unblinded_key_check(public_key) != kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (integrity_blinded_key_check(shared_secret) != kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Write the unmasked shared secret into the first share of the keyblob.
  uint32_t *ss_share0;
  uint32_t *ss_share1;
  HARDENED_TRY(keyblob_to_shares(shared_secret, &ss_share0, &ss_share1));
  memset(ss_share1, 0, MLKEM512_BYTES);

  mlk_alloc_ctx_t ctx = {.base = work,
                         .size_words = kOtcryptoMlkem512WorkBufferEncapsWords,
                         .offset_words = 0};
  int result = mlkem512_enc_derand(ciphertext.data, (unsigned char *)ss_share0,
                                   (unsigned char *)public_key->key,
                                   randomness.data, &ctx);
  if (result != 0) {
    memset(ss_share0, 0, MLKEM512_BYTES);
    return OTCRYPTO_FATAL_ERR;
  }

  shared_secret->checksum = integrity_blinded_checksum(shared_secret);

  return OTCRYPTO_OK;
}

otcrypto_status_t otcrypto_mlkem512_keygen(
    otcrypto_unblinded_key_t *public_key, otcrypto_blinded_key_t *secret_key,
    uint32_t work[kOtcryptoMlkem512WorkBufferKeypairWords]) {
  HARDENED_TRY(entropy_complex_check());

  uint32_t randomness[ceil_div(2 * MLKEM512_BYTES, sizeof(uint32_t))];
  HARDENED_TRY(entropy_csrng_instantiate(
      /*disable_trng_input=*/kHardenedBoolFalse, &kEntropyEmptySeed));
  HARDENED_TRY(entropy_csrng_generate(&kEntropyEmptySeed, randomness,
                                      ARRAYSIZE(randomness),
                                      /*fips_check=*/kHardenedBoolTrue));
  HARDENED_TRY(entropy_csrng_uninstantiate());

  otcrypto_const_byte_buf_t randomness_buf = {
      .data = (unsigned char *)randomness, .len = sizeof(randomness)};
  return otcrypto_mlkem512_keygen_derand(randomness_buf, public_key, secret_key,
                                         work);
}

otcrypto_status_t otcrypto_mlkem512_encapsulate(
    const otcrypto_unblinded_key_t *public_key, otcrypto_byte_buf_t ciphertext,
    otcrypto_blinded_key_t *shared_secret,
    uint32_t work[kOtcryptoMlkem512WorkBufferEncapsWords]) {
  HARDENED_TRY(entropy_complex_check());

  uint32_t randomness[ceil_div(MLKEM512_BYTES, sizeof(uint32_t))];
  HARDENED_TRY(entropy_csrng_instantiate(
      /*disable_trng_input=*/kHardenedBoolFalse, &kEntropyEmptySeed));
  HARDENED_TRY(entropy_csrng_generate(&kEntropyEmptySeed, randomness,
                                      ARRAYSIZE(randomness),
                                      /*fips_check=*/kHardenedBoolTrue));
  HARDENED_TRY(entropy_csrng_uninstantiate());

  otcrypto_const_byte_buf_t randomness_buf = {
      .data = (unsigned char *)randomness, .len = sizeof(randomness)};
  return otcrypto_mlkem512_encapsulate_derand(public_key, randomness_buf,
                                              ciphertext, shared_secret, work);
}

otcrypto_status_t otcrypto_mlkem512_decapsulate(
    const otcrypto_blinded_key_t *secret_key,
    otcrypto_const_byte_buf_t ciphertext, otcrypto_blinded_key_t *shared_secret,
    uint32_t work[kOtcryptoMlkem512WorkBufferDecapsWords]) {
  if (secret_key->config.key_length != MLKEM512_SECRETKEYBYTES) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.key_mode != kOtcryptoKeyModeMlkem512) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.security_level !=
      kOtcryptoKeySecurityLevelPassiveRemote) {
    // Reject high-security keys; the underlying implementation is not masked
    // against power side channels.
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.hw_backed != kHardenedBoolFalse) {
    return OTCRYPTO_NOT_IMPLEMENTED;
  }
  if (ciphertext.len != MLKEM512_CIPHERTEXTBYTES) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (shared_secret->config.key_length != MLKEM512_BYTES) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (shared_secret->config.hw_backed != kHardenedBoolFalse) {
    // Shared secret cannot be a hardware-backed key.
    return OTCRYPTO_BAD_ARGS;
  }
  if (shared_secret->config.security_level !=
      kOtcryptoKeySecurityLevelPassiveRemote) {
    // Reject high-security keys; the underlying implementation is not masked
    // against power side channels.
    return OTCRYPTO_BAD_ARGS;
  }
  if (integrity_blinded_key_check(secret_key) != kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Secret keys are stored unmasked in share0 (share1 is zero).
  uint32_t *sk_share0;
  uint32_t *sk_share1;
  HARDENED_TRY(keyblob_to_shares(secret_key, &sk_share0, &sk_share1));

  // Write the unmasked shared secret into the first share of the keyblob.
  uint32_t *ss_share0;
  uint32_t *ss_share1;
  HARDENED_TRY(keyblob_to_shares(shared_secret, &ss_share0, &ss_share1));
  memset(ss_share1, 0, MLKEM512_BYTES);

  mlk_alloc_ctx_t ctx = {.base = work,
                         .size_words = kOtcryptoMlkem512WorkBufferDecapsWords,
                         .offset_words = 0};
  int result = mlkem512_dec((unsigned char *)ss_share0, ciphertext.data,
                            (unsigned char *)sk_share0, &ctx);
  if (result != 0) {
    memset(ss_share0, 0, MLKEM512_BYTES);
    return OTCRYPTO_FATAL_ERR;
  }

  return OTCRYPTO_OK;
}

// ML-KEM-768 functions

otcrypto_status_t otcrypto_mlkem768_keygen_derand(
    otcrypto_const_byte_buf_t randomness, otcrypto_unblinded_key_t *public_key,
    otcrypto_blinded_key_t *secret_key,
    uint32_t work[kOtcryptoMlkem768WorkBufferKeypairWords]) {
  if (randomness.len != 2 * MLKEM768_BYTES) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (public_key->key_length != MLKEM768_PUBLICKEYBYTES) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.key_length != MLKEM768_SECRETKEYBYTES) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.key_mode != kOtcryptoKeyModeMlkem768) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.security_level !=
      kOtcryptoKeySecurityLevelPassiveRemote) {
    // Reject high-security keys; the underlying implementation is not masked
    // against power side channels.
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.hw_backed != kHardenedBoolFalse) {
    return OTCRYPTO_NOT_IMPLEMENTED;
  }

  // Write the unmasked secret key into the first share of the keyblob.
  uint32_t *sk_share0;
  uint32_t *sk_share1;
  HARDENED_TRY(keyblob_to_shares(secret_key, &sk_share0, &sk_share1));
  memset(sk_share1, 0, MLKEM768_SECRETKEYBYTES);

  mlk_alloc_ctx_t ctx = {.base = work,
                         .size_words = kOtcryptoMlkem768WorkBufferKeypairWords,
                         .offset_words = 0};
  int result = mlkem768_keypair_derand((unsigned char *)public_key->key,
                                       (unsigned char *)sk_share0,
                                       randomness.data, &ctx);
  if (result != 0) {
    memset(sk_share0, 0, MLKEM768_SECRETKEYBYTES);
    return OTCRYPTO_FATAL_ERR;
  }

  public_key->checksum = integrity_unblinded_checksum(public_key);
  secret_key->checksum = integrity_blinded_checksum(secret_key);

  return OTCRYPTO_OK;
}

otcrypto_status_t otcrypto_mlkem768_encapsulate_derand(
    const otcrypto_unblinded_key_t *public_key,
    otcrypto_const_byte_buf_t randomness, otcrypto_byte_buf_t ciphertext,
    otcrypto_blinded_key_t *shared_secret,
    uint32_t work[kOtcryptoMlkem768WorkBufferEncapsWords]) {
  if (public_key->key_length != MLKEM768_PUBLICKEYBYTES) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (public_key->key_mode != kOtcryptoKeyModeMlkem768) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (randomness.len != MLKEM768_BYTES) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (ciphertext.len != MLKEM768_CIPHERTEXTBYTES) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (shared_secret->config.key_length != MLKEM768_BYTES) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (shared_secret->config.hw_backed != kHardenedBoolFalse) {
    // Shared secret cannot be a hardware-backed key.
    return OTCRYPTO_BAD_ARGS;
  }
  if (shared_secret->config.security_level !=
      kOtcryptoKeySecurityLevelPassiveRemote) {
    // Reject high-security keys; the underlying implementation is not masked
    // against power side channels.
    return OTCRYPTO_BAD_ARGS;
  }
  if (integrity_unblinded_key_check(public_key) != kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (integrity_blinded_key_check(shared_secret) != kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Write the unmasked shared secret into the first share of the keyblob.
  uint32_t *ss_share0;
  uint32_t *ss_share1;
  HARDENED_TRY(keyblob_to_shares(shared_secret, &ss_share0, &ss_share1));
  memset(ss_share1, 0, MLKEM768_BYTES);

  mlk_alloc_ctx_t ctx = {.base = work,
                         .size_words = kOtcryptoMlkem768WorkBufferEncapsWords,
                         .offset_words = 0};
  int result = mlkem768_enc_derand(ciphertext.data, (unsigned char *)ss_share0,
                                   (unsigned char *)public_key->key,
                                   randomness.data, &ctx);
  if (result != 0) {
    memset(ss_share0, 0, MLKEM768_BYTES);
    return OTCRYPTO_FATAL_ERR;
  }

  shared_secret->checksum = integrity_blinded_checksum(shared_secret);

  return OTCRYPTO_OK;
}

otcrypto_status_t otcrypto_mlkem768_keygen(
    otcrypto_unblinded_key_t *public_key, otcrypto_blinded_key_t *secret_key,
    uint32_t work[kOtcryptoMlkem768WorkBufferKeypairWords]) {
  HARDENED_TRY(entropy_complex_check());

  uint32_t randomness[ceil_div(2 * MLKEM768_BYTES, sizeof(uint32_t))];
  HARDENED_TRY(entropy_csrng_instantiate(
      /*disable_trng_input=*/kHardenedBoolFalse, &kEntropyEmptySeed));
  HARDENED_TRY(entropy_csrng_generate(&kEntropyEmptySeed, randomness,
                                      ARRAYSIZE(randomness),
                                      /*fips_check=*/kHardenedBoolTrue));
  HARDENED_TRY(entropy_csrng_uninstantiate());

  otcrypto_const_byte_buf_t randomness_buf = {
      .data = (unsigned char *)randomness, .len = sizeof(randomness)};
  return otcrypto_mlkem768_keygen_derand(randomness_buf, public_key, secret_key,
                                         work);
}

otcrypto_status_t otcrypto_mlkem768_encapsulate(
    const otcrypto_unblinded_key_t *public_key, otcrypto_byte_buf_t ciphertext,
    otcrypto_blinded_key_t *shared_secret,
    uint32_t work[kOtcryptoMlkem768WorkBufferEncapsWords]) {
  HARDENED_TRY(entropy_complex_check());

  uint32_t randomness[ceil_div(MLKEM768_BYTES, sizeof(uint32_t))];
  HARDENED_TRY(entropy_csrng_instantiate(
      /*disable_trng_input=*/kHardenedBoolFalse, &kEntropyEmptySeed));
  HARDENED_TRY(entropy_csrng_generate(&kEntropyEmptySeed, randomness,
                                      ARRAYSIZE(randomness),
                                      /*fips_check=*/kHardenedBoolTrue));
  HARDENED_TRY(entropy_csrng_uninstantiate());

  otcrypto_const_byte_buf_t randomness_buf = {
      .data = (unsigned char *)randomness, .len = sizeof(randomness)};
  return otcrypto_mlkem768_encapsulate_derand(public_key, randomness_buf,
                                              ciphertext, shared_secret, work);
}

otcrypto_status_t otcrypto_mlkem768_decapsulate(
    const otcrypto_blinded_key_t *secret_key,
    otcrypto_const_byte_buf_t ciphertext, otcrypto_blinded_key_t *shared_secret,
    uint32_t work[kOtcryptoMlkem768WorkBufferDecapsWords]) {
  if (secret_key->config.key_length != MLKEM768_SECRETKEYBYTES) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.key_mode != kOtcryptoKeyModeMlkem768) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.security_level !=
      kOtcryptoKeySecurityLevelPassiveRemote) {
    // Reject high-security keys; the underlying implementation is not masked
    // against power side channels.
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.hw_backed != kHardenedBoolFalse) {
    return OTCRYPTO_NOT_IMPLEMENTED;
  }
  if (ciphertext.len != MLKEM768_CIPHERTEXTBYTES) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (shared_secret->config.key_length != MLKEM768_BYTES) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (shared_secret->config.hw_backed != kHardenedBoolFalse) {
    // Shared secret cannot be a hardware-backed key.
    return OTCRYPTO_BAD_ARGS;
  }
  if (shared_secret->config.security_level !=
      kOtcryptoKeySecurityLevelPassiveRemote) {
    // Reject high-security keys; the underlying implementation is not masked
    // against power side channels.
    return OTCRYPTO_BAD_ARGS;
  }
  if (integrity_blinded_key_check(secret_key) != kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Secret keys are stored unmasked in share0 (share1 is zero).
  uint32_t *sk_share0;
  uint32_t *sk_share1;
  HARDENED_TRY(keyblob_to_shares(secret_key, &sk_share0, &sk_share1));

  // Write the unmasked shared secret into the first share of the keyblob.
  uint32_t *ss_share0;
  uint32_t *ss_share1;
  HARDENED_TRY(keyblob_to_shares(shared_secret, &ss_share0, &ss_share1));
  memset(ss_share1, 0, MLKEM768_BYTES);

  mlk_alloc_ctx_t ctx = {.base = work,
                         .size_words = kOtcryptoMlkem768WorkBufferDecapsWords,
                         .offset_words = 0};
  int result = mlkem768_dec((unsigned char *)ss_share0, ciphertext.data,
                            (unsigned char *)sk_share0, &ctx);
  if (result != 0) {
    memset(ss_share0, 0, MLKEM768_BYTES);
    return OTCRYPTO_FATAL_ERR;
  }

  return OTCRYPTO_OK;
}

// ML-KEM-1024 functions

otcrypto_status_t otcrypto_mlkem1024_keygen_derand(
    otcrypto_const_byte_buf_t randomness, otcrypto_unblinded_key_t *public_key,
    otcrypto_blinded_key_t *secret_key,
    uint32_t work[kOtcryptoMlkem1024WorkBufferKeypairWords]) {
  if (randomness.len != 2 * MLKEM1024_BYTES) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (public_key->key_length != MLKEM1024_PUBLICKEYBYTES) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.key_length != MLKEM1024_SECRETKEYBYTES) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.key_mode != kOtcryptoKeyModeMlkem1024) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.security_level !=
      kOtcryptoKeySecurityLevelPassiveRemote) {
    // Reject high-security keys; the underlying implementation is not masked
    // against power side channels.
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.hw_backed != kHardenedBoolFalse) {
    return OTCRYPTO_NOT_IMPLEMENTED;
  }

  // Write the unmasked secret key into the first share of the keyblob.
  uint32_t *sk_share0;
  uint32_t *sk_share1;
  HARDENED_TRY(keyblob_to_shares(secret_key, &sk_share0, &sk_share1));
  memset(sk_share1, 0, MLKEM1024_SECRETKEYBYTES);

  mlk_alloc_ctx_t ctx = {.base = work,
                         .size_words = kOtcryptoMlkem1024WorkBufferKeypairWords,
                         .offset_words = 0};
  int result = mlkem1024_keypair_derand((unsigned char *)public_key->key,
                                        (unsigned char *)sk_share0,
                                        randomness.data, &ctx);
  if (result != 0) {
    memset(sk_share0, 0, MLKEM1024_SECRETKEYBYTES);
    return OTCRYPTO_FATAL_ERR;
  }

  public_key->checksum = integrity_unblinded_checksum(public_key);
  secret_key->checksum = integrity_blinded_checksum(secret_key);

  return OTCRYPTO_OK;
}

otcrypto_status_t otcrypto_mlkem1024_encapsulate_derand(
    const otcrypto_unblinded_key_t *public_key,
    otcrypto_const_byte_buf_t randomness, otcrypto_byte_buf_t ciphertext,
    otcrypto_blinded_key_t *shared_secret,
    uint32_t work[kOtcryptoMlkem1024WorkBufferEncapsWords]) {
  if (public_key->key_length != MLKEM1024_PUBLICKEYBYTES) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (public_key->key_mode != kOtcryptoKeyModeMlkem1024) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (randomness.len != MLKEM1024_BYTES) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (ciphertext.len != MLKEM1024_CIPHERTEXTBYTES) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (shared_secret->config.key_length != MLKEM1024_BYTES) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (shared_secret->config.hw_backed != kHardenedBoolFalse) {
    // Shared secret cannot be a hardware-backed key.
    return OTCRYPTO_BAD_ARGS;
  }
  if (shared_secret->config.security_level !=
      kOtcryptoKeySecurityLevelPassiveRemote) {
    // Reject high-security keys; the underlying implementation is not masked
    // against power side channels.
    return OTCRYPTO_BAD_ARGS;
  }
  if (integrity_unblinded_key_check(public_key) != kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (integrity_blinded_key_check(shared_secret) != kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Write the unmasked shared secret into the first share of the keyblob.
  uint32_t *ss_share0;
  uint32_t *ss_share1;
  HARDENED_TRY(keyblob_to_shares(shared_secret, &ss_share0, &ss_share1));
  memset(ss_share1, 0, MLKEM1024_BYTES);

  mlk_alloc_ctx_t ctx = {.base = work,
                         .size_words = kOtcryptoMlkem1024WorkBufferEncapsWords,
                         .offset_words = 0};
  int result = mlkem1024_enc_derand(ciphertext.data, (unsigned char *)ss_share0,
                                    (unsigned char *)public_key->key,
                                    randomness.data, &ctx);
  if (result != 0) {
    memset(ss_share0, 0, MLKEM1024_BYTES);
    return OTCRYPTO_FATAL_ERR;
  }

  shared_secret->checksum = integrity_blinded_checksum(shared_secret);

  return OTCRYPTO_OK;
}

otcrypto_status_t otcrypto_mlkem1024_keygen(
    otcrypto_unblinded_key_t *public_key, otcrypto_blinded_key_t *secret_key,
    uint32_t work[kOtcryptoMlkem1024WorkBufferKeypairWords]) {
  HARDENED_TRY(entropy_complex_check());

  uint32_t randomness[ceil_div(2 * MLKEM1024_BYTES, sizeof(uint32_t))];
  HARDENED_TRY(entropy_csrng_instantiate(
      /*disable_trng_input=*/kHardenedBoolFalse, &kEntropyEmptySeed));
  HARDENED_TRY(entropy_csrng_generate(&kEntropyEmptySeed, randomness,
                                      ARRAYSIZE(randomness),
                                      /*fips_check=*/kHardenedBoolTrue));
  HARDENED_TRY(entropy_csrng_uninstantiate());

  otcrypto_const_byte_buf_t randomness_buf = {
      .data = (unsigned char *)randomness, .len = sizeof(randomness)};
  return otcrypto_mlkem1024_keygen_derand(randomness_buf, public_key,
                                          secret_key, work);
}

otcrypto_status_t otcrypto_mlkem1024_encapsulate(
    const otcrypto_unblinded_key_t *public_key, otcrypto_byte_buf_t ciphertext,
    otcrypto_blinded_key_t *shared_secret,
    uint32_t work[kOtcryptoMlkem1024WorkBufferEncapsWords]) {
  HARDENED_TRY(entropy_complex_check());

  uint32_t randomness[ceil_div(MLKEM1024_BYTES, sizeof(uint32_t))];
  HARDENED_TRY(entropy_csrng_instantiate(
      /*disable_trng_input=*/kHardenedBoolFalse, &kEntropyEmptySeed));
  HARDENED_TRY(entropy_csrng_generate(&kEntropyEmptySeed, randomness,
                                      ARRAYSIZE(randomness),
                                      /*fips_check=*/kHardenedBoolTrue));
  HARDENED_TRY(entropy_csrng_uninstantiate());

  otcrypto_const_byte_buf_t randomness_buf = {
      .data = (unsigned char *)randomness, .len = sizeof(randomness)};
  return otcrypto_mlkem1024_encapsulate_derand(public_key, randomness_buf,
                                               ciphertext, shared_secret, work);
}

otcrypto_status_t otcrypto_mlkem1024_decapsulate(
    const otcrypto_blinded_key_t *secret_key,
    otcrypto_const_byte_buf_t ciphertext, otcrypto_blinded_key_t *shared_secret,
    uint32_t work[kOtcryptoMlkem1024WorkBufferDecapsWords]) {
  if (secret_key->config.key_length != MLKEM1024_SECRETKEYBYTES) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.key_mode != kOtcryptoKeyModeMlkem1024) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.security_level !=
      kOtcryptoKeySecurityLevelPassiveRemote) {
    // Reject high-security keys; the underlying implementation is not masked
    // against power side channels.
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.hw_backed != kHardenedBoolFalse) {
    return OTCRYPTO_NOT_IMPLEMENTED;
  }
  if (ciphertext.len != MLKEM1024_CIPHERTEXTBYTES) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (shared_secret->config.key_length != MLKEM1024_BYTES) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (shared_secret->config.hw_backed != kHardenedBoolFalse) {
    // Shared secret cannot be a hardware-backed key.
    return OTCRYPTO_BAD_ARGS;
  }
  if (shared_secret->config.security_level !=
      kOtcryptoKeySecurityLevelPassiveRemote) {
    // Reject high-security keys; the underlying implementation is not masked
    // against power side channels.
    return OTCRYPTO_BAD_ARGS;
  }
  if (integrity_blinded_key_check(secret_key) != kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Secret keys are stored unmasked in share0 (share1 is zero).
  uint32_t *sk_share0;
  uint32_t *sk_share1;
  HARDENED_TRY(keyblob_to_shares(secret_key, &sk_share0, &sk_share1));

  // Write the unmasked shared secret into the first share of the keyblob.
  uint32_t *ss_share0;
  uint32_t *ss_share1;
  HARDENED_TRY(keyblob_to_shares(shared_secret, &ss_share0, &ss_share1));
  memset(ss_share1, 0, MLKEM1024_BYTES);

  mlk_alloc_ctx_t ctx = {.base = work,
                         .size_words = kOtcryptoMlkem1024WorkBufferDecapsWords,
                         .offset_words = 0};
  int result = mlkem1024_dec((unsigned char *)ss_share0, ciphertext.data,
                             (unsigned char *)sk_share0, &ctx);
  if (result != 0) {
    memset(ss_share0, 0, MLKEM1024_BYTES);
    return OTCRYPTO_FATAL_ERR;
  }

  return OTCRYPTO_OK;
}
