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
/* #define SWSHAKE */

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

/**
 * Dilithium Key Pair generation
 *
 * Returns: 0 on success
 *
 * @param[in]  x10: zeta (random bytes)
 * @param[in]  x31: dptr_tw, dmem pointer to array of twiddle factors
 * @param[out] x10: dmem pointer to public key
 * @param[out] x11: dmem pointer to private key
 *
 * clobbered registers: a0-a6, t0-t5, s1, w0-w30
 */
.globl crypto_sign_keypair
crypto_sign_keypair:
    /* Stack address mapping */
    #define STACK_SEEDBUF -160
        #define STACK_RHO -160
        #define STACK_RHOPRIME -128
        #define STACK_KEY -64
    #define STACK_PK_ADDR -164
    #define STACK_SK_ADDR -168
    #define STACK_TR      -256
    #define STACK_TMP    -1280 /* Prev - 1024 */
    #define STACK_S1     -2304 /* Prev - 1024 */
#if DILITHIUM_MODE == 2
    #define STACK_T -6400 /* Prev - K*1024 */
    #define INIT_SP -6400
    #define STACK_SIZE 6528 /* Expected stack size for reference (unused). */
#elif DILITHIUM_MODE == 3
    #define STACK_T -8448 /* Prev - K*1024 */
    #define INIT_SP -8448
    #define STACK_SIZE 8576 /* Expected stack size for reference (unused). */
#elif DILITHIUM_MODE == 5
    #define STACK_T -10496 /* Prev - K*1024 */
    #define INIT_SP -10496
    #define STACK_SIZE 10624 /* Expected stack size for reference (unused). */
