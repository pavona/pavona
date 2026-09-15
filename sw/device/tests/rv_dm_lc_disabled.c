// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hw/top/dt/rv_dm.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/lc_ctrl_testutils.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"
#include "sw/device/silicon_creator/lib/drivers/epmp.h"

#include "hw/top/rv_dm_regs.h"

enum {
  kTestData = 0xdeadbeef,
};

OTTF_DEFINE_TEST_CONFIG();

static volatile bool access_exception_seen;

void ottf_load_store_fault_handler(uint32_t *exc_info) {
  access_exception_seen = true;
}

status_t execute_test(bool debug_func) {
  mmio_region_t region =
      mmio_region_from_addr(dt_rv_dm_reg_block(kDtRvDm, kDtRvDmRegBlockMem));

  // Attempt to write to RV-DM register and read.
  access_exception_seen = false;
  mmio_region_write32(region, RV_DM_DATAADDR_0_REG_OFFSET, kTestData);
  CHECK(debug_func != access_exception_seen);

  access_exception_seen = false;
  (void)mmio_region_read32(region, RV_DM_DATAADDR_0_REG_OFFSET);
  CHECK(debug_func != access_exception_seen);

  return OK_STATUS();
}

bool test_main(void) {
  // Enable access to the RV_DM memory in ePMP. Slot 6 is used because slots
  // 0-5 are used to manage access to the boot stages.
  epmp_region_t rv_dm_region = {
      .start = dt_rv_dm_reg_block(kDtRvDm, kDtRvDmRegBlockMem),
      .end = dt_rv_dm_reg_block(kDtRvDm, kDtRvDmRegBlockMem) +
             RV_DM_ROM_REG_OFFSET + RV_DM_ROM_SIZE_BYTES,
  };
  epmp_set_napot(6, rv_dm_region, kEpmpPermLockedReadWrite);

  dif_lc_ctrl_t lc;
  CHECK_DIF_OK(dif_lc_ctrl_init(mmio_region_from_addr(dt_lc_ctrl_reg_block(
                                    kDtLcCtrl, kDtLcCtrlRegBlockRegs)),
                                &lc));

  bool debug_func = false;
  CHECK_STATUS_OK(lc_ctrl_testutils_debug_func_enabled(&lc, &debug_func));

  return status_ok(execute_test(debug_func));
}
