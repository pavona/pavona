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
#define NB_POLY 512

/* Register aliases */
.equ x2, sp
.equ x3, fp
.equ x5, t0
#define t1 x6
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


/* Config to start a SHA3_512 operation. */
#define SHA3_512_CFG 0x10

/*
 * Name:        indcpa_keypair
 *
 * Description: Generates public and private key for the CPA-secure
 *              public-key encryption scheme underlying Kyber
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10 (a0): pointer to seed (KYBER_SYMBYTES = 32)
 * @param[out] x11 (a1): dmem pointer to public key pk_addr
 * @param[out] x12 (a2): dmem pointer to secret key sk_addr
 * @param[in]  x13 (a3): k, the security level
 *
 * clobbered registers: a0-a4, t0-t5, w8, w16
 */
.globl indcpa_keypair
.type indcpa_keypair, @function
indcpa_keypair:
#ifndef HARDENED
    addi s1, a1, 0
    addi s2, a2, 0
    addi s3, a3, 0

    addi x4, x0, 2
    beq  s3, x4, _handle_k2_eta_1
    addi s4, x0, 2
    beq  x0, x0, _continue
_handle_k2_eta_1:
    addi s4, x0, 3
_continue:

    /* Compute G(seed || k). */
    /* Initialize a SHA3-512 operation. */
    addi    a1, x0, 33
    slli    t0, a1, 5
    addi    t0, t0, SHA3_512_CFG
    csrrw   x0, kmac_cfg, t0

    bn.lid  x0, 0(a0)
    bn.wsrw kmac_msg, w0
    addi    t0, x0, 1
    csrrw   x0, kmac_partial_write, t0
    la      t0, buf
    bn.xor  w0, w0, w0
    bn.sid  x0, 0(t0)
    sw      a3, 0(t0)
    bn.lid  x0, 0(t0)
    bn.wsrw kmac_msg, w0
    bn.wsrr w0, kmac_digest
    bn.sid  x0, 0(t0++)
    bn.wsrr w0, kmac_digest
    bn.sid  x0, 0(t0)

    /* Generate sk. */
    la     s0, buf
    la     s5, nonce
    bn.xor w0, w0, w0
    bn.sid x0, 0(s5)
    /* Prepare for generating sk[0]. */
    addi   a0, s0, 32 /* noiseseed */
    addi   a1, s5, 0 /* nonce */
    jal    x1, poly_getnoise_eta_init
    la     s6, mpolyvec_sk
    la     s7, twiddles_ntt

    addi s3, s3, -1 /* k - 1 */
    loop s3, 22
        /* Generate sk[i]. */
        addi   a0, s4, 0 /* ETA1 */
        addi   a1, s6, 0
        jal    x1, poly_getnoise_eta_1
        /* Prepare for generating sk[i + 1]. */
        addi   a0, s0, 32 /* noiseseed */
        addi   a1, s5, 0 /* nonce */
        lw     t0, 0(a1)
        addi   t0, t0, 1
        sw     t0, 0(a1)
        jal    x1, poly_getnoise_eta_init
        /* Compute sk[i] = ntt(sk[i]). */
        bn.wsrr    w16, mod /* w16 = R | Q */
        bn.shv.16h w0, w16 << 1
        bn.wsrw    mod, w0 /* mod = 2 * R | 2 * Q */
        addi       a0, s6, 0
        addi       a1, s7, 0
        addi       a2, a0, 0
        jal        x1, ntt
        bn.wsrw    mod, w16 /* Reset mod = R | Q. */
        /* Pack sk[i]. */
        addi   a0, s6, 0
        addi   a1, s2, 0
        jal    x1, poly_tobytes
        /* Update addresses. */
        addi   s6, a0, 0 /* Point to sk[i + 1]. */
        addi   s2, a1, 0 /* Point to next slot for packed sk. */
    endloop

    /* Generate sk[k - 1]. */
    addi   a0, s4, 0 /* ETA1 */
    addi   a1, s6, 0
    jal    x1, poly_getnoise_eta_1

    /* Compute sk[k - 1] = ntt(sk[k - 1]). */
    bn.wsrr    w16, mod /* w16 = R | Q */
    bn.shv.16h w0, w16 << 1
    bn.wsrw    mod, w0 /* mod = 2 * R | 2 * Q */
    addi       a0, s6, 0
    addi       a1, s7, 0
    addi       a2, a0, 0
    jal        x1, ntt
    bn.wsrw    mod, w16 /* Reset mod = R | Q. */

    /* Prepare for generating a[0][0]. */
    addi   a0, s0, 0 /* publicseed */
    la     a1, seed_ij
    bn.xor w0, w0, w0
    bn.sid x0, 0(a1)
    jal    x1, poly_gen_matrix_init

    /* Pack sk[k - 1]. */
    addi   a0, s6, 0
    addi   a1, s2, 0
    jal    x1, poly_tobytes

    /* Save current addresses of sk. */
    la t0, dptr_sk
    sw a1, 0(t0)

    /* The following block will do:
     *  - (1) generate a[i][0],
     *  - (2) compute pk = a[i][0] * sk[0],
     *  - (3) generate a[i][j],
     *  - (4) compute pk += a[i][j] * sk[j],
     *  - (5) repeat (3) + (4) for j = 1,...,k-1.
     *  - (6) compute pk = poly_tomont(pk),
     *  - (7) generate e[i],
     *  - (8) compute e[i] = ntt(e[i]),
     *  - (9) compute pk += e[i],
     *  - (10) pack pk,
     *  - (11) repeat (1) to (10) for i = 0,..,k-1.*/

    la   s5, nonce
    la   s6, mpolyvec_sk
    la   s7, twiddles_basemul
    la   s8, seed_ij
    la   s9, poly_at /* also poly_e */
    la   s10, mpoly_pk

    addi s2, s3, -1 /* k - 2 (s3 = k - 1) */
    addi t0, x0, 0x0100
    sub  s11, t0, s3 /* 0x0100 - (k - 1) */

    loop s3, 80
        /* Generate a[i][0]. */
        addi a1, s9, 0
        jal  x1, poly_gen_matrix

        /* Prepare for generating a[i][1]. */
        addi a0, s0, 0
        addi a1, s8, 0
        lw   t0, 0(a1)
        addi t0, t0, 1
        sw   t0, 0(a1)
        jal  x1, poly_gen_matrix_init

        /* Compute pk = a * sk[0]. */
        bn.wsrr    w16, mod /* w16 = R | Q */
        bn.shv.16h w0, w16 << 1
        bn.wsrw    mod, w0 /* mod = 2*R | 2*Q */
        addi       a0, s9, 0
        la         s6, mpolyvec_sk
        addi       a1, s6, 0
        addi       a2, s7, 0
        addi       a3, s10, 0
        jal        x1, basemul
        addi       s6, a1, 0 /* Point to sk[1]. */

        /* Skip the middle columns when k = 2 (s2 = k - 2 = 0); a hardware
         * loop must have a non-zero iteration count. */
        beq  s2, x0, _skip_inner_cols
        loop s2, 14
            /* Generate a[i][j]. */
            addi a1, s9, 0
            jal  x1, poly_gen_matrix

            /* Prepare for generating a[i][j + 1]. */
            addi a0, s0, 0
            addi a1, s8, 0
            lw   t0, 0(a1)
            addi t0, t0, 1
            sw   t0, 0(a1)
            jal  x1, poly_gen_matrix_init

            /* Compute pk += a * sk[j]. */
            addi a0, s9, 0
            addi a1, s6, 0
            addi a2, s7, 0
            addi a3, s10, 0
            jal  x1, basemul_acc
            addi s6, a1, 0 /* Point to sk[j + 1]. */
        endloop
        _skip_inner_cols:

        /* Generate a[i][k - 1]. */
        addi a1, s9, 0
        jal  x1, poly_gen_matrix

        /* Prepare for generating e[i]. */
        addi a0, s0, 32
        addi a1, s5, 0
        lw   t0, 0(a1)
        addi t0, t0, 1
        sw   t0, 0(a1)
        jal  x1, poly_getnoise_eta_init

        /* Compute pk += a * sk[k - 1]. */
        addi    a0, s9, 0
        addi    a1, s6, 0
        addi    a2, s7, 0
        addi    a3, s10, 0
        jal     x1, basemul_acc
        bn.wsrw mod, w16 /* Restore mod = R | Q. */

        /* Generate e[i]. */
        addi a0, s4, 0 /* ETA1 */
        la   a1, mpoly_e
        jal  x1, poly_getnoise_eta_1

        /* Prepare for generating a[i + 1][0]. */
        addi a0, s0, 0
        addi a1, s8, 0
        lw   t0, 0(a1)
        add  t0, t0, s11
        sw   t0, 0(a1)
        jal  x1, poly_gen_matrix_init

        /* Compute pk = tomont(pk). */
        addi a0, s10, 0
        jal  x1, poly_tomont

        /* Compute e[i] = ntt(e[i]). */
        bn.wsrr    w16, mod
        bn.shv.16h w0, w16 << 1
        bn.wsrw    mod, w0
        la         a0, mpoly_e
        la         a1, twiddles_ntt
        addi       a2, a0, 0
        jal        x1, ntt
        bn.wsrw    mod, w16

        /* Compute pk += e[i]. */
        addi a0, s10, 0
        la   a1, mpoly_e
        addi a2, s10, 0
        jal  x1, poly_add

        /* Pack pk. */
        addi a0, s10, 0
        addi a1, s1, 0
        jal  x1, poly_tobytes
        addi s1, a1, 0 /* Point to next slot for packed pk. */
    endloop

    /* Generate a[k - 1][0]. */
    addi a1, s9, 0
    jal  x1, poly_gen_matrix

    /* Prepare for generating a[k - 1][1]. */
    addi a0, s0, 0
    addi a1, s8, 0
    lw   t0, 0(a1)
    addi t0, t0, 1
    sw   t0, 0(a1)
    jal  x1, poly_gen_matrix_init

    /* Compute pk = a * sk[0]. */
    bn.wsrr    w16, mod /* w16 = R | Q */
    bn.shv.16h w0, w16 << 1
    bn.wsrw    mod, w0 /* mod = 2*R | 2*Q */
    addi       a0, s9, 0
    la         s6, mpolyvec_sk
    addi       a1, s6, 0
    addi       a2, s7, 0
    addi       a3, s10, 0
    jal        x1, basemul
    addi       s6, a1, 0 /* Point to sk[1]. */

    /* Skip the middle columns when k = 2 (s2 = k - 2 = 0); a hardware
     * loop must have a non-zero iteration count. */
    beq  s2, x0, _skip_inner_cols_tail
    loop s2, 14
        /* Generate a[k - 1][j]. */
        addi a1, s9, 0
        jal  x1, poly_gen_matrix

        /* Prepare for generating a[k - 1][j + 1]. */
        addi a0, s0, 0
        addi a1, s8, 0
        lw   t0, 0(a1)
        addi t0, t0, 1
        sw   t0, 0(a1)
        jal  x1, poly_gen_matrix_init

        /* Compute pk += a * sk[j]. */
        addi a0, s9, 0
        addi a1, s6, 0
        addi a2, s7, 0
        addi a3, s10, 0
        jal  x1, basemul_acc
        addi s6, a1, 0 /* Point to sk[j + 1]. */
    endloop
    _skip_inner_cols_tail:

    /* Generate a[k - 1][k - 1]. */
    addi a1, s9, 0
    jal  x1, poly_gen_matrix

    /* Prepare for generating e[k - 1]. */
    addi a0, s0, 32
    addi a1, s5, 0
    lw   t0, 0(a1)
    addi t0, t0, 1
    sw   t0, 0(a1)
    jal  x1, poly_getnoise_eta_init

    /* Compute pk += a * sk[k - 1]. */
    addi    a0, s9, 0
    addi    a1, s6, 0
    addi    a2, s7, 0
    addi    a3, s10, 0
    jal     x1, basemul_acc
    bn.wsrw mod, w16 /* Restore mod = R | Q. */

    /* Generate e[k - 1]. */
    addi a0, s4, 0 /* ETA1 */
    la   a1, mpoly_e
    jal  x1, poly_getnoise_eta_1

    /* Compute pk = tomont(pk). */
    addi a0, s10, 0
    jal  x1, poly_tomont

    /* Compute e[k - 1] = ntt(e[k - 1]). */
    bn.wsrr    w16, mod
    bn.shv.16h w0, w16 << 1
    bn.wsrw    mod, w0
    la         a0, mpoly_e
    la         a1, twiddles_ntt
    addi       a2, a0, 0
    jal        x1, ntt
    bn.wsrw    mod, w16

    /* Compute pk += e[k - 1]. */
    addi a0, s10, 0
    la   a1, mpoly_e
    addi a2, s10, 0
    jal  x1, poly_add

    /* Pack pk. */
    addi a0, s10, 0
    addi a1, s1, 0
    jal  x1, poly_tobytes


