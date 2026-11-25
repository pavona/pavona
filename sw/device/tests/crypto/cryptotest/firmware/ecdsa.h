// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_FIRMWARE_ECDSA_H_
#define OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_FIRMWARE_ECDSA_H_

#include "sw/device/lib/base/status.h"
#include "sw/device/lib/ujson/ujson.h"
#include "sw/device/lib/crypto/impl/ecc/p384.h"
#include "sw/device/tests/crypto/cryptotest/json/ecdsa_commands.h"

// Scratch memory for ECDSA tests.
typedef struct ecdsa_test_scratch {
  uint32_t pk[(sizeof(p384_point_t) + sizeof(uint32_t) - 1) / sizeof(uint32_t)];
  uint32_t sk[(sizeof(p384_masked_scalar_t) + sizeof(uint32_t) - 1) / sizeof(uint32_t)];
  uint32_t sig[(sizeof(p384_ecdsa_signature_t) + sizeof(uint32_t) - 1) / sizeof(uint32_t)];
  union {
    cryptotest_ecdsa_signature_t sign_out;
    cryptotest_ecdsa_verify_output_t verify_out;
  } work;
} ecdsa_test_scratch_t;

status_t handle_ecdsa(ujson_t *uj, ecdsa_test_scratch_t *s);

#endif  // OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_FIRMWARE_ECDSA_H_
