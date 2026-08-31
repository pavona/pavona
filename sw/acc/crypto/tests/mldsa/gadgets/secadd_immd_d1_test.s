/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#define STACK_SIZE 1024

.section .text.start

main:
  /* All-zero register. */
  bn.xor w31, w31, w31

  /* Load stack pointer. */
  la  x2, stack_end

  /* dmem[z] <= secadd_immd_d1(dmem[xb]), kbits = 23 (output 24 words) */
  la  x10, xb
  li  x12, 23
  la  x16, z
  jal x1, secadd_immd_d1

  ecall

.data
.balign 32
stack:
  .zero STACK_SIZE
stack_end:
z:
  .zero 768
