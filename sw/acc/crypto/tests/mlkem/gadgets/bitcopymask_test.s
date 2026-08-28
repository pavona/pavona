/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#define NSHARES 2

.section .text.start

main:
  /* All-zero register. */
  bn.xor w31, w31, w31

  /* dmem[r] <= bitcopymask(dmem[x]) */
  la   x10, xb
  addi x11, x0, 32
  la   x13, rb
  jal  x1, bitcopymask

  /* Compute r */
  la     x2, rb
  la     x3, r
  li     x4, 1
  li     x5, NSHARES
  addi   x5, x5, -1
  loopi 12, 7
    addi   x6, x2, 384
    bn.lid x0, 0(x2++)
    loop x5, 3
      bn.lid x4, 0(x6)
      addi   x6, x6, 384
      bn.xor w0, w0, w1
    endloop
    bn.sid x0, 0(x3++)
  endloop

  ecall

.data
.balign 32
r:
  .zero 32 * 12
