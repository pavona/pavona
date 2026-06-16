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
#define CRHBYTES 64
#define TRBYTES 64
#define N 256
#define Q 8380417
#define D 13

/* Worst-case (ML-DSA-87) polyvec sizes for static buffers. */
#define POLYVECK_BYTES 8192
#define POLYVECL_BYTES 7168

/* Offsets into the mldsa_params struct (in mldsa_consts.s). */
#define MLDSA_PARAM_K_OFFSET 0
#define MLDSA_PARAM_L_OFFSET 4
#define MLDSA_PARAM_TAU_OFFSET 8
#define MLDSA_PARAM_OMEGA_OFFSET 12
#define MLDSA_PARAM_GAMMA1_MINUS_BETA_OFFSET 16
#define MLDSA_PARAM_POLYW1_PACKEDBYTES_OFFSET 20
#define MLDSA_PARAM_CRYPTO_PUBLICKEYBYTES_OFFSET 24
#define MLDSA_PARAM_CRYPTO_BYTES_OFFSET 44

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

/* Index of the Keccak command special register. */
#define KECCAK_CFG_REG 0x7d9
/* Config to start a SHAKE-128 operation. */
#define SHAKE128_CFG 0x2
/* Config to start a SHAKE-256 operation. */
#define SHAKE256_CFG 0xA
/* Config to start a SHA3_256 operation. */
#define SHA3_256_CFG 0x8
/* Config to start a SHA3_512 operation. */
#define SHA3_512_CFG 0x10

/**
 * Dilithium Verify
 *
 * Returns: 0 on success
 *
 * All input DMEM buffers must be 32-byte aligned and initialized up to the
 * next 32B boundary so wide-reads succeed.
 *
 * @param[in] x10: *sig, pointer to signature in DMEM
 * @param[in] dmem[msg]: message
 * @param[in] x11: byte-length of message
 * @param[in] dmem[ctx]: context value (0-256B)
 * @param[in] x12: byte-length of context
 * @param[in] dmem[mldsa_params]: active mode parameters
 * @param[in] dmem[pk]: public key
 * @param[out] dmem[result]: 0 on success, 0xffffff on failure
 *
 */
.globl crypto_sign_verify_internal
crypto_sign_verify_internal:
    la   s11, mldsa_params

    /* Save signature pointer. */
    la  t0, dptr_sig
    sw  a0, 0(t0)

    /* Unpack sig */

    /* Unpack ctilde. CTILDEBYTES depends on K (= K*8 bytes). */
    la  t0, dptr_sig
    lw  t0, 0(t0)
    la  t1, ctilde
    lw  t2, MLDSA_PARAM_K_OFFSET(s11)
    li  t3, 4
    beq t2, t3, _ctilde_unpack_44
    li  t3, 6
    beq t2, t3, _ctilde_unpack_65
    /* ML-DSA-87 (K=8, CTILDEBYTES=64): two 32B copies. */
    bn.lid x0, 0(t0++)
    bn.sid x0, 0(t1++)
    bn.lid x0, 0(t0++)
    bn.sid x0, 0(t1++)
    jal x0, _ctilde_unpack_done
_ctilde_unpack_44:
    /* ML-DSA-44 (K=4, CTILDEBYTES=32): one 32B copy. */
    bn.lid x0, 0(t0++)
    bn.sid x0, 0(t1++)
    jal x0, _ctilde_unpack_done
_ctilde_unpack_65:
    /* ML-DSA-65 (K=6, CTILDEBYTES=48): the signature is not 32-byte aligned,
       so copy using GPRs. Zero-pad the remaining 16B to avoid bignum load
       errors at the later compare. */
    LOOPI 12, 4
        lw t3, 0(t0)
        sw t3, 0(t1)
        addi t0, t0, 4
        addi t1, t1, 4
    LOOPI 4, 2
        sw x0, 0(t1)
        addi t1, t1, 4
