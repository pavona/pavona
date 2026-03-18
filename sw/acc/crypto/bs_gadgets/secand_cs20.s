/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

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
 * Name: secand_cs20 (PINI)
 *
 * Return new Boolean shares of a value r = x & y.
 * Bitsliced.
 *
 * Source: Alg.2 in [CS20]
 *         [CS20]: "Trivially and Efficiently Composing Masked Gadgets With Probe Isolating Non-Interference"
 *         Link: https://ieeexplore.ieee.org/document/8979162/
 *
 * @param[in]  x10: dptr_xb, dmem pointer to Boolean shares of x
 * @param[in]  x11: share stride, distance between shares of x
 * @param[in]  x12: dptr_yb, dmem pointer to Boolean shares of y
 * @param[in]  x13: share stride, distance between shares of y
 * @param[in]  x14: nshares, the number of shares
 * @param[out] x15: dptr_rb, dmem pointer to Boolean shares of r
 * @param[in]  x16: share stride, distance between shares of r
 *
 * clobbered registers: x2 to x10, x12, x15, x18, x28 to x31, w0 to w8
 * clobbered flag groups: FG0
 */
.globl secand_cs20
secand_cs20:
#if NSHARES == 2
    /* Save addresses. */
    addi t0, a0, 0
    addi t1, a2, 0
    addi t2, a5, 0

    /* Load x. */
    bn.xor w0, w0, w0
    bn.lid x0, 0(t0) /* x[0] */
    bn.xor w1, w1, w1
    add    t0, t0, a1
    addi   x4, x0, 1
    bn.lid x4++, 0(t0) /* x[1] */

    /* Load y. */
    bn.xor w2, w2, w2
    bn.lid x4++, 0(t1)
    bn.xor w3, w3, w3 /* y[1] */
    add    t1, t1, a3
    bn.lid x4, 0(t1) /* y[0] */

    /* PINI */
    addi    x4, x0, 6
    bn.wsrr w5, urnd
    /* Handle z_01. */
    bn.xor  w6, w6, w6
    bn.and  w6, w0, w2 /* x[0] & y[0] */
    bn.xor  w7, w7, w7
    bn.xor  w7, w3, w5 /* y[1] ^ r */
    bn.and  w7, w0, w7 /* &= x[0] */
    bn.xor  w8, w8, w8
    bn.not  w8, w0 /* x[0] ^ 1 */
    bn.and  w8, w8, w5 /* &= r */
    bn.xor  w7, w7, w8 /* w7 ^= 8 */
    bn.xor  w6, w6, w7
    bn.sid  x4, 0(t2) /* Save r[0]. */
    add     t2, t2, a6
    /* Handle z_10. */
    bn.xor  w6, w6, w6
    bn.and  w6, w1, w3 /* x[1] & y[1] */
    bn.xor  w7, w7, w7
    bn.xor  w7, w2, w5 /* y[0] ^ r */
    bn.and  w7, w1, w7 /* &= x[1] */
    bn.xor  w8, w8, w8
    bn.not  w8, w1 /* xb[1] ^ 1 */
    bn.and  w8, w8, w5 /* &= r */
    bn.xor  w7, w7, w8 /* w7 ^= w8 */
    bn.xor  w6, w6, w7
    bn.sid  x4, 0(t2) /* Save r[0]. */

    /* We want a0, a2, a6 to point to next bit. */
    addi a0, a0, 32
    addi a2, a2, 32
    addi a5, a5, 32
    ret
