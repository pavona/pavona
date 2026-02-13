// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/tests/penetrationtests/firmware/fi/acc_fi.h"

#include "sw/device/lib/base/memory.h"
#include "sw/device/lib/base/status.h"
#include "sw/device/lib/crypto/drivers/acc.h"
#include "sw/device/lib/crypto/drivers/keymgr.h"
#include "sw/device/lib/dif/dif_acc.h"
#include "sw/device/lib/dif/dif_rv_core_ibex.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/entropy_testutils.h"
#include "sw/device/lib/testing/keymgr_testutils.h"
#include "sw/device/lib/testing/test_framework/ottf_test_config.h"
#include "sw/device/lib/testing/test_framework/ujson_ottf.h"
#include "sw/device/lib/ujson/ujson.h"
#include "sw/device/tests/penetrationtests/firmware/lib/pentest_lib.h"
#include "sw/device/tests/penetrationtests/json/acc_fi_commands.h"

#include "hw/top/acc_regs.h"
#include "hw/top_earlgrey/sw/autogen/top_earlgrey.h"

// Interface to Ibex.
static dif_rv_core_ibex_t rv_core_ibex;

static dif_acc_t acc;
static dif_keymgr_t keymgr;

// Indicates whether the load_integrity test is already initialized.
static bool load_integrity_init;
// Indicates whether the char mem test is already initialized.
static bool char_mem_init;
// Indicates whether the char mem test config is valid.
static bool char_mem_test_cfg_valid;
// Reference checksum for the load integrity test.
static uint32_t load_checksum_ref;
// Load integrity test. Initialize ACC app, load it, and get interface to
// ACC data memory.
ACC_DECLARE_APP_SYMBOLS(acc_load_integrity);
ACC_DECLARE_SYMBOL_ADDR(acc_load_integrity, refval1);
ACC_DECLARE_SYMBOL_ADDR(acc_load_integrity, refval2);
ACC_DECLARE_SYMBOL_ADDR(acc_load_integrity, refval3);
static const acc_app_t kAccAppLoadIntegrity =
    ACC_APP_T_INIT(acc_load_integrity);
static const acc_addr_t kAccAppLoadIntegrityRefVal1 =
    ACC_ADDR_T_INIT(acc_load_integrity, refval1);
static const acc_addr_t kAccAppLoadIntegrityRefVal2 =
    ACC_ADDR_T_INIT(acc_load_integrity, refval2);
static const acc_addr_t kAccAppLoadIntegrityRefVal3 =
    ACC_ADDR_T_INIT(acc_load_integrity, refval3);

// Indicates whether the key sideloading test is already initialized.
static bool key_sideloading_init;
// Key sideloading test. Initialize ACC app, load it, and get interface to
// ACC data memory.
ACC_DECLARE_APP_SYMBOLS(acc_key_sideload);
ACC_DECLARE_SYMBOL_ADDR(acc_key_sideload, k_s0_l);
ACC_DECLARE_SYMBOL_ADDR(acc_key_sideload, k_s0_h);
ACC_DECLARE_SYMBOL_ADDR(acc_key_sideload, k_s1_l);
ACC_DECLARE_SYMBOL_ADDR(acc_key_sideload, k_s1_h);
const acc_app_t kAccAppKeySideload = ACC_APP_T_INIT(acc_key_sideload);
static const acc_addr_t kAccAppKeySideloadks0l =
    ACC_ADDR_T_INIT(acc_key_sideload, k_s0_l);
static const acc_addr_t kAccAppKeySideloadks0h =
    ACC_ADDR_T_INIT(acc_key_sideload, k_s0_h);
static const acc_addr_t kAccAppKeySideloadks1l =
    ACC_ADDR_T_INIT(acc_key_sideload, k_s1_l);
static const acc_addr_t kAccAppKeySideloadks1h =
    ACC_ADDR_T_INIT(acc_key_sideload, k_s1_h);

// Config for the acc.fi.char_mem test.
static bool char_mem_imem;
static bool char_mem_dmem;
static uint32_t char_mem_byte_offset;
static uint32_t char_mem_num_words;

uint32_t key_share_0_l_ref, key_share_0_h_ref;
uint32_t key_share_1_l_ref, key_share_1_h_ref;

// Reference values.
static const uint32_t ref_values[32] = {
    0x1BADB002, 0x8BADF00D, 0xA5A5A5A5, 0xABABABAB, 0xABBABABE, 0xABADCAFE,
    0xBAAAAAAD, 0xBAD22222, 0xBBADBEEF, 0xBEBEBEBE, 0xBEEFCACE, 0xC00010FF,
    0xCAFED00D, 0xCAFEFEED, 0xCCCCCCCC, 0xCDCDCDCD, 0x0D15EA5E, 0xDEAD10CC,
    0xDEADBEEF, 0xDEADCAFE, 0xDEADC0DE, 0xDEADFA11, 0xDEADF00D, 0xDEFEC8ED,
    0xDEADDEAD, 0xD00D2BAD, 0xEBEBEBEB, 0xFADEDEAD, 0xFDFDFDFD, 0xFEE1DEAD,
    0xFEEDFACE, 0xFEEEFEEE};

static const dif_keymgr_versioned_key_params_t kKeyVersionedParamsACCFI = {
    .dest = kDifKeymgrVersionedKeyDestSw,
    .salt =  // the salt doesn't really matter here.
    {
        0xb6521d8f,
        0x13a0e876,
        0x1ca1567b,
        0xb4fb0fdf,
        0x9f89bc56,
        0x4bd127c7,
        0x322288d8,
        0xde919d54,
    },
    .version = 0x0,  // specify a low enough version to work with the ROM EXT.
};

/**
 * Clears the ACC DMEM and IMEM.
 *
 * @returns OK or error.
 */
static status_t clear_acc(void) {
  // Clear ACC memory.
  TRY(acc_dmem_sec_wipe());
  TRY(acc_imem_sec_wipe());

  return OK_STATUS();
}

/**
 * Read the error bits of the ACC accelerator.
 *
 * @returns Error bits.
 */
status_t read_acc_err_bits(dif_acc_err_bits_t *err_acc) {
  TRY(dif_acc_get_err_bits(&acc, err_acc));
  return OK_STATUS();
}

/**
 * Read the ACC load checksum.
 *
 * @returns Load checksum.
 */
status_t read_acc_load_checksum(uint32_t *checksum) {
  TRY(dif_acc_get_load_checksum(&acc, checksum));
  return OK_STATUS();
}

/**
 * Clear the ACC load checksum.
 */
status_t clear_acc_load_checksum(void) {
  TRY(dif_acc_clear_load_checksum(&acc));
  return OK_STATUS();
}

status_t handle_acc_fi_char_beq(ujson_t *uj) {
  // Clear registered alerts in alert handler.
  pentest_registered_alerts_t reg_alerts = pentest_get_triggered_alerts();
  // Clear the AST recoverable alerts.
  pentest_clear_sensor_recov_alerts();

  // Initialize ACC app, load it, and get interface to ACC data memory.
  ACC_DECLARE_APP_SYMBOLS(acc_char_beq);
  ACC_DECLARE_SYMBOL_ADDR(acc_char_beq, res);
  const acc_app_t kAccAppCharBeq = ACC_APP_T_INIT(acc_char_beq);
  static const acc_addr_t kAccAppCharBeqRes =
      ACC_ADDR_T_INIT(acc_char_beq, res);
  TRY(acc_load_app(kAccAppCharBeq));

  // FI code target.
  pentest_set_trigger_high();
  TRY(acc_execute());
  TRY(acc_busy_wait_for_done());
  pentest_set_trigger_low();
  // Get registered alerts from alert handler.
  reg_alerts = pentest_get_triggered_alerts();
  // Get fatal and recoverable AST alerts from sensor controller.
  pentest_sensor_alerts_t sensor_alerts = pentest_get_sensor_alerts();

  // Read counter (x1) from ACC data memory.
  acc_fi_result_cnt_t uj_output;
  uj_output.result = 0;
  TRY(acc_dmem_read(1, kAccAppCharBeqRes, &uj_output.result));

  // Read ACC instruction counter.
  TRY(dif_acc_get_insn_cnt(&acc, &uj_output.insn_cnt));

  // Read ERR_STATUS register from ACC.
  dif_acc_err_bits_t err_acc;
  read_acc_err_bits(&err_acc);

  // Read ERR_STATUS register from Ibex.
  dif_rv_core_ibex_error_status_t err_ibx;
  TRY(dif_rv_core_ibex_get_error_status(&rv_core_ibex, &err_ibx));

  // Clear ACC memory.
  TRY(clear_acc());

  // Send back to host.
  uj_output.err_acc = err_acc;
  uj_output.err_ibx = err_ibx;
  memcpy(uj_output.alerts, reg_alerts.alerts, sizeof(reg_alerts.alerts));
  memcpy(uj_output.ast_alerts, sensor_alerts.alerts,
         sizeof(sensor_alerts.alerts));
  RESP_OK(ujson_serialize_acc_fi_result_cnt_t, uj, &uj_output);
  return OK_STATUS();
}

