/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.section .text.start

main:
  /* All-zero register. */
  bn.xor w31, w31, w31

  /* dmem[rbs] <= poly_to_bitsliced(dmem[xa]) */
  la  x10, xa
  la  x11, rbs
  jal x1, poly_to_bitsliced

  ecall

.data
.balign 32
rbs:
  .zero 32 * 12
