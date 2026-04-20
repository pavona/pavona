/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

.equ x1,  ra
.equ x5,  t0
.equ x6,  t1
.equ x7,  t2
.equ x10, a0
.equ x11, a1
.equ x12, a2
.equ x13, a3
.equ x14, a4
.equ x28, t3
.equ x29, t4
.equ x30, t5
.equ x31, t6

#define POLY_BYTES 1024
#define N_WDR      32     /* 256 / 8 */

/*
 * Name: secunmask_modq (PINI when output is public, d = 2)
 *
 * Refresh and unmask a 2-share arithmetic sharing of one polynomial mod q.
 * Composes RefreshIOS^d_q ([BC22] Alg.18 in its linear-masking variant)
 * with a sum-collapse.
 *
 *   1: x^{A_q}  <- RefreshIOS^d_q(x^{A_q})     . per-coef +/- with fresh r
 *   2: out      <- x_0^{A_q} + x_1^{A_q} mod q . sum-collapse
 *
 * Runs per-WDR (8 coefs at a time).
 * Caller must pre-load MOD with q in the lower half for .8s reductions.
 *
 * @param[out]      a0: dptr_out, 1024 B plaintext polynomial.
 * @param[in,out]   a1: dptr_x, 2 * 1024 B input (stride 1024; refreshed in place).
 * @param[in]  w31: all-zero.
 *
 * clobbered registers: x5 to x7, x28 to x31, w0 to w2, w11 to w15
 * clobbered flag groups: FG0
 */
.globl secunmask_modq
secunmask_modq:
    /* w11 = 0x007FFFFF * 8 (23-bit per-lane mask). */
    bn.not  w11, w31
    bn.rshi w11, w31, w11 >> 233
    bn.or   w11, w11, w11 << 32
    bn.or   w11, w11, w11 << 64
    bn.or   w11, w11, w11 << 128

    /* w13 = 0xFF000000 * 8 (top byte of each lane). */
    bn.shv.8s w13, w11 << 24

    /* w12 = q packed 8 lanes. */
    li     t0, 12
    la     t1, modulus
    bn.lid t0, 0(t1)

    addi t3, a1, 0                /* share 0 cursor */
    addi t4, a1, POLY_BYTES       /* share 1 cursor */
    addi t5, a0, 0                /* output cursor */

    li   t0, 0
    li   t1, 1
    li   t2, 2
    loopi N_WDR, 9
        jal         x1, _sample_rq
        bn.lid      t0, 0(t3)
        bn.addvm.8s w0, w0, w14        /* share 0 += r */
        bn.sid      t0, 0(t3++)
        bn.lid      t1, 0(t4)
        bn.subvm.8s w1, w1, w14        /* share 1 -= r */
        bn.sid      t1, 0(t4++)
        bn.addvm.8s w2, w0, w1         /* out = share 0 + share 1 */
        bn.sid      t2, 0(t5++)
    ret

/* Lane-parallel rejection sampler: returns w14 = 8 fresh uniform r in Z_q.
 * Requires w11 = 23-bit mask, w12 = q vector, w13 = top-byte mask.
 *   r  := URND & (2^23 - 1)                 (8 lanes of 23-bit uniform)
 *   ok := (r - q signed) top byte == 0xFF   (per lane, encodes r < q)
 *   retry while not all 8 lanes accept.
 *
 *   p_wdr = (8380417 / 2**23) ** 8  # ~0.9922
 */
_sample_rq:
    bn.wsrr     w14, URND
    bn.and      w14, w14, w11
    bn.subv.8s  w15, w14, w12
    bn.and      w15, w15, w13
    bn.cmp      w15, w13
    csrrs       t6, FG0, x0
    andi        t6, t6, 8
    beq         t6, x0, _sample_rq
    ret
