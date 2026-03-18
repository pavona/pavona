/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

#define N 256 /* Number of coefficients in a polynomial. */

#ifndef NSHARES
    #define NSHARES 2
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
 * Name: secsampler1_spog19 (SNI)
 *
 * Return arithmetic shares mod q of (HW(x) - HW(y)) mod q, given the Boolean
 * shares mod 2**k of x and y.
 * Vectorized for polynomial.
 *
 * Source: Alg.10 [SPOG19]
 *         [SPOG19]: "Efficiently Masking Binomial Sampling at Arbitrary Orders for Lattice-Based Crypto"
 *         Link: https://eprint.iacr.org/2019/910
 *
 * Flags: -
 *
 * @param[in]  x10: dptr_xb, dmem pointer to the input Boolean shares
 * @param[in]  x11: dptr_yb, dmem pointer to the input Boolean shares
 * @param[in]  x12: k, the bit size of the Boolean shares
 * @param[in]  x13: nshares, the number of shares
 * @param[in]  w31: all-zero
 * @param[out] x14: dptr_ra, dmem pointer to the output arithmetic shares
 *
 * clobbered registers: x2 to x12, x14, x16 to x31, w0 to w3, w8, w10 to w14, w17, w30 to w31
 * clobbered flag groups: FG0
 */
.globl secsampler1_spog19
secsampler1_spog19:
    /* Save fp to stack */
    addi sp, sp, -32
    sw   fp, 0(sp)
    addi fp, sp, 0

    /* Adjust stack for temporary variables. */
    loop a3, 1
        addi sp, sp, -NB_POLY
    sw sp, 4(fp) /* ptr_a */
    loop a3, 1
        addi sp, sp, -NB_POLY /* ptr_b */

    /* Save input and output pointers. */
    sw   a0, 12(fp)
    sw   a1, 16(fp)
    sw   a4, 20(fp)
    addi a5, a3, 0 /* Save nshares to a5. */
    addi a7, a2, -1 /* Save k - 1 to a7. */

    /* Create mask of 1s. */
    #define wmask w30
    bn.subi    wmask, bn0, 1
    #if SCHEME == 0
    bn.shv.16h wmask, wmask >> 15
    #else
    bn.shv.8s  wmask, wmask >> 31
    #endif

    /* We separate first iteration so we don't have zeroize a and compute (a+-b) mod q. */
    /* First iteration i = 0. */
    /* Compute b = x & 1. */
    addi t0, sp, 0 /* ptr_b */
    loop a5, 5
        loopi N_WDR, 3
            bn.lid x0, 0(a0++) /* a0 is already ptr_xb. */
            bn.and w0, w0, wmask
            bn.sid x0, 0(t0++)
        nop

    /* Compute b = seconebitb2amodq_spog19_mlkem(b, nshares). */
    addi a0, sp, 0 /* ptr_b */
    addi a1, a5, 0 /* a5 = nshares. */
    lw   a2, 4(fp) /* ptr_a */
    jal  x1, seconebitb2amodq_spog19_mlkem

    /* Compute b = y & 1. */
    addi t0, sp, 0 /* ptr_b */
    lw   t1, 16(fp) /* ptr_yb */
    loop a3, 5
        loopi N_WDR, 3
            bn.lid x0, 0(t1++)
            bn.and w0, w0, wmask
            bn.sid x0, 0(t0++)
        nop

    /* Compute b = seconebitb2amodq_spog19_mlkem(b, nshares). */
    addi a0, sp, 0 /* ptr_b */
    addi a1, a5, 0 /* a5 = nshares */
    addi a2, a0, 0 /* Output inplace. */
    jal  x1, seconebitb2amodq_spog19_mlkem

    /* Compute a = (a - b) mod q. */
    lw   t0, 4(fp) /* ptr_a */
    addi t1, sp, 0 /* ptr_b */
    addi x4, x0, 1
    loop a5, 6
        loopi N_WDR, 4
            bn.lid       x0, 0(t0)
            bn.lid       x4, 0(t1++)
            bn.subvm.16h w0, w0, w1
            bn.sid       x0, 0(t0++)
        nop

    addi a6, x0, 1 /* Now start shifting by i bits for i = 1,...,k - 1. */
    /* Loop over i = 1,...,k - 1 (k - 1 iterations). */
    loop a7, 49
        /* Compute b = (x >> i) & 1. */
        lw   t0, 12(fp) /* ptr_xb */
        addi t1, sp, 0 /* ptr_b */
        loop a5, 7
            loopi N_WDR, 5
                bn.lid x0, 0(t0++)
                loop a6, 1
                    bn.shv.16h w0, w0 >> 1
                bn.and w0, w0, wmask
                bn.sid x0, 0(t1++)
            nop

        /* Compute b = seconebitb2amodq_spog19_mlkem(b, nshares). */
        addi a0, sp, 0 /* ptr_b */
        addi a1, a5, 0 /* a5 = nshares */
        addi a2, a0, 0 /* Output inplace. */
        jal  x1, seconebitb2amodq_spog19_mlkem

        /* Compute a = (a + b) mod q. */
        lw   t0, 4(fp) /* ptr_a */
        addi t1, sp, 0 /* ptr_b */
        addi x4, x0, 1
        loop a1, 6
            loopi N_WDR, 4
                bn.lid x0, 0(t0)
                bn.lid x4, 0(t1++)
                bn.addvm.16h w0, w0, w1
                bn.sid x0, 0(t0++)
            nop

        /* Compute b = (y >> i) & 1. */
        lw   t0, 16(fp) /* ptr_yb */
        addi t1, sp, 0 /* ptr_b */
        loop a5, 7
            loopi N_WDR, 5
                bn.lid x0, 0(t0++)
                loop a6, 1
                    bn.shv.16h w0, w0 >> 1
                bn.and w0, w0, wmask
                bn.sid x0, 0(t1++)
            nop

        /* Compute b = seconebitb2amodq_spog19_mlkem(b, nshares). */
        addi a0, sp, 0 /* ptr_b */
        addi a1, a5, 0 /* a5 = nshares */
        addi a2, a0, 0 /* Output inplace. */
        jal  x1, seconebitb2amodq_spog19_mlkem

        /* Compute a = (a - b) mod q. */
        lw   t0, 4(fp) /* ptr_a */
        addi t1, sp, 0 /* ptr_b */
        addi x4, x0, 1
        loop a1, 6
            loopi N_WDR, 4
                bn.lid x0, 0(t0)
                bn.lid x4, 0(t1++)
                bn.subvm.16h w0, w0, w1
                bn.sid x0, 0(t0++)
            nop

        /* Adjust shift amount. */
        addi a6, a6, 1

    /* Copy a to the output. */
    lw   t0, 4(fp) /* ptr_a */
    lw   t1, 20(fp) /* ptr_ra */
    addi a4, t1, 0 /* Restore output address. */
    loop a5, 4
        loopi N_WDR, 2
            bn.lid x0, 0(t0++)
            bn.sid x0, 0(t1++)
        nop

    /* Restore sp and fp. */
    addi       sp, fp, 0
    lw         fp, 0(sp)
    addi       sp, sp, 32
    ret
