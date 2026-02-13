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
.equ x0, zero
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

/* Macros */
.macro push reg
    addi sp, sp, -4      /* Decrement stack pointer by 4 bytes */
    sw \reg, 0(sp)      /* Store register value at the top of the stack */
.endm

.macro pop reg
    lw \reg, 0(sp)      /* Load value from the top of the stack into register */
    addi sp, sp, 4     /* Increment stack pointer by 4 bytes */
.endm

/**
 * Dilithium Verify
 *
 * Returns: 0 on success
 *
 * @param[in] x10: *sig, pointer to signature in DMEM
 * @param[in] x11: siglen, byte-length of signature
 * @param[in] x12: *msg, pointer to message in DMEM
 * @param[in] x13: msglen, byte-length of message
 * @param[in] x14: *pk, pointer to public key in DMEM
 * @param[in] x15: *ctx, pointer to context in DMEM
 * @param[in] x16: ctxlen, byte-length of context
 * @param[out] dmem[result]: 0 on success, 0xffffff on failure
 *
 */
.globl crypto_sign_verify_internal
crypto_sign_verify_internal:
    /* Stack address mapping */
    #define STACK_SIG     -4
    #define STACK_SIGLEN  -8
    #define STACK_MSG    -12
    #define STACK_MSGLEN -16
    #define STACK_PK     -20
    #define STACK_CTX    -24
    #define STACK_CTXLEN -28
    #define STACK_RHO    -64
    #define STACK_MU    -128
    #define STACK_CP   -1152 /* Prev - 1024 */
    #define STACK_TMP  -2176 /* Prev - 1024 */
#if DILITHIUM_MODE == 2
    #define STACK_C  -2208 /* Prev - K*ceil(CTILDEBYTES/32)*32 */
    #define STACK_Z  -6304 /* Prev - L*1024 */
    #define STACK_W1  -10400 /* Prev - K*1024 */
    #define INIT_SP -10400
    #define STACK_SIZE 10528 /* Expected stack size for reference (unused). */
#elif DILITHIUM_MODE == 3
    #define STACK_C  -2240 /* Prev - K*ceil(CTILDEBYTES/32)*32 */
    #define STACK_Z  -7360 /* Prev - L*1024 */
    #define STACK_W1  -13504 /* Prev - K*1024 */
    #define INIT_SP -13504
    #define STACK_SIZE 13632 /* Expected stack size for reference (unused). */
#elif DILITHIUM_MODE == 5
    #define STACK_C  -2240 /* Prev - K*ceil(CTILDEBYTES/32)*32 */
    #define STACK_Z  -9408 /* Prev - L*1024 */
    #define STACK_W1  -17600 /* Prev - K*1024 */
    #define INIT_SP -17600
    #define STACK_SIZE 17728 /* Expected stack size for reference (unused). */
#endif

    /* Initialize the frame pointer */
    addi fp, sp, 0

    /* Reserve space on the stack */
    li  t0, INIT_SP
    add sp, sp, t0

    /* Store parameters to stack */
    li  t0, STACK_SIG
    add t0, fp, t0
    sw  a0, 0(t0)
    li  t0, STACK_SIGLEN
    add t0, fp, t0
    sw  a1, 0(t0)
    li  t0, STACK_MSG
    add t0, fp, t0
    sw  a2, 0(t0)
    li  t0, STACK_MSGLEN
    add t0, fp, t0
    sw  a3, 0(t0)
    li  t0, STACK_PK
    add t0, fp, t0
    sw  a4, 0(t0)
    li  t0, STACK_CTX
    add t0, fp, t0
    sw  a5, 0(t0)
    li  t0, STACK_CTXLEN
    add t0, fp, t0
    sw  a6, 0(t0)

    /* Check input lengths */
    li t0, CRYPTO_BYTES
    bne a1, t0, _fail_crypto_sign_verify_internal

    /* Unpack pk */
    /* Unpack rho */
    addi   t0, zero, 0
    bn.lid t0, 0(a4++)
    li     t1, STACK_RHO
    add    t1, fp, t1
    bn.sid t0, 0(t1)

    /* Unpack sig */
    /* Unpack c */
    /* Load sig pointer */
    li  t0, STACK_SIG
    add t0, fp, t0
    lw  t0, 0(t0)
    /* Load c pointer */
    li  t1, STACK_C
    add t1, fp, t1

    /* Setup WDR */
    li  t2, 2
    /* Copy c */
