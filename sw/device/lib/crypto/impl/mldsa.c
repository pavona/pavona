// Copyright The mldsa-native project authors
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/crypto/include/mldsa.h"

#include <string.h>

#include "sw/device/lib/base/math.h"
#include "sw/device/lib/crypto/drivers/entropy.h"
#include "sw/device/lib/crypto/impl/integrity.h"
#include "sw/device/lib/crypto/impl/keyblob.h"
#include "sw/device/lib/crypto/impl/status.h"
#ifdef ACC_HAS_PQC
#include "sw/device/lib/crypto/impl/mldsa/acc/mldsa_acc.h"
#else
#include "sw/device/lib/crypto/impl/mldsa/mldsa-native/mldsa_native_monobuild.h"
#endif

// Module ID for status codes.
#define MODULE_ID MAKE_MODULE_ID('m', 'l', 'd')

// Static assertions to verify buffer sizes match mldsa-native
#ifndef ACC_HAS_PQC
_Static_assert(kOtcryptoMldsa44WorkBufferKeypairWords * sizeof(uint32_t) ==
                   MLD_TOTAL_ALLOC_44_KEYPAIR,
               "ML-DSA-44 keypair work buffer size mismatch");
_Static_assert(kOtcryptoMldsa44WorkBufferSignWords * sizeof(uint32_t) ==
                   MLD_TOTAL_ALLOC_44_SIGN,
               "ML-DSA-44 sign work buffer size mismatch");
_Static_assert(kOtcryptoMldsa44WorkBufferVerifyWords * sizeof(uint32_t) ==
                   MLD_TOTAL_ALLOC_44_VERIFY,
               "ML-DSA-44 verify work buffer size mismatch");

_Static_assert(kOtcryptoMldsa65WorkBufferKeypairWords * sizeof(uint32_t) ==
                   MLD_TOTAL_ALLOC_65_KEYPAIR,
               "ML-DSA-65 keypair work buffer size mismatch");
_Static_assert(kOtcryptoMldsa65WorkBufferSignWords * sizeof(uint32_t) ==
                   MLD_TOTAL_ALLOC_65_SIGN,
               "ML-DSA-65 sign work buffer size mismatch");
_Static_assert(kOtcryptoMldsa65WorkBufferVerifyWords * sizeof(uint32_t) ==
                   MLD_TOTAL_ALLOC_65_VERIFY,
               "ML-DSA-65 verify work buffer size mismatch");

_Static_assert(kOtcryptoMldsa87WorkBufferKeypairWords * sizeof(uint32_t) ==
                   MLD_TOTAL_ALLOC_87_KEYPAIR,
               "ML-DSA-87 keypair work buffer size mismatch");
_Static_assert(kOtcryptoMldsa87WorkBufferSignWords * sizeof(uint32_t) ==
                   MLD_TOTAL_ALLOC_87_SIGN,
               "ML-DSA-87 sign work buffer size mismatch");
_Static_assert(kOtcryptoMldsa87WorkBufferVerifyWords * sizeof(uint32_t) ==
                   MLD_TOTAL_ALLOC_87_VERIFY,
               "ML-DSA-87 verify work buffer size mismatch");
#endif

otcrypto_status_t otcrypto_mldsa44_keygen(
    otcrypto_unblinded_key_t *public_key, otcrypto_blinded_key_t *secret_key,
    uint32_t work[kOtcryptoMldsa44WorkBufferKeypairWords]) {
  HARDENED_TRY(entropy_complex_check());

  uint32_t seed[ceil_div(kOtcryptoMldsa44SeedBytes, sizeof(uint32_t))];
  HARDENED_TRY(entropy_csrng_instantiate(
      /*disable_trng_input=*/kHardenedBoolFalse, &kEntropyEmptySeed));
  HARDENED_TRY(entropy_csrng_generate(&kEntropyEmptySeed, seed, ARRAYSIZE(seed),
                                      /*fips_check=*/kHardenedBoolTrue));
  HARDENED_TRY(entropy_csrng_uninstantiate());

  otcrypto_const_aligned_byte_buf_t seed_buf = {.data = seed,
                                                .len = sizeof(seed)};
  return otcrypto_mldsa44_keypair_derand(seed_buf, public_key, secret_key,
                                         work);
}

