// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_JSON_HKDF_COMMANDS_H_
#define OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_JSON_HKDF_COMMANDS_H_
#include "sw/device/lib/ujson/ujson_derive.h"
#ifdef __cplusplus
extern "C" {
#endif

#define MODULE_ID MAKE_MODULE_ID('j', 'h', 'k')

#define HKDF_CMD_MAX_IKM_BYTES 8192
#define HKDF_CMD_MAX_SALT_BYTES 512
// Two party IDs and ephemeral data as long as the IKM, followed by L.
#define HKDF_CMD_MAX_INFO_BYTES 16420
#define HKDF_CMD_MAX_OKM_BYTES 128

// clang-format off

#define HKDF_HASH_ALG(_, value) \
    value(_, Sha256) \
    value(_, Sha384) \
    value(_, Sha512)
UJSON_SERDE_ENUM(CryptotestHkdfHashAlg, cryptotest_hkdf_hash_alg_t, HKDF_HASH_ALG);

#define HKDF_INPUT(field, string, bytes) \
    bytes(ikm, HKDF_CMD_MAX_IKM_BYTES, ikm_len) \
    field(ikm_len, size_t) \
    bytes(salt, HKDF_CMD_MAX_SALT_BYTES, salt_len) \
    field(salt_len, size_t) \
    bytes(info, HKDF_CMD_MAX_INFO_BYTES, info_len) \
    field(info_len, size_t) \
    field(okm_len, size_t)
UJSON_SERDE_STRUCT(CryptotestHkdfInput, cryptotest_hkdf_input_t, HKDF_INPUT);

#define HKDF_OUTPUT(field, string, bytes) \
    bytes(okm, HKDF_CMD_MAX_OKM_BYTES, okm_len) \
    field(okm_len, size_t)
UJSON_SERDE_STRUCT(CryptotestHkdfOutput, cryptotest_hkdf_output_t, HKDF_OUTPUT);

#undef MODULE_ID

// clang-format on

#ifdef __cplusplus
}
#endif
#endif  // OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_JSON_HKDF_COMMANDS_H_
