// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/testing/keymgr_dpe_testutils.h"

#include "hw/top/dt/keymgr_dpe.h"
#include "hw/top/dt/otp_ctrl.h"
#include "hw/top/dt/rstmgr.h"
#include "sw/device/lib/dif/dif_keymgr_dpe.h"
#include "sw/device/lib/dif/dif_otp_ctrl.h"
#include "sw/device/lib/dif/dif_rstmgr.h"
#include "sw/device/lib/runtime/ibex.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/otp_ctrl_testutils.h"
#include "sw/device/lib/testing/rstmgr_testutils.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/silicon_creator/lib/base/chip.h"
#include "sw/device/silicon_creator/lib/base/sec_mmio.h"
#include "sw/device/silicon_creator/lib/drivers/kmac.h"

static bool check_lock_otp_partitions(const dif_otp_ctrl_t *otp,
                                      otp_partition_t partition) {
  bool is_computed;
  CHECK_DIF_OK(dif_otp_ctrl_is_digest_computed(otp, partition, &is_computed));
  if (is_computed) {
    uint64_t digest;
    CHECK_DIF_OK(dif_otp_ctrl_get_digest(otp, partition, &digest));
    LOG_INFO("OTP partition locked. Digest: %x-%x", ((uint32_t *)&digest)[0],
             ((uint32_t *)&digest)[1]);
    return false;
  }
  CHECK_STATUS_OK(otp_ctrl_testutils_lock_partition(otp, partition, 0));
  return true;
}

status_t keymgr_dpe_testutils_startup(dif_keymgr_dpe_t *keymgr_dpe,
                                      uint32_t slot_dst_sel) {
  dif_rstmgr_t rstmgr;
  TRY(dif_rstmgr_init_from_dt(kDtRstmgrAon, &rstmgr));

  dif_otp_ctrl_t otp;
  TRY(dif_otp_ctrl_init_from_dt(kDtOtpCtrl, &otp));
  bool needs_reset = check_lock_otp_partitions(&otp, kOtpPartitionSecret2);
  needs_reset =
      needs_reset | check_lock_otp_partitions(&otp, kOtpPartitionSecret3);
  if (needs_reset) {
    // Reboot device.
    rstmgr_testutils_reason_clear();
    LOG_INFO(
        "Locked SECRET2 and SECRET3 partitions. Triggering software reset");
    TRY(dif_rstmgr_software_device_reset(&rstmgr));

    // Wait here until device reset.
    wait_for_interrupt();

  } else {
    sec_mmio_init();
    kmac_keymgr_configure();

    LOG_INFO("Actuate keymgr_dpe and perform test.");

    // Initialize keymgr_dpe context.
    TRY(dif_keymgr_dpe_init_from_dt(kDtKeymgrDpe, keymgr_dpe));

    // Advance to Initialized state.
    TRY(keymgr_dpe_testutils_check_state(keymgr_dpe, kDifKeymgrDpeStateReset));
    TRY(dif_keymgr_dpe_initialize(keymgr_dpe, slot_dst_sel));
    TRY(keymgr_dpe_testutils_wait_for_operation_done(keymgr_dpe));
    TRY(keymgr_dpe_testutils_check_state(keymgr_dpe,
                                         kDifKeymgrDpeStateAvailable));
    LOG_INFO("OTP root secret is latched.");
  }
  return OK_STATUS();
}

status_t keymgr_dpe_testutils_advance_state(
    const dif_keymgr_dpe_t *keymgr_dpe,
    const dif_keymgr_dpe_advance_params_t *params) {
  TRY(dif_keymgr_dpe_advance_state(keymgr_dpe, params));
  return keymgr_dpe_testutils_wait_for_operation_done(keymgr_dpe);
}

status_t keymgr_dpe_testutils_erase_slot(
    const dif_keymgr_dpe_t *keymgr_dpe,
    const dif_keymgr_dpe_erase_params_t *params) {
  TRY(dif_keymgr_dpe_erase_slot(keymgr_dpe, params));
  return keymgr_dpe_testutils_wait_for_operation_done(keymgr_dpe);
}

status_t keymgr_dpe_testutils_generate(
    const dif_keymgr_dpe_t *keymgr_dpe,
    const dif_keymgr_dpe_generate_params_t *params,
    dif_keymgr_dpe_output_t *key) {
  TRY(dif_keymgr_dpe_generate(keymgr_dpe, params));
  TRY(keymgr_dpe_testutils_wait_for_operation_done(keymgr_dpe));
  TRY(dif_keymgr_dpe_read_output(keymgr_dpe, key));
  return OK_STATUS();
}

status_t keymgr_dpe_testutils_check_state(
    const dif_keymgr_dpe_t *keymgr_dpe,
    const dif_keymgr_dpe_state_t exp_state) {
  dif_keymgr_dpe_state_t act_state;
  TRY(dif_keymgr_dpe_get_state(keymgr_dpe, &act_state));
  TRY_CHECK(act_state == exp_state,
            "KeymgrDPE in unexpected state: %x, expected to be %x", act_state,
            exp_state);
  return OK_STATUS();
}

status_t keymgr_dpe_testutils_wait_for_operation_done(
    const dif_keymgr_dpe_t *keymgr_dpe) {
  dif_keymgr_dpe_status_codes_t status;
  do {
    TRY(dif_keymgr_dpe_get_status_codes(keymgr_dpe, &status));
  } while (status == 0);
  TRY_CHECK(status == kDifKeymgrDpeStatusCodeIdle, "Unexpected status: %x",
            status);
  return OK_STATUS();
}
