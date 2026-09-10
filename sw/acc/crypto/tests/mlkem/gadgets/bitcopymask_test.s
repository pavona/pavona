/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#define NSHARES 2

.section .text.start

main:
  /* All-zero register. */
  bn.xor w31, w31, w31

  /* r <- bitcopymask(x). */
  la   x10, xb
  addi x11, x0, 32
  la   x13, rb
  jal  x1, bitcopymask

  /* r <- unmask(rb). */
  la     x2, rb
  addi   x3, x2, 384
  la     x5, r
  li     x4, 1
  loopi 12, 4
    bn.lid x0, 0(x2++)
    bn.lid x4, 0(x3++)
    bn.xor w0, w0, w1
    bn.sid x0, 0(x5++)
  endloop

  ecall

.data
.balign 32
r:
  .zero 384
