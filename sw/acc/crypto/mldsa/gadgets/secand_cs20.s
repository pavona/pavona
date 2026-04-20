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
 * @param[in]  x10: dptr_xb, dmem pointer to the input Boolean shares of x
 * @param[in]  x11: share stride, distance between shares of x
 * @param[in]  x12: dptr_yb, dmem pointer to the input Boolean shares of y
 * @param[in]  x13: share stride, distance between shares of y
 * @param[in]  x14: nshares, the number of shares
 * @param[in]  x15: output_share_str, distance between shares of the output
 * @param[out] x16: dptr_rb, dmem pointer to the output Boolean shares of r
 *
 * clobbered registers: x2 to x10, x12, x16, x18 to x19, x28 to x31, w0 to w8
 * clobbered flag groups: FG0
 */
.globl secand_cs20
secand_cs20:
    /* Save fp to stack */
    addi sp, sp, -32
    sw   fp, 0(sp)
    addi fp, sp, 0

    /* Save registers. */
    sw  s0, 4(fp)
    sw  s1, 8(fp)
    sw  s2, 12(fp)
    sw  s3, 16(fp)
    addi s0, a0, 0
    addi s1, a2, 0
    addi s2, a6, 0

    /* Adjust sp to accommodate temporary variable tb. */
    loop a4, 1
        add sp, sp, -32 /* ptr_tb */

    /* Save input addresses. */
    addi t0, sp, 0
    addi x4, x0, 1
    addi t1, x0, 2
    /* Compute tb[i] = xb[i] & yb[i]. */
    loop a4, 9
        /* Whitening since we're accessing other shares in subsequent iterations. */
        bn.xor w0, w0, w0
        bn.xor w1, w1, w1
        bn.xor w2, w2, w2
        bn.lid x0, 0(a0)
        bn.lid x4, 0(a2)
        bn.and w2, w0, w1
        bn.sid t1, 0(t0++)
        add    a0, a0, a1
        add    a2, a2, a3

    #define wzij w0
    #define wzji w5
    #define wtmp0 w6
    #define wtmp1 w7
    #define wr w8
    addi a0, s0, 0
    addi a2, s1, 0
    /* Compute the number of iterations of the outer loop: the last share is not counted. */
    addi t0, a4, -1
    /* Compute the number of iterations of the inner loop: the first share is not counted. */
    addi t2, a4, -1
    /* Compute address of tb. */
    addi t4, sp, 0
    /* Outer loop i = 1,...,nshares-1 */
    loop t0, 41
        /* Whitening since we're accessing other shares in subsequent iterations. */
        bn.xor w0, w0, w0
        bn.xor w1, w1, w1
        bn.xor w2, w2, w2
        /* Load data. */
        bn.lid x0, 0(t4) /* w0 = tb[i] */
        bn.lid x4, 0(a0) /* w1 = xb[i] */
        bn.lid t1, 0(a2) /* w2 = yb[i] */
        /* Point to next share. */
        add a0, a0, a1
        add a2, a2, a3
        add t5, a0, 0
        add t6, a2, 0
        add s3, t4, 32
        /* Inner loop j = i + 1,...,nshares. */
        loop t2, 26
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
            /* Whitening. */
            bn.xor  wtmp1, wtmp1, wtmp1
            bn.xor  wtmp0, wtmp0, wtmp0
            /* Handle wzji. */
            bn.lid  t3, 0(s3) /* w5 = tb[j] */
            bn.xor  wtmp1, w2, wr /* wtmp1 = yb[i] ^ r */
            bn.and  wtmp1, w3, wtmp1 /* wtmp1 &= xb[j] */
            bn.not  wtmp0, w3 /* wtmp0 = xb[j] ^ 1 */
            bn.and  wtmp0, wtmp0, wr /* wtmp0 &= r */
            bn.xor  wtmp0, wtmp0, wtmp1 /* wtmp0 ^= wtmp1 */
            bn.xor  wzji, wzji, wtmp0
            bn.sid  t3, 0(s3) /* Save tb[j]. */
            /* Adjust addresses. */
            add     t5, t5, a1
            add     t6, t6, a3
            add     s3, s3, 32
        bn.sid x0, 0(t4) /* Save tb[i]. */
        add    t4, t4, 32
        /* Adjust inner loop according as outer loop moves on. We're safe here
         * since j can never be 0: i will move (nshares - 2) steps forward,
         * and j moves (nshares - 2) steps backward, meaning the minimum
         * value of j is (nshares - 1) - (nshares - 2) = 1. */
        addi t2, t2, -1

    /* Copy tb to rb. */
    addi t0, sp, 0
    addi t1, s2, 0
    loop a4, 5
        /* Whitening since we're accessing other shares in subsequent iterations. */
        bn.xor w0, w0, w0
        bn.lid x0, 0(t0++)
        bn.sid x0, 0(t1)
        add    t1, t1, a5

    /* We want a0, a2, a6 to point to next bit. */
    addi a0, s0, 32
    addi a2, s1, 32
    addi a6, s2, 32

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
