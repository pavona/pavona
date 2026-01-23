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
 * Dilithium Sign
 *
 * Returns: 0 on success
 *
 * @param[in]  x10: *sig
 * @param[in]  x11: *msg
 * @param[in]  x12: msglen
 * @param[in]  x13: *sk
 * @param[out] x10: 0 (success)
 * @param[out] x11: siglen
 *
 */
.global crypto_sign_signature_internal
crypto_sign_signature_internal:
    /* Stack address mapping */
    #define STACK_SIG -4
    #define STACK_MSG -8
    #define STACK_MSGLEN -12
    #define STACK_SK -16
    #define STACK_TR -96 /* Prev - 16 - 64 */
        #define STACK_MU -96 /* Prev */
    #define STACK_RHO -128 /* Prev - 32 */
    #define STACK_RND -160 /* Prev - 32 */
    #define STACK_KEY -192 /* Prev - 32 */
      #define STACK_RHOPRIME -192 /* Prev */
    #define STACK_Y   -1216 /* Prev - 1024 */
      #define STACK_CP  -1216 /* Prev */
    #define STACK_TMP -2240 /* Prev - 1024 */
      #define STACK_H   -2240 /* Prev */
      #define STACK_S1  -2240 /* Prev */
#if DILITHIUM_MODE == 2
    #define STACK_W1  -2368 /* Prev - K*32 */
    #define STACK_W0  -6464 /* Prev - K*1024 */
        #define STACK_CTXLEN  -6464 /* Prev */
    #define STACK_CTX  -6468 /* Prev - 4 */
    #define INIT_SP -6496
    #define STACK_SIZE 6624 /* Expected stack size for reference (unused). */
#elif DILITHIUM_MODE == 3
    #define STACK_W1  -2432 /* Prev - K*32 */
    #define STACK_W0  -8576 /* Prev - K*1024 */
        #define STACK_CTXLEN  -8576 /* Prev */
    #define STACK_CTX  -8580 /* Prev - 4 */
    #define INIT_SP -8608
    #define STACK_SIZE 8736 /* Expected stack size for reference (unused). */
#elif DILITHIUM_MODE == 5
    #define STACK_W1  -2496 /* Prev - K*32 */
    #define STACK_W0  -10688 /* Prev - K*1024 */
        #define STACK_CTXLEN  -10688 /* Prev */
    #define STACK_CTX  -10692 /* Prev - 4 */
    #define INIT_SP -10720
    #define STACK_SIZE 10848 /* Expected stack size for reference (unused). */
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
    li  t0, STACK_MSG
    add t0, fp, t0
    sw  a1, 0(t0)
    li  t0, STACK_MSGLEN
    add t0, fp, t0
    sw  a2, 0(t0)
    li  t0, STACK_SK
    add t0, fp, t0
    sw  a3, 0(t0)
    li  t0, STACK_CTX
    add t0, fp, t0
    sw  a4, 0(t0)
    li  t0, STACK_CTXLEN
    add t0, fp, t0
    sw  a5, 0(t0)

    /* Unpack sk */

    /* Setup WDR */
    li t0, 0

    /* Copy to stack */

    /* rho */
    bn.lid t0, 0(a3++)
    /* Load *rho */
    li     t1, STACK_RHO
    add    t1, fp, t1
    bn.sid t0, 0(t1++)

    /* key */
    bn.lid t0, 0(a3++)
    /* Load *key */
    li     t1, STACK_KEY
    add    t1, fp, t1
    bn.sid t0, 0(t1++)

    /* tr */
    bn.lid t0, 0(a3++)
    /* Load *tr */
    li     t1, STACK_TR
    add    t1, fp, t1
    bn.sid t0, 0(t1)
    bn.lid t0, 0(a3++)
    bn.sid t0, 32(t1)


    /* CRH(tr, msg) */

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
    li  a0, STACK_TR
    add a0, fp, a0
    jal x1, keccak_send_message

    /* Copy 0 || ctxlen to a 32B-aligned buffer temporarily. */
    li   a0, STACK_TMP
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

    /* Finish the SHAKE-256 operation. */

