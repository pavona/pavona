// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_TESTS_PENETRATIONTESTS_JSON_CRYPTOLIB_SCA_ASYM_COMMANDS_RSA_H_
#define OPENTITAN_SW_DEVICE_TESTS_PENETRATIONTESTS_JSON_CRYPTOLIB_SCA_ASYM_COMMANDS_RSA_H_
#include "sw/device/lib/ujson/ujson_derive.h"
#ifdef __cplusplus
extern "C" {
#endif

#define RSA_CMD_MAX_MESSAGE_BYTES 512
#define RSA_CMD_MAX_N_BYTES 512
#define RSA_CMD_MAX_COFACTOR_BYTES 256
#define RSA_CMD_MAX_SIGNATURE_BYTES 512

// clang-format off

#define CRYPTOLIBSCAASYM_RSA_DEC_IN(field, string) \
    field(data, uint8_t, RSA_CMD_MAX_MESSAGE_BYTES) \
    field(data_len, size_t) \
    field(mode, size_t) \
    field(p, uint8_t, RSA_CMD_MAX_COFACTOR_BYTES) \
    field(q, uint8_t, RSA_CMD_MAX_COFACTOR_BYTES) \
    field(e, uint32_t) \
    field(n, uint8_t, RSA_CMD_MAX_N_BYTES) \
    field(d_p, uint8_t, RSA_CMD_MAX_COFACTOR_BYTES) \
    field(d_q, uint8_t, RSA_CMD_MAX_COFACTOR_BYTES) \
    field(i_q, uint8_t, RSA_CMD_MAX_COFACTOR_BYTES) \
    field(n_len, size_t) \
    field(hashing, size_t) \
    field(padding, size_t) \
    field(cfg, size_t) \
    field(trigger, size_t)
UJSON_SERDE_STRUCT(CryptoLibScaAsymRsaDecIn, cryptolib_sca_asym_rsa_dec_in_t, CRYPTOLIBSCAASYM_RSA_DEC_IN);

#define CRYPTOLIBSCAASYM_RSA_DEC_OUT(field, string) \
    field(p, uint8_t, RSA_CMD_MAX_COFACTOR_BYTES) \
    field(q, uint8_t, RSA_CMD_MAX_COFACTOR_BYTES) \
    field(n, uint8_t, RSA_CMD_MAX_N_BYTES) \
    field(d_p, uint8_t, RSA_CMD_MAX_COFACTOR_BYTES) \
    field(d_q, uint8_t, RSA_CMD_MAX_COFACTOR_BYTES) \
    field(i_q, uint8_t, RSA_CMD_MAX_COFACTOR_BYTES) \
    field(n_len, size_t) \
    field(data, uint8_t, RSA_CMD_MAX_MESSAGE_BYTES) \
    field(data_len, size_t) \
    field(status, size_t) \
    field(cfg, size_t)
UJSON_SERDE_STRUCT(CryptoLibScaAsymRsaDecOut, cryptolib_sca_asym_rsa_dec_out_t, CRYPTOLIBSCAASYM_RSA_DEC_OUT);

#define CRYPTOLIBSCAASYM_RSA_SIGN_IN(field, string) \
    field(data, uint8_t, RSA_CMD_MAX_MESSAGE_BYTES) \
    field(data_len, size_t) \
    field(p, uint8_t, RSA_CMD_MAX_COFACTOR_BYTES) \
    field(q, uint8_t, RSA_CMD_MAX_COFACTOR_BYTES) \
    field(e, uint32_t) \
    field(n, uint8_t, RSA_CMD_MAX_N_BYTES) \
    field(d_p, uint8_t, RSA_CMD_MAX_COFACTOR_BYTES) \
    field(d_q, uint8_t, RSA_CMD_MAX_COFACTOR_BYTES) \
    field(i_q, uint8_t, RSA_CMD_MAX_COFACTOR_BYTES) \
    field(n_len, size_t) \
    field(hashing, size_t) \
    field(padding, size_t) \
    field(cfg, size_t) \
    field(num_iterations, size_t) \
    field(trigger, size_t)
UJSON_SERDE_STRUCT(CryptoLibScaAsymRsaSignIn, cryptolib_sca_asym_rsa_sign_in_t, CRYPTOLIBSCAASYM_RSA_SIGN_IN);

#define CRYPTOLIBSCAASYM_RSA_SIGN_OUT(field, string) \
    field(p, uint8_t, RSA_CMD_MAX_COFACTOR_BYTES) \
    field(q, uint8_t, RSA_CMD_MAX_COFACTOR_BYTES) \
    field(n, uint8_t, RSA_CMD_MAX_N_BYTES) \
    field(d_p, uint8_t, RSA_CMD_MAX_COFACTOR_BYTES) \
    field(d_q, uint8_t, RSA_CMD_MAX_COFACTOR_BYTES) \
    field(i_q, uint8_t, RSA_CMD_MAX_COFACTOR_BYTES) \
    field(n_len, size_t) \
    field(sig, uint8_t, RSA_CMD_MAX_SIGNATURE_BYTES) \
    field(sig_len, size_t) \
    field(status, size_t) \
    field(cfg, size_t)
UJSON_SERDE_STRUCT(CryptoLibScaAsymRsaSignOut, cryptolib_sca_asym_rsa_sign_out_t, CRYPTOLIBSCAASYM_RSA_SIGN_OUT);

#define CRYPTOLIBSCAASYM_PRIME_IN(field, string) \
    field(e, uint32_t) \
    field(cfg, size_t) \
    field(trigger, size_t)
UJSON_SERDE_STRUCT(CryptoLibScaAsymPrimeIn, cryptolib_sca_asym_prime_in_t, CRYPTOLIBSCAASYM_PRIME_IN);

#define CRYPTOLIBSCAASYM_PRIME_OUT(field, string) \
    field(prime, uint8_t, RSA_CMD_MAX_N_BYTES) \
    field(prime_len, size_t) \
    field(status, size_t) \
    field(cfg, size_t)
UJSON_SERDE_STRUCT(CryptoLibScaAsymPrimeOut, cryptolib_sca_asym_prime_out_t, CRYPTOLIBSCAASYM_PRIME_OUT);

// clang-format on

#ifdef __cplusplus
}
#endif
#endif  // OPENTITAN_SW_DEVICE_TESTS_PENETRATIONTESTS_JSON_CRYPTOLIB_SCA_ASYM_COMMANDS_RSA_H_
