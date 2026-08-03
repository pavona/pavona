// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "mldsa.h"

#include "sw/device/lib/base/math.h"
#include "sw/device/lib/base/memory.h"
#include "sw/device/lib/base/status.h"
#include "sw/device/lib/crypto/drivers/entropy.h"
#include "sw/device/lib/crypto/drivers/rv_core_ibex.h"
#include "sw/device/lib/crypto/impl/integrity.h"
#include "sw/device/lib/crypto/impl/keyblob.h"
#include "sw/device/lib/crypto/include/sha3.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/test_framework/ujson_ottf.h"
#include "sw/device/lib/ujson/ujson.h"

#define MODULE_ID MAKE_MODULE_ID('m', 'c', 'd')

#ifdef ACC_MLDSA_HARDENED
#define MLDSA_TEST_SECURITY_LEVEL kOtcryptoKeySecurityLevelPassivePhysical
#else
#define MLDSA_TEST_SECURITY_LEVEL kOtcryptoKeySecurityLevelPassiveRemote
#endif

static status_t hash_output(const uint8_t *data, size_t len,
                            cryptotest_mldsa_output_t *out) {
  otcrypto_const_byte_buf_t msg = {.data = data, .len = len};
  otcrypto_hash_digest_t digest = {
      .data = (uint32_t *)out->hash,
      .len = 8,
      .mode = kOtcryptoHashModeSha3_256,
  };
  return otcrypto_sha3_256(msg, &digest);
}

static otcrypto_mldsa_sign_mode_t mldsa_sign_mode_from_wire(
    cryptotest_mldsa_sign_mode_t wire_mode) {
  switch (wire_mode) {
    case kMldsaSignModeHashMldsaSha2_256:
      return kOtcryptoMldsaSignModeHashMldsaSha2_256;
    case kMldsaSignModeHashMldsaSha2_384:
      return kOtcryptoMldsaSignModeHashMldsaSha2_384;
    case kMldsaSignModeHashMldsaSha2_512:
      return kOtcryptoMldsaSignModeHashMldsaSha2_512;
    case kMldsaSignModeHashMldsaSha3_224:
      return kOtcryptoMldsaSignModeHashMldsaSha3_224;
    case kMldsaSignModeHashMldsaSha3_256:
      return kOtcryptoMldsaSignModeHashMldsaSha3_256;
    case kMldsaSignModeHashMldsaSha3_384:
      return kOtcryptoMldsaSignModeHashMldsaSha3_384;
    case kMldsaSignModeHashMldsaSha3_512:
      return kOtcryptoMldsaSignModeHashMldsaSha3_512;
    case kMldsaSignModeHashMldsaShake128:
      return kOtcryptoMldsaSignModeHashMldsaShake128;
    case kMldsaSignModeHashMldsaShake256:
      return kOtcryptoMldsaSignModeHashMldsaShake256;
    case kMldsaSignModeExternalMu:
      return kOtcryptoMldsaSignModeExternalMu;
    case kMldsaSignModePure:
    default:
      return kOtcryptoMldsaSignModeMldsa;
  }
}

static status_t send_fail(ujson_t *uj) {
  cryptotest_mldsa_output_t out;
  memset(&out, 0, sizeof(out));
  out.success = false;
  RESP_OK(ujson_serialize_cryptotest_mldsa_output_t, uj, &out);
  return OK_STATUS();
}

