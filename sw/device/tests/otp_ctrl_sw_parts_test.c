// Copyright lowRISC contributors.
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include <assert.h>
#include <stdbool.h>

#include "hw/top/dt/otp_ctrl.h"  // Generated.
#include "hw/top/dt/rstmgr.h"    // Generated.
#include "sw/device/lib/base/bitfield.h"
#include "sw/device/lib/base/macros.h"
#include "sw/device/lib/base/memory.h"
#include "sw/device/lib/base/mmio.h"
#include "sw/device/lib/dif/dif_otp_ctrl.h"
#include "sw/device/lib/dif/dif_rstmgr.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/otp_ctrl_testutils.h"
#include "sw/device/lib/testing/rstmgr_testutils.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"

#if defined(OPENTITAN_IS_EGRET)
#include "hw/top_egret/sw/autogen/top_egret.h"
#endif

static dif_otp_ctrl_t otp;
static dif_rstmgr_t rstmgr;

OTTF_DEFINE_TEST_CONFIG();

/**
 * Random values used for programming tests.
 */
enum {
  kPart0Value = 0x04675214,
#if defined(OPENTITAN_IS_DRAGONFLY)
  kPart1Value = 0xc428c1a1,
  kPart2Value = 0xf51814b4,
#endif
};

/**
 * Programs and checks the first word of a partition.
 */
static void prog_test(const otp_partition_t partition, uint32_t value) {
  uint32_t result;
  CHECK_STATUS_OK(otp_ctrl_testutils_dai_read32(&otp, partition, 0, &result));
  CHECK_STATUS_OK(otp_ctrl_testutils_wait_for_dai(&otp));
  CHECK(result == 0);
  CHECK_STATUS_OK(
      otp_ctrl_testutils_dai_write32(&otp, partition, 0, &value, 1));
  CHECK_STATUS_OK(otp_ctrl_testutils_wait_for_dai(&otp));
  CHECK_STATUS_OK(otp_ctrl_testutils_dai_read32(&otp, partition, 0, &result));
  CHECK_STATUS_OK(otp_ctrl_testutils_wait_for_dai(&otp));
  CHECK(result == value);
}

/**
 * Prints each value for status.causes -- useful for debugging values in OTP
 * Status
 */
static void dump_otp_status(const char *tag) {
  dif_otp_ctrl_status_t status = {0};
  CHECK_DIF_OK(dif_otp_ctrl_get_status(&otp, &status));
  LOG_INFO("[%s] status.codes = 0x%08x", tag, status.codes);
  for (size_t i = 0; i < ARRAYSIZE(status.causes); ++i) {
    LOG_INFO("[%s]   causes[%d] = %d", tag, i, status.causes[i]);
  }
  LOG_INFO("[%s]   kDifOtpCtrlStatusCodeDaiError index = %d", tag,
           kDifOtpCtrlStatusCodeDaiError);
  LOG_INFO("[%s]   kDifOtpCtrlPartitionDaiError index = %d", tag,
           kDifOtpCtrlPartitionDaiError);
}

/**
 * Read-locks a partition and checks that reads are locked out.
 */

static void read_lock_test(const otp_partition_t partition) {
  uint32_t result;
  bool is_locked;
  dif_otp_ctrl_status_t status;
  // Before locking, reads should work.
  CHECK_STATUS_OK(otp_ctrl_testutils_dai_read32(&otp, partition, 0, &result));
  CHECK_DIF_OK(dif_otp_ctrl_get_status(&otp, &status));
  LOG_INFO("Pre-lock read: %x,  Pre-lock status: %x", result, status);
  CHECK(status.causes[kDifOtpCtrlPartitionDaiError] == kDifOtpCtrlErrorOk,
        "Not expecting DAI error");
  uint32_t dai_error =
      bitfield_bit32_read(status.codes, kDifOtpCtrlStatusCodeDaiError);
  LOG_INFO("DAI Error bitread: %d", dai_error);

  // Lock out read access.status
  CHECK_DIF_OK(dif_otp_ctrl_lock_reading(&otp, partition));
  CHECK_DIF_OK(dif_otp_ctrl_reading_is_locked(&otp, partition, &is_locked));
  CHECK(is_locked);
  LOG_INFO("Checked lock: is_locked = %x", is_locked);
  // Check again reading.
  CHECK_STATUS_OK(otp_ctrl_testutils_dai_read32(&otp, partition, 0, &result));
  CHECK_DIF_OK(dif_otp_ctrl_get_status(&otp, &status));
  LOG_INFO("Post-lock read: %x,  Post-lock status: %x", result, status);

  dai_error = bitfield_bit32_read(status.codes, kDifOtpCtrlStatusCodeDaiError);
  LOG_INFO("DAI Error bitread: %d", dai_error);
  CHECK(status.causes[kDifOtpCtrlPartitionDaiError] ==
            kDifOtpCtrlErrorLockedAccess,
        "Expecting DAI error");
}

/**
 * Check whether the write lock works.
 */
