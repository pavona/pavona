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
/*
 * Constant-time Kyber basemul
 *
 * Returns: NTT(a)*NTT(b)
 *
 * This implements the basemul for Kyber, where n=256, q=3329.
 *
 * Flags: -
 *
 * @param[in]  x10: dptr_input1, dmem pointer to first word of input polynomial
 * @param[in]  x11: dptr_input2, dmem pointer to second word of input polynomial
 * @param[in]  x12: dptr_tw, dmem pointer to array of twiddles_basemul
 * @param[in]  w16: sw0, where sw0.0 = Q, sw0.2 = Q^-1 mod 2^32
 * @param[out] x13: dmem pointer to result
 *
 * clobbered registers: x4-x30, w0-w23, w30
 */

.globl basemul
basemul:
  /* Set up wide registers for inputs*/
  bn.xor w31, w31, w31

  LOOPI 2, 151
    /* Load input */
    addi   x4, x0, 1
    bn.lid x0, 0(x10)
    bn.lid x4++, 32(x10)
    bn.lid x4++, 64(x10)
    bn.lid x4++, 96(x10)
    bn.lid x4++, 128(x10)
    bn.lid x4++, 160(x10)
    bn.lid x4++, 192(x10)
    bn.lid x4++, 224(x10)

    bn.lid x4++, 0(x11)
    bn.lid x4++, 32(x11)
    bn.lid x4++, 64(x11)
    bn.lid x4++, 96(x11)
    bn.lid x4++, 128(x11)
    bn.lid x4++, 160(x11)
    bn.lid x4++, 192(x11)
    bn.lid x4++, 224(x11)

    /* sw0 = w16: sw0.2 = Q^-1 mod 2^32, sw0.0 = Q */
    bn.mulv.16H.acc.z.lo w26, w0, w8
    bn.mulv.l.16H.lo     w26, w26, sw0.2
    bn.mulv.l.16H.acc.hi w26, w26, sw0.0

    bn.mulv.16H.acc.z.lo w17, w1, w9
    bn.mulv.l.16H.lo     w17, w17, sw0.2
    bn.mulv.l.16H.acc.hi w17, w17, sw0.0

    bn.mulv.16H.acc.z.lo w18, w2, w10
    bn.mulv.l.16H.lo     w18, w18, sw0.2
    bn.mulv.l.16H.acc.hi w18, w18, sw0.0

    bn.mulv.16H.acc.z.lo w19, w3, w11
    bn.mulv.l.16H.lo     w19, w19, sw0.2
    bn.mulv.l.16H.acc.hi w19, w19, sw0.0

    bn.mulv.16H.acc.z.lo w20, w4, w12
    bn.mulv.l.16H.lo     w20, w20, sw0.2
    bn.mulv.l.16H.acc.hi w20, w20, sw0.0

    bn.mulv.16H.acc.z.lo w21, w5, w13
    bn.mulv.l.16H.lo     w21, w21, sw0.2
    bn.mulv.l.16H.acc.hi w21, w21, sw0.0

    bn.mulv.16H.acc.z.lo w22, w6, w14
    bn.mulv.l.16H.lo     w22, w22, sw0.2
    bn.mulv.l.16H.acc.hi w22, w22, sw0.0

    bn.mulv.16H.acc.z.lo w23, w7, w15
    bn.mulv.l.16H.lo     w23, w23, sw0.2
    bn.mulv.l.16H.acc.hi w23, w23, sw0.0

    /* Multiply ai*bi+1, ai+1*bi */
    bn.rshi              w24, w31, w8 >> 16  /*0||b_15||b_14||b_13||...||b3||b2||b1*/
    bn.trn1.16H          w8, w24, w8 /*b14||b15||...||b2||b3||b0||b1*/
    bn.mulv.16H.acc.z.lo w8, w0, w8
    bn.mulv.l.16H.lo     w8, w8, sw0.2
    bn.mulv.l.16H.acc.hi w8, w8, sw0.0

    bn.rshi              w24, w31, w9 >> 16
    bn.trn1.16H          w9, w24, w9
    bn.mulv.16H.acc.z.lo w9, w1, w9
    bn.mulv.l.16H.lo     w9, w9, sw0.2
    bn.mulv.l.16H.acc.hi w9, w9, sw0.0

    bn.rshi              w24, w31, w10 >> 16
    bn.trn1.16H          w10, w24, w10
    bn.mulv.16H.acc.z.lo w10, w2, w10
    bn.mulv.l.16H.lo     w10, w10, sw0.2
    bn.mulv.l.16H.acc.hi w10, w10, sw0.0

    bn.rshi              w24, w31, w11 >> 16
    bn.trn1.16H          w11, w24, w11
    bn.mulv.16H.acc.z.lo w11, w3, w11
    bn.mulv.l.16H.lo     w11, w11, sw0.2
    bn.mulv.l.16H.acc.hi w11, w11, sw0.0

    bn.rshi              w24, w31, w12 >> 16
    bn.trn1.16H          w12, w24, w12
    bn.mulv.16H.acc.z.lo w12, w4, w12
    bn.mulv.l.16H.lo     w12, w12, sw0.2
    bn.mulv.l.16H.acc.hi w12, w12, sw0.0

    bn.rshi              w24, w31, w13 >> 16
    bn.trn1.16H          w13, w24, w13
    bn.mulv.16H.acc.z.lo w13, w5, w13
    bn.mulv.l.16H.lo     w13, w13, sw0.2
    bn.mulv.l.16H.acc.hi w13, w13, sw0.0

    bn.rshi              w24, w31, w14 >> 16
    bn.trn1.16H          w14, w24, w14
    bn.mulv.16H.acc.z.lo w14, w6, w14
    bn.mulv.l.16H.lo     w14, w14, sw0.2
    bn.mulv.l.16H.acc.hi w14, w14, sw0.0

    bn.rshi              w24, w31, w15 >> 16
    bn.trn1.16H          w15, w24, w15
    bn.mulv.16H.acc.z.lo w15, w7, w15
    bn.mulv.l.16H.lo     w15, w15, sw0.2
    bn.mulv.l.16H.acc.hi w15, w15, sw0.0

    /* Load twiddle factors */
    addi   x4, x0, 1
    bn.lid x0, 0(x12)
    bn.lid x4++, 32(x12)
    bn.lid x4++, 64(x12)
    bn.lid x4++, 96(x12)

    /* Multiply ai*bi*zeta */
    bn.trn2.16H          w24, w26, w17
    bn.mulv.16H.acc.z.lo w24, w24, w0
    bn.mulv.l.16H.lo     w24, w24, sw0.2
    bn.mulv.l.16H.acc.hi w24, w24, sw0.0
    bn.trn1.16H          w26, w26, w24
    bn.rshi              w24, w31, w24 >> 16
    bn.trn1.16H          w17, w17, w24

    bn.trn2.16H          w24, w18, w19
    bn.mulv.16H.acc.z.lo w24, w24, w1
    bn.mulv.l.16H.lo     w24, w24, sw0.2
    bn.mulv.l.16H.acc.hi w24, w24, sw0.0
    bn.trn1.16H          w18, w18, w24
    bn.rshi              w24, w31, w24 >> 16
    bn.trn1.16H          w19, w19, w24

    bn.trn2.16H          w24, w20, w21
    bn.mulv.16H.acc.z.lo w24, w24, w2
    bn.mulv.l.16H.lo     w24, w24, sw0.2
    bn.mulv.l.16H.acc.hi w24, w24, sw0.0
    bn.trn1.16H          w20, w20, w24
    bn.rshi              w24, w31, w24 >> 16
    bn.trn1.16H          w21, w21, w24

    bn.trn2.16H          w24, w22, w23
    bn.mulv.16H.acc.z.lo w24, w24, w3
    bn.mulv.l.16H.lo     w24, w24, sw0.2
    bn.mulv.l.16H.acc.hi w24, w24, sw0.0
    bn.trn1.16H          w22, w22, w24
    bn.rshi              w24, w31, w24 >> 16
    bn.trn1.16H          w23, w23, w24

    /* Add ai*bi + ai+1*bi */
    /* w0--w7: ai*bi*zeta */
    /* w8--w15: ai+1*bi */
    /* w26--w31: free */
    bn.trn1.16H  w0, w26, w8
    bn.trn2.16H  w8, w26, w8
    bn.trn1.16H  w1, w17, w9
    bn.trn2.16H  w9, w17, w9
    bn.trn1.16H  w2, w18, w10
    bn.trn2.16H  w10, w18, w10
    bn.trn1.16H  w3, w19, w11
    bn.trn2.16H  w11, w19, w11
    bn.trn1.16H  w4, w20, w12
    bn.trn2.16H  w12, w20, w12
    bn.trn1.16H  w5, w21, w13
    bn.trn2.16H  w13, w21, w13
    bn.trn1.16H  w6, w22, w14
    bn.trn2.16H  w14, w22, w14
    bn.trn1.16H  w7, w23, w15
    bn.trn2.16H  w15, w23, w15

    /* Return result */
    bn.addvm.16H w0, w0, w8
    bn.addvm.16H w1, w1, w9
    bn.addvm.16H w2, w2, w10
    bn.addvm.16H w3, w3, w11
    bn.addvm.16H w4, w4, w12
    bn.addvm.16H w5, w5, w13
    bn.addvm.16H w6, w6, w14
    bn.addvm.16H w7, w7, w15

    /* Store output */
    addi   x4, x0, 1
    bn.sid x0, 0(x13)
    bn.sid x4++, 32(x13)
    bn.sid x4++, 64(x13)
    bn.sid x4++, 96(x13)
    bn.sid x4++, 128(x13)
    bn.sid x4++, 160(x13)
    bn.sid x4++, 192(x13)
    bn.sid x4++, 224(x13)

    /* Adjust input and output pointers. */
    addi x10, x10, 256
    addi x11, x11, 256
    addi x13, x13, 256
    addi x12, x12, 128

  /* Reset twiddle pointer. */
  addi x12, x12, -256
  ret


