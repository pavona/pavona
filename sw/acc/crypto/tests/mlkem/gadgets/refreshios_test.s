/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#define STACK_SIZE 8192

.section .text.start

main:
  /* All-zero register. */
  bn.xor w31, w31, w31

  /* rb <- refreshios(xb). */
  la  x2, stack_end
  la  x10, xb
  li  x11, 12
  li  x12, 384
  la  x14, rb
  jal x1, refreshios

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
stack:
  .zero STACK_SIZE
stack_end:

r:
  .zero 384
