// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_FIRMWARE_SPHINCSPLUS_H_
#define OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_FIRMWARE_SPHINCSPLUS_H_

#include "sw/device/lib/base/status.h"
#include "sw/device/lib/ujson/ujson.h"
#include "sw/device/tests/crypto/cryptotest/json/sphincsplus_commands.h"

// Scratch memory for SPHINCS+ tests.
typedef struct sphincsplus_test_scratch {
  cryptotest_sphincsplus_message_t message;
  cryptotest_sphincsplus_signature_t signature;
} sphincsplus_test_scratch_t;

status_t handle_sphincsplus(ujson_t *uj, sphincsplus_test_scratch_t *s);

#endif  // OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_FIRMWARE_SPHINCSPLUS_H_
