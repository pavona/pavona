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
#define RNDBYTES 32
#define N 256
#define Q 8380417
#define D 13
#define ROOT_OF_UNITY 1753

#if DILITHIUM_MODE == 2
#define K 4
#define L 4
#define ETA 2
#define TAU 39
#define BETA 78
#define GAMMA1 131072
#define GAMMA2 95232
#define OMEGA 80
#define CTILDEBYTES 32

#define POLYVECK_BYTES 4096
#define POLYVECL_BYTES 4096
#define Lminus1 3

#define CRYPTO_PUBLICKEYBYTES 1312
#define CRYPTO_SECRETKEYBYTES 2560
#define CRYPTO_BYTES 2420

#elif DILITHIUM_MODE == 3
#define K 6
#define L 5
#define ETA 4
#define TAU 49
#define BETA 196
#define GAMMA1 524288
#define GAMMA2 261888
#define OMEGA 55
#define CTILDEBYTES 48

#define POLYVECK_BYTES 6144
#define POLYVECL_BYTES 5120
#define Lminus1 4

#define CRYPTO_PUBLICKEYBYTES 1952
#define CRYPTO_SECRETKEYBYTES 4032
#define CRYPTO_BYTES 3309

#elif DILITHIUM_MODE == 5
#define K 8
#define L 7
#define ETA 2
#define TAU 60
#define BETA 120
#define GAMMA1 524288
#define GAMMA2 261888
#define OMEGA 75
#define CTILDEBYTES 64

#define POLYVECK_BYTES 8192
#define POLYVECL_BYTES 7168
#define Lminus1 6

#define CRYPTO_PUBLICKEYBYTES 2592
#define CRYPTO_SECRETKEYBYTES 4896
#define CRYPTO_BYTES 4627

#endif

#define POLYT1_PACKEDBYTES  320
#define POLYT0_PACKEDBYTES  416
#define POLYVECH_PACKEDBYTES (OMEGA + K)

#if GAMMA1 == (1 << 17)
#define POLYZ_PACKEDBYTES   576
#elif GAMMA1 == (1 << 19)
#define POLYZ_PACKEDBYTES   640
#endif

#if GAMMA2 == (Q-1)/88
#define POLYW1_PACKEDBYTES  192
#elif GAMMA2 == (Q-1)/32
#define POLYW1_PACKEDBYTES  128
#endif

#if ETA == 2
#define POLYETA_PACKEDBYTES  96
#elif ETA == 4
#define POLYETA_PACKEDBYTES 128
#endif

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
 * @param[in] dmem[pk]: public key
 * @param[out] dmem[result]: 0 on success, 0xffffff on failure
 *
 */
.globl crypto_sign_verify_internal
crypto_sign_verify_internal:
    /* Save signature pointer. */
    la  t0, dptr_sig
    sw  a0, 0(t0)

    /* Save message and context lengths. */
    addi s0, a1, 0
    addi s1, a2, 0

    /* Unpack sig */

    /* Unpack ctilde */
    la  t0, dptr_sig
    lw  t0, 0(t0)
    la  t1, ctilde
#if DILITHIUM_MODE == 2
    bn.lid x0, 0(t0++)
    bn.sid x0, 0(t1++)
#elif DILITHIUM_MODE == 3
    /* The signature is not 32-byte aligned, so we copy using GPRs. */
    LOOPI 12, 4
        lw t3, 0(t0)
        sw t3, 0(t1)
        addi t0, t0, 4
        addi t1, t1, 4
    /* We need to set the remaining 16 bytes to 0 to avoid bignum load errors. */
    LOOPI 4, 2
        sw x0, 0(t1)
        addi t1, t1, 4
#elif DILITHIUM_MODE == 5
    bn.lid x0, 0(t0++)
    bn.sid x0, 0(t1++)
    bn.lid x0, 0(t0++)
    bn.sid x0, 0(t1++)