status_t handle_acc_fi_char_bn_rshi(ujson_t *uj) {
  // Get big number (2x256 bit).
  acc_fi_big_num_t uj_data;
  TRY(ujson_deserialize_acc_fi_big_num_t(uj, &uj_data));

  // Clear registered alerts in alert handler.
  pentest_registered_alerts_t reg_alerts = pentest_get_triggered_alerts();
  // Clear the AST recoverable alerts.
  pentest_clear_sensor_recov_alerts();

  // Initialize ACC app, load it, and get interface to ACC data memory.
  ACC_DECLARE_APP_SYMBOLS(acc_char_bn_rshi);
  ACC_DECLARE_SYMBOL_ADDR(acc_char_bn_rshi, big_num);
  ACC_DECLARE_SYMBOL_ADDR(acc_char_bn_rshi, big_num_out);
  const acc_app_t kAccAppCharBnRshi = ACC_APP_T_INIT(acc_char_bn_rshi);
  static const acc_addr_t kAccAppCharBnRshiBigNum =
      ACC_ADDR_T_INIT(acc_char_bn_rshi, big_num);
  static const acc_addr_t kAccAppCharBnRshiBigNumOut =
      ACC_ADDR_T_INIT(acc_char_bn_rshi, big_num_out);

  // Load app and write received big_num into DMEM.
  TRY(acc_load_app(kAccAppCharBnRshi));
  TRY(dif_acc_dmem_write(&acc, kAccAppCharBnRshiBigNum, uj_data.big_num,
                         sizeof(uj_data.big_num)));

  // FI code target.
  pentest_set_trigger_high();
  TRY(acc_execute());
  TRY(acc_busy_wait_for_done());
  pentest_set_trigger_low();
  // Get registered alerts from alert handler.
  reg_alerts = pentest_get_triggered_alerts();
  // Get fatal and recoverable AST alerts from sensor controller.
  pentest_sensor_alerts_t sensor_alerts = pentest_get_sensor_alerts();

  // Read big_num_out from ACC data memory.
  acc_fi_big_num_out_t uj_output;
  memset(uj_output.big_num, 0, sizeof(uj_output.big_num));
  TRY(dif_acc_dmem_read(&acc, kAccAppCharBnRshiBigNumOut, uj_output.big_num,
                        sizeof(uj_output.big_num)));

  // Read ACC instruction counter.
  TRY(dif_acc_get_insn_cnt(&acc, &uj_output.insn_cnt));

  // Read ERR_STATUS register from ACC.
  dif_acc_err_bits_t err_acc;
  read_acc_err_bits(&err_acc);

  // Read ERR_STATUS register from Ibex.
  dif_rv_core_ibex_error_status_t err_ibx;
  TRY(dif_rv_core_ibex_get_error_status(&rv_core_ibex, &err_ibx));

  // Clear ACC memory.
  TRY(clear_acc());

  // Send back to host.
  uj_output.err_acc = err_acc;
  uj_output.err_ibx = err_ibx;
  memcpy(uj_output.alerts, reg_alerts.alerts, sizeof(reg_alerts.alerts));
  memcpy(uj_output.ast_alerts, sensor_alerts.alerts,
         sizeof(sensor_alerts.alerts));
  RESP_OK(ujson_serialize_acc_fi_big_num_out_t, uj, &uj_output);
  return OK_STATUS();
}

status_t handle_acc_fi_char_bn_sel(ujson_t *uj) {
  // Get big number (2x256 bit).
  acc_fi_big_num_t uj_data;
  TRY(ujson_deserialize_acc_fi_big_num_t(uj, &uj_data));

  // Clear registered alerts in alert handler.
  pentest_registered_alerts_t reg_alerts = pentest_get_triggered_alerts();
  // Clear the AST recoverable alerts.
  pentest_clear_sensor_recov_alerts();

  // Initialize ACC app, load it, and get interface to ACC data memory.
  ACC_DECLARE_APP_SYMBOLS(acc_char_bn_sel);
  ACC_DECLARE_SYMBOL_ADDR(acc_char_bn_sel, big_num);
  ACC_DECLARE_SYMBOL_ADDR(acc_char_bn_sel, big_num_out);
  const acc_app_t kAccAppCharBnSel = ACC_APP_T_INIT(acc_char_bn_sel);
  static const acc_addr_t kAccAppCharBnSelBigNum =
      ACC_ADDR_T_INIT(acc_char_bn_sel, big_num);
  static const acc_addr_t kAccAppCharBnSelBigNumOut =
      ACC_ADDR_T_INIT(acc_char_bn_sel, big_num_out);

  // Load app and write received big_num into DMEM.
  TRY(acc_load_app(kAccAppCharBnSel));
  TRY(dif_acc_dmem_write(&acc, kAccAppCharBnSelBigNum, uj_data.big_num,
                         sizeof(uj_data.big_num)));

  // FI code target.
  pentest_set_trigger_high();
  TRY(acc_execute());
  TRY(acc_busy_wait_for_done());
  pentest_set_trigger_low();
  // Get registered alerts from alert handler.
  reg_alerts = pentest_get_triggered_alerts();
  // Get fatal and recoverable AST alerts from sensor controller.
  pentest_sensor_alerts_t sensor_alerts = pentest_get_sensor_alerts();

  // Read big_num_out from ACC data memory.
  acc_fi_big_num_out_t uj_output;
  memset(uj_output.big_num, 0, sizeof(uj_output.big_num));
  TRY(dif_acc_dmem_read(&acc, kAccAppCharBnSelBigNumOut, uj_output.big_num,
                        sizeof(uj_output.big_num)));

  // Read ACC instruction counter.
  TRY(dif_acc_get_insn_cnt(&acc, &uj_output.insn_cnt));

  // Read ERR_STATUS register from ACC.
  dif_acc_err_bits_t err_acc;
  read_acc_err_bits(&err_acc);

  // Read ERR_STATUS register from Ibex.
  dif_rv_core_ibex_error_status_t err_ibx;
  TRY(dif_rv_core_ibex_get_error_status(&rv_core_ibex, &err_ibx));

  // Clear ACC memory.
  TRY(clear_acc());

  // Send back to host.
  uj_output.err_acc = err_acc;
  uj_output.err_ibx = err_ibx;
  memcpy(uj_output.alerts, reg_alerts.alerts, sizeof(reg_alerts.alerts));
  memcpy(uj_output.ast_alerts, sensor_alerts.alerts,
         sizeof(sensor_alerts.alerts));
  RESP_OK(ujson_serialize_acc_fi_big_num_out_t, uj, &uj_output);
  return OK_STATUS();
}

status_t handle_acc_fi_char_bn_wsrr(ujson_t *uj) {
  // Clear registered alerts in alert handler.
  pentest_registered_alerts_t reg_alerts = pentest_get_triggered_alerts();
  // Clear the AST recoverable alerts.
  pentest_clear_sensor_recov_alerts();

  // Initialize ACC app, load it, and get interface to ACC data memory.
  ACC_DECLARE_APP_SYMBOLS(acc_char_bn_wsrr);
  ACC_DECLARE_SYMBOL_ADDR(acc_char_bn_wsrr, acc_res_values_wdr);
  const acc_app_t kAccAppCharBnWsrr = ACC_APP_T_INIT(acc_char_bn_wsrr);
  static const acc_addr_t kAccAppCharBnWsrrResValuesWDR =
      ACC_ADDR_T_INIT(acc_char_bn_wsrr, acc_res_values_wdr);

  // Load app and write received big_num into DMEM.
  TRY(acc_load_app(kAccAppCharBnWsrr));

  // FI code target.
  pentest_set_trigger_high();
  TRY(acc_execute());
  TRY(acc_busy_wait_for_done());
  pentest_set_trigger_low();

  // Get registered alerts from alert handler.
  reg_alerts = pentest_get_triggered_alerts();
  // Get fatal and recoverable AST alerts from sensor controller.
  pentest_sensor_alerts_t sensor_alerts = pentest_get_sensor_alerts();

  // Read ERR_STATUS register from ACC.
  dif_acc_err_bits_t err_acc;
  read_acc_err_bits(&err_acc);

  // Read ERR_STATUS register from Ibex.
  dif_rv_core_ibex_error_status_t err_ibx;
  TRY(dif_rv_core_ibex_get_error_status(&rv_core_ibex, &err_ibx));

  // Read DMEM
  acc_fi_data_t uj_output;
  uj_output.res = 0;
  memset(uj_output.data, 0, sizeof(uj_output.data));
  TRY(dif_acc_dmem_read(&acc, kAccAppCharBnWsrrResValuesWDR, uj_output.data,
                        sizeof(uj_output.data)));
  // Read ACC instruction counter
  TRY(dif_acc_get_insn_cnt(&acc, &uj_output.insn_cnt));

  // Clear ACC memory.
  TRY(clear_acc());

  // Send result & ERR_STATUS to host.
  uj_output.err_acc = err_acc;
  uj_output.err_ibx = err_ibx;
  memcpy(uj_output.alerts, reg_alerts.alerts, sizeof(reg_alerts.alerts));
  memcpy(uj_output.ast_alerts, sensor_alerts.alerts,
         sizeof(sensor_alerts.alerts));
  RESP_OK(ujson_serialize_acc_fi_data_t, uj, &uj_output);

  return OK_STATUS();
}

