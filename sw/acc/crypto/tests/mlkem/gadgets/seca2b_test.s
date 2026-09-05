/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#define STACK_SIZE 20000

.section .text.start

main:
  /* All-zero register. */
  bn.xor w31, w31, w31

  /* rb <- seca2b(xa). */
  la  x2, stack_end
  la  x10, xa
  li  x11, 16
  li  x12, 512
  la  x14, rb
  jal x1, seca2b

  /* r <- unmask(rb). */
  la     x2, rb
  addi   x3, x2, 512
  la     x5, r
  li     x4, 1
  loopi 16, 4
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

r:
  .zero 512
