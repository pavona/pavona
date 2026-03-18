/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/* This gadget is specific to ML-KEM. */

.text

#define N 256 /* Number of coefficients in a polynomial. */

#ifndef NSHARES
    #define NSHARES 2
#endif

#ifndef KYBER_K
    #define KYBER_K 3
#endif

#if KYBER_K == 4
    #define DU 11
    #define DV 5
#else
    #define DU 10
    #define DV 4
#endif

#define NB_POLY 512 /* Number of bytes occupied by a polynomial */
#define N_WDR 16 /* Number of WDRs to store N coeffs */
#define BITSIZE 16 /* Register bit size */
#define BITSIZEm1 15 /* BITSIZE - 1 */
#define N_COEFFS 16 /* Number of coeffs fitting in a WDR */
#define W 4 /* ceil(log2(k - 1)), k = 16 */
#define Wm1 3 /* W - 1 */

/* Register aliases */
.equ x0, zero
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
 * Name: poly_compare_bgr21 (??)
 *
 * Given an arithmetic-masked polynomial ca, and a portion of a compressed
 * public ciphertext c, return a tuple (wb, xb) where
 * wb = Boolean-masked(MSB(x, S(ci))) and xb = Boolean-masked(MSB(x, E(ci))).
 * S, E are two public functions s.t. Compressq(x,d) = ci if x is in [S(ci), E(ci) - 1].
 * This function is specific to ML-KEM.
 * Vectorized for polynomial.
 *
 * Source: Alg.2 [BGR+21]
 *         [BGR+21]: "Masking Kyber: First- and Higher-Order Implementations"
 *         Link: https://tches.iacr.org/index.php/TCHES/article/view/9064
 *
 * Flags: -
 *
 * @param[in]  x10: dptr_ca, dmem pointer to the input arithmetic shares
 * @param[in]  x11: dptr_c, dmem pointer to the compressed public ciphertext
 * @param[in]  x12: d, the amount of compression in the function Compressq
 * @param[in]  x13: nshares, the number of shares
 * @param[out] x14: dptr_rb, dmem pointer to the output arithmetic shares
 * @param[out] x15: k, the security level
 *
 * clobbered registers: TODO
 */
.globl poly_compare_bgr21
poly_compare_bgr21:
    /* Save fp to stack */
    addi sp, sp, -64
    sw   fp, 0(sp)
    addi fp, sp, 0

    /* Save input and output pointers. */
    sw a3, 8(fp) /* nshares */
    sw a4, 12(fp) /* ptr_rb */

    sw s0, 4(fp)
    sw s1, 24(fp)
    sw s2, 28(fp)
    sw s3, 32(fp)

    /* Search for S and E values for all input coefficients. In the constant
     * "du" (or "dv"), for every word, the lower half is S and the upper half
     * is E. We need space for two masked polynomials to store S and E. */
    addi sp, sp, -NB_POLY
    addi s0, sp, 0 /* s0 = ptr_S */
    addi sp, sp, -NB_POLY
    addi s1, sp, 0 /* s1 = ptr_E */
    loop a3, 1
        addi sp, sp, -NB_POLY
    sw   sp, 16(fp)
    addi s2, sp, 0 /* s2 = ptr_wb = ptr_wa */
    loop a3, 1
        addi sp, sp, -NB_POLY
    sw   sp, 20(fp)
    addi s3, sp, 0 /* s3 = ptr_xb = ptr_xa */
    /* Decode c in a temporary stack space. */
    addi sp, sp, -NB_POLY
    addi t2, sp, 0 /* t2 = ptr_c_decoded */

    /* All-zero register. */
    bn.xor bn0, bn0, bn0

    /* If the input d is DU, then we load the address of S,E for DU.
     * Else we load S,E for DV. */
    li     x4, 5
    sub    x4, x4, a2
    srli   x4, x4, 31
    bne    x4, x0, _handle_du

    li     x4, 4
    bne    a5, x4, _handle_dv_kn4