#ifdef DILITHIUM_RANDOMIZED_SIGNING
    /* NOTE: Write real randomness to STACK_RND */
#else
    /* Write RNDBYTES=32 0s to rnd */
    bn.xor w0, w0, w0
    li     t0, 0
    li     a0, STACK_RND
    add    a0, fp, a0
    bn.sid t0, 0(a0)
#endif

    /* Initialize a SHAKE256 operation. */
    addi  a1, zero, SEEDBYTES
    addi  a1, a1, RNDBYTES
    addi  a1, a1, CRHBYTES
    slli  t0, a1, 5
    addi  t0, t0, SHAKE256_CFG
    csrrw zero, KECCAK_CFG_REG, t0

    /* Send key to the Keccak core. */
    li  a1, SEEDBYTES /* set message length to SEEDBYTES */
    li  a0, STACK_KEY
    add a0, fp, a0
    jal x1, keccak_send_message

    /* Send rnd to the Keccak core. */
    li  a1, RNDBYTES /* set message length to RNDBYTES */
    li  a0, STACK_RND
    add a0, fp, a0
    jal x1, keccak_send_message

    /* Send mu to the Keccak core. */
    li  a1, CRHBYTES /* set message length to CRHBYTES */
    li  a0, STACK_MU
    add a0, fp, a0
    jal x1, keccak_send_message

    /* Setup WDR */
    li t1, 8

    li      a0, STACK_RHOPRIME
    add     a0, fp, a0
    bn.wsrr w8, 0xA     /* KECCAK_DIGEST */
    bn.sid  t1, 0(a0++) /* Store into rhoprime buffer */
    bn.wsrr w8, 0xA     /* KECCAK_DIGEST */
    bn.sid  t1, 0(a0++) /* Store into rhoprime buffer */

    /* Finish the SHAKE-256 operation. */

    /* Prepare modulus */
    #define mod_x2 w22
    bn.wsrr   w16, 0x0 /* w16 = MOD = R | Q */
    bn.shv.8S mod_x2, w16 << 1 /* mod_x2 = 2*R | 2*Q */

    li s11, 0 /* nonce */

