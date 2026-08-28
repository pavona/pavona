/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#define STACK_SIZE 20000

.section .text.start

main:
  /* All-zero register. */
  bn.xor w31, w31, w31

  /* du = 10 (k = 2): rbu <- polyvec_hocompress(xa). */
  la  x2, stack_end
  la  x10, xa
  la  x12, rbu
  li  x13, 2
  jal x1, polyvec_hocompress

  /* ru10 <- unmask(rbu). */
  la     x2, rbu
  addi   x3, x2, 320
  la     x5, ru10
  li     x4, 1
  loopi 10, 4
    bn.lid x0, 0(x2++)
    bn.lid x4, 0(x3++)
    bn.xor w0, w0, w1
    bn.sid x0, 0(x5++)
  endloop

  /* du = 11 (k = 4): rbu <- polyvec_hocompress(xa). */
  la  x2, stack_end
  la  x10, xa
  la  x12, rbu
  li  x13, 4
  jal x1, polyvec_hocompress

  /* ru11 <- unmask(rbu). */
  la     x2, rbu
  addi   x3, x2, 352
  la     x5, ru11
  li     x4, 1
  loopi 11, 4
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

ru10:
  .zero 32 * 10

ru11:
  .zero 32 * 11