_handle_dv_k4:
    /* Decode c. */
    la     t1, mask_dv_k4
    li     x4, 2
    bn.lid x4, 0(t1) /* w2 = mask_dv */

    li   x4, 1
    /* 1st - 2nd - 3rd WDR */
    bn.lid x0, 0(a1++)
    loopi 3, 5
        loopi 16, 2
            bn.rshi w1, w0, w1 >> 16
            bn.rshi w0, bn0, w0 >> 5
        bn.and w1, w1, w2
        bn.sid x4, 0(t2++)
    /* 4th WDR */
    loopi 3, 2
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w0, bn0, w0 >> 5
    bn.rshi w1, w0, w1 >> 1
    bn.lid  x0, 0(a1++)
    bn.rshi w1, w0, w1 >> 15
    bn.rshi w0, bn0, w0 >> 4
    loopi 12, 3
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w0, bn0, w0 >> 5
    bn.and w1, w1, w2
    bn.sid x4, 0(t2++)
    /* 5th - 6th WDR */
    loopi 2, 5
        loopi 16, 2
            bn.rshi w1, w0, w1 >> 16
            bn.rshi w0, bn0, w0 >> 5
        bn.and w1, w1, w2
        bn.sid x4, 0(t2++)
    /* 7th WDR */
    loopi 6, 2
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w0, bn0, w0 >> 5
    bn.rshi w1, w0, w1 >> 2
    bn.lid  x0, 0(a1++)
    bn.rshi w1, w0, w1 >> 14
    bn.rshi w0, bn0, w0 >> 3
    loopi 9, 2
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w0, bn0, w0 >> 5
    bn.and w1, w1, w2
    bn.sid x4, 0(t2++)
    /* 8th - 9th WDR */
    loopi 2, 5
        loopi 16, 2
            bn.rshi w1, w0, w1 >> 16
            bn.rshi w0, bn0, w0 >> 5
        bn.and w1, w1, w2
        bn.sid x4, 0(t2++)
    /* 10th WDR */
    loopi 9, 2
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w0, bn0, w0 >> 5
    bn.rshi w1, w0, w1 >> 3
    bn.lid  x0, 0(a1++)
    bn.rshi w1, w0, w1 >> 13
    bn.rshi w0, bn0, w0 >> 2
    loopi 6, 2
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w0, bn0, w0 >> 5
    bn.and w1, w1, w2
    bn.sid x4, 0(t2++)
    /* 11th - 12th WDR */
    loopi 2, 5
        loopi 16, 2
            bn.rshi w1, w0, w1 >> 16
            bn.rshi w0, bn0, w0 >> 5
        bn.and w1, w1, w2
        bn.sid x4, 0(t2++)
    /* 13th WDR */
    loopi 12, 2
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w0, bn0, w0 >> 5
    bn.rshi w1, w0, w1 >> 4
    bn.lid  x0, 0(a1++)
    bn.rshi w1, w0, w1 >> 12
    bn.rshi w0, bn0, w0 >> 1
    loopi 3, 2
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w0, bn0, w0 >> 5
    bn.and w1, w1, w2
    bn.sid x4, 0(t2++)
    /* 14th - 15th - 16th WDR */
    loopi 3, 5
        loopi 16, 2
            bn.rshi w1, w0, w1 >> 16
            bn.rshi w0, bn0, w0 >> 5
        bn.and w1, w1, w2
        bn.sid x4, 0(t2++)

    la  t0, dv_k4
    beq x0, x0, _handle_common

_handle_dv_kn4:
    /* Decode c. */
    la     t1, mask_dv_kn4
    li     x4, 2
    bn.lid x4, 0(t1) /* w2 = mask_dv */

    li x4, 1
    loopi 4, 8
        bn.lid x0, 0(a1++)
        loopi 4, 5
            loopi 16, 2
                bn.rshi w1, w0, w1 >> 16
                bn.rshi w0, bn0, w0 >> 4
            bn.and w1, w1, w2
            bn.sid x4, 0(t2++)
        nop

    la  t0, dv_kn4
    beq x0, x0, _handle_common

_handle_du:
    li   x4, 4
    bne  a5, x4, _handle_du_kn4

