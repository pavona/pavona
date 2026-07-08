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

/* Hardened boolean values. Should match the values in `hardened_asm.h`. */
.equ HARDENED_BOOL_TRUE, 0x739
.equ HARDENED_BOOL_FALSE, 0x1d4

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
      bn.rshi w0, w0, w0 >> 12
    endloop
    bn.and w1, w1, w2
    bn.sid x4, 0(x11++)

    loopi 5, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w0, w0 >> 12
    endloop
    bn.rshi w1, w0, w1 >> 4
    bn.lid  x0, 0(x10++)
    bn.rshi w1, w0, w1 >> 12
    bn.rshi w0, w0, w0 >> 8
    loopi 10, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w0, w0 >> 12
    endloop
    bn.and w1, w1, w2
    bn.sid x4, 0(x11++)

    loopi 10, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w0, w0 >> 12
    endloop
    bn.rshi w1, w0, w1 >> 8
    bn.lid  x0, 0(x10++)
    bn.rshi w1, w0, w1 >> 8
    bn.rshi w0, w0, w0 >> 4
    loopi 5, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w0, w0 >> 12
    endloop
    bn.and w1, w1, w2
    bn.sid x4, 0(x11++)

    loopi 16, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w0, w0 >> 12
    endloop
    bn.and w1, w1, w2
    bn.sid x4, 0(x11++)
  endloop
  ret

/*
 * Name:        check_pk
 *
 * Description: FIPS 203 Section 7.2 modulus check. Checks whether every
 *              coefficient of the unpacked public-key polynomial vector is
 *              less than q. The input is a polyvec of K*16 words of sixteen
 *              16-bit lanes each.
 *
 * @param[in]  x12: dmem pointer to the unpacked polyvec pk
 * @param[in]  x14: KYBER_K
 * @param[in]  w31: all-zero
 * @param[out] x10 (a0): HARDENED_BOOL_TRUE if all coefficients are < q,
 *                       HARDENED_BOOL_FALSE otherwise
 *
 * clobbered registers: x5 to x7, x10, x12, x28, w0 to w2, w4
 * clobbered flag groups: FG0
 */
.globl check_pk
.type check_pk, @function
check_pk:
  /* Load q into all 16 lanes. */
  la      x5, modulus_bn
  bn.lid  x0, 0(x5)

  /* Load a vectorized 1 for comparison. */
  bn.addi w4, w31, 1
  bn.or   w4, w4, w4 << 16
  bn.or   w4, w4, w4 << 32
  bn.or   w4, w4, w4 << 64
  bn.or   w4, w4, w4 << 128

  /* Initialize success flag (0 = failure, 8 = success). */
  li      x7, 8

  li      x6, 1
  slli    x5, x14, 4
  loop    x5, 6
    bn.lid      x6, 0(x12++)
    bn.subv.16h w2, w1, w0    /* coeff - q per lane */
    bn.shv.16h  w2, w2 >> 15  /* 1 iff coeff < q */
    bn.cmp      w2, w4        /* set FG0.Z iff every lane < q */
    csrrs       x28, fg0, x0
    and         x7, x7, x28
  endloop

  addi    x10, x0, HARDENED_BOOL_FALSE
  andi    x7, x7, 8
  bne     x7, x0, _check_pk_valid
  ret
_check_pk_valid:
  addi    x10, x0, HARDENED_BOOL_TRUE
  ret
