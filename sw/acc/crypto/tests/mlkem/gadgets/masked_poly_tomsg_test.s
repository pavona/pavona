/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#define STACK_SIZE 20000

.section .text.start

main:
  /* All-zero register. */
  bn.xor w31, w31, w31

  /* rb <- masked_poly_tomsg(xa). */
  la  x2, stack_end
  la  x10, xa
  la  x12, rb
  jal x1, masked_poly_tomsg

  /* r <- unmask(rb). */
  la     x2, rb
  li     x4, 1
  bn.lid x0, 0(x2++)
  bn.lid x4, 0(x2)
  bn.xor w0, w0, w1
  la     x2, r
  bn.sid x0, 0(x2)

  ecall

.data
.balign 32
stack:
  .zero STACK_SIZE
stack_end:

r:
  .zero 32
