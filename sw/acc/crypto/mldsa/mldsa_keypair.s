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

#define SEEDBYTES 32
#define N 256
#define Q 8380417
#define D 13

/* Worst-case (ML-DSA-87) polyvec size. */
#define POLYVECK_BYTES 8192

/* Offsets into the mldsa_params struct (in mldsa_consts.s). */
#define MLDSA_PARAM_K_OFFSET 0
#define MLDSA_PARAM_L_OFFSET 4
#define MLDSA_PARAM_CRYPTO_PUBLICKEYBYTES_OFFSET 24

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

/* Config to start a SHAKE-128 operation. */
#define SHAKE128_CFG 0x2
/* Config to start a SHAKE-256 operation. */
#define SHAKE256_CFG 0xA
/* Config to start a SHA3_256 operation. */
#define SHA3_256_CFG 0x8
/* Config to start a SHA3_512 operation. */
#define SHA3_512_CFG 0x10

/**
 * Dilithium Key Pair generation
 *
 * Returns: 0 on success
 *
 * @param[in]  dmem[zeta]: 32 random bytes
 * @param[in]  dmem[mldsa_params]: active mode parameters
 * @param[out] dmem[pk]: public key
 * @param[out] dmem[sk]: secret key
 *
 * clobbered registers: a0-a6, t0-t5, s1, w0-w30
 */