otcrypto_status_t otcrypto_mldsa44_keypair_derand(
    otcrypto_const_aligned_byte_buf_t seed,
    otcrypto_unblinded_key_t *public_key, otcrypto_blinded_key_t *secret_key,
    uint32_t work[kOtcryptoMldsa44WorkBufferKeypairWords]) {
  if (seed.len != kOtcryptoMldsa44SeedBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (public_key == NULL || secret_key == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (public_key->key_mode != kOtcryptoKeyModeMldsa44) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.key_mode != kOtcryptoKeyModeMldsa44) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (public_key->key_length != kOtcryptoMldsa44PublicKeyBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.key_length != kOtcryptoMldsa44SecretKeyBytes) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Write the unmasked secret key into the first share of the keyblob.
  uint32_t *sk_share0;
  uint32_t *sk_share1;
  HARDENED_TRY(keyblob_to_shares(secret_key, &sk_share0, &sk_share1));
  memset(sk_share1, 0, kOtcryptoMldsa44SecretKeyBytes);

#ifdef ACC_HAS_PQC
  (void)work;
  HARDENED_TRY(mldsa_acc_44_keygen(seed.data, public_key->key, sk_share0));
#else
  mld_alloc_ctx_t ctx = {.base = work,
                         .size_words = kOtcryptoMldsa44WorkBufferKeypairWords,
                         .offset_words = 0};
  int result =
      mldsa44_keypair_internal((uint8_t *)public_key->key, (uint8_t *)sk_share0,
                               (const uint8_t *)seed.data, &ctx);
  if (result != 0) {
    memset(sk_share0, 0, kOtcryptoMldsa44SecretKeyBytes);
    return OTCRYPTO_FATAL_ERR;
  }
#endif

  public_key->checksum = integrity_unblinded_checksum(public_key);
  secret_key->checksum = integrity_blinded_checksum(secret_key);

  return OTCRYPTO_OK;
}

otcrypto_status_t otcrypto_mldsa44_sign(
    const otcrypto_blinded_key_t *secret_key, otcrypto_const_byte_buf_t message,
    otcrypto_const_byte_buf_t context, otcrypto_mldsa_sign_mode_t sign_mode,
    otcrypto_aligned_byte_buf_t signature,
    uint32_t work[kOtcryptoMldsa44WorkBufferSignWords]) {
  HARDENED_TRY(entropy_complex_check());

  uint32_t rnd[ceil_div(kOtcryptoMldsa44SeedBytes, sizeof(uint32_t))];
  HARDENED_TRY(entropy_csrng_instantiate(
      /*disable_trng_input=*/kHardenedBoolFalse, &kEntropyEmptySeed));
  HARDENED_TRY(entropy_csrng_generate(&kEntropyEmptySeed, rnd, ARRAYSIZE(rnd),
                                      /*fips_check=*/kHardenedBoolTrue));
  HARDENED_TRY(entropy_csrng_uninstantiate());

  otcrypto_const_aligned_byte_buf_t rnd_buf = {.data = rnd, .len = sizeof(rnd)};
  return otcrypto_mldsa44_sign_derand(secret_key, message, context, sign_mode,
                                      rnd_buf, signature, work);
}

otcrypto_status_t otcrypto_mldsa44_sign_derand(
    const otcrypto_blinded_key_t *secret_key, otcrypto_const_byte_buf_t message,
    otcrypto_const_byte_buf_t context, otcrypto_mldsa_sign_mode_t sign_mode,
    otcrypto_const_aligned_byte_buf_t rnd,
    otcrypto_aligned_byte_buf_t signature,
    uint32_t work[kOtcryptoMldsa44WorkBufferSignWords]) {
  if (secret_key == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.key_mode != kOtcryptoKeyModeMldsa44) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.key_length != kOtcryptoMldsa44SecretKeyBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (sign_mode != kOtcryptoMldsaSignModeMldsa) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (rnd.len != kOtcryptoMldsa44SeedBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (signature.len < kOtcryptoMldsa44SignatureBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (context.len > 255) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (integrity_blinded_key_check(secret_key) != kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Secret keys are stored unmasked in share0 (share1 is zero).
  uint32_t *sk_share0;
  uint32_t *sk_share1;
  HARDENED_TRY(keyblob_to_shares(secret_key, &sk_share0, &sk_share1));

#ifdef ACC_HAS_PQC
  (void)work;
  HARDENED_TRY(mldsa_acc_44_sign(sk_share0, message.data, message.len,
                                 context.data, context.len, rnd.data,
                                 signature.data));
#else
  mld_alloc_ctx_t ctx = {.base = work,
                         .size_words = kOtcryptoMldsa44WorkBufferSignWords,
                         .offset_words = 0};

  uint32_t pre_buf[(2 + 255 + (sizeof(uint32_t) - 1)) / sizeof(uint32_t)];
  uint8_t *pre = (uint8_t *)pre_buf;
  pre[0] = 0;
  pre[1] = (uint8_t)context.len;
  if (context.len > 0) {
    memcpy(pre + 2, context.data, context.len);
  }

  size_t signature_len;
  int result = mldsa44_signature_internal(
      (uint8_t *)signature.data, &signature_len, message.data, message.len, pre,
      2 + context.len, (const uint8_t *)rnd.data, (const uint8_t *)sk_share0, 0,
      &ctx);

  if (result != 0) {
    return OTCRYPTO_FATAL_ERR;
  }
#endif

  return OTCRYPTO_OK;
}

otcrypto_status_t otcrypto_mldsa44_verify(
    const otcrypto_unblinded_key_t *public_key,
    otcrypto_const_byte_buf_t message, otcrypto_const_byte_buf_t context,
    otcrypto_mldsa_sign_mode_t sign_mode,
    otcrypto_const_aligned_byte_buf_t signature,
    hardened_bool_t *verification_result,
    uint32_t work[kOtcryptoMldsa44WorkBufferVerifyWords]) {
  if (public_key == NULL || verification_result == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (public_key->key_mode != kOtcryptoKeyModeMldsa44) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (public_key->key_length != kOtcryptoMldsa44PublicKeyBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (signature.len != kOtcryptoMldsa44SignatureBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (sign_mode != kOtcryptoMldsaSignModeMldsa) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (context.len > 255) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (integrity_unblinded_key_check(public_key) != kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }

#ifdef ACC_HAS_PQC
  (void)work;
  HARDENED_TRY(mldsa_acc_44_verify(public_key->key, message.data, message.len,
                                   context.data, context.len, signature.data,
                                   verification_result));
#else
  mld_alloc_ctx_t ctx = {.base = work,
                         .size_words = kOtcryptoMldsa44WorkBufferVerifyWords,
                         .offset_words = 0};
  int result = mldsa44_verify(
      (const uint8_t *)signature.data, signature.len, message.data, message.len,
      context.data, context.len, (const uint8_t *)public_key->key, &ctx);

  *verification_result = (result == 0) ? kHardenedBoolTrue : kHardenedBoolFalse;
#endif

  return OTCRYPTO_OK;
}

// ML-DSA-65 functions

otcrypto_status_t otcrypto_mldsa65_keygen(
    otcrypto_unblinded_key_t *public_key, otcrypto_blinded_key_t *secret_key,
    uint32_t work[kOtcryptoMldsa65WorkBufferKeypairWords]) {
  HARDENED_TRY(entropy_complex_check());

  uint32_t seed[ceil_div(kOtcryptoMldsa65SeedBytes, sizeof(uint32_t))];
  HARDENED_TRY(entropy_csrng_instantiate(
      /*disable_trng_input=*/kHardenedBoolFalse, &kEntropyEmptySeed));
  HARDENED_TRY(entropy_csrng_generate(&kEntropyEmptySeed, seed, ARRAYSIZE(seed),
                                      /*fips_check=*/kHardenedBoolTrue));
  HARDENED_TRY(entropy_csrng_uninstantiate());

  otcrypto_const_aligned_byte_buf_t seed_buf = {.data = seed,
                                                .len = sizeof(seed)};
  return otcrypto_mldsa65_keypair_derand(seed_buf, public_key, secret_key,
                                         work);
}

otcrypto_status_t otcrypto_mldsa65_keypair_derand(
    otcrypto_const_aligned_byte_buf_t seed,
    otcrypto_unblinded_key_t *public_key, otcrypto_blinded_key_t *secret_key,
    uint32_t work[kOtcryptoMldsa65WorkBufferKeypairWords]) {
  if (seed.len != kOtcryptoMldsa65SeedBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (public_key == NULL || secret_key == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (public_key->key_mode != kOtcryptoKeyModeMldsa65) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.key_mode != kOtcryptoKeyModeMldsa65) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (public_key->key_length != kOtcryptoMldsa65PublicKeyBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.key_length != kOtcryptoMldsa65SecretKeyBytes) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Write the unmasked secret key into the first share of the keyblob.
  uint32_t *sk_share0;
  uint32_t *sk_share1;
  HARDENED_TRY(keyblob_to_shares(secret_key, &sk_share0, &sk_share1));
  memset(sk_share1, 0, kOtcryptoMldsa65SecretKeyBytes);

#ifdef ACC_HAS_PQC
  (void)work;
  HARDENED_TRY(mldsa_acc_65_keygen(seed.data, public_key->key, sk_share0));
#else
  mld_alloc_ctx_t ctx = {.base = work,
                         .size_words = kOtcryptoMldsa65WorkBufferKeypairWords,
                         .offset_words = 0};
  int result =
      mldsa65_keypair_internal((uint8_t *)public_key->key, (uint8_t *)sk_share0,
                               (const uint8_t *)seed.data, &ctx);
  if (result != 0) {
    memset(sk_share0, 0, kOtcryptoMldsa65SecretKeyBytes);
    return OTCRYPTO_FATAL_ERR;
  }
#endif

  public_key->checksum = integrity_unblinded_checksum(public_key);
  secret_key->checksum = integrity_blinded_checksum(secret_key);

  return OTCRYPTO_OK;
}

otcrypto_status_t otcrypto_mldsa65_sign(
    const otcrypto_blinded_key_t *secret_key, otcrypto_const_byte_buf_t message,
    otcrypto_const_byte_buf_t context, otcrypto_mldsa_sign_mode_t sign_mode,
    otcrypto_aligned_byte_buf_t signature,
    uint32_t work[kOtcryptoMldsa65WorkBufferSignWords]) {
  HARDENED_TRY(entropy_complex_check());

  uint32_t rnd[ceil_div(kOtcryptoMldsa65SeedBytes, sizeof(uint32_t))];
  HARDENED_TRY(entropy_csrng_instantiate(
      /*disable_trng_input=*/kHardenedBoolFalse, &kEntropyEmptySeed));
  HARDENED_TRY(entropy_csrng_generate(&kEntropyEmptySeed, rnd, ARRAYSIZE(rnd),
                                      /*fips_check=*/kHardenedBoolTrue));
  HARDENED_TRY(entropy_csrng_uninstantiate());

  otcrypto_const_aligned_byte_buf_t rnd_buf = {.data = rnd, .len = sizeof(rnd)};
  return otcrypto_mldsa65_sign_derand(secret_key, message, context, sign_mode,
                                      rnd_buf, signature, work);
}

otcrypto_status_t otcrypto_mldsa65_sign_derand(
    const otcrypto_blinded_key_t *secret_key, otcrypto_const_byte_buf_t message,
    otcrypto_const_byte_buf_t context, otcrypto_mldsa_sign_mode_t sign_mode,
    otcrypto_const_aligned_byte_buf_t rnd,
    otcrypto_aligned_byte_buf_t signature,
    uint32_t work[kOtcryptoMldsa65WorkBufferSignWords]) {
  if (secret_key == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.key_mode != kOtcryptoKeyModeMldsa65) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.key_length != kOtcryptoMldsa65SecretKeyBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (sign_mode != kOtcryptoMldsaSignModeMldsa) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (rnd.len != kOtcryptoMldsa65SeedBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (signature.len < kOtcryptoMldsa65SignatureBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (context.len > 255) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (integrity_blinded_key_check(secret_key) != kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Secret keys are stored unmasked in share0 (share1 is zero).
  uint32_t *sk_share0;
  uint32_t *sk_share1;
  HARDENED_TRY(keyblob_to_shares(secret_key, &sk_share0, &sk_share1));

#ifdef ACC_HAS_PQC
  (void)work;
  HARDENED_TRY(mldsa_acc_65_sign(sk_share0, message.data, message.len,
                                 context.data, context.len, rnd.data,
                                 signature.data));
#else
  mld_alloc_ctx_t ctx = {.base = work,
                         .size_words = kOtcryptoMldsa65WorkBufferSignWords,
                         .offset_words = 0};

  uint32_t pre_buf[(2 + 255 + (sizeof(uint32_t) - 1)) / sizeof(uint32_t)];
  uint8_t *pre = (uint8_t *)pre_buf;
  pre[0] = 0;
  pre[1] = (uint8_t)context.len;
  if (context.len > 0) {
    memcpy(pre + 2, context.data, context.len);
  }

  size_t signature_len;
  int result = mldsa65_signature_internal(
      (uint8_t *)signature.data, &signature_len, message.data, message.len, pre,
      2 + context.len, (const uint8_t *)rnd.data, (const uint8_t *)sk_share0, 0,
      &ctx);

  if (result != 0) {
    return OTCRYPTO_FATAL_ERR;
  }
#endif

  return OTCRYPTO_OK;
}

otcrypto_status_t otcrypto_mldsa65_verify(
    const otcrypto_unblinded_key_t *public_key,
    otcrypto_const_byte_buf_t message, otcrypto_const_byte_buf_t context,
    otcrypto_mldsa_sign_mode_t sign_mode,
    otcrypto_const_aligned_byte_buf_t signature,
    hardened_bool_t *verification_result,
    uint32_t work[kOtcryptoMldsa65WorkBufferVerifyWords]) {
  if (public_key == NULL || verification_result == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (public_key->key_mode != kOtcryptoKeyModeMldsa65) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (public_key->key_length != kOtcryptoMldsa65PublicKeyBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (signature.len != kOtcryptoMldsa65SignatureBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (sign_mode != kOtcryptoMldsaSignModeMldsa) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (context.len > 255) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (integrity_unblinded_key_check(public_key) != kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }

#ifdef ACC_HAS_PQC
  (void)work;
  HARDENED_TRY(mldsa_acc_65_verify(public_key->key, message.data, message.len,
                                   context.data, context.len, signature.data,
                                   verification_result));
#else
  mld_alloc_ctx_t ctx = {.base = work,
                         .size_words = kOtcryptoMldsa65WorkBufferVerifyWords,
                         .offset_words = 0};
  int result = mldsa65_verify(
      (const uint8_t *)signature.data, signature.len, message.data, message.len,
      context.data, context.len, (const uint8_t *)public_key->key, &ctx);

  *verification_result = (result == 0) ? kHardenedBoolTrue : kHardenedBoolFalse;
#endif

  return OTCRYPTO_OK;
}

// ML-DSA-87 functions

otcrypto_status_t otcrypto_mldsa87_keygen(
    otcrypto_unblinded_key_t *public_key, otcrypto_blinded_key_t *secret_key,
    uint32_t work[kOtcryptoMldsa87WorkBufferKeypairWords]) {
  HARDENED_TRY(entropy_complex_check());

  uint32_t seed[ceil_div(kOtcryptoMldsa87SeedBytes, sizeof(uint32_t))];
  HARDENED_TRY(entropy_csrng_instantiate(
      /*disable_trng_input=*/kHardenedBoolFalse, &kEntropyEmptySeed));
  HARDENED_TRY(entropy_csrng_generate(&kEntropyEmptySeed, seed, ARRAYSIZE(seed),
                                      /*fips_check=*/kHardenedBoolTrue));
  HARDENED_TRY(entropy_csrng_uninstantiate());

  otcrypto_const_aligned_byte_buf_t seed_buf = {.data = seed,
                                                .len = sizeof(seed)};
  return otcrypto_mldsa87_keypair_derand(seed_buf, public_key, secret_key,
                                         work);
}

otcrypto_status_t otcrypto_mldsa87_keypair_derand(
    otcrypto_const_aligned_byte_buf_t seed,
    otcrypto_unblinded_key_t *public_key, otcrypto_blinded_key_t *secret_key,
    uint32_t work[kOtcryptoMldsa87WorkBufferKeypairWords]) {
  if (seed.len != kOtcryptoMldsa87SeedBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (public_key == NULL || secret_key == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (public_key->key_mode != kOtcryptoKeyModeMldsa87) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.key_mode != kOtcryptoKeyModeMldsa87) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (public_key->key_length != kOtcryptoMldsa87PublicKeyBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.key_length != kOtcryptoMldsa87SecretKeyBytes) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Write the unmasked secret key into the first share of the keyblob.
  uint32_t *sk_share0;
  uint32_t *sk_share1;
  HARDENED_TRY(keyblob_to_shares(secret_key, &sk_share0, &sk_share1));
  memset(sk_share1, 0, kOtcryptoMldsa87SecretKeyBytes);

#ifdef ACC_HAS_PQC
  (void)work;
  HARDENED_TRY(mldsa_acc_87_keygen(seed.data, public_key->key, sk_share0));
#else
  mld_alloc_ctx_t ctx = {.base = work,
                         .size_words = kOtcryptoMldsa87WorkBufferKeypairWords,
                         .offset_words = 0};
  int result =
      mldsa87_keypair_internal((uint8_t *)public_key->key, (uint8_t *)sk_share0,
                               (const uint8_t *)seed.data, &ctx);
  if (result != 0) {
    memset(sk_share0, 0, kOtcryptoMldsa87SecretKeyBytes);
    return OTCRYPTO_FATAL_ERR;
  }
#endif

  public_key->checksum = integrity_unblinded_checksum(public_key);
  secret_key->checksum = integrity_blinded_checksum(secret_key);

  return OTCRYPTO_OK;
}

otcrypto_status_t otcrypto_mldsa87_sign(
    const otcrypto_blinded_key_t *secret_key, otcrypto_const_byte_buf_t message,
    otcrypto_const_byte_buf_t context, otcrypto_mldsa_sign_mode_t sign_mode,
    otcrypto_aligned_byte_buf_t signature,
    uint32_t work[kOtcryptoMldsa87WorkBufferSignWords]) {
  HARDENED_TRY(entropy_complex_check());

  uint32_t rnd[ceil_div(kOtcryptoMldsa87SeedBytes, sizeof(uint32_t))];
  HARDENED_TRY(entropy_csrng_instantiate(
      /*disable_trng_input=*/kHardenedBoolFalse, &kEntropyEmptySeed));
  HARDENED_TRY(entropy_csrng_generate(&kEntropyEmptySeed, rnd, ARRAYSIZE(rnd),
                                      /*fips_check=*/kHardenedBoolTrue));
  HARDENED_TRY(entropy_csrng_uninstantiate());

  otcrypto_const_aligned_byte_buf_t rnd_buf = {.data = rnd, .len = sizeof(rnd)};
  return otcrypto_mldsa87_sign_derand(secret_key, message, context, sign_mode,
                                      rnd_buf, signature, work);
}

otcrypto_status_t otcrypto_mldsa87_sign_derand(
    const otcrypto_blinded_key_t *secret_key, otcrypto_const_byte_buf_t message,
    otcrypto_const_byte_buf_t context, otcrypto_mldsa_sign_mode_t sign_mode,
    otcrypto_const_aligned_byte_buf_t rnd,
    otcrypto_aligned_byte_buf_t signature,
    uint32_t work[kOtcryptoMldsa87WorkBufferSignWords]) {
  if (secret_key == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.key_mode != kOtcryptoKeyModeMldsa87) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (secret_key->config.key_length != kOtcryptoMldsa87SecretKeyBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (sign_mode != kOtcryptoMldsaSignModeMldsa) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (rnd.len != kOtcryptoMldsa87SeedBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (signature.len < kOtcryptoMldsa87SignatureBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (context.len > 255) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (integrity_blinded_key_check(secret_key) != kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Secret keys are stored unmasked in share0 (share1 is zero).
  uint32_t *sk_share0;
  uint32_t *sk_share1;
  HARDENED_TRY(keyblob_to_shares(secret_key, &sk_share0, &sk_share1));

#ifdef ACC_HAS_PQC
  (void)work;
  HARDENED_TRY(mldsa_acc_87_sign(sk_share0, message.data, message.len,
                                 context.data, context.len, rnd.data,
                                 signature.data));
#else
  mld_alloc_ctx_t ctx = {.base = work,
                         .size_words = kOtcryptoMldsa87WorkBufferSignWords,
                         .offset_words = 0};

  uint32_t pre_buf[(2 + 255 + (sizeof(uint32_t) - 1)) / sizeof(uint32_t)];
  uint8_t *pre = (uint8_t *)pre_buf;
  pre[0] = 0;
  pre[1] = (uint8_t)context.len;
  if (context.len > 0) {
    memcpy(pre + 2, context.data, context.len);
  }

  size_t signature_len;
  int result = mldsa87_signature_internal(
      (uint8_t *)signature.data, &signature_len, message.data, message.len, pre,
      2 + context.len, (const uint8_t *)rnd.data, (const uint8_t *)sk_share0, 0,
      &ctx);

  if (result != 0) {
    return OTCRYPTO_FATAL_ERR;
  }
#endif

  return OTCRYPTO_OK;
}

otcrypto_status_t otcrypto_mldsa87_verify(
    const otcrypto_unblinded_key_t *public_key,
    otcrypto_const_byte_buf_t message, otcrypto_const_byte_buf_t context,
    otcrypto_mldsa_sign_mode_t sign_mode,
    otcrypto_const_aligned_byte_buf_t signature,
    hardened_bool_t *verification_result,
    uint32_t work[kOtcryptoMldsa87WorkBufferVerifyWords]) {
  if (public_key == NULL || verification_result == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (public_key->key_mode != kOtcryptoKeyModeMldsa87) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (public_key->key_length != kOtcryptoMldsa87PublicKeyBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (signature.len != kOtcryptoMldsa87SignatureBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (sign_mode != kOtcryptoMldsaSignModeMldsa) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (context.len > 255) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (integrity_unblinded_key_check(public_key) != kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }

#ifdef ACC_HAS_PQC
  (void)work;
  HARDENED_TRY(mldsa_acc_87_verify(public_key->key, message.data, message.len,
                                   context.data, context.len, signature.data,
                                   verification_result));
#else
  mld_alloc_ctx_t ctx = {.base = work,
                         .size_words = kOtcryptoMldsa87WorkBufferVerifyWords,
                         .offset_words = 0};
  int result = mldsa87_verify(
      (const uint8_t *)signature.data, signature.len, message.data, message.len,
      context.data, context.len, (const uint8_t *)public_key->key, &ctx);

  *verification_result = (result == 0) ? kHardenedBoolTrue : kHardenedBoolFalse;
#endif

  return OTCRYPTO_OK;
}
