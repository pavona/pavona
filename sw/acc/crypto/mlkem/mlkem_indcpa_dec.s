/* Copyright zeroRISC Inc. */
/* Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192). */
/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors. */
/* Modified by Ruben Niederhagen and Hoang Nguyen Hien Pham - authors of */
/* "Improving ML-KEM & ML-DSA on OpenTitan - Efficient Multiplication Vector Instructions for OTBN" */
/* (https://eprint.iacr.org/2025/2028). */
/* Copyright Ruben Niederhagen and Hoang Nguyen Hien Pham. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

#ifdef HARDENED
#define NSHARES 2
#else
#define NSHARES 1
#endif

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


/*
 * Name:        indcpa_dec
 *
 * Description: Decryption function of the CPA-secure
 *              public-key encryption scheme underlying Kyber.
 *
 * @param[in]  x10 (a0): dmem pointer to input ciphertext
 * @param[in]  x11 (a1): dmem pointer to input packed masked sk
 * @param[out] x12 (a2): dmem pointer to output message
 * @param[in]  x13 (a3): k, the security level
 * @param[in]  w31: all-zero register
 *
 * clobbered registers: x2 to x19, x21 to x25, x28 to x31, w0 to w26, w28 to w30, acc, acch, mod
 * clobbered flag groups: FG0
 */
.globl indcpa_dec
.type indcpa_dec, @function
indcpa_dec:
    /* Save fp to stack */
    addi sp, sp, -32
    sw   fp, 0(sp)
    addi fp, sp, 0

    addi s0, a0, 0
    addi s1, a1, 0
    addi s2, a2, 0
    addi s3, a3, 0

    /* Unpack sk and ct polynomial by polynomial. multiply them and accumulate
     * the result in m. */
    la s5, mpoly_sk
    la s6, poly_b
    la s7, mpoly_m
    la s8, twiddles_ntt
    la s9, twiddles_basemul

#ifndef HARDENED
    /* Unpack sk[0]. */
    addi a0, s1, 0
    addi a1, s5, 0 /* sk */
    jal  x1, poly_frombytes
    addi s1, a0, 0 /* Save address of sk to be unpacked later. */

    /* Unpack b.vec[0]. */
    bn.wsrr   w16, mod /* w16 = R | Q. */
    addi      a0, s0, 0 /* ct */
    addi      a1, s6, 0 /* b */
    addi      a2, s3, 0 /* k */
    jal       x1, poly_polyvec_decompress
    addi      s0, a0, 0 /* Save address of ct to be unpacked later. */

    /* Compute b = ntt(b). */
    bn.shv.16h w0, w16 << 1 /* w0 = 2*R | 2*Q */
    bn.wsrw    mod, w0 /* mod = 2*R | 2*Q */
    addi       a0, s6, 0 /* b */
    addi       a1, s8, 0 /* twiddles_ntt */
    addi       a2, a0, 0
    jal        x1, ntt

    /* Compute m = b * sk. */
    addi a1, s5, 0 /* sk */
    addi a2, s9, 0 /* twiddles_basemul */
    addi a3, s7, 0 /* m */
    addi a0, s6, 0 /* poly_b */
    jal  x1, basemul

    /* Loop over j = 1,...,KYBER_K - 1. */
    addi s3, s3, -1 /* k - 1 */
    loop s3, 19
        /* Unpack sk.vec[j]. */
        addi a0, s1, 0 /* sk.vec[j]. */
        addi a1, s5, 0 /* sk */
        jal  x1, poly_frombytes
        addi s1, a0, 0 /* Save address of sk.vec[j + 1] to be unpacked later. */

        /* Unpack b.vec[j]. */
        /* w16 is still R | Q and mod is still 2*R | 2*Q. */
        addi a0, s0, 0 /* ct */
        addi a1, s6, 0 /* b */
        addi a2, s3, 1 /* k */
        jal  x1, poly_polyvec_decompress
        addi s0, a0, 0 /* Save address of ct to be unpacked later. */

        /* Compute b = ntt(b). */
        /* w16 is still R | Q and mod is still 2*R | 2*Q. */
        addi a0, s6, 0 /* b */
        addi a1, s8, 0 /* twiddles_ntt */
        addi a2, a0, 0
        jal  x1, ntt

        /* Compute m += b * sk. */
        /* w16 is still R | Q and mod is still 2*R | 2*Q. */
        addi a0, s6, 0 /* b */
        addi a1, s5, 0 /* sk */
        addi a2, s9, 0 /* twiddles_basemul */
        addi a3, s7, 0 /* m */
        jal  x1, basemul_acc
        nop
    endloop

    /* Compute m = intt(m). */
    addi    a0, s7, 0 /* m */
    la      a1, twiddles_intt
    addi    a2, a0, 0
    jal     x1, intt
    bn.wsrw mod, w16 /* Restore mod = R | Q */

    /* Unpack v. */
    addi a0, s0, 0 /* ct */
    la   a1, poly_v
    addi a2, s3, 1 /* k */
    jal  x1, poly_decompress

    /* Compute m = v - m. */
    la   a0, poly_v
    la   a1, mpoly_m
    addi a2, a1, 0
    jal  x1, poly_sub

    /* Compute r = poly_tomsg(m). */
    la   a0, mpoly_m
    addi a1, s2, 0 /* ptr_m */
    jal  x1, poly_tomsg