#endif

    /* Unpack z */
    addi a1, t0, 0
    la   a0, z_polyvec
    LOOPI L, 2
        jal x1, polyz_unpack
        nop

    /* Copy sig pointer for unpacking h later. */
    addi s9, a1, 0

    /* reduce32(z) for central representation */
    la a0, z_polyvec
    la a1, w1_polyvec
    LOOPI L, 2
        jal x1, poly_reduce32
        nop

    /* chknorm */
    li   t0, GAMMA1
    li   t1, BETA
    sub  a1, t0, t1
    la   a0, w1_polyvec
    li   s2, 0

    loopi L, 2
        jal x1, poly_chknorm
        or  s2, s2, a2
    bne s2, x0, _fail_crypto_sign_verify_internal /* Raise error */

    /* Compute H(rho, t1) */
    /* Load pointer to pk */
    la  a0, pk

    /* Initialize a SHAKE256 operation. */
    li    a1, CRYPTO_PUBLICKEYBYTES /* set message length to CRYPTO_PUBLICKEYBYTES */
    slli  t0, a1, 5
    addi  t0, t0, SHAKE256_CFG
    csrrw x0, KECCAK_CFG_REG, t0

    /* Send the public key to the Keccak core. */
    jal x1, keccak_send_message

    /* Read tr (64B) and store in dmem[mu]. */
    la      a0, mu
    bn.wsrr w0, kmac_digest
    bn.sid  x0, 0(a0++)
    bn.wsrr w0, kmac_digest
    bn.sid  x0, 0(a0)

    /* Compute the total length of tr + [0,ctxlen] + ctx + msg. */
    li   t1, TRBYTES
    addi t1, t1, 2
    add  t1, t1, s1 /* Add len(ctx) */
    add  t1, t1, s0 /* Add len(msg) */

    /* Initialize a SHAKE256 operation. */
    slli  t0, t1, 5
    addi  t0, t0, SHAKE256_CFG
    csrrw x0, KECCAK_CFG_REG, t0

    /* Send TR to the Keccak core. */
    li  a1, TRBYTES
    la  a0, mu
    jal x1, keccak_send_message

    /* Copy 0 || ctxlen to a 32B-aligned buffer temporarily. */
    la   a0, mu
    addi t1, s1, 0
    slli t1, t1, 8
    sw   t1, 0(a0)

    /* Send 0 || ctxlen to the Keccak core (2B). */
    li  a1, 2
    jal x1, keccak_send_message

    /* Send ctx to the Keccak core. */
    addi a1, s1, 0 /* a1 <= ctxlen */
    la   a0, ctx /* a0 <= *ctx */
    jal  x1, keccak_send_message

    /* Send message to the Keccak core. */
    addi a1, s0, 0 /* a1 <= msglen */
    la   a0, msg /* a0 <= *msg */
    jal  x1, keccak_send_message

    /* Write 64B of SHAKE output to dmem[mu]. */
    la      a0, mu
    bn.wsrr w0, kmac_digest
    bn.sid  x0, 0(a0++)
    bn.wsrr w0, kmac_digest
    bn.sid  x0, 0(a0)

    la  a0, c_poly
    la  a1, ctilde
    jal x1, poly_challenge

    /* Prepare modulus */
    #define mod_x2 w22
    bn.wsrr   w16, 0x0 /* w16 = R | Q */
    bn.shv.8S mod_x2, w16 << 1 /* mod_x2 = 2*R | 2*Q */

    bn.wsrw 0x0, mod_x2 /* MOD = 2*R | 2*Q */
    /* NTT(z) */
    la   a0, z_polyvec
    addi a2, a0, 0 /* inplace */

    LOOPI L, 2
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

    /* Load offset for resetting vector pointer. */
    li s3, POLYVECL_BYTES

    /* Load pointer to rho (first 32B of public key). */
    la s5, pk

    /* Compute A * z, computing elements of A on the fly. */
    loopi K, 33
        /* Compute A[i][0]. */
        addi a1, s1, 0
        jal  x1, poly_uniform
        /* Increment the matrix nonce. */
        bn.addi w23, w23, 1
        /* Start the SHAKE128 operation for poly_uniform for A[i][1]. */
        csrrw     x0, kmac_cfg, s4
        bn.lid    x0, 0(s5)
        bn.wsrw   kmac_msg, w0
        bn.wsrw   kmac_msg, w23
        /* Compute A[i][0] * z[0] and set the output at index i. */
        addi a0, s0, 0
        addi a1, s1, 0
        addi a2, s2, 0
        jal  x1, poly_pointwise
        addi s0, s0, 1024
        loopi Lminus1, 12
            /* Compute A[i][j]. */
            addi a1, s1, 0
            jal  x1, poly_uniform
            /* Increment the matrix nonce. */
            bn.addi w23, w23, 1
            /* Start the SHAKE128 operation for poly_uniform for A[i][j+1]. */
            csrrw     x0, kmac_cfg, s4
            bn.lid    x0, 0(s5)
            bn.wsrw   kmac_msg, w0
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
        bn.subi w23, w23, L
        /* Start the SHAKE128 operation for poly_uniform for A[i+1][j]. */
        csrrw     x0, kmac_cfg, s4
        bn.lid    x0, 0(s5)
        bn.wsrw   kmac_msg, w0
        bn.wsrw   kmac_msg, w23

    /* Call random oracle and verify challenge */
    /* Initialize a SHAKE256 operation. */
    li a1, CRHBYTES
    LOOPI K, 1
        addi a1, a1, POLYW1_PACKEDBYTES
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
    loopi K, 42
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
        jal x1, poly_decode_h
        addi s9, a1, 0
        addi s7, a2, 0
        addi s8, a3, 0
        or   s10, s10, a4
        /* Use the hint to compute the next w1 polynomial. */
        addi a0, s1, 0
        addi a1, s1, 0
        addi a2, s3, 0
        jal  x1, poly_use_hint
        /* Pack the w1 polynomial (in-place). */
        addi a0, s1, 0
        addi a1, s1, 0
        jal  x1, polyw1_pack
        /* Send the packed w1 polynomial to the Keccak core. */
        addi a0, s1, 0
        addi a1, x0, POLYW1_PACKEDBYTES
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
#if CTILDEBYTES == 48 || CTILDEBYTES == 64
    bn.wsrr w8, 0xA /* KECCAK_DIGEST */
    /* Remove upper 16B from digest in the case of CTILDEBYTES == 48 */
