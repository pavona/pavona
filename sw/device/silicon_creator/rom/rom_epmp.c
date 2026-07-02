// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/silicon_creator/rom/rom_epmp.h"

#include "hw/top/dt/rom_ctrl.h"
#include "hw/top/dt/sram_ctrl.h"

#if HAS_FLASH_CTRL
#include "hw/top/dt/flash_ctrl.h"
#else
#include "hw/top/dt/soc_proxy.h"
#endif

#include "sw/device/lib/base/bitfield.h"
#include "sw/device/lib/base/csr.h"
#include "sw/device/lib/base/memory.h"
#include "sw/device/silicon_creator/lib/drivers/epmp.h"

// Symbols defined in linker script.
extern char _stack_start[];  // Lowest stack address.
extern char _text_start[];   // Start of executable code.
extern char _text_end[];     // End of executable code.

void rom_epmp_state_init(lifecycle_state_t lc_state) {
  // Address space definitions.
  //
  // Note that the stack guard is placed at _stack_start because the stack
  // grows downward from _stack_end.
  const epmp_region_t rom_text = {.start = (uintptr_t)_text_start,
                                  .end = (uintptr_t)_text_end};
  epmp_region_t rom = {
      .start = dt_rom_ctrl_memory_base(kDtRomCtrlFirst, kDtRomCtrlMemoryRom),
      .end = dt_rom_ctrl_memory_base(kDtRomCtrlFirst, kDtRomCtrlMemoryRom) +
             dt_rom_ctrl_memory_size(kDtRomCtrlFirst, kDtRomCtrlMemoryRom)};

#if defined(OPENTITAN_IS_EGRET)
  // In Egret, the silicon creator firmware lives in internal flash.
  epmp_region_t creator_fw = {
      .start = dt_flash_ctrl_memory_base(kDtFlashCtrl, kDtFlashCtrlMemoryMem),
      .end = dt_flash_ctrl_memory_base(kDtFlashCtrl, kDtFlashCtrlMemoryMem) +
             dt_flash_ctrl_memory_size(kDtFlashCtrl, kDtFlashCtrlMemoryMem)};
  const epmp_region_t mmio = {
      .start = TOP_EGRET_MMIO_BASE_ADDR,
      .end = TOP_EGRET_MMIO_BASE_ADDR + TOP_EGRET_MMIO_SIZE_BYTES};
#elif defined(OPENTITAN_IS_DRAGONFLY)
  const epmp_region_t mmio = {
      .start = TOP_DRAGONFLY_MMIO_BASE_ADDR,
      .end = TOP_DRAGONFLY_MMIO_BASE_ADDR + TOP_DRAGONFLY_MMIO_SIZE_BYTES};
#endif
  const epmp_region_t stack_guard = {.start = (uintptr_t)_stack_start,
                                     .end = (uintptr_t)_stack_start + 4};
  epmp_region_t ram = {
      .start = dt_sram_ctrl_memory_base(kDtSramCtrlMain, kDtSramCtrlMemoryRam),
      .end = dt_sram_ctrl_memory_base(kDtSramCtrlMain, kDtSramCtrlMemoryRam) +
             dt_sram_ctrl_memory_size(kDtSramCtrlMain, kDtSramCtrlMemoryRam)};

  // Initialize in-memory copy of ePMP register state.
  //
  // The actual hardware configuration is performed separately, either by reset
  // logic or in assembly. This code must be kept in sync with any changes
  // to the hardware configuration.
  memset(&epmp_state, 0, sizeof(epmp_state));
  epmp_state_configure_tor(1, rom_text, kEpmpPermLockedReadExecute);
  epmp_state_configure_napot(2, rom, kEpmpPermLockedReadOnly);
  epmp_state_configure_tor(11, mmio, kEpmpPermLockedReadWrite);
#ifdef OPENTITAN_IS_EGRET
  epmp_state_configure_napot(13, creator_fw, kEpmpPermLockedReadOnly);
#endif
  epmp_state_configure_na4(14, stack_guard, kEpmpPermLockedNoAccess);
  epmp_state_configure_napot(15, ram, kEpmpPermLockedReadWrite);
  epmp_state.mseccfg = EPMP_MSECCFG_MMWP | EPMP_MSECCFG_RLB;
}
