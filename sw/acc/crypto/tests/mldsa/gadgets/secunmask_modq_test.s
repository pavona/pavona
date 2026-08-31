/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#define NSHARES 2
#define NB_POLY 1024
#define STACK_SIZE 4096

.section .text.start

main:
  la  x2, stack_end
  bn.xor w31, w31, w31

  /* MOD <= R | Q for bn.addvm.8s / bn.subvm.8s inside the gadget. */
  li      x5, 2
  la      x6, modulus
  bn.lid  x5, 0(x6)
  li      x5, 3
  la      x6, montg_R
  bn.lid  x5, 0(x6)
  bn.rshi w2, w3, w2 >> 224
  bn.wsrw 0x0, w2

  la  x10, y_out
  la  x11, x_in
  jal x1, secunmask_modq

  ecall

.data
.balign 32
stack:
  .zero STACK_SIZE
stack_end:

.balign 32
.globl y_out
y_out:
  .zero NB_POLY