status_t handle_acc_fi_char_bne(ujson_t *uj) {
  // Clear registered alerts in alert handler.
  pentest_registered_alerts_t reg_alerts = pentest_get_triggered_alerts();
  // Clear the AST recoverable alerts.
  pentest_clear_sensor_recov_alerts();

  // Initialize ACC app, load it, and get interface to ACC data memory.
  ACC_DECLARE_APP_SYMBOLS(acc_char_bne);
  ACC_DECLARE_SYMBOL_ADDR(acc_char_bne, res);
  const acc_app_t kAccAppCharBne = ACC_APP_T_INIT(acc_char_bne);
  static const acc_addr_t kAccAppCharBneRes =
      ACC_ADDR_T_INIT(acc_char_bne, res);
  TRY(acc_load_app(kAccAppCharBne));

  // FI code target.
  pentest_set_trigger_high();
  TRY(acc_execute());
  TRY(acc_busy_wait_for_done());
  pentest_set_trigger_low();

  // Get registered alerts from alert handler.
  reg_alerts = pentest_get_triggered_alerts();
  // Get fatal and recoverable AST alerts from sensor controller.
  pentest_sensor_alerts_t sensor_alerts = pentest_get_sensor_alerts();
  // Read counter (x1) from ACC data memory.
  acc_fi_result_cnt_t uj_output;
  uj_output.result = 0;
  TRY(acc_dmem_read(1, kAccAppCharBneRes, &uj_output.result));

  // Read ACC instruction counter.
  TRY(dif_acc_get_insn_cnt(&acc, &uj_output.insn_cnt));

  // Read ERR_STATUS register from ACC.
  dif_acc_err_bits_t err_acc;
  read_acc_err_bits(&err_acc);

  // Read ERR_STATUS register from Ibex.
  dif_rv_core_ibex_error_status_t err_ibx;
  TRY(dif_rv_core_ibex_get_error_status(&rv_core_ibex, &err_ibx));
  // Clear ACC memory.
  TRY(clear_acc());

  // Send back to host.
  uj_output.err_acc = err_acc;
  uj_output.err_ibx = err_ibx;
  memcpy(uj_output.alerts, reg_alerts.alerts, sizeof(reg_alerts.alerts));
  memcpy(uj_output.ast_alerts, sensor_alerts.alerts,
         sizeof(sensor_alerts.alerts));
  RESP_OK(ujson_serialize_acc_fi_result_cnt_t, uj, &uj_output);
  return OK_STATUS();
}

status_t handle_acc_fi_char_dmem_access(ujson_t *uj) {
  // Clear registered alerts in alert handler.
  pentest_registered_alerts_t reg_alerts = pentest_get_triggered_alerts();
  // Clear the AST recoverable alerts.
  pentest_clear_sensor_recov_alerts();

  // Config for the acc.fi.char_dmem_access test.
  ACC_DECLARE_APP_SYMBOLS(acc_char_dmem_access);
  ACC_DECLARE_SYMBOL_ADDR(acc_char_dmem_access, values);
  static const acc_app_t kAccAppCharDmemAccess =
      ACC_APP_T_INIT(acc_char_dmem_access);
  static const acc_addr_t kAccVarCharDmemAccessValues =
      ACC_ADDR_T_INIT(acc_char_dmem_access, values);

  TRY(acc_load_app(kAccAppCharDmemAccess));

  // FI code target.
  pentest_set_trigger_high();
  TRY(acc_execute());
  TRY(acc_busy_wait_for_done());
  pentest_set_trigger_low();

  // Get registered alerts from alert handler.
  reg_alerts = pentest_get_triggered_alerts();
  // Get fatal and recoverable AST alerts from sensor controller.
  pentest_sensor_alerts_t sensor_alerts = pentest_get_sensor_alerts();

  // Read ERR_STATUS register from ACC.
  dif_acc_err_bits_t err_acc;
  read_acc_err_bits(&err_acc);

  // Read ERR_STATUS register from Ibex.
  dif_rv_core_ibex_error_status_t err_ibx;
  TRY(dif_rv_core_ibex_get_error_status(&rv_core_ibex, &err_ibx));

  // Read DMEM
  acc_fi_data_t uj_output;
  uj_output.res = 0;
  memset(uj_output.data, 0, sizeof(uj_output.data));
  TRY(dif_acc_dmem_read(&acc, kAccVarCharDmemAccessValues, uj_output.data,
                        sizeof(uj_output.data)));
  // Read ACC instruction counter
  TRY(dif_acc_get_insn_cnt(&acc, &uj_output.insn_cnt));

  // Send result & ERR_STATUS to host.
  uj_output.err_acc = err_acc;
  uj_output.err_ibx = err_ibx;
  memcpy(uj_output.alerts, reg_alerts.alerts, sizeof(reg_alerts.alerts));
  memcpy(uj_output.ast_alerts, sensor_alerts.alerts,
         sizeof(sensor_alerts.alerts));
  RESP_OK(ujson_serialize_acc_fi_data_t, uj, &uj_output);

  return OK_STATUS();
}

status_t handle_acc_fi_char_dmem_write(ujson_t *uj) {
  // Clear registered alerts in alert handler.
  pentest_registered_alerts_t reg_alerts = pentest_get_triggered_alerts();
  // Clear the AST recoverable alerts.
  pentest_clear_sensor_recov_alerts();

  // Config for the acc.fi.char_rf test.
  ACC_DECLARE_APP_SYMBOLS(acc_char_dmem_write);
  ACC_DECLARE_SYMBOL_ADDR(acc_char_dmem_write, mem);

  static const acc_app_t kAccAppCharDmemWrite =
      ACC_APP_T_INIT(acc_char_dmem_write);
  static const acc_addr_t kAccVarCharDmemWriteMem =
      ACC_ADDR_T_INIT(acc_char_dmem_write, mem);

  // Init application and load reference values into DMEM.
  TRY(acc_load_app(kAccAppCharDmemWrite));
  // FI code target.
  pentest_set_trigger_high();
  asm volatile(NOP30);
  // Unrolled instruction sequence.
  mmio_region_write32(
      acc.base_addr, (ptrdiff_t)(ACC_DMEM_REG_OFFSET + kAccVarCharDmemWriteMem),
      ref_values[0]);
  mmio_region_write32(
      acc.base_addr,
      (ptrdiff_t)(ACC_DMEM_REG_OFFSET + kAccVarCharDmemWriteMem + 4),
      ref_values[1]);
  mmio_region_write32(
      acc.base_addr,
      (ptrdiff_t)(ACC_DMEM_REG_OFFSET + kAccVarCharDmemWriteMem + 8),
      ref_values[2]);
  mmio_region_write32(
      acc.base_addr,
      (ptrdiff_t)(ACC_DMEM_REG_OFFSET + kAccVarCharDmemWriteMem + 12),
      ref_values[3]);
  mmio_region_write32(
      acc.base_addr,
      (ptrdiff_t)(ACC_DMEM_REG_OFFSET + kAccVarCharDmemWriteMem + 16),
      ref_values[4]);
  mmio_region_write32(
      acc.base_addr,
      (ptrdiff_t)(ACC_DMEM_REG_OFFSET + kAccVarCharDmemWriteMem + 20),
      ref_values[5]);
  mmio_region_write32(
      acc.base_addr,
      (ptrdiff_t)(ACC_DMEM_REG_OFFSET + kAccVarCharDmemWriteMem + 24),
      ref_values[6]);
  mmio_region_write32(
      acc.base_addr,
      (ptrdiff_t)(ACC_DMEM_REG_OFFSET + kAccVarCharDmemWriteMem + 28),
      ref_values[7]);
  mmio_region_write32(
      acc.base_addr,
      (ptrdiff_t)(ACC_DMEM_REG_OFFSET + kAccVarCharDmemWriteMem + 32),
      ref_values[8]);
  mmio_region_write32(
      acc.base_addr,
      (ptrdiff_t)(ACC_DMEM_REG_OFFSET + kAccVarCharDmemWriteMem + 36),
      ref_values[9]);
  mmio_region_write32(
      acc.base_addr,
      (ptrdiff_t)(ACC_DMEM_REG_OFFSET + kAccVarCharDmemWriteMem + 40),
      ref_values[10]);
  mmio_region_write32(
      acc.base_addr,
      (ptrdiff_t)(ACC_DMEM_REG_OFFSET + kAccVarCharDmemWriteMem + 44),
      ref_values[11]);
  mmio_region_write32(
      acc.base_addr,
      (ptrdiff_t)(ACC_DMEM_REG_OFFSET + kAccVarCharDmemWriteMem + 48),
      ref_values[12]);
  mmio_region_write32(
      acc.base_addr,
      (ptrdiff_t)(ACC_DMEM_REG_OFFSET + kAccVarCharDmemWriteMem + 52),
      ref_values[13]);
  mmio_region_write32(
      acc.base_addr,
      (ptrdiff_t)(ACC_DMEM_REG_OFFSET + kAccVarCharDmemWriteMem + 56),
      ref_values[14]);
  mmio_region_write32(
      acc.base_addr,
      (ptrdiff_t)(ACC_DMEM_REG_OFFSET + kAccVarCharDmemWriteMem + 60),
      ref_values[15]);
  mmio_region_write32(
      acc.base_addr,
      (ptrdiff_t)(ACC_DMEM_REG_OFFSET + kAccVarCharDmemWriteMem + 64),
      ref_values[16]);
  mmio_region_write32(
      acc.base_addr,
      (ptrdiff_t)(ACC_DMEM_REG_OFFSET + kAccVarCharDmemWriteMem + 68),
      ref_values[17]);
  mmio_region_write32(
      acc.base_addr,
      (ptrdiff_t)(ACC_DMEM_REG_OFFSET + kAccVarCharDmemWriteMem + 72),
      ref_values[18]);
  mmio_region_write32(
      acc.base_addr,
      (ptrdiff_t)(ACC_DMEM_REG_OFFSET + kAccVarCharDmemWriteMem + 76),
      ref_values[19]);
  mmio_region_write32(
      acc.base_addr,
      (ptrdiff_t)(ACC_DMEM_REG_OFFSET + kAccVarCharDmemWriteMem + 80),
      ref_values[20]);
  mmio_region_write32(
      acc.base_addr,
      (ptrdiff_t)(ACC_DMEM_REG_OFFSET + kAccVarCharDmemWriteMem + 84),
      ref_values[21]);
  mmio_region_write32(
      acc.base_addr,
      (ptrdiff_t)(ACC_DMEM_REG_OFFSET + kAccVarCharDmemWriteMem + 88),
      ref_values[22]);
  mmio_region_write32(
      acc.base_addr,
      (ptrdiff_t)(ACC_DMEM_REG_OFFSET + kAccVarCharDmemWriteMem + 92),
      ref_values[23]);
  mmio_region_write32(
      acc.base_addr,
      (ptrdiff_t)(ACC_DMEM_REG_OFFSET + kAccVarCharDmemWriteMem + 96),
      ref_values[24]);
  mmio_region_write32(
      acc.base_addr,
      (ptrdiff_t)(ACC_DMEM_REG_OFFSET + kAccVarCharDmemWriteMem + 100),
      ref_values[25]);
  mmio_region_write32(
      acc.base_addr,
      (ptrdiff_t)(ACC_DMEM_REG_OFFSET + kAccVarCharDmemWriteMem + 104),
      ref_values[26]);
  mmio_region_write32(
      acc.base_addr,
      (ptrdiff_t)(ACC_DMEM_REG_OFFSET + kAccVarCharDmemWriteMem + 108),
      ref_values[27]);
  mmio_region_write32(
      acc.base_addr,
      (ptrdiff_t)(ACC_DMEM_REG_OFFSET + kAccVarCharDmemWriteMem + 112),
      ref_values[28]);
  mmio_region_write32(
      acc.base_addr,
      (ptrdiff_t)(ACC_DMEM_REG_OFFSET + kAccVarCharDmemWriteMem + 116),
      ref_values[29]);
  mmio_region_write32(
      acc.base_addr,
      (ptrdiff_t)(ACC_DMEM_REG_OFFSET + kAccVarCharDmemWriteMem + 120),
      ref_values[30]);
  mmio_region_write32(
      acc.base_addr,
      (ptrdiff_t)(ACC_DMEM_REG_OFFSET + kAccVarCharDmemWriteMem + 124),
      ref_values[31]);
  asm volatile(NOP10);
  pentest_set_trigger_low();

  // Execute ACC application.
  TRY(acc_execute());
  TRY(acc_busy_wait_for_done());

  // Get registered alerts from alert handler.
  reg_alerts = pentest_get_triggered_alerts();
  // Get fatal and recoverable AST alerts from sensor controller.
  pentest_sensor_alerts_t sensor_alerts = pentest_get_sensor_alerts();

  // Read ERR_STATUS register from ACC.
  dif_acc_err_bits_t err_acc;
  read_acc_err_bits(&err_acc);

  // Read ERR_STATUS register from Ibex.
  dif_rv_core_ibex_error_status_t err_ibx;
  TRY(dif_rv_core_ibex_get_error_status(&rv_core_ibex, &err_ibx));

  // Compare reference values.
  acc_fi_result_array_t uj_output;
  uint32_t res_values[ARRAYSIZE(ref_values)];
  memset(res_values, 0, sizeof(res_values));
  TRY(dif_acc_dmem_read(&acc, kAccVarCharDmemWriteMem, res_values,
                        sizeof(res_values)));
  for (size_t it = 0; it < ARRAYSIZE(ref_values); it++) {
    uj_output.result[it] = res_values[it] ^ ref_values[it];
  }

  // Read ACC instruction counter.
  TRY(dif_acc_get_insn_cnt(&acc, &uj_output.insn_cnt));

  // Clear ACC memory.
  TRY(clear_acc());

  // Send result & ERR_STATUS to host.
  uj_output.err_acc = err_acc;
  uj_output.err_ibx = err_ibx;
  memcpy(uj_output.alerts, reg_alerts.alerts, sizeof(reg_alerts.alerts));
  memcpy(uj_output.ast_alerts, sensor_alerts.alerts,
         sizeof(sensor_alerts.alerts));
  RESP_OK(ujson_serialize_acc_fi_result_array_t, uj, &uj_output);

  return OK_STATUS();
}

