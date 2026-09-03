/* Copyright zeroRISC Inc & MPI-SP. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/*
  GNU/LLVM macro features layered on top of a parameterized bn.* operand:
  default arguments, keyword arguments, a nested macro invocation, and
  .purgem followed by a redefinition.
*/

.macro combine d, a, b=w31
    bn.xor \d, \a, \b
.endm

.macro apply_twice d, a
    combine \d, \a, w31
    bn.not \d, \d
.endm

.macro old_add d, a, b
    bn.and \d, \a, \b
.endm
.purgem old_add
.macro old_add d, a, b
    bn.or \d, \a, \b
.endm

  li      x2, 1
  li      x3, 2
  bn.lid  x2, 0(x0)   /* w1 = 0x11...11 */
  bn.lid  x3, 32(x0)  /* w2 = 0x13...13 */

  combine w3, w1              /* default b=w31(=0): w3 = w1 ^ 0 = w1 */
  combine w4, w1, w2           /* w4 = w1 ^ w2 */
  combine w5, w1, b=w2         /* keyword arg: same as w4 */
  apply_twice w6, w2           /* w6 = ~(w2 ^ 0) = ~w2 */
  old_add w7, w1, w2           /* uses the *redefined* old_add (bn.or) */

  ecall

.section .data
  .rept 8
  .word 0x11111111
  .endr
  .rept 8
  .word 0x13131313
  .endr