_handle_du_k4:
    /* Decode c. */
    la     t1, mask_du_k4
    li     x4, 2
    bn.lid x4, 0(t1) /* w2 = mask_du */

    li     x4, 1
    /* 1st WDR */
    bn.lid x0, 0(a1++)
    loopi 16, 2
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w0, bn0, w0 >> 11
    bn.and w1, w1, w2
    bn.sid x4, 0(t2++)
    /* 2nd WDR */
    loopi 7, 2
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w0, bn0, w0 >> 11
    bn.rshi w1, w0, w1 >> 3
    bn.lid  x0, 0(a1++)
    bn.rshi w1, w0, w1 >> 13
    bn.rshi w0, bn0, w0 >> 8
    loopi 8, 2
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w0, bn0, w0 >> 11
    bn.and w1, w1, w2
    bn.sid x4, 0(t2++)
    /* 3rd WDR */
    loopi 14, 2
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w0, bn0, w0 >> 11
    bn.rshi w1, w0, w1 >> 6
    bn.lid  x0, 0(a1++)
    bn.rshi w1, w0, w1 >> 10
    bn.rshi w0, bn0, w0 >> 5
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, bn0, w0 >> 11
    bn.and  w1, w1, w2
    bn.sid  x4, 0(t2++)
    /* 4th WDR */
    loopi 16, 2
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w0, bn0, w0 >> 11
    bn.and w1, w1, w2
    bn.sid x4, 0(t2++)
    /* 5th WDR */
    loopi 5, 2
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w0, bn0, w0 >> 11
    bn.rshi w1, w0, w1 >> 9
    bn.lid  x0, 0(a1++)
    bn.rshi w1, w0, w1 >> 7
    bn.rshi w0, bn0, w0 >> 2
    loopi 10, 2
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w0, bn0, w0 >> 11
    bn.and w1, w1, w2
    bn.sid x4, 0(t2++)
    /* 6th WDR */
    loopi 13, 2
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w0, bn0, w0 >> 11
    bn.rshi w1, w0, w1 >> 1
    bn.lid  x0, 0(a1++)
    bn.rshi w1, w0, w1 >> 15
    bn.rshi w0, bn0, w0 >> 10
    loopi 2, 2
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w0, bn0, w0 >> 11
    bn.and w1, w1, w2
    bn.sid x4, 0(t2++)
    /* 7th WDR */
    loopi 16, 2
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w0, bn0, w0 >> 11
    bn.and w1, w1, w2
    bn.sid x4, 0(t2++)
    /* 8th WDR */
    loopi 4, 2
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w0, bn0, w0 >> 11
    bn.rshi w1, w0, w1 >> 4
    bn.lid  x0, 0(a1++)
    bn.rshi w1, w0, w1 >> 12
    bn.rshi w0, bn0, w0 >> 7
    loopi 11, 2
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w0, bn0, w0 >> 11
    bn.and w1, w1, w2
    bn.sid x4, 0(t2++)
    /* 9th WDR */
    loopi 11, 2
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w0, bn0, w0 >> 11
    bn.rshi w1, w0, w1 >> 7
    bn.lid  x0, 0(a1++)
    bn.rshi w1, w0, w1 >> 9
    bn.rshi w0, bn0, w0 >> 4
    loopi 4, 2
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w0, bn0, w0 >> 11
    bn.and  w1, w1, w2
    bn.sid  x4, 0(t2++)
    /* 10th WDR */
    loopi 16, 2
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w0, bn0, w0 >> 11
    bn.and w1, w1, w2
    bn.sid x4, 0(t2++)
    /* 11th WDR */
    loopi 2, 2
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w0, bn0, w0 >> 11
    bn.rshi w1, w0, w1 >> 10
    bn.lid  x0, 0(a1++)
    bn.rshi w1, w0, w1 >> 6
    bn.rshi w0, bn0, w0 >> 1
    loopi 13, 2
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w0, bn0, w0 >> 11
    bn.and w1, w1, w2
    bn.sid x4, 0(t2++)
    /* 12th WDR */
    loopi 10, 2
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w0, bn0, w0 >> 11
    bn.rshi w1, w0, w1 >> 2
    bn.lid  x0, 0(a1++)
    bn.rshi w1, w0, w1 >> 14
    bn.rshi w0, bn0, w0 >> 9
    loopi 5, 2
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w0, bn0, w0 >> 11
    bn.and w1, w1, w2
    bn.sid x4, 0(t2++)
    /* 13th WDR */
    loopi 16, 2
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w0, bn0, w0 >> 11
    bn.and w1, w1, w2
    bn.sid x4, 0(t2++)
    /* 14th WDR */
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, bn0, w0 >> 11
    bn.rshi w1, w0, w1 >> 5
    bn.lid  x0, 0(a1++)
    bn.rshi w1, w0, w1 >> 11
    bn.rshi w0, bn0, w0 >> 6
    loopi 14, 2
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w0, bn0, w0 >> 11
    bn.and w1, w1, w2
    bn.sid x4, 0(t2++)
    /* 15th WDR */
    loopi 8, 2
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w0, bn0, w0 >> 11
    bn.rshi w1, w0, w1 >> 8
    bn.lid  x0, 0(a1++)
    bn.rshi w1, w0, w1 >> 8
    bn.rshi w0, bn0, w0 >> 3
    loopi 7, 2
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w0, bn0, w0 >> 11
    bn.and w1, w1, w2
    bn.sid x4, 0(t2++)
    /* 16th WDR */
    loopi 16, 2
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w0, bn0, w0 >> 11
    bn.and w1, w1, w2
    bn.sid x4, 0(t2++)

    la  t0, du_k4
    beq x0, x0, _handle_common