_handle_common:

    /* Save publicseed. */
    la     t0, buf
    bn.lid x0, 0(t0)
    bn.sid x0, 0(a1)
    ret

#else
    addi s1, a1, 0
    addi s2, a2, 0
    addi s3, a3, 0

    addi x4, x0, 2
    beq  s3, x4, _handle_k2_eta_1
    addi s4, x0, 2
    beq  x0, x0, _continue
_handle_k2_eta_1:
    addi s4, x0, 3
_continue:

    /* Compute G(seed || k). */
    /* Initialize a SHA3-512 operation. */
    addi    a1, x0, 33
    slli    t0, a1, 5
    addi    t0, t0, SHA3_512_CFG
    addi    t1, x0, 1
    slli    t1, t1, 20
    add     t0, t0, t1
    csrrw   x0, kmac_cfg, t0

    bn.xor  w0, w0, w0 /* Whitening. */
    bn.lid  x0, 0(a0++)
    bn.wsrw kmac_msg, w0
    bn.xor  w0, w0, w0 /* Whitening. */
    bn.lid  x0, 0(a0)
    bn.wsrw kmac_msg1, w0
    addi    t0, x0, 1
    csrrw   x0, kmac_partial_write, t0
    la      t0, buf
    bn.xor  w0, w0, w0
    bn.sid  x0, 0(t0)
    sw      a3, 0(t0)
    bn.lid  x0, 0(t0)
    bn.wsrw kmac_msg, w0
    bn.xor  w0, w0, w0
    bn.wsrw kmac_msg1, w0
    /* Read publicseed. */
    bn.wsrr w0, kmac_digest
    bn.wsrr w1, kmac_digest1
    bn.xor  w0, w0, w1
    bn.sid  x0, 0(t0++)
    /* Read noiseseed. */
    bn.xor  w0, w0, w0 /* Whitening. */
    bn.wsrr w0, kmac_digest
    bn.sid  x0, 0(t0++)
    bn.xor  w0, w0, w0 /* Whitening. */
    bn.wsrr w0, kmac_digest1
    bn.sid  x0, 0(t0++)

    /* Generate sk. */
    la     s0, buf
    la     s5, nonce
    bn.xor w0, w0, w0
    bn.sid x0, 0(s5)
    /* Prepare for generating sk[0]. */
    addi   a0, s0, 32 /* noiseseed */
    addi   a1, s5, 0 /* nonce */
    jal    x1, masked_poly_getnoise_eta_init
    la     s6, mpolyvec_sk
    la     s7, twiddles_ntt

    addi s3, s3, -1 /* k - 1 */
    loop s3, 29
        /* Generate sk[i]. */
        addi   a0, s4, 0 /* ETA1 */
        addi   a1, s6, 0
        jal    x1, masked_poly_getnoise_eta_1

        /* Prepare for generating sk[i + 1]. */
        addi   a0, s0, 32 /* noiseseed */
        addi   a1, s5, 0 /* nonce */
        lw     t0, 0(a1)
        addi   t0, t0, 1
        sw     t0, 0(a1)
        jal    x1, masked_poly_getnoise_eta_init

        /* Compute sk[i] = ntt(sk[i]). */
        bn.wsrr    w16, mod /* w16 = R | Q */
        bn.shv.16h w0, w16 << 1
        bn.wsrw    mod, w0 /* mod = 2 * R | 2 * Q */
        addi       a0, s6, 0
        addi       a1, s7, 0
        addi       a2, a0, 0
        loopi NSHARES, 3
            jal x1, whitening
            jal x1, ntt
            nop
        endloop
        bn.wsrw mod, w16 /* Reset mod = R | Q. */

        /* Pack sk[i]. */
        addi   a0, s6, 0
        addi   a1, s2, 0
        loopi NSHARES, 4
            /* Whitening. */
            bn.xor w0, w0, w0
            bn.xor w1, w1, w1
            jal x1, poly_tobytes
            nop
        endloop

        /* Update addresses. */
        addi s6, a0, 0 /* Point to sk[i + 1]. */
        addi s2, a1, 0 /* Point to next slot for packed sk. */
    endloop

    /* Generate sk[k - 1]. */
    addi   a0, s4, 0 /* ETA1 */
    addi   a1, s6, 0
    jal    x1, masked_poly_getnoise_eta_1

    /* Compute sk[k - 1] = ntt(sk[k - 1]). */
    bn.wsrr    w16, mod /* w16 = R | Q */
    bn.shv.16h w0, w16 << 1
    bn.wsrw    mod, w0 /* mod = 2 * R | 2 * Q */

    addi a0, s6, 0
    addi a1, s7, 0
    addi a2, a0, 0
    loopi NSHARES, 3
        jal x1, whitening
        jal x1, ntt
        nop
    endloop
    bn.wsrw mod, w16 /* Reset mod = R | Q. */

    /* Prepare for generating a[0][0]. */
    addi   a0, s0, 0 /* publicseed */
    la     a1, seed_ij
    bn.xor w0, w0, w0
    bn.sid x0, 0(a1)
    jal    x1, poly_gen_matrix_init

    /* Pack sk[k - 1]. */
    addi a0, s6, 0
    addi a1, s2, 0
    loopi NSHARES, 4
        /* Whitening. */
        bn.xor w0, w0, w0
        bn.xor w1, w1, w1
        jal    x1, poly_tobytes
        nop
    endloop

    /* Save current addresses of sk. */
    la t0, dptr_sk
    sw a1, 0(t0)

    /* The following block will do:
     *  - (1) generate a[i][0],
     *  - (2) compute pk = a[i][0] * sk[0],
     *  - (3) generate a[i][j],
     *  - (4) compute pk += a[i][j] * sk[j],
     *  - (5) repeat (3) + (4) for j = 1,...,k-1.
     *  - (6) compute pk = poly_tomont(pk),
     *  - (7) generate e[i],
     *  - (8) compute e[i] = ntt(e[i]),
     *  - (9) compute pk += e[i],
     *  - (10) pack pk,
     *  - (11) repeat (1) to (10) for i = 0,..,k-1.*/

    la   s5, nonce
    la   s6, mpolyvec_sk
    la   s7, twiddles_basemul
    la   s8, seed_ij
    la   s9, poly_at /* also poly_e */
    la   s10, mpoly_pk

    addi s2, s3, -1 /* k - 2 (s3 = k - 1) */
    addi t0, x0, 0x0100
    sub  s11, t0, s3 /* 0x0100 - (k - 1) */

    loop s3, 111
        /* Generate a[i][0]. */
        addi a1, s9, 0
        jal  x1, poly_gen_matrix

        /* Prepare for generating a[i][1]. */
        addi a0, s0, 0
        addi a1, s8, 0
        lw   t0, 0(a1)
        addi t0, t0, 1
        sw   t0, 0(a1)
        jal  x1, poly_gen_matrix_init

        /* Compute pk = a * sk[0]. */
        bn.wsrr    w16, mod /* w16 = R | Q */
        bn.shv.16h w0, w16 << 1
        bn.wsrw    mod, w0 /* mod = 2*R | 2*Q */

        addi a0, s9, 0
        la   a1, mpolyvec_sk
        addi a2, s7, 0
        addi a3, s10, 0
        loopi NSHARES, 3
            jal  x1, whitening
            jal  x1, basemul
            addi a0, s9, 0
        endloop
        addi s6, a1, 0 /* Point to sk[1]. */

        /* Skip the middle columns when k = 2 (s2 = k - 2 = 0); a hardware
         * loop must have a non-zero iteration count. */
        beq  s2, x0, _skip_inner_cols
        loop s2, 17
            /* Generate a[i][j]. */
            addi a1, s9, 0
            jal  x1, poly_gen_matrix

            /* Prepare for generating a[i][j + 1]. */
            addi a0, s0, 0
            addi a1, s8, 0
            lw   t0, 0(a1)
            addi t0, t0, 1
            sw   t0, 0(a1)
            jal  x1, poly_gen_matrix_init

            /* Compute pk += a * sk[j]. */
            addi a0, s9, 0
            addi a1, s6, 0
            addi a2, s7, 0
            addi a3, s10, 0
            loopi NSHARES, 3
                jal  x1, whitening
                jal  x1, basemul_acc
                addi a0, s9, 0
            endloop
            addi s6, a1, 0 /* Point to sk[j + 1]. */
        endloop
        _skip_inner_cols:

        /* Generate a[i][k - 1]. */
        addi a1, s9, 0
        jal  x1, poly_gen_matrix

        /* Prepare for generating e[i]. */
        addi a0, s0, 32
        addi a1, s5, 0
        lw   t0, 0(a1)
        addi t0, t0, 1
        sw   t0, 0(a1)
        jal  x1, masked_poly_getnoise_eta_init

        /* Compute pk += a * sk[k - 1]. */
        addi a0, s9, 0
        addi a1, s6, 0
        addi a2, s7, 0
        addi a3, s10, 0
        loopi NSHARES, 3
            jal  x1, whitening
            jal  x1, basemul_acc
            addi a0, s9, 0
        endloop
        bn.wsrw mod, w16 /* Restore mod = R | Q. */

        /* Generate e[i]. */
        addi a0, s4, 0 /* ETA1 */
        la   a1, mpoly_e
        jal  x1, masked_poly_getnoise_eta_1

        /* Prepare for generating a[i + 1][0]. */
        addi a0, s0, 0
        addi a1, s8, 0
        lw   t0, 0(a1)
        add  t0, t0, s11
        sw   t0, 0(a1)
        jal  x1, poly_gen_matrix_init

        /* Compute pk = tomont(pk). */
        addi a0, s10, 0
        loopi NSHARES, 4
            /* Whitening. */
            bn.xor w0, w0, w0
            bn.xor w1, w1, w1
            jal    x1, poly_tomont
            nop
        endloop

        /* Compute e[i] = ntt(e[i]). */
        bn.wsrr    w16, mod
        bn.shv.16h w0, w16 << 1
        bn.wsrw    mod, w0

        la   a0, mpoly_e
        la   a1, twiddles_ntt
        addi a2, a0, 0
        loopi NSHARES, 3
            jal x1, whitening
            jal x1, ntt
            nop
        endloop

        /* Compute pk += e[i]. */
        addi a0, s10, 0
        la   a1, mpoly_e
        addi a2, s10, 0
        loopi NSHARES, 4
            /* Whitening. */
            bn.xor w0, w0, w0
            bn.xor w1, w1, w1
            jal    x1, poly_add
            nop
        endloop

        /* Unmask pk. */
        addi x4, x0, 1
        addi t0, s10, 0
        addi t1, x0, NSHARES
        addi t1, t1, -1
        loopi N_WDR, 7
            addi   t2, t0, NB_POLY
            bn.lid x0, 0(t0)
            loop t1, 3
                bn.lid       x4, 0(t2)
                bn.addvm.16h w0, w0, w1
                addi         t2, t2, NB_POLY
            endloop
            bn.sid x0, 0(t0++)
        endloop

        bn.wsrw mod, w16

        /* Pack pk. */
        addi a0, s10, 0
        addi a1, s1, 0
        jal  x1, poly_tobytes
        addi s1, a1, 0 /* Point to next slot for packed pk. */
    endloop

    /* Generate a[k - 1][0]. */
    addi a1, s9, 0
    jal  x1, poly_gen_matrix

    /* Prepare for generating a[k - 1][1]. */
    addi a0, s0, 0
    addi a1, s8, 0
    lw   t0, 0(a1)
    addi t0, t0, 1
    sw   t0, 0(a1)
    jal  x1, poly_gen_matrix_init

    /* Compute pk = a * sk[0]. */
    bn.wsrr    w16, mod /* w16 = R | Q */
    bn.shv.16h w0, w16 << 1
    bn.wsrw    mod, w0 /* mod = 2*R | 2*Q */

    addi a0, s9, 0
    la   a1, mpolyvec_sk
    addi a2, s7, 0
    addi a3, s10, 0
    loopi NSHARES, 3
        jal  x1, whitening
        jal  x1, basemul
        addi a0, s9, 0
    endloop
    addi s6, a1, 0 /* Point to sk[1]. */

    /* Skip the middle columns when k = 2 (s2 = k - 2 = 0); a hardware
     * loop must have a non-zero iteration count. */
    beq  s2, x0, _skip_inner_cols_tail
    loop s2, 17
        /* Generate a[k - 1][j]. */
        addi a1, s9, 0
        jal  x1, poly_gen_matrix

        /* Prepare for generating a[k - 1][j + 1]. */
        addi a0, s0, 0
        addi a1, s8, 0
        lw   t0, 0(a1)
        addi t0, t0, 1
        sw   t0, 0(a1)
        jal  x1, poly_gen_matrix_init

        /* Compute pk += a * sk[j]. */
        addi a0, s9, 0
        addi a1, s6, 0
        addi a2, s7, 0
        addi a3, s10, 0
        loopi NSHARES, 3
            jal  x1, whitening
            jal  x1, basemul_acc
            addi a0, s9, 0
        endloop
        addi s6, a1, 0 /* Point to sk[j + 1]. */
    endloop
    _skip_inner_cols_tail:

    /* Generate a[k - 1][k - 1]. */
    addi a1, s9, 0
    jal  x1, poly_gen_matrix

    /* Prepare for generating e[k - 1]. */
    addi a0, s0, 32
    addi a1, s5, 0
    lw   t0, 0(a1)
    addi t0, t0, 1
    sw   t0, 0(a1)
    jal  x1, masked_poly_getnoise_eta_init

    /* Compute pk += a * sk[k - 1]. */
    addi a0, s9, 0
    addi a1, s6, 0
    addi a2, s7, 0
    addi a3, s10, 0
    loopi NSHARES, 3
        jal  x1, whitening
        jal  x1, basemul_acc
        addi a0, s9, 0
    endloop
    bn.wsrw mod, w16 /* Restore mod = R | Q. */

    /* Generate e[k - 1]. */
    addi a0, s4, 0 /* ETA1 */
    la   a1, mpoly_e
    jal  x1, masked_poly_getnoise_eta_1

    /* Compute pk = tomont(pk). */
    addi a0, s10, 0
    loopi NSHARES, 4
        /* Whitening. */
        bn.xor w0, w0, w0
        bn.xor w1, w1, w1
        jal    x1, poly_tomont
        nop
    endloop

    /* Compute e[k - 1] = ntt(e[k - 1]). */
    bn.wsrr    w16, mod
    bn.shv.16h w0, w16 << 1
    bn.wsrw    mod, w0

    la   a0, mpoly_e
    la   a1, twiddles_ntt
    addi a2, a0, 0
    loopi NSHARES, 3
        jal x1, whitening
        jal x1, ntt
        nop
    endloop

    /* Compute pk += e[k - 1]. */
    addi a0, s10, 0
    la   a1, mpoly_e
    addi a2, s10, 0
    loopi NSHARES, 4
        /* Whitening. */
        bn.xor w0, w0, w0
        bn.xor w1, w1, w1
        jal    x1, poly_add
        nop
    endloop

    /* Unmask pk. */
    addi x4, x0, 1
    addi t0, s10, 0
    addi t1, x0, NSHARES
    addi t1, t1, -1
    loopi N_WDR, 7
        addi   t2, t0, NB_POLY
        bn.lid x0, 0(t0)
        loop t1, 3
            bn.lid       x4, 0(t2)
            bn.addvm.16h w0, w0, w1
            addi         t2, t2, NB_POLY
        endloop
        bn.sid x0, 0(t0++)
    endloop

    bn.wsrw mod, w16

    /* Pack pk. */
    addi a0, s10, 0
    addi a1, s1, 0
    jal  x1, poly_tobytes


_handle_common:

    /* Save publicseed. */
    la     t0, buf
    bn.lid x0, 0(t0)
    bn.sid x0, 0(a1)
    ret

#endif
