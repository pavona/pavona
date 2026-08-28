/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#define NSHARES 2
#define BITSIZE 12
#define SHARE_STR 384 /* 32 * BITSIZE */
#define STACK_SIZE 8192

.section .text.start

main:
  /* All-zero register. */
  bn.xor w31, w31, w31

  /* Load stack pointer */
  la x2, stack_end

  /* dmem[rb] <= refreshios(dmem[xb], k, share stride). */
  la  x10, xb
  li  x11, BITSIZE
  li  x12, SHARE_STR
  la  x14, rb
  jal x1, refreshios

  /* Compute r */
  la     x2, rb
  la     x3, r
  li     x4, 1
  li     x5, NSHARES
  addi   x5, x5, -1
  loopi BITSIZE, 7
    addi   x6, x2, SHARE_STR
    bn.lid x0, 0(x2++)
    loop x5, 3
      bn.lid x4, 0(x6)
      bn.xor w0, w0, w1
      addi   x6, x6, SHARE_STR
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
