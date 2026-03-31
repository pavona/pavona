// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/crypto/impl/aes_kwp/aes_kwp.h"

#include "sw/device/lib/base/memory.h"
#include "sw/device/lib/base/status.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/test_framework/ujson_ottf.h"
#include "sw/device/lib/ujson/ujson.h"
#include "sw/device/tests/crypto/cryptotest/json/aes_kwp_commands.h"

// Module ID for status codes.
#define MODULE_ID MAKE_MODULE_ID('m', 'c', 'w')

enum {
  kAesMaxKeyBytes = 256 / 8,
  kAesMaxKeyWords = kAesMaxKeyBytes / 4,
};

// Arbitrary mask for testing (borrowed from aes_functest.c).
static const uint32_t kKeyMask[8] = {
    0x1b81540c, 0x220733c9, 0x8bf85383, 0x05ab50b4,
    0x8acdcb7e, 0x15e76440, 0x8459b2ce, 0xdc2110cc,
};

status_t handle_aes_kwp(ujson_t *uj) {
  aes_kwp_subcommand_t subcmd;
  TRY(ujson_deserialize_aes_kwp_subcommand_t(uj, &subcmd));
  if (subcmd != kAesKwpSubcommandAesKwpOp) {
    LOG_ERROR("Unrecognized AES-KWP subcommand: %d", subcmd);
    return INVALID_ARGUMENT();
  }

  cryptotest_aes_kwp_operation_t uj_op;
  cryptotest_aes_kwp_data_t uj_data;
  TRY(ujson_deserialize_cryptotest_aes_kwp_operation_t(uj, &uj_op));
  TRY(ujson_deserialize_cryptotest_aes_kwp_data_t(uj, &uj_data));

  // Build the KEK with two shares: share0 = key XOR mask, share1 = mask.
  uint32_t kek_share0[kAesMaxKeyWords];
  memset(kek_share0, 0, sizeof(kek_share0));
  memcpy(kek_share0, uj_data.key, uj_data.key_length);
  size_t kek_words = uj_data.key_length / sizeof(uint32_t);
  for (size_t i = 0; i < kek_words; i++) {
    kek_share0[i] ^= kKeyMask[i];
  }
  aes_key_t kek = {
      .mode = kAesCipherModeEcb,
      .sideload = kHardenedBoolFalse,
      .key_len = kek_words,
      .key_shares = {kek_share0, kKeyMask},
  };

  // Word-align the input buffer.
  size_t input_num_words =
      (uj_data.input_length + sizeof(uint32_t) - 1) / sizeof(uint32_t);
  uint32_t input_buf[input_num_words];
  memset(input_buf, 0, sizeof(input_buf));
  memcpy(input_buf, uj_data.input, uj_data.input_length);

  cryptotest_aes_kwp_output_t uj_output;
  memset(&uj_output, 0, sizeof(uj_output));

  switch (uj_op) {
    case kCryptotestAesKwpOperationWrap: {
      // Output is padded to next 8-byte boundary + 8-byte header.
      size_t padded_len = ((uj_data.input_length + 7) / 8) * 8;
      size_t ct_len = padded_len + 8;
      size_t ct_num_words = ct_len / sizeof(uint32_t);
      uint32_t ct_buf[ct_num_words];
      TRY(aes_kwp_wrap(kek, input_buf, uj_data.input_length, ct_buf));
      uj_output.output_len = ct_len;
      memcpy(uj_output.output, ct_buf, ct_len);
      uj_output.success = true;
      break;
    }
    case kCryptotestAesKwpOperationUnwrap: {
      uint32_t pt_buf[input_num_words];
      hardened_bool_t success;
      size_t pt_len;
      TRY(aes_kwp_unwrap(kek, input_buf, uj_data.input_length, &success, pt_buf,
                         &pt_len));
      if (success == kHardenedBoolTrue) {
        uj_output.success = true;
        uj_output.output_len = pt_len;
        memcpy(uj_output.output, pt_buf, pt_len);
      } else {
        uj_output.success = false;
        uj_output.output_len = 0;
      }
      break;
    }
    default:
      LOG_ERROR("Unrecognized AES-KWP operation: %d", uj_op);
      return INVALID_ARGUMENT();
  }

  RESP_OK(ujson_serialize_cryptotest_aes_kwp_output_t, uj, &uj_output);
  return OK_STATUS();
}