#ifdef ACC_MLDSA_HARDENED
// Inverse of the keygen masking: recombine the component-major ACC masked
// keyblob
//   kb = rho(32) || 0(32) || tr(64) || t0(K*416)
//        || per eta poly [share0|share1] (each pe bytes)
//        || K_share0(32) || K_share1(32)
// into a standard ML-DSA secret key
//   rho(32) || K(32) || tr(64) || s1(L*pe) || s2(K*pe) || t0(K*416)
// by XORing the shares, un-bit-slicing s1/s2, and restoring the layout.
static void mldsa_unmask_to_std(uint32_t parameter_set, const uint8_t *kb,
                                uint8_t *std) {
  size_t k, l, kbits, pe;
  switch (parameter_set) {
    case 44:
      k = 4;
      l = 4;
      kbits = 3;
      pe = 96;
      break;
    case 65:
      k = 6;
      l = 5;
      kbits = 4;
      pe = 128;
      break;
    default:
      k = 8;
      l = 7;
      kbits = 3;
      pe = 96;
      break;
  }
  size_t n = l + k;
  size_t t0_bytes = k * 416;
  size_t acc_sk_bytes = 128 + t0_bytes;
  size_t k_off = acc_sk_bytes + 2 * n * pe;
  memcpy(std, kb, 32);                             // rho
  memcpy(std + 64, kb + 64, 64);                   // tr
  memcpy(std + 128 + n * pe, kb + 128, t0_bytes);  // t0
  const uint8_t *k0 = kb + k_off;
  const uint8_t *k1 = kb + k_off + 32;
  for (size_t i = 0; i < 32; i++) {
    std[32 + i] = k0[i] ^ k1[i];  // K
  }
  for (size_t poly = 0; poly < n; poly++) {
    const uint8_t *b0 = kb + acc_sk_bytes + 2 * poly * pe;
    const uint8_t *b1 = kb + acc_sk_bytes + (2 * poly + 1) * pe;
    uint8_t *out = std + 128 + poly * pe;
    memset(out, 0, pe);
    for (size_t j = 0; j < kbits; j++) {
      for (size_t b = 0; b < 32; b++) {
        uint8_t byte = b0[j * 32 + b] ^ b1[j * 32 + b];
        for (size_t p = 0; p < 8; p++) {
          size_t bit = (b * 8 + p) * kbits + j;
          out[bit >> 3] |= (uint8_t)(((byte >> p) & 1) << (bit & 7));
        }
      }
    }
  }
}

static status_t generate_seed_mask(uint32_t *seed_mask, size_t seed_words) {
  TRY(entropy_complex_check());
  TRY(entropy_csrng_instantiate(
      /*disable_trng_input=*/kHardenedBoolFalse, &kEntropyEmptySeed));
  TRY(entropy_csrng_generate(&kEntropyEmptySeed, seed_mask, seed_words,
                             /*fips_check=*/kHardenedBoolTrue));
  TRY(entropy_csrng_uninstantiate());
  return OK_STATUS();
}
#endif  // ACC_MLDSA_HARDENED

