// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "mldsa.h"

#include "sw/device/lib/base/math.h"
#include "sw/device/lib/base/memory.h"
#include "sw/device/lib/base/status.h"
#include "sw/device/lib/crypto/impl/integrity.h"
#include "sw/device/lib/crypto/impl/keyblob.h"
#include "sw/device/lib/crypto/include/sha3.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/test_framework/ujson_ottf.h"
#include "sw/device/lib/ujson/ujson.h"

#define MODULE_ID MAKE_MODULE_ID('m', 'c', 'd')

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

static status_t send_fail(ujson_t *uj) {
  cryptotest_mldsa_output_t out;
  memset(&out, 0, sizeof(out));
  out.success = false;
  RESP_OK(ujson_serialize_cryptotest_mldsa_output_t, uj, &out);
  return OK_STATUS();
}

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

  otcrypto_const_byte_buf_t seed = {.data = d->seed, .len = d->seed_len};
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

  cryptotest_mldsa_output_t out;
  memset(&out, 0, sizeof(out));
  TRY(hash_output(hash_buf, pk_bytes + sk_bytes, &out));
  out.success = true;
  RESP_OK(ujson_serialize_cryptotest_mldsa_output_t, uj, &out);
  return OK_STATUS();
}

// Keygen from seed, then sign. Output hash: SHA3-256(pk || signature).
static status_t handle_mldsa_keygen_sign(ujson_t *uj, mldsa_test_scratch_t *s) {
  cryptotest_mldsa_keygen_sign_data_t *d = &s->cmd.keygen_sign;
  TRY(ujson_deserialize_cryptotest_mldsa_keygen_sign_data_t(uj, d));

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

  otcrypto_const_byte_buf_t seed = {.data = d->seed, .len = d->seed_len};
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
  }
  if (!status_ok(keygen_status)) {
    return send_fail(uj);
  }

  otcrypto_const_byte_buf_t message = {.data = d->message,
                                       .len = d->message_len};
  otcrypto_const_byte_buf_t context = {.data = d->context,
                                       .len = d->context_len};
  otcrypto_const_byte_buf_t rnd = {.data = d->rnd, .len = d->rnd_len};

  memset(s->sig, 0, sig_bytes);
  otcrypto_byte_buf_t signature = {.data = s->sig, .len = sig_bytes};

  status_t sign_status;
  switch (d->parameter_set) {
    case 44:
      sign_status = otcrypto_mldsa44_sign_derand(&sk, message, context,
                                                 kOtcryptoMldsaSignModeMldsa,
                                                 rnd, signature, s->work.sign);
      break;
    case 65:
      sign_status = otcrypto_mldsa65_sign_derand(&sk, message, context,
                                                 kOtcryptoMldsaSignModeMldsa,
                                                 rnd, signature, s->work.sign);
      break;
    case 87:
      sign_status = otcrypto_mldsa87_sign_derand(&sk, message, context,
                                                 kOtcryptoMldsaSignModeMldsa,
                                                 rnd, signature, s->work.sign);
      break;
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

// Output hash: SHA3-256(signature).
static status_t handle_mldsa_siggen(ujson_t *uj, mldsa_test_scratch_t *s) {
  cryptotest_mldsa_siggen_data_t *d = &s->cmd.siggen;
  TRY(ujson_deserialize_cryptotest_mldsa_siggen_data_t(uj, d));

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

  // Build blinded secret key using sk_scratch (free until sign call).
  // Use the actual received sk_len so the API rejects incorrect lengths.
  otcrypto_key_config_t sk_config = {
      .version = kOtcryptoLibVersion1,
      .key_mode = key_mode,
      .key_length = d->sk_len,
      .hw_backed = kHardenedBoolFalse,
      .security_level = kOtcryptoKeySecurityLevelPassiveRemote,
  };
  size_t sk_words_len = ceil_div(d->sk_len, sizeof(uint32_t));
  size_t sk_blob_words_needed = sk_words_len * 2;
  uint32_t *sk_raw = s->work.sk_scratch;
  uint32_t *sk_zero = s->work.sk_scratch + sk_words_len;
  memset(sk_raw, 0, sk_words_len * sizeof(uint32_t));
  memcpy(sk_raw, d->sk, d->sk_len);
  memset(sk_zero, 0, sk_words_len * sizeof(uint32_t));
  TRY(keyblob_from_shares(sk_raw, sk_zero, sk_config, s->sk));
  otcrypto_blinded_key_t sk = {
      .config = sk_config,
      .keyblob_length = sk_blob_words_needed * sizeof(uint32_t),
      .keyblob = s->sk,
  };
  sk.checksum = integrity_blinded_checksum(&sk);

  otcrypto_const_byte_buf_t message = {.data = d->message,
                                       .len = d->message_len};
  otcrypto_const_byte_buf_t context = {.data = d->context,
                                       .len = d->context_len};
  otcrypto_const_byte_buf_t rnd = {.data = d->rnd, .len = d->rnd_len};

  memset(s->sig, 0, sig_bytes);
  otcrypto_byte_buf_t signature = {.data = s->sig, .len = sig_bytes};

  status_t sign_status;
  switch (d->parameter_set) {
    case 44:
      sign_status = otcrypto_mldsa44_sign_derand(&sk, message, context,
                                                 kOtcryptoMldsaSignModeMldsa,
                                                 rnd, signature, s->work.sign);
      break;
    case 65:
      sign_status = otcrypto_mldsa65_sign_derand(&sk, message, context,
                                                 kOtcryptoMldsaSignModeMldsa,
                                                 rnd, signature, s->work.sign);
      break;
    case 87:
      sign_status = otcrypto_mldsa87_sign_derand(&sk, message, context,
                                                 kOtcryptoMldsaSignModeMldsa,
                                                 rnd, signature, s->work.sign);
      break;
  }
  if (!status_ok(sign_status)) {
    return send_fail(uj);
  }

  cryptotest_mldsa_output_t out;
  memset(&out, 0, sizeof(out));
  TRY(hash_output(s->sig, sig_bytes, &out));
  out.success = true;
  RESP_OK(ujson_serialize_cryptotest_mldsa_output_t, uj, &out);
  return OK_STATUS();
}

// Sigver: returns success/failure only, no hash.
static status_t handle_mldsa_sigver(ujson_t *uj, mldsa_test_scratch_t *s) {
  cryptotest_mldsa_sigver_data_t *d = &s->cmd.sigver;
  TRY(ujson_deserialize_cryptotest_mldsa_sigver_data_t(uj, d));

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
  otcrypto_const_byte_buf_t signature = {.data = d->signature,
                                         .len = d->signature_len};

  hardened_bool_t verification_result = kHardenedBoolFalse;
  status_t verify_status;
  switch (d->parameter_set) {
    case 44:
      verify_status = otcrypto_mldsa44_verify(
          &pk, message, context, kOtcryptoMldsaSignModeMldsa, signature,
          &verification_result, s->work.verify);
      break;
    case 65:
      verify_status = otcrypto_mldsa65_verify(
          &pk, message, context, kOtcryptoMldsaSignModeMldsa, signature,
          &verification_result, s->work.verify);
      break;
    case 87:
      verify_status = otcrypto_mldsa87_verify(
          &pk, message, context, kOtcryptoMldsaSignModeMldsa, signature,
          &verification_result, s->work.verify);
      break;
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