/*
 * basemull_acc_kyber
 *
 * Returns: NTT(a)*NTT(b)
 *
 * This implements the accumulating basemul for Kyber, where n=256, q=3329.
 *
 * Flags: -
 *
 * @param[in]  x10: dptr_input1, dmem pointer to first word of input polynomial
 * @param[in]  x11: dptr_input2, dmem pointer to second word of input polynomial
 * @param[in]  x12: dptr_tw, dmem pointer to array of twiddles_basemul
 * @param[out] x13: dmem pointer to result
 *
 * clobbered registers: x4-x30, w0-w23, w30
 */

.globl basemul_acc
basemul_acc:
  /* Set up wide registers for inputs*/
  bn.xor w31, w31, w31

  LOOPI 2, 168
    /* Load input */
    addi   x4, x0, 1
    bn.lid x0, 0(x10)
    bn.lid x4++, 32(x10)
    bn.lid x4++, 64(x10)
    bn.lid x4++, 96(x10)
    bn.lid x4++, 128(x10)
    bn.lid x4++, 160(x10)
    bn.lid x4++, 192(x10)
    bn.lid x4++, 224(x10)

    bn.lid x4++, 0(x11)
    bn.lid x4++, 32(x11)
    bn.lid x4++, 64(x11)
    bn.lid x4++, 96(x11)
    bn.lid x4++, 128(x11)
    bn.lid x4++, 160(x11)
    bn.lid x4++, 192(x11)
    bn.lid x4++, 224(x11)

    /* Multiply ai*bi */
    bn.mulv.16H.acc.z.lo w26, w0, w8
    bn.mulv.l.16H.lo     w26, w26, sw0.2
    bn.mulv.l.16H.acc.hi w26, w26, sw0.0

    bn.mulv.16H.acc.z.lo w17, w1, w9
    bn.mulv.l.16H.lo     w17, w17, sw0.2
    bn.mulv.l.16H.acc.hi w17, w17, sw0.0

    bn.mulv.16H.acc.z.lo w18, w2, w10
    bn.mulv.l.16H.lo     w18, w18, sw0.2
    bn.mulv.l.16H.acc.hi w18, w18, sw0.0

    bn.mulv.16H.acc.z.lo w19, w3, w11
    bn.mulv.l.16H.lo     w19, w19, sw0.2
    bn.mulv.l.16H.acc.hi w19, w19, sw0.0

    bn.mulv.16H.acc.z.lo w20, w4, w12
    bn.mulv.l.16H.lo     w20, w20, sw0.2
    bn.mulv.l.16H.acc.hi w20, w20, sw0.0

    bn.mulv.16H.acc.z.lo w21, w5, w13
    bn.mulv.l.16H.lo     w21, w21, sw0.2
    bn.mulv.l.16H.acc.hi w21, w21, sw0.0

    bn.mulv.16H.acc.z.lo w22, w6, w14
    bn.mulv.l.16H.lo     w22, w22, sw0.2
    bn.mulv.l.16H.acc.hi w22, w22, sw0.0

    bn.mulv.16H.acc.z.lo w23, w7, w15
    bn.mulv.l.16H.lo     w23, w23, sw0.2
    bn.mulv.l.16H.acc.hi w23, w23, sw0.0

    /* Multiply ai*bi+1, ai+1*bi */
    bn.rshi              w24, w31, w8 >> 16  /*0||b_15||b_14||b_13||...||b3||b2||b1*/
    bn.trn1.16H          w8, w24, w8 /*b14||b15||...||b2||b3||b0||b1*/
    bn.mulv.16H.acc.z.lo w8, w0, w8
    bn.mulv.l.16H.lo     w8, w8, sw0.2
    bn.mulv.l.16H.acc.hi w8, w8, sw0.0

    bn.rshi              w24, w31, w9 >> 16
    bn.trn1.16H          w9, w24, w9
    bn.mulv.16H.acc.z.lo w9, w1, w9
    bn.mulv.l.16H.lo     w9, w9, sw0.2
    bn.mulv.l.16H.acc.hi w9, w9, sw0.0

    bn.rshi              w24, w31, w10 >> 16
    bn.trn1.16H          w10, w24, w10
    bn.mulv.16H.acc.z.lo w10, w2, w10
    bn.mulv.l.16H.lo     w10, w10, sw0.2
    bn.mulv.l.16H.acc.hi w10, w10, sw0.0

    bn.rshi              w24, w31, w11 >> 16
    bn.trn1.16H          w11, w24, w11
    bn.mulv.16H.acc.z.lo w11, w3, w11
    bn.mulv.l.16H.lo     w11, w11, sw0.2
    bn.mulv.l.16H.acc.hi w11, w11, sw0.0

    bn.rshi              w24, w31, w12 >> 16
    bn.trn1.16H          w12, w24, w12
    bn.mulv.16H.acc.z.lo w12, w4, w12
    bn.mulv.l.16H.lo     w12, w12, sw0.2
    bn.mulv.l.16H.acc.hi w12, w12, sw0.0

    bn.rshi              w24, w31, w13 >> 16
    bn.trn1.16H          w13, w24, w13
    bn.mulv.16H.acc.z.lo w13, w5, w13
    bn.mulv.l.16H.lo     w13, w13, sw0.2
    bn.mulv.l.16H.acc.hi w13, w13, sw0.0

    bn.rshi              w24, w31, w14 >> 16
    bn.trn1.16H          w14, w24, w14
    bn.mulv.16H.acc.z.lo w14, w6, w14
    bn.mulv.l.16H.lo     w14, w14, sw0.2
    bn.mulv.l.16H.acc.hi w14, w14, sw0.0

    bn.rshi              w24, w31, w15 >> 16
    bn.trn1.16H          w15, w24, w15
    bn.mulv.16H.acc.z.lo w15, w7, w15
    bn.mulv.l.16H.lo     w15, w15, sw0.2
    bn.mulv.l.16H.acc.hi w15, w15, sw0.0

    /* Load twiddle factors */
    addi   x4, x0, 1
    bn.lid x0, 0(x12)
    bn.lid x4++, 32(x12)
    bn.lid x4++, 64(x12)
    bn.lid x4++, 96(x12)

    /* Multiply ai*bi*zeta */
    bn.trn2.16H          w24, w26, w17
    bn.mulv.16H.acc.z.lo w24, w24, w0
    bn.mulv.l.16H.lo     w24, w24, sw0.2
    bn.mulv.l.16H.acc.hi w24, w24, sw0.0
    bn.trn1.16H          w26, w26, w24
    bn.rshi              w24, w31, w24 >> 16
    bn.trn1.16H          w17, w17, w24

    bn.trn2.16H          w24, w18, w19
    bn.mulv.16H.acc.z.lo w24, w24, w1
    bn.mulv.l.16H.lo     w24, w24, sw0.2
    bn.mulv.l.16H.acc.hi w24, w24, sw0.0
    bn.trn1.16H          w18, w18, w24
    bn.rshi              w24, w31, w24 >> 16
    bn.trn1.16H          w19, w19, w24

    bn.trn2.16H          w24, w20, w21
    bn.mulv.16H.acc.z.lo w24, w24, w2
    bn.mulv.l.16H.lo     w24, w24, sw0.2
    bn.mulv.l.16H.acc.hi w24, w24, sw0.0
    bn.trn1.16H          w20, w20, w24
    bn.rshi              w24, w31, w24 >> 16
    bn.trn1.16H          w21, w21, w24

    bn.trn2.16H          w24, w22, w23
    bn.mulv.16H.acc.z.lo w24, w24, w3
    bn.mulv.l.16H.lo     w24, w24, sw0.2
    bn.mulv.l.16H.acc.hi w24, w24, sw0.0
    bn.trn1.16H          w22, w22, w24
    bn.rshi              w24, w31, w24 >> 16
    bn.trn1.16H          w23, w23, w24

    /* Add ai*bi + ai+1*bi */
    /* w0--w7: ai*bi*zeta */
    /* w8--w15: ai+1*bi */
    /* w26--w31: free */
    bn.trn1.16H  w0, w26, w8
    bn.trn2.16H  w8, w26, w8
    bn.trn1.16H  w1, w17, w9
    bn.trn2.16H  w9, w17, w9
    bn.trn1.16H  w2, w18, w10
    bn.trn2.16H  w10, w18, w10
    bn.trn1.16H  w3, w19, w11
    bn.trn2.16H  w11, w19, w11
    bn.trn1.16H  w4, w20, w12
    bn.trn2.16H  w12, w20, w12
    bn.trn1.16H  w5, w21, w13
    bn.trn2.16H  w13, w21, w13
    bn.trn1.16H  w6, w22, w14
    bn.trn2.16H  w14, w22, w14
    bn.trn1.16H  w7, w23, w15
    bn.trn2.16H  w15, w23, w15

    /* Return result */
    bn.addvm.16H w0, w0, w8
    bn.addvm.16H w1, w1, w9
    bn.addvm.16H w2, w2, w10
    bn.addvm.16H w3, w3, w11
    bn.addvm.16H w4, w4, w12
    bn.addvm.16H w5, w5, w13
    bn.addvm.16H w6, w6, w14
    bn.addvm.16H w7, w7, w15

    /* Load inputs at dmem_result */
    addi   x4, x0, 8
    bn.lid x4++, 0(x13)
    bn.lid x4++, 32(x13)
    bn.lid x4++, 64(x13)
    bn.lid x4++, 96(x13)
    bn.lid x4++, 128(x13)
    bn.lid x4++, 160(x13)
    bn.lid x4++, 192(x13)
    bn.lid x4++, 224(x13)

    /* Accumulate */
    bn.addvm.16H w0, w0, w8
    bn.addvm.16H w1, w1, w9
    bn.addvm.16H w2, w2, w10
    bn.addvm.16H w3, w3, w11
    bn.addvm.16H w4, w4, w12
    bn.addvm.16H w5, w5, w13
    bn.addvm.16H w6, w6, w14
    bn.addvm.16H w7, w7, w15

    /* Store output */
    addi   x4, x0, 1
    bn.sid x0, 0(x13)
    bn.sid x4++, 32(x13)
    bn.sid x4++, 64(x13)
    bn.sid x4++, 96(x13)
    bn.sid x4++, 128(x13)
    bn.sid x4++, 160(x13)
    bn.sid x4++, 192(x13)
    bn.sid x4++, 224(x13)

    /* Adjust input and output pointers. */
    addi x10, x10, 256
    addi x11, x11, 256
    addi x13, x13, 256
    addi x12, x12, 128

  /* Reset twiddle pointer. */
  addi x12, x12, -256
  ret
