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
    #define BITSIZEm1 15 /* BITSIZE - 1 */
    #define N_COEFFS 16 /* Number of coeffs fitting in a WDR */
    #define W 4 /* ceil(log2(k - 1)), k = 16 */
    #define Wm1 3 /* W - 1 */
#else
    #define NB_POLY 1024 /* Number of bytes occupied by a polynomial */
    #define N_WDR 32 /* Number of WDRs to store N coeffs */
    #define BITSIZE 32 /* Regiter bit size */
    #define BITSIZEm1 31 /* BITSIZE - 1 */
    #define N_COEFFS 8 /* Number of coeffs fitting in a WDR */
    #define W 5 /* ceil(log2(k - 1)), k = 32 */
    #define Wm1 4 /* W - 1 */
#endif

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
 * Name: secaddmodq_bbe18 (NI)
 *
 * Return Boolean shares of a value r = (x + y) mod q, for q is an arbitrary modulus.
 * Vectorized for polynomial.
 *
 * Source: Alg.10 [BBE+18]
 *         [BBE+18]: "Masking the GLP Lattice-Based Signature Scheme at Any Order"
 *         Link: https://eprint.iacr.org/2018/381.pdf
 *
 * Flags: -
 *
 * @param[in]  x10: dptr_xb, dmem pointer to the input Boolean shares
 * @param[in]  x11: dptr_yb, dmem pointer to the input Boolean shares
 * @param[in]  x12: nshares, the number of shares
 * @param[out] x13: dptr_rb, dmem pointer to the output Boolean shares
 *
 * clobbered registers: x2 to x16, x18 to x26, x28 to x31, w0 to w8, w31
 * clobbered flag groups: FG0
 */
.globl secaddmodq_bbe18
secaddmodq_bbe18:
    /* Save fp to stack */
    addi sp, sp, -32
    sw   fp, 0(sp)
    addi fp, sp, 0

    /* Save registers. */
    sw s0, 4(fp)
    sw s1, 8(fp)
    sw s2, 12(fp)
    sw s3, 16(fp)

    addi s2, a2, 0
    addi s3, a3, 0

    /* Adjust sp to accommodate temporary variables depending on nshares. */
    loop a2, 1
        addi sp, sp, -NB_POLY
    addi s0, sp, 0 /* ptr_sb */
    loop a2, 1
        addi sp, sp, -NB_POLY
    addi s1, sp, 0 /* ptr_bb */
    loop a2, 1
        addi sp, sp, -NB_POLY

    /* Compute sb = secadd_cgtv15(xb, yb, nshares). */
    /* a0 already points to xb. */
    /* a1 already points to yb. */
    /* a2 is already nshares. */
    addi a3, s0, 0 /* ptr_sb */
    jal  x1, secadd_cgtv15
    /* After this, xb and yb are not used anymore. So in case input and output
     * to secaddmodq_bbe18 are the same, over-writing rb will not cause problem. */

    /* Compute qb = [2**k - q, 0, ..., 0]. We save to rb.*/
    bn.xor  bn0, bn0, bn0
    la      t0, modulus_bn
    bn.lid  x0, 0(t0)
    #if SCHEME == 0
    bn.subv.16H w0, bn0, w0
    #else
    bn.subv.8S  w0, bn0, w0
    #endif
    addi t0, s3, 0 /* ptr_rb */
    loopi N_WDR, 1
        bn.sid x0, 0(t0++)
    addi t1, a2, -1
    li   x4, 31
    loop t1, 3
        loopi N_WDR, 1
            bn.sid x4, 0(t0++)
        nop

    /* Compute sprimeb = secadd_cgtv15(sb, qb, nshares) where qb is stored in rb
     * and rb will hold sprimeb. */
    addi a0, s0, 0 /* ptr_sb */
    addi a1, s3, 0 /* ptr_rb */
    /* a2 is still nshares. */
    addi a3, s3, 0 /* ptr_rb */
    jal  x1, secadd_cgtv15

    /* Compute bb = sharewise_lsr(sprimeb, k-1, nshares) for k = 16 or 32,
     * sprimeb is stored in rb. */
    addi a0, s3, 0 /* s3 = ptr_rb */
    addi a1, x0, BITSIZEm1
    /* a2 is still nshares. */
    addi a3, s1, 0 /* s1 = ptr_bb */
    jal  x1, sharewise_lsr

    /* Compute cb = refresh_bbd16(bb, nshares). */
    addi a0, s1, 0 /* s1 = ptr_bb */
    addi a1, a2, 0 /* a2 is still nshares. */
    addi a2, sp, 0 /* sp = ptr_cb */
    jal  x1, refresh_bbd16

    /* Compute cb = sharewise_bitext(cb, nshares). */
    addi a0, sp, 0 /* sp = ptr_cb */
    /* a1 is still nshares. */
    addi a2, sp, 0 /* sp = ptr_cb */
    jal  x1, sharewise_bitext

    /* Compute zb = secand_isw03(sb, cb, nshares). We store the result to sb
     * since sb is not used anymore. */
    addi a0, s0, 0 /* s0 = ptr_sb */
    addi a1, sp, 0 /* sp = ptr_cb */
    addi a2, s2, 0 /* s2 = nshares. */
    addi a3, s0, 0 /* s0 = ptr_sb */
    addi a4, x0, N_WDR
    addi a5, x0, NB_POLY
    jal  x1, secand_isw03

    /* Compute cb = refresh_bbd16(bb, nshares). */
    addi a0, s1, 0 /* s1 = ptr_bb */
    addi a1, a2, 0 /* a2 is still nshares. */
    addi a2, sp, 0 /* sp = ptr_cb */
    jal  x1, refresh_bbd16

    /* Compute cb = ~cb (meaning ~cb[0] only). */
    addi a0, sp, 0 /* sp = ptr_cb */
    loopi N_WDR, 3
        bn.lid x0, 0(a0)
        bn.not w0, w0
        bn.sid x0, 0(a0++)

    /* Compute cb = sharewise_bitext(cb, nshares). */
    addi a0, sp, 0 /* sp = ptr_cb */
    /* a1 is still nshares. */
    addi a2, sp, 0 /* sp = ptr_cb */
    jal  x1, sharewise_bitext

    /* Compute tb = secand_isw03(sprimeb, cb, nshares) where sprimeb is stored
     * in rb. We save to cb. */
    addi a0, s3, 0 /* s3 = ptr_rb */
    addi a1, sp, 0 /* sp = ptr_cb */
    addi a2, s2, 0 /* s2 = nshares */
    addi a3, sp, 0 /* sp = ptr_cb */
    addi a4, x0, N_WDR
    addi a5, x0, NB_POLY
    jal  x1, secand_isw03

    /* Compute rb = sharewise_xor(zb, tb) where zb is in sb and tb in cb. */
    addi a0, s0, 0 /* s0 = ptr_sb */
    addi a1, sp, 0 /* sp = ptr_cb */
    /* a2 is still nshares. */
    addi a3, s3, 0 /* s3 = ptr_rb */
    jal  x1, sharewise_xor

    /* Restore registers. */
    lw s0, 4(fp)
    lw s1, 8(fp)
    lw s2, 12(fp)
    lw s3, 16(fp)

    /* Restore sp and fp. */
    addi sp, fp, 0
    lw   fp, 0(sp)
    addi sp, sp, 32
    ret
