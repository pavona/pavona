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
 * De-serialization and subsequent decompression of a polynomial for
 * d in {4, 5}; approximate inverse of poly_compress.
 *
 * Return r = Decompressq(x, d) = round((q / 2^d) * x), where d = 4 for
 * k in {2, 3} and d = 5 for k = 4. This recovers the second ciphertext
 * component v.
 *
 * On return, x10 has been advanced by the 128 or 160 bytes consumed and x11 by
 * one polynomial (512 bytes).
 *
 * This routine is constant time.
 *
 * @param[in]  x10: dmem pointer to the input byte array
 * @param[out] x11: dmem pointer to the output polynomial
 * @param[in]  x12: k, the security level
 * @param[in]  w31: all-zero register
 *
 * clobbered registers: x4 to x5, x10 to x11, w0 to w3, acc, acch
 * clobbered flag groups: FG0
 */

.globl poly_decompress
.type poly_decompress, @function
poly_decompress:
  /* Load constants. */
  addi   x4, x0, 2
  la     x5, const_8
  bn.lid x4, 0(x5)

  addi x4, x0, 4
  beq  x12, x4, _handle_k4_poly_decompress

_handle_kn4_poly_decompress:
  la         x5, const_0x0fff
  addi       x4, x0, 3
  bn.lid     x4, 0(x5)
  bn.shv.16h w3, w3 >> 8 /* 0xf */
  addi       x4, x0, 1

  loopi 4, 11
    bn.lid x0, 0(x10++)
    loopi 4, 8
      loopi 16, 2
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w0, w31, w0 >> 4
      endloop
      bn.and           w1, w1, w3
      bn.mulv.l.16h.lo w1, w1, sw0.0
      bn.addv.16h      w1, w1, w2
      bn.shv.16h       w1, w1 >> 4
      bn.sid           x4, 0(x11++)
    endloop
    nop
  endloop
  ret

_handle_k4_poly_decompress:
  /* The decompression of a is done as follows:
   *    (((a & m) * q) + c) >> d
   * where:
   *    d = 4 for k in {2, 3} and d = 5 for k = 4,
   *    m = (1 << d) - 1,
   *    c = 8 for k in {2, 3} and c = 16 for k = 4.
   *
   * To combine 16 16x16-bit multiplications with q and addition with c,
   * let t = 16 - d and we do:
   *    ((((a & m) << t) * q) + (c << t)) >> 16
   *
   * The addition is the accumulation to acc(h), so we need to write
   * (c << (16 - d)) to acc(h) before the multiplication with q. The final
   * right shift by 16 bits is taking the high 16-bit part of the 32-bit
   * multiplication product. All of this can be done with one bn.mulv.l.16h.acc.hi. */
  addi   x4, x0, 1
  bn.lid x0, 0(x10++)
  loopi 3, 5
    loopi 16, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 5
    endloop
    jal    x1, poly_decompress_k4
    bn.sid x4, 0(x11++)
  endloop

  loopi 3, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 5
  endloop
  bn.rshi w1, w0, w1 >> 1
  bn.lid  x0, 0(x10++)
  bn.rshi w1, w0, w1 >> 15
  bn.rshi w0, w31, w0 >> 4
  loopi 12, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 5
  endloop
  jal    x1, poly_decompress_k4
  bn.sid x4, 0(x11++)

  loopi 2, 5
    loopi 16, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 5
    endloop
    jal    x1, poly_decompress_k4
    bn.sid x4, 0(x11++)
  endloop

  loopi 6, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 5
  endloop
  bn.rshi w1, w0, w1 >> 2
  bn.lid  x0, 0(x10++)
  bn.rshi w1, w0, w1 >> 14
  bn.rshi w0, w31, w0 >> 3
  loopi 9, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 5
  endloop
  jal    x1, poly_decompress_k4
  bn.sid x4, 0(x11++)

  loopi 2, 5
    loopi 16, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 5
    endloop
    jal    x1, poly_decompress_k4
    bn.sid x4, 0(x11++)
  endloop

  loopi 9, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 5
  endloop
  bn.rshi w1, w0, w1 >> 3
  bn.lid  x0, 0(x10++)
  bn.rshi w1, w0, w1 >> 13
  bn.rshi w0, w31, w0 >> 2
  loopi 6, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 5
  endloop
  jal    x1, poly_decompress_k4
  bn.sid x4, 0(x11++)

  loopi 2, 5
    loopi 16, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 5
    endloop
    jal    x1, poly_decompress_k4
    bn.sid x4, 0(x11++)
  endloop

  loopi 12, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 5
  endloop
  bn.rshi w1, w0, w1 >> 4
  bn.lid  x0, 0(x10++)
  bn.rshi w1, w0, w1 >> 12
  bn.rshi w0, w31, w0 >> 1
  loopi 3, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 5
  endloop
  jal    x1, poly_decompress_k4
  bn.sid x4, 0(x11++)

  loopi 3, 5
    loopi 16, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 5
    endloop
    jal    x1, poly_decompress_k4
    bn.sid x4, 0(x11++)
  endloop
  ret

