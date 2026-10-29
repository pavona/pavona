// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/tests/crypto/cryptotest/firmware/hmac.h"

#include "sw/device/lib/base/math.h"
#include "sw/device/lib/base/memory.h"
#include "sw/device/lib/base/status.h"
#include "sw/device/lib/crypto/impl/integrity.h"
#include "sw/device/lib/crypto/include/datatypes.h"
#include "sw/device/lib/crypto/include/hmac.h"
#include "sw/device/lib/crypto/include/key_transport.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/test_framework/ujson_ottf.h"
#include "sw/device/lib/ujson/ujson.h"
#include "sw/device/tests/crypto/cryptotest/json/hmac_commands.h"

const unsigned int kOtcryptoHmacTagBytesSha256 = 32;
const unsigned int kOtcryptoHmacTagBytesSha384 = 48;
const unsigned int kOtcryptoHmacTagBytesSha512 = 64;

const int MaxTagBytes = kOtcryptoHmacTagBytesSha512;
const int MaxTagWords = MaxTagBytes / sizeof(uint32_t);

// Random value for masking, as large as the longest test key. This value
// should not affect the result.
static const uint32_t kTestMask[kOtcryptoHmacMaxKeyWords] = {
    0xBA81767F, 0xA913C751, 0x34209992, 0x5F66021B, 0x775F4577, 0x7C02E1CE,
    0xB4A8B698, 0x1986B902, 0x7251045B, 0x3C827C6F, 0x00909D12, 0x81ABC8F9,
    0x62F2FCB6, 0x15B63124, 0x66F60052, 0xAD637669, 0x522779CF, 0x07E9FBA8,
    0x1258E541, 0x860719EF, 0x1D4F5386, 0xA9B04F7C, 0x6E98A861, 0xEFADEBA6,
    0x900E1EC8, 0xB290DBCE, 0x05946814, 0xB83A01CE, 0x4EEC86BD, 0xAE836C6C,
    0x20182AAE, 0x4476F6F4, 0x7C4A0A31, 0x7D2809BA, 0x367B29B9, 0x42444BEA,
    0xDFD6025C, 0x1E665207, 0x18E0895B, 0x20D435DB, 0xC509A6D6, 0x8CC19AB1,
    0xA5D39BD2, 0xAB479AD5, 0x5786D029, 0x2E4B7CD7, 0xB77A3D76, 0xE2A09962,
    0x156550E1, 0x8B017969, 0xF7108676, 0x531E7506, 0x1B21779A, 0xDA1A9D15,
    0xE2E8EB8B, 0x476810A5, 0x6FF31A81, 0xF2704695, 0xDFCB29AF, 0x9E2FAC0B,
    0x93F5CF4B, 0x18EA0985, 0xF274B831, 0x27EAD4F0, 0x668B397B, 0xC26AB93E,
    0x5AC3CDBF, 0xF5CADB6E, 0x7FDE6A9C, 0xFC1D6137, 0x55D9022F, 0x54E048F0,
    0x33556480, 0x6504E269, 0x0E1F7071, 0x029571CA, 0xC613C1A8, 0x78E6C197,
    0xFE194147, 0x800D735C, 0x2EEAD500, 0xE1EA0492, 0x3C03F04A, 0x1AB71264,
    0xF2AF50E4, 0xC6B58296, 0x16C9154D, 0x9E31A11E, 0xB94E9FCA, 0x5BC1DDB3,
    0x8B688382, 0xA8B4CD4F, 0x70FCD74E, 0x8D193750, 0x0860C155, 0xE08F426F,
    0xF0FFDC5D, 0x591C28E3, 0x46C67E41, 0x63C8DF10, 0x165EDA54, 0xD9B7E715,
    0x10F413B5, 0x301E4151, 0x53E700DD, 0xDBA5D583, 0x4BF5B586, 0xC37B35CA,
    0xCD59370A, 0x539E0C34, 0x6B76F5AD, 0x3A5D2710, 0x157271E0, 0xEB420987,
    0x6A2A660E, 0xE971B2B6, 0xE5B04901, 0x76F54662, 0x7FFA4BF4, 0x565C08F8,
    0x28B96291, 0xB6EF1727, 0x45301545, 0x2C425F0E, 0x98CE0A70, 0x027B24EB,
    0x2D4A5313, 0x0B928E99,
};

