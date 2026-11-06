// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_FIRMWARE_KDF_KMAC_H_
#define OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_FIRMWARE_KDF_KMAC_H_

#include "sw/device/lib/base/status.h"
#include "sw/device/lib/ujson/ujson.h"
#include "sw/device/tests/crypto/cryptotest/json/kdf_kmac_commands.h"

// Scratch memory for KDF KMAC tests.
typedef struct kdf_kmac_test_scratch {
  cryptotest_kdf_kmac_input_t input;
  uint32_t key_in_share0[KDF_KMAC_CMD_MAX_KEY_IN_BYTES / sizeof(uint32_t)];
  uint32_t
      key_in_keyblob[2 * (KDF_KMAC_CMD_MAX_KEY_IN_BYTES / sizeof(uint32_t))];
  uint32_t
      key_out_keyblob[2 * (KDF_KMAC_CMD_MAX_KEY_OUT_BYTES / sizeof(uint32_t))];
} kdf_kmac_test_scratch_t;

status_t handle_kdf_kmac(ujson_t *uj, kdf_kmac_test_scratch_t *s);

#endif  // OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_FIRMWARE_KDF_KMAC_H_
