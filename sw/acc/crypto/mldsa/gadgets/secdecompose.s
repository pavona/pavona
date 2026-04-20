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
.equ x28, t3
.equ x29, t4
.equ x30, t5
.equ x31, t6

#ifndef DILITHIUM_MODE
  #error "secdecompose requires DILITHIUM_MODE"
#endif

#define KBITS 23

#if DILITHIUM_MODE == 2
  #define M_BITS          6
  #define SHARE_STR    1024
  #define ZERO_STRIPES   17   /* KBITS - M_BITS */
#elif DILITHIUM_MODE == 3 || DILITHIUM_MODE == 5
  #define M_BITS          4
  #define SHARE_STR     768
  #define ZERO_STRIPES   19   /* KBITS - M_BITS */
#else
  #error "secdecompose: unsupported DILITHIUM_MODE"
#endif

/* Stack layout. */
#define SP_W1OUT     4
#define SP_WIO       8
#define SP_SCRATCH  12
#define SP_S5       16
#define SP_S6       20
#define SP_S7       24
#define SP_S8       28
#define SP_S9       32
#define SP_W0PACK0  36
#define SP_W0PACK1  40
#define SP_SECA2B   44

#define FRAME_SIZE   64

/*
 * Name: secdecompose (PINI, d = 2)
 *
 * Masked SecDecompose for ML-DSA: from a 2-share arithmetic sharing of w mod q
 * (q = 8380417) produce the unmasked w1 = HighBits(w, alpha) and a sharing of
 * the low part w0, where w = alpha*w1 + w0 mod q and alpha = 2*gamma2.
 *
 * Source: [ABCH+23] Alg.7 (SecDecompose).
 *   [ABCH+23]: Azouaoui et al., "Protecting Dilithium against Leakage",
 *              TCHES 2023(4).
 *
 * [ABCH+23] Alg.7 (alpha = 2*gamma2; [[0,k'[[ = low k' bits):
 *   1: if ML-DSA-65 or ML-DSA-87 then
 *   2:     b  <- w + gamma2         mod q
 *   3:     b' <- alpha^-1 * b - 1   mod q
 *   4:     b' <- SecA2BModp(b')
 *   5:     w1 <- b'[[0, k'[[
 *   6: else                                          (ML-DSA-44)
 *   7:     w1 <- SecCompress_{q,-alpha^-1}(w)
 *   8: w1 <- SecUnMask(w1)
 *   9: w0 <- w - alpha * w1        mod q
 *
 * What we compute (d = 2):
 *   L2    (alpha = (q-1)/44, k' = 6): unmasked w1, and arithmetic shares of w0
 *         reconstructed in place over the input shares.
 *   L3/L5 (alpha = (q-1)/16, k' = 4): unmasked w1, and the Boolean bitsliced
 *         shares of (gamma2 - w0) dumped per share to a5/a6.  w0 itself is not
 *         reconstructed here; consumers recover it via b2a.
 *
 * @param[out]      a0: dptr_w1, 1024 B unmasked w1
 * @param[in]       a1: dptr_w, base of arith shares (mod q) at stride a4
 * @param[in]       a3: L3/L5: dptr_scratch, >=3296 B.
 *                      L2: seccompress scratch, 4096 B.
 * @param[in]       a4: stride between shares in bytes (>= 1024)
 * @param[in]       a5: L3/L5: dptr_w0_packed_share0, 768 B.  L2: seccompress B
 *                      scratch, 2048 B.
 * @param[in]       a6: L3/L5: dptr_w0_packed_share1, 768 B.  L2: T_PACKED, 2048 B.
 * @param[in]       a7: dptr_scratch, 1536 B for seca2bmodq_bc22 (L3/L5 only).
 * @param[in]      w31: all-zero
 *
 * clobbered registers: x2, x5 to x7, x10 to x17, x28 to x31, w0 to w15, w17 to w21, w24 to w30
 * clobbered flag groups: FG0
 */
.globl secdecompose
secdecompose:
    bn.mov w28, w16
    bn.mov w29, w22
    bn.mov w30, w23

    li   t0, FRAME_SIZE
    sub  sp, sp, t0

    sw   a0,  SP_W1OUT(sp)
    sw   a1,  SP_WIO(sp)
#if DILITHIUM_MODE != 2
    sw   a5,  SP_W0PACK0(sp)
    sw   a6,  SP_W0PACK1(sp)
    sw   a7,  SP_SECA2B(sp)
#endif

    sw   s5,  SP_S5(sp)
    sw   s6,  SP_S6(sp)
    sw   s7,  SP_S7(sp)
    sw   s8,  SP_S8(sp)
    sw   s9,  SP_S9(sp)

#if DILITHIUM_MODE == 2
    /* Line 7: w1 <- SecCompress_{q,delta}(w), delta = 44. */
    sw   a6, SP_SCRATCH(sp)

    /* Copy the 2 strided shares of w into contiguous T_PACKED (a6). */
    addi t3, a1, 0
    addi t4, a6, 0
    li   t6, 0
    loopi 2, 6
        addi t1, t3, 0
        loopi 32, 2
            bn.lid t6, 0(t1++)
            bn.sid t6, 0(t4++)
        /* Whitening */
        bn.xor w0, w0, w0
        add  t3, t3, a4

    /* seccompress in place. */
    addi a0, a6, 0
    addi a1, a6, 0
    addi a2, a3, 0
    addi a3, a5, 0
    jal  x1, seccompress

    lw   s9, SP_SCRATCH(sp)
    addi s8, s9, 768

