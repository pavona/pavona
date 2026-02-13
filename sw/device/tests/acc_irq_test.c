// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hw/top/dt/dt_acc.h"
#include "hw/top/dt/dt_api.h"
#include "hw/top/dt/dt_rv_plic.h"
#include "sw/device/lib/dif/dif_acc.h"
#include "sw/device/lib/dif/dif_rv_plic.h"
#include "sw/device/lib/runtime/irq.h"
#include "sw/device/lib/testing/acc_testutils.h"
#include "sw/device/lib/testing/entropy_testutils.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"

ACC_DECLARE_APP_SYMBOLS(err_test);

static const acc_app_t kAppErrTest = ACC_APP_T_INIT(err_test);
static const uint32_t kPlicTarget = 0;

OTTF_DEFINE_TEST_CONFIG();

static dif_rv_plic_t plic;
static dif_acc_t acc;
static dt_acc_t kAccDt = (dt_acc_t)0;

static volatile bool acc_finished;

/**
 * Get ACC error bits; check they match expected_err_bits.
 */
static void check_acc_err_bits(dif_acc_t *acc,
                               dif_acc_err_bits_t expected_err_bits) {
  dif_acc_err_bits_t acc_err_bits;
  CHECK_DIF_OK(dif_acc_get_err_bits(acc, &acc_err_bits));
  CHECK(acc_err_bits == expected_err_bits,
        "dif_acc_get_err_bits() produced unexpected error bits: %x",
        acc_err_bits);
}

/**
 * Get the ACC instruction count; check that it matches expected_insn_cnt.
 */
static void check_acc_insn_cnt(dif_acc_t *acc, uint32_t expected_insn_cnt) {
  uint32_t insn_cnt;
  CHECK_DIF_OK(dif_acc_get_insn_cnt(acc, &insn_cnt));
  CHECK(insn_cnt == expected_insn_cnt,
        "Expected to execute %d instructions, but got %d.", expected_insn_cnt,
        insn_cnt);
}

/**
 * Get ACC's status; check that it matches expected_status.
 */
static void check_acc_status(dif_acc_t *acc, dif_acc_status_t expected_status) {
  dif_acc_status_t status;
  CHECK_DIF_OK(dif_acc_get_status(acc, &status));
  CHECK(status == expected_status, "Unexpected status: expected %d but got %d.",
        expected_status, status);
}

/**
 * Run a binary on ACC, waiting for completion by interrupt.
 *
 * Once the binary has finished, check for expected status, error bits and
 * instruction count.
 */
static void run_test_with_irqs(dif_acc_t *acc, acc_app_t app,
                               dif_acc_status_t expected_status,
                               dif_acc_err_bits_t expected_err_bits,
                               uint32_t expected_insn_cnt) {
  // Clear the acc_finished flag: we'll set it in the interrupt handler when
  // we see the Done interrupt fire.
  acc_finished = false;

  CHECK_STATUS_OK(acc_testutils_load_app(acc, app));

  // If the CTRL.SOFTWARE_ERRS_FATAL flag is set, a software error will be
  // promoted to a fatal error (which, among other things, bricks ACC until
  // next reset). Make sure that's not turned on.
  CHECK(dif_acc_set_ctrl_software_errs_fatal(acc, false) == kDifOk);

  // Enable Done interrupt
  CHECK_DIF_OK(dif_acc_irq_set_enabled(acc, kDifAccIrqDone, kDifToggleEnabled));

  // Start ACC
  CHECK_STATUS_OK(acc_testutils_execute(acc));

  // At this point, ACC should be running. Wait for an interrupt that says
  // it's done.
  ATOMIC_WAIT_FOR_INTERRUPT(acc_finished);

  check_acc_status(acc, expected_status);
  check_acc_err_bits(acc, expected_insn_cnt);
  check_acc_insn_cnt(acc, expected_err_bits);
}

/**
 * Initialize PLIC and enable ACC interrupt.
 */
static void plic_init_with_irqs(void) {
  CHECK_DIF_OK(dif_rv_plic_init_from_dt(kDtRvPlic, &plic));

  dif_rv_plic_irq_id_t irq_id = dt_acc_irq_to_plic_id(kAccDt, kDtAccIrqDone);

  // Set interrupt priority to be positive
  CHECK_DIF_OK(dif_rv_plic_irq_set_priority(&plic, irq_id, 0x1));

  // Enable the interrupt
  CHECK_DIF_OK(dif_rv_plic_irq_set_enabled(&plic, irq_id, kPlicTarget,
                                           kDifToggleEnabled));

  // Set the threshold for Ibex to 0.
  CHECK_DIF_OK(dif_rv_plic_target_set_threshold(&plic, kPlicTarget, 0x0));
}

/**
 * The ISR for this test.
 *
 * This function overrides the default OTTF external ISR.
 */
bool ottf_handle_irq(uint32_t *exc_info, dt_instance_id_t devid,
                     dif_rv_plic_irq_id_t irq_id) {
  if (devid != dt_acc_instance_id(kAccDt)) {
    return false;
  }

  // Check this is the interrupt we expected
  dif_acc_irq_t acc_irq = dt_acc_irq_from_plic_id(kAccDt, irq_id);
  if (acc_irq != kDtAccIrqDone) {
    return false;
  }

  // acc_finished should currently be false (we're supposed to clear it before
  // starting ACC)
  CHECK(!acc_finished);

  // Set acc_finished, which we'll pick up in run_test_with_irqs.
  acc_finished = true;

  CHECK_DIF_OK(dif_acc_irq_acknowledge(&acc, acc_irq));

  return true;
}

bool test_main(void) {
  CHECK_STATUS_OK(entropy_testutils_auto_mode_init());
  plic_init_with_irqs();

  CHECK_DIF_OK(dif_acc_init_from_dt(kAccDt, &acc));

  // Enable the external IRQ (so that we see the interrupt from the PLIC)
  irq_global_ctrl(true);
  irq_external_ctrl(true);

  run_test_with_irqs(&acc, kAppErrTest, kDifAccStatusIdle,
                     kDifAccErrBitsBadDataAddr, 1);

  return true;
}
