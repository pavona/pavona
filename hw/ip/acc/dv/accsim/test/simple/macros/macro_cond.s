/* Copyright zeroRISC Inc & MPI-SP. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/*
  .if/.else and a recursive, .exitm-terminated macro around a bn.* operand:
  acc_as.py just emits ordinary assembler expression text, so it never has
  to understand the condition or the recursion.
*/

.macro maybe_xor d, a, b, cond
.if \cond
    bn.xor \d, \a, \b
.else
    bn.and \d, \a, \b
.endif
.endm

/* Inverts \d once per recursion level, \k levels deep. */
.macro invert_n d, k
.if (\k) == 0
.exitm
.endif
    bn.not \d, \d
invert_n \d, "(\k)-1"
.endm

  li      x2, 1
  li      x3, 2
  bn.lid  x2, 0(x0)    /* w1 = 0x11...11 */
  bn.lid  x3, 32(x0)   /* w2 = 0x13...13 */

  maybe_xor w3, w1, w2, 1   /* w3 = w1 ^ w2 */
  maybe_xor w4, w1, w2, 0   /* w4 = w1 & w2 */

  invert_n w5, 3            /* w5 = ~~~0 = all ones */

  ecall

.section .data
  .rept 8
  .word 0x11111111
  .endr
  .rept 8
  .word 0x13131313
  .endr
