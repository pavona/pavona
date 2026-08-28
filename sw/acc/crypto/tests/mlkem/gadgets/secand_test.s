/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#define STACK_SIZE 1024

.section .text.start

main:
  /* All-zero register. */
  bn.xor w31, w31, w31

  /* rb <- secand(xb, yb). */
  la  x2, stack_end
  la  x10, xb
  li  x11, 32
  la  x12, yb
  li  x13, 32
  la  x15, rb
  li  x16, 32
  jal x1, secand

  /* r <- unmask(rb). */
  la     x2, rb
  la     x3, r
  li     x4, 1
  bn.lid x0, 0(x2++)
  bn.lid x4, 0(x2)
  bn.xor w0, w0, w1
  bn.sid x0, 0(x3)

  ecall

.data
.balign 32
stack:
  .zero STACK_SIZE
stack_end:

r:
  .zero 32
