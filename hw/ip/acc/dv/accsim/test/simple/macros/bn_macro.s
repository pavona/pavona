/* Copyright zeroRISC Inc & MPI-SP. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/*
  Regression test for pavona/pavona#386: a bn.* operand referencing a macro
  parameter ("\a") used to be resolved at macro-definition time, before the
  real assembler ever substitutes the argument.
*/

.macro double_op a, b
    bn.xor \a, \a, \b
    bn.not \a, \a
.endm

/* A macro that is never invoked must not fail at definition time either. */
.macro unused_macro a, b
    bn.xor \a, \a, \b
.endm

  li      x2, 2
  li      x3, 3
  bn.lid  x2, 0(x0)   /* w2 = 0x11...11 */
  bn.lid  x3, 32(x0)  /* w3 = 0x22...22 */

  double_op w2, w3

  ecall

.section .data
  .rept 8
  .word 0x11111111
  .endr
  .rept 8
  .word 0x22222222
  .endr
