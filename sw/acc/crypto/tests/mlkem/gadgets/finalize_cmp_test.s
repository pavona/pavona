/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#define STACK_SIZE 15360

.section .text.start

main:
  /* All-zero register. */
  bn.xor w31, w31, w31

  /* x <- finalize_cmp(x): AND-reduce the 256 comparison bits to bit 0. */
  la   x2, stack_end
  la   x10, x
  jal  x1, finalize_cmp

  /* Unmask x; bit 0 holds the comparison result. */
  addi   x4, x0, 1
  la     x2, x
  bn.lid x0, 0(x2++)
  bn.lid x4, 0(x2)
  bn.xor w0, w0, w1

  ecall

.data
.balign 32
stack:
  .zero STACK_SIZE
stack_end:
  .zero 0