status_t handle_acc_fi_char_hardware_dmem_op_loop(ujson_t *uj) {
  // Clear registered alerts in alert handler.
  pentest_registered_alerts_t reg_alerts = pentest_get_triggered_alerts();
  // Clear the AST recoverable alerts.
  pentest_clear_sensor_recov_alerts();

  // Initialize ACC app, load it, and get interface to ACC data memory.
  ACC_DECLARE_APP_SYMBOLS(acc_char_hardware_dmem_op_loop);
  ACC_DECLARE_SYMBOL_ADDR(acc_char_hardware_dmem_op_loop, lc);
  const acc_app_t kAccAppCharHardwareDmemOpLoop =
      ACC_APP_T_INIT(acc_char_hardware_dmem_op_loop);
  static const acc_addr_t kAccAppCharHardwareDmemOpLoopLC =
      ACC_ADDR_T_INIT(acc_char_hardware_dmem_op_loop, lc);
  TRY(acc_load_app(kAccAppCharHardwareDmemOpLoop));

  uint32_t loop_counter;

  // FI code target.
  pentest_set_trigger_high();
  TRY(acc_execute());
  TRY(acc_busy_wait_for_done());
  pentest_set_trigger_low();
  // Get registered alerts from alert handler.
  reg_alerts = pentest_get_triggered_alerts();
  // Get fatal and recoverable AST alerts from sensor controller.
  pentest_sensor_alerts_t sensor_alerts = pentest_get_sensor_alerts();

  // Read loop counter from ACC data memory.
  TRY(acc_dmem_read(1, kAccAppCharHardwareDmemOpLoopLC, &loop_counter));

  // Read ERR_STATUS register from ACC.
  dif_acc_err_bits_t err_acc;
  read_acc_err_bits(&err_acc);

  // Read ERR_STATUS register from Ibex.
  dif_rv_core_ibex_error_status_t err_ibx;
  TRY(dif_rv_core_ibex_get_error_status(&rv_core_ibex, &err_ibx));

  // Clear ACC memory.
  TRY(clear_acc());

  // Send loop counter & ERR_STATUS to host.
  acc_fi_loop_counter_t uj_output;
  uj_output.loop_counter = loop_counter;
  uj_output.err_acc = err_acc;
  uj_output.err_ibx = err_ibx;
  memcpy(uj_output.alerts, reg_alerts.alerts, sizeof(reg_alerts.alerts));
  memcpy(uj_output.ast_alerts, sensor_alerts.alerts,
         sizeof(sensor_alerts.alerts));
  RESP_OK(ujson_serialize_acc_fi_loop_counter_t, uj, &uj_output);
  return OK_STATUS();
}

status_t handle_acc_fi_char_hardware_reg_op_loop(ujson_t *uj) {
  // Clear registered alerts in alert handler.
  pentest_registered_alerts_t reg_alerts = pentest_get_triggered_alerts();
  // Clear the AST recoverable alerts.
  pentest_clear_sensor_recov_alerts();

  // Initialize ACC app, load it, and get interface to ACC data memory.
  ACC_DECLARE_APP_SYMBOLS(acc_char_hardware_reg_op_loop);
  ACC_DECLARE_SYMBOL_ADDR(acc_char_hardware_reg_op_loop, lc);
  const acc_app_t kAccAppCharHardwareRegOpLoop =
      ACC_APP_T_INIT(acc_char_hardware_reg_op_loop);
  static const acc_addr_t kAccAppCharHardwareRegOpLoopLC =
      ACC_ADDR_T_INIT(acc_char_hardware_reg_op_loop, lc);
  TRY(acc_load_app(kAccAppCharHardwareRegOpLoop));

  uint32_t loop_counter;

  // FI code target.
  pentest_set_trigger_high();
  TRY(acc_execute());
  TRY(acc_busy_wait_for_done());
  pentest_set_trigger_low();
  // Get registered alerts from alert handler.
  reg_alerts = pentest_get_triggered_alerts();
  // Get fatal and recoverable AST alerts from sensor controller.
  pentest_sensor_alerts_t sensor_alerts = pentest_get_sensor_alerts();

  // Read loop counter from ACC data memory.
  TRY(acc_dmem_read(1, kAccAppCharHardwareRegOpLoopLC, &loop_counter));

  // Read ERR_STATUS register from ACC.
  dif_acc_err_bits_t err_acc;
  read_acc_err_bits(&err_acc);

  // Read ERR_STATUS register from Ibex.
  dif_rv_core_ibex_error_status_t err_ibx;
  TRY(dif_rv_core_ibex_get_error_status(&rv_core_ibex, &err_ibx));

  // Clear ACC memory.
  TRY(clear_acc());

  // Send loop counter & ERR_STATUS to host.
  acc_fi_loop_counter_t uj_output;
  uj_output.loop_counter = loop_counter;
  uj_output.err_acc = err_acc;
  uj_output.err_ibx = err_ibx;
  memcpy(uj_output.alerts, reg_alerts.alerts, sizeof(reg_alerts.alerts));
  memcpy(uj_output.ast_alerts, sensor_alerts.alerts,
         sizeof(sensor_alerts.alerts));
  RESP_OK(ujson_serialize_acc_fi_loop_counter_t, uj, &uj_output);
  return OK_STATUS();
}

