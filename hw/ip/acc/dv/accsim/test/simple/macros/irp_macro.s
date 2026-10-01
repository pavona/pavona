/* Copyright zeroRISC Inc & MPI-SP. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/*
  .irp/.irpc bodies hit the same bug as .macro bodies: they have no name to
  register as a known macro, so a "\foo" operand went through gen_line's
  normal, eager encoding like any other line. Also covers a macro invocation
  nested inside a plain .rept, and a parameter substituted into the middle
  of a register name ("w\n").
*/

.macro negate x
    bn.not \x, \x
.endm

  li      x2, 1
  li      x3, 2
  li      x4, 3
  bn.lid  x2, 0(x0)     /* w1 = 0x11...11 */
  bn.lid  x3, 32(x0)    /* w2 = 0x22...22 */
  bn.lid  x4, 64(x0)    /* w3 = 0x33...33 */

.irp r, w1, w2, w3
    bn.not \r, \r
.endr

.rept 2
    negate w1
.endr

.irpc n, 23
    bn.not w\n, w\n
.endr

  ecall

.section .data
  .rept 8
  .word 0x11111111
  .endr
  .rept 8
  .word 0x22222222
  .endr
  .rept 8
  .word 0x33333333
  .endr