#else
    /* Save fp to stack */
    addi sp, sp, -32
    sw   fp, 0(sp)
    addi fp, sp, 0

    /* Save registers. */
    sw  s0, 4(fp)
    sw  s1, 8(fp)
    sw  s2, 12(fp)

    /* Adjust sp to accommodate temporary variable tb. */
    loop a4, 1
        add sp, sp, -32 /* ptr_tb */

    /* Save input addresses. */
    addi t0, sp, 0
    addi x4, x0, 1
    addi t1, x0, 2
    addi t2, a0, 0 /* ptr_x */
    addi t3, a2, 0 /* ptr_y */
    /* Compute tb[i] = xb[i] & yb[i]. */
    loop a4, 9
        /* Whitening since we're accessing other shares in subsequent iterations. */
        bn.xor w0, w0, w0
        bn.xor w1, w1, w1
        bn.xor w2, w2, w2
        bn.lid x0, 0(t2)
        bn.lid x4, 0(t3)
        bn.and w2, w0, w1
        bn.sid t1, 0(t0++)
        add    t2, t2, a1
        add    t3, t3, a3

    #define wzij w0
    #define wzji w5
    #define wtmp0 w6
    #define wtmp1 w7
    #define wr w8
    addi s0, a0, 0
    addi s1, a2, 0
    /* Compute the number of iterations of the outer loop: the last share is not counted. */
    addi t0, a4, -1
    /* Compute the number of iterations of the inner loop: the first share is not counted. */
    addi t2, a4, -1
    /* Compute address of tb. */
    addi t4, sp, 0
    /* Outer loop i = 1,...,nshares-1 */
    loop t0, 39
        /* Whitening since we're accessing other shares in subsequent iterations. */
        bn.xor w0, w0, w0
        bn.xor w1, w1, w1
        bn.xor w2, w2, w2
        /* Load data. */
        bn.lid x0, 0(t4) /* w0 = tb[i] */
        bn.lid x4, 0(s0) /* w1 = xb[i] */
        bn.lid t1, 0(s1) /* w2 = yb[i] */
        /* Point to next share. */
        add s0, s0, a1
        add s1, s1, a3
        add t5, s0, 0
        add t6, s1, 0
        add s2, t4, 32
        /* Inner loop j = i + 1,...,nshares. */
        loop t2, 24
            addi    t3, x0, 3
            bn.wsrr wr, urnd
            /* Whitening since we're accessing other shares in subsequent iterations. */
            bn.xor  w3, w3, w3
            bn.xor  w4, w4, w4
            bn.xor  wzji, wzji, wzji
            /* PINI */
            bn.lid  t3++, 0(t5) /* w3 = xb[j] */
            bn.lid  t3++, 0(t6) /* w4 = yb[j] */
            /* Handle wzij. */
            bn.xor  wtmp1, w4, wr /* wtmp1 = yb[j] ^ r */
            bn.and  wtmp1, w1, wtmp1 /* wtmp1 &= xb[i] */
            bn.not  wtmp0, w1 /* wtmp0 = xb[i] ^ 1 */
            bn.and  wtmp0, wtmp0, wr /* wtmp0 &= r */
            bn.xor  wtmp0, wtmp0, wtmp1 /* wtmp0 ^= wtmp1 */
            bn.xor  wzij, wzij, wtmp0
            /* Handle wzji. */
            bn.lid  t3, 0(s2) /* w5 = tb[j] */
            bn.xor  wtmp1, w2, wr /* wtmp1 = yb[i] ^ r */
            bn.and  wtmp1, w3, wtmp1 /* wtmp1 &= xb[j] */
            bn.not  wtmp0, w3 /* wtmp0 = xb[j] ^ 1 */
            bn.and  wtmp0, wtmp0, wr /* wtmp0 &= r */
            bn.xor  wtmp0, wtmp0, wtmp1 /* wtmp0 ^= wtmp1 */
            bn.xor  wzji, wzji, wtmp0
            bn.sid  t3, 0(s2) /* Save tb[j]. */
            /* Adjust addresses. */
            add     t5, t5, a1
            add     t6, t6, a3
            add     s2, s2, 32
        bn.sid x0, 0(t4) /* Save tb[i]. */
        add    t4, t4, 32
        /* Adjust inner loop according as outer loop moves on. We're safe here
         * since j can never be 0: i will move (nshares - 2) steps forward,
         * and j moves (nshares - 2) steps backward, meaning the minimum
         * value of j is (nshares - 1) - (nshares - 2) = 1. */
        addi t2, t2, -1

    /* Copy tb to rb. */
    addi t0, sp, 0
    addi t1, a5, 0
    loop a4, 5
        /* Whitening since we're accessing other shares in subsequent iterations. */
        bn.xor w0, w0, w0
        bn.lid x0, 0(t0++)
        bn.sid x0, 0(t1)
        add    t1, t1, a6

    /* We want a0, a2, a6 to point to next bit. */
    addi a0, a0, 32
    addi a2, a2, 32
    addi a5, a5, 32

    /* Restore registers. */
    lw s0, 4(fp)
    lw s1, 8(fp)
    lw s2, 12(fp)

    /* Restore sp and fp. */
    addi sp, fp, 0
    lw   fp, 0(sp)
    addi sp, sp, 32
    ret
#endif /* NSHARES == 2 */
