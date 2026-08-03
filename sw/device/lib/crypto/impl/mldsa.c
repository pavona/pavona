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
#include "sw/device/lib/crypto/include/sha2.h"
#include "sw/device/lib/crypto/include/sha3.h"
#ifdef ACC_HAS_PQC
#include "sw/device/lib/crypto/impl/mldsa/acc/mldsa_acc.h"
#else
#include "sw/device/lib/crypto/impl/mldsa/mldsa-native/mldsa_native_monobuild.h"
#endif

// Module ID for status codes.
#define MODULE_ID MAKE_MODULE_ID('m', 'l', 'd')

#ifndef ACC_HAS_PQC
// Static assertions to verify buffer sizes match mldsa-native
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
#endif  // ACC_HAS_PQC

enum {
  // Largest pre-hash digest among the supported HashML-DSA modes
  // (SHA2-512/SHA3-512/SHAKE256).
  kMldsaPreHashMaxBytes = 64,
  kMldsaPreHashMaxWords = kMldsaPreHashMaxBytes / sizeof(uint32_t),
};

// FIPS 204 message representative (mu) is always 64 bytes. Under
// ACC_HAS_PQC, `kMldsaMuBytes` already comes from mldsa_acc.h (included
// above); only define it here for the software backend, where it doesn't
// otherwise exist.
#ifndef ACC_HAS_PQC
enum {
  kMldsaMuBytes = 64,
};
_Static_assert(kMldsaMuBytes == MLDSA_CRHBYTES,
               "ML-DSA mu size mismatch with mldsa-native");
#endif

// Computes PH(M) for HashML-DSA. `sign_mode` must not be the pure mode.
// `ph` is word-typed (rather than `uint8_t`) because the hash drivers write
// the digest via word-sized MMIO reads and require a word-aligned output
// buffer.
static otcrypto_status_t mldsa_prehash_digest(
    otcrypto_mldsa_sign_mode_t sign_mode, otcrypto_const_byte_buf_t message,
    uint32_t ph[kMldsaPreHashMaxWords], size_t *ph_len) {
  otcrypto_hash_digest_t digest = {.data = ph};
  switch (launder32(sign_mode)) {
    case kOtcryptoMldsaSignModeHashMldsaSha2_256:
      HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeHashMldsaSha2_256);
      *ph_len = 32;
      digest.len = *ph_len / sizeof(uint32_t);
      return otcrypto_sha2_256(message, &digest);
    case kOtcryptoMldsaSignModeHashMldsaSha2_384:
      HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeHashMldsaSha2_384);
      *ph_len = 48;
      digest.len = *ph_len / sizeof(uint32_t);
      return otcrypto_sha2_384(message, &digest);
    case kOtcryptoMldsaSignModeHashMldsaSha2_512:
      HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeHashMldsaSha2_512);
      *ph_len = 64;
      digest.len = *ph_len / sizeof(uint32_t);
      return otcrypto_sha2_512(message, &digest);
    case kOtcryptoMldsaSignModeHashMldsaSha3_224:
      HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeHashMldsaSha3_224);
      *ph_len = 28;
      digest.len = *ph_len / sizeof(uint32_t);
      return otcrypto_sha3_224(message, &digest);
    case kOtcryptoMldsaSignModeHashMldsaSha3_256:
      HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeHashMldsaSha3_256);
      *ph_len = 32;
      digest.len = *ph_len / sizeof(uint32_t);
      return otcrypto_sha3_256(message, &digest);
    case kOtcryptoMldsaSignModeHashMldsaSha3_384:
      HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeHashMldsaSha3_384);
      *ph_len = 48;
      digest.len = *ph_len / sizeof(uint32_t);
      return otcrypto_sha3_384(message, &digest);
    case kOtcryptoMldsaSignModeHashMldsaSha3_512:
      HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeHashMldsaSha3_512);
      *ph_len = 64;
      digest.len = *ph_len / sizeof(uint32_t);
      return otcrypto_sha3_512(message, &digest);
    case kOtcryptoMldsaSignModeHashMldsaShake128:
      HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeHashMldsaShake128);
      *ph_len = 32;
      digest.len = *ph_len / sizeof(uint32_t);
      return otcrypto_shake128(message, &digest);
    case kOtcryptoMldsaSignModeHashMldsaShake256:
      HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeHashMldsaShake256);
      *ph_len = 64;
      digest.len = *ph_len / sizeof(uint32_t);
      return otcrypto_shake256(message, &digest);
    default:
      return OTCRYPTO_BAD_ARGS;
  }

  // Should be unreachable.
  HARDENED_TRAP();
  return OTCRYPTO_FATAL_ERR;
}

