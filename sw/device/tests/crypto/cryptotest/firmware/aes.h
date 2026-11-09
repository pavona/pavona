// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_FIRMWARE_AES_H_
#define OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_FIRMWARE_AES_H_

#include "sw/device/lib/base/status.h"
#include "sw/device/lib/ujson/ujson.h"
#include "sw/device/tests/crypto/cryptotest/json/aes_commands.h"

// Scratch memory for AES tests.
typedef struct aes_test_scratch {
  cryptotest_aes_data_t data;
  cryptotest_aes_output_t output;
} aes_test_scratch_t;

status_t handle_aes_block(ujson_t *uj, aes_test_scratch_t *s);
status_t handle_aes(ujson_t *uj, aes_test_scratch_t *s);

#endif  // OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_FIRMWARE_AES_H_
