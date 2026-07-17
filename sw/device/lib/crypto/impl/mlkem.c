// Copyright The mlkem-native project authors
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/crypto/include/mlkem.h"

#include "sw/device/lib/base/hardened.h"
#include "sw/device/lib/base/math.h"
#include "sw/device/lib/crypto/drivers/entropy.h"
#include "sw/device/lib/crypto/impl/integrity.h"
#include "sw/device/lib/crypto/impl/keyblob.h"
#include "sw/device/lib/crypto/impl/status.h"
#ifdef ACC_HAS_PQC
#include "sw/device/lib/crypto/impl/mlkem/acc/mlkem_acc.h"
#else
#include "sw/device/lib/crypto/impl/mlkem/mlkem-native/mlkem_native_alloc.h"
#include "sw/device/lib/crypto/impl/mlkem/mlkem-native/mlkem_native_monobuild.h"
#endif

// Module ID for status codes.
#define MODULE_ID MAKE_MODULE_ID('m', 'l', 'k')

// Static assertions to verify buffer sizes match mlkem-native
#ifndef ACC_HAS_PQC
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
#endif

// ML-KEM-512 functions

otcrypto_status_t otcrypto_mlkem512_keygen_derand(
    otcrypto_const_word32_buf_t randomness,
    otcrypto_unblinded_key_t *public_key, otcrypto_blinded_key_t *secret_key,
    uint32_t work[kOtcryptoMlkem512WorkBufferKeypairWords]) {
#if defined(ACC_MLKEM_HARDENED)
  // Randomness is masked, so buffer must be twice as long.
  if (randomness.len != 2 * kOtcryptoMlkem512KeygenSeedWords) {
    return OTCRYPTO_BAD_ARGS;
  }
#else
  if (randomness.len != kOtcryptoMlkem512KeygenSeedWords) {
    return OTCRYPTO_BAD_ARGS;
  }
#endif
  if (public_key->key_length != kOtcryptoMlkem512PublicKeyBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.key_length != kOtcryptoMlkem512SecretKeyBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.key_mode != kOtcryptoKeyModeMlkem512) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.hw_backed != kHardenedBoolFalse) {
    return OTCRYPTO_NOT_IMPLEMENTED;
  }

  HARDENED_TRY(check_keyblob_length(secret_key));

#if defined(ACC_MLKEM_HARDENED)
  if (launder32(secret_key->config.security_level) !=
      kOtcryptoKeySecurityLevelPassivePhysical) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(secret_key->config.security_level,
                    kOtcryptoKeySecurityLevelPassivePhysical);
#else
  if (launder32(secret_key->config.security_level) !=
      kOtcryptoKeySecurityLevelPassiveRemote) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(secret_key->config.security_level,
                    kOtcryptoKeySecurityLevelPassiveRemote);
#endif

#if defined(ACC_HAS_PQC) && defined(ACC_MLKEM_HARDENED)
  (void)work;
  const uint32_t *rand_share0 = randomness.data;
  const uint32_t *rand_share1 =
      &randomness.data[kOtcryptoMlkem512KeygenSeedWords];
  HARDENED_TRY(mlkem_acc_512_keygen_hardened(
      rand_share0, rand_share1, public_key->key, secret_key->keyblob));
#elif defined(ACC_HAS_PQC)
  (void)work;
  HARDENED_TRY(mlkem_acc_512_keygen(randomness.data, public_key->key,
                                    secret_key->keyblob));
#else
  mlk_alloc_ctx_t ctx = {.base = work,
                         .size_words = kOtcryptoMlkem512WorkBufferKeypairWords,
                         .offset_words = 0};
  int result = mlkem512_keypair_derand((unsigned char *)public_key->key,
                                       (unsigned char *)secret_key->keyblob,
                                       (const uint8_t *)randomness.data, &ctx);
  if (result != 0) {
    memset(secret_key->keyblob, 0, kOtcryptoMlkem512SecretKeyBytes);
    return OTCRYPTO_FATAL_ERR;
  }
#endif

  public_key->checksum = integrity_unblinded_checksum(public_key);
  secret_key->checksum = integrity_blinded_checksum(secret_key);

  return OTCRYPTO_OK;
}