#ifndef ACC_HAS_PQC
// Maps a HashML-DSA sign mode to the mldsa-native MLD_PREHASH_* constant.
// `sign_mode` must be one of the `kOtcryptoMldsaSignModeHashMldsa*` values.
static int mldsa_native_prehash_alg(otcrypto_mldsa_sign_mode_t sign_mode) {
  switch (launder32(sign_mode)) {
    case kOtcryptoMldsaSignModeHashMldsaSha2_256:
      HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeHashMldsaSha2_256);
      return MLD_PREHASH_SHA2_256;
    case kOtcryptoMldsaSignModeHashMldsaSha2_384:
      HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeHashMldsaSha2_384);
      return MLD_PREHASH_SHA2_384;
    case kOtcryptoMldsaSignModeHashMldsaSha2_512:
      HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeHashMldsaSha2_512);
      return MLD_PREHASH_SHA2_512;
    case kOtcryptoMldsaSignModeHashMldsaSha3_224:
      HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeHashMldsaSha3_224);
      return MLD_PREHASH_SHA3_224;
    case kOtcryptoMldsaSignModeHashMldsaSha3_256:
      HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeHashMldsaSha3_256);
      return MLD_PREHASH_SHA3_256;
    case kOtcryptoMldsaSignModeHashMldsaSha3_384:
      HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeHashMldsaSha3_384);
      return MLD_PREHASH_SHA3_384;
    case kOtcryptoMldsaSignModeHashMldsaSha3_512:
      HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeHashMldsaSha3_512);
      return MLD_PREHASH_SHA3_512;
    case kOtcryptoMldsaSignModeHashMldsaShake128:
      HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeHashMldsaShake128);
      return MLD_PREHASH_SHAKE_128;
    case kOtcryptoMldsaSignModeHashMldsaShake256:
      HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeHashMldsaShake256);
      return MLD_PREHASH_SHAKE_256;
    default:
      // Should be unreachable: mldsa_prehash_digest() already rejected any
      // sign_mode that isn't a supported hash mode.
      HARDENED_TRAP();
      return MLD_PREHASH_NONE;
  }
}
#endif

otcrypto_status_t otcrypto_mldsa44_keygen(
    otcrypto_unblinded_key_t *public_key, otcrypto_blinded_key_t *secret_key,
    uint32_t work[kOtcryptoMldsa44WorkBufferKeypairWords]) {
  HARDENED_TRY(entropy_complex_check());
#if defined(ACC_MLDSA_HARDENED)
  uint32_t seed[ceil_div(2 * kOtcryptoMldsa44SeedBytes, sizeof(uint32_t))];
#else
  uint32_t seed[ceil_div(kOtcryptoMldsa44SeedBytes, sizeof(uint32_t))];
#endif
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
#if defined(ACC_MLDSA_HARDENED)
  // Seed is masked, so buffer must be twice as long.
  if (seed.len != 2 * kOtcryptoMldsa44SeedBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
#else
  if (seed.len != kOtcryptoMldsa44SeedBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
#endif
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

  HARDENED_TRY(check_keyblob_length(secret_key));

#if defined(ACC_MLDSA_HARDENED)
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

#if defined(ACC_HAS_PQC) && defined(ACC_MLDSA_HARDENED)
  (void)work;
  const uint32_t *seed_share0 = seed.data;
  const uint32_t *seed_share1 =
      &seed.data[ceil_div(kOtcryptoMldsa44SeedBytes, sizeof(uint32_t))];
  HARDENED_TRY(mldsa_acc_44_keygen_hardened(
      seed_share0, seed_share1, public_key->key, secret_key->keyblob));
#elif defined(ACC_HAS_PQC)
  (void)work;
  HARDENED_TRY(
      mldsa_acc_44_keygen(seed.data, public_key->key, secret_key->keyblob));
#else
  mld_alloc_ctx_t ctx = {.base = work,
                         .size_words = kOtcryptoMldsa44WorkBufferKeypairWords,
                         .offset_words = 0};
  int result = mldsa44_keypair_internal((uint8_t *)public_key->key,
                                        (uint8_t *)secret_key->keyblob,
                                        (const uint8_t *)seed.data, &ctx);
  if (result != 0) {
    memset(secret_key->keyblob, 0, kOtcryptoMldsa44SecretKeyBytes);
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

  HARDENED_TRY(check_keyblob_length(secret_key));

  uint32_t ph[kMldsaPreHashMaxWords];
  size_t ph_len = 0;
  if (launder32(sign_mode) == kOtcryptoMldsaSignModeExternalMu) {
    HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeExternalMu);
    if (message.len != kMldsaMuBytes || context.len != 0) {
      return OTCRYPTO_BAD_ARGS;
    }
  } else if (launder32(sign_mode) != kOtcryptoMldsaSignModeMldsa) {
    HARDENED_CHECK_NE(sign_mode, kOtcryptoMldsaSignModeMldsa);
    HARDENED_TRY(mldsa_prehash_digest(sign_mode, message, ph, &ph_len));
  }

#if defined(ACC_MLDSA_HARDENED)
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

#if defined(ACC_HAS_PQC) && defined(ACC_MLDSA_HARDENED)
  (void)work;
  if (launder32(sign_mode) == kOtcryptoMldsaSignModeMldsa) {
    HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeMldsa);
    HARDENED_TRY(mldsa_acc_44_sign_hardened(
        secret_key->keyblob, message.data, message.len, context.data,
        context.len, rnd.data, signature.data));
  } else if (launder32(sign_mode) == kOtcryptoMldsaSignModeExternalMu) {
    HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeExternalMu);
    uint32_t align_message[kMldsaMuWords];
    memcpy(align_message, message.data, kMldsaMuBytes);
    HARDENED_TRY(mldsa_acc_44_sign_mu_hardened(
        secret_key->keyblob, align_message, rnd.data, signature.data));
  } else {
    HARDENED_CHECK_NE(sign_mode, kOtcryptoMldsaSignModeMldsa);
    HARDENED_CHECK_NE(sign_mode, kOtcryptoMldsaSignModeExternalMu);
    HARDENED_TRY(mldsa_acc_44_sign_pre_hash_hardened(
        secret_key->keyblob, (uint8_t *)ph, ph_len, context.data, context.len,
        sign_mode, rnd.data, signature.data));
  }
#elif defined(ACC_HAS_PQC)
  (void)work;
  if (launder32(sign_mode) == kOtcryptoMldsaSignModeMldsa) {
    HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeMldsa);
    HARDENED_TRY(mldsa_acc_44_sign(secret_key->keyblob, message.data,
                                   message.len, context.data, context.len,
                                   rnd.data, signature.data));
  } else if (launder32(sign_mode) == kOtcryptoMldsaSignModeExternalMu) {
    HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeExternalMu);
    uint32_t align_message[kMldsaMuWords];
    memcpy(align_message, message.data, kMldsaMuBytes);
    HARDENED_TRY(mldsa_acc_44_sign_mu(secret_key->keyblob, align_message,
                                      rnd.data, signature.data));
  } else {
    HARDENED_CHECK_NE(sign_mode, kOtcryptoMldsaSignModeMldsa);
    HARDENED_CHECK_NE(sign_mode, kOtcryptoMldsaSignModeExternalMu);
    HARDENED_TRY(mldsa_acc_44_sign_pre_hash(
        secret_key->keyblob, (uint8_t *)ph, ph_len, context.data, context.len,
        sign_mode, rnd.data, signature.data));
  }
