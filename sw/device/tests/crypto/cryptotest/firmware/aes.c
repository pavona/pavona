// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/tests/crypto/cryptotest/firmware/aes.h"

#include "sw/device/lib/base/memory.h"
#include "sw/device/lib/base/status.h"
#include "sw/device/lib/crypto/impl/integrity.h"
#include "sw/device/lib/crypto/impl/keyblob.h"
#include "sw/device/lib/crypto/include/aes.h"
#include "sw/device/lib/crypto/include/datatypes.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/test_framework/ujson_ottf.h"
#include "sw/device/lib/ujson/ujson.h"
#include "sw/device/tests/crypto/cryptotest/json/aes_commands.h"

enum {
  kAesBlockBytes = 128 / 8,
  kAesBlockWords = kAesBlockBytes / sizeof(uint32_t),
  kAesMaxKeyBytes = 256 / 8,
  kAesMaxKeyWords = kAesMaxKeyBytes / 4,
};

// Arbitrary mask for testing (borrowed from aes_functest.c).
static const uint32_t kKeyMask[8] = {
    0x1b81540c, 0x220733c9, 0x8bf85383, 0x05ab50b4,
    0x8acdcb7e, 0x15e76440, 0x8459b2ce, 0xdc2110cc,
};

static status_t aes_mode(cryptotest_aes_mode_t uj_mode,
                         otcrypto_aes_mode_t *mode,
                         otcrypto_key_mode_t *key_mode) {
  switch (uj_mode) {
    case kCryptotestAesModeEcb:
      *mode = kOtcryptoAesModeEcb;
      *key_mode = kOtcryptoKeyModeAesEcb;
      break;
    case kCryptotestAesModeCbc:
      *mode = kOtcryptoAesModeCbc;
      *key_mode = kOtcryptoKeyModeAesCbc;
      break;
    case kCryptotestAesModeCfb:
      *mode = kOtcryptoAesModeCfb;
      *key_mode = kOtcryptoKeyModeAesCfb;
      break;
    case kCryptotestAesModeOfb:
      *mode = kOtcryptoAesModeOfb;
      *key_mode = kOtcryptoKeyModeAesOfb;
      break;
    case kCryptotestAesModeCtr:
      *mode = kOtcryptoAesModeCtr;
      *key_mode = kOtcryptoKeyModeAesCtr;
      break;
    default:
      LOG_ERROR("Unrecognized AES block cipher mode: %d", uj_mode);
      return INVALID_ARGUMENT();
  }
  return OK_STATUS(0);
}

static status_t aes_operation(cryptotest_aes_operation_t uj_op,
                              otcrypto_aes_operation_t *op) {
  switch (uj_op) {
    case kCryptotestAesOperationEncrypt:
      *op = kOtcryptoAesOperationEncrypt;
      break;
    case kCryptotestAesOperationDecrypt:
      *op = kOtcryptoAesOperationDecrypt;
      break;
    default:
      LOG_ERROR("Unrecognized AES operation: %d", uj_op);
      return INVALID_ARGUMENT();
  }
  return OK_STATUS(0);
}