status_t handle_acc_fi_char_jal(ujson_t *uj) {
  // Clear registered alerts in alert handler.
  pentest_registered_alerts_t reg_alerts = pentest_get_triggered_alerts();
  // Clear the AST recoverable alerts.
  pentest_clear_sensor_recov_alerts();

  // Initialize ACC app, load it, and get interface to ACC data memory.
  ACC_DECLARE_APP_SYMBOLS(acc_char_jal);
  ACC_DECLARE_SYMBOL_ADDR(acc_char_jal, res);
  const acc_app_t kAccAppCharJal = ACC_APP_T_INIT(acc_char_jal);
  static const acc_addr_t kAccAppCharJalRes =
      ACC_ADDR_T_INIT(acc_char_jal, res);
  TRY(acc_load_app(kAccAppCharJal));

  // FI code target.
  pentest_set_trigger_high();
  TRY(acc_execute());
  TRY(acc_busy_wait_for_done());
  pentest_set_trigger_low();
  // Get registered alerts from alert handler.
  reg_alerts = pentest_get_triggered_alerts();
  // Get fatal and recoverable AST alerts from sensor controller.
  pentest_sensor_alerts_t sensor_alerts = pentest_get_sensor_alerts();

  // Read counter (x1) from ACC data memory.
  acc_fi_result_cnt_t uj_output;
  uj_output.result = 0;
  TRY(acc_dmem_read(1, kAccAppCharJalRes, &uj_output.result));

  // Read ACC instruction counter.
  TRY(dif_acc_get_insn_cnt(&acc, &uj_output.insn_cnt));

  // Read ERR_STATUS register from ACC.
  dif_acc_err_bits_t err_acc;
  read_acc_err_bits(&err_acc);

  // Read ERR_STATUS register from Ibex.
  dif_rv_core_ibex_error_status_t err_ibx;
  TRY(dif_rv_core_ibex_get_error_status(&rv_core_ibex, &err_ibx));

  // Clear ACC memory.
  TRY(clear_acc());

  // Send back to host.
  uj_output.err_acc = err_acc;
  uj_output.err_ibx = err_ibx;
  memcpy(uj_output.alerts, reg_alerts.alerts, sizeof(reg_alerts.alerts));
  memcpy(uj_output.ast_alerts, sensor_alerts.alerts,
         sizeof(sensor_alerts.alerts));
  RESP_OK(ujson_serialize_acc_fi_result_cnt_t, uj, &uj_output);
  return OK_STATUS();
}

status_t handle_acc_fi_char_lw(ujson_t *uj) {
  // Clear registered alerts in alert handler.
  pentest_registered_alerts_t reg_alerts = pentest_get_triggered_alerts();
  // Clear the AST recoverable alerts.
  pentest_clear_sensor_recov_alerts();

  // Initialize ACC app, load it, and get interface to ACC data memory.
  ACC_DECLARE_APP_SYMBOLS(acc_char_lw);
  ACC_DECLARE_SYMBOL_ADDR(acc_char_lw, mem_in);
  ACC_DECLARE_SYMBOL_ADDR(acc_char_lw, mem_out);
  const acc_app_t kAccAppCharLw = ACC_APP_T_INIT(acc_char_lw);
  static const acc_addr_t kAccMemIn = ACC_ADDR_T_INIT(acc_char_lw, mem_in);
  static const acc_addr_t kAccMemOut = ACC_ADDR_T_INIT(acc_char_lw, mem_out);

  // Load app and write reference values into mem_in DMEM.
  TRY(acc_load_app(kAccAppCharLw));
  TRY(dif_acc_dmem_write(&acc, kAccMemIn, ref_values, sizeof(ref_values)));

  // FI code target.
  pentest_set_trigger_high();
  TRY(acc_execute());
  TRY(acc_busy_wait_for_done());
  pentest_set_trigger_low();

  // Get registered alerts from alert handler.
  reg_alerts = pentest_get_triggered_alerts();
  // Get fatal and recoverable AST alerts from sensor controller.
  pentest_sensor_alerts_t sensor_alerts = pentest_get_sensor_alerts();

  // Compare reference values. 29 values as we are loading into 29 registers.
  acc_fi_result_array_t uj_output;
  uint32_t res_values[29];
  memset(res_values, 0, sizeof(res_values));
  memset(uj_output.result, 0, sizeof(uj_output.result));
  TRY(dif_acc_dmem_read(&acc, kAccMemOut, res_values, sizeof(res_values)));
  for (size_t it = 0; it < 29; it++) {
    uj_output.result[it] = res_values[it] ^ ref_values[it];
  }

  // Read ACC instruction counter.
  TRY(dif_acc_get_insn_cnt(&acc, &uj_output.insn_cnt));

  // Read ERR_STATUS register from ACC.
  dif_acc_err_bits_t err_acc;
  read_acc_err_bits(&err_acc);

  // Read ERR_STATUS register from Ibex.
  dif_rv_core_ibex_error_status_t err_ibx;
  TRY(dif_rv_core_ibex_get_error_status(&rv_core_ibex, &err_ibx));

  // Clear ACC memory.
  TRY(clear_acc());

  // Send back to host.
  uj_output.err_acc = err_acc;
  uj_output.err_ibx = err_ibx;
  memcpy(uj_output.alerts, reg_alerts.alerts, sizeof(reg_alerts.alerts));
  memcpy(uj_output.ast_alerts, sensor_alerts.alerts,
         sizeof(sensor_alerts.alerts));
  RESP_OK(ujson_serialize_acc_fi_result_array_t, uj, &uj_output);
  return OK_STATUS();
}

status_t handle_acc_fi_char_mem(ujson_t *uj) {
  // Get the test mode. The test mode only can be set at the beginning of a
  // test.
  if (!char_mem_test_cfg_valid) {
    acc_fi_mem_cfg_t uj_cfg;
    TRY(ujson_deserialize_acc_fi_mem_cfg_t(uj, &uj_cfg));
    char_mem_imem = uj_cfg.imem;
    char_mem_dmem = uj_cfg.dmem;
    char_mem_byte_offset = uj_cfg.byte_offset;
    char_mem_num_words = uj_cfg.num_words;
    // Set config to valid.
    char_mem_test_cfg_valid = true;
  }

  // Clear registered alerts in alert handler.
  pentest_registered_alerts_t reg_alerts = pentest_get_triggered_alerts();
  // Clear the AST recoverable alerts.
  pentest_clear_sensor_recov_alerts();

  // Reference values for DMEM and IMEM.
  uint32_t dmem_array_ref[char_mem_num_words];
  uint32_t imem_array_ref[char_mem_num_words];
  if (char_mem_dmem) {
    memset(dmem_array_ref, 0xab, sizeof(dmem_array_ref));
  }
  if (char_mem_imem) {
    memset(imem_array_ref, 0xdf, sizeof(imem_array_ref));
  }

  if (!char_mem_init) {
    if (char_mem_dmem) {
      TRY(dif_acc_dmem_write(&acc, char_mem_byte_offset, dmem_array_ref,
                             sizeof(dmem_array_ref)));
    }
    if (char_mem_imem) {
      TRY(dif_acc_imem_write(&acc, char_mem_byte_offset, imem_array_ref,
                             sizeof(imem_array_ref)));
    }
    char_mem_init = true;
  }

  // FI code target.
  pentest_set_trigger_high();
  asm volatile(NOP100);
  pentest_set_trigger_low();

  // Get registered alerts from alert handler.
  reg_alerts = pentest_get_triggered_alerts();
  // Get fatal and recoverable AST alerts from sensor controller.
  pentest_sensor_alerts_t sensor_alerts = pentest_get_sensor_alerts();

  // Read ERR_STATUS register from ACC.
  dif_acc_err_bits_t err_acc;
  read_acc_err_bits(&err_acc);

  // Read ERR_STATUS register from Ibex.
  dif_rv_core_ibex_error_status_t err_ibx;
  TRY(dif_rv_core_ibex_get_error_status(&rv_core_ibex, &err_ibx));

  acc_fi_mem_t uj_output;
  // Init with all 0 for defaults.
  memset(uj_output.dmem_data, 0, sizeof(uj_output.dmem_data));
  memset(uj_output.dmem_addr, 0, sizeof(uj_output.dmem_addr));
  memset(uj_output.imem_data, 0, sizeof(uj_output.imem_data));
  memset(uj_output.imem_addr, 0, sizeof(uj_output.imem_addr));
  uj_output.res = 0;

  // Check DMEM for data errors.
  size_t fault_pos = 0;
  if (char_mem_dmem) {
    uint32_t dmem_array_res[char_mem_num_words];
    TRY(dif_acc_dmem_read(&acc, char_mem_byte_offset, dmem_array_res,
                          sizeof(dmem_array_ref)));
    for (size_t it = 0; it < char_mem_num_words; it++) {
      if (dmem_array_res[it] != dmem_array_ref[it] &&
          fault_pos < ARRAYSIZE(uj_output.dmem_data)) {
        uj_output.dmem_data[fault_pos] = dmem_array_res[it];
        uj_output.dmem_addr[fault_pos] = it;
        fault_pos++;
        // Re-init memory.
        char_mem_init = false;
        uj_output.res = 1;
      }
    }
  }

  // Check IMEM for data errors.
  uint32_t imem_array_res[char_mem_num_words];
  if (char_mem_imem) {
    TRY(dif_acc_imem_read(&acc, char_mem_byte_offset, imem_array_res,
                          sizeof(imem_array_ref)));
    fault_pos = 0;
    for (size_t it = 0; it < char_mem_num_words; it++) {
      if (imem_array_res[it] != imem_array_ref[it] &&
          fault_pos < ARRAYSIZE(uj_output.imem_data)) {
        uj_output.imem_data[fault_pos] = imem_array_res[it];
        uj_output.imem_addr[fault_pos] = it;
        fault_pos++;
        // Re-init memory.
        char_mem_init = false;
        uj_output.res = 1;
      }
    }
  }

  // Send result & ERR_STATUS to host.
  uj_output.err_acc = err_acc;
  uj_output.err_ibx = err_ibx;
  memcpy(uj_output.alerts, reg_alerts.alerts, sizeof(reg_alerts.alerts));
  memcpy(uj_output.ast_alerts, sensor_alerts.alerts,
         sizeof(sensor_alerts.alerts));
  RESP_OK(ujson_serialize_acc_fi_mem_t, uj, &uj_output);

  return OK_STATUS();
}

