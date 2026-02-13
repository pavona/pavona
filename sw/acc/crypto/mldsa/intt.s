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
/* Macros */
.macro push reg
    addi sp, sp, -4     /* Decrement stack pointer by 4 bytes */
    sw \reg, 0(sp)      /* Store register value at the top of the stack */
.endm

.macro pop reg
    lw \reg, 0(sp)     /* Load value from the top of the stack into register */
    addi sp, sp, 4     /* Increment stack pointer by 4 bytes */
.endm

/**
 * Constant Time Dilithium inverse NTT
 *
 * Returns: INTT(input)
 *
 * This implements the in-place INTT for Dilithium, where n=256, q=8380417.
 *
 * Flags: -
 *
 * @param[in]  x10: dptr_input, dmem pointer to first word of input polynomial
 * @param[in]  x11: dptr_tw, dmem pointer to array of twiddle factors,
                    last element is n^{-1} mod q
 * @param[in]  w31: all-zero
 * @param[out] x10: dmem pointer to result
 *
 * clobbered registers: x4-x27, w0-w15, w17-w21, w24-w30
 */
.global intt
intt:

    /* Save callee-saved registers */
    .irp reg,s0,s1,s2,s3,s4,s5,s6,s7,s8,s9,s10,s11
        push \reg
    .endr

    /* Empty w20 */
    bn.xor w20, w20, w20

    /* Set up constants for input/state */
    li x4, 0
    li x5, 1
    li x6, 2
    li x7, 3
    li x8, 4
    li x9, 5
    li x13, 6
    li x14, 7
    li x15, 8
    li x16, 9
    li x17, 10
    li x18, 11
    li x19, 12
    li x20, 13
    li x21, 14
    li x22, 15

    /* Set up constants for input/twiddle factors */
    li x23, 17
    li x24, 18

    LOOPI 2, 399
        /* Load input data */
        bn.lid x4, 0(x10)
        bn.lid x5, 32(x10)
        bn.lid x6, 64(x10)
        bn.lid x7, 96(x10)
        bn.lid x8, 128(x10)
        bn.lid x9, 160(x10)
        bn.lid x13, 192(x10)
        bn.lid x14, 224(x10)
        bn.lid x15, 256(x10)
        bn.lid x16, 288(x10)
        bn.lid x17, 320(x10)
        bn.lid x18, 352(x10)
        bn.lid x19, 384(x10)
        bn.lid x20, 416(x10)
        bn.lid x21, 448(x10)
        bn.lid x22, 480(x10)

        /* Transpose */
        /* First trans w24-w31 */
        bn.trn1.8S w24, w0, w1
        bn.trn2.8S w25, w0, w1
        bn.trn1.8S w26, w2, w3
        bn.trn2.8S w27, w2, w3
        bn.trn1.8S w28, w4, w5
        bn.trn2.8S w29, w4, w5
        bn.trn1.8S w30, w6, w7
        bn.trn2.8S w31, w6, w7

        bn.trn1.4D w0, w24, w26
        bn.trn2.4D w2, w24, w26
        bn.trn1.4D w1, w25, w27
        bn.trn2.4D w3, w25, w27
        bn.trn1.4D w4, w28, w30
        bn.trn2.4D w6, w28, w30
        bn.trn1.4D w5, w29, w31
        bn.trn2.4D w7, w29, w31

        bn.trn1.2Q w24, w0, w4
        bn.trn2.2Q w28, w0, w4
        bn.trn1.2Q w25, w1, w5
        bn.trn2.2Q w29, w1, w5
        bn.trn1.2Q w26, w2, w6
        bn.trn2.2Q w30, w2, w6
        bn.trn1.2Q w27, w3, w7
        bn.trn2.2Q w31, w3, w7

        /* Second trans w0-w7 */
        bn.trn1.8S w0, w8, w9
        bn.trn2.8S w1, w8, w9
        bn.trn1.8S w2, w10, w11
        bn.trn2.8S w3, w10, w11
        bn.trn1.8S w4, w12, w13
        bn.trn2.8S w5, w12, w13
        bn.trn1.8S w6, w14, w15
        bn.trn2.8S w7, w14, w15

        bn.trn1.4D w8, w0, w2
        bn.trn2.4D w10, w0, w2
        bn.trn1.4D w9, w1, w3
        bn.trn2.4D w11, w1, w3
        bn.trn1.4D w12, w4, w6
        bn.trn2.4D w14, w4, w6
        bn.trn1.4D w13, w5, w7
        bn.trn2.4D w15, w5, w7

        bn.trn1.2Q w0, w8, w12
        bn.trn2.2Q w4, w8, w12
        bn.trn1.2Q w1, w9, w13
        bn.trn2.2Q w5, w9, w13
        bn.trn1.2Q w2, w10, w14
        bn.trn2.2Q w6, w10, w14
        bn.trn1.2Q w3, w11, w15
        bn.trn2.2Q w7, w11, w15

        /* Reverse Layer 8, stride 1 */
        #define wtmp w8

        bn.lid x23, 0(x11++) /* Load twiddle factors */

        bn.subvm.8S                wtmp, w24, w25
        bn.addvm.8S                w24, w24, w25
        bn.mulv.8S.even.acc.z.lo   w25, wtmp, w17
        bn.mulv.l.8S.even.lo       w25, w25, sw0.1
        bn.mulv.l.8S.even.acc.hi   w25, w25, sw0.0
        bn.mulv.8S.odd.acc.z.lo    w25, w25, w17
        bn.mulv.l.8S.odd.lo        w25, w25, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w25, w25, sw0.0

        bn.lid x23, 0(x11++) /* Load twiddle factors */

        bn.subvm.8S                wtmp, w26, w27
        bn.addvm.8S                w26, w26, w27
        bn.mulv.8S.even.acc.z.lo   w27, wtmp, w17
        bn.mulv.l.8S.even.lo       w27, w27, sw0.1
        bn.mulv.l.8S.even.acc.hi   w27, w27, sw0.0
        bn.mulv.8S.odd.acc.z.lo    w27, w27, w17
        bn.mulv.l.8S.odd.lo        w27, w27, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w27, w27, sw0.0

        bn.lid x23, 0(x11++) /* Load twiddle factors */

        bn.subvm.8S                wtmp, w28, w29
        bn.addvm.8S                w28, w28, w29
        bn.mulv.8S.even.acc.z.lo   w29, wtmp, w17
        bn.mulv.l.8S.even.lo       w29, w29, sw0.1
        bn.mulv.l.8S.even.acc.hi   w29, w29, sw0.0
        bn.mulv.8S.odd.acc.z.lo    w29, w29, w17
        bn.mulv.l.8S.odd.lo        w29, w29, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w29, w29, sw0.0

        bn.lid x23, 0(x11++) /* Load twiddle factors */

        bn.subvm.8S                wtmp, w30, w31
        bn.addvm.8S                w30, w30, w31
        bn.mulv.8S.even.acc.z.lo   w31, wtmp, w17
        bn.mulv.l.8S.even.lo       w31, w31, sw0.1
        bn.mulv.l.8S.even.acc.hi   w31, w31, sw0.0
        bn.mulv.8S.odd.acc.z.lo    w31, w31, w17
        bn.mulv.l.8S.odd.lo        w31, w31, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w31, w31, sw0.0

        bn.lid x23, 0(x11++) /* Load twiddle factors */

        bn.subvm.8S                wtmp, w0, w1
        bn.addvm.8S                w0, w0, w1
        bn.mulv.8S.even.acc.z.lo   w1, wtmp, w17
        bn.mulv.l.8S.even.lo       w1, w1, sw0.1
        bn.mulv.l.8S.even.acc.hi   w1, w1, sw0.0
        bn.mulv.8S.odd.acc.z.lo    w1, w1, w17
        bn.mulv.l.8S.odd.lo        w1, w1, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w1, w1, sw0.0

        bn.lid x23, 0(x11++) /* Load twiddle factors */

        bn.subvm.8S                wtmp, w2, w3
        bn.addvm.8S                w2, w2, w3
        bn.mulv.8S.even.acc.z.lo   w3, wtmp, w17
        bn.mulv.l.8S.even.lo       w3, w3, sw0.1
        bn.mulv.l.8S.even.acc.hi   w3, w3, sw0.0
        bn.mulv.8S.odd.acc.z.lo    w3, w3, w17
        bn.mulv.l.8S.odd.lo        w3, w3, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w3, w3, sw0.0

        bn.lid x23, 0(x11++) /* Load twiddle factors */

        bn.subvm.8S                wtmp, w4, w5
        bn.addvm.8S                w4, w4, w5
        bn.mulv.8S.even.acc.z.lo   w5, wtmp, w17
        bn.mulv.l.8S.even.lo       w5, w5, sw0.1
        bn.mulv.l.8S.even.acc.hi   w5, w5, sw0.0
        bn.mulv.8S.odd.acc.z.lo    w5, w5, w17
        bn.mulv.l.8S.odd.lo        w5, w5, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w5, w5, sw0.0

        bn.lid x23, 0(x11++) /* Load twiddle factors */

        bn.subvm.8S                wtmp, w6, w7
        bn.addvm.8S                w6, w6, w7
        bn.mulv.8S.even.acc.z.lo   w7, wtmp, w17
        bn.mulv.l.8S.even.lo       w7, w7, sw0.1
        bn.mulv.l.8S.even.acc.hi   w7, w7, sw0.0
        bn.mulv.8S.odd.acc.z.lo    w7, w7, w17
        bn.mulv.l.8S.odd.lo        w7, w7, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w7, w7, sw0.0


        /* Reverse Layer 7, stride 2 */


        bn.lid x23, 0(x11++) /* Load twiddle factors */

        bn.subvm.8S                wtmp, w24, w26
        bn.addvm.8S                w24, w24, w26
        bn.mulv.8S.even.acc.z.lo   w26, wtmp, w17
        bn.mulv.l.8S.even.lo       w26, w26, sw0.1
        bn.mulv.l.8S.even.acc.hi   w26, w26, sw0.0
        bn.mulv.8S.odd.acc.z.lo    w26, w26, w17
        bn.mulv.l.8S.odd.lo        w26, w26, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w26, w26, sw0.0

        bn.subvm.8S                wtmp, w25, w27
        bn.addvm.8S                w25, w25, w27
        bn.mulv.8S.even.acc.z.lo   w27, wtmp, w17
        bn.mulv.l.8S.even.lo       w27, w27, sw0.1
        bn.mulv.l.8S.even.acc.hi   w27, w27, sw0.0
        bn.mulv.8S.odd.acc.z.lo    w27, w27, w17
        bn.mulv.l.8S.odd.lo        w27, w27, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w27, w27, sw0.0


        bn.lid x23, 0(x11++) /* Load twiddle factors */

        bn.subvm.8S                wtmp, w28, w30
        bn.addvm.8S                w28, w28, w30
        bn.mulv.8S.even.acc.z.lo   w30, wtmp, w17
        bn.mulv.l.8S.even.lo       w30, w30, sw0.1
        bn.mulv.l.8S.even.acc.hi   w30, w30, sw0.0
        bn.mulv.8S.odd.acc.z.lo    w30, w30, w17
        bn.mulv.l.8S.odd.lo        w30, w30, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w30, w30, sw0.0

        bn.subvm.8S                wtmp, w29, w31
        bn.addvm.8S                w29, w29, w31
        bn.mulv.8S.even.acc.z.lo   w31, wtmp, w17
        bn.mulv.l.8S.even.lo       w31, w31, sw0.1
        bn.mulv.l.8S.even.acc.hi   w31, w31, sw0.0
        bn.mulv.8S.odd.acc.z.lo    w31, w31, w17
        bn.mulv.l.8S.odd.lo        w31, w31, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w31, w31, sw0.0


        bn.lid x23, 0(x11++) /* Load twiddle factors */

        bn.subvm.8S                wtmp, w0, w2
        bn.addvm.8S                w0, w0, w2
        bn.mulv.8S.even.acc.z.lo   w2, wtmp, w17
        bn.mulv.l.8S.even.lo       w2, w2, sw0.1
        bn.mulv.l.8S.even.acc.hi   w2, w2, sw0.0
        bn.mulv.8S.odd.acc.z.lo    w2, w2, w17
        bn.mulv.l.8S.odd.lo        w2, w2, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w2, w2, sw0.0

        bn.subvm.8S                wtmp, w1, w3
        bn.addvm.8S                w1, w1, w3
        bn.mulv.8S.even.acc.z.lo   w3, wtmp, w17
        bn.mulv.l.8S.even.lo       w3, w3, sw0.1
        bn.mulv.l.8S.even.acc.hi   w3, w3, sw0.0
        bn.mulv.8S.odd.acc.z.lo    w3, w3, w17
        bn.mulv.l.8S.odd.lo        w3, w3, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w3, w3, sw0.0


        bn.lid x23, 0(x11++) /* Load twiddle factors */

        bn.subvm.8S                wtmp, w4, w6
        bn.addvm.8S                w4, w4, w6
        bn.mulv.8S.even.acc.z.lo   w6, wtmp, w17
        bn.mulv.l.8S.even.lo       w6, w6, sw0.1
        bn.mulv.l.8S.even.acc.hi   w6, w6, sw0.0
        bn.mulv.8S.odd.acc.z.lo    w6, w6, w17
        bn.mulv.l.8S.odd.lo        w6, w6, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w6, w6, sw0.0

        bn.subvm.8S                wtmp, w5, w7
        bn.addvm.8S                w5, w5, w7
        bn.mulv.8S.even.acc.z.lo   w7, wtmp, w17
        bn.mulv.l.8S.even.lo       w7, w7, sw0.1
        bn.mulv.l.8S.even.acc.hi   w7, w7, sw0.0
        bn.mulv.8S.odd.acc.z.lo    w7, w7, w17
        bn.mulv.l.8S.odd.lo        w7, w7, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w7, w7, sw0.0

        /* Reverse Layer 6, stride 4 */

        bn.lid x23, 0(x11++) /* Load twiddle factors */

        bn.subvm.8S                wtmp, w24, w28
        bn.addvm.8S                w24, w24, w28
        bn.mulv.8S.even.acc.z.lo   w28, wtmp, w17
        bn.mulv.l.8S.even.lo       w28, w28, sw0.1
        bn.mulv.l.8S.even.acc.hi   w28, w28, sw0.0
        bn.mulv.8S.odd.acc.z.lo    w28, w28, w17
        bn.mulv.l.8S.odd.lo        w28, w28, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w28, w28, sw0.0

        bn.subvm.8S                wtmp, w25, w29
        bn.addvm.8S                w25, w25, w29
        bn.mulv.8S.even.acc.z.lo   w29, wtmp, w17
        bn.mulv.l.8S.even.lo       w29, w29, sw0.1
        bn.mulv.l.8S.even.acc.hi   w29, w29, sw0.0
        bn.mulv.8S.odd.acc.z.lo    w29, w29, w17
        bn.mulv.l.8S.odd.lo        w29, w29, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w29, w29, sw0.0

        bn.subvm.8S                wtmp, w26, w30
        bn.addvm.8S                w26, w26, w30
        bn.mulv.8S.even.acc.z.lo   w30, wtmp, w17
        bn.mulv.l.8S.even.lo       w30, w30, sw0.1
        bn.mulv.l.8S.even.acc.hi   w30, w30, sw0.0
        bn.mulv.8S.odd.acc.z.lo    w30, w30, w17
        bn.mulv.l.8S.odd.lo        w30, w30, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w30, w30, sw0.0

        bn.subvm.8S                wtmp, w27, w31
        bn.addvm.8S                w27, w27, w31
        bn.mulv.8S.even.acc.z.lo   w31, wtmp, w17
        bn.mulv.l.8S.even.lo       w31, w31, sw0.1
        bn.mulv.l.8S.even.acc.hi   w31, w31, sw0.0
        bn.mulv.8S.odd.acc.z.lo    w31, w31, w17
        bn.mulv.l.8S.odd.lo        w31, w31, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w31, w31, sw0.0


        bn.lid x23, 0(x11++) /* Load twiddle factors */

        bn.subvm.8S                wtmp, w0, w4
        bn.addvm.8S                w0, w0, w4
        bn.mulv.8S.even.acc.z.lo   w4, wtmp, w17
        bn.mulv.l.8S.even.lo       w4, w4, sw0.1
        bn.mulv.l.8S.even.acc.hi   w4, w4, sw0.0
        bn.mulv.8S.odd.acc.z.lo    w4, w4, w17
        bn.mulv.l.8S.odd.lo        w4, w4, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w4, w4, sw0.0

        bn.subvm.8S                wtmp, w1, w5
        bn.addvm.8S                w1, w1, w5
        bn.mulv.8S.even.acc.z.lo   w5, wtmp, w17
        bn.mulv.l.8S.even.lo       w5, w5, sw0.1
        bn.mulv.l.8S.even.acc.hi   w5, w5, sw0.0
        bn.mulv.8S.odd.acc.z.lo    w5, w5, w17
        bn.mulv.l.8S.odd.lo        w5, w5, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w5, w5, sw0.0

        bn.subvm.8S                wtmp, w2, w6
        bn.addvm.8S                w2, w2, w6
        bn.mulv.8S.even.acc.z.lo   w6, wtmp, w17
        bn.mulv.l.8S.even.lo       w6, w6, sw0.1
        bn.mulv.l.8S.even.acc.hi   w6, w6, sw0.0
        bn.mulv.8S.odd.acc.z.lo    w6, w6, w17
        bn.mulv.l.8S.odd.lo        w6, w6, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w6, w6, sw0.0

        bn.subvm.8S                wtmp, w3, w7
        bn.addvm.8S                w3, w3, w7
        bn.mulv.8S.even.acc.z.lo   w7, wtmp, w17
        bn.mulv.l.8S.even.lo       w7, w7, sw0.1
        bn.mulv.l.8S.even.acc.hi   w7, w7, sw0.0
        bn.mulv.8S.odd.acc.z.lo    w7, w7, w17
        bn.mulv.l.8S.odd.lo        w7, w7, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w7, w7, sw0.0

        /* Transpose back */
        /* First trans w8-w15 */
        bn.trn1.8S w8, w0, w1
        bn.trn2.8S w9, w0, w1
        bn.trn1.8S w10, w2, w3
        bn.trn2.8S w11, w2, w3
        bn.trn1.8S w12, w4, w5
        bn.trn2.8S w13, w4, w5
        bn.trn1.8S w14, w6, w7
        bn.trn2.8S w15, w6, w7

        bn.trn1.4D w0, w8, w10
        bn.trn2.4D w2, w8, w10
        bn.trn1.4D w1, w9, w11
        bn.trn2.4D w3, w9, w11
        bn.trn1.4D w4, w12, w14
        bn.trn2.4D w6, w12, w14
        bn.trn1.4D w5, w13, w15
        bn.trn2.4D w7, w13, w15

        bn.trn1.2Q w8, w0, w4
        bn.trn2.2Q w12, w0, w4
        bn.trn1.2Q w9, w1, w5
        bn.trn2.2Q w13, w1, w5
        bn.trn1.2Q w10, w2, w6
        bn.trn2.2Q w14, w2, w6
        bn.trn1.2Q w11, w3, w7
        bn.trn2.2Q w15, w3, w7

        /* Second trans w0-w7 */
        bn.trn1.8S w0, w24, w25
        bn.trn2.8S w1, w24, w25
        bn.trn1.8S w2, w26, w27
        bn.trn2.8S w3, w26, w27
        bn.trn1.8S w4, w28, w29
        bn.trn2.8S w5, w28, w29
        bn.trn1.8S w6, w30, w31
        bn.trn2.8S w7, w30, w31

        bn.trn1.4D w24, w0, w2
        bn.trn2.4D w26, w0, w2
        bn.trn1.4D w25, w1, w3
        bn.trn2.4D w27, w1, w3
        bn.trn1.4D w28, w4, w6
        bn.trn2.4D w30, w4, w6
        bn.trn1.4D w29, w5, w7
        bn.trn2.4D w31, w5, w7

        bn.trn1.2Q w0, w24, w28
        bn.trn2.2Q w4, w24, w28
        bn.trn1.2Q w1, w25, w29
        bn.trn2.2Q w5, w25, w29
        bn.trn1.2Q w2, w26, w30
        bn.trn2.2Q w6, w26, w30
        bn.trn1.2Q w3, w27, w31
        bn.trn2.2Q w7, w27, w31

        /* Reverse Layer 5, stride 8 */

        /* Load twiddle factors */
        bn.lid x23, 0(x11++)

        /* Butterflies */
        bn.subvm.8S                w30, w0, w1
        bn.addvm.8S                w0, w0, w1
        bn.mulv.l.8S.even.acc.z.lo w1, w30, sw1.0
        bn.mulv.l.8S.even.lo       w1, w1, sw0.1
        bn.mulv.l.8S.even.acc.hi   w1, w1, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w1, w1, sw1.0
        bn.mulv.l.8S.odd.lo        w1, w1, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w1, w1, sw0.0

        bn.subvm.8S                w30, w2, w3
        bn.addvm.8S                w2, w2, w3
        bn.mulv.l.8S.even.acc.z.lo w3, w30, sw1.1
        bn.mulv.l.8S.even.lo       w3, w3, sw0.1
        bn.mulv.l.8S.even.acc.hi   w3, w3, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w3, w3, sw1.1
        bn.mulv.l.8S.odd.lo        w3, w3, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w3, w3, sw0.0

        bn.subvm.8S                w30, w4, w5
        bn.addvm.8S                w4, w4, w5
        bn.mulv.l.8S.even.acc.z.lo w5, w30, sw1.2
        bn.mulv.l.8S.even.lo       w5, w5, sw0.1
        bn.mulv.l.8S.even.acc.hi   w5, w5, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w5, w5, sw1.2
        bn.mulv.l.8S.odd.lo        w5, w5, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w5, w5, sw0.0

        bn.subvm.8S                w30, w6, w7
        bn.addvm.8S                w6, w6, w7
        bn.mulv.l.8S.even.acc.z.lo w7, w30, sw1.3
        bn.mulv.l.8S.even.lo       w7, w7, sw0.1
        bn.mulv.l.8S.even.acc.hi   w7, w7, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w7, w7, sw1.3
        bn.mulv.l.8S.odd.lo        w7, w7, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w7, w7, sw0.0

        bn.subvm.8S                w30, w8, w9
        bn.addvm.8S                w8, w8, w9
        bn.mulv.l.8S.even.acc.z.lo w9, w30, sw1.4
        bn.mulv.l.8S.even.lo       w9, w9, sw0.1
        bn.mulv.l.8S.even.acc.hi   w9, w9, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w9, w9, sw1.4
        bn.mulv.l.8S.odd.lo        w9, w9, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w9, w9, sw0.0

        bn.subvm.8S                w30, w10, w11
        bn.addvm.8S                w10, w10, w11
        bn.mulv.l.8S.even.acc.z.lo w11, w30, sw1.5
        bn.mulv.l.8S.even.lo       w11, w11, sw0.1
        bn.mulv.l.8S.even.acc.hi   w11, w11, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w11, w11, sw1.5
        bn.mulv.l.8S.odd.lo        w11, w11, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w11, w11, sw0.0

        bn.subvm.8S                w30, w12, w13
        bn.addvm.8S                w12, w12, w13
        bn.mulv.l.8S.even.acc.z.lo w13, w30, sw1.6
        bn.mulv.l.8S.even.lo       w13, w13, sw0.1
        bn.mulv.l.8S.even.acc.hi   w13, w13, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w13, w13, sw1.6
        bn.mulv.l.8S.odd.lo        w13, w13, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w13, w13, sw0.0

        bn.subvm.8S                w30, w14, w15
        bn.addvm.8S                w14, w14, w15
        bn.mulv.l.8S.even.acc.z.lo w15, w30, sw1.7
        bn.mulv.l.8S.even.lo       w15, w15, sw0.1
        bn.mulv.l.8S.even.acc.hi   w15, w15, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w15, w15, sw1.7
        bn.mulv.l.8S.odd.lo        w15, w15, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w15, w15, sw0.0


        bn.sid x4, 0(x10++)
        bn.sid x5, 0(x10++)
        bn.sid x6, 0(x10++)
        bn.sid x7, 0(x10++)
        bn.sid x8, 0(x10++)
        bn.sid x9, 0(x10++)
        bn.sid x13,0(x10++)
        bn.sid x14,0(x10++)
        bn.sid x15,0(x10++)
        bn.sid x16,0(x10++)
        bn.sid x17,0(x10++)
        bn.sid x18,0(x10++)
        bn.sid x19,0(x10++)
        bn.sid x20,0(x10++)
        bn.sid x21,0(x10++)
        bn.sid x22,0(x10++)

    /* Restore input pointer */
    addi x10, x10, -1024

    /* Load twiddle factors for layers 1--4 */
    bn.lid x23, 0(x11) /* w17 */
    bn.lid x24, 32(x11) /* w18 */
    bn.mov w19, w17 /* Save the first batch of Twiddle factors to w19 */

    LOOPI 2, 357
        /* Load input data */
        bn.lid x4, 0(x10)
        bn.lid x5, 64(x10)
        bn.lid x6, 128(x10)
        bn.lid x7, 192(x10)
        bn.lid x8, 256(x10)
        bn.lid x9, 320(x10)
        bn.lid x13, 384(x10)
        bn.lid x14, 448(x10)
        bn.lid x15, 512(x10)
        bn.lid x16, 576(x10)
        bn.lid x17, 640(x10)
        bn.lid x18, 704(x10)
        bn.lid x19, 768(x10)
        bn.lid x20, 832(x10)
        bn.lid x21, 896(x10)
        bn.lid x22, 960(x10)

        /* Reverse Layer 4, stride 16 */
        bn.subvm.8S                w30, w0, w1
        bn.addvm.8S                w0, w0, w1
        bn.mulv.l.8S.even.acc.z.lo w1, w30, sw1.0
        bn.mulv.l.8S.even.lo       w1, w1, sw0.1
        bn.mulv.l.8S.even.acc.hi   w1, w1, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w1, w1, sw1.0
        bn.mulv.l.8S.odd.lo        w1, w1, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w1, w1, sw0.0

        bn.subvm.8S                w30, w2, w3
        bn.addvm.8S                w2, w2, w3
        bn.mulv.l.8S.even.acc.z.lo w3, w30, sw1.1
        bn.mulv.l.8S.even.lo       w3, w3, sw0.1
        bn.mulv.l.8S.even.acc.hi   w3, w3, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w3, w3, sw1.1
        bn.mulv.l.8S.odd.lo        w3, w3, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w3, w3, sw0.0

        bn.subvm.8S                w30, w4, w5
        bn.addvm.8S                w4, w4, w5
        bn.mulv.l.8S.even.acc.z.lo w5, w30, sw1.2
        bn.mulv.l.8S.even.lo       w5, w5, sw0.1
        bn.mulv.l.8S.even.acc.hi   w5, w5, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w5, w5, sw1.2
        bn.mulv.l.8S.odd.lo        w5, w5, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w5, w5, sw0.0

        bn.subvm.8S                w30, w6, w7
        bn.addvm.8S                w6, w6, w7
        bn.mulv.l.8S.even.acc.z.lo w7, w30, sw1.3
        bn.mulv.l.8S.even.lo       w7, w7, sw0.1
        bn.mulv.l.8S.even.acc.hi   w7, w7, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w7, w7, sw1.3
        bn.mulv.l.8S.odd.lo        w7, w7, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w7, w7, sw0.0

        bn.subvm.8S                w30, w8, w9
        bn.addvm.8S                w8, w8, w9
        bn.mulv.l.8S.even.acc.z.lo w9, w30, sw1.4
        bn.mulv.l.8S.even.lo       w9, w9, sw0.1
        bn.mulv.l.8S.even.acc.hi   w9, w9, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w9, w9, sw1.4
        bn.mulv.l.8S.odd.lo        w9, w9, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w9, w9, sw0.0

        bn.subvm.8S                w30, w10, w11
        bn.addvm.8S                w10, w10, w11
        bn.mulv.l.8S.even.acc.z.lo w11, w30, sw1.5
        bn.mulv.l.8S.even.lo       w11, w11, sw0.1
        bn.mulv.l.8S.even.acc.hi   w11, w11, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w11, w11, sw1.5
        bn.mulv.l.8S.odd.lo        w11, w11, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w11, w11, sw0.0

        bn.subvm.8S                w30, w12, w13
        bn.addvm.8S                w12, w12, w13
        bn.mulv.l.8S.even.acc.z.lo w13, w30, sw1.6
        bn.mulv.l.8S.even.lo       w13, w13, sw0.1
        bn.mulv.l.8S.even.acc.hi   w13, w13, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w13, w13, sw1.6
        bn.mulv.l.8S.odd.lo        w13, w13, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w13, w13, sw0.0

        bn.subvm.8S                w30, w14, w15
        bn.addvm.8S                w14, w14, w15
        bn.mulv.l.8S.even.acc.z.lo w15, w30, sw1.7
        bn.mulv.l.8S.even.lo       w15, w15, sw0.1
        bn.mulv.l.8S.even.acc.hi   w15, w15, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w15, w15, sw1.7
        bn.mulv.l.8S.odd.lo        w15, w15, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w15, w15, sw0.0

        /* Layer 3 */
        bn.mov w17, w18 /* Copy second batch of Twiddle factors to w17 */

        bn.subvm.8S                w30, w0, w2
        bn.addvm.8S                w0, w0, w2
        bn.mulv.l.8S.even.acc.z.lo w2, w30, sw1.0
        bn.mulv.l.8S.even.lo       w2, w2, sw0.1
        bn.mulv.l.8S.even.acc.hi   w2, w2, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w2, w2, sw1.0
        bn.mulv.l.8S.odd.lo        w2, w2, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w2, w2, sw0.0

        bn.subvm.8S                w30, w1, w3
        bn.addvm.8S                w1, w1, w3
        bn.mulv.l.8S.even.acc.z.lo w3, w30, sw1.0
        bn.mulv.l.8S.even.lo       w3, w3, sw0.1
        bn.mulv.l.8S.even.acc.hi   w3, w3, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w3, w3, sw1.0
        bn.mulv.l.8S.odd.lo        w3, w3, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w3, w3, sw0.0

        bn.subvm.8S                w30, w4, w6
        bn.addvm.8S                w4, w4, w6
        bn.mulv.l.8S.even.acc.z.lo w6, w30, sw1.1
        bn.mulv.l.8S.even.lo       w6, w6, sw0.1
        bn.mulv.l.8S.even.acc.hi   w6, w6, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w6, w6, sw1.1
        bn.mulv.l.8S.odd.lo        w6, w6, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w6, w6, sw0.0

        bn.subvm.8S                w30, w5, w7
        bn.addvm.8S                w5, w5, w7
        bn.mulv.l.8S.even.acc.z.lo w7, w30, sw1.1
        bn.mulv.l.8S.even.lo       w7, w7, sw0.1
        bn.mulv.l.8S.even.acc.hi   w7, w7, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w7, w7, sw1.1
        bn.mulv.l.8S.odd.lo        w7, w7, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w7, w7, sw0.0

        bn.subvm.8S                w30, w8, w10
        bn.addvm.8S                w8, w8, w10
        bn.mulv.l.8S.even.acc.z.lo w10, w30, sw1.2
        bn.mulv.l.8S.even.lo       w10, w10, sw0.1
        bn.mulv.l.8S.even.acc.hi   w10, w10, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w10, w10, sw1.2
        bn.mulv.l.8S.odd.lo        w10, w10, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w10, w10, sw0.0

        bn.subvm.8S                w30, w9, w11
        bn.addvm.8S                w9, w9, w11
        bn.mulv.l.8S.even.acc.z.lo w11, w30, sw1.2
        bn.mulv.l.8S.even.lo       w11, w11, sw0.1
        bn.mulv.l.8S.even.acc.hi   w11, w11, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w11, w11, sw1.2
        bn.mulv.l.8S.odd.lo        w11, w11, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w11, w11, sw0.0

        bn.subvm.8S                w30, w12, w14
        bn.addvm.8S                w12, w12, w14
        bn.mulv.l.8S.even.acc.z.lo w14, w30, sw1.3
        bn.mulv.l.8S.even.lo       w14, w14, sw0.1
        bn.mulv.l.8S.even.acc.hi   w14, w14, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w14, w14, sw1.3
        bn.mulv.l.8S.odd.lo        w14, w14, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w14, w14, sw0.0

        bn.subvm.8S                w30, w13, w15
        bn.addvm.8S                w13, w13, w15
        bn.mulv.l.8S.even.acc.z.lo w15, w30, sw1.3
        bn.mulv.l.8S.even.lo       w15, w15, sw0.1
        bn.mulv.l.8S.even.acc.hi   w15, w15, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w15, w15, sw1.3
        bn.mulv.l.8S.odd.lo        w15, w15, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w15, w15, sw0.0

        /* Layer 2 */
        bn.subvm.8S                w30, w0, w4
        bn.addvm.8S                w0, w0, w4
        bn.mulv.l.8S.even.acc.z.lo w4, w30, sw1.4
        bn.mulv.l.8S.even.lo       w4, w4, sw0.1
        bn.mulv.l.8S.even.acc.hi   w4, w4, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w4, w4, sw1.4
        bn.mulv.l.8S.odd.lo        w4, w4, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w4, w4, sw0.0

        bn.subvm.8S                w30, w1, w5
        bn.addvm.8S                w1, w1, w5
        bn.mulv.l.8S.even.acc.z.lo w5, w30, sw1.4
        bn.mulv.l.8S.even.lo       w5, w5, sw0.1
        bn.mulv.l.8S.even.acc.hi   w5, w5, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w5, w5, sw1.4
        bn.mulv.l.8S.odd.lo        w5, w5, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w5, w5, sw0.0

        bn.subvm.8S                w30, w2, w6
        bn.addvm.8S                w2, w2, w6
        bn.mulv.l.8S.even.acc.z.lo w6, w30, sw1.4
        bn.mulv.l.8S.even.lo       w6, w6, sw0.1
        bn.mulv.l.8S.even.acc.hi   w6, w6, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w6, w6, sw1.4
        bn.mulv.l.8S.odd.lo        w6, w6, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w6, w6, sw0.0

        bn.subvm.8S                w30, w3, w7
        bn.addvm.8S                w3, w3, w7
        bn.mulv.l.8S.even.acc.z.lo w7, w30, sw1.4
        bn.mulv.l.8S.even.lo       w7, w7, sw0.1
        bn.mulv.l.8S.even.acc.hi   w7, w7, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w7, w7, sw1.4
        bn.mulv.l.8S.odd.lo        w7, w7, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w7, w7, sw0.0

        bn.subvm.8S                w30, w8, w12
        bn.addvm.8S                w8, w8, w12
        bn.mulv.l.8S.even.acc.z.lo w12, w30, sw1.5
        bn.mulv.l.8S.even.lo       w12, w12, sw0.1
        bn.mulv.l.8S.even.acc.hi   w12, w12, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w12, w12, sw1.5
        bn.mulv.l.8S.odd.lo        w12, w12, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w12, w12, sw0.0

        bn.subvm.8S                w30, w9, w13
        bn.addvm.8S                w9, w9, w13
        bn.mulv.l.8S.even.acc.z.lo w13, w30, sw1.5
        bn.mulv.l.8S.even.lo       w13, w13, sw0.1
        bn.mulv.l.8S.even.acc.hi   w13, w13, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w13, w13, sw1.5
        bn.mulv.l.8S.odd.lo        w13, w13, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w13, w13, sw0.0

        bn.subvm.8S                w30, w10, w14
        bn.addvm.8S                w10, w10, w14
        bn.mulv.l.8S.even.acc.z.lo w14, w30, sw1.5
        bn.mulv.l.8S.even.lo       w14, w14, sw0.1
        bn.mulv.l.8S.even.acc.hi   w14, w14, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w14, w14, sw1.5
        bn.mulv.l.8S.odd.lo        w14, w14, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w14, w14, sw0.0

        bn.subvm.8S                w30, w11, w15
        bn.addvm.8S                w11, w11, w15
        bn.mulv.l.8S.even.acc.z.lo w15, w30, sw1.5
        bn.mulv.l.8S.even.lo       w15, w15, sw0.1
        bn.mulv.l.8S.even.acc.hi   w15, w15, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w15, w15, sw1.5
        bn.mulv.l.8S.odd.lo        w15, w15, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w15, w15, sw0.0

        /* Layer 1 */
        bn.subvm.8S                w30, w0, w8
        bn.addvm.8S                w0, w0, w8
        bn.mulv.l.8S.even.acc.z.lo w8, w30, sw1.6
        bn.mulv.l.8S.even.lo       w8, w8, sw0.1
        bn.mulv.l.8S.even.acc.hi   w8, w8, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w8, w8, sw1.6
        bn.mulv.l.8S.odd.lo        w8, w8, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w8, w8, sw0.0

        bn.subvm.8S                w30, w1, w9
        bn.addvm.8S                w1, w1, w9
        bn.mulv.l.8S.even.acc.z.lo w9, w30, sw1.6
        bn.mulv.l.8S.even.lo       w9, w9, sw0.1
        bn.mulv.l.8S.even.acc.hi   w9, w9, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w9, w9, sw1.6
        bn.mulv.l.8S.odd.lo        w9, w9, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w9, w9, sw0.0

        bn.subvm.8S                w30, w2, w10
        bn.addvm.8S                w2, w2, w10
        bn.mulv.l.8S.even.acc.z.lo w10, w30, sw1.6
        bn.mulv.l.8S.even.lo       w10, w10, sw0.1
        bn.mulv.l.8S.even.acc.hi   w10, w10, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w10, w10, sw1.6
        bn.mulv.l.8S.odd.lo        w10, w10, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w10, w10, sw0.0

        bn.subvm.8S                w30, w3, w11
        bn.addvm.8S                w3, w3, w11
        bn.mulv.l.8S.even.acc.z.lo w11, w30, sw1.6
        bn.mulv.l.8S.even.lo       w11, w11, sw0.1
        bn.mulv.l.8S.even.acc.hi   w11, w11, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w11, w11, sw1.6
        bn.mulv.l.8S.odd.lo        w11, w11, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w11, w11, sw0.0

        bn.subvm.8S                w30, w4, w12
        bn.addvm.8S                w4, w4, w12
        bn.mulv.l.8S.even.acc.z.lo w12, w30, sw1.6
        bn.mulv.l.8S.even.lo       w12, w12, sw0.1
        bn.mulv.l.8S.even.acc.hi   w12, w12, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w12, w12, sw1.6
        bn.mulv.l.8S.odd.lo        w12, w12, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w12, w12, sw0.0

        bn.subvm.8S                w30, w5, w13
        bn.addvm.8S                w5, w5, w13
        bn.mulv.l.8S.even.acc.z.lo w13, w30, sw1.6
        bn.mulv.l.8S.even.lo       w13, w13, sw0.1
        bn.mulv.l.8S.even.acc.hi   w13, w13, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w13, w13, sw1.6
        bn.mulv.l.8S.odd.lo        w13, w13, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w13, w13, sw0.0

        bn.subvm.8S                w30, w6, w14
        bn.addvm.8S                w6, w6, w14
        bn.mulv.l.8S.even.acc.z.lo w14, w30, sw1.6
        bn.mulv.l.8S.even.lo       w14, w14, sw0.1
        bn.mulv.l.8S.even.acc.hi   w14, w14, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w14, w14, sw1.6
        bn.mulv.l.8S.odd.lo        w14, w14, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w14, w14, sw0.0

        bn.subvm.8S                w30, w7, w15
        bn.addvm.8S                w7, w7, w15
        bn.mulv.l.8S.even.acc.z.lo w15, w30, sw1.6
        bn.mulv.l.8S.even.lo       w15, w15, sw0.1
        bn.mulv.l.8S.even.acc.hi   w15, w15, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w15, w15, sw1.6
        bn.mulv.l.8S.odd.lo        w15, w15, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w15, w15, sw0.0

        /* At the end of 8th layer, all coeffs are in [0,2q). Here, we switch MOD back to q so that
         * output of INTT would be in [0,q). */
        bn.wsrr w21, 0x0 /* w21 = MOD = 2*R | 2*Q */
        bn.wsrw 0x0, w16 /* MOD = R | Q */
        /* Multiply n^{-1} */
        bn.mulv.l.8S.even.acc.z.lo w0, w0, sw1.7
        bn.mulv.l.8S.even.lo       w0, w0, sw0.1
        bn.mulv.l.8S.even.acc.hi   w0, w0, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w0, w0, sw1.7
        bn.mulv.l.8S.odd.lo        w0, w0, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w0, w0, sw0.0
        bn.addvm.8S                w0, w0, w20

        bn.mulv.l.8S.even.acc.z.lo w1, w1, sw1.7
        bn.mulv.l.8S.even.lo       w1, w1, sw0.1
        bn.mulv.l.8S.even.acc.hi   w1, w1, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w1, w1, sw1.7
        bn.mulv.l.8S.odd.lo        w1, w1, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w1, w1, sw0.0
        bn.addvm.8S                w1, w1, w20

        bn.mulv.l.8S.even.acc.z.lo w2, w2, sw1.7
        bn.mulv.l.8S.even.lo       w2, w2, sw0.1
        bn.mulv.l.8S.even.acc.hi   w2, w2, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w2, w2, sw1.7
        bn.mulv.l.8S.odd.lo        w2, w2, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w2, w2, sw0.0
        bn.addvm.8S                w2, w2, w20

        bn.mulv.l.8S.even.acc.z.lo w3, w3, sw1.7
        bn.mulv.l.8S.even.lo       w3, w3, sw0.1
        bn.mulv.l.8S.even.acc.hi   w3, w3, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w3, w3, sw1.7
        bn.mulv.l.8S.odd.lo        w3, w3, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w3, w3, sw0.0
        bn.addvm.8S                w3, w3, w20

        bn.mulv.l.8S.even.acc.z.lo w4, w4, sw1.7
        bn.mulv.l.8S.even.lo       w4, w4, sw0.1
        bn.mulv.l.8S.even.acc.hi   w4, w4, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w4, w4, sw1.7
        bn.mulv.l.8S.odd.lo        w4, w4, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w4, w4, sw0.0
        bn.addvm.8S                w4, w4, w20

        bn.mulv.l.8S.even.acc.z.lo w5, w5, sw1.7
        bn.mulv.l.8S.even.lo       w5, w5, sw0.1
        bn.mulv.l.8S.even.acc.hi   w5, w5, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w5, w5, sw1.7
        bn.mulv.l.8S.odd.lo        w5, w5, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w5, w5, sw0.0
        bn.addvm.8S                w5, w5, w20

        bn.mulv.l.8S.even.acc.z.lo w6, w6, sw1.7
        bn.mulv.l.8S.even.lo       w6, w6, sw0.1
        bn.mulv.l.8S.even.acc.hi   w6, w6, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w6, w6, sw1.7
        bn.mulv.l.8S.odd.lo        w6, w6, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w6, w6, sw0.0
        bn.addvm.8S                w6, w6, w20

        bn.mulv.l.8S.even.acc.z.lo w7, w7, sw1.7
        bn.mulv.l.8S.even.lo       w7, w7, sw0.1
        bn.mulv.l.8S.even.acc.hi   w7, w7, sw0.0
        bn.mulv.l.8S.odd.acc.z.lo  w7, w7, sw1.7
        bn.mulv.l.8S.odd.lo        w7, w7, sw0.1
        bn.mulv.l.8S.odd.acc.hi    w7, w7, sw0.0
        bn.addvm.8S                w7, w7, w20
        /* Since switching MOD back and forth between q and 2q is inefficient during the last layer, we
         * use addvm with MOD = q here for the other half of the coeffs to reduce them in [0,q). */
        bn.addvm.8S w8, w8, w20
        bn.addvm.8S w9, w9, w20
        bn.addvm.8S w10, w10, w20
        bn.addvm.8S w11, w11, w20
        bn.addvm.8S w12, w12, w20
        bn.addvm.8S w13, w13, w20
        bn.addvm.8S w14, w14, w20
        bn.addvm.8S w15, w15, w20

        /* Restore MOD = 2*R | 2*Q for next INTT */
        bn.wsrw 0x0, w21

        bn.mov w17, w19 /* Copy the first batch of Twiddle factors back for next loop. */

        /* Store output data */
        bn.sid x4,  0(x10)
        bn.sid x5, 64(x10)
        bn.sid x6, 128(x10)
        bn.sid x7, 192(x10)
        bn.sid x8, 256(x10)
        bn.sid x9, 320(x10)
        bn.sid x13, 384(x10)
        bn.sid x14, 448(x10)
        bn.sid x15, 512(x10)
        bn.sid x16, 576(x10)
        bn.sid x17, 640(x10)
        bn.sid x18, 704(x10)
        bn.sid x19, 768(x10)
        bn.sid x20, 832(x10)
        bn.sid x21, 896(x10)
        bn.sid x22, 960(x10++)

    .irp reg,s11,s10,s9,s8,s7,s6,s5,s4,s3,s2,s1,s0
        pop \reg
    .endr

    bn.xor w31, w31, w31
    /* Restore input pointer */
    addi x10, x10, -64
    ret
