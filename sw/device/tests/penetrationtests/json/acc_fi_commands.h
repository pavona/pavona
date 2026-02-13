// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_TESTS_PENETRATIONTESTS_JSON_ACC_FI_COMMANDS_H_
#define OPENTITAN_SW_DEVICE_TESTS_PENETRATIONTESTS_JSON_ACC_FI_COMMANDS_H_
#include "sw/device/lib/ujson/ujson_derive.h"
#ifdef __cplusplus
extern "C" {
#endif

// clang-format off

#define ACCFI_SUBCOMMAND(_, value) \
    value(_, CharBeq) \
    value(_, CharBnRshi) \
    value(_, CharBnSel) \
    value(_, CharBnWsrr) \
    value(_, CharBne) \
    value(_, CharDmemAccess) \
    value(_, CharDmemWrite) \
    value(_, CharHardwareDmemOpLoop) \
    value(_, CharHardwareRegOpLoop) \
    value(_, CharJal) \
    value(_, CharLw) \
    value(_, CharMem) \
    value(_, CharRF) \
    value(_, CharUnrolledDmemOpLoop) \
    value(_, CharUnrolledRegOpLoop) \
    value(_, Init) \
    value(_, InitKeyMgr) \
    value(_, KeySideload)  \
    value(_, LoadIntegrity) \
    value(_, PC)
C_ONLY(UJSON_SERDE_ENUM(AccFiSubcommand, acc_fi_subcommand_t, ACCFI_SUBCOMMAND));
RUST_ONLY(UJSON_SERDE_ENUM(AccFiSubcommand, acc_fi_subcommand_t, ACCFI_SUBCOMMAND, RUST_DEFAULT_DERIVE, strum::EnumString));

#define ACCFI_LOOP_COUNTER_OUTPUT(field, string) \
    field(loop_counter, uint32_t) \
    field(err_acc, uint32_t) \
    field(err_ibx, uint32_t) \
    field(alerts, uint32_t, 3) \
    field(ast_alerts, uint32_t, 2)
UJSON_SERDE_STRUCT(AccFiLoopCounterOutput, acc_fi_loop_counter_t, ACCFI_LOOP_COUNTER_OUTPUT);

#define ACCFI_RESULT_OUTPUT(field, string) \
    field(result, uint32_t) \
    field(err_acc, uint32_t) \
    field(err_ibx, uint32_t) \
    field(alerts, uint32_t, 3) \
    field(ast_alerts, uint32_t, 2)
UJSON_SERDE_STRUCT(AccFiResultOutput, acc_fi_result_t, ACCFI_RESULT_OUTPUT);

#define ACCFI_KEY_OUTPUT(field, string) \
    field(res, uint32_t) \
    field(keys, uint32_t, 4) \
    field(err_acc, uint32_t) \
    field(err_ibx, uint32_t) \
    field(alerts, uint32_t, 3) \
    field(ast_alerts, uint32_t, 2)
UJSON_SERDE_STRUCT(AccFiKeyOutput, acc_fi_keys_t, ACCFI_KEY_OUTPUT);

#define ACCFI_MEM_CFG(field, string) \
    field(byte_offset, uint32_t) \
    field(num_words, uint32_t) \
    field(imem, bool) \
    field(dmem, bool)
UJSON_SERDE_STRUCT(AccFiMemCfg, acc_fi_mem_cfg_t, ACCFI_MEM_CFG);

#define ACCFI_MEM_OUTPUT(field, string) \
    field(res, uint32_t) \
    field(imem_data, uint32_t, 8) \
    field(imem_addr, uint32_t, 8) \
    field(dmem_data, uint32_t, 8) \
    field(dmem_addr, uint32_t, 8) \
    field(err_acc, uint32_t) \
    field(err_ibx, uint32_t) \
    field(alerts, uint32_t, 3) \
    field(ast_alerts, uint32_t, 2)
UJSON_SERDE_STRUCT(AccFiMemOutput, acc_fi_mem_t, ACCFI_MEM_OUTPUT);

#define ACCFI_DATA_OUTPUT(field, string) \
    field(res, uint32_t) \
    field(data, uint32_t, 256) \
    field(insn_cnt, uint32_t) \
    field(err_acc, uint32_t) \
    field(err_ibx, uint32_t) \
    field(alerts, uint32_t, 3) \
    field(ast_alerts, uint32_t, 2)
UJSON_SERDE_STRUCT(AccFiDataOutput, acc_fi_data_t, ACCFI_DATA_OUTPUT);

#define ACCFI_RF_CHAR_OUTPUT(field, string) \
    field(res, uint32_t) \
    field(faulty_gpr, uint32_t, 29) \
    field(faulty_wdr, uint32_t, 256) \
    field(err_acc, uint32_t) \
    field(err_ibx, uint32_t) \
    field(alerts, uint32_t, 3) \
    field(ast_alerts, uint32_t, 2)
UJSON_SERDE_STRUCT(AccFiRfCharOutput, acc_fi_rf_char_t, ACCFI_RF_CHAR_OUTPUT);

#define ACCFI_RESULT_CNT_OUTPUT(field, string) \
    field(result, uint32_t) \
    field(insn_cnt, uint32_t) \
    field(err_acc, uint32_t) \
    field(err_ibx, uint32_t) \
    field(alerts, uint32_t, 3) \
    field(ast_alerts, uint32_t, 2)
UJSON_SERDE_STRUCT(AccFiResultCntOutput, acc_fi_result_cnt_t, ACCFI_RESULT_CNT_OUTPUT);

#define ACCFI_RESULT_ARRAY(field, string) \
    field(result, uint32_t, 32) \
    field(insn_cnt, uint32_t) \
    field(err_acc, uint32_t) \
    field(err_ibx, uint32_t) \
    field(alerts, uint32_t, 3) \
    field(ast_alerts, uint32_t, 2)
UJSON_SERDE_STRUCT(AccFiResultArray, acc_fi_result_array_t, ACCFI_RESULT_ARRAY);

#define ACCFI_BIG_NUM(field, string) \
    field(big_num, uint32_t, 16)
UJSON_SERDE_STRUCT(AccFiBigNum, acc_fi_big_num_t, ACCFI_BIG_NUM);

#define ACCFI_BIG_NUM_OUTPUT(field, string) \
    field(big_num, uint32_t, 16) \
    field(insn_cnt, uint32_t) \
    field(err_acc, uint32_t) \
    field(err_ibx, uint32_t) \
    field(alerts, uint32_t, 3) \
    field(ast_alerts, uint32_t, 2)
UJSON_SERDE_STRUCT(AccFiBigNumOutput, acc_fi_big_num_out_t, ACCFI_BIG_NUM_OUTPUT);

#define ACCFI_PC(field, string) \
    field(pc, uint32_t)
UJSON_SERDE_STRUCT(AccFiPc, acc_fi_pc_t, ACCFI_PC);

#define ACCFI_PC_OUTPUT(field, string) \
    field(pc_dmem, uint32_t) \
    field(pc_acc, uint32_t) \
    field(insn_cnt, uint32_t) \
    field(err_acc, uint32_t) \
    field(err_ibx, uint32_t) \
    field(alerts, uint32_t, 3) \
    field(ast_alerts, uint32_t, 2)
UJSON_SERDE_STRUCT(AccFiPcOutput, acc_fi_pc_out_t, ACCFI_PC_OUTPUT);

// clang-format on

#ifdef __cplusplus
}
#endif
#endif  // OPENTITAN_SW_DEVICE_TESTS_PENETRATIONTESTS_JSON_ACC_FI_COMMANDS_H_
