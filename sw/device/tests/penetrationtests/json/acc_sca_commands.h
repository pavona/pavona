// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_TESTS_PENETRATIONTESTS_JSON_ACC_SCA_COMMANDS_H_
#define OPENTITAN_SW_DEVICE_TESTS_PENETRATIONTESTS_JSON_ACC_SCA_COMMANDS_H_
#include "sw/device/lib/ujson/ujson_derive.h"
#ifdef __cplusplus
extern "C" {
#endif

#define ACCSCA_CMD_MAX_BATCH_DIGEST_BYTES 40
#define ACCSCA_CMD_MAX_SEED_BYTES 40

// clang-format off

// ACC SCA arguments

#define ACCSCA_SUBCOMMAND(_, value) \
    value(_, Ecc256EcdsaKeygenFvsrKeyBatch) \
    value(_, Ecc256EcdsaKeygenFvsrSeedBatch) \
    value(_, Ecc256EnMasks) \
    value(_, Ecc256SetC) \
    value(_, Ecc256SetSeed) \
    value(_, EcdsaP256Sign) \
    value(_, EcdsaP256SignBatch) \
    value(_, EcdsaP256SignFvsrBatch) \
    value(_, Init) \
    value(_, InitKeyMgr) \
    value(_, InsnCarryFlag) \
    value(_, CombiOps) \
    value(_, KeySideloadFvsr) \
    value(_, Rsa512Decrypt)
C_ONLY(UJSON_SERDE_ENUM(AccScaSubcommand, acc_sca_subcommand_t, ACCSCA_SUBCOMMAND));
RUST_ONLY(UJSON_SERDE_ENUM(AccScaSubcommand, acc_sca_subcommand_t, ACCSCA_SUBCOMMAND, RUST_DEFAULT_DERIVE, strum::EnumString));

#define ACC_SCA_EN_MASKS(field, string) \
    field(en_masks, bool)
UJSON_SERDE_STRUCT(PenetrationtestAccScaEnMasks, penetrationtest_acc_sca_en_masks_t, ACC_SCA_EN_MASKS);

#define ACC_SCA_NUM_TRACES(field, string) \
    field(num_traces, uint32_t)
UJSON_SERDE_STRUCT(PenetrationtestAccScaNumTraces, penetrationtest_acc_sca_num_traces_t, ACC_SCA_NUM_TRACES);

#define ACC_SCA_BATCH_DIGEST(field, string) \
    field(batch_digest, uint8_t, ACCSCA_CMD_MAX_BATCH_DIGEST_BYTES)
UJSON_SERDE_STRUCT(PenetrationtestAccScaBatchDigest, penetrationtest_acc_sca_batch_digest_t, ACC_SCA_BATCH_DIGEST);

#define ACC_SCA_SEED(field, string) \
    field(seed, uint8_t, ACCSCA_CMD_MAX_SEED_BYTES)
UJSON_SERDE_STRUCT(PenetrationtestAccScaSeed, penetrationtest_acc_sca_seed_t, ACC_SCA_SEED);

#define ACC_SCA_CONSTANT(field, string) \
    field(constant, uint8_t, ACCSCA_CMD_MAX_SEED_BYTES)
UJSON_SERDE_STRUCT(PenetrationtestAccScaConstant, penetrationtest_acc_sca_constant_t, ACC_SCA_CONSTANT);

#define ACC_SCA_KEY(field, string) \
    field(shares, uint32_t, 4) \
    field(keys, uint32_t, 2)
UJSON_SERDE_STRUCT(PenetrationtestAccScaKey, penetrationtest_acc_sca_key_t, ACC_SCA_KEY);

#define ACC_SCA_FIXED_SEED(field, string) \
    field(fixed_seed, uint32_t)
UJSON_SERDE_STRUCT(PenetrationtestAccScaFixedKey, penetrationtest_acc_sca_fixed_seed_t, ACC_SCA_FIXED_SEED);

#define ACC_SCA_RSA512_DEC(field, string) \
    field(modu, uint8_t, 64) \
    field(exp, uint8_t, 64) \
    field(msg, uint8_t, 64)
UJSON_SERDE_STRUCT(PenetrationtestAccScaRsa512Dec, penetrationtest_acc_sca_rsa512_dec_t, ACC_SCA_RSA512_DEC);

#define ACC_SCA_RSA512_DEC_OUT(field, string) \
    field(out, uint8_t, 64)
UJSON_SERDE_STRUCT(PenetrationtestAccScaRsa512DecOut, penetrationtest_acc_sca_rsa512_dec_out_t, ACC_SCA_RSA512_DEC_OUT);

#define ACC_SCA_BIG_NUM(field, string) \
    field(big_num, uint32_t, 8)
UJSON_SERDE_STRUCT(PenetrationtestAccScaBigNum, penetrationtest_acc_sca_big_num_t, ACC_SCA_BIG_NUM);

#define ACC_SCA_ECDSA_P256_SIGN(field, string) \
    field(msg, uint32_t, 8) \
    field(d0, uint32_t, 10) \
    field(k0, uint32_t, 10)
UJSON_SERDE_STRUCT(PenetrationtestAccScaEcdsaP256Sign, penetrationtest_acc_sca_ecdsa_p256_sign_t, ACC_SCA_ECDSA_P256_SIGN);

#define ACC_SCA_ECDSA_P256_SIGNATURE(field, string) \
    field(r, uint8_t, 32) \
    field(s, uint8_t, 32)
UJSON_SERDE_STRUCT(PenetrationtestAccScaEcdsaP256Signature, penetrationtest_acc_sca_ecdsa_p256_signature_t, ACC_SCA_ECDSA_P256_SIGNATURE);

#define ACC_SCA_TEST_BATCH_OPS(field, string) \
    field(num_iterations, uint32_t) \
    field(fixed_data1, uint32_t) \
    field(fixed_data2, uint32_t) \
    field(print_flag, bool) \
    field(trigger, uint32_t)
UJSON_SERDE_STRUCT(AccScaTestBatchOps, acc_sca_test_batch_ops_t, ACC_SCA_TEST_BATCH_OPS);

#define ACC_SCA_OPS_RESULT(field, string) \
    field(result1, uint32_t, 8) \
    field(result2, uint32_t, 8) \
    field(result3, uint32_t, 8) \
    field(result4, uint32_t, 8) \
    field(result5, uint32_t, 8) \
    field(result6, uint32_t, 8) \
    field(result7, uint32_t, 8) \
    field(result8, uint32_t)
UJSON_SERDE_STRUCT(AccScaOpsResult, acc_sca_ops_result_t, ACC_SCA_OPS_RESULT);

#define ACC_SCA_EMPTY(field, string) \
    field(success, bool)
UJSON_SERDE_STRUCT(AccScaEmpty, acc_sca_empty_t, ACC_SCA_EMPTY);

// clang-format on

#ifdef __cplusplus
}
#endif
#endif  // OPENTITAN_SW_DEVICE_TESTS_PENETRATIONTESTS_JSON_ACC_SCA_COMMANDS_H_
