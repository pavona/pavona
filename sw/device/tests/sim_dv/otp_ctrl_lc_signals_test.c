// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hw/top/dt/otp_ctrl.h"
#include "sw/device/lib/base/memory.h"
#include "sw/device/lib/base/mmio.h"
#include "sw/device/lib/dif/dif_kmac.h"
#include "sw/device/lib/dif/dif_lc_ctrl.h"
#include "sw/device/lib/dif/dif_otp_ctrl.h"
#include "sw/device/lib/dif/dif_rstmgr.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/kmac_testutils.h"
#include "sw/device/lib/testing/lc_ctrl_testutils.h"
#include "sw/device/lib/testing/otp_ctrl_testutils.h"
#include "sw/device/lib/testing/rstmgr_testutils.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_test_config.h"
#include "sw/device/silicon_creator/lib/base/chip.h"
#include "sw/device/silicon_creator/lib/drivers/retention_sram.h"

#if defined(OPENTITAN_IS_EGRET)
#include "sw/device/lib/dif/dif_flash_ctrl.h"
#include "sw/device/lib/dif/dif_keymgr.h"
#include "sw/device/lib/testing/keymgr_testutils.h"
#elif defined(OPENTITAN_IS_DRAGONFLY)
#include "sw/device/lib/dif/dif_alert_handler.h"
#include "sw/device/lib/dif/dif_keymgr_dpe.h"
#include "sw/device/lib/testing/keymgr_dpe_testutils.h"
#endif

#include "hw/top/otp_ctrl_regs.h"

static dif_lc_ctrl_t lc;
static dif_otp_ctrl_t otp;
static dif_rstmgr_t rstmgr;
static dif_kmac_t kmac;

#if defined(OPENTITAN_IS_EGRET)
static dif_flash_ctrl_state_t flash;
static dif_keymgr_t keymgr;
#elif defined(OPENTITAN_IS_DRAGONFLY)
static dif_alert_handler_t alert_handler;
static dif_keymgr_dpe_t keymgr_dpe;
#endif

// LC RMA token value in OTP SECRET2 partition.
static const uint8_t kOtpRmaToken[OTP_CTRL_PARAM_RMA_TOKEN_SIZE] = {
    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
    0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
};

// Root key share 0 in OTP SECRET2 partition.
static const uint8_t
    kOtpRootKeyShare0[OTP_CTRL_PARAM_CREATOR_ROOT_KEY_SHARE0_SIZE] = {
        0x6e, 0x70, 0x48, 0x68, 0xa3, 0x2f, 0xfa, 0x1b, 0xd8, 0x36, 0x4d,
        0x00, 0x79, 0xbd, 0x04, 0xe6, 0x53, 0x18, 0xfc, 0xc3, 0xc9, 0xdd,
        0x39, 0xfa, 0xe0, 0x18, 0x49, 0x69, 0xc9, 0x81, 0x05, 0x17,
};

// Root key share 1 in OTP SECRET2 partition.
static const uint8_t
    kOtpRootKeyShare1[OTP_CTRL_PARAM_CREATOR_ROOT_KEY_SHARE1_SIZE] = {
        0x2f, 0x78, 0x6f, 0x93, 0x9a, 0xc4, 0xcf, 0x95, 0xb6, 0xec, 0x61,
        0x76, 0xbd, 0x08, 0x05, 0x0c, 0x09, 0x89, 0xe1, 0x73, 0x4b, 0x0a,
        0x59, 0x1b, 0xdd, 0x34, 0x84, 0x82, 0x32, 0x9a, 0x93, 0x31};

#if defined(OPENTITAN_IS_DRAGONFLY)
// Creator seed in OTP SECRET2 partition.
static const uint8_t kOtpCreatorSeed[OTP_CTRL_PARAM_CREATOR_SEED_SIZE] = {
    0xb2, 0x95, 0xd2, 0x1b, 0xec, 0xdf, 0xbd, 0xcd, 0x67, 0xe7, 0xab,
    0x2d, 0x6f, 0x66, 0x0b, 0x08, 0x27, 0x3b, 0xf6, 0x5c, 0xe8, 0x0f,
    0x16, 0x95, 0x58, 0x6b, 0x80, 0xdb, 0xc3, 0xdb, 0xa2, 0x7e};

