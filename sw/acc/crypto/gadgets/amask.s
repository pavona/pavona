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
 * Name: amask
 *
 * Return arithmetic shares of an unmasked value x.
 * Vectorized for polynomial.
 *
 * Flags: -
 *
 * @param[in]  x10: dptr_x, dmem pointer to the input unmasked value
 * @param[in]  x11: nshares, the number of shares
 * @param[out] x12: dptr_r, dmem pointer to the output arithmetic shares
 *
 * clobbered registers: x2 to x7, x10, x14, x18, x20 to x21, x29 to x31, w0 to w1, w8, w10 to w14, w17, w31
 * clobbered flag groups: FG0
 */
.globl amask
amask:
    /* Save input address. */
    addi t4, a0, 0
    addi t5, a1, 0
    addi t5, t5, -1 /* t5 = nshares - 1 */
    addi t6, a2, 0

    /* Generate (nshares - 1) random shares. */
    addi a0, a2, 0
    loop t5, 2
        jal x1, poly_rej_samp
        nop

    /* Compute r[nshares - 1] = x - (r[1] + ... + r[nshares - 2]) mod Q. */
    addi x4, x0, 1
    addi a0, t4, 0
    loopi N_WDR, 8
        addi   t0, t6, 0
        bn.lid x0, 0(a0++)
        loop t5, 3
            bn.lid       x4, 0(t6)
            addi         t6, t6, NB_POLY
            bn.subvm.16h w0, w0, w1
        bn.sid x0, 0(t6)
        addi   t6, t0, 32
    ret
