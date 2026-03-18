/* Copyright zeroRISC Inc. */
/* Copyright Amin Abdulrahman and Hoang Nguyen Hien Pham. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

#ifndef NSHARES
    #define NSHARES 2
#endif

#define NB_POLY 512
#define N_WDR 16

/* Register aliases */
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
 * Name: seconebitb2amodq_spog19_mlkem (SNI)
 *
 * Return arithmetic shares mod q = 3329 of a bit x, given its Boolean shares.
 * Vectorized for polynomial.
 *
 * Source: Alg.5 [SPOG19]
 *         [SPOG19]: "Efficiently Masking Binomial Sampling at Arbitrary Orders for Lattice-Based Crypto"
 *         Link: https://eprint.iacr.org/2019/910
 *
 * Note: The algorithm is also provided in [CGTZ23] (Alg.2). This implementation
 *       follows Alg.2 of [CGTZ23] for performance reason and for free-SNI
 *       security, which can be reused also for ML-DSA.
 *       [CGTZ23]: "Improved Gadgets for the High-Order Masking of Dilithium"
 *       Link: https://tches.iacr.org/index.php/TCHES/article/view/11160
 *
 * @param[in]  w16: R | Q
 * @param[in]  x10: dptr_x, dmem pointer to Boolean shares of x
 * @param[in]  x11: nshares, the number of shares
 * @param[out] x12: dptr_r, dmem pointer to arithmetic shares of r
 *
 * clobbered registers: TODO
 * clobbered flag groups: TODO
 */
.globl seconebitb2amodq_spog19_mlkem
seconebitb2amodq_spog19_mlkem:
    /* Save fp to stack */
    addi sp, sp, -32
    sw   fp, 0(sp)
    addi fp, sp, 0

    /* Save registers. */
    sw   s0, 4(fp)
    sw   s1, 8(fp)
    sw   s2, 12(fp)
    sw   s3, 16(fp)
    addi s0, a0, 0
    addi s1, a1, 0
    addi s2, a2, 0

    /* Adjust stack for temporary variables. */
    loop a1, 1
        addi sp, sp, -NB_POLY /* ptr_v */

    /* Copy x[2] to v[1]. */
    addi t0, sp, 0 /* ptr_v */
    addi t1, a0, NB_POLY /* ptr_x[2] */
    loopi N_WDR, 2
        bn.lid x0, 0(t1++)
        bn.sid x0, 0(t0++)
    /* Zeroize v[2]. */
    bn.xor w0, w0, w0
    loopi N_WDR, 1
        bn.sid x0, 0(t0++)

    /* Construct the vector of 1s. */
    #define wone w30
    bn.subi    wone, w0, 1
    bn.shv.16h wone, wone >> 15

    addi t0, x0, 2
    beq  a1, t0, _handle_common

    /* Loop over i = 2,...,nshares - 1. */
    /* --------------------------------------------------------------------- */
    addi s1, s1, -2 /* nshares - 2. */
    addi a1, x0, 2 /* Start with i = 2 shares. */
    addi s3, a0, 2*NB_POLY /* ptr_x[3] */
    loop s1, 31
        addi a0, sp, 0 /* s8 = ptr_v */
        /* a1 is already i. */
        addi a2, a0, 0 /* Output inplace. */
        jal  x1, linearrefreshmodq_rp10_mlkem

        /* As a2 is still pointing to v[i + 1], we clear it for next loop iteration. */
        bn.xor w0, w0, w0
        loopi N_WDR, 1
            bn.sid x0, 0(a2++)

        /* To avoid use modular multiplication, we compute (1 - 2*x[i + 1]) * v[j]
         * as follows:
         *  - t0 = x[i + 1] - 1
         *  - We have t0 = 0xFFFF if x[i + 1] = 0 and t0 = 0 if x[i + 1] = 1.
         *  - t1 = v[j] & t0
         *  - t1 <<= 1
         *  - r = bn.subvm(t1, v[j]) with MOD = Q. This works because if x[i + 1] = 0,
         *    then t1 = 2*v[j] and r = 2*v[j] - v[j] = v[j]. Otherwise,
         *    t1 = (0 - v[j]) mod Q.
         * For v[1], we continue with v[1] = (v[1] + x[i + 1]) mod Q before
         * saving the result to memory.
         */
        addi t0, s3, 0 /* ptr_x[i + 1] */
        addi s3, s3, NB_POLY /* ptr_x[i + 2] */
        addi t1, sp, 0 /* ptr_v */
        addi x4, x0, 1
        addi a1, a1, -1 /* a1 = i - 1 */
        loopi N_WDR, 18
            bn.lid         x0, 0(t0++) /* x[i + 1] */
            bn.subv.16h    w2, w0, wone
            addi           t2, t1, 0
            /* Handle v[1] so that we also compute v[1] = (v[1] + x[i + 1]) mod Q
            * before saving it to memory. */
            bn.lid         x4, 0(t1) /* v[1] */
            bn.and         w3, w1, w2
            bn.shv.16h     w3, w3 << 1
            bn.subvm.16h   w1, w3, w1
            bn.addvm.16h   w1, w0, w1
            bn.sid         x4, 0(t1)
            addi           t1, t1, NB_POLY /* Point to v[2]. */
            /* Loop over i = 2,...,nshares. */
            loop a1, 6
                bn.lid       x4, 0(t1) /* v[i] */
                bn.and       w3, w1, w2
                bn.shv.16h   w3, w3 << 1
                bn.subvm.16h w1, w3, w1
                bn.sid       x4, 0(t1)
                addi         t1, t1, NB_POLY /* Point to v[i + 1]. */
            addi t1, t2, 32
        /* Restore a1 = i and then increment it for loop i + 1. */
        addi a1, a1, 2
    /* After this loop a1 will be nshares. */

