// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hw/top/dt/sram_ctrl.h"
#include "sw/device/silicon_creator/lib/manifest_def.h"

// Note: Since this test program is written to verify the behavior of the ROM C
// exception handlers,
// - it does not have a `.crt` section,
// - its entrypoint `_rom_ext_start_boot()` is defined here and it doesn't have
// a `rom_ext_main()` function, and
// - it has only the following sections:
//   - `.manifest`, to be able to boot this program from ROM,
//   - `.text`, only 2 instructions to trigger an instruction access fault, and
//   - `.static_critical`, required by the linker script.

void _ottf_start(void) {
  ((void (*)(void))dt_sram_ctrl_memory_base(kDtSramCtrlMain,
                                            kDtSramCtrlMemoryRam))();
}
