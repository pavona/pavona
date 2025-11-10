// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_TESTS_PENETRATIONTESTS_JSON_CRYPTOLIB_SCA_ASYM_COMMANDS_H_
#define OPENTITAN_SW_DEVICE_TESTS_PENETRATIONTESTS_JSON_CRYPTOLIB_SCA_ASYM_COMMANDS_H_
#include "cryptolib_sca_asym_commands_ecc.h"
#include "cryptolib_sca_asym_commands_rsa.h"
#include "sw/device/lib/ujson/ujson_derive.h"
#ifdef __cplusplus
extern "C" {
#endif

#define MODULE_ID MAKE_MODULE_ID('j', 's', 'a')

// clang-format off

#define CRYPTOLIBSCAASYM_SUBCOMMAND(_, value) \
    value(_, RsaDec) \
    value(_, RsaSign) \
    value(_, Prime) \
    value(_, P256BaseMulFvsr) \
    value(_, P256BaseMulDaisy) \
    value(_, P256PointMul) \
    value(_, P256Ecdh) \
    value(_, P256Sign) \
    value(_, P384BaseMulFvsr) \
    value(_, P384BaseMulDaisy) \
    value(_, P384PointMul) \
    value(_, P384Ecdh) \
    value(_, P384Sign) \
    value(_, Secp256k1BaseMulFvsr) \
    value(_, Secp256k1BaseMulDaisy) \
    value(_, Secp256k1PointMul) \
    value(_, Secp256k1Ecdh) \
    value(_, Secp256k1Sign) \
    value(_, X25519BaseMulFvsr) \
    value(_, X25519BaseMulDaisy) \
    value(_, X25519PointMul) \
    value(_, X25519Ecdh) \
    value(_, Ed25519BaseMulFvsr) \
    value(_, Ed25519BaseMulDaisy) \
    value(_, Ed25519Sign) \
    value(_, Init)
C_ONLY(UJSON_SERDE_ENUM(CryptoLibScaAsymSubcommand, cryptolib_sca_asym_subcommand_t, CRYPTOLIBSCAASYM_SUBCOMMAND));
RUST_ONLY(UJSON_SERDE_ENUM(CryptoLibScaAsymSubcommand, cryptolib_sca_asym_subcommand_t, CRYPTOLIBSCAASYM_SUBCOMMAND, RUST_DEFAULT_DERIVE, strum::EnumString));

#undef MODULE_ID

// clang-format on

#ifdef __cplusplus
}
#endif
#endif  // OPENTITAN_SW_DEVICE_TESTS_PENETRATIONTESTS_JSON_CRYPTOLIB_SCA_ASYM_COMMANDS_H_