/**
 * Decompression of 16 coefficients with d = 5, for KYBER_K = 4; subroutine of
 * poly_decompress.
 *
 * This routine is constant time.
 *
 * @param[in,out] w1: input vector with 16 5-bit compressed coefficients, which
 *                    is overwritten with the 16 16-bit output coefficients
 * @param[in]     w2: const_8
 *
 * clobbered registers: w1, acc, acch
 * clobbered flag groups: none
 */

.type poly_decompress_k4, @function
poly_decompress_k4:
  bn.shv.16h           w1, w1 << 11 /* << 11 */
  bn.wsrw              acc, w2      /* Write const_8 to acc. */
  bn.wsrw              acch, w2     /* Write const_8 to acch. */
  bn.mulv.l.16h.acc.hi w1, w1, sw0.0 /* * q + acc(h) */
  ret

/**
 * De-serialization and subsequent decompression of a polynomial for
 * d in {10, 11}; approximate inverse of poly_polyvec_compress.
 *
 * Return r = Decompressq(x, d) = round((q / 2^d) * x), where d = 10 for
 * k in {2, 3} and d = 11 for k = 4. This recovers one polynomial of the first
 * ciphertext component u.
 *
 * On return, x10 has been advanced by the 320 or 352 bytes consumed and x11 by
 * one polynomial (512 bytes).
 *
 * This routine is constant time.
 *
 * @param[in]  x10: dmem pointer to the input byte array
 * @param[out] x11: dmem pointer to the output polynomial
 * @param[in]  x12: k, the security level
 * @param[in]  w31: all-zero register
 *
 * clobbered registers: x4 to x5, x10 to x11, w0 to w3, acc, acch
 * clobbered flag groups: none
 */

.globl poly_polyvec_decompress
.type poly_polyvec_decompress, @function
poly_polyvec_decompress:
  /* Load constants. */
  la        x5, const_8
  addi      x4, x0, 2
  bn.lid    x4++, 0(x5)
  bn.shv.8s w2, w2 << 16
  bn.shv.8s w2, w2 >> 4 /* w2 = (0x00008000)^8 */
  la        x5, const_0x0fff
  bn.lid    x4++, 0(x5)

  /* The decompression of a is done as follows:
   *    (((a & m) * q) + c) >> d
   * where:
   *    d = 10 for k in {2, 3} and d = 11 for k = 4,
   *    m = (1 << d) - 1,
   *    c = 512 for k in {2, 3} and c = 1024 for k = 4.
   *
   * To combine 16 16x16-bit multiplications with q and addition with c,
   * let t = 16 - d and we do:
   *    ((((a & m) << t) * q) + (c << t)) >> 16
   *
   * The addition is the accumulation to acc(h), so we need to write
   * (c << (16 - d)) to acc(h) before the multiplication with q. The final
   * right shift by 16 bits is taking the high 16-bit part of the 32-bit
   * multiplication product. All of this can be done with one bn.mulv.l.16h.acc.hi. */
  beq  x12, x4, _handle_k4_polyvec_decompress

