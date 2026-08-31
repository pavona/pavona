/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#define NSHARES 2

.section .text.start

main:
  la     x2, stack_end
  bn.xor w31, w31, w31

  /* psi case 0: b <- secleq(x_in0), C = c_wdr0; store b to y_out0. */
  li     x5, 17
  la     x6, c_wdr0
  bn.lid x5, 0(x6)
  la     x11, x_in0
  jal    x1, secleq
  la     x10, y_out0
  li     x11, 0
  bn.sid x11, 0(x10)

  /* psi case 1: b <- secleq(x_in1), C = c_wdr1; store b to y_out1. */
  li     x5, 17
  la     x6, c_wdr1
  bn.lid x5, 0(x6)
  la     x11, x_in1
  jal    x1, secleq
  la     x10, y_out1
  li     x11, 0
  bn.sid x11, 0(x10)

  ecall

.data
.balign 32
stack:
  .zero 4096
stack_end:

.balign 32
.globl y_out0
y_out0:
  .zero 32
.globl y_out1
y_out1:
  .zero 32