status_t handle_aes_block(ujson_t *uj, aes_test_scratch_t *s) {
  cryptotest_aes_mode_t uj_mode;
  cryptotest_aes_operation_t uj_op;
  cryptotest_aes_padding_t uj_padding;
  cryptotest_aes_data_t *uj_data = &s->data;
  TRY(ujson_deserialize_cryptotest_aes_mode_t(uj, &uj_mode));
  TRY(ujson_deserialize_cryptotest_aes_operation_t(uj, &uj_op));
  TRY(ujson_deserialize_cryptotest_aes_padding_t(uj, &uj_padding));
  TRY(ujson_deserialize_cryptotest_aes_data_t(uj, uj_data));

  otcrypto_aes_mode_t mode;
  otcrypto_key_mode_t key_mode;
  TRY(aes_mode(uj_mode, &mode, &key_mode));

  otcrypto_aes_operation_t op;
  TRY(aes_operation(uj_op, &op));

  otcrypto_aes_padding_t padding;
  switch (uj_padding) {
    case kCryptotestAesPaddingPkcs7:
      padding = kOtcryptoAesPaddingPkcs7;
      break;
    case kCryptotestAesPaddingIso9797M2:
      padding = kOtcryptoAesPaddingIso9797M2;
      break;
    case kCryptotestAesPaddingNull:
      padding = kOtcryptoAesPaddingNull;
      break;
    default:
      LOG_ERROR("Unrecognized AES padding scheme: %d", uj_op);
      return INVALID_ARGUMENT();
  }

  // Convert the data struct into cryptolib types
  const size_t AES_IV_SIZE = 4;
  uint32_t iv_buf[AES_IV_SIZE];
  memcpy(iv_buf, uj_data->iv, AES_IV_SIZE * 4);
  otcrypto_word32_buf_t iv = {
      .data = iv_buf,
      .len = kAesBlockWords,
  };

  otcrypto_const_byte_buf_t input = {
      .data = uj_data->input,
      .len = (size_t)uj_data->input_len,
  };

  // Build the key configuration
  otcrypto_key_config_t config = {
      .version = kOtcryptoLibVersion1,
      .key_mode = key_mode,
      .key_length = uj_data->key_length,
      .hw_backed = kHardenedBoolFalse,
      .security_level = kOtcryptoKeySecurityLevelPassiveRemote,
  };
  // Create buffer to store key
  uint32_t key_buf[kAesMaxKeyWords];
  memcpy(key_buf, uj_data->key, kAesMaxKeyBytes);
  // Create keyblob
  size_t keyblob_words = 0;
  TRY(keyblob_num_words(config, &keyblob_words));
  uint32_t keyblob[2 * kAesMaxKeyWords];
  if (keyblob_words > ARRAYSIZE(keyblob)) {
    return INVALID_ARGUMENT();
  }
  // Create blinded key
  TRY(keyblob_from_key_and_mask(key_buf, kKeyMask, config, keyblob));
  otcrypto_blinded_key_t key = {
      .config = config,
      .keyblob_length = keyblob_words * sizeof(uint32_t),
      .keyblob = keyblob,
  };
  key.checksum = integrity_blinded_checksum(&key);

  size_t padded_len_bytes;
  TRY(otcrypto_aes_padded_plaintext_length((size_t)uj_data->input_len, padding,
                                           &padded_len_bytes));
  if (padded_len_bytes > AES_CMD_MAX_MSG_BYTES) {
    return OUT_OF_RANGE();
  }
  cryptotest_aes_output_t *uj_output = &s->output;
  otcrypto_byte_buf_t output = {
      .data = uj_output->output,
      .len = padded_len_bytes,
  };

  TRY(otcrypto_aes(&key, iv, mode, op, input, padding, output));

  uj_output->output_len = padded_len_bytes;
  RESP_OK(ujson_serialize_cryptotest_aes_output_t, uj, uj_output);
  return OK_STATUS(0);
}

enum {
  kAesMctOuterIterations = 100,
  kAesMctInnerIterations = 1000,
};

