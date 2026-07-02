// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/silicon_creator/second_rom/second_rom_epmp.h"

#include "hw/top/dt/rv_dm.h"
#include "hw/top/dt/soc_proxy.h"
#include "hw/top/dt/sram_ctrl.h"
#include "sw/device/lib/base/bitfield.h"
#include "sw/device/lib/base/csr.h"
#include "sw/device/lib/base/memory.h"
#include "sw/device/silicon_creator/lib/drivers/epmp.h"

#ifdef PAVONA_IS_DRAGONFLY
#include "hw/top_dragonfly/sw/autogen/top_dragonfly.h"
#endif

// Symbols defined in linker script.
extern char _rom_ext_virtual_start_address[];  // Start of ROM_EXT (VMA)
extern char _rom_ext_virtual_size[];           // Size of ROM_EXT (VMA)

void second_rom_epmp_state_init(void) {
  // Open Mailbox RAM and section of eFLASH/CTN containing ROM_EXT manifest.
  epmp_region_t ram_mbox = {
      .start = dt_sram_ctrl_memory_base(kDtSramCtrlMbox, kDtSramCtrlMemoryRam),
      .end = dt_sram_ctrl_memory_base(kDtSramCtrlMbox, kDtSramCtrlMemoryRam) +
             dt_sram_ctrl_memory_size(kDtSramCtrlMbox, kDtSramCtrlMemoryRam)};
  epmp_region_t rom_ext = {.start = TOP_DRAGONFLY_SOC_PROXY_RAM_CTN_BASE_ADDR,
                           .end = TOP_DRAGONFLY_SOC_PROXY_RAM_CTN_BASE_ADDR +
                                  (uintptr_t)_rom_ext_virtual_size};
  // Update ePMP hardware registers and in-memory state.
  epmp_set_napot(12, ram_mbox, kEpmpPermLockedReadWrite);
  epmp_set_napot(13, rom_ext, kEpmpPermLockedReadOnly);
}
