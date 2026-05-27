// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hw/top/dt/rstmgr.h"
#ifdef HAS_FLASH_CTRL
#include "hw/top/dt/flash_ctrl.h"
#endif

/* Helpers to get register addresses in irq_asm.S . */

/**
 * Base address of the rstmgr registers.
 */
uint32_t rstmgr_reg_base(void) {
  return dt_rstmgr_reg_block(kDtRstmgrAon, kDtRstmgrRegBlockCore);
}

#ifdef HAS_FLASH_CTRL
/**
 * Base address of the flash_ctrl registers.
 */
uint32_t flash_ctrl_reg_base(void) {
  return dt_flash_ctrl_reg_block(kDtFlashCtrl, kDtFlashCtrlRegBlockCore);
}
#endif
