// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_JSON_KDF_HMAC_COMMANDS_H_
#define OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_JSON_KDF_HMAC_COMMANDS_H_
#include "sw/device/lib/ujson/ujson_derive.h"
#ifdef __cplusplus
extern "C" {
#endif

#define MODULE_ID MAKE_MODULE_ID('j', 'k', 'd')

#define KDF_HMAC_CMD_MAX_KEY_IN_BYTES 64
#define KDF_HMAC_CMD_MAX_FIXED_DATA_BYTES 64
#define KDF_HMAC_CMD_MAX_KEY_OUT_BYTES 128

// clang-format off

#define KDF_HMAC_MODE(_, value) \
    value(_, Counter) \
    value(_, Feedback)
UJSON_SERDE_ENUM(CryptotestKdfHmacMode, cryptotest_kdf_hmac_mode_t, KDF_HMAC_MODE);

#define KDF_HMAC_HASH_ALG(_, value) \
    value(_, Sha256) \
    value(_, Sha384) \
    value(_, Sha512)
UJSON_SERDE_ENUM(CryptotestKdfHmacHashAlg, cryptotest_kdf_hmac_hash_alg_t, KDF_HMAC_HASH_ALG);

#define KDF_HMAC_INPUT(field, string, bytes) \
    bytes(key_in, KDF_HMAC_CMD_MAX_KEY_IN_BYTES, key_in_len) \
    field(key_in_len, size_t) \
    bytes(fixed_data, KDF_HMAC_CMD_MAX_FIXED_DATA_BYTES, fixed_data_len) \
    field(fixed_data_len, size_t) \
    field(key_out_len, size_t)
UJSON_SERDE_STRUCT(CryptotestKdfHmacInput, cryptotest_kdf_hmac_input_t, KDF_HMAC_INPUT);

#define KDF_HMAC_OUTPUT(field, string, bytes) \
    bytes(key_out, KDF_HMAC_CMD_MAX_KEY_OUT_BYTES, key_out_len) \
    field(key_out_len, size_t)
UJSON_SERDE_STRUCT(CryptotestKdfHmacOutput, cryptotest_kdf_hmac_output_t, KDF_HMAC_OUTPUT);

#undef MODULE_ID

// clang-format on

#ifdef __cplusplus
}
#endif
#endif  // OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_JSON_KDF_HMAC_COMMANDS_H_
