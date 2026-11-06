// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_JSON_KDF_KMAC_COMMANDS_H_
#define OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_JSON_KDF_KMAC_COMMANDS_H_
#include "sw/device/lib/ujson/ujson_derive.h"
#ifdef __cplusplus
extern "C" {
#endif

#define MODULE_ID MAKE_MODULE_ID('j', 'k', 'k')

#define KDF_KMAC_CMD_MAX_KEY_IN_BYTES 64
#define KDF_KMAC_CMD_MAX_LABEL_BYTES 32
#define KDF_KMAC_CMD_MAX_CONTEXT_BYTES 512
#define KDF_KMAC_CMD_MAX_KEY_OUT_BYTES 512

// clang-format off

#define KDF_KMAC_MODE(_, value) \
    value(_, Kmac128) \
    value(_, Kmac256)
UJSON_SERDE_ENUM(CryptotestKdfKmacMode, cryptotest_kdf_kmac_mode_t, KDF_KMAC_MODE);

#define KDF_KMAC_INPUT(field, string, bytes) \
    bytes(key_in, KDF_KMAC_CMD_MAX_KEY_IN_BYTES, key_in_len) \
    field(key_in_len, size_t) \
    bytes(label, KDF_KMAC_CMD_MAX_LABEL_BYTES, label_len) \
    field(label_len, size_t) \
    bytes(context, KDF_KMAC_CMD_MAX_CONTEXT_BYTES, context_len) \
    field(context_len, size_t) \
    field(key_out_len, size_t)
UJSON_SERDE_STRUCT(CryptotestKdfKmacInput, cryptotest_kdf_kmac_input_t, KDF_KMAC_INPUT);

#define KDF_KMAC_OUTPUT(field, string, bytes) \
    bytes(key_out, KDF_KMAC_CMD_MAX_KEY_OUT_BYTES, key_out_len) \
    field(key_out_len, size_t)
UJSON_SERDE_STRUCT(CryptotestKdfKmacOutput, cryptotest_kdf_kmac_output_t, KDF_KMAC_OUTPUT);

#undef MODULE_ID

// clang-format on

#ifdef __cplusplus
}
#endif
#endif  // OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_JSON_KDF_KMAC_COMMANDS_H_
