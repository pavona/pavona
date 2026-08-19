/* Copyright zeroRISC Inc. */
/* Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192). */
/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors. */
/* Modified by Ruben Niederhagen and Hoang Nguyen Hien Pham - authors of */
/* "Improving ML-KEM & ML-DSA on OpenTitan - Efficient Multiplication Vector Instructions for OTBN" */
/* (https://eprint.iacr.org/2025/2028). */
/* Copyright Ruben Niederhagen and Hoang Nguyen Hien Pham. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

/**
 * Pair-pointwise multiplication of two polynomials in the NTT domain.
 *
 * Return r = x * y * R^-1 mod q with R = 2^16, where x and y are polynomials
 * with n = 256 coefficients in Z_q for q = 3329, both given in NTT domain.
 * The R^-1 factor stems from the Montgomery reduction of each coefficient
 * product; callers either remove it with poly_tomont or absorb it into intt.
 *
 * This routine only zeroes the destination r and then falls through into
 * basemul_acc, so it has the same register requirements.
 *
 * On return, x10, x11 and x13 have been advanced by one polynomial
 * (512 bytes), so that consecutive calls walk a polynomial vector, and x12 has
 * been restored to its original value.
 *
 * This routine is constant time.
 *
 * @param[in]  x10: dmem pointer to x
 * @param[in]  x11: dmem pointer to y
 * @param[in]  x12: dmem pointer to the twiddle factors twiddles_basemul
 * @param[out] x13: dmem pointer to r
 * @param[in]  w31: all-zero register
 * @param[in]  mod: 2q
 *
 * clobbered registers: x4, x10 to x13, w0 to w15, w17 to w26, acc, acch
 * clobbered flag groups: none
 */

.globl basemul
.type basemul, @function
basemul:
  /* basemul is basemul_acc with a zeroed destination. The stores also
   * initialize the destination before basemul_acc reads it back. */
  addi   x4, x0, 31
  bn.sid x4, 0(x13)
  bn.sid x4, 32(x13)
  bn.sid x4, 64(x13)
  bn.sid x4, 96(x13)
  bn.sid x4, 128(x13)
  bn.sid x4, 160(x13)
  bn.sid x4, 192(x13)
  bn.sid x4, 224(x13)
  bn.sid x4, 256(x13)
  bn.sid x4, 288(x13)
  bn.sid x4, 320(x13)
  bn.sid x4, 352(x13)
  bn.sid x4, 384(x13)
  bn.sid x4, 416(x13)
  bn.sid x4, 448(x13)
  bn.sid x4, 480(x13)
  /* Fall through into basemul_acc. */


/**
 * Accumulating pair-pointwise multiplication of two polynomials in the NTT
 * domain.
 *
 * Compute r += x * y * R^-1 mod q with R = 2^16, where x and y are polynomials
 * with n = 256 coefficients in Z_q for q = 3329, both given in NTT domain.
 * The R^-1 factor stems from the Montgomery reduction of each coefficient
 * product; callers either remove it with poly_tomont or absorb it into intt.
 *
 * On return, x10, x11 and x13 have been advanced by one polynomial
 * (512 bytes), so that consecutive calls walk a polynomial vector, and x12 has
 * been restored to its original value.
 *
 * This routine is constant time.
 *
 * @param[in]     x10: dmem pointer to x
 * @param[in]     x11: dmem pointer to y
 * @param[in]     x12: dmem pointer to the twiddle factors twiddles_basemul
 * @param[in,out] x13: dmem pointer to r
 * @param[in]     w31: all-zero register
 * @param[in]     mod: 2q
 *
 * clobbered registers: x4, x10 to x13, w0 to w15, w17 to w26, acc, acch
 * clobbered flag groups: none
 */

