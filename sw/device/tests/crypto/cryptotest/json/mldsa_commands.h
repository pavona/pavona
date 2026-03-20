// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_JSON_MLDSA_COMMANDS_H_
#define OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_JSON_MLDSA_COMMANDS_H_
#include "sw/device/lib/ujson/ujson_derive.h"
#ifdef __cplusplus
extern "C" {
#endif

#define MODULE_ID MAKE_MODULE_ID('j', 'd', 's')

// Buffer sizes based on ML-DSA-87 (largest parameter set),
// oversized where needed for invalid test vectors.
#define MLDSA_CMD_MAX_MSG_BYTES 8448  // ML-DSA-87: 8192
#define MLDSA_CMD_MAX_CTX_BYTES 256   // FIPS 204: 255
#define MLDSA_CMD_MAX_SK_BYTES 4928   // ML-DSA-87: 4896
#define MLDSA_CMD_MAX_PK_BYTES 2624   // ML-DSA-87: 2592
#define MLDSA_CMD_MAX_SIG_BYTES 4672  // ML-DSA-87: 4627
#define MLDSA_CMD_MAX_SEED_BYTES 64   // all parameter sets: 32
#define MLDSA_CMD_MAX_RND_BYTES 32    // all parameter sets
#define MLDSA_CMD_HASH_BYTES 32

// clang-format off

#define MLDSA_SUBCOMMAND(_, value) \
    value(_, MldsaKeygen) \
    value(_, MldsaKeygenSign) \
    value(_, MldsaSiggen) \
    value(_, MldsaSigver)
UJSON_SERDE_ENUM(MldsaSubcommand, mldsa_subcommand_t, MLDSA_SUBCOMMAND);

// Keygen: input seed only.
#define MLDSA_KEYGEN_DATA(field, string) \
    field(parameter_set, uint32_t) \
    field(seed, uint8_t, MLDSA_CMD_MAX_SEED_BYTES) \
    field(seed_len, size_t)
UJSON_SERDE_STRUCT(CryptotestMldsaKeygenData, cryptotest_mldsa_keygen_data_t, MLDSA_KEYGEN_DATA);

// KeygenSign: keygen from seed then sign.
#define MLDSA_KEYGEN_SIGN_DATA(field, string) \
    field(parameter_set, uint32_t) \
    field(seed, uint8_t, MLDSA_CMD_MAX_SEED_BYTES) \
    field(seed_len, size_t) \
    field(message, uint8_t, MLDSA_CMD_MAX_MSG_BYTES) \
    field(message_len, size_t) \
    field(context, uint8_t, MLDSA_CMD_MAX_CTX_BYTES) \
    field(context_len, size_t) \
    field(rnd, uint8_t, MLDSA_CMD_MAX_RND_BYTES) \
    field(rnd_len, size_t)
UJSON_SERDE_STRUCT(CryptotestMldsaKeygenSignData, cryptotest_mldsa_keygen_sign_data_t, MLDSA_KEYGEN_SIGN_DATA);

// Siggen: input secret key + message + context + randomness.
#define MLDSA_SIGGEN_DATA(field, string) \
    field(parameter_set, uint32_t) \
    field(sk, uint8_t, MLDSA_CMD_MAX_SK_BYTES) \
    field(sk_len, size_t) \
    field(message, uint8_t, MLDSA_CMD_MAX_MSG_BYTES) \
    field(message_len, size_t) \
    field(context, uint8_t, MLDSA_CMD_MAX_CTX_BYTES) \
    field(context_len, size_t) \
    field(rnd, uint8_t, MLDSA_CMD_MAX_RND_BYTES) \
    field(rnd_len, size_t)
UJSON_SERDE_STRUCT(CryptotestMldsaSiggenData, cryptotest_mldsa_siggen_data_t, MLDSA_SIGGEN_DATA);

// Sigver: input public key + message + context + signature.
#define MLDSA_SIGVER_DATA(field, string) \
    field(parameter_set, uint32_t) \
    field(pk, uint8_t, MLDSA_CMD_MAX_PK_BYTES) \
    field(pk_len, size_t) \
    field(message, uint8_t, MLDSA_CMD_MAX_MSG_BYTES) \
    field(message_len, size_t) \
    field(context, uint8_t, MLDSA_CMD_MAX_CTX_BYTES) \
    field(context_len, size_t) \
    field(signature, uint8_t, MLDSA_CMD_MAX_SIG_BYTES) \
    field(signature_len, size_t)
UJSON_SERDE_STRUCT(CryptotestMldsaSigverData, cryptotest_mldsa_sigver_data_t, MLDSA_SIGVER_DATA);

// Hash-based output: firmware returns SHA3-256 of outputs + success.
#define MLDSA_OUTPUT(field, string) \
    field(hash, uint8_t, MLDSA_CMD_HASH_BYTES) \
    field(success, bool)
UJSON_SERDE_STRUCT(CryptotestMldsaOutput, cryptotest_mldsa_output_t, MLDSA_OUTPUT);

#undef MODULE_ID

// clang-format on

#ifdef __cplusplus
}
#endif
#endif  // OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_JSON_MLDSA_COMMANDS_H_
