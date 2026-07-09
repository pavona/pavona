// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hw/top/dt/lc_ctrl.h"
#include "hw/top/dt/otp_ctrl.h"
#include "sw/device/lib/base/abs_mmio.h"
#include "sw/device/lib/dif/dif_lc_ctrl.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"

#include "hw/top/otp_ctrl_regs.h"

OTTF_DEFINE_TEST_CONFIG();

bool test_main(void) {
  dif_lc_ctrl_t lc_ctrl;
  CHECK_DIF_OK(dif_lc_ctrl_init_from_dt(kDtLcCtrl, &lc_ctrl));

  dif_lc_ctrl_state_t state;
  CHECK_DIF_OK(dif_lc_ctrl_get_state(&lc_ctrl, &state));

  uint32_t rom_en = 1;
#if defined(OPENTITAN_IS_EGRET)
  const uint32_t otp_ctrl_base = dt_otp_ctrl_primary_reg_block(kDtOtpCtrl);
  rom_en = abs_mmio_read32(otp_ctrl_base + OTP_CTRL_SW_CFG_WINDOW_REG_OFFSET +
                           OTP_CTRL_PARAM_CREATOR_SW_CFG_ROM_EXEC_EN_OFFSET);
#elif defined(OPENTITAN_IS_DRAGONFLY)
  // Dragonfly lacks ROM_EXEC_EN, so set test status to wfi, do just that,
  // and wait for the vseq to change the lc state and reset us.
  if (state != kDifLcCtrlStateProd) {
    test_status_set(kTestStatusInWfi);
    // Infinite loop waiting for an interrupt
    abort();
  }
#else
#error Unsupported top
#endif

  if (rom_en == 0) {
    // The test should never reach here
    CHECK(false,
          "Unexpected branch - code not expected to execute since ROM "
          "execution is disabled");
  } else if (state == kDifLcCtrlStateProd && rom_en > 0) {
    // The test environment is waiting for this message
    LOG_INFO("ROM and test execution successful");
    return true;
  }

  LOG_INFO("Current state is 0x%x, rom_en is 0x%x", state, rom_en);
  return false;
}