#else
  mld_alloc_ctx_t ctx = {.base = work,
                         .size_words = kOtcryptoMldsa44WorkBufferSignWords,
                         .offset_words = 0};
  int result;
  if (launder32(sign_mode) == kOtcryptoMldsaSignModeMldsa) {
    HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeMldsa);
    uint32_t pre_buf[(2 + 255 + (sizeof(uint32_t) - 1)) / sizeof(uint32_t)];
    uint8_t *pre = (uint8_t *)pre_buf;
    pre[0] = 0;
    pre[1] = (uint8_t)context.len;
    if (context.len > 0) {
      memcpy(pre + 2, context.data, context.len);
    }
    result = mldsa44_signature_internal(
        (uint8_t *)signature.data, message.data, message.len, pre,
        2 + context.len, (const uint8_t *)rnd.data,
        (const uint8_t *)secret_key->keyblob, 0, &ctx);
  } else if (launder32(sign_mode) == kOtcryptoMldsaSignModeExternalMu) {
    HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeExternalMu);
    result = mldsa44_signature_internal(
        (uint8_t *)signature.data, message.data, kMldsaMuBytes, NULL, 0,
        (const uint8_t *)rnd.data, (const uint8_t *)secret_key->keyblob, 1,
        &ctx);
  } else {
    HARDENED_CHECK_NE(sign_mode, kOtcryptoMldsaSignModeMldsa);
    HARDENED_CHECK_NE(sign_mode, kOtcryptoMldsaSignModeExternalMu);
    result = mldsa44_signature_pre_hash_internal(
        (uint8_t *)signature.data, (uint8_t *)ph, ph_len, context.data,
        context.len, (const uint8_t *)rnd.data,
        (const uint8_t *)secret_key->keyblob,
        mldsa_native_prehash_alg(sign_mode), &ctx);
  }

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
  if (context.len > 255) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (integrity_unblinded_key_check(public_key) != kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }

  uint32_t ph[kMldsaPreHashMaxWords];
  size_t ph_len = 0;
  if (launder32(sign_mode) == kOtcryptoMldsaSignModeExternalMu) {
    HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeExternalMu);
    if (message.len != kMldsaMuBytes || context.len != 0) {
      return OTCRYPTO_BAD_ARGS;
    }
  } else if (launder32(sign_mode) != kOtcryptoMldsaSignModeMldsa) {
    HARDENED_CHECK_NE(sign_mode, kOtcryptoMldsaSignModeMldsa);
    HARDENED_TRY(mldsa_prehash_digest(sign_mode, message, ph, &ph_len));
  }

