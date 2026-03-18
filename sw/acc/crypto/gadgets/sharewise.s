/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/* This file contains all gadgets that can be applied sharewise. */
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

/* Functions */
.globl sharewise_xor
.globl sharewise_lsl
.globl sharewise_lsr
.globl sharewise_msb
.globl sharewise_bitext

/*
 * Name: sharewise_xor (NI)
 *
 * Given Boolean shares xb and yb of x and y, return (xb[i] ^ yb[i]).
 * Vectorized for polynomial.
 *
 * Flags: -
 *
 * @param[in]  x10: dptr_xb, dmem pointer to the 1st input Boolean shares
 * @param[in]  x11: dptr_yb, dmem pointer to the 2nd input Boolean shares
 * @param[in]  x12: nshares, the number of shares
 * @param[out] x13: dptr_rb, dmem pointer to the output Boolean shares
 *
 * clobbered registers: x4 to x5, x10 to x11, x13, w0 to w2
 * clobbered flag groups: FG0
 */
sharewise_xor:
    #define wx w0
    #define wy w1
    #define wr w2

    li x4, 1
    li t0, 2
    /* Go over i = 1,...,nshares */
    loop a2, 6
        /* Go over coeff batch. */
        loopi N_WDR, 4
            bn.lid x0, 0(a0++) /* wx = x[i] */
            bn.lid x4, 0(a1++) /* wy = y[i] */
            bn.xor wr, wx, wy /* wr = x[i] ^ y[i] */
            bn.sid x5, 0(a3++)
        nop
    ret

/*
 * Name: sharewise_lsl (NI)
 *
 * Given Boolean shares xb of a value x, and an integer s, return (xb[i] << s).
 * Vectorized for polynomial.
 *
 * Flags: -
 *
 * @param[in]  x10: dptr_xb, dmem pointer to the input Boolean shares
 * @param[in]  x11: s, the shift amount
 * @param[in]  x12: nshares, the number of shares
 * @param[out] x13: dptr_rb, dmem pointer to the output Boolean shares
 *
 * clobbered registers: x10, x13, w0
 * clobbered flag groups: none
 */
sharewise_lsl:
    /* Go over i = 1,...,nshares */
    loop a2, 6
        /* Go over coeff batch. */
        loopi N_WDR, 4
            bn.lid x0, 0(a0++) /* wx = x[i] */
            /* TODO: since we don't have a shift instruction that can shift an
             * arbitrary amount at runtime, we need to shift bit by bit. I feel
             * like this can reveal the HW of the MSB, and thus some of the top
             * bits after shifting is done. */
            loop a1, 1
            #if SCHEME == 0
                bn.shv.16H w0, w0 << 1
            #else
                bn.shv.8S  w0, w0 << 1
            #endif
            bn.sid x0, 0(a3++)
        nop
    ret

/*
 * Name: sharewise_lsr (NI)
 *
 * Given Boolean shares xb of a value x, and an integer s, return (xb[i] >> s).
 * Vectorized for polynomial.
 *
 * Flags: -
 *
 * @param[in]  x10: dptr_xb, dmem pointer to the input Boolean shares
 * @param[in]  x11: s, the shift amount
 * @param[in]  x12: nshares, the number of shares
 * @param[out] x13: dptr_rb, dmem pointer to the output Boolean shares
 *
 * clobbered registers: x10, x13, w0
 * clobbered flag groups: none
 */
sharewise_lsr:
    /* Go over i = 1,...,nshares */
    loop a2, 6
        /* Go over coeff batch. */
        loopi N_WDR, 4
            bn.lid x0, 0(a0++) /* wx = x[i] */
            /* TODO: since we don't have a shift instruction that can shift an
             * arbitrary amount at runtime, we need to shift bit by bit. I feel
             * like this can reveal the HW of the MSB, and thus some of the top
             * bits after shifting is done. */
            loop a1, 1
            #if SCHEME == 0
                bn.shv.16H w0, w0 >> 1
            #else
                bn.shv.8S  w0, w0 >> 1
            #endif
            bn.sid x0, 0(a3++)
        nop
    ret

/*
 * Name: sharewise_msb (NI)
 *
 * Given Boolean shares xb of a value x, and a bit size k, return MSB(xb[i]).
 * Since we are working primarily with ML-KEM and ML-DSA, we fix k = 12 and
 * k = 23 respectively.
 * Vectorized for polynomial.
 *
 * Flags: -
 *
 * @param[in]  x10: dptr_xb, dmem pointer to the input Boolean shares
 * @param[in]  x11: nshares, the number of shares
 * @param[out] x12: dptr_rb, dmem pointer to the output Boolean shares
 *
 * clobbered registers: x10, x12, w0 to w1, w31
 * clobbered flag groups: FG0
 */
sharewise_msb:
    /* Zeroize a WDR */
    bn.xor bn0, bn0, bn0

    /* Create the mask 1. */
    #define wmask w1
    bn.subi wmask, bn0, 1
    #if SCHEME == 0
    bn.shv.16H wmask, wmask >> 15
    #else
    bn.shv.8S  wmask, wmask >> 31
    #endif

    /* Go over i = 1,...,nshares */
    loop a1, 6
        /* Go over coeff batch. */
        loopi N_WDR, 4
            bn.lid     x0, 0(a0++) /* w0 = xb[i] */
            #if SCHEME == 0
            bn.shv.16H w0, w0 >> 11
            #else
            bn.shv.8S  w0, w0 >> 22
            #endif
            bn.and     w0, w0, wmask
            bn.sid     x0, 0(a2++)
        nop
    ret

/*
 * Name: sharewise_bitext (NI)
 *
 * Given Boolean shares of a bit xb, return (xb[i] & 1) repeated k times.
 * Vectorized for polynomial.
 *
 * Flags: -
 *
 * @param[in]  x10: dptr_xb, dmem pointer to the input Boolean shares
 * @param[in]  x11: nshares, the number of shares
 * @param[out] x12: dptr_rb, dmem pointer to the output Boolean shares
 *
 * clobbered registers: x10, x12, w0 to w2, w31
 * clobbered flag groups: FG0
 */
sharewise_bitext:
    /* Zeroize a WDR */
    bn.xor bn0, bn0, bn0

    /* Create the mask ((1 << N) - 1). */
    #define wmask w1
    bn.subi wmask, bn0, 1
    /* Create the mask 1 */
    #define wone w2
    #if SCHEME == 0
    bn.shv.16H wone, wmask >> 15
    #else
    bn.shv.8S  wone, wmask >> 31
    #endif

#if SCHEME == 0
    /* Go over i = 1,...,nshares */
    loop a1, 6
        /* Go over coeff batch. */
        loopi N_WDR, 4
            bn.lid              x0, 0(a0++) /* w0 = xb[i] */
            bn.and              w0, w0, wone /* w0 = xb[i] & 1 */
            bn.mulv.16H.lo      w0, w0, wmask
            bn.sid              x0, 0(a2++)
        nop
#else
    /* Go over i = 1,...,nshares */
    loop a1, 7
        /* Go over coeff batch. */
        loopi N_WDR, 5
            bn.lid              x0, 0(a0++) /* w0 = xb[i] */
            bn.and              w0, w0, wone /* w0 = xb[i] & 1 */
            bn.mulv.8S.even.lo  w0, w0, wmask
            bn.mulv.8S.odd.lo   w0, w0, wmask
            bn.sid              x0, 0(a2++)
        nop
#endif
    ret
