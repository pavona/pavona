// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_FIRMWARE_HASH_H_
#define OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_FIRMWARE_HASH_H_

#include "sw/device/lib/base/status.h"
#include "sw/device/lib/ujson/ujson.h"
#include "sw/device/tests/crypto/cryptotest/json/hash_commands.h"

// Scratch memory for hash tests.
typedef struct hash_test_scratch {
  cryptotest_hash_message_t message;
  uint32_t digest[HASH_CMD_MAX_DIGEST_BYTES / sizeof(uint32_t)];
  cryptotest_hash_output_t output;
  cryptotest_hash_mct_output_t mct_output;
} hash_test_scratch_t;

status_t handle_hash(ujson_t *uj, hash_test_scratch_t *s);

// Runs the ACVP SHA3 Monte Carlo test.
status_t handle_hash_mct(ujson_t *uj, hash_test_scratch_t *s);

#endif  // OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_FIRMWARE_HASH_H_
