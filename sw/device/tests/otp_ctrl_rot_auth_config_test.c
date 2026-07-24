// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hw/top/dt/otp_ctrl.h"
#include "sw/device/lib/arch/device.h"
#include "sw/device/lib/dif/dif_otp_ctrl.h"
#include "sw/device/lib/testing/otp_ctrl_testutils.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_test_config.h"
#include "sw/device/silicon_creator/manuf/lib/individualize.h"
#include "sw/device/silicon_creator/manuf/lib/individualize_sw_cfg.h"

OTTF_DEFINE_TEST_CONFIG();

bool test_main(void) {
  dif_otp_ctrl_t otp_ctrl;
  CHECK_DIF_OK(dif_otp_ctrl_init_from_dt(kDtOtpCtrl, &otp_ctrl));
  CHECK_STATUS_OK(manuf_individualize_device_rot_owner_auth_slot0(&otp_ctrl));
  CHECK_STATUS_OK(manuf_individualize_device_rot_owner_auth_slot1(&otp_ctrl));
  CHECK_STATUS_OK(manuf_individualize_device_rot_owner_auth_slot2(&otp_ctrl));
  CHECK_STATUS_OK(manuf_individualize_device_rot_owner_auth_slot3(&otp_ctrl));
  CHECK_STATUS_OK(
      manuf_individualize_device_rot_owner_auth_slot0_state(&otp_ctrl));
  CHECK_STATUS_OK(
      manuf_individualize_device_rot_owner_auth_slot1_state(&otp_ctrl));
  CHECK_STATUS_OK(
      manuf_individualize_device_rot_owner_auth_slot2_state(&otp_ctrl));
  CHECK_STATUS_OK(
      manuf_individualize_device_rot_owner_auth_slot3_state(&otp_ctrl));
  if (kDeviceType == kDeviceSimDV) {
    test_status_set(kTestStatusPassed);
  }
  return true;
}
