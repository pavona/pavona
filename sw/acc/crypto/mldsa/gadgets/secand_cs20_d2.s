/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

/* Register aliases */
.equ x0, zero
.equ x4, tp
.equ x5, t0
.equ x6, t1
.equ x7, t2
.equ x10, a0
.equ x11, a1
.equ x12, a2
.equ x13, a3
.equ x14, a4
.equ x15, a5
.equ x16, a6
.equ x28, t3
.equ x29, t4
.equ x30, t5
.equ x31, t6

/*
 * Name: secand_cs20 (PINI, d=2 only)
 *
 * Return new Boolean shares of a value r = x & y.
 * Bitsliced.
 *
 * d=2 specialization of secand_cs20.s: hand-unrolled, no stack frame,
 * tb[] kept in WDRs.  nshares (a4) is ignored.  Unlike the generic
 * secand_cs20, a0/a2/a6 are not advanced on return.
 *
 * Source: Alg.2 in [CS20]
 *         [CS20]: "Trivially and Efficiently Composing Masked Gadgets With Probe Isolating Non-Interference"
 *         Link: https://ieeexplore.ieee.org/document/8979162/
 *
 * @param[in]  x10: dptr_xb, dmem pointer to the input Boolean shares of x
 * @param[in]  x11: share stride, distance between shares of x
 * @param[in]  x12: dptr_yb, dmem pointer to the input Boolean shares of y
 * @param[in]  x13: share stride, distance between shares of y
 * @param[in]  x14: nshares (ignored, fixed to 2)
 * @param[in]  x15: output_share_str, distance between shares of the output
 * @param[out] x16: dptr_rb, dmem pointer to the output Boolean shares of r
 *
 * clobbered registers: x4, x5, x6, x7, x28 to x30, w0 to w8
 * clobbered flag groups: FG0
 */
.globl secand_cs20
secand_cs20:
    addi x4, x0, 1
    addi t0, x0, 2
    addi t1, x0, 3
    addi t2, x0, 4
    addi t3, x0, 5
    addi t4, x0, 6

    /* Compute tb[0] = xb[0] & yb[0]. */
    /* Whitening since we're accessing other shares in subsequent steps. */
    bn.xor w1, w1, w1
    bn.xor w3, w3, w3
    bn.xor w5, w5, w5
    bn.lid x4, 0(a0)                /* w1 = xb[0] */
    bn.lid t1, 0(a2)                /* w3 = yb[0] */
    bn.and w5, w1, w3               /* w5 = tb[0] */

    /* Compute tb[1] = xb[1] & yb[1]. */
    /* Whitening since we're accessing other shares in subsequent steps. */
    bn.xor w2, w2, w2
    bn.xor w4, w4, w4
    bn.xor w6, w6, w6
    add    t5, a0, a1
    bn.lid t0, 0(t5)                /* w2 = xb[1] */
    add    t5, a2, a3
    bn.lid t2, 0(t5)                /* w4 = yb[1] */
    bn.and w6, w2, w4               /* w6 = tb[1] */

    /* Single PINI pair (i, j) = (0, 1). */
    bn.wsrr w0, urnd                /* w0 = r */

    /* Handle wzij. */
    bn.xor w7, w4, w0               /* wtmp1 = yb[j] ^ r */
    bn.and w7, w7, w1               /* wtmp1 &= xb[i]    */
    bn.not w8, w1                   /* wtmp0 = xb[i] ^ 1 */
    bn.and w8, w8, w0               /* wtmp0 &= r        */
    bn.xor w8, w8, w7               /* wtmp0 ^= wtmp1    */
    bn.xor w5, w5, w8               /* tb[0] ^= wtmp0    */

    /* Whitening. */
    bn.xor w7, w7, w7
    bn.xor w8, w8, w8

    /* Handle wzji. */
    bn.xor w7, w3, w0               /* wtmp1 = yb[i] ^ r */
    bn.and w7, w7, w2               /* wtmp1 &= xb[j]    */
    bn.not w8, w2                   /* wtmp0 = xb[j] ^ 1 */
    bn.and w8, w8, w0               /* wtmp0 &= r        */
    bn.xor w8, w8, w7               /* wtmp0 ^= wtmp1    */
    bn.xor w6, w6, w8               /* tb[1] ^= wtmp0    */

    /* Copy tb to rb. */
    bn.sid t3, 0(a6)                /* rb[0] = tb[0] */
    add    t5, a6, a5
    bn.sid t4, 0(t5)                /* rb[1] = tb[1] */

    ret
