/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#define NB_POLY 512

.section .text.start

main:
  /* All-zero register. */
  bn.xor w31, w31, w31

  /* dmem[rn] <= poly_from_bitsliced(dmem[rbs]) */
  la  x10, rbs
  la  x11, rn
  jal x1, poly_from_bitsliced

  ecall

.data
.balign 32
rn:
  .zero NB_POLY
