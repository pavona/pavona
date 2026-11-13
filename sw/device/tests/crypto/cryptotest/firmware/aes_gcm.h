// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_FIRMWARE_AES_GCM_H_
#define OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_FIRMWARE_AES_GCM_H_

#include "sw/device/lib/base/status.h"
#include "sw/device/lib/ujson/ujson.h"
#include "sw/device/tests/crypto/cryptotest/json/aes_gcm_commands.h"

// Scratch memory for AES-GCM tests.
typedef struct aes_gcm_test_scratch {
  cryptotest_aes_gcm_data_t data;
  cryptotest_aes_gcm_output_t output;
} aes_gcm_test_scratch_t;

status_t handle_aes_gcm_op(ujson_t *uj, aes_gcm_test_scratch_t *s);
status_t handle_aes_gcm(ujson_t *uj, aes_gcm_test_scratch_t *s);

#endif  // OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_FIRMWARE_AES_GCM_H_
