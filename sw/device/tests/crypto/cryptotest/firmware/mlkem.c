// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "mlkem.h"

#include "sw/device/lib/base/math.h"
#include "sw/device/lib/base/memory.h"
#include "sw/device/lib/base/status.h"
#include "sw/device/lib/crypto/impl/integrity.h"
#include "sw/device/lib/crypto/impl/keyblob.h"
#include "sw/device/lib/crypto/include/sha3.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/test_framework/ujson_ottf.h"
#include "sw/device/lib/ujson/ujson.h"

#define MODULE_ID MAKE_MODULE_ID('m', 'c', 'k')

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
      .security_level = kOtcryptoKeySecurityLevelPassiveRemote,
  };
  size_t sk_blob_words = ceil_div(sk_bytes, sizeof(uint32_t)) * 2;
  memset(s->sk, 0, sk_blob_words * sizeof(uint32_t));
  otcrypto_blinded_key_t sk = {
      .config = sk_config,
      .keyblob_length = sk_blob_words * sizeof(uint32_t),
      .keyblob = s->sk,
  };
  sk.checksum = integrity_blinded_checksum(&sk);

  otcrypto_const_byte_buf_t seed = {.data = d.seed, .len = d.seed_len};
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

  otcrypto_const_byte_buf_t ct = {.data = d.c, .len = d.c_len};
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
      .security_level = kOtcryptoKeySecurityLevelPassiveRemote,
  };
  size_t sk_blob_words = ceil_div(sk_bytes, sizeof(uint32_t)) * 2;
  memset(s->sk, 0, sk_blob_words * sizeof(uint32_t));
  otcrypto_blinded_key_t sk = {
      .config = sk_config,
      .keyblob_length = sk_blob_words * sizeof(uint32_t),
      .keyblob = s->sk,
  };
  sk.checksum = integrity_blinded_checksum(&sk);

  otcrypto_const_byte_buf_t seed = {.data = d.seed, .len = d.seed_len};
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

  // Unmask sk and build pk||sk hash in work.tmp.
  size_t sk_words_count = keyblob_share_num_words(sk_config);
  uint8_t *hash_buf = s->work.tmp;
  memcpy(hash_buf, s->pk, pk_bytes);
  TRY(keyblob_key_unmask(&sk, sk_words_count,
                         (uint32_t *)(hash_buf + pk_bytes)));

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

  otcrypto_const_byte_buf_t m = {.data = d.seed, .len = d.seed_len};

  memset(s->ct, 0, sizeof(s->ct));
  otcrypto_byte_buf_t ct = {.data = s->ct, .len = ct_bytes};

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
      .security_level = kOtcryptoKeySecurityLevelPassiveRemote,
  };
  size_t dk_words_len = ceil_div(d.dk_len, sizeof(uint32_t));
  size_t sk_blob_words_needed = dk_words_len * 2;
  uint32_t *dk_raw = s->work.dk_scratch;
  uint32_t *dk_zeros = s->work.dk_scratch + dk_words_len;
  memset(dk_raw, 0, dk_words_len * sizeof(uint32_t));
  memcpy(dk_raw, d.dk, d.dk_len);
  memset(dk_zeros, 0, dk_words_len * sizeof(uint32_t));
  TRY(keyblob_from_shares(dk_raw, dk_zeros, sk_config, s->sk));
  otcrypto_blinded_key_t sk = {
      .config = sk_config,
      .keyblob_length = sk_blob_words_needed * sizeof(uint32_t),
      .keyblob = s->sk,
  };
  sk.checksum = integrity_blinded_checksum(&sk);

  otcrypto_const_byte_buf_t ct = {.data = d.c, .len = d.c_len};

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
