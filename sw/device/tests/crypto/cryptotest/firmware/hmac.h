// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_FIRMWARE_HMAC_H_
#define OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_FIRMWARE_HMAC_H_

#include "sw/device/lib/base/status.h"
#include "sw/device/lib/crypto/include/hmac.h"
#include "sw/device/lib/ujson/ujson.h"
#include "sw/device/tests/crypto/cryptotest/json/hmac_commands.h"

static_assert(HMAC_CMD_MAX_KEY_BYTES <= kOtcryptoHmacMaxKeyBytes,
              "The cryptolib must accept the longest test key");

// Scratch memory for HMAC tests.
typedef struct hmac_test_scratch {
  cryptotest_hmac_key_t key;
  cryptotest_hmac_message_t message;
  uint32_t key_share0[kOtcryptoHmacMaxKeyWords];
  uint32_t keyblob[2 * kOtcryptoHmacMaxKeyWords];
} hmac_test_scratch_t;

status_t handle_hmac(ujson_t *uj, hmac_test_scratch_t *s);

#endif  // OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_FIRMWARE_HMAC_H_
