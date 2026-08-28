/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.section .text.start

main:
  /* All-zero register. */
  bn.xor w31, w31, w31

  /* mod = qinv | q. */
  add     x4, x0, x0
  la      x5, modulus_bn
  bn.lid  x4++, 0(x5)
  bn.rshi w0, w31, w0 >> 240
  la      x5, modulus_inv
  bn.lid  x4, 0(x5)
  bn.or   w0, w0, w1 << 32
  bn.wsrw mod, w0

  /* r <- poly_rej_samp(rand_in). */
  bn.wsrr w16, mod
  la      x10, r
  la      x11, rand_in
  jal     x1, poly_rej_samp

  ecall
