/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

.equ x1,  ra
.equ x2,  sp
.equ x5,  t0
.equ x6,  t1
.equ x7,  t2
.equ x10, a0
.equ x11, a1
.equ x12, a2
.equ x13, a3
.equ x14, a4
.equ x15, a5
.equ x16, a6
.equ x17, a7
.equ x28, t3
.equ x29, t4
.equ x30, t5
.equ x31, t6

/* Stack frame: SP_C (32 B WDR stash for secleq constant) + SP_SECA2B /
 * SP_BUF (4 B word slots).  The bit-major share-inner buffer is now
 * caller-provided in a4. */
#define SP_SECA2B     0
#define SP_BUF        4
#define SP_C         32
#define SP_FRAME     64

/*
 * Name: secboundcheck (PINI when output is public)
 *
 * Implements Alg.5 SecBoundCheck^d_{q,lambda_0,lambda_1}(x^{A_q}) of
 * [ABCH+23].  Returns the per-lane "passed" mask b in w0 (b_i = 1 iff
 * -lambda_0 <= x_i <= lambda_1 mod q).
 *
 *   1: x_0^{A_q}  <- x_0^{A_q} + lambda_0 mod q
 *   2: x'^{B,k}   <- SecA2BModp^d_q(x^{A_q})                . seca2bmodq_bc22
 *   3: b          <- SecLeq^d_{lambda_0+lambda_1}(x'^{B,k}) . secleq
 *
 * Source: Alg.5 of "Protecting Dilithium against Leakage --
 *         Revisited Sensitivity Analysis and Improved Implementations",
 *         https://eprint.iacr.org/2022/1406
 *
 * @param[in]      a0: dptr_x_arith, 2*1024 B arith shares (stride 1024).
 * @param[in]      a2: dptr_lambda0_vec, 32 bytes broadcast of lambda_0.
 * @param[in]      a3: dptr_scratch, 1536 B for seca2bmodq_bc22.
 * @param[in]      a4: dptr_buf, 1536 B bit-major share-inner buffer
 *                     (must not overlap dptr_scratch or dptr_x_arith).
 * @param[in]     w17: lane-0 holds C = 2^{k+1} - (lambda_0+lambda_1) - 1.
 * @param[in]     w31: all-zero.
 * @param[out]     w0: per-lane b.
 *
 * w16/w22/w23 are stashed in w28/w29/w30 across the chain.
 *
 * clobbered registers: x2, x5 to x7, x10 to x17, x28 to x31, w0 to w27
 * clobbered flag groups: FG0
 */

.globl secboundcheck
secboundcheck:
    bn.mov w28, w16
    bn.mov w29, w22
    bn.mov w30, w23

    addi sp, sp, -SP_FRAME
    sw   a3, SP_SECA2B(sp)
    sw   a4, SP_BUF(sp)

    /* Stash C across the seca2bmodq call. */
    li   t0, 17
    bn.sid t0, SP_C(sp)

    /* Preserve arguments. */
    addi a7, a0, 0

    /* Step 1: x_0^{A_q} <- x_0^{A_q} + lambda_0 mod q.  Written to a4 so
     * the caller's x stays intact. */
    bn.lid x0, 0(a2)
    addi t0, a7, 0
    addi t1, a4, 0
    li   t2, 1
    loopi 32, 3
        bn.lid      t2, 0(t0++)
        bn.addvm.8S w1, w1, w0
        bn.sid      t2, 0(t1++)

    /* Bitslice each share into the share-major bit-inner buffer. */
    addi a0, a4, 0
    addi a1, a4, 0
    li   a2, 32
    jal  x1, bitslice

    /* Whitening */
    bn.xor w0, w0, w0
    bn.xor w1, w1, w1
    bn.xor w2, w2, w2
    bn.xor w3, w3, w3
    bn.xor w4, w4, w4
    bn.xor w5, w5, w5
    bn.xor w6, w6, w6
    bn.xor w7, w7, w7
    bn.xor w8, w8, w8
    bn.xor w9, w9, w9
    bn.xor w10, w10, w10
    bn.xor w11, w11, w11
    bn.xor w12, w12, w12
    bn.xor w13, w13, w13
    bn.xor w14, w14, w14
    bn.xor w15, w15, w15
    bn.xor w16, w16, w16
    bn.xor w17, w17, w17
    bn.xor w18, w18, w18
    bn.xor w19, w19, w19
    bn.xor w20, w20, w20
    bn.xor w21, w21, w21
    bn.xor w22, w22, w22
    bn.xor w23, w23, w23
    bn.xor w24, w24, w24
    bn.xor w25, w25, w25
    bn.xor w26, w26, w26
    bn.xor w27, w27, w27
    lw   a4, SP_BUF(sp)
    addi a0, a4, 768
    addi a1, a7, 1024
    li   a2, 32
    jal  x1, bitslice

    /* Zero bit-k pad of each share. */
    lw   a4, SP_BUF(sp)
    li   t0, 31
    addi t1, a4, 736
    bn.sid t0, 0(t1)
    addi t1, a4, 1504
    bn.sid t0, 0(t1)

    /* Step 2: x'^{B,k} <- SecA2BModp^d_q(x^{A_q}). */
    addi a0, a4, 0
    addi a1, a4, 0
    lw   a3, SP_SECA2B(sp)
    jal  x1, seca2bmodq_bc22

    /* Step 3: b <- SecLeq^d_{lambda_0+lambda_1}(x'^{B,k}). */
    lw   a4, SP_BUF(sp)
    li   t0, 17
    bn.lid t0, SP_C(sp)
    addi a1, a4, 0
    jal  x1, secleq

    addi sp, sp, SP_FRAME

    bn.mov w16, w28
    bn.mov w22, w29
    bn.mov w23, w30
    ret
