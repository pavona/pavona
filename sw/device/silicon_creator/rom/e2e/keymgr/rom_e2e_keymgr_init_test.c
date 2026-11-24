// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hw/top/dt/keymgr.h"
#include "hw/top/dt/otp_ctrl.h"
#include "hw/top/dt/rstmgr.h"
#include "sw/device/lib/base/mmio.h"
#include "sw/device/lib/dif/dif_keymgr.h"
#include "sw/device/lib/dif/dif_otp_ctrl.h"
#include "sw/device/lib/dif/dif_rstmgr.h"
#include "sw/device/lib/runtime/ibex.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/keymgr_testutils.h"
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

OTTF_DEFINE_TEST_CONFIG();

static dif_keymgr_t keymgr;
static dif_otp_ctrl_t otp_ctrl;
static dif_rstmgr_t rstmgr;

static void measure_otp_partition(otp_partition_t partition) {
  dt_otp_partition_info_t partition_info =
      dt_otp_ctrl_partition(kDtOtpCtrl, partition);
  uint32_t buf[partition_info.size / sizeof(uint32_t)];
  otp_read(partition_info.start_addr, buf,
           partition_info.size / sizeof(uint32_t));
  hmac_sha256_update((unsigned char *)buf, partition_info.size);
}

bool test_main(void) {
  CHECK_DIF_OK(dif_keymgr_init(mmio_region_from_addr(dt_keymgr_reg_block(
                                   kDtKeymgr, kDtKeymgrRegBlockCore)),
                               &keymgr));
  CHECK_DIF_OK(dif_otp_ctrl_init(mmio_region_from_addr(dt_otp_ctrl_reg_block(
                                     kDtOtpCtrl, kDtOtpCtrlRegBlockCore)),
                                 &otp_ctrl));
  CHECK_DIF_OK(dif_rstmgr_init(mmio_region_from_addr(dt_rstmgr_reg_block(
                                   kDtRstmgrAon, kDtRstmgrRegBlockCore)),
                               &rstmgr));

  CHECK_STATUS_OK(keymgr_testutils_check_state(&keymgr, kDifKeymgrStateReset));

  dif_keymgr_binding_value_t bindings;
  CHECK_DIF_OK(dif_keymgr_read_binding(&keymgr, &bindings));

  const manifest_t *manifest = manifest_def_get();

  if (otp_read32(OTP_CTRL_PARAM_OWNER_SW_CFG_ROM_KEYMGR_OTP_MEAS_EN_OFFSET) ==
      kHardenedBoolTrue) {
    LOG_INFO("ROM OTP measurement feature ENABLED.");
    // Check that the attestation is equal to the digest of concatenations of:
    //   - the CreatorSwCfg partition,
    //   - the OwnerSwCfg partition,
    //   - the partitions containing the first stage boot keys.
    hmac_sha256_init();
    // Measure CREATOR_SW_CFG.
    measure_otp_partition(kOtpPartitionCreatorSwCfg);
    // Measure OWNER_SW_CFG.
    measure_otp_partition(kOtpPartitionOwnerSwCfg);
    // Measure the secure boot keys.
    measure_otp_partition(kOtpPartitionRotOwnerAuthSlot0);
    measure_otp_partition(kOtpPartitionRotOwnerAuthSlot1);
    measure_otp_partition(kOtpPartitionRotOwnerAuthSlot2);
    measure_otp_partition(kOtpPartitionRotOwnerAuthSlot3);

    hmac_sha256_process();
    hmac_digest_t otp_measurement;
    hmac_sha256_final(&otp_measurement);

    CHECK_ARRAYS_EQ(bindings.attestation, otp_measurement.digest,
                    ARRAYSIZE(bindings.attestation));
  } else {
    LOG_INFO("ROM OTP measurement feature DISABLED.");
    // Check that the attestation is equal to `binding_value` field of the
    // manifest.
    CHECK_ARRAYS_EQ(bindings.attestation, manifest->binding_value.data,
                    ARRAYSIZE(bindings.attestation));
  }

  // Check that the sealing is equal to `binding_value` field of the
  // manifest.
  CHECK_ARRAYS_EQ(bindings.sealing, manifest->binding_value.data,
                  ARRAYSIZE(bindings.sealing));

  // Check that the creator max version is equal to `max_key_version` field of
  // the manifest.
  dif_keymgr_max_key_version_t versions;
  CHECK_DIF_OK(dif_keymgr_read_max_key_version(&keymgr, &versions));
  CHECK(versions.creator_max_key_version == manifest->max_key_version);
  return true;
}
