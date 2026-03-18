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
 * Name: secand_isw03 (SNI)
 *
 * Return new Boolean shares of a value r = x ^ y.
 * Vectorized for polynomial.
 *
 * Source: Described in [ISW03]
 *         [ISW03]: "Private Circuits: Securing Hardware against Probing Attacks"
 *         Link: https://link.springer.com/chapter/10.1007/978-3-540-45146-4_27
 *
 * Note: The algorithm is also provided in [CGV14] (Alg.1), [SPOG19] (Alg.18)
 *       and [BBE+18] (Alg.11). This implementation follows Alg.11 of [BBE+18].
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
 * @param[in]  x14: number of coeff batches
 * @param[in]  x15: share stride
 *
 * clobbered registers: x2 to x11, x13 to x16, x19, x28 to x30, w0 to w8
 * clobbered flag groups: FG0
 */
.globl secand_isw03
secand_isw03:
    /* Save fp to stack */
    addi sp, sp, -32
    sw   fp, 0(sp)
    addi fp, sp, 0

    /* Save registers. */
    sw s0, 4(fp)
    sw s1, 8(fp)
    sw s2, 12(fp)

    /* Adjust sp to accommodate temporary variable tb. */
    loop a2, 1
        sub sp, sp, a5

    li x4, 1
    li t2, 2
    /* Save input addresses. */
    addi t0, a0, 0
    addi t1, a1, 0
    addi t3, sp, 0
    /* Compute tb[i] = xb[i] & yb[i]. */
    loop a2, 6
        loop a4, 4
            bn.lid x0, 0(t0++)
            bn.lid x4, 0(t1++)
            bn.and w2, w0, w1
            bn.sid t2, 0(t3++)
        nop

    #define wtmp w6
    #define wzij w7
    #define wzji w8
    addi t6, sp, 0
    /* Compute the number of iterations of the outer loop: the last share is not counted. */
    addi s2, a2, -1
    /* Go over all coeffs of a polynomial. */
    loop a4, 42
        /* Save data pointers. */
        addi s0, a0, 0
        addi s1, a1, 0
        addi t5, t6, 0
        /* Compute the number of iterations of the inner loop: the first share is not counted. */
        addi t4, s2, 0
        /* Outer loop i = 1,...,nshares-1 */
        loop s2, 34
            addi   x4, x0, 1
            /* Whitening since we're accessing other shares in subsequent iterations. */
            bn.xor w0, w0, w0
            bn.xor w1, w1, w1
            bn.xor w2, w2, w2
            bn.lid x0, 0(t6) /* w0 = tb[i] */
            bn.lid x4++, 0(a0) /* w1 = xb[i] */
            bn.lid x4++, 0(a1) /* w2 = yb[i] */
            /* Point to next share. */
            add t0, a0, a5
            add t1, a1, a5
            add t2, t6, a5
            /* Inner loop j = i + 1,...,nshares. */
            loop t4, 18
                bn.wsrr wzij, urnd
                /* Whitening since we're accessing other shares in subsequent iterations. */
                bn.xor  w3, w3, w3
                bn.xor  w4, w4, w4
                bn.xor  w5, w5, w5
                addi    t3, x0, 3
                bn.lid  t3++, 0(t0) /* w3 = xb[j] */
                bn.lid  t3++, 0(t1) /* w4 = yb[j] */
                bn.and  wtmp, w1, w4 /* wtmp = xb[i] & yb[j] */
                bn.xor  wzji, wtmp, wzij /* wzij = (xb[i] & yb[j]) ^ rand */
                bn.and  wtmp, w3, w2 /* wtmp = xb[j] & yb[i] */
                bn.xor  wzji, wzji, wtmp /* wzji ^= (xb[j] & yb[i]) */
                bn.lid  t3, 0(t2) /* w5 = tb[j] */
                bn.xor  w0, w0, wzij /* w0 = tb[i] ^ wzij */
                bn.xor  w5, w5, wzji /* w5 = tb[j] ^ wzji */
                bn.sid  t3, 0(t2) /* Save tb[j]. */
                /* Point to next share. */
                add t0, t0, a5
                add t1, t1, a5
                add t2, t2, a5
            bn.sid x0, 0(t6) /* Save tb[i]. */
            /* Point to next share. */
            add a0, a0, a5
            add a1, a1, a5
            add t6, t6, a5
            /* Adjust inner loop according as outer loop moves on. We're safe here
             * since j can never be 0: i will move (nshares - 2) steps forward,
             * and j moves (nshares - 2) steps backward, meaning the minimum
             * value of j is (nshares - 1) - (nshares - 2) = 1. */
            addi t4, t4, -1
        /* Move to next batch of coeffs. */
        addi a0, s0, 32
        addi a1, s1, 32
        addi t6, t5, 32

    /* Copy tb to rb. */
    addi t0, sp, 0
    loop a2, 4
        loop a4, 2
            bn.lid x0, 0(t0++)
            bn.sid x0, 0(a3++)
        nop

    /* Restore registers. */
    lw s0, 4(fp)
    lw s1, 8(fp)
    lw s2, 12(fp)

    /* Restore sp and fp. */
    addi sp, fp, 0
    lw   fp, 0(sp)
    addi sp, sp, 32
    ret