// Owner seed in OTP SECRET3 partition.
static const uint8_t kOtpOwnerSeed[OTP_CTRL_PARAM_OWNER_SEED_SIZE] = {
    0x69, 0xe7, 0x05, 0xa0, 0x65, 0xc2, 0xec, 0x6b, 0x04, 0xb0, 0xb6,
    0x34, 0x59, 0x31, 0x35, 0x26, 0x18, 0x58, 0xae, 0xe1, 0xd4, 0x9f,
    0x3b, 0xa9, 0x23, 0x0b, 0xcd, 0x38, 0xc1, 0xeb, 0x6b, 0x3e};
#endif

// Enum that encodes the possible test modes.
typedef enum { kWriteMode, kReadMode, kWriteReadMode } test_mode_t;

OTTF_DEFINE_TEST_CONFIG();

/**
 * Initialize the peripherals used in this test.
 */
static void init_peripherals(void) {
  dif_otp_ctrl_config_t config = {
      .check_timeout = 100000,
      .integrity_period_mask = 0x3ffff,
      .consistency_period_mask = 0x3ffffff,
  };
  // Life cycle
  CHECK_DIF_OK(dif_lc_ctrl_init_from_dt(kDtLcCtrl, &lc));
  // OTP
  CHECK_DIF_OK(dif_otp_ctrl_init_from_dt(kDtOtpCtrl, &otp));
  CHECK_DIF_OK(dif_otp_ctrl_configure(&otp, config));
  // Rstmgr
  CHECK_DIF_OK(dif_rstmgr_init_from_dt(kDtRstmgrAon, &rstmgr));
  // KMAC (init for Keymgr and KeymgrDPE use)
  CHECK_DIF_OK(dif_kmac_init_from_dt(kDtKmac, &kmac));
  CHECK_STATUS_OK(kmac_testutils_config(&kmac, true));
#if defined(OPENTITAN_IS_EGRET)
  // Keymgr
  CHECK_DIF_OK(dif_keymgr_init_from_dt(kDtKeymgr, &keymgr));
  // Flash
  CHECK_DIF_OK(dif_flash_ctrl_init_state_from_dt(&flash, kDtFlashCtrl));
#elif defined(OPENTITAN_IS_DRAGONFLY)
  // Alert Handler
  CHECK_DIF_OK(dif_alert_handler_init_from_dt(kDtAlertHandler, &alert_handler));
  // KeymgrDPE
  CHECK_DIF_OK(dif_keymgr_dpe_init_from_dt(kDtKeymgrDpe, &keymgr_dpe));
#endif
}

// The life cycle state the chip booted in, read once in test_main.
static dif_lc_ctrl_state_t lc_state;

/**
 * Returns whether a read of the given partition should succeed or fail.
 *
 * A locked partition refuses reads, except in RMA, where SECRET0, SECRET1 and
 * SECRET2 stay readable so the RMA token and the creator key material can be
 * read back. SECRET3 stays locked. Writes are refused either way.
 */
static exp_test_result_t read_exp_result(otp_partition_t partition,
                                         exp_test_result_t exp_result) {
  if (exp_result == kExpectFailed && lc_state == kDifLcCtrlStateRma &&
      partition != kOtpPartitionSecret3) {
    return kExpectPassed;
  }
  return exp_result;
}

/**
 * Attempt to write the buffer to the specified address within the given
 * partition. If exp_result is set to kExpectFailed, the test expects the
 * access to fail with a DAI access error. If exp_result is set to
 * kExpectPassed, the test expects the test to pass without errors.
 */
static void otp_write_test(uint32_t address, otp_partition_t partition,
                           const uint8_t *buffer, uint32_t size,
                           exp_test_result_t exp_result) {
  CHECK_STATUS_OK(otp_ctrl_testutils_wait_for_dai(&otp));
  for (uint32_t i = address; i < address + size; i += sizeof(uint64_t)) {
    uint64_t word;
    memcpy(&word, &buffer[i], sizeof(word));
    CHECK_DIF_OK(dif_otp_ctrl_dai_program64(&otp, partition, i, word));
    CHECK_STATUS_OK(otp_ctrl_testutils_wait_for_dai(&otp));
    CHECK(address <= INT32_MAX, "address must fit into int32_t");
    CHECK_STATUS_OK(otp_ctrl_testutils_dai_access_error_check(
        &otp, exp_result, (int32_t)address));
  }
}

