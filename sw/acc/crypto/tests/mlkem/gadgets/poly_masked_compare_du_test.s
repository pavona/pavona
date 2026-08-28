/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#define NSHARES 2
#define STACK_SIZE 15360

.section .text.start

main:
  /* All-zero register. */
  bn.xor w31, w31, w31

  /* Load stack pointer. */
  la x2, stack_end

  /* r <= poly_masked_compare_du(xu, cu_du11), k = 4 path (du = 11). */
  la   x10, xu
  la   x11, cu_du11
  addi x12, x0, 352 /* du = 11 share stride */
  la   x14, r
  addi x15, x0, 4 /* k */
  jal  x1, poly_masked_compare_du

  /* r &= poly_masked_compare_du(xu, cu_du10), k != 4 path (du = 10). */
  la   x10, xu
  la   x11, cu_du10
  addi x12, x0, 320 /* du = 10 share stride */
  la   x14, r
  addi x15, x0, 2 /* k */
  jal  x1, poly_masked_compare_du

  /* Recombine r; both compares matched, so every bit is set. */
  addi   x4, x0, 1
  la     x10, r
  addi   x11, x0, NSHARES
  addi   x11, x11, -1
  bn.lid x0, 0(x10++)
  loop x11, 2
    bn.lid x4, 0(x10++)
    bn.xor w0, w0, w1
  endloop

  ecall

.data
.balign 32
stack:
  .zero STACK_SIZE
stack_end:

r:
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .zero 32 * (NSHARES - 1)
