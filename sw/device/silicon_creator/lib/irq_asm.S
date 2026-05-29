// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/base/multibits_asm.h"
#include "hw/top/rstmgr_regs.h"

#ifdef HAS_FLASH_CTRL
#include "hw/top/flash_ctrl_regs.h"
#endif

  // Place this code into the .crt section to be able to call it early in
  // the boot process before ePMP is reconfigured.
  //
  // NOTE: The "ax" flag below is necessary to ensure that this section
  // is allocated executable space in ROM by the linker.
  .section .crt, "ax"

  /**
   * Exception handler that is safe to call before the C runtime has been
   * initialized. It must not use the stack or global pointer.
   *
   * The exception handler will use the reset manager to trigger a reset.
   */
  .balign 4
  .global _asm_exception_handler
  .type _asm_exception_handler, @function
_asm_exception_handler:
.L_exception_loop:
  .extern rstmgr_reg_base
  // Request a system reset.
  call rstmgr_reg_base
  li t1, MULTIBIT_ASM_BOOL4_TRUE
  sw t1, RSTMGR_RESET_REQ_REG_OFFSET(a0)

#ifdef HAS_FLASH_CTRL
  .extern flash_ctrl_reg_base
  // Disable access to flash.
  //
  // This is done after requesting a reset so that this function will
  // work even if it is in flash.
  call flash_ctrl_reg_base
  sw zero, FLASH_CTRL_DIS_REG_OFFSET(a0)
#endif

  wfi
  j   .L_exception_loop
  .size _asm_exception_handler, .-_asm_exception_handler
