// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/tests/crypto/cryptotest/firmware/kdf_hmac.h"

#include "sw/device/lib/base/math.h"
#include "sw/device/lib/base/memory.h"
#include "sw/device/lib/base/status.h"
#include "sw/device/lib/crypto/impl/keyblob.h"
#include "sw/device/lib/crypto/include/datatypes.h"
#include "sw/device/lib/crypto/include/hkdf.h"
#include "sw/device/lib/crypto/include/kdf_ctr.h"
#include "sw/device/lib/crypto/include/key_transport.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/test_framework/ujson_ottf.h"
#include "sw/device/lib/ujson/ujson.h"

// Random value for masking, as large as the longest test key. This value
// should not affect the result.
static const uint32_t
    kTestMask[KDF_HMAC_CMD_MAX_KEY_IN_BYTES / sizeof(uint32_t)] = {
        0xB12EC1F4, 0xD91E9F4F, 0xCB409606, 0x6683F506, 0xE9EDBC57, 0x6E911483,
        0x5233C8AE, 0xCC66E3DB, 0xCC575FE2, 0xEC7E7E41, 0x25A10E20, 0x195A4BDA,
        0xEC535559, 0x4955B425, 0x898DF193, 0xB126D516,
};

status_t handle_kdf_hmac(ujson_t *uj, kdf_hmac_test_scratch_t *s) {
  // Declare test arguments
  cryptotest_kdf_hmac_mode_t uj_mode;
  cryptotest_kdf_hmac_hash_alg_t uj_hash_alg;
  cryptotest_kdf_hmac_input_t *uj_input = &s->input;
  // Deserialize test arguments from UART
  TRY(ujson_deserialize_cryptotest_kdf_hmac_mode_t(uj, &uj_mode));
  TRY(ujson_deserialize_cryptotest_kdf_hmac_hash_alg_t(uj, &uj_hash_alg));
  TRY(ujson_deserialize_cryptotest_kdf_hmac_input_t(uj, uj_input));

  otcrypto_key_mode_t key_mode;
  switch (uj_hash_alg) {
    case kCryptotestKdfHmacHashAlgSha256:
      key_mode = kOtcryptoKeyModeHmacSha256;
      break;
    case kCryptotestKdfHmacHashAlgSha384:
      key_mode = kOtcryptoKeyModeHmacSha384;
      break;
    case kCryptotestKdfHmacHashAlgSha512:
      key_mode = kOtcryptoKeyModeHmacSha512;
      break;
    default:
      LOG_ERROR("Unsupported KDF hash algorithm: %d", uj_hash_alg);
      return INVALID_ARGUMENT();
  }
  if (uj_input->key_out_len > KDF_HMAC_CMD_MAX_KEY_OUT_BYTES) {
    return INVALID_ARGUMENT();
  }
  // Build the key configurations
  otcrypto_key_config_t key_in_config = {
      .version = kOtcryptoLibVersion1,
      .key_mode = key_mode,
      .key_length = uj_input->key_in_len,
      .hw_backed = kHardenedBoolFalse,
      .security_level = kOtcryptoKeySecurityLevelPassiveRemote,
  };
  otcrypto_key_config_t key_out_config = {
      .version = kOtcryptoLibVersion1,
      .key_mode = key_mode,
      .key_length = uj_input->key_out_len,
      .hw_backed = kHardenedBoolFalse,
      .security_level = kOtcryptoKeySecurityLevelPassiveRemote,
  };
  // Create key shares.
  size_t key_in_words = ceil_div(uj_input->key_in_len, sizeof(uint32_t));
  memset(s->key_in_share0, 0, sizeof(s->key_in_share0));
  memcpy(s->key_in_share0, uj_input->key_in, uj_input->key_in_len);
  for (size_t i = 0; i < key_in_words; i++) {
    s->key_in_share0[i] ^= kTestMask[i];
  }
  otcrypto_const_word32_buf_t share0 = {
      .data = s->key_in_share0,
      .len = key_in_words,
  };
  otcrypto_const_word32_buf_t share1 = {
      .data = kTestMask,
      .len = key_in_words,
  };
  // Create blinded keys
  otcrypto_blinded_key_t key_in = {
      .config = key_in_config,
      .keyblob_length = 2 * key_in_words * sizeof(uint32_t),
      .keyblob = s->key_in_keyblob,
  };
  TRY(otcrypto_import_blinded_key(share0, share1, &key_in));
  size_t key_out_words = ceil_div(uj_input->key_out_len, sizeof(uint32_t));
  otcrypto_blinded_key_t key_out = {
      .config = key_out_config,
      .keyblob_length = 2 * key_out_words * sizeof(uint32_t),
      .keyblob = s->key_out_keyblob,
  };

  otcrypto_const_byte_buf_t fixed_data = {
      .data = uj_input->fixed_data,
      .len = uj_input->fixed_data_len,
  };
  otcrypto_status_t status;
  switch (uj_mode) {
    case kCryptotestKdfHmacModeCounter:
      status = otcrypto_kdf_ctr_hmac(&key_in, fixed_data, &key_out);
      break;
    case kCryptotestKdfHmacModeFeedback:
      status = otcrypto_hkdf_expand(&key_in, fixed_data, &key_out);
      break;
    default:
      LOG_ERROR("Unsupported KDF mode: %d", uj_mode);
      return INVALID_ARGUMENT();
  }
  if (status.value != kOtcryptoStatusValueOk) {
    return INTERNAL(status.value);
  }

  // Unmask the derived key
  uint32_t *key_out_share0;
  uint32_t *key_out_share1;
  TRY(keyblob_to_shares(&key_out, &key_out_share0, &key_out_share1));
  uint32_t key_out_buf[KDF_HMAC_CMD_MAX_KEY_OUT_BYTES / sizeof(uint32_t)];
  for (size_t i = 0; i < key_out_words; i++) {
    key_out_buf[i] = key_out_share0[i] ^ key_out_share1[i];
  }

  // Copy the derived key to uJSON type
  cryptotest_kdf_hmac_output_t uj_output;
  memcpy(uj_output.key_out, key_out_buf, uj_input->key_out_len);
  uj_output.key_out_len = uj_input->key_out_len;

  // Send the derived key to host via UART
  RESP_OK(ujson_serialize_cryptotest_kdf_hmac_output_t, uj, &uj_output);
  return OK_STATUS(0);
}