_rej_crypto_sign_signature_internal:
    /* Matrix-vector multiplication */

    /* Get destination pointer. */
    li s1, STACK_W0
    add s1, fp, s1

    /* Initialize destination to 0. */
    li t0, 31
    addi t1, s1, 0
    LOOPI K, 3
        LOOPI 32, 1
          bn.sid t0, 0(t1++)
        nop

    /* Load the constant for resetting the w pointer. */
    li s6, POLYVECK_BYTES

    /* Initialize the nonce for matrix expansion. This value should be
         byte(i) || byte(j)
       for entry A[i][j]. */
    bn.xor w23, w23, w23

    /* Load a constant pointer to the zero wide register. */
    li s5, 31

    /* Load a pointer to the vectorized gamma1. */
    la   s7, gamma1_vec_const

    /* Load a pointer to the NTT twiddles. */
    la   s9, twiddles_fwd

    /* Load other pointers. */
    li   s8, STACK_Y
    add  s8, fp, s8
    li   s10, STACK_TMP
    add  s10, fp, s10

    /* Precompute the SHAKE128 configuration for poly_uniform. */
    addi  s4, zero, 34
    slli  s4, s4, 5
    addi  s4, s4, SHAKE128_CFG

    /* Compute A * y, computing the values for A and y on the fly.

       We compute column-wise so that we genearate elements of y only once; in
       pseudocode, this computation does:

         for j in 0..l-1:
           yj = ntt(y[j])
           for i in 0..k-1:
             w[i] += A[i][j] * yj
    */
    loopi L, 38
        /* Zero the buffer for y[j]. */
        addi  t0, s8, 0
        loopi 32, 1
          bn.sid s5, 0(t0++)
        /* Compute y[j]. */
        addi a0, s8, 0
        add  a1, fp, STACK_RHOPRIME
        addi a2, s11, 0 /* y sampling nonce */
        addi a3, s7, 0
        jal  x1, poly_uniform_gamma_1
        addi s11, a2, 1 /* a2 should be preserved after execution */
        /* Start the SHAKE128 operation for poly_uniform for A[0][j]. */
        csrrw zero, kmac_cfg, s4
        addi  a0, fp, STACK_RHO
        bn.lid    x0, 0(a0)
        bn.wsrw   kmac_msg, w0
        bn.wsrw   kmac_msg, w23
        bn.wsrw 0x0, mod_x2 /* MOD = 2*R | 2*Q */
        /* Compute ntt(y[j]). */
        addi a0, s8, 0
        addi a1, s9, 0
        addi a2, s8, 0
        jal x1, ntt
        loopi K, 13
            /* Compute A[i][j]. */
            addi a1, s10, 0
            jal  x1, poly_uniform
            /* Increment the row index by 1. */
            bn.addi w23, w23, 256
            /* Start the SHAKE128 operation for poly_uniform for A[i+1][j]. */
            csrrw zero, kmac_cfg, s4
            addi  a0, fp, STACK_RHO
            bn.lid    x0, 0(a0)
            bn.wsrw   kmac_msg, w0
            bn.wsrw   kmac_msg, w23
            addi a0, s8, 0
            addi a1, s10, 0
            addi a2, s1, 0 /* *w[i] */
            /* Add A[i][j] * y[j] to w[i]. */
            jal  x1, poly_pointwise_acc
            /* Increment the w pointer. */
            addi s1, s1, 1024
        /* Reset w pointer. */
        sub  s1, s1, s6
        /* Increment the column index in the nonce by one. */
        bn.addi w23, w23, 1
        /* Reset the row index in the nonce to zero. */
        bn.rshi w23, w23, bn0 >> 8
        bn.rshi w23, bn0, w23 >> 248
        bn.wsrw 0x0, w16 /* Restore MOD = R | Q */

    bn.wsrw 0x0, mod_x2 /* MOD = 2*R | 2*Q */
    /* Inverse NTT on w */
    li  a0, STACK_W0
    add a0, fp, a0
    la  a1, twiddles_inv

    .irp reg,t0,t1,t2,t3,t4,t5,t6,a0,a1,a2,a3,a4,a5,a6,a7
        push \reg
    .endr

    LOOPI K, 3
        jal x1, intt
        /* Reset the twiddle pointer */
        addi a1, a1, -960
        /* Go to next input polynomial */
        addi a0, a0, 1024

    .irp reg,a7,a6,a5,a4,a3,a2,a1,a0,t6,t5,t4,t3,t2,t1,t0
        pop \reg
    .endr
    bn.wsrw 0x0, w16 /* Restore MOD = R | Q */

    /* Random oracle */
    /* Initialize a SHAKE256 operation. */
    addi  a1, zero, CRHBYTES
    LOOPI K, 1
        addi a1, a1, POLYW1_PACKEDBYTES
    slli  t0, a1, 5
    addi  t0, t0, SHAKE256_CFG
    csrrw zero, KECCAK_CFG_REG, t0

    /* Send mu to the Keccak core. */
    li  a1, CRHBYTES /* set mu length to CRHBYTES */
    li  a0, STACK_MU
    add a0, fp, a0
    jal x1, keccak_send_message

    /* Save some pointers for loop. */
    li  s0, STACK_W0
    add s0, fp, s0
    li  s1, STACK_W1
    add s1, fp, s1
    li  s4, STACK_TMP
    add s4, fp, s4

    /* Get the pointer to the signature (used as tmp buffer for packed w1). */
    li  s2, STACK_SIG
    add s2, fp, s2
    lw  s2, 0(s2) /* Get *sig */
    addi s3, s2, 0 /* Save *sig. */
#if CTILDEBYTES == 48
    /* Use an offset of 16 to get an aligned buffer (alignment hack for CTILDE). */
    addi s2, s2, 16