#else
    /* Lines 2-3 (L3/L5): Compute b'
     *  2: b  <- w + gamma2         mod q
     *  3: b' <- alpha^-1 * b - 1   mod q
     *
     * With alpha^-1 = -16 and gamma2 = (q-1)/32, line 3 specializes to
     *   b' = alpha^-1*(w + gamma2) - 1
     *      = -16*(w + gamma2) - 1
     *      = -16*w + (q-1)/2 mod q.
     */

    addi s5, a3, 0
    addi s8, s5, 1024

    /* Share 0: -16*w_s0 + (q-1)/2. */
    la   t0, qm1half_const
    li   t1, 1
    bn.lid t1, 0(t0)
    lw   t3, SP_WIO(sp)
    addi t4, s5, 0
    li   t6, 0
    loopi 32, 8
        bn.lid      t6, 0(t3++)
        bn.subvm.8S w0, w31, w0
        bn.addvm.8S w0, w0, w0
        bn.addvm.8S w0, w0, w0
        bn.addvm.8S w0, w0, w0
        bn.addvm.8S w0, w0, w0
        bn.addvm.8S w0, w0, w1
        bn.sid      t6, 0(t4++)

    /* Bitslice share 0; zero bit k. */
    addi a0, s8, 0
    addi a1, s5, 0
    li   a2, 32
    jal  x1, bitslice
    li   t0, 31
    addi t1, s8, 736
    bn.sid t0, 0(t1)

    /* Whitening */
    bn.xor w0, w0, w0
    /* Share 1: -16*w_s1. */
    lw   t3, SP_WIO(sp)
    add  t3, t3, a4
    addi t4, s5, 0
    li   t6, 0
    loopi 32, 7
        bn.lid      t6, 0(t3++)
        bn.subvm.8S w0, w31, w0
        bn.addvm.8S w0, w0, w0
        bn.addvm.8S w0, w0, w0
        bn.addvm.8S w0, w0, w0
        bn.addvm.8S w0, w0, w0
        bn.sid      t6, 0(t4++)

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
    /* Bitslice share 1; zero bit k. */
    addi a0, s8, 768
    addi a1, s5, 0
    li   a2, 32
    jal  x1, bitslice
    li   t0, 31
    addi t1, s8, 1504             /* 768 + 736 */
    bn.sid t0, 0(t1)

    /* Line 4: b' <- SecA2BModp(b'). */
    addi a0, s8, 0
    addi a1, s8, 0
    li   a2, 2
    lw   a3, SP_SECA2B(sp)
    jal  x1, seca2bmodq_bc22

    /* Line 5: the low 4 stripes of b' are w1, left in place for the Line 8
     * collapse.  Stripes 4..22 (19) hold the Boolean shares of (gamma2 - w0);
     * dump per share to a5/a6 (608 B each). */
    lw   t0, SP_W0PACK0(sp)
    addi t3, s8, 128              /* share 0, stripe 4 */
    li   t1, 0
    loopi 19, 2
        bn.lid t1, 0(t3++)
        bn.sid t1, 0(t0++)
    lw   t0, SP_W0PACK1(sp)
    addi t3, s8, 896              /* share 1, stripe 4 (768 + 128) */
    loopi 19, 2
        bn.lid t1, 0(t3++)
        bn.sid t1, 0(t0++)

    /* W1_BSL base = T_BSL_BMSI + 768*d. */
    addi s9, s8, 1536
#endif

    /* Line 8: w1 <- SecUnMask(w1) = refresh + XOR-collapse */
    addi t3, s8, 0                /* share 0 stripe 0 */
    addi t4, s8, SHARE_STR        /* share 1 stripe 0 */
    addi t5, s9, 0
    li   t0, 0
    li   t1, 1
    loopi M_BITS, 7
        bn.lid  t0, 0(t3++)
        bn.lid  t1, 0(t4++)
        bn.wsrr w2, URND
        bn.xor  w0, w0, w2
        bn.xor  w1, w1, w2
        bn.xor  w0, w0, w1
        bn.sid  t0, 0(t5++)

    /* Zero stripes M_BITS..KBITS-1. */
    li   t0, ZERO_STRIPES
    li   t1, 31
    loop t0, 1
        bn.sid t1, 0(t5++)

    /* unbitslice w1. */
    lw   a0, SP_W1OUT(sp)
    addi a1, s9, 0
    jal  x1, unbitslice

#if DILITHIUM_MODE == 2
    /* Line 9: w0 <- w - alpha*w1 mod q:
     * share 0 := w_s0 - alpha*w1 (alpha = 2*gamma2)
     * share 1 = w_s1.
     */
    bn.wsrw 0x0, w28 /* MOD = R|Q (stashed) for subvm */
    la   t0, gamma2_vec_const
    li   t1, 24
    bn.lid t1, 0(t0)
    lw   a0, SP_W1OUT(sp)
    lw   a1, SP_WIO(sp)
    li   t0, 0
    li   t1, 1
    loopi 32, 7
        bn.lid t0, 0(a0++)
        bn.mulv.8S.even.lo w0, w0, w24
        bn.mulv.8S.odd.lo  w0, w0, w24
        bn.addv.8S w0, w0, w0
        bn.lid t1, 0(a1)
        bn.subvm.8S w0, w1, w0
        bn.sid t0, 0(a1++)
#endif

    lw   s5,  SP_S5(sp)
    lw   s6,  SP_S6(sp)
    lw   s7,  SP_S7(sp)
    lw   s8,  SP_S8(sp)
    lw   s9,  SP_S9(sp)
    li   t0,  FRAME_SIZE
    add  sp, sp, t0

    bn.mov w16, w28
    bn.mov w22, w29
    bn.mov w23, w30
    ret
