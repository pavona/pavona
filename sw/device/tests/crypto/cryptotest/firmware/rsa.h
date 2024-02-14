// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_FIRMWARE_RSA_H_
#define OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_FIRMWARE_RSA_H_

#include "sw/device/lib/base/status.h"
#include "sw/device/lib/ujson/ujson.h"

status_t handle_rsa_pkcs1_15_sign(ujson_t *uj);
status_t handle_rsa_pkcs1_15_verify(ujson_t *uj);
status_t handle_rsa_pss_sign(ujson_t *uj);
status_t handle_rsa_pss_verify(ujson_t *uj);
status_t handle_rsa_oaep_encrypt(ujson_t *uj);
status_t handle_rsa_oaep_decrypt(ujson_t *uj);
status_t handle_rsa(ujson_t *uj);

#endif  // OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_FIRMWARE_RSA_H_
