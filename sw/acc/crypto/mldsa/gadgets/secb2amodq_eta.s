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
.equ x28, t3
.equ x29, t4
.equ x30, t5
.equ x31, t6

/*
 * Name: secb2amodq_eta (PINI, d = 2)
 *
 * b2a for polyeta-shaped Boolean inputs (k = 3 for eta=2, k = 4 for eta=4):
 * zero-pads the k-stripe shares to the full 24-stripe Z_q layout, runs
 * secb2amodq_bc22, then unbitslices each output share to canonical 32-bit
 * arithmetic at caller's a0.
 *
 * @param[in]   a0: dptr_out, 2 * 1024 B canonical arith shares (mod q).
 * @param[in]   a1: dptr_x_share0, k * 32 B Boolean bitsliced.
 * @param[in]   a2: dptr_x_share1, k * 32 B Boolean bitsliced.
 * @param[in]   a3: bit-width k (3 or 4).
 * @param[in]   a4: dptr_scratch, 1536 B for seca2bmodq_bc22 (forwarded).
 * @param[in]   a5: dptr_buf, 1536 B share-major Boolean buffer
 *                  (must not overlap dptr_scratch).
 * @param[in]   w31: all-zero.
 *
 * clobbered registers: x2, x5 to x7, x10 to x17, x28 to x31, w0 to w27
 * clobbered flag groups: FG0
 */
.globl secb2amodq_eta
secb2amodq_eta:
    addi sp, sp, -32
    sw   ra,  0(sp)
    sw   a0,  4(sp)
    sw   a4,  8(sp)
    sw   a5, 12(sp)

    /* Zero the 48-WDR buffer at a5. */
    li   t2, 31
    addi t0, a5, 0
    loopi 48, 1
        bn.sid t2, 0(t0++)

    /* share 0 low k stripes -> buffer + 0. */
    li   t2, 0
    addi t0, a5, 0
    addi t4, a1, 0
    loop a3, 2
        bn.lid t2, 0(t4++)
        bn.sid t2, 0(t0++)

    /* Whitening */
    bn.xor w0, w0, w0
    /* share 1 low k stripes -> buffer + 768. */
    addi t0, a5, 768
    addi t4, a2, 0
    loop a3, 2
        bn.lid t2, 0(t4++)
        bn.sid t2, 0(t0++)

    /* b2a: caller's a0 receives bitsliced arith shares. */
    lw   a0,  4(sp)
    addi a1, a5, 0
    lw   a3,  8(sp)
    jal  x1, secb2amodq_bc22

    /* Unbitslice each share to canonical 32-bit; share 1 first so its
     * overlapping write [1024..1535] doesn't clobber share 0's source. */
    lw   a0,  4(sp)
    addi a1, a0, 768
    addi a0, a0, 1024
    jal  x1, unbitslice

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
    lw   a0,  4(sp)
    addi a1, a0, 0
    jal  x1, unbitslice

    lw   ra,  0(sp)
    addi sp, sp, 32
    ret
