// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hw/top/dt/otp_ctrl.h"
#include "sw/device/lib/base/status.h"
#include "sw/device/lib/dif/dif_otp_ctrl.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"

OTTF_DEFINE_TEST_CONFIG();

dif_otp_ctrl_t otp;

bool test_main(void) {
  CHECK_DIF_OK(dif_otp_ctrl_init_from_dt(kDtOtpCtrl, &otp));

  dif_otp_ctrl_config_t config = {
      .check_timeout = 100000,
      .integrity_period_mask = 0x3ffff,
      .consistency_period_mask = 0x3ffffff,
  };

  LOG_INFO("dif_otp_ctrl_configure:");
  // Since the ePMP forbids access to the OTP controller's register space,
  // this call is expected to cause a fault.
  CHECK_DIF_OK(dif_otp_ctrl_configure(&otp, config));
  return true;
}
