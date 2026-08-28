/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#define NSHARES 2
#define BITSIZE 16
#define SHARE_STR 512
#define STACK_SIZE 1024

.section .text.start

main:
  /* All-zero register. */
  bn.xor w31, w31, w31

  /* Load stack pointer. */
  la  x2, stack_end

  /* dmem[rb] <= secadd(dmem[xb], dmem[yb]) */
  la  x10, xb
  li  x11, SHARE_STR
  la  x12, yb
  li  x13, SHARE_STR
  la  x15, rb
  li  x16, SHARE_STR
  li  x17, BITSIZE
  jal x1, secadd

  /* Compute r */
  la     x2, rb
  la     x3, r
  li     x4, 1
  li     x5, NSHARES
  addi   x5, x5, -1
  li     x6, BITSIZE
  loop x6, 7
    addi   x7, x2, SHARE_STR
    bn.lid x0, 0(x2++)
    loop x5, 3
      bn.lid x4, 0(x7)
      bn.xor w0, w0, w1
      addi   x7, x7, SHARE_STR
    endloop
    bn.sid x0, 0(x3++)
  endloop

  ecall

.data
.balign 32
stack:
  .zero STACK_SIZE
stack_end:

r:
  .zero 32 * BITSIZE
