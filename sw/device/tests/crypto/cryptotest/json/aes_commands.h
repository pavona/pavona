// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_JSON_AES_COMMANDS_H_
#define OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_JSON_AES_COMMANDS_H_
#include "sw/device/lib/ujson/ujson_derive.h"
#ifdef __cplusplus
extern "C" {
#endif

#define MODULE_ID MAKE_MODULE_ID('j', 'a', 'e')

#define AES_CMD_MAX_MSG_BYTES 16000
#define AES_CMD_MAX_KEY_BYTES 32           // 256 / 8
#define AES_CMD_MAX_MCT_KEYS_BYTES 3200    // 100 * 256 / 8
#define AES_CMD_MAX_MCT_BLOCKS_BYTES 1600  // 100 * 128 / 8

// clang-format off

#define AES_SUBCOMMAND(_, value) \
    value(_, AesBlock) \
    value(_, AesMct) \
    value(_, AesGcm)
UJSON_SERDE_ENUM(AesSubcommand, aes_subcommand_t, AES_SUBCOMMAND);

// AES arguments
#define AES_MODE(_, value) \
    value(_, Ecb) \
    value(_, Cbc) \
    value(_, Cfb) \
    value(_, Ofb) \
    value(_, Ctr)
UJSON_SERDE_ENUM(CryptotestAesMode, cryptotest_aes_mode_t, AES_MODE);

#define AES_OPERATION(_, value) \
    value(_, Encrypt) \
    value(_, Decrypt)
UJSON_SERDE_ENUM(CryptotestAesOperation, cryptotest_aes_operation_t, AES_OPERATION);

#define AES_PADDING(_, value) \
    value(_, Pkcs7) \
    value(_, Iso9797M2) \
    value(_, Null)
UJSON_SERDE_ENUM(CryptotestAesPadding, cryptotest_aes_padding_t, AES_PADDING);

#define AES_DATA(field, string, bytes) \
    field(key, uint8_t, AES_CMD_MAX_KEY_BYTES) \
    field(key_length, size_t) \
    field(iv, uint8_t, 16) \
    bytes(input, AES_CMD_MAX_MSG_BYTES, input_len) \
    field(input_len, size_t)
UJSON_SERDE_STRUCT(CryptotestAesData, cryptotest_aes_data_t, AES_DATA);

#define AES_OUTPUT(field, string, bytes) \
    bytes(output, AES_CMD_MAX_MSG_BYTES, output_len) \
    field(output_len, size_t)
UJSON_SERDE_STRUCT(CryptotestAesOutput, cryptotest_aes_output_t, AES_OUTPUT);

#define AES_MCT_OUTPUT(field, string, bytes) \
    bytes(keys, AES_CMD_MAX_MCT_KEYS_BYTES, keys_len) \
    field(keys_len, size_t) \
    bytes(ivs, AES_CMD_MAX_MCT_BLOCKS_BYTES, ivs_len) \
    field(ivs_len, size_t) \
    bytes(inputs, AES_CMD_MAX_MCT_BLOCKS_BYTES, inputs_len) \
    field(inputs_len, size_t) \
    bytes(outputs, AES_CMD_MAX_MCT_BLOCKS_BYTES, outputs_len) \
    field(outputs_len, size_t)
UJSON_SERDE_STRUCT(CryptotestAesMctOutput, cryptotest_aes_mct_output_t, AES_MCT_OUTPUT);

#undef MODULE_ID

// clang-format on

#ifdef __cplusplus
}
#endif
#endif  // OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_JSON_AES_COMMANDS_H_