#endif

    /* This loop:
         - decomposes each polynomial w[i] into w0[i] and w1[i]
         - packs w1[i] and sends it to the Keccak core
         - records the nonzero high bits of w1[i] for later use

       Afterwards, the w1[i] value can be discarded, so we do not need to keep
       two w-sized polyvecs in scope at once. */
    loopi K, 14
        /* Decompose w and store w0 in-place, w1 in tmp. */
        addi   a0, s0, 0
        addi   a1, s4, 0
        addi   a2, s0, 0
        jal    x1, poly_decompose
        /* Pack w1. */
        addi   a0, s2, 0
        addi   a1, s4, 0
        jal    x1, polyw1_pack
        /* Send packed w1 to the Keccak core. */
        addi   a0, s2, 0
        addi   a1, zero, POLYW1_PACKEDBYTES
        jal    x1, keccak_send_message
        /* Calculate the coefficients of w1 that are nonzero mod q, and store them. */
        addi   a0, s4, 0
        jal    x1, poly_nonzero_encode
        bn.sid x0, 0(s1++)
        /* Increment w pointer. */
        addi s0, s0, 1024

    /* Setup WDR */
    li t1, 8

    /* Read first 32 bytes of digest. */
    bn.wsrr w8, 0xA

    /* Get always-aligned temporary buffer. */
    li   t0, STACK_TMP
    add  t0, fp, t0
#if CTILDEBYTES == 32
    /* Store first 32 bytes into temp buffer and signature. */
    bn.sid  t1, 0(t0)
    bn.sid  t1, 0(s3)
#elif CTILDEBYTES == 48
    /* Store first 32 bytes into temp buffer and (unaligned) signature. */
    bn.sid  t1, 0(t0)
    LOOPI 8, 4
        lw t2, 0(t0)
        sw t2, 0(s3)
        addi t0, t0, 4
        addi s3, s3, 4

    /* Read 32 more bytes and store 16 of them. */
    bn.wsrr w8, 0xA
    bn.sid  t1, 0(t0)
    LOOPI 4, 4
        lw t2, 0(t0)
        sw t2, 0(s3)
        addi t0, t0, 4
        addi s3, s3, 4
#elif CTILDEBYTES == 64
    /* Store first 32 bytes into temp buffer and signature. */
    bn.sid  t1, 0(t0)
    bn.sid  t1, 0(s3)
    /* Store 32 more bytes (both places). */
    bn.wsrr w8, 0xA
    bn.sid  t1, 32(t0)
    bn.sid  t1, 32(s3)
