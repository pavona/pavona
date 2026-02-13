// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hw/top/dt/dt_acc.h"
#include "sw/device/lib/dif/dif_acc.h"
#include "sw/device/lib/runtime/ibex.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/entropy_testutils.h"
#include "sw/device/lib/testing/acc_testutils.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"

ACC_DECLARE_APP_SYMBOLS(barrett384);
ACC_DECLARE_SYMBOL_ADDR(barrett384, inp_a);
ACC_DECLARE_SYMBOL_ADDR(barrett384, inp_b);
ACC_DECLARE_SYMBOL_ADDR(barrett384, inp_m);
ACC_DECLARE_SYMBOL_ADDR(barrett384, inp_u);
ACC_DECLARE_SYMBOL_ADDR(barrett384, oup_c);

static const acc_app_t kAppBarrett = ACC_APP_T_INIT(barrett384);
static const acc_addr_t kInpA = ACC_ADDR_T_INIT(barrett384, inp_a);
static const acc_addr_t kInpB = ACC_ADDR_T_INIT(barrett384, inp_b);
static const acc_addr_t kInpM = ACC_ADDR_T_INIT(barrett384, inp_m);
static const acc_addr_t kInpU = ACC_ADDR_T_INIT(barrett384, inp_u);
static const acc_addr_t kOupC = ACC_ADDR_T_INIT(barrett384, oup_c);

ACC_DECLARE_APP_SYMBOLS(err_test);

static const acc_app_t kAppErrTest = ACC_APP_T_INIT(err_test);

static_assert(kDtAccCount >= 1,
              "This test requires at least one ACC instance");

static dt_acc_t kTestAcc = (dt_acc_t)0;

OTTF_DEFINE_TEST_CONFIG();

/**
 * Gets the ACC instruction count, checks that it matches expectations.
 */
static void check_acc_insn_cnt(dif_acc_t *acc, uint32_t expected_insn_cnt) {
  uint32_t insn_cnt;
  CHECK_DIF_OK(dif_acc_get_insn_cnt(acc, &insn_cnt));
  CHECK(insn_cnt == expected_insn_cnt,
        "Expected to execute %d instructions, but got %d.", expected_insn_cnt,
        insn_cnt);
}

/**
 * Run a 384-bit Barrett Multiplication on ACC and check its result.
 *
 * This test is not aiming to exhaustively test the Barrett multiplication
 * itself, but test the interaction between device software and ACC. As such,
 * only trivial parameters are used.
 *
 * The code executed on ACC can be found in sw/acc/code-snippets/barrett384.s.
 * The entry point wrap_barrett384() is called according to the calling
 * convention described in the ACC assembly code file.
 */
static void test_barrett384(dif_acc_t *acc) {
  enum { kDataSizeBytes = 48 };

  CHECK_STATUS_OK(acc_testutils_load_app(acc, kAppBarrett));

  // a, first operand
  static const uint8_t a[kDataSizeBytes] = {10};

  // b, second operand
  static uint8_t b[kDataSizeBytes] = {20};

  // m, modulus, max. length 384 bit with 2^384 > m > 2^383
  // We choose the modulus of P-384: m = 2**384 - 2**128 - 2**96 + 2**32 - 1
  static const uint8_t m[kDataSizeBytes] = {
      0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
      0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
      0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xfe, 0xff, 0xff, 0xff, 0xff,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0xff};

  // u, pre-computed Barrett constant (without u[384]/MSb of u which is always 1
  // for the allowed range but has to be set to 0 here).
  // u has to be pre-calculated as u = floor(2^768/m).
  static const uint8_t u[kDataSizeBytes] = {
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00,
      0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x01};

  // c, result, max. length 384 bit.
  uint8_t c[kDataSizeBytes] = {0};

  // c = (a * b) % m = (10 * 20) % m = 200
  static const uint8_t c_expected[kDataSizeBytes] = {200};

  CHECK_STATUS_OK(acc_testutils_write_data(acc, sizeof(a), &a, kInpA));
  CHECK_STATUS_OK(acc_testutils_write_data(acc, sizeof(b), &b, kInpB));
  CHECK_STATUS_OK(acc_testutils_write_data(acc, sizeof(m), &m, kInpM));
  CHECK_STATUS_OK(acc_testutils_write_data(acc, sizeof(u), &u, kInpU));

  CHECK_DIF_OK(dif_acc_set_ctrl_software_errs_fatal(acc, true));
  CHECK_STATUS_OK(acc_testutils_execute(acc));
  CHECK(dif_acc_set_ctrl_software_errs_fatal(acc, false) == kDifUnavailable);
  CHECK_STATUS_OK(acc_testutils_wait_for_done(acc, kDifAccErrBitsNoError));

  // Reading back result (c).
  CHECK_STATUS_OK(acc_testutils_read_data(acc, sizeof(c), kOupC, &c));

  for (int i = 0; i < sizeof(c); ++i) {
    CHECK(c[i] == c_expected[i],
          "Unexpected result c at byte %d: 0x%x (actual) != 0x%x (expected)", i,
          c[i], c_expected[i]);
  }

  check_acc_insn_cnt(acc, 174);
}

/**
 * Run err_test on ACC and check it produces the expected error
 *
 * This test tries to load from an invalid address which should result in the
 * kDifAccErrBitsBadDataAddr error bit being set
 *
 * The code executed on ACC can be found in sw/acc/code-snippets/err_test.s.
 * The entry point wrap_err_test() is called, no arguments are passed or results
 * returned.
 */
static void test_err_test(dif_acc_t *acc) {
  CHECK_STATUS_OK(acc_testutils_load_app(acc, kAppErrTest));

  // TODO: Turn on software_errs_fatal for err_test. Currently the model doesn't
  // support this feature so turning it on leads to a failure when run with the
  // model.
  CHECK_DIF_OK(dif_acc_set_ctrl_software_errs_fatal(acc, false));
  CHECK_STATUS_OK(acc_testutils_execute(acc));
  CHECK_STATUS_OK(
      acc_testutils_wait_for_done(acc, kDifAccErrBitsBadDataAddr));

  check_acc_insn_cnt(acc, 1);
}

static void test_sec_wipe(dif_acc_t *acc) {
  dif_acc_status_t acc_status;

  CHECK_DIF_OK(dif_acc_write_cmd(acc, kDifAccCmdSecWipeDmem));
  CHECK_DIF_OK(dif_acc_get_status(acc, &acc_status));
  CHECK(acc_status == kDifAccStatusBusySecWipeDmem);
  CHECK_STATUS_OK(acc_testutils_wait_for_done(acc, kDifAccErrBitsNoError));

  CHECK_DIF_OK(dif_acc_write_cmd(acc, kDifAccCmdSecWipeImem));
  CHECK_DIF_OK(dif_acc_get_status(acc, &acc_status));
  CHECK(acc_status == kDifAccStatusBusySecWipeImem);
  CHECK_STATUS_OK(acc_testutils_wait_for_done(acc, kDifAccErrBitsNoError));
}

bool test_main(void) {
  CHECK_STATUS_OK(entropy_testutils_auto_mode_init());

  dif_acc_t acc;
  CHECK_DIF_OK(dif_acc_init_from_dt(kTestAcc, &acc));

  test_barrett384(&acc);
  test_sec_wipe(&acc);
  test_err_test(&acc);

  return true;
}
