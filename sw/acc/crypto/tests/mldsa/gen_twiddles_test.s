/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * Test for gen_twiddles_fwd: the generated forward NTT twiddle table written to
 * `scratch` must byte-match the precomputed twiddles_fwd.
 */

.section .text.start

main:
  bn.xor w31, w31, w31

  /* w16 = {Q, Qinv, ..} via the R|Q packing the dispatcher uses. */
  li      x5, 2
  la      x6, modulus
  bn.lid  x5, 0(x6)
  li      x5, 3
  la      x6, montg_R
  bn.lid  x5, 0(x6)
  bn.rshi w16, w3, w2 >> 224

  jal x1, gen_twiddles_fwd

  ecall
