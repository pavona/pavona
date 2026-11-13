// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include <stdbool.h>

#include "hw/top/dt/keymgr_dpe.h"
#include "hw/top/dt/otp_ctrl.h"
#include "hw/top/dt/rstmgr.h"
#include "sw/device/lib/base/mmio.h"
#include "sw/device/lib/dif/dif_keymgr_dpe.h"
#include "sw/device/lib/dif/dif_otp_ctrl.h"
#include "sw/device/lib/dif/dif_rstmgr.h"
#include "sw/device/lib/runtime/ibex.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/keymgr_dpe_testutils.h"
#include "sw/device/lib/testing/otp_ctrl_testutils.h"
#include "sw/device/lib/testing/rstmgr_testutils.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"
#include "sw/device/silicon_creator/lib/base/boot_measurements.h"
#include "sw/device/silicon_creator/lib/base/sec_mmio.h"
#include "sw/device/silicon_creator/lib/drivers/hmac.h"
#include "sw/device/silicon_creator/lib/drivers/otp.h"
#include "sw/device/silicon_creator/lib/manifest.h"
#include "sw/device/silicon_creator/lib/manifest_def.h"

#include "hw/top/otp_ctrl_regs.h"  // Generated

OTTF_DEFINE_TEST_CONFIG();

static dif_keymgr_dpe_t keymgr_dpe;
static dif_otp_ctrl_t otp_ctrl;
static dif_rstmgr_t rstmgr;
static uint32_t otp_state[kHmacDigestNumWords + 4] = {0};

static void print_otp_sw_cfg_digests(void) {
  uint64_t creator_digest, owner_digest, auth_slot0_digest, auth_slot1_digest,
           auth_slot2_digest, auth_slot3_digest = 0;
  CHECK_DIF_OK(dif_otp_ctrl_get_digest(
      &otp_ctrl, kDifOtpCtrlPartitionCreatorSwCfg, &creator_digest));
  CHECK_DIF_OK(dif_otp_ctrl_get_digest(
      &otp_ctrl, kDifOtpCtrlPartitionOwnerSwCfg, &owner_digest));
  CHECK_DIF_OK(dif_otp_ctrl_get_digest(
      &otp_ctrl, kDifOtpCtrlPartitionRotOwnerAuthSlot0, &auth_slot0_digest));
  CHECK_DIF_OK(dif_otp_ctrl_get_digest(
      &otp_ctrl, kDifOtpCtrlPartitionRotOwnerAuthSlot1, &auth_slot1_digest));
  CHECK_DIF_OK(dif_otp_ctrl_get_digest(
      &otp_ctrl, kDifOtpCtrlPartitionRotOwnerAuthSlot2, &auth_slot2_digest));
  CHECK_DIF_OK(dif_otp_ctrl_get_digest(
      &otp_ctrl, kDifOtpCtrlPartitionRotOwnerAuthSlot3, &auth_slot3_digest));
  LOG_INFO("CreatorSwCfg Digest: 0x%08x%08x", (uint32_t)(creator_digest >> 32),
           (uint32_t)creator_digest);
  LOG_INFO("OwnerSwCfg Digest:   0x%08x%08x", (uint32_t)(owner_digest >> 32),
           (uint32_t)owner_digest);
  LOG_INFO("RotOwnerAuthSlot0 Digest: 0x%08x%08x", (uint32_t)(auth_slot0_digest >> 32),
           (uint32_t)auth_slot0_digest);
  LOG_INFO("RotOwnerAuthSlot1 Digest: 0x%08x%08x", (uint32_t)(auth_slot1_digest >> 32),
           (uint32_t)auth_slot1_digest);
  LOG_INFO("RotOwnerAuthSlot2 Digest: 0x%08x%08x", (uint32_t)(auth_slot2_digest >> 32),
           (uint32_t)auth_slot2_digest);
  LOG_INFO("RotOwnerAuthSlot3 Digest: 0x%08x%08x", (uint32_t)(auth_slot3_digest >> 32),
           (uint32_t)auth_slot3_digest);
}

