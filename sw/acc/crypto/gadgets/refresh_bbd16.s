/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

#define N 256 /* Number of coefficients in a polynomial. */

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
#else
    #define NB_POLY 1024 /* Number of bytes occupied by a polynomial */
    #define N_WDR 32 /* Number of WDRs to store N coeffs */
    #define BITSIZE 32 /* Regiter bit size */
    #define N_COEFFS 8 /* Number of coeffs fitting in a WDR */
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
 * Name: refresh_bbd16 (SNI)
 *
 * Return new Boolean shares of a value x, given its Boolean shares.
 * Vectorized for polynomial.
 *
 * Source: Gadget.4b [BBD+16]
 *         [BBD+16]: "Strong Non-Interference and Type-Directed Higher-Order Masking"
 *         Link: https://eprint.iacr.org/2015/506
 *
 * Note: The algorithm is also provided in [SPOG19] (Alg.20) and [BBE+18] (Alg.8).
 *       This implementation follows Alg.8 of [BBE+18].
 *       [BBE+18]: "Masking the GLP Lattice-Based Signature Scheme at Any Order"
 *       Link: https://eprint.iacr.org/2018/381.pdf
 *       We assume that the bit size of the masks is always 16.
 *
 * Flags: -
 *
 * @param[in]  x10: dptr_xb, dmem pointer to the input Boolean shares
 * @param[in]  x11: nshares, the number of shares
 * @param[out] x12: dptr_rb, dmem pointer to the output Boolean shares
 *
 * clobbered registers: x4 to x8, x10, x12, w0 to w2
 * clobbered flag groups: FG0
 */
.globl refresh_bbd16
refresh_bbd16:
    /* A masked polynomial contains of nshares polynomials, storing subsequently
     * in the memory. */
    #define wrand w2

    /* Save output address */
    addi t2, a2, 0
    /* Create a copy of the input in the output space. Later on, we only work
     * with this copy. It is fine because we don't access shares of a value
     * consecutively. */
    loop a1, 4
        loopi N_WDR, 2
            bn.lid x0, 0(a0++)
            bn.sid x0, 0(t2++)
        nop

    li x4, 1
    /* Go over all coeffs of a polynomial. */
    loopi N_WDR, 17
        /* Compute the number of iterations of the outer loop: the last share is not counted. */
        addi t0, a1, -1
        /* Compute the number of iterations of the inner loop: the first share is not counted. */
        addi t1, a1, -1
        addi t3, a2, 0 /* Save output pointer. */
        /* Outer loop i = 1,...,nshares-1 */
        loop t0, 12
            bn.lid x0, 0(a2) /* w0 = rb[i] */
            /* Point t2 to next share. */
            addi t2, a2, NB_POLY
            /* Inner loop j = i + 1,...,nshares */
            loop t1, 6
                bn.wsrr wrand, urnd
                bn.xor w0, w0, wrand /* w0 ^= wrand */
                bn.lid x4, 0(t2) /* w1 = rb[j] */
                bn.xor w1, w1, wrand /* w1 ^= wrand */
                bn.sid x4, 0(t2)
                /* Update t2 to point to next share. */
                addi t2, t2, NB_POLY
            bn.sid x0, 0(a2)
            /* Point a2 to next share. */
            addi a2, a2, NB_POLY
            /* Adjust inner loop according as outer loop moves on. We're safe here
             * since j can never be 0: i will move (nshares - 2) steps forward,
             * and j moves (nshares - 2) steps backward, meaning the minimum
             * value of j is (nshares - 1) - (nshares - 2) = 1. */
            addi t1, t1, -1
        /* Increment output address after refreshing the first batch of coeffs. */
        addi a2, t3, 32
    ret