#endif
    /* Initialize the frame pointer */
    addi fp, sp, 0

    /* Reserve space on the stack */
    li  t0, INIT_SP
    add sp, sp, t0

    /* Store parameters to stack */
    li  t0, STACK_PK_ADDR
    add t0, fp, t0
    sw  a1, 0(t0)
    li  t0, STACK_SK_ADDR
    add t0, fp, t0
    sw  a2, 0(t0)

    /* Copy zeta to seedbuf */
    li t1, 0
    bn.lid t1, 0(a0) /* load zeta */
    addi a0, fp, STACK_SEEDBUF /* load seedbuf address */
    bn.sid t1, 0(a0)

    /* Insert K, L at end of seedbuf */
    li t2, 0xFFFF
    lw t3, SEEDBYTES(a0)
    and t3, t3, t2
    li t4, K
    or t3, t3, t4
    li t4, L
    slli t4, t4, 8
    or t3, t3, t4
    sw t3, SEEDBYTES(a0)

    /* Initialize a SHAKE256 operation. */
    addi  a1, zero, SEEDBYTES
    addi  a1, a1, 2 /* SEEDBYTES+2 */
    slli  t0, a1, 5
    addi  t0, t0, SHAKE256_CFG
    csrrw zero, KECCAK_CFG_REG, t0

    /* Send the message to the Keccak core. */
    /* a0 already contains *seedbuf */
    /* a1 already contains SEEDBYTES + 2 */
    jal  x1, keccak_send_message

    /* Squeeze into output buffer */
    addi t1, fp, STACK_SEEDBUF /* load seedbuf address */
    /* Read the digest and store to memory.
       dmem[STACK_SEEDBUF] <= SHAKE256(zeta, 1024) */
    li t0, 8
    /* This gets 2*SEEDBYTES + CRHBYTES of data */
    LOOPI 4, 2
        bn.wsrr w8, 0xA /* KECCAK_DIGEST */
        bn.sid  t0, 0(t1++) /* Store into buffer */

    /* Finish the SHAKE-256 operation. */

    bn.wsrr   w16, mod /* w16 = R | Q */
    bn.shv.8S w22, w16 << 1 /* w22 = 2*R | 2*Q */
    bn.wsrw   mod, w22 /* MOD = 2*R | 2*Q */

    /* Load source pointers for matrix-vector multiplication. */
    li  s0, STACK_S1
    add s0, fp, s0
    li  s1, STACK_TMP
    add s1, fp, s1

    /* Load destination pointer for matrix-vector multiplication. */
    li  s2, STACK_T
    add s2, fp, s2

    /* Zero the destination buffer. */
    li t0, 31
    addi t1, s2, 0
    LOOPI K, 3
        LOOPI 32, 1
          bn.sid t0, 0(t1++)
        nop

    /* Load offset for resetting vector pointer. */
    li s3, POLYVECK_BYTES

    /* Initialize the nonce for matrix expansion. This value should be
         byte(i) || byte(j)
       for entry A[i][j]. */
    bn.xor w23, w23, w23

    /* Load pointer to twiddle factors for NTT */
    la  s5, twiddles_fwd

    /* Initialize the nonce for sampling s1. */
    li   s6, 0

    /* Load the destination for packed s1 within the secret key. */
    li   t1, STACK_SK_ADDR
    add  t1, fp, t1
    lw   s7, 0(t1)
    addi s7, s7, 128

    /* Precompute the SHAKE128 configuration for poly_uniform. */
    addi  s4, zero, 34
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
    loopi L, 38
        bn.wsrw   mod, w16 /* MOD = R | Q */
        /* Sample the next polynomial from s1. */
        addi a0, fp, STACK_RHOPRIME
        addi a1, s0, 0
        addi a2, s6, 0
        jal  x1, poly_uniform_eta
        addi s6, s6, 1
        /* Start the SHAKE128 operation for poly_uniform for A[0][j]. */
        csrrw zero, kmac_cfg, s4
        addi  a0, fp, STACK_RHO
        bn.lid    x0, 0(a0)
        bn.wsrw   kmac_msg, w0
        bn.wsrw   kmac_msg, w23
        /* Pack the s1 polynomial into the secret key. */
        addi a0, s7, 0
        addi a1, s0, 0
        jal x1, polyeta_pack
        addi s7, a0, 0
        bn.wsrw   mod, w22 /* MOD = 2*R | 2*Q */
        /* Compute ntt(s1[j]). */
        addi a0, s0, 0
        addi a1, s5, 0
        addi a2, s0, 0
        jal  x1, ntt
        loopi K, 13
            /* Compute A[i][j]. */
            addi a1, s1, 0
            jal  x1, poly_uniform
            /* Increment the row in the matrix nonce (upper byte). */
            bn.addi w23, w23, 256
            /* Start the SHAKE128 operation for poly_uniform for A[i+1][j]. */
            csrrw zero, kmac_cfg, s4
            addi  a0, fp, STACK_RHO
            bn.lid    x0, 0(a0)
            bn.wsrw   kmac_msg, w0
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
    li  a0, STACK_T
    add a0, fp, a0
    la  a1, twiddles_inv

    LOOPI K, 3
        jal  x1, intt
        addi a1, a1, -960 /* Reset the twiddle pointer */
        addi a0, a0, 1024 /* Go to next input polynomial */
    bn.wsrw 0x0, w16 /* Restore MOD = R | Q */

    /* Load pointers for loop. */
    li  s0, STACK_TMP
    add s0, fp, s0
    li  s1, STACK_T
    add s1, fp, s1

    /* Initialize the nonce for sampling s2. */
    li s6, L

    /* This loop samples s2 and adds it to A*s1 (currently in the t buffer). */
    LOOPI K, 14
        /* Sample the next polynomial from s2 and store in temp buffer. */
        addi a0, fp, STACK_RHOPRIME
        addi a1, s0, 0
        addi a2, s6, 0
        jal  x1, poly_uniform_eta
        addi s6, s6, 1
        /* Pack the s2 polynomial into the secret key. */
        addi a0, s7, 0
        addi a1, s0, 0
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
    li  s1, STACK_T
    add s1, fp, s1

    LOOPI K, 9
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

    /* Pack pk */

    /* Load rho pointer */
    li t1, STACK_RHO
    add t1, fp, t1

    /* w0 <= rho */
    addi   t0, zero, 0
    bn.lid t0, 0(t1)
    /* Load pk pointer */
    li     t1, STACK_PK_ADDR
    add    t1, fp, t1
    lw     a0, 0(t1)
    /* Store rho */
    bn.sid t0, 0(a0++)

    /* Load pointer to t1 */
    li  a1, STACK_T
    add a1, fp, a1

    /* Pack t1 */
    LOOPI K, 2
        jal x1, polyt1_pack
        nop

    /* Hash pk */

    /* Initialize a SHAKE256 operation. */
    li    a1, CRYPTO_PUBLICKEYBYTES
    slli  t0, a1, 5
    addi  t0, t0, SHAKE256_CFG
    csrrw zero, KECCAK_CFG_REG, t0

    /* Send the message to the Keccak core. */
    /* Load pk pointer */
    li     t1, STACK_PK_ADDR
    add    t1, fp, t1
    lw     a0, 0(t1)
    /* a1 already contains CRYPTO_PUBLICKEYBYTES */
    jal  x1, keccak_send_message

    /* Squeeze into output buffer */
    /* load seedbuf address */
    li  t0, STACK_TR
    add t1, fp, t0

    /* Read the digest.
       dmem[STACK_SEEDBUF] <= SHAKE256(zeta, 1024) */
    li      t0, 0
    bn.wsrr w0, 0xA /* KECCAK_DIGEST */
    bn.sid  t0, 0(t1++) /* Store into buffer */
    bn.wsrr w0, 0xA /* KECCAK_DIGEST */
    bn.sid  t0, 0(t1) /* Store into buffer */

    /* Finish the SHAKE-256 operation. */

    /* Pack sk */

    /* Load sk pointer */
    li  t1, STACK_SK_ADDR
    add t1, fp, t1
    lw  a0, 0(t1)

    /* Load rho pointer */
    li     t1, STACK_RHO
    add    t1, fp, t1
    /* w0 <= rho */
    li     t0, 0
    bn.lid t0, 0(t1)
    /* Store rho */
    bn.sid t0, 0(a0++)

    /* Load key pointer */
    li     t1, STACK_KEY
    add    t1, fp, t1
    /* w0 <= key */
    addi   t0, zero, 0
    bn.lid t0, 0(t1)
    /* Store key */
    bn.sid t0, 0(a0++)

    /* Load tr pointer */
    li     t1, STACK_TR
    add    t1, fp, t1
    /* w0 <= tr */
    addi   t0, zero, 0
    bn.lid t0, 0(t1++)
    /* Store tr */
    bn.sid t0, 0(a0++)
    bn.lid t0, 0(t1++)
    bn.sid t0, 0(a0++)

    /* Free space on the stack */
    addi sp, fp, 0
    ret
