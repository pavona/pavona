/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

.equ x1,  ra
.equ x2,  sp
.equ x5,  t0
.equ x6,  t1
.equ x10, a0
.equ x11, a1
.equ x12, a2
.equ x28, t3
.equ x29, t4
.equ x30, t5

#define KBITS 23

/*
 * Name: unbitslice (ML-DSA, KBITS = 23)
 *
 * Inverse of bitslice: take KBITS bitsliced WDRs (lane i of WDR j = bit
 * j of coef i) and produce 32 canonical WDRs of 8 x 32-bit packed
 * coefficients with the upper (32 - KBITS) bits zero.
 *
 * @param[in]       a0: ptr_out, dmem pointer to output (32 * 32 = 1024 B)
 * @param[in]       a1: ptr_in,  dmem pointer to input  (KBITS * 32 bytes)
 * @param[in]  w31: all-zero
 *
 * clobbered registers: x5, x10 to x12, x28, x30, w0 to w27
 * clobbered flag groups: FG0
 */
.globl unbitslice
unbitslice:
    la   a2, scratch

    /* === Phase 2: scatter 23 bitsliced inputs through three 8x8 lane
     * transposes into 32 scratch WDRs.  q=3 (bits 23..31) is zero-filled. === */

    /* --- q=0 --- */
    li   t0, 0
    loopi 8, 2
        bn.lid t0, 0(a1++)
        addi   t0, t0, 1

    bn.trn1.8S w8,  w0, w1
    bn.trn2.8S w9,  w0, w1
    bn.trn1.8S w10, w2, w3
    bn.trn2.8S w11, w2, w3
    bn.trn1.8S w12, w4, w5
    bn.trn2.8S w13, w4, w5
    bn.trn1.8S w14, w6, w7
    bn.trn2.8S w15, w6, w7
    bn.trn1.4D w0,  w8,  w10
    bn.trn2.4D w2,  w8,  w10
    bn.trn1.4D w1,  w9,  w11
    bn.trn2.4D w3,  w9,  w11
    bn.trn1.4D w4,  w12, w14
    bn.trn2.4D w6,  w12, w14
    bn.trn1.4D w5,  w13, w15
    bn.trn2.4D w7,  w13, w15
    bn.trn1.2Q w16, w0, w4
    bn.trn2.2Q w20, w0, w4
    bn.trn1.2Q w17, w1, w5
    bn.trn2.2Q w21, w1, w5
    bn.trn1.2Q w18, w2, w6
    bn.trn2.2Q w22, w2, w6
    bn.trn1.2Q w19, w3, w7
    bn.trn2.2Q w23, w3, w7

    /* Store w16..w23 to scratch at stride 128. */
    addi t3, a2, 0
    li   t0, 16
    bn.sid t0, 0(t3)
    addi t3, t3, 128
    addi t0, t0, 1
    bn.sid t0, 0(t3)
    addi t3, t3, 128
    addi t0, t0, 1
    bn.sid t0, 0(t3)
    addi t3, t3, 128
    addi t0, t0, 1
    bn.sid t0, 0(t3)
    addi t3, t3, 128
    addi t0, t0, 1
    bn.sid t0, 0(t3)
    addi t3, t3, 128
    addi t0, t0, 1
    bn.sid t0, 0(t3)
    addi t3, t3, 128
    addi t0, t0, 1
    bn.sid t0, 0(t3)
    addi t3, t3, 128
    addi t0, t0, 1
    bn.sid t0, 0(t3)

    /* --- q=1 --- */
    li   t0, 0
    loopi 8, 2
        bn.lid t0, 0(a1++)
        addi   t0, t0, 1

    bn.trn1.8S w8,  w0, w1
    bn.trn2.8S w9,  w0, w1
    bn.trn1.8S w10, w2, w3
    bn.trn2.8S w11, w2, w3
    bn.trn1.8S w12, w4, w5
    bn.trn2.8S w13, w4, w5
    bn.trn1.8S w14, w6, w7
    bn.trn2.8S w15, w6, w7
    bn.trn1.4D w0,  w8,  w10
    bn.trn2.4D w2,  w8,  w10
    bn.trn1.4D w1,  w9,  w11
    bn.trn2.4D w3,  w9,  w11
    bn.trn1.4D w4,  w12, w14
    bn.trn2.4D w6,  w12, w14
    bn.trn1.4D w5,  w13, w15
    bn.trn2.4D w7,  w13, w15
    bn.trn1.2Q w16, w0, w4
    bn.trn2.2Q w20, w0, w4
    bn.trn1.2Q w17, w1, w5
    bn.trn2.2Q w21, w1, w5
    bn.trn1.2Q w18, w2, w6
    bn.trn2.2Q w22, w2, w6
    bn.trn1.2Q w19, w3, w7
    bn.trn2.2Q w23, w3, w7

    addi t3, a2, 32
    li   t0, 16
    bn.sid t0, 0(t3)
    addi t3, t3, 128
    addi t0, t0, 1
    bn.sid t0, 0(t3)
    addi t3, t3, 128
    addi t0, t0, 1
    bn.sid t0, 0(t3)
    addi t3, t3, 128
    addi t0, t0, 1
    bn.sid t0, 0(t3)
    addi t3, t3, 128
    addi t0, t0, 1
    bn.sid t0, 0(t3)
    addi t3, t3, 128
    addi t0, t0, 1
    bn.sid t0, 0(t3)
    addi t3, t3, 128
    addi t0, t0, 1
    bn.sid t0, 0(t3)
    addi t3, t3, 128
    addi t0, t0, 1
    bn.sid t0, 0(t3)

    /* --- q=2: 7 inputs + zero pad for missing bit 23. --- */
    li   t0, 0
    loopi 7, 2
        bn.lid t0, 0(a1++)
        addi   t0, t0, 1
    bn.mov w7, w31

    bn.trn1.8S w8,  w0, w1
    bn.trn2.8S w9,  w0, w1
    bn.trn1.8S w10, w2, w3
    bn.trn2.8S w11, w2, w3
    bn.trn1.8S w12, w4, w5
    bn.trn2.8S w13, w4, w5
    bn.trn1.8S w14, w6, w7
    bn.trn2.8S w15, w6, w7
    bn.trn1.4D w0,  w8,  w10
    bn.trn2.4D w2,  w8,  w10
    bn.trn1.4D w1,  w9,  w11
    bn.trn2.4D w3,  w9,  w11
    bn.trn1.4D w4,  w12, w14
    bn.trn2.4D w6,  w12, w14
    bn.trn1.4D w5,  w13, w15
    bn.trn2.4D w7,  w13, w15
    bn.trn1.2Q w16, w0, w4
    bn.trn2.2Q w20, w0, w4
    bn.trn1.2Q w17, w1, w5
    bn.trn2.2Q w21, w1, w5
    bn.trn1.2Q w18, w2, w6
    bn.trn2.2Q w22, w2, w6
    bn.trn1.2Q w19, w3, w7
    bn.trn2.2Q w23, w3, w7

    addi t3, a2, 64
    li   t0, 16
    bn.sid t0, 0(t3)
    addi t3, t3, 128
    addi t0, t0, 1
    bn.sid t0, 0(t3)
    addi t3, t3, 128
    addi t0, t0, 1
    bn.sid t0, 0(t3)
    addi t3, t3, 128
    addi t0, t0, 1
    bn.sid t0, 0(t3)
    addi t3, t3, 128
    addi t0, t0, 1
    bn.sid t0, 0(t3)
    addi t3, t3, 128
    addi t0, t0, 1
    bn.sid t0, 0(t3)
    addi t3, t3, 128
    addi t0, t0, 1
    bn.sid t0, 0(t3)
    addi t3, t3, 128
    addi t0, t0, 1
    bn.sid t0, 0(t3)

    /* --- q=3: zero-fill (no input bits). --- */
    addi t3, a2, 96
    li   t0, 31
    loopi 8, 2
        bn.sid t0, 0(t3)
        addi   t3, t3, 128

    /* === Rebuild masks w20..w27 (clobbered by Phase 2 transposes). === */
    bn.not    w6,  w31
    bn.shv.8S w20, w6  >> 16
    bn.shv.8S w4,  w20 << 8
    bn.xor    w21, w20, w4
    bn.shv.8S w4,  w21 << 4
    bn.xor    w22, w21, w4
    bn.shv.8S w4,  w22 << 2
    bn.xor    w23, w22, w4
    bn.shv.8S w4,  w23 << 1
    bn.xor    w24, w23, w4
    bn.rshi   w25, w31, w6  >> 128
    bn.rshi   w4,  w31, w6  >> 192
    bn.rshi   w5,  w4,  w31 >> 128
    bn.or     w26, w4,  w5
    bn.rshi   w4,  w31, w6  >> 224
    bn.rshi   w5,  w4,  w31 >> 192
    bn.or     w4,  w4,  w5
    bn.rshi   w5,  w4,  w31 >> 128
    bn.or     w27, w4,  w5

    /* === Phase 1: 8 groups of 32x32 bit transpose, scratch -> output. === */
    addi t3, a2, 0
    li   t5, 8

    loop t5, 161
        li   t0, 0
        loopi 4, 2
            bn.lid t0, 0(t3++)
            addi   t0, t0, 1

        /* Stage j=16 (cross-WDR). */
        bn.shv.8S w4, w0 >> 16
        bn.xor    w4, w2, w4
        bn.and    w4, w4, w20
        bn.xor    w2, w2, w4
        bn.shv.8S w4, w4 << 16
        bn.xor    w0, w0, w4

        bn.shv.8S w4, w1 >> 16
        bn.xor    w4, w3, w4
        bn.and    w4, w4, w20
        bn.xor    w3, w3, w4
        bn.shv.8S w4, w4 << 16
        bn.xor    w1, w1, w4

        /* Stage j=8 (cross-WDR). */
        bn.shv.8S w4, w0 >> 8
        bn.xor    w4, w1, w4
        bn.and    w4, w4, w21
        bn.xor    w1, w1, w4
        bn.shv.8S w4, w4 << 8
        bn.xor    w0, w0, w4

        bn.shv.8S w4, w2 >> 8
        bn.xor    w4, w3, w4
        bn.and    w4, w4, w21
        bn.xor    w3, w3, w4
        bn.shv.8S w4, w4 << 8
        bn.xor    w2, w2, w4

        /* Stage j=4 (intra-WDR). */
        bn.rshi   w6, w31, w0 >> 128
        bn.shv.8S w4, w0 >> 4
        bn.xor    w4, w6, w4
        bn.and    w4, w4, w22
        bn.xor    w6, w6, w4
        bn.shv.8S w4, w4 << 4
        bn.xor    w0, w0, w4
        bn.rshi   w6, w6, w31 >> 128
        bn.and    w0, w0, w25
        bn.or     w0, w0, w6

        bn.rshi   w6, w31, w1 >> 128
        bn.shv.8S w4, w1 >> 4
        bn.xor    w4, w6, w4
        bn.and    w4, w4, w22
        bn.xor    w6, w6, w4
        bn.shv.8S w4, w4 << 4
        bn.xor    w1, w1, w4
        bn.rshi   w6, w6, w31 >> 128
        bn.and    w1, w1, w25
        bn.or     w1, w1, w6

        bn.rshi   w6, w31, w2 >> 128
        bn.shv.8S w4, w2 >> 4
        bn.xor    w4, w6, w4
        bn.and    w4, w4, w22
        bn.xor    w6, w6, w4
        bn.shv.8S w4, w4 << 4
        bn.xor    w2, w2, w4
        bn.rshi   w6, w6, w31 >> 128
        bn.and    w2, w2, w25
        bn.or     w2, w2, w6

        bn.rshi   w6, w31, w3 >> 128
        bn.shv.8S w4, w3 >> 4
        bn.xor    w4, w6, w4
        bn.and    w4, w4, w22
        bn.xor    w6, w6, w4
        bn.shv.8S w4, w4 << 4
        bn.xor    w3, w3, w4
        bn.rshi   w6, w6, w31 >> 128
        bn.and    w3, w3, w25
        bn.or     w3, w3, w6

        /* Stage j=2 (intra-WDR). */
        bn.and    w5, w0, w26
        bn.rshi   w6, w31, w0 >> 64
        bn.and    w6, w6, w26
        bn.shv.8S w4, w5 >> 2
        bn.xor    w4, w6, w4
        bn.and    w4, w4, w23
        bn.xor    w6, w6, w4
        bn.shv.8S w4, w4 << 2
        bn.xor    w5, w5, w4
        bn.rshi   w6, w6, w31 >> 192
        bn.or     w0, w5, w6

        bn.and    w5, w1, w26
        bn.rshi   w6, w31, w1 >> 64
        bn.and    w6, w6, w26
        bn.shv.8S w4, w5 >> 2
        bn.xor    w4, w6, w4
        bn.and    w4, w4, w23
        bn.xor    w6, w6, w4
        bn.shv.8S w4, w4 << 2
        bn.xor    w5, w5, w4
        bn.rshi   w6, w6, w31 >> 192
        bn.or     w1, w5, w6

        bn.and    w5, w2, w26
        bn.rshi   w6, w31, w2 >> 64
        bn.and    w6, w6, w26
        bn.shv.8S w4, w5 >> 2
        bn.xor    w4, w6, w4
        bn.and    w4, w4, w23
        bn.xor    w6, w6, w4
        bn.shv.8S w4, w4 << 2
        bn.xor    w5, w5, w4
        bn.rshi   w6, w6, w31 >> 192
        bn.or     w2, w5, w6

        bn.and    w5, w3, w26
        bn.rshi   w6, w31, w3 >> 64
        bn.and    w6, w6, w26
        bn.shv.8S w4, w5 >> 2
        bn.xor    w4, w6, w4
        bn.and    w4, w4, w23
        bn.xor    w6, w6, w4
        bn.shv.8S w4, w4 << 2
        bn.xor    w5, w5, w4
        bn.rshi   w6, w6, w31 >> 192
        bn.or     w3, w5, w6

        /* Stage j=1 (intra-WDR). */
        bn.and    w5, w0, w27
        bn.rshi   w6, w31, w0 >> 32
        bn.and    w6, w6, w27
        bn.shv.8S w4, w5 >> 1
        bn.xor    w4, w6, w4
        bn.and    w4, w4, w24
        bn.xor    w6, w6, w4
        bn.shv.8S w4, w4 << 1
        bn.xor    w5, w5, w4
        bn.rshi   w6, w6, w31 >> 224
        bn.or     w0, w5, w6

        bn.and    w5, w1, w27
        bn.rshi   w6, w31, w1 >> 32
        bn.and    w6, w6, w27
        bn.shv.8S w4, w5 >> 1
        bn.xor    w4, w6, w4
        bn.and    w4, w4, w24
        bn.xor    w6, w6, w4
        bn.shv.8S w4, w4 << 1
        bn.xor    w5, w5, w4
        bn.rshi   w6, w6, w31 >> 224
        bn.or     w1, w5, w6

        bn.and    w5, w2, w27
        bn.rshi   w6, w31, w2 >> 32
        bn.and    w6, w6, w27
        bn.shv.8S w4, w5 >> 1
        bn.xor    w4, w6, w4
        bn.and    w4, w4, w24
        bn.xor    w6, w6, w4
        bn.shv.8S w4, w4 << 1
        bn.xor    w5, w5, w4
        bn.rshi   w6, w6, w31 >> 224
        bn.or     w2, w5, w6

        bn.and    w5, w3, w27
        bn.rshi   w6, w31, w3 >> 32
        bn.and    w6, w6, w27
        bn.shv.8S w4, w5 >> 1
        bn.xor    w4, w6, w4
        bn.and    w4, w4, w24
        bn.xor    w6, w6, w4
        bn.shv.8S w4, w4 << 1
        bn.xor    w5, w5, w4
        bn.rshi   w6, w6, w31 >> 224
        bn.or     w3, w5, w6

        li   t0, 0
        loopi 4, 2
            bn.sid t0, 0(a0++)
            addi   t0, t0, 1
        nop

    ret
