// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_JSON_MLKEM_COMMANDS_H_
#define OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_JSON_MLKEM_COMMANDS_H_
#include "sw/device/lib/ujson/ujson_derive.h"
#ifdef __cplusplus
extern "C" {
#endif

#define MODULE_ID MAKE_MODULE_ID('j', 'd', 'e')

// Buffer sizes based on ML-KEM-1024 (largest parameter set),
// oversized where needed for invalid test vectors.
#define MLKEM_CMD_MAX_EK_BYTES 2048   // ML-KEM-1024: 1568
#define MLKEM_CMD_MAX_DK_BYTES 3200   // ML-KEM-1024: 3168
#define MLKEM_CMD_MAX_CT_BYTES 1600   // ML-KEM-1024: 1568
#define MLKEM_CMD_MAX_SEED_BYTES 128  // ML-KEM-1024: 64
#define MLKEM_CMD_SS_BYTES 32         // all parameter sets

// clang-format off

#define MLKEM_SUBCOMMAND(_, value) \
    value(_, MlkemKeygenDecaps) \
    value(_, MlkemKeygen) \
    value(_, MlkemEncaps) \
    value(_, MlkemDecaps)
UJSON_SERDE_ENUM(MlkemSubcommand, mlkem_subcommand_t, MLKEM_SUBCOMMAND);

// Keygen: input seed only.
#define MLKEM_KEYGEN_DATA(field, string) \
    field(parameter_set, uint32_t) \
    field(seed, uint8_t, MLKEM_CMD_MAX_SEED_BYTES) \
    field(seed_len, size_t)
UJSON_SERDE_STRUCT(CryptotestMlkemKeygenData, cryptotest_mlkem_keygen_data_t, MLKEM_KEYGEN_DATA);

// KeygenDecaps: input seed + ciphertext.
#define MLKEM_KEYGEN_DECAPS_DATA(field, string) \
    field(parameter_set, uint32_t) \
    field(seed, uint8_t, MLKEM_CMD_MAX_SEED_BYTES) \
    field(seed_len, size_t) \
    field(c, uint8_t, MLKEM_CMD_MAX_CT_BYTES) \
    field(c_len, size_t)
UJSON_SERDE_STRUCT(CryptotestMlkemKeygenDecapsData, cryptotest_mlkem_keygen_decaps_data_t, MLKEM_KEYGEN_DECAPS_DATA);

// Encaps: input randomness (via seed) + encapsulation key.
#define MLKEM_ENCAPS_DATA(field, string) \
    field(parameter_set, uint32_t) \
    field(seed, uint8_t, MLKEM_CMD_MAX_SEED_BYTES) \
    field(seed_len, size_t) \
    field(ek, uint8_t, MLKEM_CMD_MAX_EK_BYTES) \
    field(ek_len, size_t)
UJSON_SERDE_STRUCT(CryptotestMlkemEncapsData, cryptotest_mlkem_encaps_data_t, MLKEM_ENCAPS_DATA);

// Decaps: input decapsulation key + ciphertext.
#define MLKEM_DECAPS_DATA(field, string) \
    field(parameter_set, uint32_t) \
    field(dk, uint8_t, MLKEM_CMD_MAX_DK_BYTES) \
    field(dk_len, size_t) \
    field(c, uint8_t, MLKEM_CMD_MAX_CT_BYTES) \
    field(c_len, size_t)
UJSON_SERDE_STRUCT(CryptotestMlkemDecapsData, cryptotest_mlkem_decaps_data_t, MLKEM_DECAPS_DATA);

// KeygenDecaps output: derived encapsulation key and decapsulated secret.
#define MLKEM_KEYGEN_DECAPS_OUTPUT(field, string) \
    field(ek, uint8_t, MLKEM_CMD_MAX_EK_BYTES) \
    field(ek_len, size_t) \
    field(k, uint8_t, MLKEM_CMD_SS_BYTES) \
    field(k_len, size_t) \
    field(success, bool)
UJSON_SERDE_STRUCT(CryptotestMlkemKeygenDecapsOutput, cryptotest_mlkem_keygen_decaps_output_t, MLKEM_KEYGEN_DECAPS_OUTPUT);

// Keygen output: the key pair in the standard FIPS 203 encoding.
#define MLKEM_KEYGEN_OUTPUT(field, string) \
    field(ek, uint8_t, MLKEM_CMD_MAX_EK_BYTES) \
    field(ek_len, size_t) \
    field(dk, uint8_t, MLKEM_CMD_MAX_DK_BYTES) \
    field(dk_len, size_t) \
    field(success, bool)
UJSON_SERDE_STRUCT(CryptotestMlkemKeygenOutput, cryptotest_mlkem_keygen_output_t, MLKEM_KEYGEN_OUTPUT);

// Encaps output: ciphertext and shared secret.
#define MLKEM_ENCAPS_OUTPUT(field, string) \
    field(c, uint8_t, MLKEM_CMD_MAX_CT_BYTES) \
    field(c_len, size_t) \
    field(k, uint8_t, MLKEM_CMD_SS_BYTES) \
    field(k_len, size_t) \
    field(success, bool)
UJSON_SERDE_STRUCT(CryptotestMlkemEncapsOutput, cryptotest_mlkem_encaps_output_t, MLKEM_ENCAPS_OUTPUT);

// Decaps output: shared secret.
#define MLKEM_DECAPS_OUTPUT(field, string) \
    field(k, uint8_t, MLKEM_CMD_SS_BYTES) \
    field(k_len, size_t) \
    field(success, bool)
UJSON_SERDE_STRUCT(CryptotestMlkemDecapsOutput, cryptotest_mlkem_decaps_output_t, MLKEM_DECAPS_OUTPUT);

#undef MODULE_ID

// clang-format on

#ifdef __cplusplus
}
#endif
#endif  // OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_JSON_MLKEM_COMMANDS_H_