.globl crypto_sign_keypair
crypto_sign_keypair:
    la   s11, mldsa_params
    lw   s10, MLDSA_PARAM_K_OFFSET(s11)

    /* Initialize a SHAKE256 operation. */
    li    a1, SEEDBYTES
    addi  a1, a1, 2 /* SEEDBYTES+2 */
    slli  t0, a1, 5
    addi  t0, t0, SHAKE256_CFG
    csrrw x0, kmac_cfg, t0

    /* Send zeta to KMAC block. */
    la a0, zeta
    li a1, 32
    jal  x1, keccak_send_message

    /* Send K, L to KMAC block. */
    la      t1, poly_wdr2gpr
    li      t0, 1
    csrrw   x0, kmac_partial_write, t0
    sw      s10, 0(t1)
    bn.lid  x0, 0(t1)
    bn.wsrw kmac_msg, w0
    csrrw   x0, kmac_partial_write, t0
    lw      t2, MLDSA_PARAM_L_OFFSET(s11)
    sw      t2, 0(t1)
    bn.lid  x0, 0(t1)
    bn.wsrw kmac_msg, w0

    /* Squeeze into output buffers. Store rho and the key in sk. */
    la      t0, sk
    bn.wsrr w0, kmac_digest
    bn.sid  x0, 0(t0++)
    la      t1, rhoprime
    bn.wsrr w0, kmac_digest
    bn.sid  x0, 0(t1++)
    bn.wsrr w0, kmac_digest
    bn.sid  x0, 0(t1)
    bn.wsrr w0, kmac_digest
    bn.sid  x0, 0(t0)

    /* Finish the SHAKE-256 operation. */

    bn.wsrr   w16, mod /* w16 = R | Q */
    bn.shv.8S w22, w16 << 1 /* w22 = 2*R | 2*Q */
    bn.wsrw   mod, w22 /* MOD = 2*R | 2*Q */

    /* Load source pointers for matrix-vector multiplication. */
    la  s0, s1_poly
    la  s1, tmp_poly

    /* Load destination pointer for matrix-vector multiplication. */
    la  s2, t_polyvec

    /* Zero the destination buffer. */
    li t0, 31
    addi t1, s2, 0
    LOOP s10, 3
        LOOPI 32, 1
          bn.sid t0, 0(t1++)
        nop

    /* Load offset for resetting vector pointer (K * 1024). */
    slli s3, s10, 10

    /* Initialize the nonce for matrix expansion. This value should be
         byte(i) || byte(j)
       for entry A[i][j]. */
    bn.xor w23, w23, w23

    /* Load pointers to rho and rho'. */
    la  s8, sk
    la  s5, rhoprime

    /* Initialize the nonce for sampling s1. */
    li   s6, 0

    /* Load the destination for packed s1 within the secret key. */
    la   s7, sk
    addi s7, s7, 128

    /* Precompute the SHAKE128 configuration for poly_uniform. */
    addi  s4, x0, 34
    slli  s4, s4, 5
    addi  s4, s4, SHAKE128_CFG

    /* Compute A * s1, computing elements of A on the fly.

       We compute column-wise so that we generate elements of s1 only once; in
       pseudocode, this computation does:

         for j in 0..l-1:
           s1j = ntt(s1[j])
           for i in 0..k-1:
             t[i] += A[i][j] * s1j
    */
    lw t0, MLDSA_PARAM_L_OFFSET(s11)
    LOOP t0, 43
        bn.wsrw   mod, w16 /* MOD = R | Q */
        /* Sample the next polynomial from s1. */
        addi a0, s5, 0
        addi a1, s0, 0
        addi a2, s6, 0
        addi a4, s10, 0
        jal  x1, poly_uniform_eta
        addi s6, s6, 1
        /* Start the SHAKE128 operation for poly_uniform for A[0][j]. */
        csrrw x0, kmac_cfg, s4
        addi  a0, s8, 0
        bn.lid    x0, 0(a0)
        bn.wsrw   kmac_msg, w0
        addi      t0, x0, 2
        csrrw     x0, kmac_partial_write, t0
        bn.wsrw   kmac_msg, w23
        /* Pack the s1 polynomial into the secret key. */
        addi a0, s7, 0
        addi a1, s0, 0
        addi a4, s10, 0
        jal x1, polyeta_pack
        addi s7, a0, 0
        bn.wsrw   mod, w22 /* MOD = 2*R | 2*Q */
        /* Compute ntt(s1[j]). */
        addi a0, s0, 0
        addi a2, s0, 0
        jal  x1, ntt
        LOOP s10, 15
            /* Compute A[i][j]. */
            addi a1, s1, 0
            jal  x1, poly_uniform
            /* Increment the row in the matrix nonce (upper byte). */
            bn.addi w23, w23, 256
            /* Start the SHAKE128 operation for poly_uniform for A[i+1][j]. */
            csrrw x0, kmac_cfg, s4
            addi  a0, s8, 0
            bn.lid    x0, 0(a0)
            bn.wsrw   kmac_msg, w0
            addi      t0, x0, 2
            csrrw     x0, kmac_partial_write, t0
            bn.wsrw   kmac_msg, w23
            /* Compute A[i][j] * s1[j] and add it to the output at index i. */
            addi a0, s0, 0
            addi a1, s1, 0
            addi a2, s2, 0
            jal  x1, poly_pointwise_acc
            /* Increment the output vector pointer *t. */
            addi s2, s2, 1024
        /* Reset output vector pointer. */
        sub  s2, s2, s3
        /* Increment the column index in the nonce by one. */
        bn.addi w23, w23, 1
        /* Reset the row index in the nonce to zero. */
        bn.rshi w23, w23, bn0 >> 8
        bn.rshi w23, bn0, w23 >> 248

    /* After poly_pointwise, w16 is still R | Q and MOD is still 2*R | 2*Q */
    /* Inverse NTT on t=A*s1 */
    la  a0, t_polyvec

    LOOP s10, 2
        jal  x1, intt
        addi a0, a0, 1024 /* Go to next input polynomial */
    bn.wsrw 0x0, w16 /* Restore MOD = R | Q */

    /* Load pointers for loop. */
    la  s0, tmp_poly
    la  s1, t_polyvec
    la  s3, rhoprime

    /* Initialize the nonce for sampling s2. */
    lw s6, MLDSA_PARAM_L_OFFSET(s11)

    /* This loop samples s2 and adds it to A*s1 (currently in the t buffer). */
    LOOP s10, 16
        /* Sample the next polynomial from s2 and store in temp buffer. */
        addi a0, s3, 0
        addi a1, s0, 0
        addi a2, s6, 0
        addi a4, s10, 0
        jal  x1, poly_uniform_eta
        addi s6, s6, 1
        /* Pack the s2 polynomial into the secret key. */
        addi a0, s7, 0
        addi a1, s0, 0
        addi a4, s10, 0
        jal  x1, polyeta_pack
        addi s7, a0, 0
        /* t[i] += s2 */
        addi a0, s0, 0
        addi a1, s1, 0
        addi a2, s1, 0
        jal  x1, poly_add
        /* Increment polyvec pointer *t. */
        addi s1, s1, 1024

    /* Reset t pointer for power2round loop. */
    la  s1, t_polyvec

    LOOP s10, 9
        /* Split t polynomial into t0 (tmp buffer) and t1 (t buffer). */
        addi a0, s1, 0
        addi a1, s0, 0
        addi a2, s1, 0
        jal  x1, poly_power2round
        /* Pack the t0 polynomial into secret key. */
        addi a0, s7, 0
        addi a1, s0, 0
        jal  x1, polyt0_pack
        addi s7, a0, 0
        /* Increment polyvec pointer *t. */
        addi s1, s1, 1024

    /* Pack pk. */
    la a0, pk

    /* Copy rho from secret key. */
    la     t1, sk
    bn.lid x0, 0(t1)
    bn.sid x0, 0(a0++)

    /* Load pointer to t1 */
    la  a1, t_polyvec

    /* Pack t1 */
    LOOP s10, 2
        jal x1, polyt1_pack
        nop

    /* Hash pk */

    /* Initialize a SHAKE256 operation. */
    lw    a1, MLDSA_PARAM_CRYPTO_PUBLICKEYBYTES_OFFSET(s11)
    slli  t0, a1, 5
    addi  t0, t0, SHAKE256_CFG
    csrrw x0, kmac_cfg, t0

    /* Send the message to the Keccak core. */
    la     a0, pk
    jal  x1, keccak_send_message

    /* Read the digest (tr) into the secret key.
       dmem[sk+64] <= SHAKE256(pk, 64) */
    la      t0, sk
    bn.wsrr w0, kmac_digest
    bn.sid  x0, 64(t0)
    bn.wsrr w0, kmac_digest
    bn.sid  x0, 96(t0)

    /* Finish the SHAKE-256 operation. */

    ret