#ifdef ACC_HAS_PQC
  (void)work;
  if (launder32(sign_mode) == kOtcryptoMldsaSignModeMldsa) {
    HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeMldsa);
    HARDENED_TRY(mldsa_acc_44_verify(public_key->key, message.data, message.len,
                                     context.data, context.len, signature.data,
                                     verification_result));
  } else if (launder32(sign_mode) == kOtcryptoMldsaSignModeExternalMu) {
    HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeExternalMu);
    uint32_t align_message[kMldsaMuWords];
    memcpy(align_message, message.data, kMldsaMuBytes);
    HARDENED_TRY(mldsa_acc_44_verify_mu(public_key->key, align_message,
                                        signature.data, verification_result));
  } else {
    HARDENED_CHECK_NE(sign_mode, kOtcryptoMldsaSignModeMldsa);
    HARDENED_CHECK_NE(sign_mode, kOtcryptoMldsaSignModeExternalMu);
    HARDENED_TRY(mldsa_acc_44_verify_pre_hash(
        public_key->key, (uint8_t *)ph, ph_len, context.data, context.len,
        sign_mode, signature.data, verification_result));
  }
#else
  mld_alloc_ctx_t ctx = {.base = work,
                         .size_words = kOtcryptoMldsa44WorkBufferVerifyWords,
                         .offset_words = 0};
  int result;
  if (launder32(sign_mode) == kOtcryptoMldsaSignModeMldsa) {
    HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeMldsa);
    result = mldsa44_verify((const uint8_t *)signature.data, message.data,
                            message.len, context.data, context.len,
                            (const uint8_t *)public_key->key, &ctx);
  } else if (launder32(sign_mode) == kOtcryptoMldsaSignModeExternalMu) {
    HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeExternalMu);
    result = mldsa44_verify_extmu((const uint8_t *)signature.data, message.data,
                                  (const uint8_t *)public_key->key, &ctx);
  } else {
    HARDENED_CHECK_NE(sign_mode, kOtcryptoMldsaSignModeMldsa);
    HARDENED_CHECK_NE(sign_mode, kOtcryptoMldsaSignModeExternalMu);
    result = mldsa44_verify_pre_hash_internal(
        (const uint8_t *)signature.data, (uint8_t *)ph, ph_len, context.data,
        context.len, (const uint8_t *)public_key->key,
        mldsa_native_prehash_alg(sign_mode), &ctx);
  }

  *verification_result = (result == 0) ? kHardenedBoolTrue : kHardenedBoolFalse;
#endif

  return OTCRYPTO_OK;
}

// ML-DSA-65 functions