_handle_kn4_polyvec_decompress:
  addi x4, x0, 1
  loopi 2, 69
    bn.lid x0, 0(x10++)
    loopi 16, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 10
    endloop
    jal    x1, polyvec_decompress_kn4
    bn.sid x4, 0(x11++)

    loopi 9, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 10
    endloop
    bn.rshi w1, w0, w1 >> 6
    bn.lid  x0, 0(x10++)
    bn.rshi w1, w0, w1 >> 10
    bn.rshi w0, w31, w0 >> 4
    loopi 6, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 10
    endloop
    jal x1, polyvec_decompress_kn4
    bn.sid x4, 0(x11++)

    loopi 16, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 10
    endloop
    jal    x1, polyvec_decompress_kn4
    bn.sid x4, 0(x11++)

    loopi 3, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 10
    endloop
    bn.rshi w1, w0, w1 >> 2
    bn.lid  x0, 0(x10++)
    bn.rshi w1, w0, w1 >> 14
    bn.rshi w0, w31, w0 >> 8
    loopi 12, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 10
    endloop
    jal    x1, polyvec_decompress_kn4
    bn.sid x4, 0(x11++)

    loopi 12, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 10
    endloop
    bn.rshi w1, w0, w1 >> 8
    bn.lid  x0, 0(x10++)
    bn.rshi w1, w0, w1 >> 8
    bn.rshi w0, w31, w0 >> 2
    loopi 3, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 10
    endloop
    jal    x1, polyvec_decompress_kn4
    bn.sid x4, 0(x11++)

    loopi 16, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 10
    endloop
    jal    x1, polyvec_decompress_kn4
    bn.sid x4, 0(x11++)

    loopi 6, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 10
    endloop
    bn.rshi w1, w0, w1 >> 4
    bn.lid  x0, 0(x10++)
    bn.rshi w1, w0, w1 >> 12
    bn.rshi w0, w31, w0 >> 6
    loopi 9, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 10
    endloop
    jal    x1, polyvec_decompress_kn4
    bn.sid x4, 0(x11++)

    loopi 16, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 10
    endloop
    jal    x1, polyvec_decompress_kn4
    bn.sid x4, 0(x11++)
  endloop
  ret