// Output hash: SHA3-256(pk || sk).
static status_t handle_mldsa_keygen(ujson_t *uj, mldsa_test_scratch_t *s) {
  cryptotest_mldsa_keygen_data_t *d = &s->cmd.keygen;
  TRY(ujson_deserialize_cryptotest_mldsa_keygen_data_t(uj, d));

  otcrypto_key_mode_t key_mode;
  size_t pk_bytes, sk_bytes;

  switch (d->parameter_set) {
    case 44:
      key_mode = kOtcryptoKeyModeMldsa44;
      pk_bytes = kOtcryptoMldsa44PublicKeyBytes;
      sk_bytes = kOtcryptoMldsa44SecretKeyBytes;
      break;
    case 65:
      key_mode = kOtcryptoKeyModeMldsa65;
      pk_bytes = kOtcryptoMldsa65PublicKeyBytes;
      sk_bytes = kOtcryptoMldsa65SecretKeyBytes;
      break;
    case 87:
      key_mode = kOtcryptoKeyModeMldsa87;
      pk_bytes = kOtcryptoMldsa87PublicKeyBytes;
      sk_bytes = kOtcryptoMldsa87SecretKeyBytes;
      break;
    default:
      LOG_ERROR("Unsupported ML-DSA parameter set: %d", d->parameter_set);
      return INVALID_ARGUMENT();
  }

  memset(s->pk, 0, sizeof(s->pk));
  otcrypto_unblinded_key_t pk = {
      .key_mode = key_mode, .key_length = pk_bytes, .key = s->pk};
  pk.checksum = integrity_unblinded_checksum(&pk);

  otcrypto_key_config_t sk_config = {
      .version = kOtcryptoLibVersion1,
      .key_mode = key_mode,
      .key_length = sk_bytes,
      .hw_backed = kHardenedBoolFalse,
      .security_level = MLDSA_TEST_SECURITY_LEVEL,
  };
  size_t sk_blob_words;
  TRY(keyblob_num_words(sk_config, &sk_blob_words));
  memset(s->sk, 0, sk_blob_words * sizeof(uint32_t));
  otcrypto_blinded_key_t sk = {
      .config = sk_config,
      .keyblob_length = sk_blob_words * sizeof(uint32_t),
      .keyblob = s->sk,
  };
  sk.checksum = integrity_blinded_checksum(&sk);

#ifdef ACC_MLDSA_HARDENED
  // Seed is masked, so buffer is twice as long.
  uint32_t seed_words[2 * (MLDSA_CMD_MAX_SEED_BYTES + sizeof(uint32_t) - 1) /
                      sizeof(uint32_t)];
  uint8_t *seed_share0 = (uint8_t *)seed_words;
  uint8_t *seed_share1 = (uint8_t *)seed_words + d->seed_len;
  memcpy(seed_share0, d->seed, d->seed_len);

  // Skip masking an empty seed; a zero-length CSRNG request would hang.
  if (d->seed_len > 0) {
    uint32_t mask[(MLDSA_CMD_MAX_SEED_BYTES + sizeof(uint32_t) - 1) /
                  sizeof(uint32_t)];
    TRY(generate_seed_mask(
        mask, (d->seed_len + sizeof(uint32_t) - 1) / sizeof(uint32_t)));
    memcpy(seed_share1, mask, d->seed_len);
    for (size_t i = 0; i < d->seed_len; i++) {
      seed_share0[i] ^= seed_share1[i];
    }
  }
  otcrypto_const_aligned_byte_buf_t seed = {.data = seed_words,
                                            .len = 2 * d->seed_len};
#else
  uint32_t seed_words[(MLDSA_CMD_MAX_SEED_BYTES + sizeof(uint32_t) - 1) /
                      sizeof(uint32_t)];
  memcpy(seed_words, d->seed, d->seed_len);
  otcrypto_const_aligned_byte_buf_t seed = {.data = seed_words,
                                            .len = d->seed_len};
#endif
  status_t keygen_status;
  switch (d->parameter_set) {
    case 44:
      keygen_status =
          otcrypto_mldsa44_keypair_derand(seed, &pk, &sk, s->work.keypair);
      break;
    case 65:
      keygen_status =
          otcrypto_mldsa65_keypair_derand(seed, &pk, &sk, s->work.keypair);
      break;
    case 87:
      keygen_status =
          otcrypto_mldsa87_keypair_derand(seed, &pk, &sk, s->work.keypair);
      break;
    default:
      return INVALID_ARGUMENT();
  }
  if (!status_ok(keygen_status)) {
    return send_fail(uj);
  }

  cryptotest_mldsa_output_t out;
  memset(&out, 0, sizeof(out));
  // Hash pk || sk; the sk is reconstructed into the standard reference layout.
  uint8_t *hash_buf = s->work.tmp;
  memcpy(hash_buf, s->pk, pk_bytes);
#ifdef ACC_MLDSA_HARDENED
  mldsa_unmask_to_std(d->parameter_set, (const uint8_t *)sk.keyblob,
                      hash_buf + pk_bytes);
#else
  // Unprotected: the keyblob is the plain sk.
  memcpy(hash_buf + pk_bytes, sk.keyblob, sk_bytes);
#endif
  TRY(hash_output(hash_buf, pk_bytes + sk_bytes, &out));
  out.success = true;
  RESP_OK(ujson_serialize_cryptotest_mldsa_output_t, uj, &out);
  return OK_STATUS();
}