status_t handle_acc_fi_char_register_file(ujson_t *uj) {
  // Clear registered alerts in alert handler.
  pentest_registered_alerts_t reg_alerts = pentest_get_triggered_alerts();
  // Clear the AST recoverable alerts.
  pentest_clear_sensor_recov_alerts();

  // Config for the acc.fi.char_rf test.
  ACC_DECLARE_APP_SYMBOLS(acc_char_rf);
  ACC_DECLARE_SYMBOL_ADDR(acc_char_rf, acc_ref_values);
  ACC_DECLARE_SYMBOL_ADDR(acc_char_rf, acc_res_values_gpr);
  ACC_DECLARE_SYMBOL_ADDR(acc_char_rf, acc_res_values_wdr);

  static const acc_app_t kAccAppCharRF = ACC_APP_T_INIT(acc_char_rf);
  static const acc_addr_t kAccVarCharRFRefValues =
      ACC_ADDR_T_INIT(acc_char_rf, acc_ref_values);
  static const acc_addr_t kAccVarCharRFResValuesGPR =
      ACC_ADDR_T_INIT(acc_char_rf, acc_res_values_gpr);
  static const acc_addr_t kAccVarCharRFResValuesWDR =
      ACC_ADDR_T_INIT(acc_char_rf, acc_res_values_wdr);

  // Init application and load reference values into DMEM.
  TRY(acc_load_app(kAccAppCharRF));
  TRY(dif_acc_dmem_write(&acc, kAccVarCharRFRefValues, ref_values,
                         sizeof(ref_values)));

  pentest_set_trigger_high();
  TRY(acc_execute());
  TRY(acc_busy_wait_for_done());
  pentest_set_trigger_low();

  // Get registered alerts from alert handler.
  reg_alerts = pentest_get_triggered_alerts();
  // Get fatal and recoverable AST alerts from sensor controller.
  pentest_sensor_alerts_t sensor_alerts = pentest_get_sensor_alerts();

  // Read ERR_STATUS register from ACC.
  dif_acc_err_bits_t err_acc;
  read_acc_err_bits(&err_acc);

  // Read ERR_STATUS register from Ibex.
  dif_rv_core_ibex_error_status_t err_ibx;
  TRY(dif_rv_core_ibex_get_error_status(&rv_core_ibex, &err_ibx));

  // Read GPR RF values from DMEM.
  uint32_t res_values_gpr[29];
  memset(res_values_gpr, 0, sizeof(res_values_gpr));
  TRY(dif_acc_dmem_read(&acc, kAccVarCharRFResValuesGPR, res_values_gpr,
                        sizeof(res_values_gpr)));

  // Compare GPR RF values to reference values.
  acc_fi_rf_char_t uj_output;
  memset(uj_output.faulty_gpr, 0, sizeof(uj_output.faulty_gpr));
  uj_output.res = 0;
  for (size_t it = 0; it < ARRAYSIZE(res_values_gpr); it++) {
    if (res_values_gpr[it] != ref_values[it]) {
      uj_output.res = 1;
      // Report reference value XOR faulty value back to also detect faulty
      // values that are 0.
      uj_output.faulty_gpr[it] = res_values_gpr[it] ^ ref_values[it];
    }
  }

  // Read WDR RF values from DMEM.
  uint32_t res_values_wdr[256];
  memset(res_values_wdr, 0, sizeof(res_values_wdr));
  TRY(dif_acc_dmem_read(&acc, kAccVarCharRFResValuesWDR, res_values_wdr,
                        sizeof(res_values_wdr)));

  // Compare WDR RF values to reference values.
  memset(uj_output.faulty_wdr, 0, sizeof(uj_output.faulty_wdr));
  for (size_t it = 0; it < ARRAYSIZE(res_values_wdr); it++) {
    if (res_values_wdr[it] != ref_values[it % 32]) {
      uj_output.res = 1;
      // Report reference value XOR faulty value back to also detect faulty
      // values that are 0.
      uj_output.faulty_wdr[it] = res_values_wdr[it] ^ ref_values[it % 32];
    }
  }

  // Send result & ERR_STATUS to host.
  uj_output.err_acc = err_acc;
  uj_output.err_ibx = err_ibx;
  memcpy(uj_output.alerts, reg_alerts.alerts, sizeof(reg_alerts.alerts));
  memcpy(uj_output.ast_alerts, sensor_alerts.alerts,
         sizeof(sensor_alerts.alerts));
  RESP_OK(ujson_serialize_acc_fi_rf_char_t, uj, &uj_output);

  return OK_STATUS();
}

status_t handle_acc_fi_char_unrolled_dmem_op_loop(ujson_t *uj) {
  // Clear registered alerts in alert handler.
  pentest_registered_alerts_t reg_alerts = pentest_get_triggered_alerts();
  // Clear the AST recoverable alerts.
  pentest_clear_sensor_recov_alerts();

  // Initialize ACC app, load it, and get interface to ACC data memory.
  ACC_DECLARE_APP_SYMBOLS(acc_char_unrolled_dmem_op_loop);
  ACC_DECLARE_SYMBOL_ADDR(acc_char_unrolled_dmem_op_loop, lc);
  const acc_app_t kAccAppCharUnrolledDmemOpLoop =
      ACC_APP_T_INIT(acc_char_unrolled_dmem_op_loop);
  static const acc_addr_t kAccAppCharUnrolledDmemOpLoopLC =
      ACC_ADDR_T_INIT(acc_char_unrolled_dmem_op_loop, lc);
  TRY(acc_load_app(kAccAppCharUnrolledDmemOpLoop));

  uint32_t loop_counter;

  // FI code target.
  pentest_set_trigger_high();
  TRY(acc_execute());
  TRY(acc_busy_wait_for_done());
  pentest_set_trigger_low();
  // Get registered alerts from alert handler.
  reg_alerts = pentest_get_triggered_alerts();
  // Get fatal and recoverable AST alerts from sensor controller.
  pentest_sensor_alerts_t sensor_alerts = pentest_get_sensor_alerts();

  // Read loop counter from ACC data memory.
  TRY(acc_dmem_read(1, kAccAppCharUnrolledDmemOpLoopLC, &loop_counter));

  // Read ERR_STATUS register from ACC.
  dif_acc_err_bits_t err_acc;
  read_acc_err_bits(&err_acc);

  // Read ERR_STATUS register from Ibex.
  dif_rv_core_ibex_error_status_t err_ibx;
  TRY(dif_rv_core_ibex_get_error_status(&rv_core_ibex, &err_ibx));

  // Clear ACC memory.
  TRY(clear_acc());

  // Send loop counter & ERR_STATUS to host.
  acc_fi_loop_counter_t uj_output;
  uj_output.loop_counter = loop_counter;
  uj_output.err_acc = err_acc;
  uj_output.err_ibx = err_ibx;
  memcpy(uj_output.alerts, reg_alerts.alerts, sizeof(reg_alerts.alerts));
  memcpy(uj_output.ast_alerts, sensor_alerts.alerts,
         sizeof(sensor_alerts.alerts));
  RESP_OK(ujson_serialize_acc_fi_loop_counter_t, uj, &uj_output);
  return OK_STATUS();
}

