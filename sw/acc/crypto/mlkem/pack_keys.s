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

/* Register aliases */
.equ x2, sp
.equ x3, fp
.equ x5, t0
.equ x6, t1
.equ x7, t2
.equ x8, s0
.equ x9, s1
.equ x10, a0
.equ x11, a1
.equ x12, a2
.equ x13, a3
.equ x14, a4
.equ x15, a5
.equ x16, a6
.equ x17, a7
.equ x18, s2
.equ x19, s3
.equ x20, s4
.equ x21, s5
.equ x22, s6
.equ x23, s7
.equ x24, s8
.equ x25, s9
.equ x26, s10
.equ x27, s11
.equ x28, t3
.equ x29, t4
.equ x30, t5
.equ x31, t6


/*
 * Name:        poly_tobytes
 *
 * Description: Serialization of a polynomial into KYBER_POLYBYTES = 384 bytes
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: dptr_input, dmem pointer to input polynomial
 * @param[in]  w31: all-zero register
 * @param[out] x11: dptr_output, dmem pointer to output
 *
 * clobbered registers: x4-x9, w0-w5, w31
 */
.globl poly_tobytes
.type poly_tobytes, @function
poly_tobytes:
    addi x4, x0, 1
    loopi 4, 37
        bn.lid       x0, 0(a0++)
        /* Reduce inputs to [0,q) because outputs of NTT without final conditional
         * subtraction in Montgomery multiplication are in [0,2q). */
        bn.addvm.16h w0, w0, w31
        loopi 16, 2
            bn.rshi w1, w0, w1 >> 12
            bn.rshi w0, w31, w0 >> 16
        endloop
        bn.lid       x0, 0(a0++)
        bn.addvm.16h w0, w0, w31
        loopi 5, 2
            bn.rshi w1, w0, w1 >> 12
            bn.rshi w0, w31, w0 >> 16
        endloop
        bn.rshi w1, w0, w1 >> 4
        bn.rshi w0, w31, w0 >> 4
        bn.sid  x4, 0(a1++)

        bn.rshi w1, w0, w1 >> 8
        bn.rshi w0, w31, w0  >> 12
        loopi 10, 2
            bn.rshi w1, w0, w1 >> 12
            bn.rshi w0, w31, w0 >> 16
        endloop
        bn.lid       x0, 0(a0++)
        bn.addvm.16h w0, w0, w31
        loopi 10, 2
            bn.rshi w1, w0, w1 >> 12
            bn.rshi w0, w31, w0 >> 16
        endloop
        bn.rshi w1, w0, w1 >> 8
        bn.rshi w0, w31, w0 >> 8
        bn.sid  x4, 0(a1++)

        bn.rshi w1, w0, w1 >> 4
        bn.rshi w0, w31, w0 >> 8
        loopi 5, 2
            bn.rshi w1, w0, w1 >> 12
            bn.rshi w0, w31, w0 >> 16
        endloop
        bn.lid       x0, 0(a0++)
        bn.addvm.16h w0, w0, w31
        loopi 16, 2
            bn.rshi w1, w0, w1 >> 12
            bn.rshi w0, w31, w0 >> 16
        endloop
        bn.sid x4, 0(a1++)
    endloop
    ret

/*
 * Name:        poly_frombytes
 *
 * Description: De-serialization of a polynomial; inverse of poly_tobytes
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: dptr_input, dmem pointer to input byte array
 * @param[out] x11: dptr_output, dmem pointer to output
 *
 * clobbered registers: x4-x8, w0-w4, w31
 */
.globl poly_frombytes
.type poly_frombytes, @function
poly_frombytes:
  la     t0, const_0x0fff
  addi   x4, x0, 2
  bn.lid x4, 0(t0)
  addi   x4, x0, 1

  loopi 4, 35
    /* Load inputs */
    bn.lid x0, 0(a0++)

    /* First 16 coeffs = 24 bytes */
    loopi 16, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w0, w0 >> 12
    endloop
    bn.and w1, w1, w2
    bn.sid x4, 0(a1++)

    /* Second 16 coeffs = 24 bytes (8 bytes w0 + 16 bytes w1)*/
    loopi 5, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w0, w0 >> 12
    endloop
    bn.rshi w1, w0, w1 >> 4
    bn.lid  x0, 0(a0++)
    bn.rshi w1, w0, w1 >> 12
    bn.rshi w0, w0, w0 >> 8
    loopi 10, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w0, w0 >> 12
    endloop
    bn.and w1, w1, w2
    bn.sid x4, 0(a1++)

    /* Third 16 coeffs = 24 bytes (16 bytes w1 + 8 bytes w2) */
    loopi 10, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w0, w0 >> 12
    endloop
    bn.rshi w1, w0, w1 >> 8
    bn.lid  x0, 0(a0++)
    bn.rshi w1, w0, w1 >> 8
    bn.rshi w0, w0, w0 >> 4
    loopi 5, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w0, w0 >> 12
    endloop
    bn.and w1, w1, w2
    bn.sid x4, 0(a1++)

    /* Fourth 16 coeffs = 24 bytes (24 bytes w2) */
    loopi 16, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w0, w0 >> 12
    endloop
    bn.and w1, w1, w2
    bn.sid x4, 0(a1++)
  endloop
  ret