#endif

    /* Finish the SHAKE-256 operation. */

    /* Challenge */
    /* CTILDE was temporarily stored in STACK_TMP. Re-use here because it is aligned,
       for CTILDEBYTES = 48 as well */
    li   a0, STACK_CP
    add  a0, fp, a0
    li   a1, STACK_TMP
    add  a1, fp, a1
    jal  x1, poly_challenge

    bn.wsrw 0x0, mod_x2 /* MOD = 2*R | 2*Q */

    /* NTT(cp) */
    li   a0, STACK_CP
    add  a0, fp, a0 /* Input */
    addi a2, a0, 0  /* Output inplace */
    la   a1, twiddles_fwd
    jal  x1, ntt

    bn.wsrw 0x0, w16 /* Restore MOD = R | Q */

    /* Load pointer to packed s1 */
    li   s0, STACK_SK
    add  s0, fp, s0
    lw   s0, 0(s0)
    addi s0, s0, 128

    /* Reset the nonce for y and set up a constant for poly_uniform_gamma1. */
    addi s8, s11, -L

    /* Save some stack pointers. */
    li   s1, STACK_S1
    add  s1, fp, s1
    li   s2, STACK_TMP
    add  s2, fp, s2
    li   s3, STACK_RHOPRIME
    add  s3, fp, s3
    li   s7, STACK_CP
    add  s7, fp, s7
    li   s9, STACK_SIG
    add  s9, fp, s9
    lw   s9, 0(s9)
    addi s9, s9, CTILDEBYTES /* c is already packed */
    la   s10, gamma1_vec_const

    /* This loop computes z = (cp * s1) = y one element at a time, and does
       rejection sampling on each element before packing it into the signature.
       Cannot easily be a hardware loop because of the branch to
       _rej_crypto_sign_signature_internal. */
    .rept L
        /* Unpack the next polynomial from s1. */
        addi a0, s1, 0
        addi a1, s0, 0
        jal x1, polyeta_unpack
        /* Update the packed s1 pointer. */
        addi s0, a1, 0

        bn.wsrw 0x0, mod_x2 /* MOD = 2*R | 2*Q */

        /* Compute ntt(s1). */
        addi a0, s1, 0
        la   a1, twiddles_fwd
        addi a2, s1, 0
        jal x1, ntt
        /* z = cp * s1 */
        addi a0, s1, 0
        addi a1, s7, 0
        addi a2, s2, 0
        jal  x1, poly_pointwise
        /* After poly_pointwise, w16 is still R | Q and MOD is still 2*R | 2*Q */

        /* Inverse NTT on z */
        addi a0, s2, 0
        la  a1, twiddles_inv
        jal x1, intt

        bn.wsrw 0x0, w16 /* Restore MOD = R | Q */

        /* Sample the next value of y and add it to z. */
        addi a0, s2, 0
        addi a1, s3, 0
        addi a2, s8, 0
        addi a3, s10, 0
        jal  x1, poly_uniform_gamma_1

        /* Update the nonce for y. */
        addi s8, a2, 1

        /* reduce32(z) to move to mod^{+-} for bound check */
        addi a0, s2, 0
        addi a1, s2, 0
        jal x1, poly_reduce32

        /* chknorm */
        addi a0, s2, 0
        li   t0, GAMMA1
        li   t1, BETA
        sub  a1, t0, t1
        jal x1, poly_chknorm

        bne a0, zero, _rej_crypto_sign_signature_internal

        /* Speculatively pack z[i] into the signature. */
        addi a0, s9, 0
        addi a1, s2, 0
        jal x1, polyz_pack
        /* Update the pointer to the end of the packed part. */
        addi s9, a0, 0
    .endr

    /* get *sig + CTILDEBYTES + L*POLYZ_PACKEDBYTES */
    addi a0, s9, 0

    /* Set hint bytes at end of signature (length omega + k) to 0. Round to
       next word boundary. */
    li    t1, OMEGA
    addi  t1, t1, K
    addi  t1, t1, 3
    srli  t1, t1, 2
    LOOP  t1, 2
      sw   x0, 0(a0)
      addi a0, a0, 4

    addi a0, s9, 0

    /* Load pointer to packed S2. */
    li   s0, STACK_SK
    add  s0, fp, s0
    lw   s0, 0(s0)
#if DILITHIUM_MODE == 2
    addi s2, s0, 512
#elif DILITHIUM_MODE == 3
    addi s2, s0, 768
#elif DILITHIUM_MODE == 5
    addi s2, s0, 800
#endif

    /* Load pointer to packed T0. */
#if DILITHIUM_MODE == 2
    addi s0, s0, 896
#elif DILITHIUM_MODE == 3
    addi s0, s0, 1536
#elif DILITHIUM_MODE == 5
    addi s0, s0, 1568
