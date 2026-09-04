// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_SILICON_CREATOR_SECOND_ROM_SECOND_ROM_EPMP_H_
#define OPENTITAN_SW_DEVICE_SILICON_CREATOR_SECOND_ROM_SECOND_ROM_EPMP_H_

#include <stdint.h>

#include "sw/device/silicon_creator/lib/drivers/lifecycle.h"
#include "sw/device/silicon_creator/lib/epmp_state.h"

#ifdef __cplusplus
extern "C" {
#endif  // __cplusplus

/**
 * ROM enhanced Physical Memory Protection (ePMP) library.
 *
 * The ePMP configuration is managed in two parts:
 *
 *   1. The actual hardware configuration held in CSRs
 *   2. The in-memory copy of register values in `epmp_state_t` that is used
 *      to verify the CSRs
 *
 * Every time the hardware configuration is updated the in-memory copy
 * must also be updated. The hardware configuration is usually interacted
 * with directly using the CSR library or assembly whereas the in-memory
 * copy of the state should normally be modified using configuration functions
 * from the silicon creator ePMP library.
 *
 * This separation of concerns allows the hardware configuration to be
 * updated efficiently as needed (including before the C runtime is
 * initialized) with the in-memory copy of the state used to double check the
 * configuration as required.
 */

/**
 * Initialise the ePMP in-memory copy of the register state to reflect the
 * hardware configuration expected at entry to the ROM C code.
 *
 * The actual hardware configuration is performed separately, either by reset
 * logic or in assembly. This code must be kept in sync with any changes
 * to the hardware configuration.
 *
 * @param lc_state The current lifecycle state to check for debug enable.
 */
void second_rom_epmp_state_init(void);

/**
 * Base address of the Mbox RAM.
 */
uint32_t sram_ctrl_mbox_ram_base(void);

/**
 * Size of the Mbox RAM.
 */
uint32_t sram_ctrl_mbox_ram_size(void);

/**
 * Base address of the CTN SRAM.
 */
uint32_t soc_proxy_ctn_base(void);

/**
 * Size of the CTN SRAM.
 */
uint32_t soc_proxy_ctn_size(void);

#ifdef __cplusplus
}  // extern "C"
#endif  // __cplusplus

#endif  // OPENTITAN_SW_DEVICE_SILICON_CREATOR_SECOND_ROM_SECOND_ROM_EPMP_H_
