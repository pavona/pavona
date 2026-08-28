/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#define NSHARES 2
#define N_WDR 16
#define NB_POLY 512
#define STACK_SIZE 20000

.section .text.start

main:
  /* All-zero register. */
  bn.xor w31, w31, w31

  /* MOD <= dmem[modulus] */
  addi    x4, x0, 0
  la      x5, modulus_bn
  bn.lid  x4++, 0(x5)
  bn.rshi w0, w31, w0 >> 240
  la      x5, modulus_inv
  bn.lid  x4, 0(x5)
  bn.or   w0, w0, w1 << 32
  bn.wsrw 0x0, w0

  /* Load stack pointer */
  la x2, stack_end

  /* dmem[ra] <= secb2amodq(dmem[xb]) */
  la  x10, xb
  la  x12, ra
  jal x1, secb2amodq

  /* Compute r */
  la   x2, ra
  la   x3, r
  li   x4, 1
  li   x5, NSHARES
  addi x5, x5, -1
  loopi N_WDR, 7
    addi   x6, x2, NB_POLY
    bn.lid x0, 0(x2++)
    loop x5, 3
      bn.lid       x4, 0(x6)
      bn.addvm.16h w0, w0, w1
      addi         x6, x6, NB_POLY
    endloop
    bn.sid x0, 0(x3++)
  endloop
  ecall

.data
.balign 32
stack:
  .zero STACK_SIZE
stack_end:

r:
  .zero 32 * N_WDR
