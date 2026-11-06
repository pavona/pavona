// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/tests/crypto/cryptotest/firmware/kdf_kmac.h"

#include "sw/device/lib/base/math.h"
#include "sw/device/lib/base/memory.h"
#include "sw/device/lib/base/status.h"
#include "sw/device/lib/crypto/impl/keyblob.h"
#include "sw/device/lib/crypto/include/datatypes.h"
#include "sw/device/lib/crypto/include/key_transport.h"
#include "sw/device/lib/crypto/include/kmac_kdf.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/test_framework/ujson_ottf.h"
#include "sw/device/lib/ujson/ujson.h"

// Module ID for status codes.
#define MODULE_ID MAKE_MODULE_ID('k', 'd', 'k')

// Random value for masking, as large as the longest test key. This value
// should not affect the result.
static const uint32_t
    kTestMask[KDF_KMAC_CMD_MAX_KEY_IN_BYTES / sizeof(uint32_t)] = {
        0x31CC7B54, 0x0BC191C5, 0x5AE633CB, 0x77A19599, 0xC00B89BB, 0x7AA2F65C,
        0x5E59F686, 0xDFDC6974, 0xDB59A5D9, 0x2C537A29, 0xF4E79DDC, 0x8B1B8FE6,
        0xAE3F8A70, 0xA8893203, 0xCD4A882E, 0x7834C1F0,
};

status_t handle_kdf_kmac(ujson_t *uj, kdf_kmac_test_scratch_t *s) {
  // Declare test arguments
  cryptotest_kdf_kmac_mode_t uj_mode;
  cryptotest_kdf_kmac_input_t *uj_input = &s->input;
  // Deserialize test arguments from UART
  TRY(ujson_deserialize_cryptotest_kdf_kmac_mode_t(uj, &uj_mode));
  TRY(ujson_deserialize_cryptotest_kdf_kmac_input_t(uj, uj_input));

  otcrypto_key_mode_t key_mode;
  switch (uj_mode) {
    case kCryptotestKdfKmacModeKmac128:
      key_mode = kOtcryptoKeyModeKdfKmac128;
      break;
    case kCryptotestKdfKmacModeKmac256:
      key_mode = kOtcryptoKeyModeKdfKmac256;
      break;
    default:
      LOG_ERROR("Unsupported KDF KMAC mode: %d", uj_mode);
      return INVALID_ARGUMENT();
  }
  if (uj_input->key_out_len > KDF_KMAC_CMD_MAX_KEY_OUT_BYTES) {
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

  otcrypto_const_byte_buf_t label = {
      .data = uj_input->label,
      .len = uj_input->label_len,
  };
  otcrypto_const_byte_buf_t context = {
      .data = uj_input->context,
      .len = uj_input->context_len,
  };
  otcrypto_status_t status =
      otcrypto_kmac_kdf(&key_in, label, context, &key_out);
  if (status.value != kOtcryptoStatusValueOk) {
    return INTERNAL(status.value);
  }

  // Unmask the derived key
  uint32_t *key_out_share0;
  uint32_t *key_out_share1;
  TRY(keyblob_to_shares(&key_out, &key_out_share0, &key_out_share1));
  uint32_t key_out_buf[KDF_KMAC_CMD_MAX_KEY_OUT_BYTES / sizeof(uint32_t)];
  for (size_t i = 0; i < key_out_words; i++) {
    key_out_buf[i] = key_out_share0[i] ^ key_out_share1[i];
  }

  // Copy the derived key to uJSON type
  cryptotest_kdf_kmac_output_t uj_output;
  memcpy(uj_output.key_out, key_out_buf, uj_input->key_out_len);
  uj_output.key_out_len = uj_input->key_out_len;

  // Send the derived key to host via UART
  RESP_OK(ujson_serialize_cryptotest_kdf_kmac_output_t, uj, &uj_output);
  return OK_STATUS(0);
}