#if DILITHIUM_MODE == 2
    bn.lid t2, 0(t0++)
    bn.sid t2, 0(t1++)
#elif DILITHIUM_MODE == 3
    /* Since the signature is at a boundary has the address k*32 + 16, the first
    16 bytes are accessed using the GPRs */
    LOOPI 12, 4
        lw t3, 0(t0)
        sw t3, 0(t1)
        addi t0, t0, 4
        addi t1, t1, 4
    /* By here, the pointer to the signature in t0 should be 32B aligned */
    /* bn.lid t2, 0(t0++)
    bn.sid t2, 0(t1++) */
#elif DILITHIUM_MODE == 5
    bn.lid t2, 0(t0++)
    bn.sid t2, 0(t1++)
    bn.lid t2, 0(t0++)
    bn.sid t2, 0(t1++)
#endif

    /* Unpack z */
    /* Copy sig pointer */
    addi a1, t0, 0
    /* Load pointer to z */
    li   a0, STACK_Z
    add  a0, fp, a0

    LOOPI L, 2
        jal x1, polyz_unpack
        nop

    /* Copy sig pointer for unpacking h later. */
    addi s9, a1, 0

    /* reduce32(z) for central representation */
    li  a0, STACK_Z
    add a0, fp, a0
    li  a1, STACK_W1 /* Use as temporary buffer. */
    add a1, fp, a1
    LOOPI L, 2
        jal x1, poly_reduce32
        nop

    /* chknorm */
    li  t0, GAMMA1
    li  t1, BETA
    sub a1, t0, t1
    li  a0, STACK_W1
    add a0, fp, a0
    addi s0, a0, 0

    .rept L
        addi a0, s0, 0 /* Copy back input pointer */
        jal x1, poly_chknorm
        bne a0, zero, _fail_crypto_sign_verify_internal /* Raise error */
        addi s0, s0, 1024 /* Increment input pointer */
    .endr

    /* Compute H(rho, t1) */
    /* Load pointer to pk */
    li  a0, STACK_PK
    add a0, fp, a0
    lw  a0, 0(a0)

    /* Initialize a SHAKE256 operation. */
    li    a1, CRYPTO_PUBLICKEYBYTES /* set message length to CRYPTO_PUBLICKEYBYTES */
    slli  t0, a1, 5
    addi  t0, t0, SHAKE256_CFG
    csrrw zero, KECCAK_CFG_REG, t0

    /* Send the public key to the Keccak core. */
    jal x1, keccak_send_message

    /* Read tr (64B) and store in STACK_MU */
    li  a0, STACK_MU
    add a0, fp, a0
    bn.wsrr w0, kmac_digest
    bn.sid  zero, 0(a0++)
    bn.wsrr w0, kmac_digest
    bn.sid  zero, 0(a0)

    /* Compute the total length of tr + [0,ctxlen] + ctx + msg. */
    li   t1, TRBYTES
    addi t1, t1, 2
    li   t2, STACK_CTXLEN
    add  t2, fp, t2
    lw   t2, 0(t2) /* t2 <= ctxlen */
    add  t1, t1, t2 /* Add len(ctx) */
    li   t2, STACK_MSGLEN
    add  t2, fp, t2
    lw   t2, 0(t2) /* t2 <= msglen */
    add  t1, t1, t2 /* Add msglen */

    /* Initialize a SHAKE256 operation. */
    slli  t0, t1, 5
    addi  t0, t0, SHAKE256_CFG
    csrrw zero, KECCAK_CFG_REG, t0

    /* Send TR to the Keccak core. */
    li  a1, TRBYTES
    li  a0, STACK_MU
    add a0, fp, a0
    jal x1, keccak_send_message

    /* Copy 0 || ctxlen to a 32B-aligned buffer temporarily. */
    li   a0, STACK_MU
    add  a0, fp, a0
    li   t1, STACK_CTXLEN
    add  t1, fp, t1
    lw   t1, 0(t1)
    slli t1, t1, 8
    sw   t1, 0(a0)

    /* Send 0 || ctxlen to the Keccak core (2B). */
    li  a1, 2
    jal x1, keccak_send_message

    /* Send ctx to the Keccak core. */
    li  a1, STACK_CTXLEN
    add a1, fp, a1
    lw  a1, 0(a1) /* a1 <= ctxlen */
    li  a0, STACK_CTX
    add a0, fp, a0
    lw  a0, 0(a0) /* a0 <= *ctx */
    jal x1, keccak_send_message

    /* Send message to the Keccak core. */
    li  a1, STACK_MSGLEN
    add a1, fp, a1
    lw  a1, 0(a1) /* a1 <= msglen */
    li  a0, STACK_MSG
    add a0, fp, a0
    lw  a0, 0(a0) /* a0 <= *msg */
    jal x1, keccak_send_message

    /* Write 64B of SHAKE output to STACK_MU. */
    li  a0, STACK_MU
    add a0, fp, a0
    bn.wsrr w0, kmac_digest
    bn.sid  zero, 0(a0++)
    bn.wsrr w0, kmac_digest
    bn.sid  zero, 0(a0)

    li  a0, STACK_CP
    add a0, fp, a0
    li  a1, STACK_C
    add a1, fp, a1
    jal x1, poly_challenge

    /* Prepare modulus */
    #define mod_x2 w22
    bn.wsrr   w16, 0x0 /* w16 = R | Q */
    bn.shv.8S mod_x2, w16 << 1 /* mod_x2 = 2*R | 2*Q */

    bn.wsrw 0x0, mod_x2 /* MOD = 2*R | 2*Q */
    /* NTT(z) */
    li   a0, STACK_Z
    add  a0, fp, a0
    addi a2, a0, 0 /* inplace */
    la   a1, twiddles_fwd

    .irp reg,t0,t1,t2,t3,t4,t5,t6,a0,a1,a2,a3,a4,a5,a6,a7
        push \reg
    .endr

    LOOPI L, 2
        jal  x1, ntt
        addi a1, a1, -1024

    .irp reg,a7,a6,a5,a4,a3,a2,a1,a0,t6,t5,t4,t3,t2,t1,t0
        pop \reg
    .endr

    /* Initialize the nonce for matrix expansion. This value should be
         byte(i) || byte(j)
       for entry A[i][j]. */
    bn.xor w23, w23, w23

    /* Precompute the SHAKE128 configuration for poly_uniform. */
    addi  s4, zero, 34
    slli  s4, s4, 5
    addi  s4, s4, SHAKE128_CFG

    /* Start the SHAKE computation for A[0][0] ahead of NTT for performance. */
    csrrw zero, kmac_cfg, s4
    addi  a0, fp, STACK_RHO
    bn.lid    x0, 0(a0)
    bn.wsrw   kmac_msg, w0
    bn.wsrw   kmac_msg, w23

    /* After NTT(z), w16 is still R | Q and MOD is still 2*R | 2*Q */
    /* NTT(c) */
    li   a0, STACK_CP
    add  a0, fp, a0
    addi a2, a0, 0 /* inplace */
    la   a1, twiddles_fwd

    .irp reg,t0,t1,t2,t3,t4,t5,t6,a0,a1,a2,a3,a4,a5,a6,a7
        push \reg
    .endr

    jal x1, ntt

    .irp reg,a7,a6,a5,a4,a3,a2,a1,a0,t6,t5,t4,t3,t2,t1,t0
        pop \reg
    .endr


    /* After NTT(c), w16 is still R | Q and MOD is still 2*R | 2*Q */

    /* Load source pointers for matrix-vector multiplication. */
    li  s0, STACK_Z
    add s0, fp, s0
    li  s1, STACK_TMP
    add s1, fp, s1

    /* Load destination pointer for matrix-vector multiplication. */
    li  s2, STACK_W1
    add s2, fp, s2

    /* Load offset for resetting vector pointer. */
    li s3, POLYVECL_BYTES

     /* Compute A * z, computing elements of A on the fly. */
    loopi K, 36
        /* Compute A[i][0]. */
        addi a1, s1, 0
        jal  x1, poly_uniform
        /* Increment the matrix nonce. */
        bn.addi w23, w23, 1
        /* Start the SHAKE128 operation for poly_uniform for A[i][1]. */
        csrrw zero, kmac_cfg, s4
        addi  a0, fp, STACK_RHO
        bn.lid    x0, 0(a0)
        bn.wsrw   kmac_msg, w0
        bn.wsrw   kmac_msg, w23
        /* Compute A[i][0] * z[0] and set the output at index i. */
        addi a0, s0, 0
        addi a1, s1, 0
        addi a2, s2, 0
        jal  x1, poly_pointwise
        addi s0, s0, 1024
        loopi Lminus1, 13
            /* Compute A[i][j]. */
            addi a1, s1, 0
            jal  x1, poly_uniform
            /* Increment the matrix nonce. */
            bn.addi w23, w23, 1
            /* Start the SHAKE128 operation for poly_uniform for A[i][j+1]. */
            csrrw zero, kmac_cfg, s4
            addi  a0, fp, STACK_RHO
            bn.lid    x0, 0(a0)
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
        csrrw zero, kmac_cfg, s4
        addi  a0, fp, STACK_RHO
        bn.lid    x0, 0(a0)
        bn.wsrw   kmac_msg, w0
        bn.wsrw   kmac_msg, w23

    /* Call random oracle and verify challenge */
    /* Initialize a SHAKE256 operation. */
    li a1, CRHBYTES
    LOOPI K, 1
        addi a1, a1, POLYW1_PACKEDBYTES
    slli  t0, a1, 5
    addi  t0, t0, SHAKE256_CFG
    csrrw zero, KECCAK_CFG_REG, t0

    /* Send mu to the Keccak core. */
    li  a0, STACK_MU
    add a0, fp, a0
    li  a1, CRHBYTES /* set mu length to CRHBYTES */
    jal x1, keccak_send_message

    /* Load the pointer to the packed t1 within the public key. */
    li   s6, STACK_PK
    add  s6, fp, s6
    lw   s6, 0(s6)
    addi s6, s6, 32

    /* Initialize the counters for poly_decode_h. */
    li   s7, 0
    li   s8, 0

    /* Initialize failure buffer (0 on success, -1 on failure) */
    li   s10, 0

    /* This loop computes w1 polynomials and sends them to the Keccak core
       incrementally. This way, we avoid ever storing the entire w1 on the
       stack. */
    la  s0, twiddles_inv
    li  s1, STACK_W1
    add s1, fp, s1
    li  s3, STACK_TMP
    add s3, fp, s3
    li  s4, STACK_CP
    add s4, fp, s4
    la  s5, twiddles_fwd
    loopi K, 44
        /* Unpack the next polynomial from t1 and store it in temp buffer. */
        addi a0, s3, 0
        addi a1, s6, 0
        jal  x1, polyt1_unpack
        addi s6, a1, 0
        /* Shift-left of t1 polynomial. */
        addi t1, s3, 0
        LOOPI 32, 3
            bn.lid    zero, 0(t1)
            bn.shv.8S w0, w0 << D
            bn.sid    zero, 0(t1++)
        /* Compute ntt(t1) in place. */
        addi a0, s3, 0
        addi a1, s5, 0
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
        addi a1, s0, 0
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
        addi a1, zero, POLYW1_PACKEDBYTES
        jal  x1, keccak_send_message
        addi s1, s1, 1024 /* increment *w1 */

    bn.wsrr w8, 0xA /* KECCAK_DIGEST */

    /* Restore MOD = R | Q to avoid clobbering, unused from here on. */
    bn.wsrw mod, w16

    /* Check the failure register from the loop. */
    bne s10, zero, _fail_crypto_sign_verify_internal

    /* Setup WDR for c2 */
    li t1, 8

    /* Setup WDR for c */
    li t2, 9

    li     t0, STACK_C
    add    t0, fp, t0
    bn.lid t2, 0(t0++)

    /* Check if c == c2 */
    bn.cmp w8, w9

    /* Get the FG0.Z flag into a register.
    x2 <= (CSRs[FG0] >> 3) & 1 = FG0.Z */
    csrrs t1, 0x7c0, zero
    srli  t1, t1, 3
    andi  t1, t1, 1

    beq t1, zero, _fail_crypto_sign_verify_internal
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
    csrrs t0, 0x7c0, zero
    srli  t0, t0, 3
    andi  t0, t0, 1

    beq t0, zero, _fail_crypto_sign_verify_internal
#endif
    beq zero, zero, _success_crypto_sign_verify_internal

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
