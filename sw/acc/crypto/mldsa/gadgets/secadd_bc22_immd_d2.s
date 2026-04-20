/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

.equ x0, zero
.equ x1, ra
.equ x2, sp
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
.equ x28, t3
.equ x29, t4
.equ x30, t5
.equ x31, t6

.equ w31, bn0

/*
 * Name: secadd_bc22_immd_d2 (PINI, d = 2)
 *
 * Inline d=2 SecAdd of x with a public k-bit constant in w17 lane 0.
 *
 * @param[in]  x10: dptr_x, k * 2 * 32 B
 * @param[in]  x12: k, bitsize
 * @param[in]  x13: share stride (= k * 32)
 * @param[in]  x14: nshares (must be 2)
 * @param[out] x15: dptr_z, k * 2 * 32 B
 * @param[in]  w17: lane-0 holds the constant
 * @param[in]  w31: all-zero
 *
 * clobbered registers: x5 to x7, x10 to x16, x28 to x31, w0 to w19
 * clobbered flag groups: FG0
 */
.globl secadd_bc22_immd_d2
secadd_bc22_immd_d2:
    add  t4, a0, a3                /* t4 = x share 1 ptr */
    add  t5, a5, a3                /* t5 = z share 1 ptr */

    bn.not w19, w31                /* wONES */
    bn.xor w18, w18, w18
    bn.addi w18, w18, 1            /* wMASK = lane-0 bit 0 */

    bn.xor w12, w12, w12           /* c_0 = 0 */
    bn.xor w13, w13, w13           /* c_1 = 0 */

    li   t0, 1                     /* x_0 -> w1 */
    li   t1, 2                     /* x_1 -> w2 */
    li   t2, 10                    /* r_0 idx (= w10) */
    li   t3, 11                    /* r_1 idx (= w11) */

    addi t6, a2, 0
    loop t6, 39
        /* Derive y_bit. */
        bn.and w0, w17, w18
        bn.cmp w0, w31
        bn.sel w3, w31, w19, FG0.Z
        bn.rshi w17, w31, w17 >> 1

        /* Share 0: a_0 = x_0 ^ y_bit, t_0 = x_0 ^ c_0, r_0 = c_0 ^ a_0. */
        bn.xor w1, w1, w1
        bn.lid t0, 0(a0)
        bn.xor w4, w1, w3
        bn.xor w6, w1, w12
        bn.xor w10, w12, w4
        bn.sid t2, 0(a5)

        /* Inter-share whitening. */
        bn.xor w0, w0, w0

        /* Share 1: a_1 = x_1, t_1 = x_1 ^ c_1, r_1 = c_1 ^ a_1. */
        bn.xor w2, w2, w2
        bn.lid t1, 0(t4)
        bn.mov w5, w2
        bn.xor w7, w2, w13
        bn.xor w11, w13, w5
        bn.sid t3, 0(t5)

        /* SecAnd(a_0,a_1; t_0,t_1) -> (u_0, u_1). */
        bn.wsrr w14, urnd
        bn.xor w16, w7, w14
        bn.and w16, w16, w4
        bn.not w15, w4
        bn.and w15, w15, w14
        bn.xor w15, w15, w16
        bn.and w8, w4, w6
        bn.xor w8, w8, w15

        bn.xor w0, w0, w0

        bn.xor w16, w6, w14
        bn.and w16, w16, w5
        bn.not w15, w5
        bn.and w15, w15, w14
        bn.xor w15, w15, w16
        bn.and w9, w5, w7
        bn.xor w9, w9, w15

        /* New carry: c = x ^ u. */
        bn.xor w12, w1, w8
        bn.xor w13, w2, w9

        /* Advance pointers. */
        addi a0, a0, 32
        addi t4, t4, 32
        addi a5, a5, 32
        addi t5, t5, 32

    ret
