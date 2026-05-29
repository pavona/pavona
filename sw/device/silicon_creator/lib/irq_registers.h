// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_SILICON_CREATOR_LIB_IRQ_REGISTERS_H_
#define OPENTITAN_SW_DEVICE_SILICON_CREATOR_LIB_IRQ_REGISTERS_H_

/* Helpers to get register addresses in irq_asm.S . */

/**
 * Base address of the rstmgr registers.
 */
uint32_t rstmgr_reg_base(void);

#ifdef HAS_FLASH_CTRL
/**
 * Base address of the flash_ctrl registers.
 */
uint32_t flash_ctrl_reg_base(void);
#endif

#endif  // OPENTITAN_SW_DEVICE_SILICON_CREATOR_LIB_IRQ_REGISTERS_H_