/**
 * Attempt to read the OTP contents at the specified address within the given
 * partition, and compares the read data to the data in the buffer. If
 * exp_result is set to kExpectFailed, the test expects the access to fail
 * with a DAI access error, and it also expects the read data to NOT match with
 * the data in the buffer. If exp_result is set to kExpectPassed, the test
 * expects the test to pass without errors and the read data to match with the
 * data in the buffer.
 */
static void otp_read_test(uint32_t address, otp_partition_t partition,
                          const uint8_t *buffer, uint32_t size,
                          exp_test_result_t exp_result) {
  CHECK_STATUS_OK(otp_ctrl_testutils_wait_for_dai(&otp));
  for (uint32_t i = address; i < address + size; i += sizeof(uint64_t)) {
    uint64_t got, exp;
    CHECK_DIF_OK(dif_otp_ctrl_dai_read_start(&otp, partition, i));
    CHECK_STATUS_OK(otp_ctrl_testutils_wait_for_dai(&otp));
    CHECK(address <= INT32_MAX, "address must fit into int32_t");
    CHECK_STATUS_OK(otp_ctrl_testutils_dai_access_error_check(
        &otp, exp_result, (int32_t)address));

    // Check whether the read data matches.
    memcpy(&exp, &buffer[i], sizeof(exp));
    CHECK_DIF_OK(dif_otp_ctrl_dai_read64_end(&otp, &got));
    if (exp_result == kExpectFailed) {
      CHECK(got != exp,
            "0x%x == 0x%x (got == exp) is not expected at address 0x%x",
            (uint32_t)got, (uint32_t)exp, address);
    } else {
      CHECK(got == exp,
            "0x%x != 0x%x (got != exp) is not expected at address 0x%x",
            (uint32_t)got, (uint32_t)exp, address);
    }
  }
}

/**
 * Test wrapper function that first calls the write and then the read test.
 */
static void otp_write_read_test(test_mode_t test_mode, uint32_t address,
                                otp_partition_t partition,
                                const uint8_t *buffer, uint32_t size,
                                exp_test_result_t exp_result) {
  if (test_mode == kWriteMode || test_mode == kWriteReadMode) {
    LOG_INFO("Write test at 0x%x...", address);
    otp_write_test(address, partition, buffer, size, exp_result);
  }
  if (test_mode == kReadMode || test_mode == kWriteReadMode) {
    LOG_INFO("Read test at 0x%x...", address);
    otp_read_test(address, partition, buffer, size,
                  read_exp_result(partition, exp_result));
  }
}

/**
 * Test wrapper function that calls the write and read tests above for all
 * objects within the SECRET2 and optionally SECRET3 partitions.
 */
static void run_otp_access_tests(test_mode_t test_mode,
                                 exp_test_result_t exp_result) {
  otp_write_read_test(
      test_mode,
      OTP_CTRL_PARAM_RMA_TOKEN_OFFSET - OTP_CTRL_PARAM_SECRET2_OFFSET,
      kOtpPartitionSecret2, (uint8_t *)kOtpRmaToken,
      OTP_CTRL_PARAM_RMA_TOKEN_SIZE, exp_result);
  otp_write_read_test(test_mode,
                      OTP_CTRL_PARAM_CREATOR_ROOT_KEY_SHARE0_OFFSET -
                          OTP_CTRL_PARAM_SECRET2_OFFSET,
                      kOtpPartitionSecret2, (uint8_t *)kOtpRootKeyShare0,
                      OTP_CTRL_PARAM_CREATOR_ROOT_KEY_SHARE0_SIZE, exp_result);
  otp_write_read_test(test_mode,
                      OTP_CTRL_PARAM_CREATOR_ROOT_KEY_SHARE1_OFFSET -
                          OTP_CTRL_PARAM_SECRET2_OFFSET,
                      kOtpPartitionSecret2, (uint8_t *)kOtpRootKeyShare1,
                      OTP_CTRL_PARAM_CREATOR_ROOT_KEY_SHARE1_SIZE, exp_result);
#if defined(OPENTITAN_IS_DRAGONFLY)
  otp_write_read_test(
      test_mode,
      OTP_CTRL_PARAM_CREATOR_SEED_OFFSET - OTP_CTRL_PARAM_SECRET2_OFFSET,
      kOtpPartitionSecret2, (uint8_t *)kOtpCreatorSeed,
      OTP_CTRL_PARAM_CREATOR_SEED_SIZE, exp_result);
  otp_write_read_test(
      test_mode,
      OTP_CTRL_PARAM_OWNER_SEED_OFFSET - OTP_CTRL_PARAM_SECRET3_OFFSET,
      kOtpPartitionSecret3, (uint8_t *)kOtpOwnerSeed,
      OTP_CTRL_PARAM_OWNER_SEED_SIZE, exp_result);
#endif
}