status_t handle_hmac(ujson_t *uj, hmac_test_scratch_t *s) {
  // Declare test arguments
  cryptotest_hmac_hash_alg_t uj_hash_alg;
  cryptotest_hmac_key_t *uj_key = &s->key;
  cryptotest_hmac_message_t *uj_message = &s->message;
  // Deserialize test arguments from UART
  TRY(ujson_deserialize_cryptotest_hmac_hash_alg_t(uj, &uj_hash_alg));
  TRY(ujson_deserialize_cryptotest_hmac_key_t(uj, uj_key));
  TRY(ujson_deserialize_cryptotest_hmac_message_t(uj, uj_message));

  otcrypto_key_mode_t key_mode;
  unsigned int tag_bytes;
  switch (uj_hash_alg) {
    case kCryptotestHmacHashAlgSha256:
      key_mode = kOtcryptoKeyModeHmacSha256;
      tag_bytes = kOtcryptoHmacTagBytesSha256;
      break;
    case kCryptotestHmacHashAlgSha384:
      key_mode = kOtcryptoKeyModeHmacSha384;
      tag_bytes = kOtcryptoHmacTagBytesSha384;
      break;
    case kCryptotestHmacHashAlgSha512:
      key_mode = kOtcryptoKeyModeHmacSha512;
      tag_bytes = kOtcryptoHmacTagBytesSha512;
      break;
    default:
      LOG_ERROR("Unsupported HMAC key mode: %d", uj_hash_alg);
      return INVALID_ARGUMENT();
  }
  // Build the key configuration
  otcrypto_key_config_t config = {
      .version = kOtcryptoLibVersion1,
      .key_mode = key_mode,
      .key_length = uj_key->key_len,
      .hw_backed = kHardenedBoolFalse,
      .security_level = kOtcryptoKeySecurityLevelPassiveRemote,
  };
  // Create key shares.
  size_t key_words = ceil_div(uj_key->key_len, sizeof(uint32_t));
  memset(s->key_share0, 0, sizeof(s->key_share0));
  memcpy(s->key_share0, uj_key->key, uj_key->key_len);
  for (size_t i = 0; i < key_words; i++) {
    s->key_share0[i] ^= kTestMask[i];
  }
  otcrypto_const_word32_buf_t share0 = {
      .data = s->key_share0,
      .len = key_words,
  };
  otcrypto_const_word32_buf_t share1 = {
      .data = kTestMask,
      .len = key_words,
  };
  // Create blinded key
  otcrypto_blinded_key_t key = {
      .config = config,
      .keyblob_length = 2 * key_words * sizeof(uint32_t),
      .keyblob = s->keyblob,
  };
  TRY(otcrypto_import_blinded_key(share0, share1, &key));

  otcrypto_const_byte_buf_t input_message = {
      .len = uj_message->message_len,
      .data = uj_message->message,
  };

  // Create tag
  uint32_t tag_buf[MaxTagWords];
  otcrypto_word32_buf_t tag = {
      .len = tag_bytes / sizeof(uint32_t),
      .data = tag_buf,
  };
  otcrypto_status_t status = otcrypto_hmac(&key, input_message, tag);
  if (status.value != kOtcryptoStatusValueOk) {
    return INTERNAL(status.value);
  }
  // Copy tag to uJSON type
  cryptotest_hmac_tag_t uj_tag;
  memcpy(uj_tag.tag, tag_buf, tag_bytes);
  uj_tag.tag_len = tag_bytes;

  // Send tag to host via UART
  RESP_OK(ujson_serialize_cryptotest_hmac_tag_t, uj, &uj_tag);
  return OK_STATUS(0);
}
