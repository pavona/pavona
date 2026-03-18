/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

#define N 256 /* Number of coefficients in a polynomial. */

#ifndef NSHARES
    #define NSHARES 2
#endif

/* We define the number of bytes that a polynomial occupies only for ML-KEM for
 * for now. We can generalize this for ML-DSA if these gadgets are needed. */
#ifndef SCHEME
    #define SCHEME 0 /* 0: ML-KEM, 1: ML-DSA. */
#endif

#if SCHEME == 0
    #define NB_POLY 512 /* Number of bytes occupied by a polynomial */
    #define N_WDR 16 /* Number of WDRs to store N coeffs */
    #define BITSIZE 16 /* Register bit size */
    #define N_COEFFS 16 /* Number of coeffs fitting in a WDR */
    #define W 4 /* ceil(log2(k - 1)), k = 16 */
    #define Wm1 3 /* W - 1 */
#else
    #define NB_POLY 1024 /* Number of bytes occupied by a polynomial */
    #define N_WDR 32 /* Number of WDRs to store N coeffs */
    #define BITSIZE 32 /* Regiter bit size */
    #define N_COEFFS 8 /* Number of coeffs fitting in a WDR */
    #define W 5 /* ceil(log2(k - 1)), k = 32 */
    #define Wm1 4 /* W - 1 */
#endif

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
 * Name: secadd_cgtv15 (SNI)
 *
 * Return Boolean shares of a value r = (x + y) mod 2^k, for k is the register
 * bit size in this case.
 * Vectorized for polynomial.
 *
 * Source: Alg.6 [CGTV15]
 *         [CGTV15]: "Conversion from Arithmetic to Boolean Masking with Logarithmic Complexity"
 *         Link: http://link.springer.com/10.1007/978-3-662-48116-5_7
 *
 * Note: The algorithm is also provided in [BBE+18] (Alg.9). This implementation
 *       follows Alg.11 of [BBE+18].
 *       [BBE+18]: "Masking the GLP Lattice-Based Signature Scheme at Any Order"
 *       Link: https://eprint.iacr.org/2018/381.pdf
 *       We assume that the bit size of the masks is always 16.
 *
 * Flags: -
 *
 * @param[in]  x10: dptr_xb, dmem pointer to the input Boolean shares
 * @param[in]  x11: dptr_yb, dmem pointer to the input Boolean shares
 * @param[in]  x12: nshares, the number of shares
 * @param[out] x13: dptr_rb, dmem pointer to the output Boolean shares
 *
 * clobbered registers: x2 to x16, x18 to x26, x28 to x31, w0 to w8
 * clobbered flag groups: FG0
 */