// Keygen from seed, then sign. Output hash: SHA3-256(pk || signature).
static status_t handle_mldsa_keygen_sign(ujson_t *uj, mldsa_test_scratch_t *s) {
  cryptotest_mldsa_keygen_sign_data_t *d = &s->cmd.keygen_sign;
  TRY(ujson_deserialize_cryptotest_mldsa_keygen_sign_data_t(uj, d));
  otcrypto_mldsa_sign_mode_t sign_mode =
      mldsa_sign_mode_from_wire(d->sign_mode);

  otcrypto_key_mode_t key_mode;
  size_t pk_bytes, sk_bytes, sig_bytes;

  switch (d->parameter_set) {
    case 44:
      key_mode = kOtcryptoKeyModeMldsa44;
      pk_bytes = kOtcryptoMldsa44PublicKeyBytes;
      sk_bytes = kOtcryptoMldsa44SecretKeyBytes;
      sig_bytes = kOtcryptoMldsa44SignatureBytes;
      break;
    case 65:
      key_mode = kOtcryptoKeyModeMldsa65;
      pk_bytes = kOtcryptoMldsa65PublicKeyBytes;
      sk_bytes = kOtcryptoMldsa65SecretKeyBytes;
      sig_bytes = kOtcryptoMldsa65SignatureBytes;
      break;
    case 87:
      key_mode = kOtcryptoKeyModeMldsa87;
      pk_bytes = kOtcryptoMldsa87PublicKeyBytes;
      sk_bytes = kOtcryptoMldsa87SecretKeyBytes;
      sig_bytes = kOtcryptoMldsa87SignatureBytes;
      break;
    default:
      LOG_ERROR("Unsupported ML-DSA parameter set: %d", d->parameter_set);
      return INVALID_ARGUMENT();
  }

  memset(s->pk, 0, sizeof(s->pk));
  otcrypto_unblinded_key_t pk = {
      .key_mode = key_mode, .key_length = pk_bytes, .key = s->pk};
  pk.checksum = integrity_unblinded_checksum(&pk);

  otcrypto_key_config_t sk_config = {
      .version = kOtcryptoLibVersion1,
      .key_mode = key_mode,
      .key_length = sk_bytes,
      .hw_backed = kHardenedBoolFalse,
      .security_level = MLDSA_TEST_SECURITY_LEVEL,
  };
  size_t sk_blob_words;
  TRY(keyblob_num_words(sk_config, &sk_blob_words));
  memset(s->sk, 0, sk_blob_words * sizeof(uint32_t));
  otcrypto_blinded_key_t sk = {
      .config = sk_config,
      .keyblob_length = sk_blob_words * sizeof(uint32_t),
      .keyblob = s->sk,
  };
  sk.checksum = integrity_blinded_checksum(&sk);

#ifdef ACC_MLDSA_HARDENED
  // Seed is masked, so buffer is twice as long.
  uint32_t seed_words[2 * (MLDSA_CMD_MAX_SEED_BYTES + sizeof(uint32_t) - 1) /
                      sizeof(uint32_t)];
  uint8_t *seed_share0 = (uint8_t *)seed_words;
  uint8_t *seed_share1 = (uint8_t *)seed_words + d->seed_len;
  memcpy(seed_share0, d->seed, d->seed_len);

  // Skip masking an empty seed; a zero-length CSRNG request would hang.
  if (d->seed_len > 0) {
    uint32_t mask[(MLDSA_CMD_MAX_SEED_BYTES + sizeof(uint32_t) - 1) /
                  sizeof(uint32_t)];
    TRY(generate_seed_mask(
        mask, (d->seed_len + sizeof(uint32_t) - 1) / sizeof(uint32_t)));
    memcpy(seed_share1, mask, d->seed_len);
    for (size_t i = 0; i < d->seed_len; i++) {
      seed_share0[i] ^= seed_share1[i];
    }
  }
  otcrypto_const_aligned_byte_buf_t seed = {.data = seed_words,
                                            .len = 2 * d->seed_len};
#else
  uint32_t seed_words[(MLDSA_CMD_MAX_SEED_BYTES + sizeof(uint32_t) - 1) /
                      sizeof(uint32_t)];
  memcpy(seed_words, d->seed, d->seed_len);
  otcrypto_const_aligned_byte_buf_t seed = {.data = seed_words,
                                            .len = d->seed_len};
#endif
  status_t keygen_status;
  switch (d->parameter_set) {
    case 44:
      keygen_status =
          otcrypto_mldsa44_keypair_derand(seed, &pk, &sk, s->work.keypair);
      break;
    case 65:
      keygen_status =
          otcrypto_mldsa65_keypair_derand(seed, &pk, &sk, s->work.keypair);
      break;
    case 87:
      keygen_status =
          otcrypto_mldsa87_keypair_derand(seed, &pk, &sk, s->work.keypair);
      break;
    default:
      return INVALID_ARGUMENT();
  }
  if (!status_ok(keygen_status)) {
    return send_fail(uj);
  }

  otcrypto_const_byte_buf_t message = {.data = d->message,
                                       .len = d->message_len};
  otcrypto_const_byte_buf_t context = {.data = d->context,
                                       .len = d->context_len};
  uint32_t rnd_words[(MLDSA_CMD_MAX_RND_BYTES + sizeof(uint32_t) - 1) /
                     sizeof(uint32_t)];
  memcpy(rnd_words, d->rnd, d->rnd_len);
  otcrypto_const_aligned_byte_buf_t rnd = {.data = rnd_words,
                                           .len = d->rnd_len};

  memset(s->sig, 0, sig_bytes);
  otcrypto_aligned_byte_buf_t signature = {.data = s->sig, .len = sig_bytes};

  status_t sign_status;
  switch (d->parameter_set) {
    case 44:
      sign_status = otcrypto_mldsa44_sign_derand(
          &sk, message, context, sign_mode, rnd, signature, s->work.sign);
      break;
    case 65:
      sign_status = otcrypto_mldsa65_sign_derand(
          &sk, message, context, sign_mode, rnd, signature, s->work.sign);
      break;
    case 87:
      sign_status = otcrypto_mldsa87_sign_derand(
          &sk, message, context, sign_mode, rnd, signature, s->work.sign);
      break;
    default:
      return INVALID_ARGUMENT();
  }
  if (!status_ok(sign_status)) {
    return send_fail(uj);
  }

  // Hash pk || sig using work.tmp as scratch.
  uint8_t *hash_buf = s->work.tmp;
  memcpy(hash_buf, s->pk, pk_bytes);
  memcpy(hash_buf + pk_bytes, s->sig, sig_bytes);

  cryptotest_mldsa_output_t out;
  memset(&out, 0, sizeof(out));
  TRY(hash_output(hash_buf, pk_bytes + sig_bytes, &out));
  out.success = true;
  RESP_OK(ujson_serialize_cryptotest_mldsa_output_t, uj, &out);
  return OK_STATUS();
}