.globl basemul_acc
.type basemul_acc, @function
basemul_acc:
  /* Set up wide registers for inputs*/
  loopi 2, 164
    /* Load x. */
    add    x4, x0, x0
    bn.lid x4++, 0(x10)
    bn.lid x4++, 32(x10)
    bn.lid x4++, 64(x10)
    bn.lid x4++, 96(x10)
    bn.lid x4++, 128(x10)
    bn.lid x4++, 160(x10)
    bn.lid x4++, 192(x10)
    bn.lid x4++, 224(x10)

    /* Load y. */
    bn.lid x4++, 0(x11)
    bn.lid x4++, 32(x11)
    bn.lid x4++, 64(x11)
    bn.lid x4++, 96(x11)
    bn.lid x4++, 128(x11)
    bn.lid x4++, 160(x11)
    bn.lid x4++, 192(x11)
    bn.lid x4++, 224(x11)

    /* Point to the next half of the input polynomials. */
    addi x10, x10, 256
    addi x11, x11, 256

    /* For the following steps, we consider a = (x[i], x[i + 1]) and b = (y[i], y[i + 1])
     * for i = [0,2,4..14]. We will do the following:
     *  - Step 1: Compute s[0] = a[0] * b[0] and s[1] = a[1] * b[1].
     *  - Step 2: Compute s[1] = s[1] * zeta.
     *  - Step 3: Compute s'[0] = a[0] * b[1] and s'[1] = a[1] * b[0].
     *  - Step 4: Compute r[0] += (a[1] * b[1] * zeta) + a[0] * b[0] = s[1] + s[0] and
     *                    r[1] += (a[0] * b[1]) + (a[1] * b[0]) = s'[1] + s'[0].
     */

    /* Step 1: Compute s[i] = a[i] * b[i]. */
    bn.mulv.16h.acc.z.lo w25, w0, w8
    bn.mulv.l.16h.lo     w25, w25, sw0.2
    bn.mulv.l.16h.acc.hi w25, w25, sw0.0

    bn.mulv.16h.acc.z.lo w17, w1, w9
    bn.mulv.l.16h.lo     w17, w17, sw0.2
    bn.mulv.l.16h.acc.hi w17, w17, sw0.0

    bn.mulv.16h.acc.z.lo w18, w2, w10
    bn.mulv.l.16h.lo     w18, w18, sw0.2
    bn.mulv.l.16h.acc.hi w18, w18, sw0.0

    bn.mulv.16h.acc.z.lo w19, w3, w11
    bn.mulv.l.16h.lo     w19, w19, sw0.2
    bn.mulv.l.16h.acc.hi w19, w19, sw0.0

    bn.mulv.16h.acc.z.lo w20, w4, w12
    bn.mulv.l.16h.lo     w20, w20, sw0.2
    bn.mulv.l.16h.acc.hi w20, w20, sw0.0

    bn.mulv.16h.acc.z.lo w21, w5, w13
    bn.mulv.l.16h.lo     w21, w21, sw0.2
    bn.mulv.l.16h.acc.hi w21, w21, sw0.0

    bn.mulv.16h.acc.z.lo w22, w6, w14
    bn.mulv.l.16h.lo     w22, w22, sw0.2
    bn.mulv.l.16h.acc.hi w22, w22, sw0.0

    bn.mulv.16h.acc.z.lo w23, w7, w15
    bn.mulv.l.16h.lo     w23, w23, sw0.2
    bn.mulv.l.16h.acc.hi w23, w23, sw0.0

    /* Step 2: Compute s[1] = s[1] * zeta.
     * To improve performance, we group all the elements that needed to be multiplied by roots
     * of unity into one vector using bn.trn. After multiplication, we return the results to
     * the original vectors. */
    addi                 x4, x0, 26
    bn.lid               x4, 0(x12++)
    bn.trn2.16h          w24, w25, w17
    bn.mulv.16h.acc.z.lo w24, w24, w26
    bn.mulv.l.16h.lo     w24, w24, sw0.2
    bn.mulv.l.16h.acc.hi w24, w24, sw0.0
    bn.trn1.16h          w25, w25, w24
    bn.rshi              w24, w31, w24 >> 16
    bn.trn1.16h          w17, w17, w24

    bn.lid               x4, 0(x12++)
    bn.trn2.16h          w24, w18, w19
    bn.mulv.16h.acc.z.lo w24, w24, w26
    bn.mulv.l.16h.lo     w24, w24, sw0.2
    bn.mulv.l.16h.acc.hi w24, w24, sw0.0
    bn.trn1.16h          w18, w18, w24
    bn.rshi              w24, w31, w24 >> 16
    bn.trn1.16h          w19, w19, w24

    bn.lid               x4, 0(x12++)
    bn.trn2.16h          w24, w20, w21
    bn.mulv.16h.acc.z.lo w24, w24, w26
    bn.mulv.l.16h.lo     w24, w24, sw0.2
    bn.mulv.l.16h.acc.hi w24, w24, sw0.0
    bn.trn1.16h          w20, w20, w24
    bn.rshi              w24, w31, w24 >> 16
    bn.trn1.16h          w21, w21, w24

    bn.lid               x4, 0(x12++)
    bn.trn2.16h          w24, w22, w23
    bn.mulv.16h.acc.z.lo w24, w24, w26
    bn.mulv.l.16h.lo     w24, w24, sw0.2
    bn.mulv.l.16h.acc.hi w24, w24, sw0.0
    bn.trn1.16h          w22, w22, w24
    bn.rshi              w24, w31, w24 >> 16
    bn.trn1.16h          w23, w23, w24

    /* Step 3: Compute s'[0] = a[0] * b[1] and s'[1] = a[1] * b[0].
     *  - Swap (b[0], b[1]) <- (b[1], b[0]).
     *  - Compute s'[i] = a[i] * b[i]. */
    bn.rshi              w24, w31, w8 >> 16
    bn.trn1.16h          w8, w24, w8
    bn.mulv.16h.acc.z.lo w8, w0, w8
    bn.mulv.l.16h.lo     w8, w8, sw0.2
    bn.mulv.l.16h.acc.hi w8, w8, sw0.0

    bn.rshi              w24, w31, w9 >> 16
    bn.trn1.16h          w9, w24, w9
    bn.mulv.16h.acc.z.lo w9, w1, w9
    bn.mulv.l.16h.lo     w9, w9, sw0.2
    bn.mulv.l.16h.acc.hi w9, w9, sw0.0

    bn.rshi              w24, w31, w10 >> 16
    bn.trn1.16h          w10, w24, w10
    bn.mulv.16h.acc.z.lo w10, w2, w10
    bn.mulv.l.16h.lo     w10, w10, sw0.2
    bn.mulv.l.16h.acc.hi w10, w10, sw0.0

    bn.rshi              w24, w31, w11 >> 16
    bn.trn1.16h          w11, w24, w11
    bn.mulv.16h.acc.z.lo w11, w3, w11
    bn.mulv.l.16h.lo     w11, w11, sw0.2
    bn.mulv.l.16h.acc.hi w11, w11, sw0.0

    bn.rshi              w24, w31, w12 >> 16
    bn.trn1.16h          w12, w24, w12
    bn.mulv.16h.acc.z.lo w12, w4, w12
    bn.mulv.l.16h.lo     w12, w12, sw0.2
    bn.mulv.l.16h.acc.hi w12, w12, sw0.0

    bn.rshi              w24, w31, w13 >> 16
    bn.trn1.16h          w13, w24, w13
    bn.mulv.16h.acc.z.lo w13, w5, w13
    bn.mulv.l.16h.lo     w13, w13, sw0.2
    bn.mulv.l.16h.acc.hi w13, w13, sw0.0

    bn.rshi              w24, w31, w14 >> 16
    bn.trn1.16h          w14, w24, w14
    bn.mulv.16h.acc.z.lo w14, w6, w14
    bn.mulv.l.16h.lo     w14, w14, sw0.2
    bn.mulv.l.16h.acc.hi w14, w14, sw0.0

    bn.rshi              w24, w31, w15 >> 16
    bn.trn1.16h          w15, w24, w15
    bn.mulv.16h.acc.z.lo w15, w7, w15
    bn.mulv.l.16h.lo     w15, w15, sw0.2
    bn.mulv.l.16h.acc.hi w15, w15, sw0.0

    /* Step 4: Compute r[0] += (a[1] * b[1] * zeta) + a[0] * b[0] and
     *                 r[1] += (a[0] * b[1]) + (a[1] * b[0]).
     *
     *  - Compute (s[1], s[0])   <- (s'[0], s[0]) = (a[0] * b[1], a[0] * b[0]).
     *  - Compute (s'[1], s'[0]) <- (s'[1], s[1]) = (a[1] * b[0], a[1] * b[1] * zeta).
     *  - Compute r[i] += (s[i] + s'[i]).
     */
    bn.trn1.16h  w0, w25, w8
    bn.trn2.16h  w8, w25, w8
    bn.addvm.16h w8, w0, w8
    bn.lid       x0, 0(x13)
    bn.addvm.16h w0, w0, w8
    bn.sid       x0, 0(x13++)

    bn.trn1.16h  w1, w17, w9
    bn.trn2.16h  w9, w17, w9
    bn.addvm.16h w1, w1, w9
    bn.lid       x0, 0(x13)
    bn.addvm.16h w0, w0, w1
    bn.sid       x0, 0(x13++)

    bn.trn1.16h  w2, w18, w10
    bn.trn2.16h  w10, w18, w10
    bn.addvm.16h w2, w2, w10
    bn.lid       x0, 0(x13)
    bn.addvm.16h w0, w0, w2
    bn.sid       x0, 0(x13++)

    bn.trn1.16h  w3, w19, w11
    bn.trn2.16h  w11, w19, w11
    bn.addvm.16h w3, w3, w11
    bn.lid       x0, 0(x13)
    bn.addvm.16h w0, w0, w3
    bn.sid       x0, 0(x13++)

    bn.trn1.16h  w4, w20, w12
    bn.trn2.16h  w12, w20, w12
    bn.addvm.16h w4, w4, w12
    bn.lid       x0, 0(x13)
    bn.addvm.16h w0, w0, w4
    bn.sid       x0, 0(x13++)

    bn.trn1.16h  w5, w21, w13
    bn.trn2.16h  w13, w21, w13
    bn.addvm.16h w5, w5, w13
    bn.lid       x0, 0(x13)
    bn.addvm.16h w0, w0, w5
    bn.sid       x0, 0(x13++)

    bn.trn1.16h  w6, w22, w14
    bn.trn2.16h  w14, w22, w14
    bn.addvm.16h w6, w6, w14
    bn.lid       x0, 0(x13)
    bn.addvm.16h w0, w0, w6
    bn.sid       x0, 0(x13++)

    bn.trn1.16h  w7, w23, w15
    bn.trn2.16h  w15, w23, w15
    bn.addvm.16h w7, w7, w15
    bn.lid       x0, 0(x13)
    bn.addvm.16h w0, w0, w7
    bn.sid       x0, 0(x13++)
  endloop

  /* Reset twiddle pointer. */
  addi x12, x12, -256
  ret
