/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.section .text.start

main:
  /* All-zero register. */
  bn.xor w31, w31, w31

  /* rn <- poly_from_bitsliced(rbs). */
  la  x10, rbs
  la  x11, rn
  jal x1, poly_from_bitsliced

  ecall

.data
.balign 32
rn:
  .zero 512