_handle_du_kn4:
    /* Decode c. */
    la     t1, mask_du_kn4
    li     x4, 2
    bn.lid x4, 0(t1) /* w2 = mask_du */

    li x4, 1
    loopi 2, 69
        /* 1st WDR */
        bn.lid x0, 0(a1++)
        loopi 16, 2
            bn.rshi w1, w0, w1 >> 16
            bn.rshi w0, bn0, w0 >> 10
        bn.and w1, w1, w2
        bn.sid x4, 0(t2++)
        /* 2nd WDR */
        loopi 9, 2
            bn.rshi w1, w0, w1 >> 16
            bn.rshi w0, bn0, w0 >> 10
        bn.rshi w1, w0, w1 >> 6
        bn.lid  x0, 0(a1++)
        bn.rshi w1, w0, w1 >> 10
        bn.rshi w0, bn0, w0 >> 4
        loopi 6, 2
            bn.rshi w1, w0, w1 >> 16
            bn.rshi w0, bn0, w0 >> 10
        bn.and w1, w1, w2
        bn.sid x4, 0(t2++)
        /* 3rd WDR */
        loopi 16, 2
            bn.rshi w1, w0, w1 >> 16
            bn.rshi w0, bn0, w0 >> 10
        bn.and w1, w1, w2
        bn.sid x4, 0(t2++)
        /* 4th WDR */
        loopi 3, 2
            bn.rshi w1, w0, w1 >> 16
            bn.rshi w0, bn0, w0 >> 10
        bn.rshi w1, w0, w1 >> 2
        bn.lid  x0, 0(a1++)
        bn.rshi w1, w0, w1 >> 14
        bn.rshi w0, bn0, w0 >> 8
        loopi 12, 2
            bn.rshi w1, w0, w1 >> 16
            bn.rshi w0, bn0, w0 >> 10
        bn.and w1, w1, w2
        bn.sid x4, 0(t2++)
        /* 5th WDR */
        loopi 12, 2
            bn.rshi w1, w0, w1 >> 16
            bn.rshi w0, bn0, w0 >> 10
        bn.rshi w1, w0, w1 >> 8
        bn.lid  x0, 0(a1++)
        bn.rshi w1, w0, w1 >> 8
        bn.rshi w0, bn0, w0 >> 2
        loopi 3, 2
            bn.rshi w1, w0, w1 >> 16
            bn.rshi w0, bn0, w0 >> 10
        bn.and w1, w1, w2
        bn.sid x4, 0(t2++)
        /* 6th WDR */
        loopi 16, 2
            bn.rshi w1, w0, w1 >> 16
            bn.rshi w0, bn0, w0 >> 10
        bn.and w1, w1, w2
        bn.sid x4, 0(t2++)
        /* 7th WDR */
        loopi 6, 2
            bn.rshi w1, w0, w1 >> 16
            bn.rshi w0, bn0, w0 >> 10
        bn.rshi w1, w0, w1 >> 4
        bn.lid  x0, 0(a1++)
        bn.rshi w1, w0, w1 >> 12
        bn.rshi w0, bn0, w0 >> 6
        loopi 9, 2
            bn.rshi w1, w0, w1 >> 16
            bn.rshi w0, bn0, w0 >> 10
        bn.and w1, w1, w2
        bn.sid x4, 0(t2++)
        /* 8th WDR */
        loopi 16, 2
            bn.rshi w1, w0, w1 >> 16
            bn.rshi w0, bn0, w0 >> 10
        bn.and w1, w1, w2
        bn.sid x4, 0(t2++)
    la   t0, du_kn4

