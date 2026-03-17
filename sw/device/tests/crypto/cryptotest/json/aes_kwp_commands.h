// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_JSON_AES_KWP_COMMANDS_H_
#define OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_JSON_AES_KWP_COMMANDS_H_
#include "sw/device/lib/ujson/ujson_derive.h"
#ifdef __cplusplus
extern "C" {
#endif

#define MODULE_ID MAKE_MODULE_ID('j', 'c', 'e')

#define AES_KWP_CMD_MAX_MSG_BYTES 520
#define AES_KWP_CMD_MAX_KEY_BYTES 32  // 256 / 8

// clang-format off

#define AES_KWP_SUBCOMMAND(_, value) \
    value(_, AesKwpOp)
UJSON_SERDE_ENUM(AesKwpSubcommand, aes_kwp_subcommand_t, AES_KWP_SUBCOMMAND);

#define AES_KWP_OPERATION(_, value) \
    value(_, Wrap) \
    value(_, Unwrap)
UJSON_SERDE_ENUM(CryptotestAesKwpOperation, cryptotest_aes_kwp_operation_t, AES_KWP_OPERATION);

#define AES_KWP_DATA(field, string) \
    field(key, uint8_t, AES_KWP_CMD_MAX_KEY_BYTES) \
    field(key_length, size_t) \
    field(input, uint8_t, AES_KWP_CMD_MAX_MSG_BYTES) \
    field(input_length, size_t)
UJSON_SERDE_STRUCT(CryptotestAesKwpData, cryptotest_aes_kwp_data_t, AES_KWP_DATA);

#define AES_KWP_OUTPUT(field, string) \
    field(output, uint8_t, AES_KWP_CMD_MAX_MSG_BYTES) \
    field(output_len, size_t) \
    field(success, bool)
UJSON_SERDE_STRUCT(CryptotestAesKwpOutput, cryptotest_aes_kwp_output_t, AES_KWP_OUTPUT);

#undef MODULE_ID

// clang-format on

#ifdef __cplusplus
}
#endif
#endif  // OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_JSON_AES_KWP_COMMANDS_H_
