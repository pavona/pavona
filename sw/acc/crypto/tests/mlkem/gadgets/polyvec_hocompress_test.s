/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#define NSHARES 2
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

  /* Unmask rbu -> ru10 (du = 10, share stride 10 * 32). */
  la     x2, rbu
  la     x3, ru10
  li     x4, 1
  li     x5, NSHARES
  addi   x5, x5, -1
  li     x6, 10
  loop x6, 7
    addi   x7, x2, 320
    bn.lid x0, 0(x2++)
    loop x5, 3
      bn.lid x4, 0(x7)
      bn.xor w0, w0, w1
      addi   x7, x7, 320
    endloop
    bn.sid x0, 0(x3++)
  endloop

  /* du = 11 (k = 4): rbu <- polyvec_hocompress(xa). */
  la  x2, stack_end
  la  x10, xa
  la  x12, rbu
  li  x13, 4
  jal x1, polyvec_hocompress

  /* Unmask rbu -> ru11 (du = 11, share stride 11 * 32). */
  la     x2, rbu
  la     x3, ru11
  li     x4, 1
  li     x5, NSHARES
  addi   x5, x5, -1
  li     x6, 11
  loop x6, 7
    addi   x7, x2, 352
    bn.lid x0, 0(x2++)
    loop x5, 3
      bn.lid x4, 0(x7)
      bn.xor w0, w0, w1
      addi   x7, x7, 352
    endloop
    bn.sid x0, 0(x3++)
  endloop

  ecall

.data
.balign 32
stack:
  .zero STACK_SIZE
stack_end:

.data
.balign 32
ru10:
  .zero 32 * 10

ru11:
  .zero 32 * 11
