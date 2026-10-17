/* Copyright zeroRISC Inc & MPI-SP. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/*
  A macro parameter used as an immediate operand: bn.lid's offset (a signed,
  <<5-shifted, split-across-two-bit-ranges field) with a negative value, a
  GPR parameter passed an ABI register name, bn.rshi's shift amount (an
  unsigned, split-across-two-bit-ranges field), and bn.addi's immediate.
*/

.macro load_off grd, gprs1, off
    bn.lid \grd, \off(\gprs1)
.endm

.macro rshi_m d, a, b, n
    bn.rshi \d, \a, \b >> \n
.endm

.macro addi_m d, a, n
    bn.addi \d, \a, \n
.endm

  /* li/la don't accept an ABI name for <grd> directly, unlike a macro
     parameter, so set the plain register here and pass "t0"/"a1" below. */
  li      x5, 1
  la      x11, block1
  load_off t0, a1, 0     /* w1 = block1 = 0x22...22 */
  load_off t0, a1, -32   /* w1 = block0 = 0x11...11 (negative offset) */

  li      x2, 2
  li      x3, 3
  bn.lid  x2, 0(x0)      /* w2 = block0 = 0x11...11 */
  bn.lid  x3, 32(x0)     /* w3 = block1 = 0x22...22 */

  rshi_m  w4, w2, w3, 8
  addi_m  w5, w2, 0x123

  ecall

.section .data
block0:
  .rept 8
  .word 0x11111111
  .endr
block1:
  .rept 8
  .word 0x22222222
  .endr
