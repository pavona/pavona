/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#define STACK_SIZE 1024

.section .text.start

main:
  /* All-zero register. */
  bn.xor w31, w31, w31

  /* (rb, cout = cb) <- secfulladder(xb, yb, cin = cb). */
  la  x2, stack_end
  la  x10, xb
  li  x11, 32
  la  x12, yb
  li  x13, 32
  la  x15, rb
  li  x16, 32
  la  x17, cb
  li  x29, 32
  la  x30, cb
  li  x31, 32
  jal x1, secfulladder

  /* r <- unmask(rb). */
  la     x2, r
  la     x3, rb
  li     x4, 1
  bn.lid x0, 0(x3++)
  bn.lid x4, 0(x3++)
  bn.xor w0, w0, w1
  bn.sid x0, 0(x2++)
  /* cout <- unmask(cb). */
  la     x3, cb
  bn.lid x0, 0(x3++)
  bn.lid x4, 0(x3++)
  bn.xor w0, w0, w1
  bn.sid x0, 0(x2++)

  ecall

.data
.balign 32
stack:
  .zero STACK_SIZE
stack_end:

r:
  .zero 64