#else
    /* Unpack sk[0]. */
    addi a0, s1, 0
    addi a1, s5, 0 /* sk */
    loopi NSHARES, 4
        /* Whitening. */
        bn.xor  w0, w0, w0
        bn.xor  w1, w1, w1
        jal     x1, poly_frombytes
        nop
    endloop
    addi s1, a0, 0 /* Save address of sk to be unpacked later. */

    /* Refresh sk[0] arithmetic shares (MOD = R | Q here). */
    bn.wsrr w16, mod /* w16 = R | Q. */
    addi    a0, s5, 0
    addi    a2, s5, 0
    jal     x1, refreshmodq

    /* Unpack b.vec[0]. */
    addi      a0, s0, 0 /* ct */
    addi      a1, s6, 0 /* b */
    addi      a2, s3, 0 /* k */
    jal       x1, poly_polyvec_decompress
    addi      s0, a0, 0 /* Save address of ct to be unpacked later. */

    /* Compute b = ntt(b). */
    bn.shv.16h w0, w16 << 1 /* w0 = 2*R | 2*Q */
    bn.wsrw    mod, w0 /* mod = 2*R | 2*Q */
    addi       a0, s6, 0 /* b */
    addi       a1, s8, 0 /* twiddles_ntt */
    addi       a2, a0, 0
    jal        x1, ntt

    /* Compute m = b * sk. */
    addi a1, s5, 0 /* sk */
    addi a2, s9, 0 /* twiddles_basemul */
    addi a3, s7, 0 /* m */
    loopi NSHARES, 4
        jal  x1, whitening
        addi a0, s6, 0 /* poly_b */
        jal  x1, basemul
        nop
    endloop

    /* Loop over j = 1,...,KYBER_K - 1. */
    addi s3, s3, -1 /* k - 1 */
    loop s3, 32
        /* Unpack sk.vec[j]. */
        addi a0, s1, 0 /* sk.vec[j]. */
        addi a1, s5, 0 /* sk */
        loopi NSHARES, 4
            /* Whitening. */
            bn.xor w0, w0, w0
            bn.xor w1, w1, w1
            jal    x1, poly_frombytes
            nop
        endloop
        addi s1, a0, 0 /* Save address of sk.vec[j + 1] to be unpacked later. */

        /* Refresh sk.vec[j] arithmetic shares. */
        bn.wsrw    mod, w16 /* MOD = R | Q. */
        addi       a0, s5, 0
        addi       a2, s5, 0
        jal        x1, refreshmodq
        bn.shv.16h w0, w16 << 1
        bn.wsrw    mod, w0 /* MOD = 2*R | 2*Q. */

        /* Unpack b.vec[j]. */
        /* w16 is still R | Q and mod is still 2*R | 2*Q. */
        addi a0, s0, 0 /* ct */
        addi a1, s6, 0 /* b */
        addi a2, s3, 1 /* k */
        jal  x1, poly_polyvec_decompress
        addi s0, a0, 0 /* Save address of ct to be unpacked later. */

        /* Compute b = ntt(b). */
        /* w16 is still R | Q and mod is still 2*R | 2*Q. */
        addi a0, s6, 0 /* b */
        addi a1, s8, 0 /* twiddles_ntt */
        addi a2, a0, 0
        jal  x1, ntt

        /* Compute m += b * sk. */
        addi a1, s5, 0 /* sk */
        addi a2, s9, 0 /* twiddles_basemul */
        /* w16 is still R | Q and mod is still 2*R | 2*Q. */
        addi a3, s7, 0 /* m */
        loopi NSHARES, 4
            jal  x1, whitening
            addi a0, s6, 0 /* b */
            jal  x1, basemul_acc
            nop
        endloop
        nop
    endloop

    /* Compute m = intt(m). */
    addi a0, s7, 0 /* m */
    la   a1, twiddles_intt
    addi a2, a0, 0
    loopi NSHARES, 3
        jal x1, whitening
        jal x1, intt
        nop
    endloop
    bn.wsrw mod, w16 /* Restore mod = R | Q */

    /* Unpack v. */
    addi a0, s0, 0 /* ct */
    la   a1, poly_v
    addi a2, s3, 1 /* k */
    jal  x1, poly_decompress

    /* Compute m = v - m. */
    la   a0, poly_v
    la   a1, mpoly_m
    addi a2, a1, 0
    jal  x1, poly_sub

    addi   t0, x0, NSHARES
    addi   t0, t0, -1 /* t0 = nshares - 1. */
    bn.xor w0, w0, w0
    loop t0, 5
        loopi N_WDR, 3
            bn.lid       x0, 0(a1)
            bn.subvm.16h w0, w31, w0
            bn.sid       x0, 0(a1++)
        endloop
        /* Whitening. */
        bn.xor w0, w0, w0
    endloop

    /* Compute r = masked_poly_tomsg(m). */
    la   a0, mpoly_m
    addi a2, s2, 0 /* ptr_m */
    jal  x1, masked_poly_tomsg

#endif

    /* Restore sp and fp. */
    addi sp, fp, 0
    lw   fp, 0(sp)
    addi sp, sp, 32
    ret
