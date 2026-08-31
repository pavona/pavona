/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.section .text.start

main:
  la      x2, stack_end
  bn.xor w31, w31, w31

  /* MOD <= R | Q for bn.subvm.8s / bn.addvm.8s inside the gadget. */
  li      x5, 2
  la      x6, modulus
  bn.lid  x5, 0(x6)
  li      x5, 3
  la      x6, montg_R
  bn.lid  x5, 0(x6)
  bn.rshi w2, w3, w2 >> 224
  bn.wsrw 0x0, w2

  /* lambda case 0: b <- secboundcheck(x_arith0), C = c_wdr0; store b. */
  li      x5, 17
  la      x6, c_wdr0
  bn.lid  x5, 0(x6)
  la      x10, x_arith0
  la      x12, lambda0_vec0
  la      x13, seca2b_scratch
  la      x14, secboundcheck_buf
  jal     x1, secboundcheck
  la      x10, y_out0
  li      x11, 0
  bn.sid  x11, 0(x10)

  /* lambda case 1: b <- secboundcheck(x_arith1), C = c_wdr1; store b. */
  li      x5, 17
  la      x6, c_wdr1
  bn.lid  x5, 0(x6)
  la      x10, x_arith1
  la      x12, lambda0_vec1
  la      x13, seca2b_scratch
  la      x14, secboundcheck_buf
  jal     x1, secboundcheck
  la      x10, y_out1
  li      x11, 0
  bn.sid  x11, 0(x10)

  ecall

.data
.balign 32
stack:
  .zero 8192
stack_end:

.balign 32
.globl y_out0
y_out0:
  .zero 32
.balign 32
.globl y_out1
y_out1:
  .zero 32

.balign 32
seca2b_scratch:
  .zero 1536

.balign 32
secboundcheck_buf:
  .zero 1536
