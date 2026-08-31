/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.section .text.start

main:
  la  x2, stack_end
  bn.xor w31, w31, w31

  la  x10, r
  la  x11, rand
  jal x1, poly_rej_samp_bitsliced

  ecall

.data
.balign 32
stack:
  .zero 1024
stack_end:
  .byte 0
