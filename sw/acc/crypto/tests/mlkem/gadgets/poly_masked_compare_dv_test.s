/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#define STACK_SIZE 15360

.section .text.start

main:
  /* All-zero register. */
  bn.xor w31, w31, w31

  /* r <- poly_masked_compare_dv(xv, cv_dv5), k = 4 path (dv = 5). */
  la   x2, stack_end
  la   x10, xv
  la   x11, cv_dv5
  addi x12, x0, 160
  la   x14, r
  addi x15, x0, 4
  jal  x1, poly_masked_compare_dv

  /* r &= poly_masked_compare_dv(xv, cv_dv4), k != 4 path (dv = 4). */
  la   x10, xv
  la   x11, cv_dv4
  addi x12, x0, 128
  la   x14, r
  addi x15, x0, 2
  jal  x1, poly_masked_compare_dv

  /* Unmask r; both compares matched, so every bit is set. */
  addi   x4, x0, 1
  la     x10, r
  bn.lid x0, 0(x10++)
  bn.lid x4, 0(x10++)
  bn.xor w0, w0, w1

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