otcrypto_status_t otcrypto_mlkem512_encapsulate_derand(
    const otcrypto_unblinded_key_t *public_key,
    otcrypto_const_word32_buf_t randomness, otcrypto_word32_buf_t ciphertext,
    otcrypto_blinded_key_t *shared_secret,
    uint32_t work[kOtcryptoMlkem512WorkBufferEncapsWords]) {
  if (public_key->key_length != kOtcryptoMlkem512PublicKeyBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (public_key->key_mode != kOtcryptoKeyModeMlkem512) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (randomness.len != kOtcryptoMlkem512EncapsSeedWords) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (ciphertext.len != kOtcryptoMlkem512CiphertextWords) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (shared_secret->config.key_length != kOtcryptoMlkem512SharedSecretBytes) {
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
  memset(ss_share1, 0, kOtcryptoMlkem512SharedSecretBytes);

#ifdef ACC_HAS_PQC
  (void)work;
  HARDENED_TRY(mlkem_acc_512_encap(randomness.data, public_key->key,
                                   ciphertext.data, ss_share0));
#else
  mlk_alloc_ctx_t ctx = {.base = work,
                         .size_words = kOtcryptoMlkem512WorkBufferEncapsWords,
                         .offset_words = 0};
  int result = mlkem512_enc_derand(
      (uint8_t *)ciphertext.data, (unsigned char *)ss_share0,
      (unsigned char *)public_key->key, (const uint8_t *)randomness.data, &ctx);
  if (result != 0) {
    memset(ss_share0, 0, kOtcryptoMlkem512SharedSecretBytes);
    return OTCRYPTO_FATAL_ERR;
  }
#endif

  shared_secret->checksum = integrity_blinded_checksum(shared_secret);

  return OTCRYPTO_OK;
}

otcrypto_status_t otcrypto_mlkem512_keygen(
    otcrypto_unblinded_key_t *public_key, otcrypto_blinded_key_t *secret_key,
    uint32_t work[kOtcryptoMlkem512WorkBufferKeypairWords]) {
  HARDENED_TRY(entropy_complex_check());

#if defined(ACC_MLKEM_HARDENED)
  // Randomness is masked, so buffer must be twice as long.
  uint32_t randomness[2 * kOtcryptoMlkem512KeygenSeedWords];
#else
  uint32_t randomness[kOtcryptoMlkem512KeygenSeedWords];
#endif
  HARDENED_TRY(entropy_csrng_instantiate(
      /*disable_trng_input=*/kHardenedBoolFalse, &kEntropyEmptySeed));
  HARDENED_TRY(entropy_csrng_generate(&kEntropyEmptySeed, randomness,
                                      ARRAYSIZE(randomness),
                                      /*fips_check=*/kHardenedBoolTrue));
  HARDENED_TRY(entropy_csrng_uninstantiate());

  otcrypto_const_word32_buf_t randomness_buf = {.data = randomness,
                                                .len = ARRAYSIZE(randomness)};
  return otcrypto_mlkem512_keygen_derand(randomness_buf, public_key, secret_key,
                                         work);
}

otcrypto_status_t otcrypto_mlkem512_encapsulate(
    const otcrypto_unblinded_key_t *public_key,
    otcrypto_word32_buf_t ciphertext, otcrypto_blinded_key_t *shared_secret,
    uint32_t work[kOtcryptoMlkem512WorkBufferEncapsWords]) {
  HARDENED_TRY(entropy_complex_check());

  uint32_t randomness[kOtcryptoMlkem512EncapsSeedWords];
  HARDENED_TRY(entropy_csrng_instantiate(
      /*disable_trng_input=*/kHardenedBoolFalse, &kEntropyEmptySeed));
  HARDENED_TRY(entropy_csrng_generate(&kEntropyEmptySeed, randomness,
                                      ARRAYSIZE(randomness),
                                      /*fips_check=*/kHardenedBoolTrue));
  HARDENED_TRY(entropy_csrng_uninstantiate());

  otcrypto_const_word32_buf_t randomness_buf = {.data = randomness,
                                                .len = ARRAYSIZE(randomness)};
  return otcrypto_mlkem512_encapsulate_derand(public_key, randomness_buf,
                                              ciphertext, shared_secret, work);
}

otcrypto_status_t otcrypto_mlkem512_decapsulate(
    const otcrypto_blinded_key_t *secret_key,
    otcrypto_const_word32_buf_t ciphertext,
    otcrypto_blinded_key_t *shared_secret,
    uint32_t work[kOtcryptoMlkem512WorkBufferDecapsWords]) {
  if (secret_key->config.key_length != kOtcryptoMlkem512SecretKeyBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.key_mode != kOtcryptoKeyModeMlkem512) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.hw_backed != kHardenedBoolFalse) {
    return OTCRYPTO_NOT_IMPLEMENTED;
  }
  if (ciphertext.len != kOtcryptoMlkem512CiphertextWords) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (shared_secret->config.key_length != kOtcryptoMlkem512SharedSecretBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (shared_secret->config.hw_backed != kHardenedBoolFalse) {
    // Shared secret cannot be a hardware-backed key.
    return OTCRYPTO_BAD_ARGS;
  }
#ifndef ACC_MLKEM_HARDENED
  if (shared_secret->config.security_level !=
      kOtcryptoKeySecurityLevelPassiveRemote) {
    // Reject high-security keys; the underlying implementation is not masked
    // against power side channels.
    return OTCRYPTO_BAD_ARGS;
  }
#endif
  if (integrity_blinded_key_check(secret_key) != kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }

  HARDENED_TRY(check_keyblob_length(secret_key));

  // Write the unmasked shared secret into the first share of the keyblob.
  uint32_t *ss_share0;
  uint32_t *ss_share1;
  HARDENED_TRY(keyblob_to_shares(shared_secret, &ss_share0, &ss_share1));
  memset(ss_share1, 0, kOtcryptoMlkem512SharedSecretBytes);

#if defined(ACC_MLKEM_HARDENED)
  if (launder32(secret_key->config.security_level) !=
      kOtcryptoKeySecurityLevelPassivePhysical) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(secret_key->config.security_level,
                    kOtcryptoKeySecurityLevelPassivePhysical);
#else
  if (launder32(secret_key->config.security_level) !=
      kOtcryptoKeySecurityLevelPassiveRemote) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(secret_key->config.security_level,
                    kOtcryptoKeySecurityLevelPassiveRemote);
#endif

#if defined(ACC_HAS_PQC) && defined(ACC_MLKEM_HARDENED)
  (void)work;
  HARDENED_TRY(mlkem_acc_512_decap_hardened(
      ciphertext.data, secret_key->keyblob, ss_share0, ss_share1));
#elif defined(ACC_HAS_PQC)
  (void)work;
  HARDENED_TRY(
      mlkem_acc_512_decap(ciphertext.data, secret_key->keyblob, ss_share0));
#else
  mlk_alloc_ctx_t ctx = {.base = work,
                         .size_words = kOtcryptoMlkem512WorkBufferDecapsWords,
                         .offset_words = 0};
  int result =
      mlkem512_dec((unsigned char *)ss_share0, (const uint8_t *)ciphertext.data,
                   (unsigned char *)secret_key->keyblob, &ctx);
  if (result != 0) {
    memset(ss_share0, 0, kOtcryptoMlkem512SharedSecretBytes);
    return OTCRYPTO_FATAL_ERR;
  }
#endif

  shared_secret->checksum = integrity_blinded_checksum(shared_secret);

  return OTCRYPTO_OK;
}

// ML-KEM-768 functions

otcrypto_status_t otcrypto_mlkem768_keygen_derand(
    otcrypto_const_word32_buf_t randomness,
    otcrypto_unblinded_key_t *public_key, otcrypto_blinded_key_t *secret_key,
    uint32_t work[kOtcryptoMlkem768WorkBufferKeypairWords]) {
#if defined(ACC_MLKEM_HARDENED)
  // Randomness is masked, so buffer must be twice as long.
  if (randomness.len != 2 * kOtcryptoMlkem768KeygenSeedWords) {
    return OTCRYPTO_BAD_ARGS;
  }
#else
  if (randomness.len != kOtcryptoMlkem768KeygenSeedWords) {
    return OTCRYPTO_BAD_ARGS;
  }
#endif
  if (public_key->key_length != kOtcryptoMlkem768PublicKeyBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.key_length != kOtcryptoMlkem768SecretKeyBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.key_mode != kOtcryptoKeyModeMlkem768) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.hw_backed != kHardenedBoolFalse) {
    return OTCRYPTO_NOT_IMPLEMENTED;
  }

  HARDENED_TRY(check_keyblob_length(secret_key));

#if defined(ACC_MLKEM_HARDENED)
  if (launder32(secret_key->config.security_level) !=
      kOtcryptoKeySecurityLevelPassivePhysical) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(secret_key->config.security_level,
                    kOtcryptoKeySecurityLevelPassivePhysical);
#else
  if (launder32(secret_key->config.security_level) !=
      kOtcryptoKeySecurityLevelPassiveRemote) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(secret_key->config.security_level,
                    kOtcryptoKeySecurityLevelPassiveRemote);
#endif

#if defined(ACC_HAS_PQC) && defined(ACC_MLKEM_HARDENED)
  (void)work;
  const uint32_t *rand_share0 = randomness.data;
  const uint32_t *rand_share1 =
      &randomness.data[kOtcryptoMlkem768KeygenSeedWords];
  HARDENED_TRY(mlkem_acc_768_keygen_hardened(
      rand_share0, rand_share1, public_key->key, secret_key->keyblob));
#elif defined(ACC_HAS_PQC)
  (void)work;
  HARDENED_TRY(mlkem_acc_768_keygen(randomness.data, public_key->key,
                                    secret_key->keyblob));
#else
  mlk_alloc_ctx_t ctx = {.base = work,
                         .size_words = kOtcryptoMlkem768WorkBufferKeypairWords,
                         .offset_words = 0};
  int result = mlkem768_keypair_derand((unsigned char *)public_key->key,
                                       (unsigned char *)secret_key->keyblob,
                                       (const uint8_t *)randomness.data, &ctx);
  if (result != 0) {
    memset(secret_key->keyblob, 0, kOtcryptoMlkem768SecretKeyBytes);
    return OTCRYPTO_FATAL_ERR;
  }
#endif

  public_key->checksum = integrity_unblinded_checksum(public_key);
  secret_key->checksum = integrity_blinded_checksum(secret_key);

  return OTCRYPTO_OK;
}

otcrypto_status_t otcrypto_mlkem768_encapsulate_derand(
    const otcrypto_unblinded_key_t *public_key,
    otcrypto_const_word32_buf_t randomness, otcrypto_word32_buf_t ciphertext,
    otcrypto_blinded_key_t *shared_secret,
    uint32_t work[kOtcryptoMlkem768WorkBufferEncapsWords]) {
  if (public_key->key_length != kOtcryptoMlkem768PublicKeyBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (public_key->key_mode != kOtcryptoKeyModeMlkem768) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (randomness.len != kOtcryptoMlkem768EncapsSeedWords) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (ciphertext.len != kOtcryptoMlkem768CiphertextWords) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (shared_secret->config.key_length != kOtcryptoMlkem768SharedSecretBytes) {
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
  memset(ss_share1, 0, kOtcryptoMlkem768SharedSecretBytes);

#ifdef ACC_HAS_PQC
  (void)work;
  HARDENED_TRY(mlkem_acc_768_encap(randomness.data, public_key->key,
                                   ciphertext.data, ss_share0));
#else
  mlk_alloc_ctx_t ctx = {.base = work,
                         .size_words = kOtcryptoMlkem768WorkBufferEncapsWords,
                         .offset_words = 0};
  int result = mlkem768_enc_derand(
      (uint8_t *)ciphertext.data, (unsigned char *)ss_share0,
      (unsigned char *)public_key->key, (const uint8_t *)randomness.data, &ctx);
  if (result != 0) {
    memset(ss_share0, 0, kOtcryptoMlkem768SharedSecretBytes);
    return OTCRYPTO_FATAL_ERR;
  }
#endif

  shared_secret->checksum = integrity_blinded_checksum(shared_secret);

  return OTCRYPTO_OK;
}

otcrypto_status_t otcrypto_mlkem768_keygen(
    otcrypto_unblinded_key_t *public_key, otcrypto_blinded_key_t *secret_key,
    uint32_t work[kOtcryptoMlkem768WorkBufferKeypairWords]) {
  HARDENED_TRY(entropy_complex_check());

#if defined(ACC_MLKEM_HARDENED)
  // Randomness is masked, so buffer must be twice as long.
  uint32_t randomness[2 * kOtcryptoMlkem768KeygenSeedWords];
#else
  uint32_t randomness[kOtcryptoMlkem768KeygenSeedWords];
#endif
  HARDENED_TRY(entropy_csrng_instantiate(
      /*disable_trng_input=*/kHardenedBoolFalse, &kEntropyEmptySeed));
  HARDENED_TRY(entropy_csrng_generate(&kEntropyEmptySeed, randomness,
                                      ARRAYSIZE(randomness),
                                      /*fips_check=*/kHardenedBoolTrue));
  HARDENED_TRY(entropy_csrng_uninstantiate());

  otcrypto_const_word32_buf_t randomness_buf = {.data = randomness,
                                                .len = ARRAYSIZE(randomness)};
  return otcrypto_mlkem768_keygen_derand(randomness_buf, public_key, secret_key,
                                         work);
}

otcrypto_status_t otcrypto_mlkem768_encapsulate(
    const otcrypto_unblinded_key_t *public_key,
    otcrypto_word32_buf_t ciphertext, otcrypto_blinded_key_t *shared_secret,
    uint32_t work[kOtcryptoMlkem768WorkBufferEncapsWords]) {
  HARDENED_TRY(entropy_complex_check());

  uint32_t randomness[kOtcryptoMlkem768EncapsSeedWords];
  HARDENED_TRY(entropy_csrng_instantiate(
      /*disable_trng_input=*/kHardenedBoolFalse, &kEntropyEmptySeed));
  HARDENED_TRY(entropy_csrng_generate(&kEntropyEmptySeed, randomness,
                                      ARRAYSIZE(randomness),
                                      /*fips_check=*/kHardenedBoolTrue));
  HARDENED_TRY(entropy_csrng_uninstantiate());

  otcrypto_const_word32_buf_t randomness_buf = {.data = randomness,
                                                .len = ARRAYSIZE(randomness)};
  return otcrypto_mlkem768_encapsulate_derand(public_key, randomness_buf,
                                              ciphertext, shared_secret, work);
}

otcrypto_status_t otcrypto_mlkem768_decapsulate(
    const otcrypto_blinded_key_t *secret_key,
    otcrypto_const_word32_buf_t ciphertext,
    otcrypto_blinded_key_t *shared_secret,
    uint32_t work[kOtcryptoMlkem768WorkBufferDecapsWords]) {
  if (secret_key->config.key_length != kOtcryptoMlkem768SecretKeyBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.key_mode != kOtcryptoKeyModeMlkem768) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.hw_backed != kHardenedBoolFalse) {
    return OTCRYPTO_NOT_IMPLEMENTED;
  }
  if (ciphertext.len != kOtcryptoMlkem768CiphertextWords) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (shared_secret->config.key_length != kOtcryptoMlkem768SharedSecretBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (shared_secret->config.hw_backed != kHardenedBoolFalse) {
    // Shared secret cannot be a hardware-backed key.
    return OTCRYPTO_BAD_ARGS;
  }
#ifndef ACC_MLKEM_HARDENED
  if (shared_secret->config.security_level !=
      kOtcryptoKeySecurityLevelPassiveRemote) {
    // Reject high-security keys; the underlying implementation is not masked
    // against power side channels.
    return OTCRYPTO_BAD_ARGS;
  }
#endif
  if (integrity_blinded_key_check(secret_key) != kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }

  HARDENED_TRY(check_keyblob_length(secret_key));

  // Write the unmasked shared secret into the first share of the keyblob.
  uint32_t *ss_share0;
  uint32_t *ss_share1;
  HARDENED_TRY(keyblob_to_shares(shared_secret, &ss_share0, &ss_share1));
  memset(ss_share1, 0, kOtcryptoMlkem768SharedSecretBytes);

#if defined(ACC_MLKEM_HARDENED)
  if (launder32(secret_key->config.security_level) !=
      kOtcryptoKeySecurityLevelPassivePhysical) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(secret_key->config.security_level,
                    kOtcryptoKeySecurityLevelPassivePhysical);
#else
  if (launder32(secret_key->config.security_level) !=
      kOtcryptoKeySecurityLevelPassiveRemote) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(secret_key->config.security_level,
                    kOtcryptoKeySecurityLevelPassiveRemote);
#endif

#if defined(ACC_HAS_PQC) && defined(ACC_MLKEM_HARDENED)
  (void)work;
  HARDENED_TRY(mlkem_acc_768_decap_hardened(
      ciphertext.data, secret_key->keyblob, ss_share0, ss_share1));
#elif defined(ACC_HAS_PQC)
  (void)work;
  HARDENED_TRY(
      mlkem_acc_768_decap(ciphertext.data, secret_key->keyblob, ss_share0));
#else
  mlk_alloc_ctx_t ctx = {.base = work,
                         .size_words = kOtcryptoMlkem768WorkBufferDecapsWords,
                         .offset_words = 0};
  int result =
      mlkem768_dec((unsigned char *)ss_share0, (const uint8_t *)ciphertext.data,
                   (unsigned char *)secret_key->keyblob, &ctx);
  if (result != 0) {
    memset(ss_share0, 0, kOtcryptoMlkem768SharedSecretBytes);
    return OTCRYPTO_FATAL_ERR;
  }
#endif

  shared_secret->checksum = integrity_blinded_checksum(shared_secret);

  return OTCRYPTO_OK;
}

// ML-KEM-1024 functions

otcrypto_status_t otcrypto_mlkem1024_keygen_derand(
    otcrypto_const_word32_buf_t randomness,
    otcrypto_unblinded_key_t *public_key, otcrypto_blinded_key_t *secret_key,
    uint32_t work[kOtcryptoMlkem1024WorkBufferKeypairWords]) {
#if defined(ACC_MLKEM_HARDENED)
  // Randomness is masked, so buffer must be twice as long.
  if (randomness.len != 2 * kOtcryptoMlkem1024KeygenSeedWords) {
    return OTCRYPTO_BAD_ARGS;
  }
#else
  if (randomness.len != kOtcryptoMlkem1024KeygenSeedWords) {
    return OTCRYPTO_BAD_ARGS;
  }
#endif
  if (public_key->key_length != kOtcryptoMlkem1024PublicKeyBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.key_length != kOtcryptoMlkem1024SecretKeyBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.key_mode != kOtcryptoKeyModeMlkem1024) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.hw_backed != kHardenedBoolFalse) {
    return OTCRYPTO_NOT_IMPLEMENTED;
  }

  HARDENED_TRY(check_keyblob_length(secret_key));

#if defined(ACC_MLKEM_HARDENED)
  if (launder32(secret_key->config.security_level) !=
      kOtcryptoKeySecurityLevelPassivePhysical) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(secret_key->config.security_level,
                    kOtcryptoKeySecurityLevelPassivePhysical);
#else
  if (launder32(secret_key->config.security_level) !=
      kOtcryptoKeySecurityLevelPassiveRemote) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(secret_key->config.security_level,
                    kOtcryptoKeySecurityLevelPassiveRemote);
#endif

#if defined(ACC_HAS_PQC) && defined(ACC_MLKEM_HARDENED)
  (void)work;
  const uint32_t *rand_share0 = randomness.data;
  const uint32_t *rand_share1 =
      &randomness.data[kOtcryptoMlkem1024KeygenSeedWords];
  HARDENED_TRY(mlkem_acc_1024_keygen_hardened(
      rand_share0, rand_share1, public_key->key, secret_key->keyblob));
#elif defined(ACC_HAS_PQC)
  (void)work;
  HARDENED_TRY(mlkem_acc_1024_keygen(randomness.data, public_key->key,
                                     secret_key->keyblob));
#else
  mlk_alloc_ctx_t ctx = {.base = work,
                         .size_words = kOtcryptoMlkem1024WorkBufferKeypairWords,
                         .offset_words = 0};
  int result = mlkem1024_keypair_derand((unsigned char *)public_key->key,
                                        (unsigned char *)secret_key->keyblob,
                                        (const uint8_t *)randomness.data, &ctx);
  if (result != 0) {
    memset(secret_key->keyblob, 0, kOtcryptoMlkem1024SecretKeyBytes);
    return OTCRYPTO_FATAL_ERR;
  }
#endif

  public_key->checksum = integrity_unblinded_checksum(public_key);
  secret_key->checksum = integrity_blinded_checksum(secret_key);

  return OTCRYPTO_OK;
}

otcrypto_status_t otcrypto_mlkem1024_encapsulate_derand(
    const otcrypto_unblinded_key_t *public_key,
    otcrypto_const_word32_buf_t randomness, otcrypto_word32_buf_t ciphertext,
    otcrypto_blinded_key_t *shared_secret,
    uint32_t work[kOtcryptoMlkem1024WorkBufferEncapsWords]) {
  if (public_key->key_length != kOtcryptoMlkem1024PublicKeyBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (public_key->key_mode != kOtcryptoKeyModeMlkem1024) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (randomness.len != kOtcryptoMlkem1024EncapsSeedWords) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (ciphertext.len != kOtcryptoMlkem1024CiphertextWords) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (shared_secret->config.key_length != kOtcryptoMlkem1024SharedSecretBytes) {
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
  memset(ss_share1, 0, kOtcryptoMlkem1024SharedSecretBytes);

#ifdef ACC_HAS_PQC
  (void)work;
  HARDENED_TRY(mlkem_acc_1024_encap(randomness.data, public_key->key,
                                    ciphertext.data, ss_share0));
#else
  mlk_alloc_ctx_t ctx = {.base = work,
                         .size_words = kOtcryptoMlkem1024WorkBufferEncapsWords,
                         .offset_words = 0};
  int result = mlkem1024_enc_derand(
      (uint8_t *)ciphertext.data, (unsigned char *)ss_share0,
      (unsigned char *)public_key->key, (const uint8_t *)randomness.data, &ctx);
  if (result != 0) {
    memset(ss_share0, 0, kOtcryptoMlkem1024SharedSecretBytes);
    return OTCRYPTO_FATAL_ERR;
  }
#endif

  shared_secret->checksum = integrity_blinded_checksum(shared_secret);

  return OTCRYPTO_OK;
}

otcrypto_status_t otcrypto_mlkem1024_keygen(
    otcrypto_unblinded_key_t *public_key, otcrypto_blinded_key_t *secret_key,
    uint32_t work[kOtcryptoMlkem1024WorkBufferKeypairWords]) {
  HARDENED_TRY(entropy_complex_check());

#if defined(ACC_MLKEM_HARDENED)
  // Randomness is masked, so buffer must be twice as long.
  uint32_t randomness[2 * kOtcryptoMlkem1024KeygenSeedWords];
#else
  uint32_t randomness[kOtcryptoMlkem1024KeygenSeedWords];
#endif
  HARDENED_TRY(entropy_csrng_instantiate(
      /*disable_trng_input=*/kHardenedBoolFalse, &kEntropyEmptySeed));
  HARDENED_TRY(entropy_csrng_generate(&kEntropyEmptySeed, randomness,
                                      ARRAYSIZE(randomness),
                                      /*fips_check=*/kHardenedBoolTrue));
  HARDENED_TRY(entropy_csrng_uninstantiate());

  otcrypto_const_word32_buf_t randomness_buf = {.data = randomness,
                                                .len = ARRAYSIZE(randomness)};
  return otcrypto_mlkem1024_keygen_derand(randomness_buf, public_key,
                                          secret_key, work);
}

otcrypto_status_t otcrypto_mlkem1024_encapsulate(
    const otcrypto_unblinded_key_t *public_key,
    otcrypto_word32_buf_t ciphertext, otcrypto_blinded_key_t *shared_secret,
    uint32_t work[kOtcryptoMlkem1024WorkBufferEncapsWords]) {
  HARDENED_TRY(entropy_complex_check());

  uint32_t randomness[kOtcryptoMlkem1024EncapsSeedWords];
  HARDENED_TRY(entropy_csrng_instantiate(
      /*disable_trng_input=*/kHardenedBoolFalse, &kEntropyEmptySeed));
  HARDENED_TRY(entropy_csrng_generate(&kEntropyEmptySeed, randomness,
                                      ARRAYSIZE(randomness),
                                      /*fips_check=*/kHardenedBoolTrue));
  HARDENED_TRY(entropy_csrng_uninstantiate());

  otcrypto_const_word32_buf_t randomness_buf = {.data = randomness,
                                                .len = ARRAYSIZE(randomness)};
  return otcrypto_mlkem1024_encapsulate_derand(public_key, randomness_buf,
                                               ciphertext, shared_secret, work);
}

otcrypto_status_t otcrypto_mlkem1024_decapsulate(
    const otcrypto_blinded_key_t *secret_key,
    otcrypto_const_word32_buf_t ciphertext,
    otcrypto_blinded_key_t *shared_secret,
    uint32_t work[kOtcryptoMlkem1024WorkBufferDecapsWords]) {
  if (secret_key->config.key_length != kOtcryptoMlkem1024SecretKeyBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.key_mode != kOtcryptoKeyModeMlkem1024) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.hw_backed != kHardenedBoolFalse) {
    return OTCRYPTO_NOT_IMPLEMENTED;
  }
  if (ciphertext.len != kOtcryptoMlkem1024CiphertextWords) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (shared_secret->config.key_length != kOtcryptoMlkem1024SharedSecretBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (shared_secret->config.hw_backed != kHardenedBoolFalse) {
    // Shared secret cannot be a hardware-backed key.
    return OTCRYPTO_BAD_ARGS;
  }
#ifndef ACC_MLKEM_HARDENED
  if (shared_secret->config.security_level !=
      kOtcryptoKeySecurityLevelPassiveRemote) {
    // Reject high-security keys; the underlying implementation is not masked
    // against power side channels.
    return OTCRYPTO_BAD_ARGS;
  }
#endif
  if (integrity_blinded_key_check(secret_key) != kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }

  HARDENED_TRY(check_keyblob_length(secret_key));

  // Write the unmasked shared secret into the first share of the keyblob.
  uint32_t *ss_share0;
  uint32_t *ss_share1;
  HARDENED_TRY(keyblob_to_shares(shared_secret, &ss_share0, &ss_share1));
  memset(ss_share1, 0, kOtcryptoMlkem1024SharedSecretBytes);

#if defined(ACC_MLKEM_HARDENED)
  if (launder32(secret_key->config.security_level) !=
      kOtcryptoKeySecurityLevelPassivePhysical) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(secret_key->config.security_level,
                    kOtcryptoKeySecurityLevelPassivePhysical);
#else
  if (launder32(secret_key->config.security_level) !=
      kOtcryptoKeySecurityLevelPassiveRemote) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(secret_key->config.security_level,
                    kOtcryptoKeySecurityLevelPassiveRemote);
#endif

#if defined(ACC_HAS_PQC) && defined(ACC_MLKEM_HARDENED)
  (void)work;
  HARDENED_TRY(mlkem_acc_1024_decap_hardened(
      ciphertext.data, secret_key->keyblob, ss_share0, ss_share1));
#elif defined(ACC_HAS_PQC)
  (void)work;
  HARDENED_TRY(
      mlkem_acc_1024_decap(ciphertext.data, secret_key->keyblob, ss_share0));
#else
  mlk_alloc_ctx_t ctx = {.base = work,
                         .size_words = kOtcryptoMlkem1024WorkBufferDecapsWords,
                         .offset_words = 0};
  int result = mlkem1024_dec((unsigned char *)ss_share0,
                             (const uint8_t *)ciphertext.data,
                             (unsigned char *)secret_key->keyblob, &ctx);
  if (result != 0) {
    memset(ss_share0, 0, kOtcryptoMlkem1024SharedSecretBytes);
    return OTCRYPTO_FATAL_ERR;
  }
#endif

  shared_secret->checksum = integrity_blinded_checksum(shared_secret);

  return OTCRYPTO_OK;
}