otcrypto_status_t otcrypto_mldsa65_keygen(
    otcrypto_unblinded_key_t *public_key, otcrypto_blinded_key_t *secret_key,
    uint32_t work[kOtcryptoMldsa65WorkBufferKeypairWords]) {
  HARDENED_TRY(entropy_complex_check());

#if defined(ACC_MLDSA_HARDENED)
  uint32_t seed[ceil_div(2 * kOtcryptoMldsa65SeedBytes, sizeof(uint32_t))];
#else
  uint32_t seed[ceil_div(kOtcryptoMldsa65SeedBytes, sizeof(uint32_t))];
#endif
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
#if defined(ACC_MLDSA_HARDENED)
  // Seed is masked, so buffer must be twice as long.
  if (seed.len != 2 * kOtcryptoMldsa65SeedBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
#else
  if (seed.len != kOtcryptoMldsa65SeedBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
#endif
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

  HARDENED_TRY(check_keyblob_length(secret_key));

#if defined(ACC_MLDSA_HARDENED)
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

#if defined(ACC_HAS_PQC) && defined(ACC_MLDSA_HARDENED)
  (void)work;
  const uint32_t *seed_share0 = seed.data;
  const uint32_t *seed_share1 =
      &seed.data[ceil_div(kOtcryptoMldsa65SeedBytes, sizeof(uint32_t))];
  HARDENED_TRY(mldsa_acc_65_keygen_hardened(
      seed_share0, seed_share1, public_key->key, secret_key->keyblob));
#elif defined(ACC_HAS_PQC)
  (void)work;
  HARDENED_TRY(
      mldsa_acc_65_keygen(seed.data, public_key->key, secret_key->keyblob));
#else
  mld_alloc_ctx_t ctx = {.base = work,
                         .size_words = kOtcryptoMldsa65WorkBufferKeypairWords,
                         .offset_words = 0};
  int result = mldsa65_keypair_internal((uint8_t *)public_key->key,
                                        (uint8_t *)secret_key->keyblob,
                                        (const uint8_t *)seed.data, &ctx);
  if (result != 0) {
    memset(secret_key->keyblob, 0, kOtcryptoMldsa65SecretKeyBytes);
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

  HARDENED_TRY(check_keyblob_length(secret_key));

  uint32_t ph[kMldsaPreHashMaxWords];
  size_t ph_len = 0;
  if (launder32(sign_mode) == kOtcryptoMldsaSignModeExternalMu) {
    HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeExternalMu);
    if (message.len != kMldsaMuBytes || context.len != 0) {
      return OTCRYPTO_BAD_ARGS;
    }
  } else if (launder32(sign_mode) != kOtcryptoMldsaSignModeMldsa) {
    HARDENED_CHECK_NE(sign_mode, kOtcryptoMldsaSignModeMldsa);
    HARDENED_TRY(mldsa_prehash_digest(sign_mode, message, ph, &ph_len));
  }

#if defined(ACC_MLDSA_HARDENED)
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

#if defined(ACC_HAS_PQC) && defined(ACC_MLDSA_HARDENED)
  (void)work;
  if (launder32(sign_mode) == kOtcryptoMldsaSignModeMldsa) {
    HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeMldsa);
    HARDENED_TRY(mldsa_acc_65_sign_hardened(
        secret_key->keyblob, message.data, message.len, context.data,
        context.len, rnd.data, signature.data));
  } else if (launder32(sign_mode) == kOtcryptoMldsaSignModeExternalMu) {
    HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeExternalMu);
    uint32_t align_message[kMldsaMuWords];
    memcpy(align_message, message.data, kMldsaMuBytes);
    HARDENED_TRY(mldsa_acc_65_sign_mu_hardened(
        secret_key->keyblob, align_message, rnd.data, signature.data));
  } else {
    HARDENED_CHECK_NE(sign_mode, kOtcryptoMldsaSignModeMldsa);
    HARDENED_CHECK_NE(sign_mode, kOtcryptoMldsaSignModeExternalMu);
    HARDENED_TRY(mldsa_acc_65_sign_pre_hash_hardened(
        secret_key->keyblob, (uint8_t *)ph, ph_len, context.data, context.len,
        sign_mode, rnd.data, signature.data));
  }
#elif defined(ACC_HAS_PQC)
  (void)work;
  if (launder32(sign_mode) == kOtcryptoMldsaSignModeMldsa) {
    HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeMldsa);
    HARDENED_TRY(mldsa_acc_65_sign(secret_key->keyblob, message.data,
                                   message.len, context.data, context.len,
                                   rnd.data, signature.data));
  } else if (launder32(sign_mode) == kOtcryptoMldsaSignModeExternalMu) {
    HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeExternalMu);
    uint32_t align_message[kMldsaMuWords];
    memcpy(align_message, message.data, kMldsaMuBytes);
    HARDENED_TRY(mldsa_acc_65_sign_mu(secret_key->keyblob, align_message,
                                      rnd.data, signature.data));
  } else {
    HARDENED_CHECK_NE(sign_mode, kOtcryptoMldsaSignModeMldsa);
    HARDENED_CHECK_NE(sign_mode, kOtcryptoMldsaSignModeExternalMu);
    HARDENED_TRY(mldsa_acc_65_sign_pre_hash(
        secret_key->keyblob, (uint8_t *)ph, ph_len, context.data, context.len,
        sign_mode, rnd.data, signature.data));
  }
#else
  mld_alloc_ctx_t ctx = {.base = work,
                         .size_words = kOtcryptoMldsa65WorkBufferSignWords,
                         .offset_words = 0};
  int result;
  if (launder32(sign_mode) == kOtcryptoMldsaSignModeMldsa) {
    HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeMldsa);
    uint32_t pre_buf[(2 + 255 + (sizeof(uint32_t) - 1)) / sizeof(uint32_t)];
    uint8_t *pre = (uint8_t *)pre_buf;
    pre[0] = 0;
    pre[1] = (uint8_t)context.len;
    if (context.len > 0) {
      memcpy(pre + 2, context.data, context.len);
    }
    result = mldsa65_signature_internal(
        (uint8_t *)signature.data, message.data, message.len, pre,
        2 + context.len, (const uint8_t *)rnd.data,
        (const uint8_t *)secret_key->keyblob, 0, &ctx);
  } else if (launder32(sign_mode) == kOtcryptoMldsaSignModeExternalMu) {
    HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeExternalMu);
    result = mldsa65_signature_internal(
        (uint8_t *)signature.data, message.data, kMldsaMuBytes, NULL, 0,
        (const uint8_t *)rnd.data, (const uint8_t *)secret_key->keyblob, 1,
        &ctx);
  } else {
    HARDENED_CHECK_NE(sign_mode, kOtcryptoMldsaSignModeMldsa);
    HARDENED_CHECK_NE(sign_mode, kOtcryptoMldsaSignModeExternalMu);
    result = mldsa65_signature_pre_hash_internal(
        (uint8_t *)signature.data, (uint8_t *)ph, ph_len, context.data,
        context.len, (const uint8_t *)rnd.data,
        (const uint8_t *)secret_key->keyblob,
        mldsa_native_prehash_alg(sign_mode), &ctx);
  }

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
  if (context.len > 255) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (integrity_unblinded_key_check(public_key) != kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }

  uint32_t ph[kMldsaPreHashMaxWords];
  size_t ph_len = 0;
  if (launder32(sign_mode) == kOtcryptoMldsaSignModeExternalMu) {
    HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeExternalMu);
    if (message.len != kMldsaMuBytes || context.len != 0) {
      return OTCRYPTO_BAD_ARGS;
    }
  } else if (launder32(sign_mode) != kOtcryptoMldsaSignModeMldsa) {
    HARDENED_CHECK_NE(sign_mode, kOtcryptoMldsaSignModeMldsa);
    HARDENED_TRY(mldsa_prehash_digest(sign_mode, message, ph, &ph_len));
  }

