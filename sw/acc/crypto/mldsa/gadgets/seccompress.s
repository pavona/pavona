/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

.equ x1,  ra
.equ x2,  sp
.equ x5,  t0
.equ x6,  t1
.equ x7,  t2
.equ x8,  s0
.equ x9,  s1
.equ x10, a0
.equ x11, a1
.equ x12, a2
.equ x13, a3
.equ x14, a4
.equ x15, a5
.equ x16, a6
.equ x18, s2
.equ x19, s3
.equ x28, t3
.equ x29, t4
.equ x30, t5
.equ x31, t6

#define KBITS            32
#define POLY_BYTES     1024
#define BSL_BYTES      1024            /* k * 32 per share */
#define BOOL_BYTES     2048            /* d * k * 32 */
#define SHARE_STR      1024            /* k * 32 */

/* Stack layout */
#define SP_OUT            4
#define SP_X              8
#define SP_S0            16
#define SP_S1            20
#define SP_S2            24
#define SP_S3            28
#define SP_SCRATCH       32            /* caller scratch base (a2) */
#define SP_BPTR          36            /* caller B scratch (a3) */
#define FRAME_SIZE       64

#define T_DENSE_OFF       0
#define T_BSL_OFF      2048


/* CSUB constants */
#define CSUB_VPTR          4
#define CSUB_SCRATCH      16
#define CSUB_FRAME        32
#define CSUB_TMP_OFF      32
#define CSUB_AND_OFF      96
#define CSUB_DIFF_OFF    192

/*
 * Name: seccompress (PINI, d = 2)
 *
 * Masked SecCompress for the ML-DSA-44 SecDecompose: from 2 arithmetic shares
 * of x mod q (q = 8380417) produce a Boolean sharing of
 * w1 = round(x*delta/q) mod delta, delta = 44.  Hardcoded for d = 2 with
 * ell = 24, c = 8, k = ell + c = 32.
 *
 * Source: [CGMZ23] Alg.2 (HOCompress).  Used for [ABCH+23] Alg.7 line 7 (the
 * L2 SecDecompose branch).
 *   [CGMZ23]: Coron, Gerard, Montoya, Zeitoun, "High-order Polynomial
 *             Comparison and Masking Lattice-based Encryption", eprint 2021/1615.
 *
 * Paper Alg.2 verbatim (n shares, d output bits; Compress_{q,d}(x) = round(x*2^d/q) mod 2^d):
 *   1: alpha <- ceil(log2(q*n))
 *   2: z_1   <- floor((x_1*2^(d+alpha+1) + q)/(2q)) + 2^(alpha-1)  mod 2^(d+alpha)
 *   3: for i = 2..n: z_i <- floor((x_i*2^(d+alpha+1) + q)/(2q))    mod 2^(d+alpha)
 *   4: (c_1,..,c_n) <- A2B(d + alpha, (z_1,..,z_n))
 *   5: for i = 1..n: y_i <- c_i >> alpha
 *   6: return (y_1..y_n)
 *
 * What we compute (n = 2; compress modulus 2^d -> delta = 44, so alpha -> ell
 * = 24 and d -> c = 8):
 *   1: z_0 <- round(x_0*delta*2^ell / q) + 2^(ell-1)   mod 2^(ell+c)
 *   2: z_1 <- round(x_1*delta*2^ell / q)               mod 2^(ell+c)
 *   3: Z  <- A2B(ell + c, (z_0, z_1))
 *   4: V' <- Z >> ell                                   (top c=8 stripes of Z)
 *   5: for t = 1, 2:  V' <- (V' >= delta) ? V' - delta : V'
 *
 * After line 4, V' can be in [0,88] - hence, we need two conditional subtractions of 44.
 *
 * Rounded division by q (lines 1-2): ACC has no division, so we replace
 * it by multiplication:
 * round(x_i*delta*2^ell / q) is a truncating Barrett multiply
 *   z_i = (x_i * K) >> 25,  K = round(delta*2^(ell+25) / q) = 0xB02C09A2.
 *
 *
 * @param[out]    a0: dptr_z, 2048 B share-major a2b output (share_str=1024)
 * @param[in]     a1: dptr_x, 2 * 1024 B arith shares mod q (contiguous)
 * @param[in]     a2: dptr_scratch, 4096 B (T_DENSE + T_BSL), caller-provided
 * @param[in]     a3: dptr_b, 2048 B scratch for the a2b's B, caller-provided
 * @param[in]    w31: all-zero
 *
 * clobbered registers: x2, x5 to x7, x10 to x17, x28 to x31, w0 to w27
 * clobbered flag groups: FG0
 */
