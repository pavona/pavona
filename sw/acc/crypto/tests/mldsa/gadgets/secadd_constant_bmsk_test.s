/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#define STACK_SIZE 1024

.section .text.start

main:
  /* All-zero register. */
  bn.xor w31, w31, w31

  /* Load stack pointer. */
  la x2, stack_end

  /* dmem[spb] <= secadd_constant_bmsk(dmem[spb]) (in place) */
  la  x10, spb
  jal x1, secadd_constant_bmsk

  /* Recombine the in-place output: z[j] = spb[j] ^ spb[j + (k+1)]. */
  la x2, spb
  la x3, z
  li x4, 1
  li x6, 24
  loop x6, 5
    addi   x7, x2, 768
    bn.lid x0, 0(x2++)
    bn.lid x4, 0(x7)
    bn.xor w0, w0, w1
    bn.sid x0, 0(x3++)
  endloop

  ecall

.data
.balign 32
stack:
  .zero STACK_SIZE
stack_end:
z:
  .zero 768
