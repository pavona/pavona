/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * Test for the inverse twiddle generation (gen_twiddles_fwd + _inv_transform):
 * the result written to `scratch` must match the table intt derives at runtime
 * (inv[i] = q - fwd[255-i]).
 */

.section .text.start

main:
  bn.xor w31, w31, w31

  /* w16 = {Q, Qinv, ..} via the R|Q packing; MOD = 2R|2Q (dispatcher state). */
  li     x5, 2
  la     x6, modulus
  bn.lid x5, 0(x6)
  li     x5, 3
  la     x6, montg_R
  bn.lid x5, 0(x6)
  bn.rshi   w16, w3, w2 >> 224
  bn.shv.8s w22, w16 << 1
  bn.wsrw   0x0, w22

  jal x1, gen_twiddles_fwd
  jal x1, _inv_transform

  ecall
