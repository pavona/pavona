// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_FIRMWARE_HKDF_H_
#define OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_FIRMWARE_HKDF_H_

#include "sw/device/lib/base/status.h"
#include "sw/device/lib/crypto/include/hkdf.h"
#include "sw/device/lib/crypto/include/hmac.h"
#include "sw/device/lib/ujson/ujson.h"
#include "sw/device/tests/crypto/cryptotest/json/hkdf_commands.h"

static_assert(HKDF_CMD_MAX_SALT_BYTES <= kOtcryptoHmacMaxKeyBytes,
              "The cryptolib must accept the longest test salt");

// Scratch memory for HKDF tests.
typedef struct hkdf_test_scratch {
  cryptotest_hkdf_input_t input;
  uint32_t ikm_share0[HKDF_CMD_MAX_IKM_BYTES / sizeof(uint32_t)];
  uint32_t ikm_keyblob[2 * (HKDF_CMD_MAX_IKM_BYTES / sizeof(uint32_t))];
  uint32_t okm_keyblob[2 * (HKDF_CMD_MAX_OKM_BYTES / sizeof(uint32_t))];
} hkdf_test_scratch_t;

status_t handle_hkdf(ujson_t *uj, hkdf_test_scratch_t *s);

#endif  // OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_FIRMWARE_HKDF_H_
