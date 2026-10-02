// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_JSON_DRBG_COMMANDS_H_
#define OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_JSON_DRBG_COMMANDS_H_
#include "sw/device/lib/ujson/ujson_derive.h"
#ifdef __cplusplus
extern "C" {
#endif

#define DRBG_CMD_MAX_ENTROPY_BYTES 48
#define DRBG_CMD_MAX_PERSONALIZATION_STRING_BYTES 48
#define DRBG_CMD_MAX_ADDITIONAL_INPUT_BYTES 48
#define DRBG_CMD_MAX_OUTPUT_BYTES 64

// clang-format off

#define DRBG_INPUT(field, string, bytes) \
    bytes(entropy, DRBG_CMD_MAX_ENTROPY_BYTES, entropy_len) \
    field(entropy_len, size_t) \
    bytes(personalization_string, DRBG_CMD_MAX_PERSONALIZATION_STRING_BYTES, personalization_string_len) \
    field(personalization_string_len, size_t) \
    field(reseed, uint8_t) \
    bytes(reseed_entropy, DRBG_CMD_MAX_ENTROPY_BYTES, reseed_entropy_len) \
    field(reseed_entropy_len, size_t) \
    bytes(reseed_additional_input, DRBG_CMD_MAX_ADDITIONAL_INPUT_BYTES, reseed_additional_input_len) \
    field(reseed_additional_input_len, size_t) \
    bytes(additional_input_1, DRBG_CMD_MAX_ADDITIONAL_INPUT_BYTES, additional_input_1_len) \
    field(additional_input_1_len, size_t) \
    bytes(additional_input_2, DRBG_CMD_MAX_ADDITIONAL_INPUT_BYTES, additional_input_2_len) \
    field(additional_input_2_len, size_t) \
    field(output_len, size_t)
UJSON_SERDE_STRUCT(CryptotestDrbgInput, cryptotest_drbg_input_t, DRBG_INPUT);

#define DRBG_OUTPUT(field, string, bytes) \
    bytes(output, DRBG_CMD_MAX_OUTPUT_BYTES, output_len) \
    field(output_len, size_t)
UJSON_SERDE_STRUCT(CryptotestDrbgOutput, cryptotest_drbg_output_t, DRBG_OUTPUT);

// clang-format on

#ifdef __cplusplus
}
#endif
#endif  // OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_JSON_DRBG_COMMANDS_H_
