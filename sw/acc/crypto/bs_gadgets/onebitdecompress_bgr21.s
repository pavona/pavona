/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

#ifndef NSHARES
    #define NSHARES 2
#endif

#define NB_POLY 512 /* Number of bytes occupied by a polynomial */
#define N_WDR 16 /* Number of WDRs to store N coeffs */
#define N_COEFFS 16 /* Number of coeffs fitting in a WDR */

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
 * Name: onebitdecompress_bgr21 (SNI)
 *
 * Given Boolean shares of the 32B message m, return arithmetic shares
 * mod q = 3329 of mp = Decompressq(m,1).
 * Vectorized for polynomial.
 *
 * Source: Described in Section 3.3 in [BGR+21]
 *         [BGR+21]: "Masking Kyber: First- and Higher-Order Implementations"
 *         Link: https://tches.iacr.org/index.php/TCHES/article/view/9064
 *
 * Note: This is also Alg.16 in [BC22]
 *       [BC22]: "Bitslicing Arithmetic/Boolean Masking Conversions for Fun and Profit: with Application to Lattice-Based KEMs"
 *       Link: https://tches.iacr.org/index.php/TCHES/article/view/9831
 *
 * @param[in]  w16: R | Q
 * @param[in]  x10: dptr_m, dmem pointer to Boolean shares of m (bitsliced)
 * @param[in]  x11: nshares, the number of shares
 * @param[out] x12: dptr_mp, dmem pointer to arithmetic shares of r
 *
 * clobbered registers: TODO
 * clobbered flags: TODO
 */
.globl onebitdecompress_bgr21
onebitdecompress_bgr21:
    /* Save fp to stack */
    addi sp, sp, -32
    sw   fp, 0(sp)
    addi fp, sp, 0

    /* Save output address to stack. */
    sw   s0, 4(fp)
    addi s0, a2, 0

    /* All-zero register. */
    bn.xor bn0, bn0, bn0

    /* Create 1-bit mask. */
    #define wmask w2
    bn.subi    wmask, bn0, 1
    bn.shv.16h wmask, wmask << 15

    /* Unpack the bitsliced input m, matching the bitslice transform in masked_poly_tomsg. */
    addi x4, x0, 1
    loop a1, 7
        bn.lid x0, 0(a0++)
        loopi N_WDR, 4
            bn.and     w1, w0, wmask
            bn.shv.16h w0, w0 << 1
            bn.shv.16h w1, w1 >> 15
            bn.sid     x4, 0(a2++)
        nop

    /* Compute mp = seconebitb2amodq_spog19_mlkem(m, nshares). */
    /* w16 = R | Q */
    addi a0, s0, 0 /* ptr_m */
    /* a1 is still nshares. */
    addi a2, s0, 0 /* ptr_r */
    jal  x1, seconebitb2amodq_spog19_mlkem

    /* Compute mp = sharewise_mul(mp, Q//2). */
    /* w16 is still R | Q. */
    la      t0, modulus_over_2_m2_16 /* ((Q + 1) / 2) * (2^16) % Q. */
    addi    x4, x0, 1
    bn.lid  x4, 0(t0)
    bn.xor  bn0, bn0, bn0
    loop a1, 8
        loopi N_WDR, 6
            bn.lid               x0, 0(s0)
            bn.mulv.16H.acc.z.lo w0, w0, w1
            bn.mulv.l.16H.lo     w0, w0, sw0.2
            bn.mulv.l.16H.acc.hi w0, w0, sw0.0
            bn.addvm.16H         w0, w0, bn0
            bn.sid               x0, 0(s0++)
        nop

    /* Restore a2. */
    lw s0, 4(fp)

    /* Restore sp and fp. */
    addi sp, fp, 0
    lw   fp, 0(sp)
    addi sp, sp, 32
    ret
