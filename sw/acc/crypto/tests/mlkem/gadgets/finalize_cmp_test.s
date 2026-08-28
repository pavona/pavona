/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#define NSHARES 2
#define STACK_SIZE 15360

.section .text.start

main:
  /* All-zero register. */
  bn.xor w31, w31, w31

  /* Load stack pointer. */
  la x2, stack_end

  /* x <= finalize_cmp(x): AND-reduce the 256 comparison bits to bit 0. */
  la   x10, x
  jal  x1, finalize_cmp

  /* Recombine x; bit 0 holds the comparison result. */
  addi   x4, x0, 1
  la     x10, x
  addi   x11, x0, NSHARES
  addi   x11, x11, -1
  bn.lid x0, 0(x10++)
  loop x11, 2
    bn.lid x4, 0(x10++)
    bn.xor w0, w0, w1
  endloop

  ecall

.data
.balign 32
stack:
  .zero STACK_SIZE
stack_end:
