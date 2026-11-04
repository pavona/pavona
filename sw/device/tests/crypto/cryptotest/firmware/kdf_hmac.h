// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_FIRMWARE_KDF_HMAC_H_
#define OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_FIRMWARE_KDF_HMAC_H_

#include "sw/device/lib/base/status.h"
#include "sw/device/lib/ujson/ujson.h"
#include "sw/device/tests/crypto/cryptotest/json/kdf_hmac_commands.h"

// Scratch memory for KDF HMAC tests.
typedef struct kdf_hmac_test_scratch {
  cryptotest_kdf_hmac_input_t input;
  uint32_t key_in_share0[KDF_HMAC_CMD_MAX_KEY_IN_BYTES / sizeof(uint32_t)];
  uint32_t
      key_in_keyblob[2 * (KDF_HMAC_CMD_MAX_KEY_IN_BYTES / sizeof(uint32_t))];
  uint32_t
      key_out_keyblob[2 * (KDF_HMAC_CMD_MAX_KEY_OUT_BYTES / sizeof(uint32_t))];
} kdf_hmac_test_scratch_t;

status_t handle_kdf_hmac(ujson_t *uj, kdf_hmac_test_scratch_t *s);

#endif  // OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_FIRMWARE_KDF_HMAC_H_
