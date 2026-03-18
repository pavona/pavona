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
 * Name: secb2amodq_spog19 (SNI)
 *
 * Return arithmetic shares mod q of a value x given its Boolean shares mod 2**k.
 * Vectorized for polynomial.
 *
 * Source: Alg.9 [SPOG19]
 *         [SPOG19]: "Efficiently Masking Binomial Sampling at Arbitrary Orders for Lattice-Based Crypto"
 *         Link: https://eprint.iacr.org/2019/910
 *
 * Flags: -
 *
 * @param[in]  x10: dptr_xb, dmem pointer to the input arithmetic shares
 * @param[in]  x11: nshares, the number of shares
 * @param[in]  x12: k, the bit size of the Boolean shares
 * @param[in]  w31: all-zero
 * @param[out] x13: dptr_ra, dmem pointer to the output Boolean shares
 *
 * clobbered registers: x2 to x12, x14, x16 to x31, w0 to w3, w8, w10 to w14, w17, w30 to w31
 * clobbered flag groups: FG0
 */
.globl secb2amodq_spog19
secb2amodq_spog19:
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

    addi s0, a0, 0
    addi s1, a1, 0
    addi s2, a3, 0

    /* Adjust stack for temporary variables. */
    loop a1, 1
        addi sp, sp, -NB_POLY
    addi s3, sp, 0 /* ptr_a */
    loop a1, 1
        addi sp, sp, -NB_POLY /* ptr_b */

    /* All-zero register. */
    bn.xor bn0, bn0, bn0

    /* Create mask of 1s. */
    #define wmask w30
    bn.subi    wmask, bn0, 1
    #if SCHEME == 0
    bn.shv.16h wmask, wmask >> 15
    #else
    bn.shv.8s  wmask, wmask >> 31
    #endif

    /* Compute t = sharewise_lsr(xb, k - 1, nshares). */
    addi t0, s3, 0 /* ptr_a */
    addi s4, a2, -1 /* Start shifting by k - 1 bits. */
    loop a1, 7
        loopi N_WDR, 5
            bn.lid x0, 0(a0++)
            loop s4, 1
                #if SCHEME == 0
                bn.shv.16h w0, w0 >> 1
                #else
                bn.shv.8s  w0, w0 >> 1
                #endif
            bn.and w0, w0, wmask
            bn.sid x0, 0(t0++)
        nop

    /* Compute a = seconebitb2amodq_spog19_mlkem(a, nshares). */
    addi a0, s3, 0 /* ptr_a */
    /* a1 is still nshares. */
    addi a2, a0, 0 /* Output inplace. */
    jal  x1, seconebitb2amodq_spog19_mlkem

    addi a6, s4, -1 /* Now start shifting by (k - i) bits for i = 2,...,k. */
    addi s4, s4, -1
    /* Loop over i = 2,...,k-1 (k-2 iterations). */
    loop s4, 26
        addi a0, s0, 0
        addi t1, sp, 0 /* ptr_b */
        addi t0, t1, 0
        /* Compute b = sharewise_lsr(x, k - i, nshares). */
        loop a1, 7
            loopi N_WDR, 5
                bn.lid x0, 0(a0++)
                loop a6, 1
                    #if SCHEME == 0
                    bn.shv.16h w0, w0 >> 1
                    #else
                    bn.shv.8s  w0, w0 >> 1
                    #endif
                bn.and w0, w0, wmask
                bn.sid x0, 0(t0++)
            nop

        /* Compute b = seconebitb2amodq_spog19_mlkem(b, nshares). */
        addi a0, t1, 0 /* ptr_b */
        /* a1 is still nshares. */
        addi a2, a0, 0 /* Output inplace. */
        jal  x1, seconebitb2amodq_spog19_mlkem

        /* Compute a = (2*a + b) mod q. */
        addi t0, s3, 0 /* ptr_a */
        addi t1, sp, 0 /* ptr_b */
        addi x4, x0, 1
        loop a1, 7
            loopi N_WDR, 5
                bn.lid x0, 0(t0)
                bn.lid x4, 0(t1++)
                #if SCHEME == 0
                bn.addvm.16h w0, w0, w0
                bn.addvm.16h w0, w0, w1
                #else
                bn.addvm.8s w0, w0, w0
                bn.addvm.8s w0, w0, w1
                #endif
                bn.sid x0, 0(t0++)
            nop

        /* Adjust shift amount. */
        addi a6, a6, -1

    /* The last iteration is handled separately since the shift amount is 0,
     * causing LOOP error. */
    addi a0, s0, 0
    addi t1, sp, 0 /* ptr_b */
    addi t0, t1, 0
    /* Compute b = sharewise_lsr(x, 0, nshares). */
    loop a1, 5
        loopi N_WDR, 3
            bn.lid x0, 0(a0++)
            bn.and w0, w0, wmask
            bn.sid x0, 0(t0++)
        nop

    /* Compute b = seconebitb2amodq_spog19_mlkem(b, nshares). */
    addi a0, t1, 0 /* ptr_b */
    /* a1 is still nshares. */
    addi a2, a0, 0 /* Output inplace. */
    jal  x1, seconebitb2amodq_spog19_mlkem

    /* Compute a = (2*a + b) mod q. */
    addi t0, s3, 0 /* ptr_a */
    addi t1, sp, 0 /* ptr_b */
    addi t2, s2, 0 /* ptr_r */
    addi x4, x0, 1
    loop a1, 7
        loopi N_WDR, 5
            bn.lid x0, 0(t0++)
            bn.lid x4, 0(t1++)
            #if SCHEME == 0
            bn.addvm.16h w0, w0, w0
            bn.addvm.16h w0, w0, w1
            #else
            bn.addvm.8s w0, w0, w0
            bn.addvm.8s w0, w0, w1
            #endif
            bn.sid x0, 0(t2++)
        nop

    /* Restore registers. */
    lw s0, 4(fp)
    lw s1, 8(fp)
    lw s2, 12(fp)
    lw s3, 16(fp)
    lw s4, 20(fp)

    /* Restore sp and fp. */
    addi  sp, fp, 0
    lw    fp, 0(sp)
    addi  sp, sp, 32
    ret
