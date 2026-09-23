/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.section .text.start

main:
  /* All-zero register. */
  bn.xor w31, w31, w31

  /* w16 = mod = qinv | q. */
  addi    x4, x0, 16
  la      x5, modulus_bn
  bn.lid  x4++, 0(x5)
  bn.rshi w16, w31, w16 >> 240
  la      x5, modulus_inv
  bn.lid  x4, 0(x5)
  bn.or   w16, w16, w17 << 32
  bn.wsrw mod, w16

  /* r_dv4 <- poly_decompress(x_dv4), k != 4 path (dv = 4). */
  la   x10, x_dv4
  la   x11, r_dv4
  addi x12, x0, 2 /* k */
  jal  x1, poly_decompress

  /* r_dv5 <- poly_decompress(x_dv5), k = 4 path (dv = 5). */
  la   x10, x_dv5
  la   x11, r_dv5
  addi x12, x0, 4 /* k */
  jal  x1, poly_decompress

  ecall

.data
.balign 32
r_dv4:
  .zero 512
r_dv5:
  .zero 512