_handle_common:
    addi a5, s0, 0 /* s0 = ptr_S */
    addi a6, s1, 0 /* s1 = ptr_E */
    /* Create the mask 0xFFFF. */
    li   t1, 1
    sub  t6, x0, t1
    srl  t6, t6, 16
    addi a1, sp, 0 /* a1 = ptr_c_decoded */
    /* Loop over all coeffs in pairs since we don't have 2B-aligned save. */
    loopi 128, 21
        /* Compute address of the corresponding S and E values. */
        lw   t1, 0(a1) /* t1 = c[i + 1] || c[i] */
        addi a1, a1, 4 /* Move to next word. */
        sll  t1, t1, 2 /* t1 *= 4 = (c[i + 1] * 4) || (c[i] * 4) */
        /* Handle c[i]. */
        and  t2, t1, t6 /* t2 = c[i] * 4 */
        add  t2, t0, t2 /* t2 = address of S(c[i]) and E(c[i]) */
        lw   t2, 0(t2) /* t2 = E(c[i]) || S(c[i]) */
        and  t3, t2, t6 /* t3 = S(c[i]) */
        srl  t4, t2, 16 /* t4 = E(c[i]) */
        /* Handle c[i + 1]. */
        srl  t1, t1, 16 /* t1 = c[i + 1] * 4 */
        add  t2, t0, t1 /* t2 = address of S(c[i + 1]) and E(c[i + 1]) */
        lw   t2, 0(t2) /* t2 = E(c[i + 1]) || S(c[i + 1]) */
        and  t5, t2, t6 /* t5 = S(c[i + 1]) */
        srl  t2, t2, 16 /* t2 = E(c[i + 1]) */
        /* Combine S(c[i + 1]) || S(c[i]). */
        sll  t5, t5, 16
        or   t3, t3, t5
        sw   t3, 0(a5) /* s0 = ptr_S */
        addi a5, a5, 4 /* Move to next word. */
        /* Combine E(c[i + 1]) || E(c[i]). */
        sll  t2, t2, 16
        or   t2, t2, t4
        sw   t2, 0(a6) /* s1 = ptr_E */
        addi a6, a6, 4 /* Move to next word. */

    /* Compute wa.shares[0] = (ca.shares[0] + 2048 - S) mod Q. Since S is stored
     * as (2048 - S) mod Q, we only need to compute (ca.shares[0] + S) mod Q.
     * Compute xa.shares[0] = (ca.shares[0] - E) mod Q. */
    addi t0, s2, 0 /* s2 = ptr_wb */
    addi t1, s3, 0 /* s3 = ptr_xb */
    li   x4, 1
    loopi N_WDR, 7
        bn.lid       x0, 0(a0++) /* w0 = ca.shares[0] */
        /* Handle S */
        bn.lid       x4, 0(s0++) /* Load S */
        bn.addvm.16h w1, w0, w1
        bn.sid       x4, 0(t0++) /* t0 = ptr_wa */
        /* Handle E */
        bn.lid       x4, 0(s1++) /* Load E */
        bn.subvm.16h w1, w0, w1
        bn.sid       x4, 0(t1++) /* t1 = ptr_xa */
    /* Copy the rest of ca to wa and xa. */
    addi t2, a3, -1
    loop t2, 5
        loopi N_WDR, 3
            bn.lid x0, 0(a0++)
            bn.sid x0, 0(t0++)
            bn.sid x0, 0(t1++)
        nop

    /* Compute wb = seca2bmodq_spog19(wa, nshares). */
    addi a0, s2, 0 /* s2 = ptr_wa */
    addi a1, a3, 0 /* a3 is still nshares. */
    addi a2, s2, 0 /* s2 = ptr_wb = ptr_wa */
    jal  x1, seca2bmodq_spog19

    /* Compute xb = seca2bmodq_spog19(xa, nshares). */
    lw   a0, 20(fp) /* s2 = ptr_xa */
    lw   a1, 8(fp) /* nshares */
    addi a2, a0, 0 /* s2 = ptr_xb = ptr_xa */
    jal  x1, seca2bmodq_spog19

    /* Extract msb of wb and xb and bitslicing them. */
    lw   a0, 16(fp) /* ptr_wb */
    lw   a2, 20(fp) /* ptr_xb */
    lw   t0, 12(fp) /* ptr_rb */
    /* We save bitslicing results of wb to ptr_rb, but of xb to
     * ptr_rb + nshares * 32B. */
    lw   a1, 8(fp) /* nshares */
    addi t1, t0, 0
    loop a1, 1
        addi t1, t1, 32

    li x4, 1
    li t2, 2
    loop a1, 14
        loopi N_WDR, 11
            /* Handle wb. */
            bn.lid     x0, 0(a0++)
            bn.shv.16H w0, w0 >> 11 /* Extract MSBs. */
            loopi N_COEFFS, 2
                bn.rshi w1, w0, w1 >> 1 /* Shift all the MSBs on w1. */
                bn.rshi w0, bn0, w0 >> 16 /* Shift out used coeff. */
            bn.lid     x0, 0(a2++)
            bn.shv.16H w0, w0 >> 11 /* Extract MSBs. */
            loopi N_COEFFS, 2
                bn.rshi w2, w0, w2 >> 1 /* Shift all the MSBs on w2. */
                bn.rshi w0, bn0, w0 >> 16 /* Shift out used coeff. */
            nop
        bn.sid x4, 0(t0++)
        bn.sid t2, 0(t1++)

    /* Restore registers. */
    lw s0, 4(fp)
    lw s1, 24(fp)
    lw s2, 28(fp)
    lw s3, 32(fp)

    /* Restore sp and fp. */
    addi sp, fp, 0
    lw   fp, 0(sp)
    addi sp, sp, 64
    ret