#ifdef ACC_MLDSA_HARDENED
// Rewrite a standard ML-DSA secret key
//   rho(32) || K(32) || tr(64) || s1(L*pe) || s2(K*pe) || t0(K*416)
// into the component-major ACC masked keyblob
//   kb = rho(32) || 0(32) || tr(64) || t0(K*416)
//        || per eta poly [share0|share1] (each pe bytes, Boolean shares of the
//           bit-sliced packed poly)
//        || K_share0(32) || K_share1(32).
static void mldsa_std_sk_to_masked(uint32_t parameter_set, const uint8_t *std,
                                   uint8_t *kb) {
  size_t k, l, kbits, pe;
  switch (parameter_set) {
    case 44:
      k = 4;
      l = 4;
      kbits = 3;
      pe = 96;
      break;
    case 65:
      k = 6;
      l = 5;
      kbits = 4;
      pe = 128;
      break;
    default:
      k = 8;
      l = 7;
      kbits = 3;
      pe = 96;
      break;
  }
  size_t n = l + k;
  size_t t0_bytes = k * 416;
  size_t acc_sk_bytes = 128 + t0_bytes;
  size_t k_off = acc_sk_bytes + 2 * n * pe;
  const uint8_t *s1s2 = std + 128;
  const uint8_t *t0 = std + 128 + n * pe;
  // Public part (rho, zeroed K slot, tr, t0).
  memcpy(kb, std, 32);             // rho @ 0
  memset(kb + 32, 0, 32);          // K-slot @ 32 (must be zero)
  memcpy(kb + 64, std + 64, 64);   // tr @ 64
  memcpy(kb + 128, t0, t0_bytes);  // t0 @ 128
  // Per eta poly: bit-slice into share0, draw a random share1, share0 ^=
  // share1.
  for (size_t poly = 0; poly < n; poly++) {
    const uint8_t *chunk = s1s2 + poly * pe;
    uint8_t *sh0 = kb + acc_sk_bytes + 2 * poly * pe;
    uint8_t *sh1 = kb + acc_sk_bytes + (2 * poly + 1) * pe;
    for (size_t j = 0; j < kbits; j++) {
      for (size_t b = 0; b < 32; b++) {
        uint8_t byte = 0;
        for (size_t p = 0; p < 8; p++) {
          size_t bit = (b * 8 + p) * kbits + j;
          byte |= (uint8_t)(((chunk[bit >> 3] >> (bit & 7)) & 1) << p);
        }
        sh0[j * 32 + b] = byte;
      }
    }
    for (size_t i = 0; i < pe; i += 4) {
      uint32_t r = ibex_rnd32_read();
      memcpy(&sh1[i], &r, 4);
      sh0[i] ^= sh1[i];
      sh0[i + 1] ^= sh1[i + 1];
      sh0[i + 2] ^= sh1[i + 2];
      sh0[i + 3] ^= sh1[i + 3];
    }
  }
  // Boolean-share K: K_share1 = random, K_share0 = K ^ K_share1.
  uint8_t *ksh0 = kb + k_off;
  uint8_t *ksh1 = kb + k_off + 32;
  for (size_t i = 0; i < 32; i += 4) {
    uint32_t r = ibex_rnd32_read();
    memcpy(&ksh1[i], &r, 4);
    ksh0[i] = std[32 + i] ^ ksh1[i];
    ksh0[i + 1] = std[32 + i + 1] ^ ksh1[i + 1];
    ksh0[i + 2] = std[32 + i + 2] ^ ksh1[i + 2];
    ksh0[i + 3] = std[32 + i + 3] ^ ksh1[i + 3];
  }
}
#endif

