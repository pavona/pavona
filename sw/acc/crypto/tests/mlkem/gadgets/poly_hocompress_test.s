/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#define STACK_SIZE 20000

.section .text.start

main:
  /* All-zero register. */
  bn.xor w31, w31, w31

  /* dv = 4 (k = 2): rbv <- poly_hocompress(xa). */
  la  x2, stack_end
  la  x10, xa
  la  x12, rbv
  li  x13, 2
  jal x1, poly_hocompress

  /* rv4 <- unmask(rbv). */
  la     x2, rbv
  addi   x3, x2, 128
  la     x5, rv4
  li     x4, 1
  loopi 4, 4
    bn.lid x0, 0(x2++)
    bn.lid x4, 0(x3++)
    bn.xor w0, w0, w1
    bn.sid x0, 0(x5++)
  endloop

  /* dv = 5 (k = 4): rbv <- poly_hocompress(xa). */
  la  x2, stack_end
  la  x10, xa
  la  x12, rbv
  li  x13, 4
  jal x1, poly_hocompress

  /* rv5 <- unmask(rbv). */
  la     x2, rbv
  addi   x3, x2, 160
  la     x5, rv5
  li     x4, 1
  loopi 5, 4
    bn.lid x0, 0(x2++)
    bn.lid x4, 0(x3++)
    bn.xor w0, w0, w1
    bn.sid x0, 0(x5++)
  endloop

  ecall

.data
.balign 32
stack:
  .zero STACK_SIZE
stack_end:

rv4:
  .zero 32 * 4

rv5:
  .zero 32 * 5