static status_t handle_aes_mct(ujson_t *uj, aes_test_scratch_t *s) {
  cryptotest_aes_mode_t uj_mode;
  cryptotest_aes_operation_t uj_op;
  cryptotest_aes_data_t *uj_data = &s->data;
  TRY(ujson_deserialize_cryptotest_aes_mode_t(uj, &uj_mode));
  TRY(ujson_deserialize_cryptotest_aes_operation_t(uj, &uj_op));
  TRY(ujson_deserialize_cryptotest_aes_data_t(uj, uj_data));

  otcrypto_aes_mode_t mode;
  otcrypto_key_mode_t key_mode;
  TRY(aes_mode(uj_mode, &mode, &key_mode));
  otcrypto_aes_operation_t op;
  TRY(aes_operation(uj_op, &op));
  size_t key_len = uj_data->key_length;
  if (key_len > kAesMaxKeyBytes || uj_data->input_len != kAesBlockBytes) {
    return INVALID_ARGUMENT();
  }
  otcrypto_key_config_t config = {
      .version = kOtcryptoLibVersion1,
      .key_mode = key_mode,
      .key_length = key_len,
      .hw_backed = kHardenedBoolFalse,
      .security_level = kOtcryptoKeySecurityLevelPassiveRemote,
  };
  size_t keyblob_words = 0;
  TRY(keyblob_num_words(config, &keyblob_words));

  // The key, IV and input of the current outer iteration.
  uint32_t key_buf[kAesMaxKeyWords] = {0};
  uint32_t iv[kAesBlockWords];
  uint32_t input[kAesBlockWords];
  memcpy(key_buf, uj_data->key, key_len);
  memcpy(iv, uj_data->iv, kAesBlockBytes);
  memcpy(input, uj_data->input, kAesBlockBytes);

  cryptotest_aes_mct_output_t *uj_output = &s->mct_output;
  memset(uj_output, 0, sizeof(*uj_output));
  for (size_t i = 0; i < kAesMctOuterIterations; i++) {
    memcpy(&uj_output->keys[i * key_len], key_buf, key_len);
    memcpy(&uj_output->ivs[i * kAesBlockBytes], iv, kAesBlockBytes);
    memcpy(&uj_output->inputs[i * kAesBlockBytes], input, kAesBlockBytes);

    uint32_t keyblob[2 * kAesMaxKeyWords];
    TRY(keyblob_from_key_and_mask(key_buf, kKeyMask, config, keyblob));
    otcrypto_blinded_key_t key = {
        .config = config,
        .keyblob_length = keyblob_words * sizeof(uint32_t),
        .keyblob = keyblob,
    };
    key.checksum = integrity_blinded_checksum(&key);
    // `otcrypto_aes` carries the IV from one block to the next.
    uint32_t chain_iv[kAesBlockWords];
    memcpy(chain_iv, iv, kAesBlockBytes);
    otcrypto_word32_buf_t chain = {
        .data = chain_iv,
        .len = kAesBlockWords,
    };
    // The outputs of the last two inner iterations, `prev || last`.
    uint32_t blocks[2 * kAesBlockWords];
    uint32_t *prev = &blocks[0];
    uint32_t *last = &blocks[kAesBlockWords];
    for (size_t j = 0; j < kAesMctInnerIterations; j++) {
      uint32_t out[kAesBlockWords];
      otcrypto_const_byte_buf_t in_buf = {
          .data = (const unsigned char *)input,
          .len = kAesBlockBytes,
      };
      otcrypto_byte_buf_t out_buf = {
          .data = (unsigned char *)out,
          .len = kAesBlockBytes,
      };
      otcrypto_status_t status = otcrypto_aes(&key, chain, mode, op, in_buf,
                                              kOtcryptoAesPaddingNull, out_buf);
      if (status.value != kOtcryptoStatusValueOk) {
        return INTERNAL(status.value);
      }
      // ECB feeds each output back in. The other modes feed in the IV, then
      // the output before last.
      if (mode == kOtcryptoAesModeEcb) {
        memcpy(input, out, kAesBlockBytes);
      } else if (j == 0) {
        memcpy(input, iv, kAesBlockBytes);
      } else {
        memcpy(input, last, kAesBlockBytes);
      }
      memcpy(prev, last, kAesBlockBytes);
      memcpy(last, out, kAesBlockBytes);
    }
    memcpy(&uj_output->outputs[i * kAesBlockBytes], last, kAesBlockBytes);

    // XOR the key with the last `key_len` bytes of `prev || last`.
    uint8_t *key_bytes = (uint8_t *)key_buf;
    uint8_t *tail = (uint8_t *)blocks + sizeof(blocks) - key_len;
    for (size_t k = 0; k < key_len; k++) {
      key_bytes[k] ^= tail[k];
    }
    memcpy(iv, last, kAesBlockBytes);
  }

  uj_output->keys_len = kAesMctOuterIterations * key_len;
  uj_output->ivs_len = kAesMctOuterIterations * kAesBlockBytes;
  uj_output->inputs_len = kAesMctOuterIterations * kAesBlockBytes;
  uj_output->outputs_len = kAesMctOuterIterations * kAesBlockBytes;
  RESP_OK(ujson_serialize_cryptotest_aes_mct_output_t, uj, uj_output);
  return OK_STATUS(0);
}

status_t handle_aes(ujson_t *uj, aes_test_scratch_t *s) {
  aes_subcommand_t cmd;
  TRY(ujson_deserialize_aes_subcommand_t(uj, &cmd));
  switch (cmd) {
    case kAesSubcommandAesBlock:
      return handle_aes_block(uj, s);
      break;
    case kAesSubcommandAesMct:
      return handle_aes_mct(uj, s);
      break;
    default:
      LOG_ERROR("Unrecognized AES subcommand: %d", cmd);
      return INVALID_ARGUMENT();
  }
  return OK_STATUS(0);
}