// Output hash: SHA3-256(signature).
static status_t handle_mldsa_siggen(ujson_t *uj, mldsa_test_scratch_t *s) {
  cryptotest_mldsa_siggen_data_t *d = &s->cmd.siggen;
  TRY(ujson_deserialize_cryptotest_mldsa_siggen_data_t(uj, d));
  otcrypto_mldsa_sign_mode_t sign_mode =
      mldsa_sign_mode_from_wire(d->sign_mode);

  otcrypto_key_mode_t key_mode;
  size_t sig_bytes;

  switch (d->parameter_set) {
    case 44:
      key_mode = kOtcryptoKeyModeMldsa44;
      sig_bytes = kOtcryptoMldsa44SignatureBytes;
      break;
    case 65:
      key_mode = kOtcryptoKeyModeMldsa65;
      sig_bytes = kOtcryptoMldsa65SignatureBytes;
      break;
    case 87:
      key_mode = kOtcryptoKeyModeMldsa87;
      sig_bytes = kOtcryptoMldsa87SignatureBytes;
      break;
    default:
      LOG_ERROR("Unsupported ML-DSA parameter set: %d", d->parameter_set);
      return INVALID_ARGUMENT();
  }

  // Build the blinded secret key directly in s->sk.
  // Use the actual received sk_len so the API rejects incorrect lengths.
  otcrypto_key_config_t sk_config = {
      .version = kOtcryptoLibVersion1,
      .key_mode = key_mode,
      .key_length = d->sk_len,
      .hw_backed = kHardenedBoolFalse,
      .security_level = MLDSA_TEST_SECURITY_LEVEL,
  };
  size_t sk_blob_words;
  TRY(keyblob_num_words(sk_config, &sk_blob_words));
  uint8_t *kb = (uint8_t *)s->sk;
  memset(kb, 0, sk_blob_words * sizeof(uint32_t));
#ifdef ACC_MLDSA_HARDENED
  // The masked signer consumes the ACC keyblob layout (component-major), not a
  // standard sk.
  mldsa_std_sk_to_masked(d->parameter_set, d->sk, kb);
#else
  // Unprotected: the keyblob is the plain sk.
  memcpy(kb, d->sk, d->sk_len);
#endif
  otcrypto_blinded_key_t sk = {
      .config = sk_config,
      .keyblob_length = sk_blob_words * sizeof(uint32_t),
      .keyblob = s->sk,
  };
  sk.checksum = integrity_blinded_checksum(&sk);

  otcrypto_const_byte_buf_t message = {.data = d->message,
                                       .len = d->message_len};
  otcrypto_const_byte_buf_t context = {.data = d->context,
                                       .len = d->context_len};
  uint32_t rnd_words[(MLDSA_CMD_MAX_RND_BYTES + sizeof(uint32_t) - 1) /
                     sizeof(uint32_t)];
  memcpy(rnd_words, d->rnd, d->rnd_len);
  otcrypto_const_aligned_byte_buf_t rnd = {.data = rnd_words,
                                           .len = d->rnd_len};

  memset(s->sig, 0, sig_bytes);
  otcrypto_aligned_byte_buf_t signature = {.data = s->sig, .len = sig_bytes};

  status_t sign_status;
  switch (d->parameter_set) {
    case 44:
      sign_status = otcrypto_mldsa44_sign_derand(
          &sk, message, context, sign_mode, rnd, signature, s->work.sign);
      break;
    case 65:
      sign_status = otcrypto_mldsa65_sign_derand(
          &sk, message, context, sign_mode, rnd, signature, s->work.sign);
      break;
    case 87:
      sign_status = otcrypto_mldsa87_sign_derand(
          &sk, message, context, sign_mode, rnd, signature, s->work.sign);
      break;
    default:
      return INVALID_ARGUMENT();
  }
  if (!status_ok(sign_status)) {
    return send_fail(uj);
  }

  cryptotest_mldsa_output_t out;
  memset(&out, 0, sizeof(out));
  TRY(hash_output((uint8_t *)s->sig, sig_bytes, &out));
  out.success = true;
  RESP_OK(ujson_serialize_cryptotest_mldsa_output_t, uj, &out);
  return OK_STATUS();
}