status_t handle_acc_fi_char_unrolled_reg_op_loop(ujson_t *uj) {
  // Clear registered alerts in alert handler.
  pentest_registered_alerts_t reg_alerts = pentest_get_triggered_alerts();
  // Clear the AST recoverable alerts.
  pentest_clear_sensor_recov_alerts();

  // Initialize ACC app, load it, and get interface to ACC data memory.
  ACC_DECLARE_APP_SYMBOLS(acc_char_unrolled_reg_op_loop);
  ACC_DECLARE_SYMBOL_ADDR(acc_char_unrolled_reg_op_loop, lc);
  const acc_app_t kAccAppCharUnrolledRegOpLoop =
      ACC_APP_T_INIT(acc_char_unrolled_reg_op_loop);
  static const acc_addr_t kAccAppCharUnrolledRegOpLoopLC =
      ACC_ADDR_T_INIT(acc_char_unrolled_reg_op_loop, lc);
  TRY(acc_load_app(kAccAppCharUnrolledRegOpLoop));

  uint32_t loop_counter;

  // FI code target.
  pentest_set_trigger_high();
  TRY(acc_execute());
  TRY(acc_busy_wait_for_done());
  pentest_set_trigger_low();
  // Get registered alerts from alert handler.
  reg_alerts = pentest_get_triggered_alerts();
  // Get fatal and recoverable AST alerts from sensor controller.
  pentest_sensor_alerts_t sensor_alerts = pentest_get_sensor_alerts();

  // Read loop counter from ACC data memory.
  TRY(acc_dmem_read(1, kAccAppCharUnrolledRegOpLoopLC, &loop_counter));

  // Read ERR_STATUS register from ACC.
  dif_acc_err_bits_t err_acc;
  read_acc_err_bits(&err_acc);

  // Read ERR_STATUS register from Ibex.
  dif_rv_core_ibex_error_status_t err_ibx;
  TRY(dif_rv_core_ibex_get_error_status(&rv_core_ibex, &err_ibx));

  // Clear ACC memory.
  TRY(clear_acc());

  // Send loop counter & ERR_STATUS to host.
  acc_fi_loop_counter_t uj_output;
  uj_output.loop_counter = loop_counter;
  uj_output.err_acc = err_acc;
  uj_output.err_ibx = err_ibx;
  memcpy(uj_output.alerts, reg_alerts.alerts, sizeof(reg_alerts.alerts));
  memcpy(uj_output.ast_alerts, sensor_alerts.alerts,
         sizeof(sensor_alerts.alerts));
  RESP_OK(ujson_serialize_acc_fi_loop_counter_t, uj, &uj_output);
  return OK_STATUS();
}

status_t handle_acc_fi_init(ujson_t *uj) {
  penetrationtest_cpuctrl_t uj_cpuctrl_data;
  TRY(ujson_deserialize_penetrationtest_cpuctrl_t(uj, &uj_cpuctrl_data));
  penetrationtest_sensor_config_t uj_sensor_data;
  TRY(ujson_deserialize_penetrationtest_sensor_config_t(uj, &uj_sensor_data));
  penetrationtest_alert_config_t uj_alert_data;
  TRY(ujson_deserialize_penetrationtest_alert_config_t(uj, &uj_alert_data));

  // Configure the entropy complex for ACC. Set the reseed interval to max
  // to avoid a non-constant trigger window.
  TRY(pentest_configure_entropy_source_max_reseed_interval());

  pentest_select_trigger_type(kPentestTriggerTypeSw);
  pentest_init(kPentestTriggerSourceAcc,
               kPentestPeripheralIoDiv4 | kPentestPeripheralEdn |
                   kPentestPeripheralCsrng | kPentestPeripheralEntropy |
                   kPentestPeripheralAes | kPentestPeripheralHmac |
                   kPentestPeripheralKmac | kPentestPeripheralAcc,
               uj_sensor_data.sensor_ctrl_enable,
               uj_sensor_data.sensor_ctrl_en_fatal);

  // Configure Ibex to allow reading ERR_STATUS register.
  TRY(dif_rv_core_ibex_init(
      mmio_region_from_addr(TOP_EARLGREY_RV_CORE_IBEX_CFG_BASE_ADDR),
      &rv_core_ibex));

  // Init the ACC core.
  TRY(dif_acc_init(mmio_region_from_addr(TOP_EARLGREY_ACC_BASE_ADDR), &acc));

  // Configure the alert handler. Alerts triggered by IP blocks are captured
  // and reported to the test.
  pentest_configure_alert_handler(
      uj_alert_data.alert_classes, uj_alert_data.enable_alerts,
      uj_alert_data.enable_classes, uj_alert_data.accumulation_thresholds,
      uj_alert_data.signals, uj_alert_data.duration_cycles,
      uj_alert_data.ping_timeout);

  // Configure the CPU for the pentest.
  penetrationtest_device_info_t uj_output;
  TRY(pentest_configure_cpu(
      uj_cpuctrl_data.enable_icache, &uj_output.icache_en,
      uj_cpuctrl_data.enable_dummy_instr, &uj_output.dummy_instr_en,
      uj_cpuctrl_data.dummy_instr_count, uj_cpuctrl_data.enable_jittery_clock,
      uj_cpuctrl_data.enable_sram_readback, &uj_output.clock_jitter_locked,
      &uj_output.clock_jitter_en, &uj_output.sram_main_readback_locked,
      &uj_output.sram_ret_readback_locked, &uj_output.sram_main_readback_en,
      &uj_output.sram_ret_readback_en, uj_cpuctrl_data.enable_data_ind_timing,
      &uj_output.data_ind_timing_en));

  // The load integrity, key sideloading, and char_mem tests get initialized at
  // the first run.
  load_integrity_init = false;
  key_sideloading_init = false;
  char_mem_init = false;
  char_mem_test_cfg_valid = false;

  // Read rom digest.
  TRY(pentest_read_rom_digest(uj_output.rom_digest));

  // Read device ID and return to host.
  TRY(pentest_read_device_id(uj_output.device_id));
  RESP_OK(ujson_serialize_penetrationtest_device_info_t, uj, &uj_output);

  // Read the sensor config.
  TRY(pentest_send_sensor_config(uj));

  // Read the alert config.
  TRY(pentest_send_alert_config(uj));

  // Read different SKU config fields and return to host.
  TRY(pentest_send_sku_config(uj));

  return OK_STATUS();
}

status_t handle_acc_fi_init_keymgr(ujson_t *uj) {
  dif_kmac_t kmac;
  TRY(dif_kmac_init(mmio_region_from_addr(TOP_EARLGREY_KMAC_BASE_ADDR), &kmac));
  TRY(dif_keymgr_init(mmio_region_from_addr(TOP_EARLGREY_KEYMGR_BASE_ADDR),
                      &keymgr));
  TRY(keymgr_testutils_initialize(&keymgr, &kmac));

  dif_keymgr_versioned_key_params_t sideload_params = kKeyVersionedParamsACCFI;
  sideload_params.dest = kDifKeymgrVersionedKeyDestAcc;
  TRY(keymgr_testutils_generate_versioned_key(&keymgr, sideload_params));
  return OK_STATUS();
}

status_t handle_acc_fi_key_sideload(ujson_t *uj) {
  TRY(dif_acc_set_ctrl_software_errs_fatal(&acc, /*enable=*/false));
  // Clear registered alerts in alert handler.
  pentest_registered_alerts_t reg_alerts = pentest_get_triggered_alerts();
  // Clear the AST recoverable alerts.
  pentest_clear_sensor_recov_alerts();

  if (!key_sideloading_init) {
    // Setup keymanager for sideloading key into ACC.
    TRY(acc_load_app(kAccAppKeySideload));
    // Get reference keys.
    TRY(acc_execute());
    TRY(acc_busy_wait_for_done());

    TRY(acc_dmem_read(1, kAccAppKeySideloadks0l, &key_share_0_l_ref));
    TRY(acc_dmem_read(1, kAccAppKeySideloadks0h, &key_share_0_h_ref));
    TRY(acc_dmem_read(1, kAccAppKeySideloadks1l, &key_share_1_l_ref));
    TRY(acc_dmem_read(1, kAccAppKeySideloadks1h, &key_share_1_h_ref));

    key_sideloading_init = true;
  }

  // FI code target.
  pentest_set_trigger_high();
  TRY(acc_execute());
  TRY(acc_busy_wait_for_done());
  pentest_set_trigger_low();

  // Get registered alerts from alert handler.
  reg_alerts = pentest_get_triggered_alerts();
  // Get fatal and recoverable AST alerts from sensor controller.
  pentest_sensor_alerts_t sensor_alerts = pentest_get_sensor_alerts();

  // Read loop counter from ACC data memory.
  uint32_t key_share_0_l, key_share_0_h;
  uint32_t key_share_1_l, key_share_1_h;
  TRY(acc_dmem_read(1, kAccAppKeySideloadks0l, &key_share_0_l));
  TRY(acc_dmem_read(1, kAccAppKeySideloadks0h, &key_share_0_h));
  TRY(acc_dmem_read(1, kAccAppKeySideloadks1l, &key_share_1_l));
  TRY(acc_dmem_read(1, kAccAppKeySideloadks1h, &key_share_1_h));

  // Read ERR_STATUS register from ACC.
  dif_acc_err_bits_t err_acc;
  read_acc_err_bits(&err_acc);

  // Read ERR_STATUS register from Ibex.
  dif_rv_core_ibex_error_status_t err_ibx;
  TRY(dif_rv_core_ibex_get_error_status(&rv_core_ibex, &err_ibx));

  acc_fi_keys_t uj_output;
  uj_output.keys[0] = key_share_0_l;
  uj_output.keys[1] = key_share_0_h;
  uj_output.keys[2] = key_share_1_l;
  uj_output.keys[3] = key_share_1_h;

  uj_output.res = 0;
  if ((key_share_0_l != key_share_0_l_ref) ||
      (key_share_0_h != key_share_0_h_ref) ||
      (key_share_1_l != key_share_1_l_ref) ||
      (key_share_1_h != key_share_1_h_ref)) {
    uj_output.res = 1;
  }

  // Send result & ERR_STATUS to host.
  uj_output.err_acc = err_acc;
  uj_output.err_ibx = err_ibx;
  memcpy(uj_output.alerts, reg_alerts.alerts, sizeof(reg_alerts.alerts));
  memcpy(uj_output.ast_alerts, sensor_alerts.alerts,
         sizeof(sensor_alerts.alerts));
  RESP_OK(ujson_serialize_acc_fi_keys_t, uj, &uj_output);
  return OK_STATUS();
}