.globl seccompress
seccompress:
    li   t0, FRAME_SIZE
    sub  sp, sp, t0
    sw   a0, SP_OUT(sp)
    sw   a1, SP_X(sp)
    sw   s0, SP_S0(sp)
    sw   s1, SP_S1(sp)
    sw   s2, SP_S2(sp)
    sw   s3, SP_S3(sp)
    sw   a2, SP_SCRATCH(sp)
    sw   a3, SP_BPTR(sp)

    /* K = 0xB02C09A2 -> w16 (broadcast to all 8 lanes). */
    bn.addi  w16, w31, 0xB0
    bn.rshi  w16, w16, w31 >> 248
    bn.addi  w16, w16, 0x2C
    bn.rshi  w16, w16, w31 >> 248
    bn.addi  w16, w16, 0x09
    bn.rshi  w16, w16, w31 >> 248
    bn.addi  w16, w16, 0xA2
    bn.rshi  w18, w16, w31 >> 224
    bn.or    w16, w16, w18
    bn.rshi  w18, w16, w31 >> 192
    bn.or    w16, w16, w18
    bn.rshi  w18, w16, w31 >> 128
    bn.or    w16, w16, w18

    /* BIAS = 2^23 -> w17 (broadcast to all 8 lanes). */
    bn.addi   w17, w31, 1
    bn.rshi   w18, w17, w31 >> 224
    bn.or     w17, w17, w18
    bn.rshi   w18, w17, w31 >> 192
    bn.or     w17, w17, w18
    bn.rshi   w18, w17, w31 >> 128
    bn.or     w17, w17, w18
    bn.shv.8S w17, w17 << 23

    /* Steps 1-2: z_i = round(x_i*delta*2^ell / q) mod 2^(ell+c) for i in {0,1}. */
    addi     s0, a1, 0
    lw       s1, SP_SCRATCH(sp)
    loopi    2, 10
        li       t0, 0
        li       t2, 3
        loopi    32, 5
            bn.lid               t0, 0(s0++)
            bn.shv.8S            w0, w0 << 7
            bn.mulv.8S.even.hi   w3, w0, w16
            bn.mulv.8S.odd.hi    w3, w3, w16
            bn.sid               t2, 0(s1++)
        /* Whitening */
        bn.xor w0, w0, w0
        bn.xor w3, w3, w3

    /* Add the rounding bias 2^(ell-1) = 2^23 to share 0. */
    lw       s0, SP_SCRATCH(sp)
    li       t0, 0
    loopi    32, 3
        bn.lid       t0, 0(s0)
        bn.addv.8S   w0, w0, w17
        bn.sid       t0, 0(s0++)

    /* Step 3: Z = A2B(z_0, z_1) */

    /* Bitslice each share */
    lw       s0, SP_SCRATCH(sp)
    lw       s1, SP_SCRATCH(sp)
    li       t0, T_BSL_OFF
    add      s1, s1, t0
    loopi    2, 34
        addi a0, s1, 0
        addi a1, s0, 0
        li   a2, 32
        jal  x1, bitslice_k32
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
        addi s0, s0, POLY_BYTES
        addi s1, s1, BSL_BYTES


    /* SecA2B (BCC22, Alg 8) */
    /* A = (z_0, 0), B = (0, z_1). */
    lw   a1, SP_SCRATCH(sp)
    li   t0, T_BSL_OFF
    add  a1, a1, t0                     /* z_0 bitsliced */
    addi a2, a1, BSL_BYTES              /* z_1 bitsliced */
    lw   a4, SP_SCRATCH(sp)
    lw   a5, SP_BPTR(sp)
    addi t3, a4, 0
    addi t4, a5, 0
    li   t0, 0
    li   t1, 1
    li   t2, 31
    loopi 32, 6
        bn.lid t0, 0(a1++)            /* z_0[i] */
        bn.lid t1, 0(a2++)            /* z_1[i] */
        bn.sid t0, 0(t3)              /* A.share0 = z_0[i] */
        bn.sid t2, 1024(t3++)         /* A.share1 = 0 */
        bn.sid t2, 0(t4)              /* B.share0 = 0 */
        bn.sid t1, 1024(t4++)         /* B.share1 = z_1[i] */

    /* Z = A + B mod 2^32 (secadd_bc22, k=32, share_str=1024, d=2). */
    addi a0, a4, 0
    addi a1, a5, 0
    li   a2, 32
    li   a3, 1024
    li   a4, 2
    lw   a5, SP_OUT(sp)
    jal  x1, secadd_bc22

    /* Step 4 implicit by using higher bits. */

    /* Step 5: V' = V' mod delta, two passes of the conditional subtract-delta.
     * V' from step 4 lies in [0, 2*delta] = [0, 88]:
     *  pass 1 maps it to [0, 44],
     *  pass 2 folds the residual 44 -> 0.*/
    lw   a0, SP_OUT(sp)
    addi a0, a0, 768                /* V' = top 8 stripes of Z (share 0) */
    lw   a1, SP_SCRATCH(sp)
    li   t0, CSUB_FRAME
    sub  sp, sp, t0
    sw   a0, CSUB_VPTR(sp)
    sw   a1, CSUB_SCRATCH(sp)
    jal  x1, _seccompress_csub
    jal  x1, _seccompress_csub
    li   t0, CSUB_FRAME
    add  sp, sp, t0

    lw   s0, SP_S0(sp)
    lw   s1, SP_S1(sp)
    lw   s2, SP_S2(sp)
    lw   s3, SP_S3(sp)
    li   t0, FRAME_SIZE
    add  sp, sp, t0
    ret


