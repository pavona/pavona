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
 * Conversion of a 32-byte message into a polynomial.
 *
 * Map every one of the 256 message bits to one coefficient, sending a 0 bit to
 * 0 and a 1 bit to (q + 1) / 2 = 1665.
 *
 * On return, x11 has been advanced by one polynomial (512 bytes).
 *
 * This routine is constant time.
 *
 * @param[in]  x10: dmem pointer to the input byte array
 * @param[out] x11: dmem pointer to the output polynomial
 * @param[in]  w31: all-zero register
 *
 * clobbered registers: x4 to x5, x11, w0 to w1, w3
 * clobbered flag groups: FG0
 */

.globl poly_frommsg
.type poly_frommsg, @function
poly_frommsg:
  la     x5, const_qp1_half
  addi   x4, x0, 3
  bn.lid x4, 0(x5)

  addi   x4, x0, 1
  bn.lid x0, 0(x10)
  loopi 16, 7
    loopi 16, 3
      bn.rshi w1, w0, w1 >> 1
      bn.rshi w1, w31, w1 >> 15
      bn.rshi w0, w31, w0 >> 1
    endloop
    bn.subv.16h w1, w31, w1
    bn.and      w1, w1, w3
    bn.sid      x4, 0(x11++)
  endloop
  ret

/**
 * Conversion of a polynomial into a 32-byte message.
 *
 * Compress every coefficient down to a single bit, that is r = Compress(x, 1),
 * which yields 1 exactly for the coefficients that are closer to
 * (q + 1) / 2 = 1665 than to 0.
 *
 * On return, x10 has been advanced by one polynomial (512 bytes).
 *
 * This routine is constant time.
 *
 * @param[in]  x10: dmem pointer to the input polynomial
 * @param[out] x11: dmem pointer to the output byte array
 * @param[in]  w31: all-zero register
 *
 * clobbered registers: x4 to x5, x10, w0 to w3, w17
 * clobbered flag groups: FG0
 */

.globl poly_tomsg
.type poly_tomsg, @function
poly_tomsg:
  /* Load constants. */
  la        x5, const_qp1_half
  addi      x4, x0, 2
  bn.lid    x4, 0(x5) /* w2 = (0x681)^16 */
  la        x5, const_m_dv
  addi      x4, x0, 17
  bn.lid    x4, 0(x5)
  bn.shv.8s w17, w17 >> 8 /* 1290167 */
  bn.subi   w17, w17, 7   /* w17 = 1290160 = 80635 << 4 */

  loopi 16, 14
    bn.lid               x0, 0(x10++)
    bn.shv.16h           w0, w0 << 1   /* <= 1 */
    bn.addv.16h          w0, w0, w2    /* += 1665 */
    bn.trn1.16h          w1, w0, w31   /* Put even coeffs in 32-bit slots. */
    bn.mulv.l.8s.even.hi w1, w1, sw1.0 /* >> 32 = high parts of 64-bit products. */
    bn.mulv.l.8s.odd.hi  w1, w1, sw1.0 /* >> 32 = high parts of 64-bit products. */
    bn.trn2.16h          w0, w0, w31   /* Put odd coeffs to 32-bit slots. */
    bn.mulv.l.8s.even.hi w0, w0, sw1.0 /* >> 32 = high parts of 64-bit products. */
    bn.mulv.l.8s.odd.hi  w0, w0, sw1.0 /* >> 32 = high parts of 64-bit products. */
    bn.trn1.16h          w0, w1, w0
    loopi 16, 2
      bn.rshi w3, w0, w3 >> 1
      bn.rshi w0, w31, w0 >> 16
    endloop
    nop
  endloop
  addi   x4, x0, 3
  bn.sid x4, 0(x11)

  ret

/**
 * Modular addition of two polynomials.
 *
 * Return r = (x + y) mod q, coefficient by coefficient, for whichever modulus
 * the mod WSR currently holds.
 *
 * On return, x10, x11 and x12 have been advanced by one polynomial
 * (512 bytes), so that consecutive calls walk a polynomial vector.
 *
 * This routine is constant time.
 *
 * @param[in]  x10: dmem pointer to x
 * @param[in]  x11: dmem pointer to y
 * @param[out] x12: dmem pointer to r
 * @param[in]  mod: the modulus q
 *
 * clobbered registers: x4, x10 to x12, w0 to w1
 * clobbered flag groups: none
 */

.globl poly_add
.type poly_add, @function
poly_add:
  addi x4, x0, 1
  loopi 16, 4
    bn.lid       x0, 0(x10++)
    bn.lid       x4, 0(x11++)
    bn.addvm.16h w0, w0, w1
    bn.sid       x0, 0(x12++)
  endloop
  ret

/**
 * Modular subtraction of two polynomials.
 *
 * Return r = (x - y) mod q, coefficient by coefficient, for whichever modulus
 * the mod WSR currently holds.
 *
 * On return, x10, x11 and x12 have been advanced by one polynomial
 * (512 bytes), so that consecutive calls walk a polynomial vector.
 *
 * This routine is constant time.
 *
 * @param[in]  x10: dmem pointer to x
 * @param[in]  x11: dmem pointer to y
 * @param[out] x12: dmem pointer to r
 * @param[in]  mod: the modulus q
 *
 * clobbered registers: x4, x10 to x12, w0 to w1
 * clobbered flag groups: none
 */

.globl poly_sub
.type poly_sub, @function
poly_sub:
  addi x4, x0, 1
  loopi 16, 4
    bn.lid       x0, 0(x10++)
    bn.lid       x4, 0(x11++)
    bn.subvm.16h w0, w0, w1
    bn.sid       x0, 0(x12++)
  endloop
  ret

/**
 * In-place conversion of a polynomial into the Montgomery domain.
 *
 * Multiply every coefficient by R = 2^16 mod q, by multiplying with the
 * precomputed constant 2^32 mod q and then applying a Montgomery reduction.
 * This is also how callers strip the R^-1 factor that basemul and basemul_acc
 * leave behind.
 *
 * On return, x10 has been advanced by one polynomial (512 bytes).
 *
 * This routine is constant time.
 *
 * @param[in,out] x10: dmem pointer to x
 * @param[in]     w16 (sw0): sw0.0 = q = 3329 (1st 16-bit lane),
 *                           sw0.2 = -q^-1 mod 2^16 = 3327 (3rd 16-bit lane)
 * @param[in]     w31: all-zero register
 *
 * clobbered registers: x4 to x5, x10, w0 to w1, acch, acc
 * clobbered flag groups: none
 */

.globl poly_tomont
.type poly_tomont, @function
poly_tomont:
  la     x5, const_2_32_modq
  add    x4, x0, x0
  bn.lid x4++, 0(x5)

  loopi 16, 6
    bn.lid               x4, 0(x10)
    bn.mulv.16h.acc.z.lo w1, w0, w1
    bn.mulv.l.16h.lo     w1, w1, sw0.2
    bn.mulv.l.16h.acc.hi w1, w1, sw0.0
    bn.addvm.16h         w1, w1, w31
    bn.sid               x4, 0(x10++)
  endloop
  ret
