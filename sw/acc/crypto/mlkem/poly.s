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

#define N_WDR 16
#define N_COEFFS 16

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

.equ w31, bn0

/*
 * Name:        poly_frommsg
 *
 * Description: Convert 32-byte message to polynomial
 *
 * Arguments:   - uint8_t r: input byte array (KYBER_SYMBYTES=32 bytes)
 *              - poly a: output polynomial, n=256, q=3329
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: dptr_input, dmem pointer to input byte array
 * @param[out] x11: dptr_output, dmem pointer to output
 *
 * clobbered registers: x4 to x6, x12, w0 to w1, w3
 * clobbered flag groups: FG0
 */

.globl poly_frommsg
poly_frommsg:
    /* Load constant. */
    la     t0, modulus_over_2
    addi   x4, x0, 3
    bn.lid x4, 0(t0)

    /* All-zero register. */
    bn.xor bn0, bn0, bn0

    addi   x4, x0, 1
    bn.lid x0, 0(a0)
    loopi N_WDR, 7
        loopi N_COEFFS, 3
            bn.rshi w1, w0, w1 >> 1
            bn.rshi w1, bn0, w1 >> 15
            bn.rshi w0, bn0, w0 >> 1
        bn.subv.16h w1, bn0, w1
        bn.and      w1, w1, w3
        bn.sid      x4, 0(a1++)
    ret

/*
 * Name:        poly_tomsg
 *
 * Description: Convert polynomial to 32-byte message
 *
 * Arguments:   - uint8_t r: output byte array (KYBER_SYMBYTES=32 bytes)
 *              - poly a: input polynomial, n=256, q=3329
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: dptr_input, dmem pointer to input polynomial
 * @param[out] x11: dptr_output, dmem pointer to output byte array
 *
 * clobbered registers: TODO
 * clobbered flag groups: FG0
 */

.globl poly_tomsg
poly_tomsg:
    /* Load consts. */
    la     t0, modulus_over_2
    addi   x4, x0, 2
    bn.lid x4, 0(t0) /* w2 = (0x681)^16 */
    bn.mov w30, w16 /* Save w16 */
    la     t0, const_1290167
    addi   x4, x0, 16
    bn.lid x4, 0(t0) /* w16 = 1290167 */

    /* Multiply the constant 80635 with 2**4 so that later we shift to the right
    * 32 bits instead of 28 bits. This means we can return the high parts of
    * the 64-bit products within the multiplication instruction. */
    bn.subi w16, w16, 7 /* w16 = 1290160 = 80635 << 4 */

    /* All-zero register. */
    bn.xor bn0, bn0, bn0

    loopi N_WDR, 14
        bn.lid               x0, 0(a0++)  /* Load input */
        bn.shv.16h           w0, w0 << 1   /* <= 1 */
        bn.addv.16h          w0, w0, w2    /* += 1665 */
        bn.trn1.16h          w1, w0, bn0 /* Put even coeffs in 32-bit slots */
        bn.mulv.l.8s.even.hi w1, w1, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
        bn.mulv.l.8s.odd.hi  w1, w1, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
        bn.trn2.16h          w0, w0, bn0 /* Put odd coeffs to 32-bit slots */
        bn.mulv.l.8s.even.hi w0, w0, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
        bn.mulv.l.8s.odd.hi  w0, w0, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
        bn.trn1.16h          w0, w1, w0 /* Interleaving the results to original order */
        loopi N_COEFFS, 2
            bn.rshi w3, w0, w3 >> 1
            bn.rshi w0, bn0, w0 >> 16
        nop
    addi   x4, x0, 3
    bn.sid x4, 0(a1)
    bn.mov w16, w30 /* Restore w16. */
    ret

/*
 * Name:        poly_add
 *
 * Description: Add 2 vectors
 *
 * Arguments:   -
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: dptr_input, dmem pointer to first poly
 * @param[in]  x11: dptr_input, dmem pointer to second poly
 * @param[in]  x12: dptr_output, dmem pointer to output polynomial
 *
 * clobbered registers: x4, x10 to x12, w0 to w1
 * clobbered flag groups: none
 */
.globl poly_add
poly_add:
    li x4, 1

    loopi N_WDR, 4
        bn.lid       x0, 0(a0++)
        bn.lid       x4, 0(a1++)
        bn.addvm.16h w0, w0, w1
        bn.sid       x0, 0(a2++)
    ret

/*
 * Name:        poly_sub
 *
 * Description: Sub 2 vectors
 *
 * Arguments:   -
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: dptr_input, dmem pointer to first poly
 * @param[in]  x11: dptr_input, dmem pointer to second poly
 * @param[out] x12: dptr_output, dmem pointer to output polynomial
 *
 * clobbered registers: x4, x10 to x12, w0 to w1
 * clobbered flag groups: none
 */
.globl poly_sub
poly_sub:
    li x4, 1

    loopi N_WDR, 4
        bn.lid       x0, 0(a0++)
        bn.lid       x4, 0(a1++)
        bn.subvm.16h w0, w0, w1
        bn.sid       x0, 0(a2++)
    ret

/*
 * Name:        poly_tomont
 *
 * Description: Put the input polynomial out of Montgomery domain
 *
 * Arguments:   -
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in/out]  x10: dptr_input, dmem pointer to first poly
 * @param[in]      w16: sw0, where sw0.2 = Q^-1 mod 2^32, sw0.0 = Q
 *
 * clobbered registers: x4, x10, w0 to w1, acc, acch
 * clobbered flag groups: none
 */
.globl poly_tomont
poly_tomont:
    /* All-zero register. */
    bn.xor bn0, bn0, bn0

    /* Load const_tomont */
    la     t0, const_tomont
    li     x4, 0
    bn.lid x4++, 0(t0)

    loopi N_WDR, 6
        bn.lid               x4, 0(a0)
        bn.mulv.16h.acc.z.lo w1, w0, w1
        bn.mulv.l.16h.lo     w1, w1, sw0.2
        bn.mulv.l.16h.acc.hi w1, w1, sw0.0
        bn.addvm.16h         w1, w1, bn0
        bn.sid               x4, 0(a0++)
    ret
