// Copyright Konrad Jansen, Vincent Quentin Ulitzsch, Niclas Kuehnapfel
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Reset and trap entry for the Resiliator fault-injection firmware.
//
// The layout is fixed by Ibex (see resiliator_fw.ld):
//   0x00  mtvec base: exception entry
//   0x80  reset vector

#include "hw/vendor/kjnsen_resiliator/firmware/injection.h"

// Match failure() in injection.h; its C macro cannot be used from assembly.
#define RESILIATOR_FAILURE_WORD 0x40b58633

  .section .init, "ax", @progbits

  //////////////////////////////////////////////////////////////////////////////
  // 0x00: trap entry                                                         //
  //////////////////////////////////////////////////////////////////////////////

  // Treat exceptions as failed attacks. Interrupts are tied off in the testbench.
  .globl _trap_entry
  .type _trap_entry, @function
_trap_entry:
  li   t0, RESILIATOR_GPIO_ADDR
  li   t1, RESILIATOR_FAILURE_WORD
  sw   t1, 0(t0)
_trap_halt:
  j    _trap_halt
  .size _trap_entry, .-_trap_entry

  //////////////////////////////////////////////////////////////////////////////
  // 0x80: reset vector                                                       //
  //////////////////////////////////////////////////////////////////////////////

  . = 0x80

  .globl _start
  .type _start, @function
_start:
  // Put every architectural register into a known state. Without this the
  // golden and faulty simulations could diverge on reset values alone, which
  // would make every injection look "successful".
  mv   x1, zero
  mv   x2, zero
  mv   x3, zero
  mv   x4, zero
  mv   x5, zero
  mv   x6, zero
  mv   x7, zero
  mv   x8, zero
  mv   x9, zero
  mv   x10, zero
  mv   x11, zero
  mv   x12, zero
  mv   x13, zero
  mv   x14, zero
  mv   x15, zero
  mv   x16, zero
  mv   x17, zero
  mv   x18, zero
  mv   x19, zero
  mv   x20, zero
  mv   x21, zero
  mv   x22, zero
  mv   x23, zero
  mv   x24, zero
  mv   x25, zero
  mv   x26, zero
  mv   x27, zero
  mv   x28, zero
  mv   x29, zero
  mv   x30, zero
  mv   x31, zero

  // Full-descending stack from the top of SRAM, and a global pointer for
  // .sdata/.sbss relaxation.
  la   sp, _stack_top
.option push
.option norelax
  la   gp, __global_pointer$
.option pop

  // Zero .bss. crt_section_clear takes (start, end) in a0/a1.
  la   a0, _bss_start
  la   a1, _bss_end
  jal  ra, crt_section_clear

  jal  ra, main

  // Report failure when main() returns without terminating the simulation.
  li   t0, RESILIATOR_GPIO_ADDR
  li   t1, RESILIATOR_FAILURE_WORD
  sw   t1, 0(t0)
_start_halt:
  j    _start_halt
  .size _start, .-_start