status_t handle_acc_fi_load_integrity(ujson_t *uj) {
  // Clear registered alerts in alert handler.
  pentest_registered_alerts_t reg_alerts = pentest_get_triggered_alerts();
  // Clear the AST recoverable alerts.
  pentest_clear_sensor_recov_alerts();

  if (!load_integrity_init) {
    // Load the ACC app and read the load checksum without FI to retrieve
    // reference value.
    clear_acc_load_checksum();
    TRY(acc_load_app(kAccAppLoadIntegrity));
    read_acc_load_checksum(&load_checksum_ref);
    clear_acc_load_checksum();

    load_integrity_init = true;
  }

  // FI code target.
  pentest_set_trigger_high();
  TRY(acc_load_app(kAccAppLoadIntegrity));
  pentest_set_trigger_low();
  // Get registered alerts from alert handler.
  reg_alerts = pentest_get_triggered_alerts();
  // Get fatal and recoverable AST alerts from sensor controller.
  pentest_sensor_alerts_t sensor_alerts = pentest_get_sensor_alerts();

  // Read back checksum.
  uint32_t load_checksum;
  read_acc_load_checksum(&load_checksum);
  clear_acc_load_checksum();

  // Read loop counter from ACC data memory.
  uint32_t ref_val1, ref_val2, ref_val3;
  TRY(acc_dmem_read(1, kAccAppLoadIntegrityRefVal1, &ref_val1));
  TRY(acc_dmem_read(1, kAccAppLoadIntegrityRefVal2, &ref_val2));
  TRY(acc_dmem_read(1, kAccAppLoadIntegrityRefVal3, &ref_val3));

  // Check if DMEM is corrupted.
  bool dmem_corrupted = false;
  if ((ref_val1 != 0x1BADB002) || (ref_val2 != 0x8BADF00D) ||
      (ref_val3 != 0xA5A5A5A5)) {
    dmem_corrupted = true;
  }

  // If DMEM is corrupted and the checksum is still correct, we achieved the
  // attack goal.
  uint32_t res = 0;
  if ((load_checksum_ref == load_checksum) && dmem_corrupted) {
    res = 1;
  }

  // Read ERR_STATUS register from ACC.
  dif_acc_err_bits_t err_acc;
  read_acc_err_bits(&err_acc);

  // Read ERR_STATUS register from Ibex.
  dif_rv_core_ibex_error_status_t err_ibx;
  TRY(dif_rv_core_ibex_get_error_status(&rv_core_ibex, &err_ibx));

  // Clear ACC memory.
  TRY(clear_acc());

  // Send result & ERR_STATUS to host.
  acc_fi_result_t uj_output;
  uj_output.result = res;
  uj_output.err_acc = err_acc;
  uj_output.err_ibx = err_ibx;
  memcpy(uj_output.alerts, reg_alerts.alerts, sizeof(reg_alerts.alerts));
  memcpy(uj_output.ast_alerts, sensor_alerts.alerts,
         sizeof(sensor_alerts.alerts));
  RESP_OK(ujson_serialize_acc_fi_result_t, uj, &uj_output);
  return OK_STATUS();
}

status_t handle_acc_fi_pc(ujson_t *uj) {
  // Get ACC program counter from host.
  acc_fi_pc_t uj_data;
  TRY(ujson_deserialize_acc_fi_pc_t(uj, &uj_data));

  // Clear registered alerts in alert handler.
  pentest_registered_alerts_t reg_alerts = pentest_get_triggered_alerts();
  // Clear the AST recoverable alerts.
  pentest_clear_sensor_recov_alerts();

  // Initialize ACC app, load it, and get interface to ACC data memory.
  ACC_DECLARE_APP_SYMBOLS(acc_pc);
  ACC_DECLARE_SYMBOL_ADDR(acc_pc, pc);
  ACC_DECLARE_SYMBOL_ADDR(acc_pc, pc_out);
  const acc_app_t kAccAppPc = ACC_APP_T_INIT(acc_pc);
  static const acc_addr_t kAccPc = ACC_ADDR_T_INIT(acc_pc, pc);
  static const acc_addr_t kAccPcOut = ACC_ADDR_T_INIT(acc_pc, pc_out);
  dif_acc_status_t acc_status;

  // Load app.
  TRY(acc_load_app(kAccAppPc));

  // FI code target.
  pentest_set_trigger_high();
  TRY(dif_acc_dmem_write(&acc, kAccPc, &uj_data.pc, sizeof(uj_data.pc)));
  TRY(acc_execute());
  // Wait until is started before deasserting the trigger.
  bool is_running = false;
  while (!is_running) {
    TRY(dif_acc_get_status(&acc, &acc_status));
    if (acc_status != kDifAccStatusIdle) {
      is_running = true;
    }
  }
  pentest_set_trigger_low();
  TRY(acc_busy_wait_for_done());
  // Get registered alerts from alert handler.
  reg_alerts = pentest_get_triggered_alerts();
  // Get fatal and recoverable AST alerts from sensor controller.
  pentest_sensor_alerts_t sensor_alerts = pentest_get_sensor_alerts();

  // Read pc_out from ACC data memory.
  acc_fi_pc_out_t uj_output;
  TRY(dif_acc_dmem_read(&acc, kAccPcOut, &uj_output.pc_acc,
                        sizeof(uj_output.pc_acc)));
  TRY(dif_acc_dmem_read(&acc, kAccPc, &uj_output.pc_dmem,
                        sizeof(uj_output.pc_dmem)));

  // Read ACC instruction counter.
  TRY(dif_acc_get_insn_cnt(&acc, &uj_output.insn_cnt));

  // Read ERR_STATUS register from ACC.
  dif_acc_err_bits_t err_acc;
  read_acc_err_bits(&err_acc);

  // Read ERR_STATUS register from Ibex.
  dif_rv_core_ibex_error_status_t err_ibx;
  TRY(dif_rv_core_ibex_get_error_status(&rv_core_ibex, &err_ibx));

  // Clear ACC memory.
  TRY(clear_acc());

  // Send back to host.
  uj_output.err_acc = err_acc;
  uj_output.err_ibx = err_ibx;
  memcpy(uj_output.alerts, reg_alerts.alerts, sizeof(reg_alerts.alerts));
  memcpy(uj_output.ast_alerts, sensor_alerts.alerts,
         sizeof(sensor_alerts.alerts));
  RESP_OK(ujson_serialize_acc_fi_pc_out_t, uj, &uj_output);
  return OK_STATUS();
}

status_t handle_acc_fi(ujson_t *uj) {
  acc_fi_subcommand_t cmd;
  TRY(ujson_deserialize_acc_fi_subcommand_t(uj, &cmd));
  switch (cmd) {
    case kAccFiSubcommandCharBeq:
      return handle_acc_fi_char_beq(uj);
    case kAccFiSubcommandCharBnRshi:
      return handle_acc_fi_char_bn_rshi(uj);
    case kAccFiSubcommandCharBnSel:
      return handle_acc_fi_char_bn_sel(uj);
    case kAccFiSubcommandCharBnWsrr:
      return handle_acc_fi_char_bn_wsrr(uj);
    case kAccFiSubcommandCharBne:
      return handle_acc_fi_char_bne(uj);
    case kAccFiSubcommandCharDmemAccess:
      return handle_acc_fi_char_dmem_access(uj);
    case kAccFiSubcommandCharDmemWrite:
      return handle_acc_fi_char_dmem_write(uj);
    case kAccFiSubcommandCharHardwareDmemOpLoop:
      return handle_acc_fi_char_hardware_dmem_op_loop(uj);
    case kAccFiSubcommandCharHardwareRegOpLoop:
      return handle_acc_fi_char_hardware_reg_op_loop(uj);
    case kAccFiSubcommandCharJal:
      return handle_acc_fi_char_jal(uj);
    case kAccFiSubcommandCharLw:
      return handle_acc_fi_char_lw(uj);
    case kAccFiSubcommandCharMem:
      return handle_acc_fi_char_mem(uj);
    case kAccFiSubcommandCharRF:
      return handle_acc_fi_char_register_file(uj);
    case kAccFiSubcommandCharUnrolledDmemOpLoop:
      return handle_acc_fi_char_unrolled_dmem_op_loop(uj);
    case kAccFiSubcommandCharUnrolledRegOpLoop:
      return handle_acc_fi_char_unrolled_reg_op_loop(uj);
    case kAccFiSubcommandInit:
      return handle_acc_fi_init(uj);
    case kAccFiSubcommandInitKeyMgr:
      return handle_acc_fi_init_keymgr(uj);
    case kAccFiSubcommandKeySideload:
      return handle_acc_fi_key_sideload(uj);
    case kAccFiSubcommandLoadIntegrity:
      return handle_acc_fi_load_integrity(uj);
    case kAccFiSubcommandPC:
      return handle_acc_fi_pc(uj);
    default:
      LOG_ERROR("Unrecognized ACC FI subcommand: %d", cmd);
      return INVALID_ARGUMENT();
  }
  return OK_STATUS();
}
