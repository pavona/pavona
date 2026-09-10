/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#define STACK_SIZE 15360

.section .text.start

main:
  /* All-zero register. */
  bn.xor w31, w31, w31

  /* r <- masked_poly_compare_dv(xv, cv_dv5), k = 4 path (dv = 5). */
  la   x2, stack_end
  la   x10, xv
  la   x11, cv_dv5
  addi x12, x0, 160
  la   x14, r
  addi x15, x0, 4
  jal  x1, masked_poly_compare_dv

  /* r &= masked_poly_compare_dv(xv, cv_dv4), k != 4 path (dv = 4). */
  la   x10, xv
  la   x11, cv_dv4
  addi x12, x0, 128
  la   x14, r
  addi x15, x0, 2
  jal  x1, masked_poly_compare_dv

  /* w0 <- unmask(r). */
  addi   x4, x0, 1
  la     x10, r
  bn.lid x0, 0(x10++)
  bn.lid x4, 0(x10++)
  bn.xor w0, w0, w1

  /* If both compares matches, every bit is set. Otherwise, we
   * set the result to all 0 for comparison with the expected result
   * for the masked_poly_compare_dv_false_test. */
  bn.subi w1, w31, 1
  bn.cmp  w0, w1, FG0
  bn.sel  w0, w0, w31, FG0.z

  ecall

.data
.balign 32
stack:
  .zero STACK_SIZE
stack_end:

r:
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .zero 32