/**
 * Try to initialize and advance to kDifKeymgrStateCreatorRootKey state.
 *
 * @param expect_init_fail Whether initialization is expected to fail.
 */
static void keymgr_advance_to_creator_root_key(bool expect_init_fail) {
#if defined(OPENTITAN_IS_EGRET)
  // Check the last word of the retention SRAM creator area to determine the
  // type of the ROM.
  bool is_using_test_rom =
      retention_sram_get()
          ->creator
          .reserved[ARRAYSIZE((retention_sram_t){0}.creator.reserved) - 1] ==
      TEST_ROM_IDENTIFIER;

  // Advance from Reset to Initialized state (or expect it to fail).
  CHECK_STATUS_OK(keymgr_testutils_check_state(&keymgr, kDifKeymgrStateReset));
  CHECK_STATUS_OK(keymgr_testutils_advance_state(&keymgr, NULL));
  const dif_keymgr_state_t exp_state =
      expect_init_fail ? kDifKeymgrStateInvalid : kDifKeymgrStateInitialized;
  CHECK_STATUS_OK(keymgr_testutils_check_state(&keymgr, exp_state));

  // Advance to Creator Root Key state (or expect it to fail as well).
  if (is_using_test_rom) {
    LOG_INFO("Using test_rom, setting inputs and advancing state...");
    CHECK((kDifOk == dif_keymgr_advance_state(&keymgr, &kCreatorParams)) ^
          expect_init_fail);
  } else {
    LOG_INFO("Using rom, only advancing state...");
    CHECK((kDifOk == dif_keymgr_advance_state_raw(&keymgr)) ^ expect_init_fail);
  }
#elif defined(OPENTITAN_IS_DRAGONFLY)
  // Advance from Reset to Available state, loading OTP secret shares (or expect
  // it to fail).
  CHECK_STATUS_OK(
      keymgr_dpe_testutils_check_state(&keymgr_dpe, kDifKeymgrDpeStateReset));
  CHECK(kDifOk == dif_keymgr_dpe_initialize(&keymgr_dpe, 0));
  CHECK_STATUS_OK(keymgr_dpe_testutils_wait_for_operation_done(&keymgr_dpe));
  const dif_keymgr_dpe_state_t exp_state = expect_init_fail
                                               ? kDifKeymgrDpeStateInvalid
                                               : kDifKeymgrDpeStateAvailable;
  CHECK_STATUS_OK(keymgr_dpe_testutils_check_state(&keymgr_dpe, exp_state));

  // Advance to Creator Root Key state (or expect it to fail as well).
  dif_keymgr_dpe_advance_params_t params = {
      .binding_value = {0xdc96c23d, 0xaf36e268, 0xcb68ff71, 0xe92f76e2,
                        0xb8a8379d, 0x426dc745, 0x19f5cff7, 0x4ec9c6d6},
      .max_key_version = 0x11,
      .slot_src_sel = 0,
      .slot_dst_sel = 0,
      .slot_policy = 1 << 0,
  };
  if (!expect_init_fail) {
    CHECK_STATUS_OK(keymgr_dpe_testutils_advance_state(&keymgr_dpe, &params));
    CHECK_STATUS_OK(keymgr_dpe_testutils_check_state(&keymgr_dpe, exp_state));
  } else {
    CHECK_DIF_OK(dif_keymgr_dpe_advance_state(&keymgr_dpe, &params));
    dif_keymgr_dpe_status_codes_t status;
    // Wait for operation to finish, confirm status and state.
    do {
      CHECK_DIF_OK(dif_keymgr_dpe_get_status_codes(&keymgr_dpe, &status));
    } while (status == 0);
    CHECK(status == (kDifKeymgrDpeStatusCodeIdle |
                     kDifKeymgrDpeStatusCodeInvalidOperation));
    CHECK_STATUS_OK(keymgr_dpe_testutils_check_state(&keymgr_dpe, exp_state));
  }
#endif
}

/**
 * Checks that the first advance command does not complete.
 */
