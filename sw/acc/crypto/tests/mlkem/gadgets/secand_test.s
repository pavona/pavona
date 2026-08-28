/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#define NSHARES 2
#define STACK_SIZE 1024

.section .text.start

main:
  /* All-zero register. */
  bn.xor w31, w31, w31

  /* Load stack pointer. */
  la  x2, stack_end

  /* dmem[rb] <= secand(dmem[xb], dmem[yb]) */
  la  x10, xb
  li  x11, 32
  la  x12, yb
  li  x13, 32
  la  x15, rb
  li  x16, 32
  jal x1, secand

  /* Compute r */
  la     x2, rb
  la     x3, r
  li     x4, 1
  li     x5, NSHARES
  addi   x5, x5, -1
  bn.lid x0, 0(x2++)
  loop x5, 2
    bn.lid x4, 0(x2++)
    bn.xor w0, w0, w1
  endloop
  bn.sid x0, 0(x3)

  ecall

.data
.balign 32
stack:
  .zero STACK_SIZE
stack_end:

r:
  .zero 32