#ifdef ACC_HAS_PQC
  (void)work;
  if (launder32(sign_mode) == kOtcryptoMldsaSignModeMldsa) {
    HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeMldsa);
    HARDENED_TRY(mldsa_acc_65_verify(public_key->key, message.data, message.len,
                                     context.data, context.len, signature.data,
                                     verification_result));
  } else if (launder32(sign_mode) == kOtcryptoMldsaSignModeExternalMu) {
    HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeExternalMu);
    uint32_t align_message[kMldsaMuWords];
    memcpy(align_message, message.data, kMldsaMuBytes);
    HARDENED_TRY(mldsa_acc_65_verify_mu(public_key->key, align_message,
                                        signature.data, verification_result));
  } else {
    HARDENED_CHECK_NE(sign_mode, kOtcryptoMldsaSignModeMldsa);
    HARDENED_CHECK_NE(sign_mode, kOtcryptoMldsaSignModeExternalMu);
    HARDENED_TRY(mldsa_acc_65_verify_pre_hash(
        public_key->key, (uint8_t *)ph, ph_len, context.data, context.len,
        sign_mode, signature.data, verification_result));
  }
#else
  mld_alloc_ctx_t ctx = {.base = work,
                         .size_words = kOtcryptoMldsa65WorkBufferVerifyWords,
                         .offset_words = 0};
  int result;
  if (launder32(sign_mode) == kOtcryptoMldsaSignModeMldsa) {
    HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeMldsa);
    result = mldsa65_verify((const uint8_t *)signature.data, message.data,
                            message.len, context.data, context.len,
                            (const uint8_t *)public_key->key, &ctx);
  } else if (launder32(sign_mode) == kOtcryptoMldsaSignModeExternalMu) {
    HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeExternalMu);
    result = mldsa65_verify_extmu((const uint8_t *)signature.data, message.data,
                                  (const uint8_t *)public_key->key, &ctx);
  } else {
    HARDENED_CHECK_NE(sign_mode, kOtcryptoMldsaSignModeMldsa);
    HARDENED_CHECK_NE(sign_mode, kOtcryptoMldsaSignModeExternalMu);
    result = mldsa65_verify_pre_hash_internal(
        (const uint8_t *)signature.data, (uint8_t *)ph, ph_len, context.data,
        context.len, (const uint8_t *)public_key->key,
        mldsa_native_prehash_alg(sign_mode), &ctx);
  }

  *verification_result = (result == 0) ? kHardenedBoolTrue : kHardenedBoolFalse;
#endif

  return OTCRYPTO_OK;
}

// ML-DSA-87 functions

otcrypto_status_t otcrypto_mldsa87_keygen(
    otcrypto_unblinded_key_t *public_key, otcrypto_blinded_key_t *secret_key,
    uint32_t work[kOtcryptoMldsa87WorkBufferKeypairWords]) {
  HARDENED_TRY(entropy_complex_check());
#if defined(ACC_MLDSA_HARDENED)
  uint32_t seed[ceil_div(2 * kOtcryptoMldsa87SeedBytes, sizeof(uint32_t))];
#else
  uint32_t seed[ceil_div(kOtcryptoMldsa87SeedBytes, sizeof(uint32_t))];
#endif
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
#if defined(ACC_MLDSA_HARDENED)
  // Seed is masked, so buffer must be twice as long.
  if (seed.len != 2 * kOtcryptoMldsa87SeedBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
#else
  if (seed.len != kOtcryptoMldsa87SeedBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
#endif
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

  HARDENED_TRY(check_keyblob_length(secret_key));

#if defined(ACC_MLDSA_HARDENED)
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

#if defined(ACC_HAS_PQC) && defined(ACC_MLDSA_HARDENED)
  (void)work;
  const uint32_t *seed_share0 = seed.data;
  const uint32_t *seed_share1 =
      &seed.data[ceil_div(kOtcryptoMldsa87SeedBytes, sizeof(uint32_t))];
  HARDENED_TRY(mldsa_acc_87_keygen_hardened(
      seed_share0, seed_share1, public_key->key, secret_key->keyblob));
#elif defined(ACC_HAS_PQC)
  (void)work;
  HARDENED_TRY(
      mldsa_acc_87_keygen(seed.data, public_key->key, secret_key->keyblob));
#else
  mld_alloc_ctx_t ctx = {.base = work,
                         .size_words = kOtcryptoMldsa87WorkBufferKeypairWords,
                         .offset_words = 0};
  int result = mldsa87_keypair_internal((uint8_t *)public_key->key,
                                        (uint8_t *)secret_key->keyblob,
                                        (const uint8_t *)seed.data, &ctx);
  if (result != 0) {
    memset(secret_key->keyblob, 0, kOtcryptoMldsa87SecretKeyBytes);
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

  HARDENED_TRY(check_keyblob_length(secret_key));

  uint32_t ph[kMldsaPreHashMaxWords];
  size_t ph_len = 0;
  if (launder32(sign_mode) == kOtcryptoMldsaSignModeExternalMu) {
    HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeExternalMu);
    if (message.len != kMldsaMuBytes || context.len != 0) {
      return OTCRYPTO_BAD_ARGS;
    }
  } else if (launder32(sign_mode) != kOtcryptoMldsaSignModeMldsa) {
    HARDENED_CHECK_NE(sign_mode, kOtcryptoMldsaSignModeMldsa);
    HARDENED_TRY(mldsa_prehash_digest(sign_mode, message, ph, &ph_len));
  }

#if defined(ACC_MLDSA_HARDENED)
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

#if defined(ACC_HAS_PQC) && defined(ACC_MLDSA_HARDENED)
  (void)work;
  if (launder32(sign_mode) == kOtcryptoMldsaSignModeMldsa) {
    HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeMldsa);
    HARDENED_TRY(mldsa_acc_87_sign_hardened(
        secret_key->keyblob, message.data, message.len, context.data,
        context.len, rnd.data, signature.data));
  } else if (launder32(sign_mode) == kOtcryptoMldsaSignModeExternalMu) {
    HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeExternalMu);
    uint32_t align_message[kMldsaMuWords];
    memcpy(align_message, message.data, kMldsaMuBytes);
    HARDENED_TRY(mldsa_acc_87_sign_mu_hardened(
        secret_key->keyblob, align_message, rnd.data, signature.data));
  } else {
    HARDENED_CHECK_NE(sign_mode, kOtcryptoMldsaSignModeMldsa);
    HARDENED_CHECK_NE(sign_mode, kOtcryptoMldsaSignModeExternalMu);
    HARDENED_TRY(mldsa_acc_87_sign_pre_hash_hardened(
        secret_key->keyblob, (uint8_t *)ph, ph_len, context.data, context.len,
        sign_mode, rnd.data, signature.data));
  }
#elif defined(ACC_HAS_PQC)
  (void)work;
  if (launder32(sign_mode) == kOtcryptoMldsaSignModeMldsa) {
    HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeMldsa);
    HARDENED_TRY(mldsa_acc_87_sign(secret_key->keyblob, message.data,
                                   message.len, context.data, context.len,
                                   rnd.data, signature.data));
  } else if (launder32(sign_mode) == kOtcryptoMldsaSignModeExternalMu) {
    HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeExternalMu);
    uint32_t align_message[kMldsaMuWords];
    memcpy(align_message, message.data, kMldsaMuBytes);
    HARDENED_TRY(mldsa_acc_87_sign_mu(secret_key->keyblob, align_message,
                                      rnd.data, signature.data));
  } else {
    HARDENED_CHECK_NE(sign_mode, kOtcryptoMldsaSignModeMldsa);
    HARDENED_CHECK_NE(sign_mode, kOtcryptoMldsaSignModeExternalMu);
    HARDENED_TRY(mldsa_acc_87_sign_pre_hash(
        secret_key->keyblob, (uint8_t *)ph, ph_len, context.data, context.len,
        sign_mode, rnd.data, signature.data));
  }