static void keymgr_check_cannot_advance(void) {
  LOG_INFO("Check that the Keymgr cannot advance...");
#if defined(OPENTITAN_IS_EGRET)
  CHECK_STATUS_OK(keymgr_testutils_check_state(&keymgr, kDifKeymgrStateReset));
  // Try to initialize the key manager. We expect this call to fail with
  // a "kDifLocked" code, since the key manager is not enabled.
  CHECK(kDifLocked == dif_keymgr_advance_state(&keymgr, NULL),
        "Keymgr is not expected to be available in this LC state.");
#elif defined(OPENTITAN_IS_DRAGONFLY)
  CHECK_STATUS_OK(
      keymgr_dpe_testutils_check_state(&keymgr_dpe, kDifKeymgrDpeStateReset));
  // Try to initialize the key manager. We expect this call to fail with
  // a "kDifLocked" code, since the key manager is not enabled.
  dif_keymgr_dpe_advance_params_t invalid_params = {0};
  CHECK(
      kDifLocked == dif_keymgr_dpe_advance_state(&keymgr_dpe, &invalid_params),
      "KeymgrDPE is not expected to be available in this LC state.");
#endif
}

/**
 * Check that the key manager flags the KMAC inputs as invalid. This happens
 * when the root keys are not valid and hence tied to all-zero inside the key
 * manager.
 */
static void keymgr_check_root_key_is_invalid(void) {
  LOG_INFO("Trying to advance to Creator Root Key and expecting failure...");
#if defined(OPENTITAN_IS_DRAGONFLY)
  // On Keymgr DPE, this generates an alert, which is expected, so we disable
  // if it is currently enabled and restore it after.
  dt_alert_id_t keymgr_dpe_recov_op_alert = dt_keymgr_dpe_alert_to_alert_id(
      kDtKeymgrDpe, kDtKeymgrDpeAlertRecovOperationErr);
  CHECK_DIF_OK(dif_alert_handler_alert_set_enabled(
      &alert_handler, keymgr_dpe_recov_op_alert, kDifToggleDisabled));
#endif
  keymgr_advance_to_creator_root_key(/*expect_init_fail=*/true);
#if defined(OPENTITAN_IS_DRAGONFLY)
  // Re-enable alert.
  CHECK_DIF_OK(dif_alert_handler_alert_set_enabled(
      &alert_handler, keymgr_dpe_recov_op_alert, kDifToggleEnabled));
#endif
}

/**
 * Generate a SW key and store it within the retention SRAM.
 */
static void keymgr_check_can_generate_key(void) {
  LOG_INFO("Trying to advance to Creator Root Key and expecting success...");
  keymgr_advance_to_creator_root_key(/*expect_init_fail=*/false);
#if defined(OPENTITAN_IS_EGRET)
  LOG_INFO("Check that the Keymgr can generate a key...");
  CHECK_STATUS_OK(keymgr_testutils_wait_for_operation_done(&keymgr));
  CHECK_STATUS_OK(
      keymgr_testutils_check_state(&keymgr, kDifKeymgrStateCreatorRootKey));
  CHECK_STATUS_OK(
      keymgr_testutils_generate_versioned_key(&keymgr, kKeyVersionedParams));
#elif defined(OPENTITAN_IS_DRAGONFLY)
  LOG_INFO("Check that the KeymgrDPE can generate a key...");
  CHECK_STATUS_OK(keymgr_dpe_testutils_wait_for_operation_done(&keymgr_dpe));
  CHECK_STATUS_OK(keymgr_dpe_testutils_check_state(
      &keymgr_dpe, kDifKeymgrDpeStateAvailable));
  dif_keymgr_dpe_generate_params_t params = {
      .key_dest = kDifKeymgrDpeKeyDestNone,
      .sideload_key = false,
      .salt =
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
      .version = 0x11,
      .slot_src_sel = 0,
  };
  dif_keymgr_dpe_output_t key;
  CHECK_STATUS_OK(keymgr_dpe_testutils_generate(&keymgr_dpe, &params, &key));
#endif
}

/**
 * Resets the chip.
 */
static void reset_chip(void) {
  CHECK_DIF_OK(dif_rstmgr_software_device_reset(&rstmgr));
  busy_spin_micros(100);
  CHECK(false, "Should have reset before this line");
}