static void write_lock_test(const otp_partition_t partition, uint32_t value,
                            bool exp_write_err) {
  uint32_t result;
  dif_otp_ctrl_status_t status;
  // We still expect the same value that has been written before
  CHECK_STATUS_OK(otp_ctrl_testutils_dai_read32(&otp, partition, 0, &result));
  LOG_INFO("read result vs value: %x vs %x", result, value);
  CHECK(result == value);

  CHECK_DIF_OK(dif_otp_ctrl_get_status(&otp, &status));

  CHECK(status.causes[kDifOtpCtrlPartitionDaiError] == kDifOtpCtrlErrorOk,
        "Not expecting DAI error");

  uint32_t dai_error =
      bitfield_bit32_read(status.codes, kDifOtpCtrlStatusCodeDaiError);
  LOG_INFO("DAI Error bitread: %d", dai_error);

  CHECK_DIF_OK(dif_otp_ctrl_dai_program32(&otp, partition, 0, value));
  LOG_INFO("Try to program value: %x", value);

  CHECK_DIF_OK(dif_otp_ctrl_get_status(&otp, &status));

  dai_error = bitfield_bit32_read(status.codes, kDifOtpCtrlStatusCodeDaiError);
  LOG_INFO("DAI Error bitread: %d", dai_error);

  if (exp_write_err) {
    CHECK_STATUS_OK(otp_ctrl_testutils_dai_read32(&otp, partition, 0, &result));
    LOG_INFO("read result vs value: %x vs %x", result, value);

    CHECK(status.causes[kDifOtpCtrlPartitionDaiError] ==
              kDifOtpCtrlErrorLockedAccess,
          "Expecting DAI error");
    LOG_INFO("Expecting DAI error");
  } else {
    // Note: This will only throw no Error (e.g. kDifOtpCtrlErrorOk)
    // so long as the written value is the same as is currently
    // stored if it is a non-write-lockable partition
    CHECK(status.causes[kDifOtpCtrlPartitionDaiError] == kDifOtpCtrlErrorOk,
          "Not expecting DAI error");
    LOG_INFO("Not expecting DAI error");
  }
}

/**
 * Initialize the peripherals used in this test.
 */
static void init_peripherals(void) {
  CHECK_DIF_OK(dif_otp_ctrl_init_from_dt(kDtOtpCtrl, &otp));
  dif_otp_ctrl_config_t config = {
      .check_timeout = 100000,
      .integrity_period_mask = 0x3ffff,
      .consistency_period_mask = 0x3ffffff,
  };
  CHECK_DIF_OK(dif_otp_ctrl_configure(&otp, config));
  CHECK_DIF_OK(dif_rstmgr_init_from_dt(kDtRstmgrAon, &rstmgr));
}

bool test_main(void) {
  dif_rstmgr_reset_info_bitfield_t rst_info;
  init_peripherals();

  rst_info = rstmgr_testutils_reason_get();
  rstmgr_testutils_reason_clear();
  if (rst_info & kDifRstmgrResetInfoPor) {
    LOG_INFO("1) Prog/read tests");
    prog_test(kOtpPartitionOwnerSwCfg, kPart0Value);
    LOG_INFO("kOtpPartitionOwnerSwCfg: %x", kOtpPartitionOwnerSwCfg);
    LOG_INFO("kPart0Value: %x", kPart0Value);

#if defined(OPENTITAN_IS_DRAGONFLY)
    prog_test(kOtpPartitionOwnershipSlotState, kPart1Value);
    LOG_INFO("kOtpPartitionOwnershipSlotState: %x",
             kOtpPartitionOwnershipSlotState);
    LOG_INFO("kPart1Value: %x", kPart1Value);

    prog_test(kOtpPartitionExtNvm, kPart2Value);
    LOG_INFO("kOtpPartitionExtNvm: %x", kOtpPartitionExtNvm);
    LOG_INFO("kPart2Value: %x", kPart2Value);
#endif

    LOG_INFO("2) CSR read lock tests");

    LOG_INFO("read lock 1");
    read_lock_test(kOtpPartitionOwnerSwCfg);
#if defined(OPENTITAN_IS_DRAGONFLY)
    LOG_INFO("read lock 2");
    read_lock_test(kOtpPartitionOwnershipSlotState);

    LOG_INFO("read lock 3");
    read_lock_test(kOtpPartitionExtNvm);
#endif
    LOG_INFO("3) Write-lock partitions and reset chip to check locks");
    // This should succeed.
    CHECK_DIF_OK(
        dif_otp_ctrl_dai_digest(&otp, kOtpPartitionOwnerSwCfg, 0xAAAAAAAA));
#if defined(OPENTITAN_IS_DRAGONFLY)
    // These two should fail since the partitions do not have a digest.
    CHECK(dif_otp_ctrl_dai_digest(&otp, kOtpPartitionOwnershipSlotState,
                                  0xAAAAAAAA) == kDifBadArg);
    CHECK(dif_otp_ctrl_dai_digest(&otp, kOtpPartitionExtNvm, 0xAAAAAAAA) ==
          kDifBadArg);
#endif
    // Reset the chip
    CHECK_DIF_OK(dif_rstmgr_software_device_reset(&rstmgr));
    busy_spin_micros(100);
    CHECK(false, "Should have reset before this line");

  } else if (rst_info == kDifRstmgrResetInfoSw) {
    LOG_INFO("4) Check write-locks");
    // Expect an error due to the write-lock.
    LOG_INFO("check write lock 1: expects an error");
    write_lock_test(kOtpPartitionOwnerSwCfg, kPart0Value, true);
#if defined(OPENTITAN_IS_DRAGONFLY)
    // These two cannot be locked, hence we don't expect an error.
    LOG_INFO("check write lock 2: no error -- can't be locked");
    write_lock_test(kOtpPartitionOwnershipSlotState, kPart1Value, false);
    LOG_INFO("check write lock 3: no error -- can't be locked");
    write_lock_test(kOtpPartitionExtNvm, kPart2Value, false);
#endif
    // Test passed
    return true;
  } else {
    LOG_ERROR("Unexpected reset info 0x%02X", rst_info);
  }
  return false;
}
