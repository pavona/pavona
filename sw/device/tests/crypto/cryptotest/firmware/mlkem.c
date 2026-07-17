// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "mlkem.h"

#include "sw/device/lib/base/hardened_memory.h"
#include "sw/device/lib/base/math.h"
#include "sw/device/lib/base/memory.h"
#include "sw/device/lib/base/status.h"
#include "sw/device/lib/crypto/drivers/entropy.h"
#include "sw/device/lib/crypto/impl/integrity.h"
#include "sw/device/lib/crypto/impl/keyblob.h"
#include "sw/device/lib/crypto/include/sha3.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/test_framework/ujson_ottf.h"
#include "sw/device/lib/ujson/ujson.h"

#define MODULE_ID MAKE_MODULE_ID('m', 'c', 'k')

// The hardened ACC backend requires PassivePhysical secret keys; the
// unprotected and native backends require PassiveRemote.
#ifdef ACC_MLKEM_HARDENED
#define MLKEM_SECRET_KEY_SECURITY_LEVEL kOtcryptoKeySecurityLevelPassivePhysical
#else
#define MLKEM_SECRET_KEY_SECURITY_LEVEL kOtcryptoKeySecurityLevelPassiveRemote
#endif

static status_t hash_output(const uint8_t *data, size_t len,
                            cryptotest_mlkem_output_t *out) {
  otcrypto_const_byte_buf_t msg = {.data = data, .len = len};
  otcrypto_hash_digest_t digest = {
      .data = (uint32_t *)out->hash,
      .len = 8,
      .mode = kOtcryptoHashModeSha3_256,
  };
  return otcrypto_sha3_256(msg, &digest);
}

static status_t send_fail(ujson_t *uj) {
  cryptotest_mlkem_output_t out;
  memset(&out, 0, sizeof(out));
  out.success = false;
  RESP_OK(ujson_serialize_cryptotest_mlkem_output_t, uj, &out);
  return OK_STATUS();
}

#ifdef ACC_MLKEM_HARDENED
static status_t generate_seed_mask(uint32_t *seed_mask, size_t seed_words) {
  TRY(entropy_complex_check());
  TRY(entropy_csrng_instantiate(
      /*disable_trng_input=*/kHardenedBoolFalse, &kEntropyEmptySeed));
  TRY(entropy_csrng_generate(&kEntropyEmptySeed, seed_mask, seed_words,
                             /*fips_check=*/kHardenedBoolTrue));
  TRY(entropy_csrng_uninstantiate());
  return OK_STATUS();
}
#endif