/*
 * _seccompress_csub (internal, d=2): one conditional subtract of delta=44,
 * V' = (V' >= delta) ? V' - delta : V', as a masked select:
 *   diff = V' + (256 - delta)             (secadd_bc22_immd_d2, 8 stripes)
 *   mask = MSB(diff)                      (1 iff V' < delta)
 *   tmp  = V' XOR diff                    (sharewise)
 *   V'   = SecAnd(mask, tmp) XOR diff     (mask=1 keeps V', mask=0 takes diff)
 */
_seccompress_csub:
    /* diff = V' + (256 - delta) mod 256 via inline-constant SecAdd. */
    bn.addi w17, w31, 212
    lw   a0, CSUB_VPTR(sp)
    li   a2, 8
    li   a3, 1024
    li   a4, 2
    lw   a5, CSUB_SCRATCH(sp)
    addi a5, a5, CSUB_DIFF_OFF
    jal  x1, secadd_bc22_immd_d2

    /* Masked select over the 8 V'/diff stripes:
     *   V'[i] = (mask & (V'[i] ^ diff[i])) ^ diff[i],  mask = MSB(diff).
     */
    lw   s0, CSUB_VPTR(sp)
    lw   t6, CSUB_SCRATCH(sp)
    addi s1, t6, CSUB_DIFF_OFF
    loopi 8, 37
        /* tmp = V'[i] ^ diff[i] sharewise */
        li   t1, 0
        li   t2, 1
        bn.lid t1, 0(s0)
        bn.lid t2, 0(s1)
        bn.xor w0, w0, w1
        addi t5, t6, CSUB_TMP_OFF
        bn.sid t1, 0(t5)
        /* Whitening */
        bn.xor w0, w0, w0
        bn.xor w1, w1, w1
        bn.lid t1, 1024(s0)
        bn.lid t2, 1024(s1)
        bn.xor w0, w0, w1
        bn.sid t1, 32(t5)
        /* and = secand_cs20(mask = diff[bit 7], tmp) */
        addi a0, t6, CSUB_DIFF_OFF
        addi a0, a0, 224
        li   a1, 1024
        addi a2, t6, CSUB_TMP_OFF
        li   a3, 32
        li   a4, 2
        li   a5, 32
        addi a6, t6, CSUB_AND_OFF
        jal  x1, secand_cs20
        /* V'[i] = and ^ diff[i] sharewise */
        li   t1, 0
        li   t2, 1
        addi t5, t6, CSUB_AND_OFF
        bn.lid t1, 0(t5)
        bn.lid t2, 0(s1)
        bn.xor w0, w0, w1
        bn.sid t1, 0(s0)
        /* Whitening */
        bn.xor w0, w0, w0
        bn.xor w1, w1, w1
        bn.lid t1, 32(t5)
        bn.lid t2, 1024(s1)
        bn.xor w0, w0, w1
        bn.sid t1, 1024(s0)
        addi s0, s0, 32
        addi s1, s1, 32

    ret
