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
 * Name: seca2bmodq_spog19 (SNI)
 *
 * Return Boolean shares mod 2**k of a value x given its arithmetic shares mod q,
 * for q is an arbitrary modulus such that 2**k > 2q.
 * Vectorized for polynomial.
 *
 * Source: Alg.3 [SPOG19]
 *         [SPOG19]: "Efficiently Masking Binomial Sampling at Arbitrary Orders for Lattice-Based Crypto"
 *         Link: https://eprint.iacr.org/2019/910
 *
 * Flags: -
 *
 * @param[in]  x10: dptr_xa, dmem pointer to the input Boolean shares
 * @param[in]  x11: nshares, the number of shares
 * @param[in]  w31: all-zero
 * @param[out] x12: dptr_rb, dmem pointer to the output arithmetic shares
 *
 * clobbered registers: x2 to x16, x18 to x26, x28 to x31, w0 to w8, w31
 * clobbered flag groups: FG0
 */
.globl seca2bmodq_spog19
seca2bmodq_spog19:
    /* Save fp to stack */
    addi sp, sp, -32
    sw   fp, 0(sp)
    addi fp, sp, 0

    /* Save input and output pointers. */
    sw a0, 4(fp)
    sw a1, 8(fp)
    sw a2, 12(fp)

    /* If nshares > 1, continue. Else, return. */
    li  x4, 1
    beq a1, x4, _handle_one_share

    /* Compute number of shares for each recursive call. */
    srl t0, a1, 1 /* t0 = nshares // 2 */
    sw  t0, 16(fp)
    sub t1, a1, t0 /* t1 = nshares - (nshares // 2) */
    sw  t1, 20(fp)

    /*** A2B for the first half. ***/
    /* Adjust sp to accommodate temporary values of recursive calls. */
    loop a1, 1
        addi sp, sp, -NB_POLY
    sw sp, 24(fp) /* ptr_yb */

    /* Compute yb = seca2bmodq_spog19(xa[0],...,xa[nshares // 2], nshares // 2). */
    /* a0 = ptr_xa */
    lw  a1, 16(fp)
    lw  a2, 24(fp) /* ptr_yb */
    jal x1, seca2bmodq_spog19

    /* Zeroize yb[nshares // 2 + 1]...yb[nshares]. */
    lw  t0, 24(fp) /* ptr_yb */
    lw  t1, 16(fp) /* t1 = nshares // 2 */
    /* Point t0 to yb[nshares // 2 + 1]. */
    loop t1, 1
        addi t0, t0, NB_POLY
    lw t1, 20(fp) /* t1 = nshares - (nshares // 2) */
    li x4, 31
    loop t1, 3
        loopi N_WDR, 1
            bn.sid x4, 0(t0++)
        nop

    /* Compute yb = refresh_bbd16(yb, nshares). */
    lw  a0, 24(fp) /* ptr_yb */
    lw  a1, 8(fp) /* a1 = nshares */
    lw  a2, 24(fp) /* ptr_yb */
    jal x1, refresh_bbd16

    /*** A2B for the second half. ***/
    lw a0, 4(fp) /* ptr_xa */
    lw t0, 16(fp) /* t0 = nshares // 2 */
    /* Point a0 to xa[nshares // 2 + 1]. */
    loop t0, 1
        addi a0, a0, NB_POLY
    /* a1 is still nshares. */
    /* Adjust sp to accommodate temporary values of recursive calls. */
    loop a1, 1
        addi sp, sp, -NB_POLY
    addi a2, sp, 0 /* ptr_zb */
    lw   a1, 20(fp) /* a1 = nshares - (nshares // 2) */
    jal  x1, seca2bmodq_spog19

    /* Zeroize zb[nshares - (nshares // 2) + 1]...zb[nshares]. */
    addi t0, sp, 0 /* ptr_zb */
    lw   t1, 20(fp) /* t1 = nshares - (nshares // 2) */
    /* Point t0 to zb[nshares - (nshares // 2) + 1]. */
    loop t1, 1
        addi t0, t0, NB_POLY
    lw t1, 16(fp) /* t1 = (nshares // 2) */
    li x4, 31
    loop t1, 3
        loopi N_WDR, 1
            bn.sid x4, 0(t0++)
        nop

    /* Compute zb = refresh_bbd16(zb, nshares). */
    addi a0, sp, 0 /* ptr_zb */
    lw   a1, 8(fp) /* a1 = nshares */
    addi a2, sp, 0 /* ptr_zb */
    jal  x1, refresh_bbd16

    /* Compute rb = secaddmodq_bbe18(yb, zb, nshares). */
    lw   a0, 24(fp) /* ptr_yb */
    addi a1, sp, 0 /* ptr_zb */
    lw   a2, 8(fp) /* nshares */
    lw   a3, 12(fp) /* ptr_rb */
    jal  x1, secaddmodq_bbe18
    beq  x0, x0, _end

_handle_one_share:
    /* a0 = ptr_xa. */
    /* a2 = ptr_rb. */
    loopi N_WDR, 2
        bn.lid x0, 0(a0++)
        bn.sid x0, 0(a2++)

_end:
    /* Restore sp and fp. */
    addi       sp, fp, 0
    lw         fp, 0(sp)
    addi       sp, sp, 32
    ret