// Output hash: SHA3-256(ek || K).
static status_t handle_mlkem_keygen_decaps(ujson_t *uj,
                                           mlkem_test_scratch_t *s) {
  cryptotest_mlkem_keygen_decaps_data_t d;
  TRY(ujson_deserialize_cryptotest_mlkem_keygen_decaps_data_t(uj, &d));

  otcrypto_key_mode_t key_mode;
  size_t pk_bytes, sk_bytes, ss_bytes;

  switch (d.parameter_set) {
    case 512:
      key_mode = kOtcryptoKeyModeMlkem512;
      pk_bytes = kOtcryptoMlkem512PublicKeyBytes;
      sk_bytes = kOtcryptoMlkem512SecretKeyBytes;
      ss_bytes = kOtcryptoMlkem512SharedSecretBytes;
      break;
    case 768:
      key_mode = kOtcryptoKeyModeMlkem768;
      pk_bytes = kOtcryptoMlkem768PublicKeyBytes;
      sk_bytes = kOtcryptoMlkem768SecretKeyBytes;
      ss_bytes = kOtcryptoMlkem768SharedSecretBytes;
      break;
    case 1024:
      key_mode = kOtcryptoKeyModeMlkem1024;
      pk_bytes = kOtcryptoMlkem1024PublicKeyBytes;
      sk_bytes = kOtcryptoMlkem1024SecretKeyBytes;
      ss_bytes = kOtcryptoMlkem1024SharedSecretBytes;
      break;
    default:
      LOG_ERROR("Unsupported ML-KEM parameter set: %d", d.parameter_set);
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
      .security_level = MLKEM_SECRET_KEY_SECURITY_LEVEL,
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

  // Reject non-word-multiple input lengths; word-multiple-but-wrong lengths
  // are caught by the library's word-count check.
  if (d.seed_len % sizeof(uint32_t) != 0 || d.c_len % sizeof(uint32_t) != 0) {
    return send_fail(uj);
  }
  size_t seed_len_words = d.seed_len / sizeof(uint32_t);

#ifdef ACC_MLKEM_HARDENED
  // Seed is masked, so buffer is twice as long.
  uint32_t seed_words[2 * MLKEM_CMD_MAX_SEED_BYTES / sizeof(uint32_t)];
  uint32_t *seed_share0 = seed_words;
  uint32_t *seed_share1 = &seed_words[seed_len_words];
  memcpy(seed_share0, d.seed, d.seed_len);

  // Skip masking an empty seed; a zero-length CSRNG request would hang.
  if (seed_len_words > 0) {
    TRY(generate_seed_mask(seed_share1, seed_len_words));
    for (size_t i = 0; i < seed_len_words; i++) {
      seed_share0[i] ^= seed_share1[i];
    }
  }
  otcrypto_const_word32_buf_t seed = {.data = seed_words,
                                      .len = 2 * seed_len_words};
#else
  uint32_t seed_words[MLKEM_CMD_MAX_SEED_BYTES / sizeof(uint32_t)];
  memcpy(seed_words, d.seed, d.seed_len);
  otcrypto_const_word32_buf_t seed = {.data = seed_words,
                                      .len = seed_len_words};
#endif
  status_t keygen_status;
  switch (d.parameter_set) {
    case 512:
      keygen_status =
          otcrypto_mlkem512_keygen_derand(seed, &pk, &sk, s->work.keypair);
      break;
    case 768:
      keygen_status =
          otcrypto_mlkem768_keygen_derand(seed, &pk, &sk, s->work.keypair);
      break;
    case 1024:
      keygen_status =
          otcrypto_mlkem1024_keygen_derand(seed, &pk, &sk, s->work.keypair);
      break;
    default:
      return INVALID_ARGUMENT();
  }
  if (!status_ok(keygen_status)) {
    return send_fail(uj);
  }

  memset(s->ct, 0, sizeof(s->ct));
  memcpy(s->ct, d.c, d.c_len);
  otcrypto_const_word32_buf_t ct = {.data = s->ct,
                                    .len = d.c_len / sizeof(uint32_t)};
  otcrypto_key_config_t ss_config = {
      .version = kOtcryptoLibVersion1,
      .key_mode = kOtcryptoKeyModeAesCtr,
      .key_length = ss_bytes,
      .hw_backed = kHardenedBoolFalse,
      .security_level = kOtcryptoKeySecurityLevelPassiveRemote,
  };
  uint32_t ss_blob[ceil_div(ss_bytes, sizeof(uint32_t)) * 2];
  memset(ss_blob, 0, sizeof(ss_blob));
  otcrypto_blinded_key_t ss = {
      .config = ss_config,
      .keyblob_length = sizeof(ss_blob),
      .keyblob = ss_blob,
  };
  ss.checksum = integrity_blinded_checksum(&ss);

  status_t decaps_status;
  switch (d.parameter_set) {
    case 512:
      decaps_status =
          otcrypto_mlkem512_decapsulate(&sk, ct, &ss, s->work.decaps);
      break;
    case 768:
      decaps_status =
          otcrypto_mlkem768_decapsulate(&sk, ct, &ss, s->work.decaps);
      break;
    case 1024:
      decaps_status =
          otcrypto_mlkem1024_decapsulate(&sk, ct, &ss, s->work.decaps);
      break;
    default:
      return INVALID_ARGUMENT();
  }
  if (!status_ok(decaps_status)) {
    return send_fail(uj);
  }

  size_t ss_words = keyblob_share_num_words(ss_config);
  uint32_t ss_unmasked[ss_words];
  TRY(keyblob_key_unmask(&ss, ss_words, ss_unmasked));

  uint8_t *hash_buf = s->work.tmp;
  memcpy(hash_buf, s->pk, pk_bytes);
  memcpy(hash_buf + pk_bytes, ss_unmasked, ss_bytes);

  cryptotest_mlkem_output_t out;
  memset(&out, 0, sizeof(out));
  TRY(hash_output(hash_buf, pk_bytes + ss_bytes, &out));
  out.success = true;
  RESP_OK(ujson_serialize_cryptotest_mlkem_output_t, uj, &out);
  return OK_STATUS();
}

#ifdef ACC_MLKEM_HARDENED
// Rebuild the plaintext dk from the ACC masked keyblob (component-major): per
// poly the two arithmetic shares sum mod q; ek||H(ek) is public; z = z0 ^ z1.
static status_t mlkem_unmask_sk(const otcrypto_blinded_key_t *sk, size_t k,
                                uint8_t *dk) {
  const uint8_t *kb = (const uint8_t *)sk->keyblob;
  for (size_t p = 0; p < k; p++) {
    const uint8_t *s0 = kb + 768 * p;
    const uint8_t *s1 = kb + 768 * p + 384;
    for (size_t i = 0; i < 384; i += 3) {
      uint32_t a0 = s0[i] | ((uint32_t)(s0[i + 1] & 0x0f) << 8);
      uint32_t a1 = (s0[i + 1] >> 4) | ((uint32_t)s0[i + 2] << 4);
      uint32_t b0 = s1[i] | ((uint32_t)(s1[i + 1] & 0x0f) << 8);
      uint32_t b1 = (s1[i + 1] >> 4) | ((uint32_t)s1[i + 2] << 4);
      uint32_t c0 = (a0 + b0) % 3329;
      uint32_t c1 = (a1 + b1) % 3329;
      dk[384 * p + i] = (uint8_t)c0;
      dk[384 * p + i + 1] = (uint8_t)((c0 >> 8) | (c1 << 4));
      dk[384 * p + i + 2] = (uint8_t)(c1 >> 4);
    }
  }
  memcpy(dk + 384 * k, kb + 768 * k, 384 * k + 64);
  for (size_t i = 0; i < 32; i++) {
    dk[768 * k + 64 + i] = kb[1152 * k + 64 + i] ^ kb[1152 * k + 96 + i];
  }
  return OK_STATUS();
}
#endif

// Output hash: SHA3-256(ek || dk).
static status_t handle_mlkem_keygen(ujson_t *uj, mlkem_test_scratch_t *s) {
  cryptotest_mlkem_keygen_data_t d;
  TRY(ujson_deserialize_cryptotest_mlkem_keygen_data_t(uj, &d));

  otcrypto_key_mode_t key_mode;
  size_t pk_bytes, sk_bytes;

  switch (d.parameter_set) {
    case 512:
      key_mode = kOtcryptoKeyModeMlkem512;
      pk_bytes = kOtcryptoMlkem512PublicKeyBytes;
      sk_bytes = kOtcryptoMlkem512SecretKeyBytes;
      break;
    case 768:
      key_mode = kOtcryptoKeyModeMlkem768;
      pk_bytes = kOtcryptoMlkem768PublicKeyBytes;
      sk_bytes = kOtcryptoMlkem768SecretKeyBytes;
      break;
    case 1024:
      key_mode = kOtcryptoKeyModeMlkem1024;
      pk_bytes = kOtcryptoMlkem1024PublicKeyBytes;
      sk_bytes = kOtcryptoMlkem1024SecretKeyBytes;
      break;
    default:
      LOG_ERROR("Unsupported ML-KEM parameter set: %d", d.parameter_set);
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
      .security_level = MLKEM_SECRET_KEY_SECURITY_LEVEL,
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

  // Reject non-word-multiple input lengths; word-multiple-but-wrong lengths
  // are caught by the library's word-count check.
  if (d.seed_len % sizeof(uint32_t) != 0) {
    return send_fail(uj);
  }
  size_t seed_len_words = d.seed_len / sizeof(uint32_t);

#ifdef ACC_MLKEM_HARDENED
  // Seed is masked, so buffer is twice as long.
  uint32_t seed_words[2 * MLKEM_CMD_MAX_SEED_BYTES / sizeof(uint32_t)];
  uint32_t *seed_share0 = seed_words;
  uint32_t *seed_share1 = &seed_words[seed_len_words];
  memcpy(seed_share0, d.seed, d.seed_len);

  // Skip masking an empty seed; a zero-length CSRNG request would hang.
  if (seed_len_words > 0) {
    TRY(generate_seed_mask(seed_share1, seed_len_words));
    for (size_t i = 0; i < seed_len_words; i++) {
      seed_share0[i] ^= seed_share1[i];
    }
  }
  otcrypto_const_word32_buf_t seed = {.data = seed_words,
                                      .len = 2 * seed_len_words};
#else
  uint32_t seed_words[MLKEM_CMD_MAX_SEED_BYTES / sizeof(uint32_t)];
  memcpy(seed_words, d.seed, d.seed_len);
  otcrypto_const_word32_buf_t seed = {.data = seed_words,
                                      .len = seed_len_words};
#endif
  status_t keygen_status;
  switch (d.parameter_set) {
    case 512:
      keygen_status =
          otcrypto_mlkem512_keygen_derand(seed, &pk, &sk, s->work.keypair);
      break;
    case 768:
      keygen_status =
          otcrypto_mlkem768_keygen_derand(seed, &pk, &sk, s->work.keypair);
      break;
    case 1024:
      keygen_status =
          otcrypto_mlkem1024_keygen_derand(seed, &pk, &sk, s->work.keypair);
      break;
    default:
      return INVALID_ARGUMENT();
  }
  if (!status_ok(keygen_status)) {
    return send_fail(uj);
  }

  // Rebuild the standard dk and build pk||sk hash in work.tmp.
  uint8_t *hash_buf = s->work.tmp;
  memcpy(hash_buf, s->pk, pk_bytes);
#ifdef ACC_MLKEM_HARDENED
  size_t k = (sk_bytes - 96) / 768;
  TRY(mlkem_unmask_sk(&sk, k, hash_buf + pk_bytes));
#else
  // Unprotected: the keyblob is the plain dk.
  memcpy(hash_buf + pk_bytes, sk.keyblob, sk_bytes);
#endif

  cryptotest_mlkem_output_t out;
  memset(&out, 0, sizeof(out));
  TRY(hash_output(hash_buf, pk_bytes + sk_bytes, &out));
  out.success = true;
  RESP_OK(ujson_serialize_cryptotest_mlkem_output_t, uj, &out);
  return OK_STATUS();
}

// Output hash: SHA3-256(ct || K).
static status_t handle_mlkem_encaps(ujson_t *uj, mlkem_test_scratch_t *s) {
  cryptotest_mlkem_encaps_data_t d;
  TRY(ujson_deserialize_cryptotest_mlkem_encaps_data_t(uj, &d));

  otcrypto_key_mode_t key_mode;
  size_t ct_bytes, ss_bytes;

  switch (d.parameter_set) {
    case 512:
      key_mode = kOtcryptoKeyModeMlkem512;
      ct_bytes = kOtcryptoMlkem512CiphertextBytes;
      ss_bytes = kOtcryptoMlkem512SharedSecretBytes;
      break;
    case 768:
      key_mode = kOtcryptoKeyModeMlkem768;
      ct_bytes = kOtcryptoMlkem768CiphertextBytes;
      ss_bytes = kOtcryptoMlkem768SharedSecretBytes;
      break;
    case 1024:
      key_mode = kOtcryptoKeyModeMlkem1024;
      ct_bytes = kOtcryptoMlkem1024CiphertextBytes;
      ss_bytes = kOtcryptoMlkem1024SharedSecretBytes;
      break;
    default:
      LOG_ERROR("Unsupported ML-KEM parameter set: %d", d.parameter_set);
      return INVALID_ARGUMENT();
  }

  memset(s->pk, 0, sizeof(s->pk));
  memcpy(s->pk, d.ek, d.ek_len);
  otcrypto_unblinded_key_t pk = {
      .key_mode = key_mode, .key_length = d.ek_len, .key = s->pk};
  pk.checksum = integrity_unblinded_checksum(&pk);

  // Reject non-word-multiple randomness lengths; word-multiple-but-wrong
  // lengths are caught by the library's word-count check.
  if (d.seed_len % sizeof(uint32_t) != 0) {
    return send_fail(uj);
  }
  uint32_t m_words[MLKEM_CMD_MAX_SEED_BYTES / sizeof(uint32_t)];
  memcpy(m_words, d.seed, d.seed_len);
  otcrypto_const_word32_buf_t m = {.data = m_words,
                                   .len = d.seed_len / sizeof(uint32_t)};

  memset(s->ct, 0, sizeof(s->ct));
  otcrypto_word32_buf_t ct = {.data = s->ct,
                              .len = ct_bytes / sizeof(uint32_t)};

  otcrypto_key_config_t ss_config = {
      .version = kOtcryptoLibVersion1,
      .key_mode = kOtcryptoKeyModeAesCtr,
      .key_length = ss_bytes,
      .hw_backed = kHardenedBoolFalse,
      .security_level = kOtcryptoKeySecurityLevelPassiveRemote,
  };
  uint32_t ss_blob[ceil_div(ss_bytes, sizeof(uint32_t)) * 2];
  memset(ss_blob, 0, sizeof(ss_blob));
  otcrypto_blinded_key_t ss = {
      .config = ss_config,
      .keyblob_length = sizeof(ss_blob),
      .keyblob = ss_blob,
  };
  ss.checksum = integrity_blinded_checksum(&ss);

  status_t encaps_status;
  switch (d.parameter_set) {
    case 512:
      encaps_status =
          otcrypto_mlkem512_encapsulate_derand(&pk, m, ct, &ss, s->work.encaps);
      break;
    case 768:
      encaps_status =
          otcrypto_mlkem768_encapsulate_derand(&pk, m, ct, &ss, s->work.encaps);
      break;
    case 1024:
      encaps_status = otcrypto_mlkem1024_encapsulate_derand(&pk, m, ct, &ss,
                                                            s->work.encaps);
      break;
    default:
      return INVALID_ARGUMENT();
  }
  if (!status_ok(encaps_status)) {
    return send_fail(uj);
  }

  size_t ss_words = keyblob_share_num_words(ss_config);
  uint32_t ss_unmasked[ss_words];
  TRY(keyblob_key_unmask(&ss, ss_words, ss_unmasked));

  uint8_t *hash_buf = s->work.tmp;
  memcpy(hash_buf, s->ct, ct_bytes);
  memcpy(hash_buf + ct_bytes, ss_unmasked, ss_bytes);

  cryptotest_mlkem_output_t out;
  memset(&out, 0, sizeof(out));
  TRY(hash_output(hash_buf, ct_bytes + ss_bytes, &out));
  out.success = true;
  RESP_OK(ujson_serialize_cryptotest_mlkem_output_t, uj, &out);
  return OK_STATUS();
}

// Output hash: SHA3-256(K).
static status_t handle_mlkem_decaps(ujson_t *uj, mlkem_test_scratch_t *s) {
  cryptotest_mlkem_decaps_data_t d;
  TRY(ujson_deserialize_cryptotest_mlkem_decaps_data_t(uj, &d));

  otcrypto_key_mode_t key_mode;
  size_t ss_bytes;

  switch (d.parameter_set) {
    case 512:
      key_mode = kOtcryptoKeyModeMlkem512;
      ss_bytes = kOtcryptoMlkem512SharedSecretBytes;
      break;
    case 768:
      key_mode = kOtcryptoKeyModeMlkem768;
      ss_bytes = kOtcryptoMlkem768SharedSecretBytes;
      break;
    case 1024:
      key_mode = kOtcryptoKeyModeMlkem1024;
      ss_bytes = kOtcryptoMlkem1024SharedSecretBytes;
      break;
    default:
      LOG_ERROR("Unsupported ML-KEM parameter set: %d", d.parameter_set);
      return INVALID_ARGUMENT();
  }

  otcrypto_key_config_t sk_config = {
      .version = kOtcryptoLibVersion1,
      .key_mode = key_mode,
      .key_length = d.dk_len,
      .hw_backed = kHardenedBoolFalse,
      .security_level = MLKEM_SECRET_KEY_SECURITY_LEVEL,
  };
  size_t sk_blob_words;
  TRY(keyblob_num_words(sk_config, &sk_blob_words));
  uint8_t *kb = (uint8_t *)s->sk;
  memset(kb, 0, sk_blob_words * sizeof(uint32_t));
#ifdef ACC_MLKEM_HARDENED
  // Format the plaintext dk as the ACC masked dk with a zero second share:
  // per poly s0 = plain, s1 = 0 (interleaved); ek||H(ek) public; z0 = z, z1 =
  // 0.
  size_t k = (d.dk_len - 96) / 768;
  for (size_t p = 0; p < k; p++) {
    memcpy(kb + 768 * p, d.dk + 384 * p, 384);
  }
  memcpy(kb + 768 * k, d.dk + 384 * k, 384 * k + 64);
  memcpy(kb + 1152 * k + 64, d.dk + 768 * k + 64, 32);
#else
  memcpy(kb, d.dk, d.dk_len);
#endif
  otcrypto_blinded_key_t sk = {
      .config = sk_config,
      .keyblob_length = sk_blob_words * sizeof(uint32_t),
      .keyblob = s->sk,
  };
  sk.checksum = integrity_blinded_checksum(&sk);

  // Reject non-word-multiple ciphertext lengths; word-multiple-but-wrong
  // lengths are caught by the library's word-count check.
  if (d.c_len % sizeof(uint32_t) != 0) {
    return send_fail(uj);
  }
  memset(s->ct, 0, sizeof(s->ct));
  memcpy(s->ct, d.c, d.c_len);
  otcrypto_const_word32_buf_t ct = {.data = s->ct,
                                    .len = d.c_len / sizeof(uint32_t)};

  otcrypto_key_config_t ss_config = {
      .version = kOtcryptoLibVersion1,
      .key_mode = kOtcryptoKeyModeAesCtr,
      .key_length = ss_bytes,
      .hw_backed = kHardenedBoolFalse,
      .security_level = kOtcryptoKeySecurityLevelPassiveRemote,
  };
  uint32_t ss_blob[ceil_div(ss_bytes, sizeof(uint32_t)) * 2];
  memset(ss_blob, 0, sizeof(ss_blob));
  otcrypto_blinded_key_t ss = {
      .config = ss_config,
      .keyblob_length = sizeof(ss_blob),
      .keyblob = ss_blob,
  };
  ss.checksum = integrity_blinded_checksum(&ss);

  status_t decaps_status;
  switch (d.parameter_set) {
    case 512:
      decaps_status =
          otcrypto_mlkem512_decapsulate(&sk, ct, &ss, s->work.decaps);
      break;
    case 768:
      decaps_status =
          otcrypto_mlkem768_decapsulate(&sk, ct, &ss, s->work.decaps);
      break;
    case 1024:
      decaps_status =
          otcrypto_mlkem1024_decapsulate(&sk, ct, &ss, s->work.decaps);
      break;
    default:
      return INVALID_ARGUMENT();
  }
  if (!status_ok(decaps_status)) {
    return send_fail(uj);
  }

  size_t ss_words = keyblob_share_num_words(ss_config);
  uint32_t ss_unmasked[ss_words];
  TRY(keyblob_key_unmask(&ss, ss_words, ss_unmasked));

  cryptotest_mlkem_output_t out;
  memset(&out, 0, sizeof(out));
  TRY(hash_output((uint8_t *)ss_unmasked, ss_bytes, &out));
  out.success = true;
  RESP_OK(ujson_serialize_cryptotest_mlkem_output_t, uj, &out);
  return OK_STATUS();
}

status_t handle_mlkem(ujson_t *uj, mlkem_test_scratch_t *s) {
  mlkem_subcommand_t subcmd;
  TRY(ujson_deserialize_mlkem_subcommand_t(uj, &subcmd));

  switch (subcmd) {
    case kMlkemSubcommandMlkemKeygenDecaps:
      return handle_mlkem_keygen_decaps(uj, s);
    case kMlkemSubcommandMlkemKeygen:
      return handle_mlkem_keygen(uj, s);
    case kMlkemSubcommandMlkemEncaps:
      return handle_mlkem_encaps(uj, s);
    case kMlkemSubcommandMlkemDecaps:
      return handle_mlkem_decaps(uj, s);
    default:
      LOG_ERROR("Unrecognized ML-KEM subcommand: %d", subcmd);
      return INVALID_ARGUMENT();
  }
}