.globl secadd_cgtv15
secadd_cgtv15:
    /* Save fp to stack */
    addi sp, sp, -32
    sw   fp, 0(sp)
    addi fp, sp, 0

    /* Save registers. */
    sw s0, 4(fp)
    sw s1, 8(fp)
    sw s2, 12(fp)
    sw s3, 16(fp)
    sw s4, 20(fp)
    sw s5, 24(fp)
    sw s6, 28(fp)

    /* Adjust sp to accommodate temporary variables depending on nshares. */
    loop a2, 1
        addi sp, sp, -NB_POLY
    addi s4, sp, 0
    loop a2, 1
        addi sp, sp, -NB_POLY
    addi s5, sp, 0
    loop a2, 1
        addi sp, sp, -NB_POLY

    addi s0, a0, 0
    addi s1, a1, 0
    addi s2, a2, 0
    addi s3, a3, 0

    /* Compute pb = sharewise_xor(xb, yb, nshares). */
    /* a0 already points to xb. */
    /* a1 already points to yb. */
    /* a2 is already nshares. */
    addi a3, s4, 0 /* s4 = ptr_pb */
    jal  x1, sharewise_xor

    /* Compute gb = secand_isw03(xb, yb, nshares). */
    addi a0, s0, 0 /* s0 = ptr_xb */
    addi a1, s1, 0 /* s1 = ptr_yb */
    /* a2 is already nshares. */
    addi a3, s5, 0 /* s5 = ptr_gb */
    addi a4, x0, N_WDR
    addi a5, x0, NB_POLY
    jal  x1, secand_isw03

    /* Because we also need xb ^ yb at the end of this function, we copy pb to
     * rb to prevent compute this again. */
    addi a0, s3, 0 /* s3 = ptr_rb */
    addi a1, s4, 0 /* s4 = ptr_pb */
    /* a2 is still nshares after sharewise_xor. */
    loop a2, 4
        loopi N_WDR, 2
            bn.lid x0, 0(a1++)
            bn.sid x0, 0(a0++)
        nop

    li s6, 1 /* s6 = p = 1,...,2**(W-2) */
    /* Loop i = 1,...,W-1 */
    loopi Wm1, 30
        /* Compute ab = sharewise_lsl(gb, p, nshares). */
        addi a0, s5, 0 /* s5 = ptr_gb */
        addi a1, s6, 0
        /* a2 is already nshares. */
        addi a3, sp, 0 /* sp = ptr_ab */
        jal  x1, sharewise_lsl

        /* Compute ab = secand_isw03(ab, pb, nshares). */
        addi a0, sp, 0 /* sp = ptr_ab */
        addi a1, s4, 0 /* s4 = ptr_pb */
        /* a2 is already nshares. */
        addi a3, sp, 0 /* sp = ptr_ab */
        addi a4, x0, N_WDR
        addi a5, x0, NB_POLY
        jal  x1, secand_isw03

        /* Compute gb = sharewise_xor(gb, ab, nshares). */
        addi a0, s5, 0 /* s5 = ptr_gb */
        addi a1, sp, 0 /* sp = ptr_ab */
        /* a2 is already nshares. */
        addi a3, s5, 0 /* s5 = ptr_gb */
        jal  x1, sharewise_xor

        /* Compute aprimeb = sharewise_lsl(pb, p, nshares). We store to ab.*/
        addi a0, s4, 0 /* s4 = ptr_pb */
        addi a1, s6, 0
        /* a2 is already nshares. */
        addi a3, sp, 0 /* s7 = ptr_ab */
        jal  x1, sharewise_lsl

        /* Compute ab = refresh_bbd16(ab, nshares) where ab = aprimeb. */
        addi a0, sp, 0 /* s7 = ptr_ab */
        addi a1, s2, 0 /* s2 = nshares */
        addi a2, sp, 0 /* s7 = ptr_ab */
        jal  x1, refresh_bbd16

        /* Compute pb = secand_isw03(pb, ab, nshares). */
        addi a0, s4, 0 /* s4 = ptr_pb */
        addi a1, sp, 0 /* s7 = ptr_ab */
        addi a2, s2, 0 /* s2 = nshares */
        addi a3, s4, 0 /* s4 = ptr_pb */
        addi a4, x0, N_WDR
        addi a5, x0, NB_POLY
        jal  x1, secand_isw03

        /* Adjust shift amount. */
        sll s6, s6, 1
    /* End loop. */

    /* Compute ab = sharewise_lsl(gb, 1 << (W - 1), nshares). */
    addi a0, s5, 0 /* s5 = ptr_gb */
    addi a1, s6, 0 /* s6 = 1 << (W - 1) after the loop */
    /* a2 is already nshares. */
    addi a3, sp, 0 /* sp = ptr_ab */
    jal  x1, sharewise_lsl

    /* Compute ab = secand_isw03(ab, pb, nshares). */
    addi a0, sp, 0 /* sp = ptr_ab */
    addi a1, s4, 0 /* s4 = ptr_pb */
    /* a2 is already nshares. */
    addi a3, sp, 0 /* sp = ptr_ab */
    addi a4, x0, N_WDR
    addi a5, x0, NB_POLY
    jal  x1, secand_isw03

    /* Compute gb = sharewise_xor(gb, ab, nshares). */
    addi a0, s5, 0 /* s5 = ptr_gb */
    addi a1, sp, 0 /* sp = ptr_ab */
    /* a2 is already nshares. */
    addi a3, s5, 0 /* s5 = ptr_gb */
    jal  x1, sharewise_xor

    /* Compute pb = sharewise_lsl(gb, 1, nshares). Store the result temporarily
     * in pb. */
    addi a0, s5, 0 /* s5 = ptr_gb */
    addi a1, x0, 1
    /* a2 is already nshares. */
    addi a3, s4, 0 /* s4 = ptr_pb */
    jal  x1, sharewise_lsl

    /* Compute rb = sharewise_xor(rb, pb, nshares), where rb = xb ^ yb. */
    addi a0, s3, 0 /* s3 = ptr_rb */
    addi a1, s4, 0 /* s4 = ptr_pb */
    /* a2 is already nshares. */
    addi a3, s3, 0 /* s3 = ptr_rb */
    jal  x1, sharewise_xor

    /* Restore registers. */
    lw s0, 4(fp)
    lw s1, 8(fp)
    lw s2, 12(fp)
    lw s3, 16(fp)
    lw s4, 20(fp)
    lw s5, 24(fp)
    lw s6, 28(fp)

    /* Restore sp and fp. */
    addi       sp, fp, 0
    lw         fp, 0(sp)
    addi       sp, sp, 32
    ret
