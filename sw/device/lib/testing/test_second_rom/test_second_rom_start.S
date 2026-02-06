// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/**
 * Test second ROM runtime initialization code.
 */

  // NOTE: The "ax" flag below is necessary to ensure that this section
  // is allocated executable space in ROM by the linker.
  .section .crt, "ax"

// -----------------------------------------------------------------------------

  /**
   * Callable entry point for the boot rom.
   *
   * Currently, this zeroes the `.bss` section, copies initial data to
   * `.data`, and then jumps to the program entry point.
   */
  .balign 4
  .global _start
  .type _start, @function
_start:
  // Zero out the `.bss` segment.
  la   a0, _bss_start
  la   a1, _bss_end
  call crt_section_clear

  // Initialize the `.data` segment from the `.idata` segment.
  la   a0, _data_start
  la   a1, _data_end
  la   a2, _data_init_start
  call crt_section_copy

  // Clobber all temporary registers.
  li t0, 0x0
  li t1, 0x0
  li t2, 0x0
  li t3, 0x0
  li t4, 0x0
  li t5, 0x0
  li t6, 0x0

  // Clobber all argument registers.
  li a0, 0x0
  li a1, 0x0
  li a2, 0x0
  li a3, 0x0
  li a4, 0x0
  li a5, 0x0
  li a6, 0x0
  li a7, 0x0

  // Jump into the C program entry point.
  call _second_rom_boot_start

  // Enter a wait for interrupt loop, the device should reset shortly.
.L_wfi_loop:
  wfi
  j   .L_wfi_loop
  .size _start, .-_start

// -----------------------------------------------------------------------------

  /**
   * Test ROM IRQ/exception handler; loops forever.
   */
  .balign 4
  .section .text
  .global _test_rom_irq_handler
  .type _test_rom_irq_handler, @function
_test_rom_irq_handler:
  wfi
  j _test_rom_irq_handler
  .size _test_rom_irq_handler, .-_test_rom_irq_handler
