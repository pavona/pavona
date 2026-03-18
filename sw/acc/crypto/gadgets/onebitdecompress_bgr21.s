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
 * Name: onebitdecompress_bgr21 (??)
 *
 * Given Boolean shares of the 32B message m, return arithmetic shares of mp = Decompressq(m,1).
 * This function is specific to ML-KEM.
 * Vectorized for polynomial.
 *
 * Source: Described in Section 3.3 in [BGR+21]
 *         [BGR+21]: "Masking Kyber: First- and Higher-Order Implementations"
 *         Link: https://tches.iacr.org/index.php/TCHES/article/view/9064
 *
 * Flags: -
 *
 * @param[in]  x10: dptr_m, dmem pointer to the input Boolean shares (in bislice form)
 * @param[in]  x11: nshares, the number of shares
 * @param[out] x12: dptr_mp, dmem pointer to the output arithmetic shares
 *
 * clobbered registers: x2 to x12, x14, x18 to x31, w0 to w3, w8, w10 to w14, w16 to w17, w30 to w31, acc, acch
 * clobbered flag groups: FG0
 */
.globl onebitdecompress_bgr21
onebitdecompress_bgr21:
    /* Save fp to stack */
    addi sp, sp, -32
    sw   fp, 0(sp)
    addi fp, sp, 0

    /* Save output address to stack. */
    sw a2, 4(fp)

    /* Adjust stack for unpacking bitsliced input m. */
    loop a1, 1
        addi sp, sp, -NB_POLY
    addi t0, sp, 0 /* ptr_m */

    /* All-zero register. */
    bn.xor bn0, bn0, bn0

    /* Create 1-bit mask. */
    #define wmask w2
    bn.subi    wmask, bn0, 1
    bn.shv.16h wmask, wmask >> 15

    /* Unpack the bitsliced input m. */
    addi x4, x0, 1
    loop a1, 8
        bn.lid x0, 0(a0++)
        loopi N_WDR, 5
            loopi N_COEFFS, 2
                bn.rshi w1, w0, w1 >> 16
                bn.rshi w0, bn0, w0 >> 1
            bn.and w1, w1, wmask
            bn.sid x4, 0(t0++)
        nop

    /* Compute mp = seconebitb2amodq_spog19_mlkem(m, nshares). */
    addi a0, sp, 0 /* ptr_m */
    /* a1 is still nshares. */
    /* a2 already points to ptr_mp. */
    jal  x1, seconebitb2amodq_spog19_mlkem

    /* Compute mp = sharewise_mul(mp, Q//2). */
    bn.wsrr w16, MOD /* Prepare the modulus for Montgomery multiplication. */
    la      t0, modulus_over_2_m2_16 /* ((Q + 1) / 2) * (2^16) % Q. */
    addi    x4, x0, 1
    bn.lid  x4, 0(t0)
    lw      t0, 4(fp) /* ptr_mp */
    loop a1, 8
        loopi N_WDR, 6
            bn.lid               x0, 0(t0)
            bn.mulv.16H.acc.z.lo w0, w0, w1
            bn.mulv.l.16H.lo     w0, w0, sw0.2
            bn.mulv.l.16H.acc.hi w0, w0, sw0.0
            bn.addvm.16H         w0, w0, bn0
            bn.sid               x0, 0(t0++)
        nop

    /* Restore sp and fp. */
    addi sp, fp, 0
    lw   fp, 0(sp)
    addi sp, sp, 32
    ret