// Sigver: returns success/failure only, no hash.
static status_t handle_mldsa_sigver(ujson_t *uj, mldsa_test_scratch_t *s) {
  cryptotest_mldsa_sigver_data_t *d = &s->cmd.sigver;
  TRY(ujson_deserialize_cryptotest_mldsa_sigver_data_t(uj, d));
  otcrypto_mldsa_sign_mode_t sign_mode =
      mldsa_sign_mode_from_wire(d->sign_mode);

  otcrypto_key_mode_t key_mode;

  switch (d->parameter_set) {
    case 44:
      key_mode = kOtcryptoKeyModeMldsa44;
      break;
    case 65:
      key_mode = kOtcryptoKeyModeMldsa65;
      break;
    case 87:
      key_mode = kOtcryptoKeyModeMldsa87;
      break;
    default:
      LOG_ERROR("Unsupported ML-DSA parameter set: %d", d->parameter_set);
      return INVALID_ARGUMENT();
  }

  memset(s->pk, 0, sizeof(s->pk));
  memcpy(s->pk, d->pk, d->pk_len);
  otcrypto_unblinded_key_t pk = {
      .key_mode = key_mode, .key_length = d->pk_len, .key = s->pk};
  pk.checksum = integrity_unblinded_checksum(&pk);

  otcrypto_const_byte_buf_t message = {.data = d->message,
                                       .len = d->message_len};
  otcrypto_const_byte_buf_t context = {.data = d->context,
                                       .len = d->context_len};
  memcpy(s->sig, d->signature, d->signature_len);
  otcrypto_const_aligned_byte_buf_t signature = {.data = s->sig,
                                                 .len = d->signature_len};

  hardened_bool_t verification_result = kHardenedBoolFalse;
  status_t verify_status;
  switch (d->parameter_set) {
    case 44:
      verify_status =
          otcrypto_mldsa44_verify(&pk, message, context, sign_mode, signature,
                                  &verification_result, s->work.verify);
      break;
    case 65:
      verify_status =
          otcrypto_mldsa65_verify(&pk, message, context, sign_mode, signature,
                                  &verification_result, s->work.verify);
      break;
    case 87:
      verify_status =
          otcrypto_mldsa87_verify(&pk, message, context, sign_mode, signature,
                                  &verification_result, s->work.verify);
      break;
    default:
      return INVALID_ARGUMENT();
  }

  cryptotest_mldsa_output_t out;
  memset(&out, 0, sizeof(out));
  out.success =
      status_ok(verify_status) && verification_result == kHardenedBoolTrue;
  RESP_OK(ujson_serialize_cryptotest_mldsa_output_t, uj, &out);
  return OK_STATUS();
}

status_t handle_mldsa(ujson_t *uj, mldsa_test_scratch_t *s) {
  mldsa_subcommand_t subcmd;
  TRY(ujson_deserialize_mldsa_subcommand_t(uj, &subcmd));

  switch (subcmd) {
    case kMldsaSubcommandMldsaKeygen:
      return handle_mldsa_keygen(uj, s);
    case kMldsaSubcommandMldsaKeygenSign:
      return handle_mldsa_keygen_sign(uj, s);
    case kMldsaSubcommandMldsaSiggen:
      return handle_mldsa_siggen(uj, s);
    case kMldsaSubcommandMldsaSigver:
      return handle_mldsa_sigver(uj, s);
    default:
      LOG_ERROR("Unrecognized ML-DSA subcommand: %d", subcmd);
      return INVALID_ARGUMENT();
  }
}