_handle_k4_polyvec_decompress:
  addi   x4, x0, 1
  bn.lid x0, 0(x10++)
  loopi 16, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 11
  endloop
  jal    x1, polyvec_decompress_k4
  bn.sid x4, 0(x11++)

  loopi 7, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 11
  endloop
  bn.rshi w1, w0, w1 >> 3
  bn.lid  x0, 0(x10++)
  bn.rshi w1, w0, w1 >> 13
  bn.rshi w0, w31, w0 >> 8
  loopi 8, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 11
  endloop
  jal    x1, polyvec_decompress_k4
  bn.sid x4, 0(x11++)

  loopi 14, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 11
  endloop
  bn.rshi              w1, w0, w1 >> 6
  bn.lid               x0, 0(x10++)
  bn.rshi              w1, w0, w1 >> 10
  bn.rshi              w0, w31, w0 >> 5
  bn.rshi              w1, w0, w1 >> 16
  bn.rshi              w0, w31, w0 >> 11
  jal    x1, polyvec_decompress_k4
  bn.sid x4, 0(x11++)

  loopi 16, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 11
  endloop
  jal    x1, polyvec_decompress_k4
  bn.sid x4, 0(x11++)

  loopi 5, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 11
  endloop
  bn.rshi w1, w0, w1 >> 9
  bn.lid  x0, 0(x10++)
  bn.rshi w1, w0, w1 >> 7
  bn.rshi w0, w31, w0 >> 2
  loopi 10, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 11
  endloop
  jal    x1, polyvec_decompress_k4
  bn.sid x4, 0(x11++)

  loopi 13, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 11
  endloop
  bn.rshi w1, w0, w1 >> 1
  bn.lid  x0, 0(x10++)
  bn.rshi w1, w0, w1 >> 15
  bn.rshi w0, w31, w0 >> 10
  loopi 2, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 11
  endloop
  jal    x1, polyvec_decompress_k4
  bn.sid x4, 0(x11++)

  loopi 16, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 11
  endloop
  jal    x1, polyvec_decompress_k4
  bn.sid x4, 0(x11++)

  loopi 4, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 11
  endloop
  bn.rshi w1, w0, w1 >> 4
  bn.lid  x0, 0(x10++)
  bn.rshi w1, w0, w1 >> 12
  bn.rshi w0, w31, w0 >> 7
  loopi 11, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 11
  endloop
  jal    x1, polyvec_decompress_k4
  bn.sid x4, 0(x11++)

  loopi 11, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 11
  endloop
  bn.rshi w1, w0, w1 >> 7
  bn.lid  x0, 0(x10++)
  bn.rshi w1, w0, w1 >> 9
  bn.rshi w0, w31, w0 >> 4
  loopi 4, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 11
  endloop
  jal    x1, polyvec_decompress_k4
  bn.sid x4, 0(x11++)

  loopi 16, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 11
  endloop
  jal    x1, polyvec_decompress_k4
  bn.sid x4, 0(x11++)

  loopi 2, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 11
  endloop
  bn.rshi w1, w0, w1 >> 10
  bn.lid  x0, 0(x10++)
  bn.rshi w1, w0, w1 >> 6
  bn.rshi w0, w31, w0 >> 1
  loopi 13, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 11
  endloop
  jal    x1, polyvec_decompress_k4
  bn.sid x4, 0(x11++)

  loopi 10, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 11
  endloop
  bn.rshi w1, w0, w1 >> 2
  bn.lid  x0, 0(x10++)
  bn.rshi w1, w0, w1 >> 14
  bn.rshi w0, w31, w0 >> 9
  loopi 5, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 11
  endloop
  jal    x1, polyvec_decompress_k4
  bn.sid x4, 0(x11++)

  loopi 16, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 11
  endloop
  jal    x1, polyvec_decompress_k4
  bn.sid x4, 0(x11++)

  bn.rshi w1, w0, w1 >> 16
  bn.rshi w0, w31, w0 >> 11
  bn.rshi w1, w0, w1 >> 5
  bn.lid  x0, 0(x10++)
  bn.rshi w1, w0, w1 >> 11
  bn.rshi w0, w31, w0 >> 6
  loopi 14, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 11
  endloop
  jal    x1, polyvec_decompress_k4
  bn.sid x4, 0(x11++)

  loopi 8, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 11
  endloop
  bn.rshi w1, w0, w1 >> 8
  bn.lid  x0, 0(x10++)
  bn.rshi w1, w0, w1 >> 8
  bn.rshi w0, w31, w0 >> 3
  loopi 7, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 11
  endloop
  jal    x1, polyvec_decompress_k4
  bn.sid x4, 0(x11++)

  loopi 16, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 11
  endloop
  jal    x1, polyvec_decompress_k4
  bn.sid x4, 0(x11++)
  ret

/**
 * Decompression of 16 coefficients with d = 10, for KYBER_K = {2, 3};
 * subroutine of poly_polyvec_decompress.
 *
 * This routine is constant time.
 *
 * @param[in,out] w1: input vector with 16 10-bit compressed coefficients, which
 *                    is overwritten with the 16 16-bit output coefficients
 * @param[in]     w2: (0x00008000)^8
 *
 * clobbered registers: w1, acc, acch
 * clobbered flag groups: none
 */

.type polyvec_decompress_kn4, @function
polyvec_decompress_kn4:
  bn.shv.16h           w1, w1 << 6   /* *(2**6) */
  bn.wsrw              acc, w2       /* Write (0x00008000) to acc. */
  bn.wsrw              acch, w2      /* Write (0x00008000) to acch. */
  bn.mulv.l.16h.acc.hi w1, w1, sw0.0 /* * q + acc(h) */
  ret

/**
 * Decompression of 16 coefficients with d = 11, for KYBER_K = 4; subroutine of
 * poly_polyvec_decompress.
 *
 * This routine is constant time.
 *
 * @param[in,out] w1: input vector with 16 11-bit compressed coefficients, which
 *                    is overwritten with the 16 16-bit output coefficients
 * @param[in]     w2: (0x00008000)^8
 *
 * clobbered registers: w1, acc, acch
 * clobbered flag groups: none
 */

.type polyvec_decompress_k4, @function
polyvec_decompress_k4:
  bn.shv.16h           w1, w1 << 5    /* *(2**5) */
  bn.wsrw              acc, w2        /* Write (0x00008000) to acc. */
  bn.wsrw              acch, w2       /* Write (0x00008000) to acch. */
  bn.mulv.l.16h.acc.hi w1, w1, sw0.0  /* * q + acc(h) */
  ret
