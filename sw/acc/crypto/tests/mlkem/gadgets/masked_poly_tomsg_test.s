/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#define NSHARES 2
#define STACK_SIZE 20000

.section .text.start

main:
  /* All-zero register. */
  bn.xor w31, w31, w31

  /* Load stack pointer */
  la x2, stack_end

  /* dmem[rb] <= masked_poly_tomsg(dmem[xa]). */
  la  x10, xa
  la  x12, rb
  jal x1, masked_poly_tomsg

  /* Compute r. */
  la     x2, rb
  la     x3, r
  li     x4, 1
  li     x5, NSHARES
  addi   x5, x5, -1
  bn.lid x0, 0(x2++)
  loop x5, 2
    bn.lid x4, 0(x2++)
    bn.xor w0, w0, w1
  endloop
  bn.sid x0, 0(x3++)

  ecall

.data
.balign 32
stack:
  .zero STACK_SIZE
stack_end:

.data
.balign 32
r:
  .zero 32
