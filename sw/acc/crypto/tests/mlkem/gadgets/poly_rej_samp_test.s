/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.section .text.start

main:
  /* All-zero register. */
  bn.xor w31, w31, w31

  /* w16 = mod = mqinv | q. */
  addi    x4, x0, 16
  la      x5, const_q
  bn.lid  x4++, 0(x5)
  bn.rshi w16, w31, w16 >> 240
  la      x5, const_mqinv
  bn.lid  x4, 0(x5)
  bn.or   w16, w16, w17 << 32
  bn.wsrw mod, w16

  /* r <- poly_rej_samp(rand_in). */
  la  x10, r
  la  x11, rand_in
  jal x1, poly_rej_samp

  ecall
