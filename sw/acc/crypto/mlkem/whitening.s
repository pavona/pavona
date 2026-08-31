/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * Whitening steps for ML-KEM.
 *
 * The entry points below form a single fall-through chain, ordered so that
 * each one clears its own registers and then falls into the next:
 *
 *   whitening                    -> w23
 *   whitening_getnoise_eta_e3    -> w20 to w22
 *   whitening_du                 -> w19
 *   whitening_dv                 -> w18
 *   whitening_bitslice_transpose -> w0 to w15, w24, then ret
 *   whitening_getnoise_eta_e2    -> w0 to w15, w24, then ret
 *
 * Do not insert code between the entry points.
 */

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
  bn.xor w23, w31, w31

/**
 * Whitening step for _bitslice_eta_3.
 *
 * Zeroize the clobbered WDRs containing coefficients of secret values that
 * _bitslice_eta_3 uses, that is the six digest words w17 to w22, the bit
 * matrices w0 to w15 they are shifted into, and the transpose scratch w24 and
 * w25. Wide registers that contain constants are not wiped.
 *
 * This routine is constant time.
 *
 * clobbered registers: w0 to w15, w17 to w22, w24 to w25
 * clobbered flag groups: FG0
 */

.globl whitening_getnoise_eta_e3
.type whitening_getnoise_eta_e3, @function
whitening_getnoise_eta_e3:
  bn.xor w20, w31, w31
  bn.xor w21, w31, w31
  bn.xor w22, w31, w31

/**
 * Whitening step for polyvec_hocompress.
 *
 * Zeroize the clobbered WDRs containing coefficients of secret values that the
 * modulus switch step in polyvec_hocompress uses, that is the temporaries w17
 * to w19. Wide registers that contain constants (w20 to w22) are not wiped.
 *
 * This routine is constant time.
 *
 * clobbered registers: w0 to w15, w17 to w19, w24 to w25
 * clobbered flag groups: FG0
 */

.globl whitening_du
.type whitening_du, @function
whitening_du:
  bn.xor w19, w31, w31

/**
 * Whitening step for poly_hocompress and masked_poly_tomsg.
 *
 * Zeroize the clobbered WDRs containing coefficients of secret values that the
 * modulus switch step in poly_hocompress and masked_poly_tomsg uses, that is
 * the temporaries w17 and w18. Wide registers that contain constants (w20 to
 * w22) are not wiped.
 *
 * This routine is constant time.
 *
 * clobbered registers: w0 to w15, w17 to w18, w24 to w25
 * clobbered flag groups: FG0
 */

.globl whitening_dv
.type whitening_dv, @function
whitening_dv:
  bn.xor w17, w31, w31
  bn.xor w18, w31, w31

/**
 * Whitening step for _bitslice_transpose.
 *
 * Zeroize the clobbered WDRs containing coefficients of secret values that
 * _bitslice_transpose uses: the bit matrices w0 to w15 and the temporaries w24
 * and w25. Wide registers that contain constants are not wiped.
 *
 * This is the tail of the chain and holds the only `ret`.
 *
 * This routine is constant time.
 *
 * clobbered registers: w0 to w15, w24 to w25
 * clobbered flag groups: FG0
 */

.globl whitening_bitslice_transpose
.type whitening_bitslice_transpose, @function
whitening_bitslice_transpose:

/**
 * Whitening step for _getnoise_eta_2.
 *
 * Zeroize the clobbered WDRs containing coefficients of secret values that
 * _getnoise_eta_2 uses. Only the bitslicing scratch is wiped here, that is the
 * bit matrices w0 to w15 and the temporaries w24 and w25: the squeeze words
 * w17 to w23 are still live across the loop and _getnoise_eta_2 clears them
 * itself before returning. Wide registers that contain constants are not wiped.
 *
 * This is the tail of the chain and holds the only `ret`.
 *
 * This routine is constant time.
 *
 * clobbered registers: w0 to w15, w24 to w25
 * clobbered flag groups: FG0
 */

.globl whitening_getnoise_eta_e2
.type whitening_getnoise_eta_e2, @function
whitening_getnoise_eta_e2:
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
  bn.xor w24, w31, w31
  bn.xor w25, w31, w31
  ret
