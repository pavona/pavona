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
 * Serialization of a polynomial into KYBER_POLYBYTES = 384 bytes.
 *
 * Pack the 256 coefficients of a polynomial into 384 bytes, 12 bits each.
 *
 * On return, x10 has been advanced by one polynomial (512 bytes) and x11 by
 * KYBER_POLYBYTES, so that consecutive calls walk a polynomial vector.
 *
 * This routine is constant time.
 *
 * @param[in]  x10: dmem pointer to the input polynomial
 * @param[out] x11: dmem pointer to the output byte array
 * @param[in]  w31: all-zero register
 * @param[in]  mod: q = 3329
 *
 * clobbered registers: x4, x10 to x11, w0 to w1
 * clobbered flag groups: none
 */

.globl poly_tobytes
.type poly_tobytes, @function
poly_tobytes:
  addi x4, x0, 1
  loopi 4, 37
    bn.lid       x0, 0(x10++)
    /* Reduce inputs to [0,q) because outputs of NTT without final conditional
     * subtraction in Montgomery multiplication are in [0,2q). */
    bn.addvm.16h w0, w0, w31
    loopi 16, 2
      bn.rshi w1, w0, w1 >> 12
      bn.rshi w0, w31, w0 >> 16
    endloop
    bn.lid       x0, 0(x10++)
    bn.addvm.16h w0, w0, w31
    loopi 5, 2
      bn.rshi w1, w0, w1 >> 12
      bn.rshi w0, w31, w0 >> 16
    endloop
    bn.rshi w1, w0, w1 >> 4
    bn.rshi w0, w31, w0 >> 4
    bn.sid  x4, 0(x11++)

    bn.rshi w1, w0, w1 >> 8
    bn.rshi w0, w31, w0  >> 12
    loopi 10, 2
      bn.rshi w1, w0, w1 >> 12
      bn.rshi w0, w31, w0 >> 16
    endloop
    bn.lid       x0, 0(x10++)
    bn.addvm.16h w0, w0, w31
    loopi 10, 2
      bn.rshi w1, w0, w1 >> 12
      bn.rshi w0, w31, w0 >> 16
    endloop
    bn.rshi w1, w0, w1 >> 8
    bn.rshi w0, w31, w0 >> 8
    bn.sid  x4, 0(x11++)

    bn.rshi w1, w0, w1 >> 4
    bn.rshi w0, w31, w0 >> 8
    loopi 5, 2
      bn.rshi w1, w0, w1 >> 12
      bn.rshi w0, w31, w0 >> 16
    endloop
    bn.lid       x0, 0(x10++)
    bn.addvm.16h w0, w0, w31
    loopi 16, 2
      bn.rshi w1, w0, w1 >> 12
      bn.rshi w0, w31, w0 >> 16
    endloop
    bn.sid x4, 0(x11++)
  endloop
  ret

/**
 * De-serialization of a polynomial; inverse of poly_tobytes.
 *
 * Unpack KYBER_POLYBYTES = 384 bytes into the 256 coefficients of a
 * polynomial, 12 bits each.
 *
 * On return, x10 has been advanced by KYBER_POLYBYTES and x11 by one
 * polynomial (512 bytes), so that consecutive calls walk a polynomial vector.
 *
 * This routine is constant time.
 *
 * @param[in]  x10: dmem pointer to the input byte array
 * @param[out] x11: dmem pointer to the output polynomial
 * @param[in]  w31: all-zero register
 *
 * clobbered registers: x4, x10 to x11, w0 to w2
 * clobbered flag groups: FG0
 */

.globl poly_frombytes
.type poly_frombytes, @function
poly_frombytes:
  bn.subi    w2, w31, 1
  bn.shv.16h w2, w2 >> 4

  addi x4, x0, 1
  loopi 4, 35
    bn.lid x0, 0(x10++)

    loopi 16, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 12
    endloop
    bn.and w1, w1, w2
    bn.sid x4, 0(x11++)

    loopi 5, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 12
    endloop
    bn.rshi w1, w0, w1 >> 4
    bn.lid  x0, 0(x10++)
    bn.rshi w1, w0, w1 >> 12
    bn.rshi w0, w31, w0 >> 8
    loopi 10, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 12
    endloop
    bn.and w1, w1, w2
    bn.sid x4, 0(x11++)

    loopi 10, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 12
    endloop
    bn.rshi w1, w0, w1 >> 8
    bn.lid  x0, 0(x10++)
    bn.rshi w1, w0, w1 >> 8
    bn.rshi w0, w31, w0 >> 4
    loopi 5, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 12
    endloop
    bn.and w1, w1, w2
    bn.sid x4, 0(x11++)

    loopi 16, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 12
    endloop
    bn.and w1, w1, w2
    bn.sid x4, 0(x11++)
  endloop
  ret