#endif

    /* Initialize some pointers for the loop. */
    li  s1, STACK_H
    add s1, fp, s1
    li  s3, STACK_W0
    add s3, fp, s3
    li  s5, STACK_W1
    add s5, fp, s5
    li  s7, STACK_CP
    add s7, fp, s7
    li  s10, STACK_TMP
    add s10, fp, s10

    /* Initialize the coefficient sum for the hint for post-check. */
    li  s4, 0

    /* Initialize the counter for the index in the hint vector. */
    li  s6, 0

    /* Normalize w0 to the [0, q) range (in-place). */
    addi   a0, s3, 0
    li     t1, 1
    la     t0, modulus
    bn.lid t1, 0(t0)
    LOOPI K, 6
        LOOPI 32, 4
            bn.lid      x0, 0(a0)
            bn.addv.8S  w0, w0, w1
            bn.addvm.8S w0, bn0, w0
            bn.sid      x0, 0(a0++)
        NOP

    /* This loop computes the hint one element at a time, and performs
       rejection sampling. For each index i=0..k-1, it does:

         tmp = cp * s2[i]
         w0[i] -= tmp
         tmp = reduce32(w0[i])
         if not poly_chknorm(tmp, gamma - beta):
           reject
         tmp = cp * t0[i]
         h = reduce32(tmp)
         if not poly_chknorm(h, gamma):
           reject
         w0[i] += h
         if not poly_chknorm(w0[i], gamma - beta):
           reject
         make_hint(h, w0[i], w1[i]) # gets written directly into signature
     */
    .rept K
        /* Unpack the next polynomial from s2. */
        addi a0, s10, 0
        addi a1, s2, 0
        jal  x1, polyeta_unpack
        addi a0, a0, -1024

        /* Update the packed s2 pointer. */
        addi s2, a1, 0

        bn.wsrw 0x0, mod_x2 /* MOD = 2*R | 2*Q */

        /* Compute ntt(s2[i]) in-place. */
        la   a1, twiddles_fwd
        addi a2, a0, 0
        jal x1, ntt

        /* tmp = cp * s2 */
        addi a0, s10, 0
        addi a1, s7, 0
        addi a2, s10, 0
        jal  x1, poly_pointwise

        /* Inverse NTT on tmp */
        addi a0, s10, 0
        la  a1, twiddles_inv
        jal x1, intt

        bn.wsrw 0x0, w16 /* Restore MOD = R | Q */

        /* w0[i] -= tmp */
        addi a0, s3, 0
        addi a1, s10, 0
        addi a2, s3, 0
        jal  x1, poly_sub

        /* tmp = reduce32(w0[i]) to move to mod^{+-} for bound check */
        addi a0, s3, 0
        addi a1, s10, 0
        jal  x1, poly_reduce32

        /* chknorm(tmp, gamma2 - beta) */
        addi a0, s10, 0
        li   t0, GAMMA2
        li   t1, BETA
        sub  a1, t0, t1
        jal  x1, poly_chknorm
        bne  a0, zero, _rej_crypto_sign_signature_internal

        /* Unpack the next polynomial from t0. */
        addi a0, s10, 0
        addi a1, s0, 0
        jal  x1, polyt0_unpack

        /* Update the packed t0 pointer. */
        addi s0, a1, 0

        bn.wsrw 0x0, mod_x2 /* MOD = 2*R | 2*Q */

        /* Compute ntt(t0[i]) in-place. */
        addi a0, s10, 0
        la   a1, twiddles_fwd
        addi a2, a0, 0
        jal x1, ntt

        /* tmp = cp * t0 */
        addi a0, s10, 0
        addi a1, s7, 0
        addi a2, s10, 0
        jal  x1, poly_pointwise

        /* Inverse NTT on tmp */
        addi a0, s10, 0
        la  a1, twiddles_inv
        jal x1, intt

        bn.wsrw 0x0, w16 /* Restore MOD = R | Q */

        /* w0[i] += tmp */
        addi a0, s3, 0
        addi a1, s10, 0
        addi a2, s3, 0
        jal  x1, poly_add

        /* h = reduce32(tmp) to move to mod^{+-} for bound check */
        addi a0, s10, 0
        addi a1, s1, 0
        jal  x1, poly_reduce32

        /* chknorm(h, gamma2) */
        li   a1, GAMMA2
        addi a0, s1, 0
        jal  x1, poly_chknorm
        bne  a0, zero, _rej_crypto_sign_signature_internal

        /* h[i] = make_hint(w0[i], w1[i]) */
        addi   a0, s1, 0
        addi   a1, s3, 0
        bn.lid x0, 0(s5++)
        jal    x1, poly_make_hint

        /* Update the coefficient sum accumulator (saving previous value). */
        add  a2, s4, 0
        add  s4, s4, a0

        /* If the accumulator (# nonzero coeffs in h) is > omega, reject. */
        li   t0, OMEGA
        sub  t0, t0, s4
        srli t0, t0, 31
        bne  zero, t0, _rej_crypto_sign_signature_internal

        /* Encode h[i] into the signature. */
        addi a0, s9, 0
        addi a1, s1, 0
        addi a3, s6, 0
        jal  x1, poly_encode_h

        /* Increment i. */
        addi s6, s6, 1
        /* Update pointer into w0. */
        addi s3, s3, 1024
    .endr

    /* Return success and signature length */
    li a0, 0
    li a1, CRYPTO_BYTES

    /* Free space on the stack */
    addi sp, fp, 0
  ret
