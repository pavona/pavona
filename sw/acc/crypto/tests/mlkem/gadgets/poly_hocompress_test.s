/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#define NSHARES 2
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

  /* Unmask rbv -> rv4 (dv = 4, share stride 4 * 32). */
  la     x2, rbv
  la     x3, rv4
  li     x4, 1
  li     x5, NSHARES
  addi   x5, x5, -1
  li     x6, 4
  loop x6, 7
    addi   x7, x2, 128
    bn.lid x0, 0(x2++)
    loop x5, 3
      bn.lid x4, 0(x7)
      bn.xor w0, w0, w1
      addi   x7, x7, 128
    endloop
    bn.sid x0, 0(x3++)
  endloop

  /* dv = 5 (k = 4): rbv <- poly_hocompress(xa). */
  la  x2, stack_end
  la  x10, xa
  la  x12, rbv
  li  x13, 4
  jal x1, poly_hocompress

  /* Unmask rbv -> rv5 (dv = 5, share stride 5 * 32). */
  la     x2, rbv
  la     x3, rv5
  li     x4, 1
  li     x5, NSHARES
  addi   x5, x5, -1
  li     x6, 5
  loop x6, 7
    addi   x7, x2, 160
    bn.lid x0, 0(x2++)
    loop x5, 3
      bn.lid x4, 0(x7)
      bn.xor w0, w0, w1
      addi   x7, x7, 160
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
rv4:
  .zero 32 * 4

rv5:
  .zero 32 * 5