#if CTILDEBYTES == 48
    bn.rshi w8, w8, bn0 >> 128
    bn.rshi w8, bn0, w8 >> 128
#endif
    bn.lid t2, 0(t0++)

    /* Check if c == c2 */
    bn.cmp w8, w9

    /* Get the FG0.Z flag into a register.
    x2 <= (CSRs[FG0] >> 3) & 1 = FG0.Z */
    csrrs t0, 0x7c0, x0
    srli  t0, t0, 3
    andi  t0, t0, 1

    beq t0, x0, _fail_crypto_sign_verify_internal
#endif
    beq x0, x0, _success_crypto_sign_verify_internal

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

.bss

/* Pointer to signature. */
.balign 4
dptr_sig:
.zero 4

/* mu intermediate value (64B). */
.balign 32
mu:
.zero 64

/* ctilde intermediate value (CTILDEBYTES bytes). */
.balign 32
ctilde:
.zero CTILDEBYTES

/* Challenge polynomial (1024B). */
.balign 32
c_poly:
.zero 1024

/* Temporary polynomial buffer (1024B). */
.balign 32
tmp_poly:
.zero 1024

/* z polynomial vector (L*1024B). */
.balign 32
z_polyvec:
.zero POLYVECL_BYTES

/* w1 polynomial vector (K*1024B). */
.balign 32
w1_polyvec:
.zero POLYVECK_BYTES