bool test_main(void) {
  CHECK_DIF_OK(
      dif_keymgr_dpe_init(mmio_region_from_addr(dt_keymgr_dpe_reg_block(
                              kDtKeymgrDpe, kDtKeymgrDpeRegBlockCore)),
                          &keymgr_dpe));
  CHECK_DIF_OK(dif_otp_ctrl_init(mmio_region_from_addr(dt_otp_ctrl_reg_block(
                                     kDtOtpCtrl, kDtOtpCtrlRegBlockCore)),
                                 &otp_ctrl));
  CHECK_DIF_OK(dif_rstmgr_init(mmio_region_from_addr(dt_rstmgr_reg_block(
                                   kDtRstmgrAon, kDtRstmgrRegBlockCore)),
                               &rstmgr));

  // If this is the first boot. lck measured OTP partitions and reset.
  if (UNWRAP(rstmgr_testutils_is_reset_info(&rstmgr, kDifRstmgrResetInfoPor))) {
    LOG_INFO("Power on reset. Locking OTP *SwCfg and *AuthSlot* partitions ...");
    const uint64_t kFakeOtpDigests[6] = {
        0x0000111122223333,
        0x4444555566667777,
        0x88889999aaaabbbb,
        0xccccddddeeeeffff,
        0x3333222211110000,
        0x7777666655554444,
    };
    CHECK_STATUS_OK(otp_ctrl_testutils_lock_partition(
        &otp_ctrl, kDifOtpCtrlPartitionCreatorSwCfg,
        /*digest=*/kFakeOtpDigests[0]));
    CHECK_STATUS_OK(otp_ctrl_testutils_lock_partition(
        &otp_ctrl, kDifOtpCtrlPartitionOwnerSwCfg,
        /*digest=*/kFakeOtpDigests[1]));
    CHECK_STATUS_OK(otp_ctrl_testutils_lock_partition(
        &otp_ctrl, kDifOtpCtrlPartitionRotOwnerAuthSlot0,
        /*digest=*/kFakeOtpDigests[2]));
    CHECK_STATUS_OK(otp_ctrl_testutils_lock_partition(
        &otp_ctrl, kDifOtpCtrlPartitionRotOwnerAuthSlot1,
        /*digest=*/kFakeOtpDigests[3]));
    CHECK_STATUS_OK(otp_ctrl_testutils_lock_partition(
        &otp_ctrl, kDifOtpCtrlPartitionRotOwnerAuthSlot2,
        /*digest=*/kFakeOtpDigests[4]));
    CHECK_STATUS_OK(otp_ctrl_testutils_lock_partition(
        &otp_ctrl, kDifOtpCtrlPartitionRotOwnerAuthSlot3,
        /*digest=*/kFakeOtpDigests[5]));
    rstmgr_testutils_reason_clear();
    LOG_INFO("Issuing a software reset ...");
    CHECK_DIF_OK(dif_rstmgr_software_device_reset(&rstmgr));
    wait_for_interrupt();
  } else {
    print_otp_sw_cfg_digests();
    LOG_INFO("SW reset. Executing test ...");
  }

  CHECK_STATUS_OK(
      keymgr_dpe_testutils_check_state(&keymgr_dpe, kDifKeymgrDpeStateReset));

  dif_keymgr_dpe_binding_value_t bindings;
  CHECK_DIF_OK(dif_keymgr_dpe_read_binding(&keymgr_dpe, &bindings));

  const manifest_t *manifest = manifest_def_get();

  if (otp_read32(OTP_CTRL_PARAM_OWNER_SW_CFG_ROM_KEYMGR_OTP_MEAS_EN_OFFSET) ==
      kHardenedBoolTrue) {
    LOG_INFO("ROM OTP measurement feature ENABLED.");
    // Check that the attestation is equal to the digest of concatenations of:
    //   - the digest of the CreatorSwCfg partition,
    //   - the digest of the OwnerSwCfg partition,
    //   - the SHA256 integrity hash of the first stage boot keys.
    CHECK_DIF_OK(dif_otp_ctrl_get_digest(&otp_ctrl,
                                         kDifOtpCtrlPartitionCreatorSwCfg,
                                         (uint64_t *)otp_state));
    CHECK_DIF_OK(dif_otp_ctrl_get_digest(&otp_ctrl,
                                         kDifOtpCtrlPartitionOwnerSwCfg,
                                         (uint64_t *)&otp_state[2]));
    CHECK_DIF_OK(dif_otp_ctrl_get_digest(&otp_ctrl,
                                         kDifOtpCtrlPartitionRotOwnerAuthSlot0,
                                         (uint64_t *)&otp_state[4]));
    CHECK_DIF_OK(dif_otp_ctrl_get_digest(&otp_ctrl,
                                         kDifOtpCtrlPartitionRotOwnerAuthSlot1,
                                         (uint64_t *)&otp_state[6]));
    CHECK_DIF_OK(dif_otp_ctrl_get_digest(&otp_ctrl,
                                         kDifOtpCtrlPartitionRotOwnerAuthSlot2,
                                         (uint64_t *)&otp_state[8]));
    CHECK_DIF_OK(dif_otp_ctrl_get_digest(&otp_ctrl,
                                         kDifOtpCtrlPartitionRotOwnerAuthSlot3,
                                         (uint64_t *)&otp_state[10]));
    hmac_digest_t otp_measurement;
    hmac_sha256(otp_state, sizeof(otp_state), &otp_measurement);
    LOG_INFO("OTP CreatorSwCfg Digest: 0x%08x%08x", otp_state[1], otp_state[0]);
    LOG_INFO("OTP OwnerSwCfg Digest:   0x%08x%08x", otp_state[3], otp_state[2]);
    LOG_INFO("OTP RotOwnerAuthSlot0 Digest:   0x%08x%08x", otp_state[5], otp_state[4]);
    LOG_INFO("OTP RotOwnerAuthSlot1 Digest:   0x%08x%08x", otp_state[7], otp_state[6]);
    LOG_INFO("OTP RotOwnerAuthSlot2 Digest:   0x%08x%08x", otp_state[9], otp_state[8]);
    LOG_INFO("OTP RotOwnerAuthSlot3 Digest:   0x%08x%08x", otp_state[11], otp_state[10]);

    CHECK_ARRAYS_EQ(bindings.binding, otp_measurement.digest,
                    ARRAYSIZE(bindings.binding));
  } else {
    LOG_INFO("ROM OTP measurement feature DISABLED.");
    // Check that the attestation is equal to `binding_value` field of the
    // manifest.
    CHECK_ARRAYS_EQ(bindings.binding, manifest->binding_value.data,
                    ARRAYSIZE(bindings.binding));
  }

  // Check that the creator max version is equal to `max_key_version` field of
  // the manifest.
  dif_keymgr_dpe_max_key_version_t versions;
  CHECK_DIF_OK(dif_keymgr_dpe_read_max_key_version(&keymgr_dpe, &versions));
  CHECK(versions.max_key_version == manifest->max_key_version);
  return true;
}