/**
 * This tests the impact of the lc_creator_seed_sw_rw_en and lc_seed_hw_rd_en
 * life cycle access control signals on the SECRET2 partition. Since it uses
 * the key manager to perform some of the testing, this test also checks the
 * impact of lc_keymgr_en on the key manager.
 *
 * The SECRETT2 partition should only be readable/writable by SW in
 * PROD/RMA/DEV. Once it is locked, the partition is not accessible by SW
 * anymore, but becomes accessible to HW (key manager).
 *
 * The test can be run in different life cycle states and figure out what to
 * check based on the state exposed in the life cycle controller.
 *
 * PROD/DEV/RMA:
 * 1)  Provision non-constant creator/owner secrets to flash
 * 2)  Program SECRET2 partition and read it back
 * 3)  Check that the key manager advance errors out due to all-zero root key
 * 4)  Reset the chip
 * 5)  Check that the SECRET2 partition can still be read
 * 6)  Check that the key manager advance errors out due to all-zero root key
 * 7)  Lock the SECRET2 partition
 * 8)  Reset the chip
 * 9)  Check that the SECRET2 partition is not accessible anymore
 * 10) Check that the key manager can generate a SW key without errors
 *
 * All other life cycle states:
 * 1) Check that key manager cannot be initialized because it is disabled
 * 2) Check the SECRET2 partition is not accessible
 *
 */
bool test_main(void) {
  bool is_computed;
  dif_lc_ctrl_state_t state;
  dif_rstmgr_reset_info_bitfield_t rst_info;
  init_peripherals();

  rst_info = rstmgr_testutils_reason_get();
  rstmgr_testutils_reason_clear();

  CHECK_DIF_OK(dif_lc_ctrl_get_state(&lc, &state));
  lc_state = state;
  CHECK_STATUS_OK(lc_ctrl_testutils_lc_state_log(&state));

  switch (state) {
    case kDifLcCtrlStateDev:
    case kDifLcCtrlStateProd:
    case kDifLcCtrlStateProdEnd:
    case kDifLcCtrlStateRma:
      if (rst_info & kDifRstmgrResetInfoPor) {
        LOG_INFO("First access test iteration...");
#if defined(OPENTITAN_IS_EGRET)
        // Make sure the secrets in flash are non-zero.
        CHECK_STATUS_OK(keymgr_testutils_flash_init(&flash, &kCreatorSecret,
                                                    &kOwnerSecret));
#endif
        // Program the SECRET partitions and perform read back test.
        run_otp_access_tests(kWriteReadMode, kExpectPassed);
        // We expect the root key to be invalid at this point.
        keymgr_check_root_key_is_invalid();
        reset_chip();

      } else if (rst_info == kDifRstmgrResetInfoSw) {
        CHECK_DIF_OK(dif_otp_ctrl_is_digest_computed(&otp, kOtpPartitionSecret2,
                                                     &is_computed));
#if defined(OPENTITAN_IS_DRAGONFLY)
        bool secret3_is_computed;
        CHECK_DIF_OK(dif_otp_ctrl_is_digest_computed(
            &otp, kOtpPartitionSecret3, &secret3_is_computed));
        is_computed = is_computed && secret3_is_computed;
#endif

        if (!is_computed) {
          LOG_INFO("Second access test iteration...");
          // SECRET partitions should still be readable.
          run_otp_access_tests(kReadMode, kExpectPassed);
          // We expect the root key to still be invalid at this point, since
          // SECRET partitions have not been locked yet.
          keymgr_check_root_key_is_invalid();
          // Lock the SECRET2 partition.
          CHECK_STATUS_OK(otp_ctrl_testutils_lock_partition(
              &otp, kOtpPartitionSecret2, 0));
#if defined(OPENTITAN_IS_DRAGONFLY)
          // Lock the SECRET3 partition.
          CHECK_STATUS_OK(otp_ctrl_testutils_lock_partition(
              &otp, kOtpPartitionSecret3, 0));
#endif
          reset_chip();
        } else {
          LOG_INFO("Third access test iteration...");
          // All accesses are disallowed.
          run_otp_access_tests(kWriteReadMode, kExpectFailed);
          // At this point we expect that the key manager can generate keys
          // without errors.
          keymgr_check_can_generate_key();
          // Test passed.
          return true;
        }
      } else {
        LOG_ERROR("Unexpected reset info 0x%02X", rst_info);
      }

      break;
    default:  // this covers all TEST_UNLOCKED* states.
      // Accesses to the SECRET partitions should error out.
      run_otp_access_tests(kWriteReadMode, kExpectFailed);
      // Keymgr initialization should not work in this state.
      keymgr_check_cannot_advance();
      // Test passed.
      return true;
  }

  return false;
}