#else
  mld_alloc_ctx_t ctx = {.base = work,
                         .size_words = kOtcryptoMldsa87WorkBufferSignWords,
                         .offset_words = 0};
  int result;
  if (launder32(sign_mode) == kOtcryptoMldsaSignModeMldsa) {
    HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeMldsa);
    uint32_t pre_buf[(2 + 255 + (sizeof(uint32_t) - 1)) / sizeof(uint32_t)];
    uint8_t *pre = (uint8_t *)pre_buf;
    pre[0] = 0;
    pre[1] = (uint8_t)context.len;
    if (context.len > 0) {
      memcpy(pre + 2, context.data, context.len);
    }
    result = mldsa87_signature_internal(
        (uint8_t *)signature.data, message.data, message.len, pre,
        2 + context.len, (const uint8_t *)rnd.data,
        (const uint8_t *)secret_key->keyblob, 0, &ctx);
  } else if (launder32(sign_mode) == kOtcryptoMldsaSignModeExternalMu) {
    HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeExternalMu);
    result = mldsa87_signature_internal(
        (uint8_t *)signature.data, message.data, kMldsaMuBytes, NULL, 0,
        (const uint8_t *)rnd.data, (const uint8_t *)secret_key->keyblob, 1,
        &ctx);
  } else {
    HARDENED_CHECK_NE(sign_mode, kOtcryptoMldsaSignModeMldsa);
    HARDENED_CHECK_NE(sign_mode, kOtcryptoMldsaSignModeExternalMu);
    result = mldsa87_signature_pre_hash_internal(
        (uint8_t *)signature.data, (uint8_t *)ph, ph_len, context.data,
        context.len, (const uint8_t *)rnd.data,
        (const uint8_t *)secret_key->keyblob,
        mldsa_native_prehash_alg(sign_mode), &ctx);
  }

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
  if (context.len > 255) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (integrity_unblinded_key_check(public_key) != kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }

  uint32_t ph[kMldsaPreHashMaxWords];
  size_t ph_len = 0;
  if (launder32(sign_mode) == kOtcryptoMldsaSignModeExternalMu) {
    HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeExternalMu);
    if (message.len != kMldsaMuBytes || context.len != 0) {
      return OTCRYPTO_BAD_ARGS;
    }
  } else if (launder32(sign_mode) != kOtcryptoMldsaSignModeMldsa) {
    HARDENED_CHECK_NE(sign_mode, kOtcryptoMldsaSignModeMldsa);
    HARDENED_TRY(mldsa_prehash_digest(sign_mode, message, ph, &ph_len));
  }

#ifdef ACC_HAS_PQC
  (void)work;
  if (launder32(sign_mode) == kOtcryptoMldsaSignModeMldsa) {
    HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeMldsa);
    HARDENED_TRY(mldsa_acc_87_verify(public_key->key, message.data, message.len,
                                     context.data, context.len, signature.data,
                                     verification_result));
  } else if (launder32(sign_mode) == kOtcryptoMldsaSignModeExternalMu) {
    HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeExternalMu);
    uint32_t align_message[kMldsaMuWords];
    memcpy(align_message, message.data, kMldsaMuBytes);
    HARDENED_TRY(mldsa_acc_87_verify_mu(public_key->key, align_message,
                                        signature.data, verification_result));
  } else {
    HARDENED_CHECK_NE(sign_mode, kOtcryptoMldsaSignModeMldsa);
    HARDENED_CHECK_NE(sign_mode, kOtcryptoMldsaSignModeExternalMu);
    HARDENED_TRY(mldsa_acc_87_verify_pre_hash(
        public_key->key, (uint8_t *)ph, ph_len, context.data, context.len,
        sign_mode, signature.data, verification_result));
  }
#else
  mld_alloc_ctx_t ctx = {.base = work,
                         .size_words = kOtcryptoMldsa87WorkBufferVerifyWords,
                         .offset_words = 0};
  int result;
  if (launder32(sign_mode) == kOtcryptoMldsaSignModeMldsa) {
    HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeMldsa);
    result = mldsa87_verify((const uint8_t *)signature.data, message.data,
                            message.len, context.data, context.len,
                            (const uint8_t *)public_key->key, &ctx);
  } else if (launder32(sign_mode) == kOtcryptoMldsaSignModeExternalMu) {
    HARDENED_CHECK_EQ(sign_mode, kOtcryptoMldsaSignModeExternalMu);
    result = mldsa87_verify_extmu((const uint8_t *)signature.data, message.data,
                                  (const uint8_t *)public_key->key, &ctx);
  } else {
    HARDENED_CHECK_NE(sign_mode, kOtcryptoMldsaSignModeMldsa);
    HARDENED_CHECK_NE(sign_mode, kOtcryptoMldsaSignModeExternalMu);
    result = mldsa87_verify_pre_hash_internal(
        (const uint8_t *)signature.data, (uint8_t *)ph, ph_len, context.data,
        context.len, (const uint8_t *)public_key->key,
        mldsa_native_prehash_alg(sign_mode), &ctx);
  }

  *verification_result = (result == 0) ? kHardenedBoolTrue : kHardenedBoolFalse;
#endif

  return OTCRYPTO_OK;
}