_handle_common:
    /* Loop i = nshares. */
    /* --------------------------------------------------------------------- */
    addi a0, sp, 0 /* ptr_v */
    /* a1 is still nshares. */
    addi a2, a0, 0 /* Output inplace. */
    jal  x1, linearrefreshmodq_rp10_mlkem

    /* To avoid use modular multiplication, we compute (1 - 2*x[1]) * v[j]
     * as follows:
     *  - t0 = x[1] - 1
     *  - We have t0 = 0xFFFF if x[1] = 0 and t0 = 0 if x[1] = 1.
     *  - t1 = v[j] & t0
     *  - t1 <<= 1
     *  - r = bn.subvm(t1, v[j]) with MOD = Q. This works because if x[1] = 0,
     *    then t1 = 2*v[j] and r = 2*v[j] - v[j] = v[j]. Otherwise,
     *    t1 = (0 - v[j]) mod Q.
     * For v[1], we continue with v[1] = (v[1] + x[1]) mod Q before
     * saving the result to memory.
     */
    addi t0, s0, 0 /* ptr_x[1] */
    addi t1, sp, 0 /* ptr_v */
    addi x4, x0, 1
    addi a1, a1, -1 /* a1 = nshares - 1 */
    loopi N_WDR, 18
        bn.lid         x0, 0(t0++) /* x[1] */
        bn.subv.16h    w2, w0, wone
        addi           t2, t1, 0
        /* Handle v[1] so that we also compute v[1] = (v[1] + x[1]) mod Q
         * before saving it to memory. */
        bn.lid       x4, 0(t1) /* v[1] */
        bn.and       w3, w1, w2
        bn.shv.16h   w3, w3 << 1
        bn.subvm.16h w1, w3, w1
        bn.addvm.16h w1, w0, w1
        bn.sid       x4, 0(t1)
        addi         t1, t1, NB_POLY /* Point to v[2]. */
        /* Loop over i = 2,...,nshares. */
        loop a1, 6
            bn.lid       x4, 0(t1) /* v[i] */
            bn.and       w3, w1, w2
            bn.shv.16h   w3, w3 << 1
            bn.subvm.16h w1, w3, w1
            bn.sid       x4, 0(t1)
            addi         t1, t1, NB_POLY /* Point to v[i + 1]. */
        addi t1, t2, 32

    /* Reverse (v[1],...,v[nshares]) --> (v[nshares],...,v[1]). */
    /* --------------------------------------------------------------------- */
    addi t0, a1, 1 /* a1 = nshares - 1 */
    srli t0, t0, 1 /* t0 = nshares // 2 */
    /* Compute the address v[nshares]. */
    addi t1, sp, 0 /* ptr_v */
    addi t2, sp, 0 /* ptr_v */
    loop a1, 1
        addi t1, t1, NB_POLY

    loop t0, 6
        loopi N_WDR, 4
            bn.lid x0, 0(t2)
            bn.lid x4, 0(t1)
            bn.sid x0, 0(t1++)
            bn.sid x4, 0(t2++)
        addi t1, t1, -2*NB_POLY

    /* Compute (v[nshares],...,v[1]) --> linearrefreshmodq_rp10_mlkem(v[nshares],...,v[1]). */
    /* Last linearrefreshmodq_rp10_mlkem */
    /* --------------------------------------------------------------------- */
    addi a0, sp, 0 /* s8 = ptr_v */
    addi a1, a1, 1 /* Restore a1 to nshares. */
    addi a2, s2, 0 /* ptr_r */
    jal  x1, linearrefreshmodq_rp10_mlkem

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
