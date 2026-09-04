/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * Whitening step for NTT, INTT and pair-pointwise multiplication.
 *
 * Zeroize the clobbered WDRs containing coefficients of secret values
 * that ntt, intt, basemul and basemul_acc use. Wide registers that
 * contain constants are not wiped.
 *
 * This routine is constant time.
 *
 * @param[in]     w0 to w15, w17 to w25: registers to be whitened
 * @param[in]     w31: all-zero register
 *
 * clobbered registers: w0 to w15, w17 to w25
 * clobbered flag groups: FG0
 */

.globl whitening
.type whitening, @function
whitening:
  bn.xor w0, w31, w31
  bn.xor w1, w31, w31
  bn.xor w2, w31, w31
  bn.xor w3, w31, w31
  bn.xor w4, w31, w31
  bn.xor w5, w31, w31
  bn.xor w6, w31, w31
  bn.xor w7, w31, w31
  bn.xor w8, w31, w31
  bn.xor w9, w31, w31
  bn.xor w10, w31, w31
  bn.xor w11, w31, w31
  bn.xor w12, w31, w31
  bn.xor w13, w31, w31
  bn.xor w14, w31, w31
  bn.xor w15, w31, w31
  bn.xor w17, w31, w31
  bn.xor w18, w31, w31
  bn.xor w19, w31, w31
  bn.xor w20, w31, w31
  bn.xor w21, w31, w31
  bn.xor w22, w31, w31
  bn.xor w23, w31, w31
  bn.xor w24, w31, w31
  bn.xor w25, w31, w31
  ret