/*
 * Name: finalize_cmp_bc22 (inplace)
 *
 * Return Boolean shares of the comparison bit given output of masked_compare_bc22.
 * Bitsliced.
 *
 * Source: Described in Section 6.2 [BC22]
 *         [BC22]: "Bitslicing Arithmetic/Boolean Masking Conversions for Fun and Profit: with Application to Lattice-Based KEMs"
 *         Link: https://tches.iacr.org/index.php/TCHES/article/view/9831
 *
 * @param[in/out] x10: dptr_x, dmem pointer to Boolean shares of output of masked_compare_bc22
 * @param[in]     x11: nshares, the number of shares
 *
 * clobbered registers: x2 to x16, x18, x28 to x31, w0 to w8, w31
 * clobbered flag groups: FG0
 */
.globl finalize_cmp_bc22
finalize_cmp_bc22:
    /* Save fp to stack */
    addi sp, sp, -32
    sw   fp, 0(sp)
    addi fp, sp, 0

    /* Save registers. */
    sw s0, 4(fp)
    sw s1, 8(fp)

    /* Save input and output address. */
    addi s0, a0, 0
    addi s1, a1, 0

    /* Adjust stack space for temporary variable. */
    loop a1, 1
        addi sp, sp, -32

    /* All-zero register. */
    bn.xor bn0, bn0, bn0

    /* Compute x &= (x >> 128). */
    /* Compute t = x >> 128. */
    addi x4, x0, 1
    addi t0, sp, 0 /* ptr_t */
    loop s1, 5
        /* Whitening. */
        bn.xor  w0, w0, w0
        bn.xor  w1, w1, w1
        bn.lid  x0, 0(a0++)
        bn.rshi w1, bn0, w0 >> 128
        bn.sid  x4, 0(t0++)
    /* Compute x &= t. */
    addi a0, s0, 0
    addi a1, sp, 0
    addi a2, s1, 0
    addi a3, s0, 0
    addi a4, x0, 1
    addi a5, x0, 32
    jal  x1, secand_isw03

    /* Compute x &= (x >> 64). */
    /* Compute t = x >> 64. */
    addi x4, x0, 1
    addi a0, s0, 0
    addi t0, sp, 0 /* ptr_t */
    loop s1, 5
        /* Whitening. */
        bn.xor  w0, w0, w0
        bn.xor  w1, w1, w1
        bn.lid  x0, 0(a0++)
        bn.rshi w1, bn0, w0 >> 64
        bn.sid  x4, 0(t0++)
    /* Compute x &= t. */
    addi a0, s0, 0
    addi a1, sp, 0
    addi a2, s1, 0
    addi a3, s0, 0
    addi a4, x0, 1
    addi a5, x0, 32
    jal  x1, secand_isw03

    /* Compute x &= (x >> 32). */
    /* Compute t = x >> 32. */
    addi x4, x0, 1
    addi a0, s0, 0
    addi t0, sp, 0 /* ptr_t */
    loop s1, 5
        /* Whitening. */
        bn.xor  w0, w0, w0
        bn.xor  w1, w1, w1
        bn.lid  x0, 0(a0++)
        bn.rshi w1, bn0, w0 >> 32
        bn.sid  x4, 0(t0++)
    /* Compute x &= t. */
    addi a0, s0, 0
    addi a1, sp, 0
    addi a2, s1, 0
    addi a3, s0, 0
    addi a4, x0, 1
    addi a5, x0, 32
    jal  x1, secand_isw03

    /* Compute x &= (x >> 16). */
    /* Compute t = x >> 16. */
    addi x4, x0, 1
    addi a0, s0, 0
    addi t0, sp, 0 /* ptr_t */
    loop s1, 5
        /* Whitening. */
        bn.xor  w0, w0, w0
        bn.xor  w1, w1, w1
        bn.lid  x0, 0(a0++)
        bn.rshi w1, bn0, w0 >> 16
        bn.sid  x4, 0(t0++)
    /* Compute x &= t. */
    addi a0, s0, 0
    addi a1, sp, 0
    addi a2, s1, 0
    addi a3, s0, 0
    addi a4, x0, 1
    addi a5, x0, 32
    jal  x1, secand_isw03

    /* Compute x &= (x >> 8). */
    /* Compute t = x >> 8. */
    addi x4, x0, 1
    addi a0, s0, 0
    addi t0, sp, 0 /* ptr_t */
    loop s1, 5
        /* Whitening. */
        bn.xor  w0, w0, w0
        bn.xor  w1, w1, w1
        bn.lid  x0, 0(a0++)
        bn.rshi w1, bn0, w0 >> 8
        bn.sid  x4, 0(t0++)
    /* Compute x &= t. */
    addi a0, s0, 0
    addi a1, sp, 0
    addi a2, s1, 0
    addi a3, s0, 0
    addi a4, x0, 1
    addi a5, x0, 32
    jal  x1, secand_isw03

    /* Compute x &= (x >> 4). */
    /* Compute t = x >> 4. */
    addi x4, x0, 1
    addi a0, s0, 0
    addi t0, sp, 0 /* ptr_t */
    loop s1, 5
        /* Whitening. */
        bn.xor  w0, w0, w0
        bn.xor  w1, w1, w1
        bn.lid  x0, 0(a0++)
        bn.rshi w1, bn0, w0 >> 4
        bn.sid  x4, 0(t0++)
    /* Compute x &= t. */
    addi a0, s0, 0
    addi a1, sp, 0
    addi a2, s1, 0
    addi a3, s0, 0
    addi a4, x0, 1
    addi a5, x0, 32
    jal  x1, secand_isw03

    /* Compute x &= (x >> 2). */
    /* Compute t = x >> 2. */
    addi x4, x0, 1
    addi a0, s0, 0
    addi t0, sp, 0 /* ptr_t */
    loop s1, 5
        /* Whitening. */
        bn.xor  w0, w0, w0
        bn.xor  w1, w1, w1
        bn.lid  x0, 0(a0++)
        bn.rshi w1, bn0, w0 >> 2
        bn.sid  x4, 0(t0++)
    /* Compute x &= t. */
    addi a0, s0, 0
    addi a1, sp, 0
    addi a2, s1, 0
    addi a3, s0, 0
    addi a4, x0, 1
    addi a5, x0, 32
    jal  x1, secand_isw03

    /* Compute x &= (x >> 1). */
    /* Compute t = x >> 1. */
    addi x4, x0, 1
    addi a0, s0, 0
    addi t0, sp, 0 /* ptr_t */
    loop s1, 5
        /* Whitening. */
        bn.xor  w0, w0, w0
        bn.xor  w1, w1, w1
        bn.lid  x0, 0(a0++)
        bn.rshi w1, bn0, w0 >> 1
        bn.sid  x4, 0(t0++)
    /* Compute x &= t. */
    addi a0, s0, 0
    addi a1, sp, 0
    addi a2, s1, 0
    addi a3, s0, 0
    addi a4, x0, 1
    addi a5, x0, 32
    jal  x1, secand_isw03

    /* Restore registers. */
    lw s0, 4(fp)
    lw s1, 8(fp)

    /* Restore sp and fp. */
    addi sp, fp, 0
    lw   fp, 0(sp)
    addi sp, sp, 32
    ret