_ctilde_unpack_done:

    /* z is not 32-byte aligned for ML-DSA-65: GPR-copy it into w1_polyvec and
       unpack from there. z_bytes = CRYPTO_BYTES - CTILDEBYTES - OMEGA - K. */
    lw   t1, MLDSA_PARAM_CRYPTO_BYTES_OFFSET(s11)
    lw   t2, MLDSA_PARAM_K_OFFSET(s11)
    slli t3, t2, 3   /* CTILDEBYTES = K*8 */
    sub  t1, t1, t3
    lw   t3, MLDSA_PARAM_OMEGA_OFFSET(s11)
    sub  t1, t1, t3
    sub  t1, t1, t2  /* z_bytes (multiple of 4) */
    srli t1, t1, 2
    addi s9, t0, 0   /* walk the sig z-region; ends at the hint */
    la   a0, w1_polyvec
    LOOP t1, 4
        lw   t2, 0(s9)
        sw   t2, 0(a0)
        addi s9, s9, 4
        addi a0, a0, 4

    /* s9 now points at the hint region. Unpack z from the aligned copy. */
    la   a1, w1_polyvec
    la   a0, z_polyvec
    lw   a4, MLDSA_PARAM_K_OFFSET(s11)
    lw   t0, MLDSA_PARAM_L_OFFSET(s11)
    LOOP t0, 2
        jal x1, polyz_unpack
        nop

    /* reduce32(z) for central representation */
    la a0, z_polyvec
    la a1, w1_polyvec
    lw   t0, MLDSA_PARAM_L_OFFSET(s11)
    LOOP t0, 2
        jal x1, poly_reduce32
        nop

    /* chknorm */
    lw   a1, MLDSA_PARAM_GAMMA1_MINUS_BETA_OFFSET(s11)   /* GAMMA1 - BETA */
    la   a0, w1_polyvec
    li   s2, 0

    lw   t0, MLDSA_PARAM_L_OFFSET(s11)
    LOOP t0, 2
        jal x1, poly_chknorm
        or  s2, s2, a2
    bne s2, x0, _fail_crypto_sign_verify_internal /* Raise error */

    /* External mu: dmem[mu] is supplied by the caller. */

    la  a0, c_poly
    la  a1, ctilde
    lw   t0, MLDSA_PARAM_K_OFFSET(s11)
    slli a2, t0, 3   /* CTILDEBYTES = K * 8 */
    lw   a3, MLDSA_PARAM_TAU_OFFSET(s11)
    jal x1, poly_challenge

    /* Prepare modulus */
    #define mod_x2 w22
    bn.wsrr   w16, 0x0 /* w16 = R | Q */
    bn.shv.8S mod_x2, w16 << 1 /* mod_x2 = 2*R | 2*Q */

    bn.wsrw 0x0, mod_x2 /* MOD = 2*R | 2*Q */
    /* NTT(z) */
    la   a0, z_polyvec
    addi a2, a0, 0 /* inplace */

    lw t0, MLDSA_PARAM_L_OFFSET(s11)
    LOOP t0, 2
        jal  x1, ntt
        addi a1, a1, -1024

    /* Initialize the nonce for matrix expansion. This value should be
         byte(i) || byte(j)
       for entry A[i][j]. */
    bn.xor w23, w23, w23

    /* Precompute the SHAKE128 configuration for poly_uniform. */
    addi  s4, x0, 34
    slli  s4, s4, 5
    addi  s4, s4, SHAKE128_CFG

    /* Start the SHAKE computation for A[0][0] ahead of NTT for performance. */
    csrrw     x0, kmac_cfg, s4
    la        a0, pk
    bn.lid    x0, 0(a0)
    bn.wsrw   kmac_msg, w0
    addi      t0, x0, 2
    csrrw     x0, kmac_partial_write, t0
    bn.wsrw   kmac_msg, w23

    /* After NTT(z), w16 is still R | Q and MOD is still 2*R | 2*Q */
    /* NTT(c) */
    la   a0, c_poly
    addi a2, a0, 0 /* inplace */
    jal  x1, ntt


    /* After NTT(c), w16 is still R | Q and MOD is still 2*R | 2*Q */

    /* Load source pointers for matrix-vector multiplication. */
    la  s0, z_polyvec
    la  s1, tmp_poly

    /* Load destination pointer for matrix-vector multiplication. */
    la  s2, w1_polyvec

    lw   t0, MLDSA_PARAM_L_OFFSET(s11)
    slli s3, t0, 10

    /* Load pointer to rho (first 32B of public key). */
    la s5, pk

    /* Compute A * z, computing elements of A on the fly. */
    lw a4, MLDSA_PARAM_K_OFFSET(s11)
    LOOP a4, 43
        /* Compute A[i][0]. */
        addi a1, s1, 0
        jal  x1, poly_uniform
        /* Increment the matrix nonce. */
        bn.addi w23, w23, 1
        /* Start the SHAKE128 operation for poly_uniform for A[i][1]. */
        csrrw     x0, kmac_cfg, s4
        bn.lid    x0, 0(s5)
        bn.wsrw   kmac_msg, w0
        addi      t0, x0, 2
        csrrw     x0, kmac_partial_write, t0
        bn.wsrw   kmac_msg, w23
        /* Compute A[i][0] * z[0] and set the output at index i. */
        addi a0, s0, 0
        addi a1, s1, 0
        addi a2, s2, 0
        jal  x1, poly_pointwise
        addi s0, s0, 1024
        lw t0, MLDSA_PARAM_L_OFFSET(s11)
        addi t0, t0, -1
        LOOP t0, 14
            /* Compute A[i][j]. */
            addi a1, s1, 0
            jal  x1, poly_uniform
            /* Increment the matrix nonce. */
            bn.addi w23, w23, 1
            /* Start the SHAKE128 operation for poly_uniform for A[i][j+1]. */
            csrrw     x0, kmac_cfg, s4
            bn.lid    x0, 0(s5)
            bn.wsrw   kmac_msg, w0
            addi      t0, x0, 2
            csrrw     x0, kmac_partial_write, t0
            bn.wsrw   kmac_msg, w23
            /* Compute A[i][j] * z[j] and add it to the output at index i. */
            addi a0, s0, 0
            addi a1, s1, 0
            addi a2, s2, 0
            jal  x1, poly_pointwise_acc
            addi s0, s0, 1024
        /* Reset input vector pointer */
        sub  s0, s0, s3
        addi s2, s2, 1024
        /* Adjust the matrix nonce to reset the column and increment the row. */
        bn.addi w23, w23, 256
        lw t0, MLDSA_PARAM_L_OFFSET(s11)
        LOOP t0, 1
            bn.subi w23, w23, 1
        /* Start the SHAKE128 operation for poly_uniform for A[i+1][j]. */
        csrrw     x0, kmac_cfg, s4
        bn.lid    x0, 0(s5)
        bn.wsrw   kmac_msg, w0
        addi      t0, x0, 2
        csrrw     x0, kmac_partial_write, t0
        bn.wsrw   kmac_msg, w23

    /* Call random oracle and verify challenge */
    /* Initialize a SHAKE256 operation. */
    li a1, CRHBYTES
    lw t0, MLDSA_PARAM_POLYW1_PACKEDBYTES_OFFSET(s11)
    lw a4, MLDSA_PARAM_K_OFFSET(s11)
    LOOP a4, 1
        add a1, a1, t0
    slli  t0, a1, 5
    addi  t0, t0, SHAKE256_CFG
    csrrw x0, KECCAK_CFG_REG, t0

    /* Send mu to the Keccak core. */
    la  a0, mu
    li  a1, CRHBYTES /* set mu length to CRHBYTES */
    jal x1, keccak_send_message

    /* Load the pointer to the packed t1 within the public key. */
    la   s6, pk
    addi s6, s6, 32

    /* Initialize the counters for poly_decode_h. */
    li   s7, 0
    li   s8, 0

    /* Initialize failure buffer (0 on success, -1 on failure) */
    li   s10, 0

    /* This loop computes w1 polynomials and sends them to the Keccak core
       incrementally. This way, we avoid ever storing the entire w1 on the
       stack. */
    la  s1, w1_polyvec
    la  s3, tmp_poly
    la  s4, c_poly
    lw  a4, MLDSA_PARAM_K_OFFSET(s11)
    LOOP a4, 45
        /* Unpack the next polynomial from t1 and store it in temp buffer. */
        addi a0, s3, 0
        addi a1, s6, 0
        jal  x1, polyt1_unpack
        addi s6, a1, 0
        /* Shift-left of t1 polynomial. */
        addi t1, s3, 0
        LOOPI 32, 3
            bn.lid    x0, 0(t1)
            bn.shv.8S w0, w0 << D
            bn.sid    x0, 0(t1++)
        /* Compute ntt(t1) in place. */
        addi a0, s3, 0
        addi a2, s3, 0
        jal  x1, ntt
        /* Compute cp * t1, storing the result in t1. */
        addi a0, s4, 0
        addi a1, s3, 0
        addi a2, s3, 0
        jal  x1, poly_pointwise
        /* Compute the next polynomial of w_approx = Az - t1. */
        addi a0, s1, 0
        addi a1, s3, 0
        addi a2, s1, 0
        jal x1, poly_sub
        /* Inverse NTT on w_approx (stored in w1 buffer). */
        addi a0, s1, 0
        jal  x1, intt
        /* Decode the next polynomial from the hint and update the error register. */
        addi a0, s3, 0
        addi a1, s9, 0
        addi a2, s7, 0
        addi a3, s8, 0
        lw   a5, MLDSA_PARAM_K_OFFSET(s11)
        lw   t4, MLDSA_PARAM_OMEGA_OFFSET(s11)
        jal x1, poly_decode_h
        addi s9, a1, 0
        addi s7, a2, 0
        addi s8, a3, 0
        or   s10, s10, a4
        /* Use the hint to compute the next w1 polynomial. */
        addi a0, s1, 0
        addi a1, s1, 0
        addi a2, s3, 0
        lw   a4, MLDSA_PARAM_K_OFFSET(s11)
        jal  x1, poly_use_hint
        /* Pack the w1 polynomial (in-place). */
        addi a0, s1, 0
        addi a1, s1, 0
        jal  x1, polyw1_pack
        /* Send the packed w1 polynomial to the Keccak core. */
        addi a0, s1, 0
        lw   a1, MLDSA_PARAM_POLYW1_PACKEDBYTES_OFFSET(s11)
        jal  x1, keccak_send_message
        addi s1, s1, 1024 /* increment *w1 */

    bn.wsrr w8, 0xA /* KECCAK_DIGEST */

    /* Restore MOD = R | Q to avoid clobbering, unused from here on. */
    bn.wsrw mod, w16

    /* Check the failure register from the loop. */
    bne s10, x0, _fail_crypto_sign_verify_internal

    /* Setup WDR for c2 */
    li t1, 8

    /* Setup WDR for c */
    li t2, 9

    la     t0, ctilde
    bn.lid t2, 0(t0++)

    /* Check if c == c2 */
    bn.cmp w8, w9

    /* Get the FG0.Z flag into a register.
    x2 <= (CSRs[FG0] >> 3) & 1 = FG0.Z */
    csrrs t1, 0x7c0, x0
    srli  t1, t1, 3
    andi  t1, t1, 1

    beq t1, x0, _fail_crypto_sign_verify_internal

    /* If CTILDEBYTES == 32 (K=4), one 32B compare suffices. */
    lw   t1, MLDSA_PARAM_K_OFFSET(s11)
    li   t3, 4
    beq  t1, t3, _success_crypto_sign_verify_internal

    bn.wsrr w8, 0xA /* KECCAK_DIGEST */
    /* Remove upper 16B from digest in the case of CTILDEBYTES == 48 (K=6). */
    li   t3, 6
    bne  t1, t3, _skip_mask_ctilde
    bn.rshi w8, w8, bn0 >> 128
    bn.rshi w8, bn0, w8 >> 128
_skip_mask_ctilde:
    bn.lid t2, 0(t0++)

    /* Check if c == c2 */
    bn.cmp w8, w9

    /* Get the FG0.Z flag into a register.
    x2 <= (CSRs[FG0] >> 3) & 1 = FG0.Z */
    csrrs t0, 0x7c0, x0
    srli  t0, t0, 3
    andi  t0, t0, 1

    beq t0, x0, _fail_crypto_sign_verify_internal
    jal x0, _success_crypto_sign_verify_internal

    /* ------------------------ */

    /* Free space on the stack */
    addi sp, fp, 0
_success_crypto_sign_verify_internal:
    li a0, 0
    la a1, result
    sw a0, 0(a1)
    ret

_fail_crypto_sign_verify_internal:
    li a0, -1
    la a1, result
    sw a0, 0(a1)
    /*unimp*/
    ret
