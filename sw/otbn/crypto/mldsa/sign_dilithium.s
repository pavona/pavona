/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors */
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

/*
 * Send a variable-length message to the Keccak core.
 *
 * Expects the Keccak core to have already received a `start` command matching
 * the desired hash function. After calling this routine, reading from the
 * KECCAK_DIGEST special register will return the hash digest.
 *
 * @param[in]   a1: len, byte-length of the message
 * @param[in]   a0: dptr_msg, pointer to message in DMEM
 * @param[in]   w31: all-zero
 * @param[in] dmem[dptr_msg..dptr_msg+len]: msg, hash function input
 *
 * clobbered registers: t0, a1, w0
 * clobbered flag groups: None
 */
keccak_send_message:
  /* Compute the number of full 256-bit message chunks.
  t0 <= x11 >> 5 = floor(len / 32) */
  srli t0, x11, 5

  /* Write all full 256-bit sections of the test message. */
  beq  t0, zero, _no_full_wdr

  loop t0, 2
      /* w0 <= dmem[x10..x10+32] = msg[32*i..32*i-1]
         x10 <= x10 + 32 */
      bn.lid  x0, 0(x10++)
      /* Write to the KECCAK_MSG wide special register (index 9).
         KECCAK_MSG <= w0 */
      bn.wsrw 0x9, w0

_no_full_wdr:
  /* Compute the remaining message length.
       t0 <= x11 & 31 = len mod 32 */
  andi t0, x11, 31

  /* If the remaining length is zero, return early. */
  beq t0, x0, _keccak_send_message_end

  bn.lid  x0, 0(x10)
  bn.wsrw 0x9, w0

  _keccak_send_message_end:
  ret

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
.global sign_dilithium
sign_dilithium:
    /* Stack address mapping */
    #define STACK_SIG -4
    #define STACK_MSG -8
    #define STACK_MSGLEN -12
    #define STACK_SK -16
    #define STACK_TR -96 /* Prev - 16 - 64 */
        #define STACK_MU -96 /* Prev */
    #define STACK_RHO -128 /* Prev - 32 */
        #define STACK_RND -128 /* Prev */
    #define STACK_KEY -160 /* Prev - 32 */
    #define STACK_RHOPRIME  -160 /* Prev */
#if DILITHIUM_MODE == 2
    #define STACK_T0  -4256 /* Prev - K*1024 */
    #define STACK_S1  -8352 /* Prev - L*1024 */
    #define STACK_S2  -12448 /* Prev - K*1024 */
    #define STACK_MAT -28832 /* Prev - K*L*1024 */
    #define STACK_Y -32928 /* Prev - K*1024 */
        #define STACK_H -32928 /* Prev */
        #define STACK_TMP_POLYVEC -32928 /* Prev */
    #define STACK_Z -37024 /* Prev - L*1024 */
    #define STACK_W1 -41120 /* Prev - K*1024 */
    #define STACK_W0 -45216 /* Prev - K*1024 */
    #define STACK_CP -46240 /* Prev - 1024 */
        #define STACK_CTXLEN -46240 /* Prev */
        #define STACK_CTX -46244 /* Prev - 4 */
    #define SIGNATURE -48672 /* Prev - ((CRYPTO_BYTES>>5)+1)*1024 */

#elif DILITHIUM_MODE == 3
    #define STACK_T0  -6304 /* Prev - K*1024 */
    #define STACK_S1  -11424 /* Prev - L*1024 */
    #define STACK_S2  -17568 /* Prev - K*1024 */
    #define STACK_MAT -48288 /* Prev - K*L*1024 */
    #define STACK_Y -54432 /* Prev - K*1024 */
        #define STACK_H -54432 /* Prev */
        #define STACK_TMP_POLYVEC -54432 /* Prev */
    #define STACK_Z -59552 /* Prev - L*1024 */
    #define STACK_W1 -65696 /* Prev - K*1024 */
    #define STACK_W0 -71840 /* Prev - K*1024 */
    #define STACK_CP -72864 /* Prev - 1024 */
        #define STACK_CTXLEN -72864 /* Prev */
        #define STACK_CTX -72868 /* Prev - 4 */
    #define SIGNATURE -76192 /* Prev - ((CRYPTO_BYTES>>5)+1)*32 */
    
#elif DILITHIUM_MODE == 5
    #define STACK_T0  -8352 /* Prev - K*1024 */
    #define STACK_S1  -15520 /* Prev - L*1024 */
    #define STACK_S2  -23712 /* Prev - K*1024 */
    #define STACK_MAT -81056 /* Prev - K*L*1024 */
    #define STACK_Y -89248 /* Prev - K*1024 ; actually, L is enough but we overlap with TMP */
        #define STACK_H -89248 /* Prev */
        #define STACK_TMP_POLYVEC -89248 /* overlap */
    #define STACK_Z -96416 /* Prev - L*1024 */
    #define STACK_W1 -104608 /* Prev - K*1024 */
    #define STACK_W0 -112800 /* Prev - K*1024 */
    #define STACK_CP -113824 /* Prev - 1024 */
        #define STACK_CTXLEN -113824 /* Prev */
        #define STACK_CTX -113828 /* Prev - 4 */
    #define SIGNATURE -118464 /* Prev - ((CRYPTO_BYTES>>5)+1)*32 */
#endif
    /* Initialize the frame pointer */
    addi fp, sp, 0

    /* Reserve space on the stack */
#if DILITHIUM_MODE == 2
    li  t0, -48672
#elif DILITHIUM_MODE == 3
    li  t0, -76192
#elif DILITHIUM_MODE == 5
    li  t0, -118464
#endif
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

    
    /* Unpack s1 */
    /* Load pointer to s1 */
    li   a0, STACK_S1
    add  a0, fp, a0
    /* Load pointer to packed s1 */
    addi a1, a3, 0

    LOOPI L, 2
        jal x1, polyeta_unpack_dilithium
        nop
    
    /* Unpack s2 */
    /* Load pointer to s2 */
    li  a0, STACK_S2
    add a0, fp, a0

    LOOPI K, 2
        jal x1, polyeta_unpack_dilithium
        nop

    /* Unpack t0 */
    /* Load pointer to t0 */
    li  a0, STACK_T0
    add a0, fp, a0

    LOOPI K, 2
        jal x1, polyt0_unpack_dilithium
        nop

    /* CRH(tr, msg) */

    /* Initialize a SHAKE256 operation. */
    li a1, TRBYTES
    addi a1, a1, 2 /* Add len of ctxlen */
    
    li t2, STACK_CTXLEN
    add t2, fp, t2
    lw t2, 0(t2) /* t2 <= ctxlen */
    add a1, a1, t2 /* Add len(ctx) */

    li  t2, STACK_MSGLEN
    add t2, fp, t2
    lw  t2, 0(t2)
    add a1, a1, t2 /* Add msglen */

    slli  t0, a1, 5
    addi  t0, t0, SHAKE256_CFG
    csrrw zero, KECCAK_CFG_REG, t0

    push a1
    /* Send TR to the Keccak core. */
    li  a1, TRBYTES /* set message length to TRBYTES */
    li  a0, STACK_TR
    add a0, fp, a0
    jal x1, keccak_send_message
    pop a1

    /* Copy ctxlen (2B)||ctx (???B) to continous memory location */
    li t2, STACK_CTXLEN
    add a0, fp, t2
    lw t2, 0(a0) /* t2 <= ctxlen */
    li t3, STACK_CP /* Re-use CP buffer for absorbing ctxlen and ctx */
    add t3, fp, t3

    /* Note: Add support for non-4B multiple ctxlen */
    /* Compute number of iterations */
    srli t4, t2, 2 /* Divide by 4 because of word-wise operation*/

    /* Create mask for clearing upper bits */
    addi t6, zero, -1
    srli t6, t6, 16

    /* Add 0-byte */
    slli t2, t2, 8
    /* Clear upper bits */
    slli t2, t2, 16
    srli t2, t2, 16

    /* Get ctx pointer */
    li a0, STACK_CTX
    add a0, fp, a0
    lw a0, 0(a0) /* a0 <= *ctx */

    /* Load first ctx word and merge it with the 2 bytes from 0||ctxlen */
    lw t5, 0(a0)
    slli t5, t5, 16
    or t2, t5, t2
    sw t2, 0(t3) /* First store to buffer */
    addi t3, t3, 4 /* First write done */

    addi t4, t4, -1

    LOOP t4, 8
        /* Load word from ctx: c */
        lw t2, 0(a0)
        srli t2, t2, 16
        /* Load next word from ctx: c' */
        lw t5, 4(a0)
        slli t5, t5, 16 /* Shift lower bits to the top half for merging */
        addi a0, a0, 4/* Increment address */

        /* Merge remaining two bytes from c with first two bytes of c' */
        or t2, t2, t5
        /* Store c[2:]||c'[:2] to buffer */
        sw t2, 0(t3)
        addi t3, t3, 4

    /* Use last 2B from the ctx that will be left over to merge with the message */
    lw t2, 0(a0)
    srli t2, t2, 16

    /* Load first word of the message and combinde with remainder from ctx */
    li  a0, STACK_MSG
    add a0, fp, a0
    lw  a0, 0(a0) /* loads msg pointer */

    lw t4, 0(a0)
    slli t4, t4, 16 /* Clear upper bits and move in place for merging */
    /* merge ctx and msg */
    or t2, t2, t4

    /* First store */
    sw t2, 0(t3) /* First store to buffer */
    addi t3, t3, 4 /* First write done */

    /* Compute number of iterations from msglen */
    li  t4, STACK_MSGLEN
    add t4, fp, t4
    lw  t4, 0(t4)

    /* Divide msglen by wordsize */
    /* NOTE: Add support for non multiple of 4B */
    srli t4, t4, 2

    addi t4, t4, -1

    /* Iterate over remaining message bytes */
    LOOP t4, 8
        /* Load word from msg: m */
        lw t2, 0(a0)
        srli t2, t2, 16
        /* Load next word from msg: m' */
        lw t5, 4(a0)
        slli t5, t5, 16 /* Shift lower bits to the top half for merging */
        addi a0, a0, 4/* Increment address */

        /* Merge remaining two bytes from m with first two bytes of m' */
        or t2, t2, t5

        /* Store m[2:]||m'[:2] to buffer */
        sw t2, 0(t3)
        addi t3, t3, 4
    
    /* Store last two message bytes */
    lw t2, 0(a0) /* Load last two bytes */
    srli t2, t2, 16
    sw t2, 0(t3)

    /* a1 still contains length but includes TRBYTES */
    addi a1, a1, -TRBYTES

    li t3, STACK_CP /* Re-use CP buffer for absorbing ctxlen and ctx */
    add a0, fp, t3

    jal x1, keccak_send_message

    /* Setup WDR */
    li t1, 8

    /* Write SHAKE output to dmem */
    li      a0, STACK_MU
    add     a0, fp, a0
    bn.wsrr w8, 0xA     /* KECCAK_DIGEST */
    bn.sid  t1, 0(a0++) /* Store into mu buffer */
    bn.wsrr w8, 0xA     /* KECCAK_DIGEST */
    bn.sid  t1, 0(a0++) /* Store into mu buffer */

    /* Finish the SHAKE-256 operation. */

    /* Expand matrix */
    /* Initialize the nonce */
    li a2, 0

    li a1, STACK_MAT
    add a1, fp, a1
    LOOPI K, 10
        LOOPI L, 7
            /* Load parameters */
            addi a0, fp, STACK_RHO
            push a2
            jal  x1, poly_uniform
            pop a2
            addi a2, a2, 1
        addi a2, a2, 256
        addi a2, a2, -L

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

    /* NTT(s1) */
    li   a0, STACK_S1
    add  a0, fp, a0
    addi a2, a0, 0 /* Inplace */
    la   a1, twiddles_fwd

    .irp reg,t0,t1,t2,t3,t4,t5,t6,a0,a1,a2,a3,a4,a5,a6,a7
       push \reg
    .endr

    LOOPI L, 2
        jal x1, ntt_dilithium
        addi a1, a1, -1024 /* Reset twiddle pointer */

    .irp reg,a7,a6,a5,a4,a3,a2,a1,a0,t6,t5,t4,t3,t2,t1,t0
        pop \reg
    .endr

    /* NTT(s2) */
    li   a0, STACK_S2
    add  a0, fp, a0
    addi a2, a0, 0 /* inplace */

    .irp reg,t0,t1,t2,t3,t4,t5,t6,a0,a1,a2,a3,a4,a5,a6,a7
       push \reg
    .endr

    LOOPI K, 2
      jal  x1, ntt_dilithium
      addi a1, a1, -1024 /* Reset twiddle pointer */

    .irp reg,a7,a6,a5,a4,a3,a2,a1,a0,t6,t5,t4,t3,t2,t1,t0
        pop \reg
    .endr

    /* NTT(t0) */
    li   a0, STACK_T0
    add  a0, fp, a0
    addi a2, a0, 0 /* Inplace */

    .irp reg,t0,t1,t2,t3,t4,t5,t6,a0,a1,a2,a3,a4,a5,a6,a7
       push \reg
    .endr

    LOOPI K, 2
        jal x1, ntt_dilithium
        addi a1, a1, -1024 /* Reset twiddle pointer */

    .irp reg,a7,a6,a5,a4,a3,a2,a1,a0,t6,t5,t4,t3,t2,t1,t0
        pop \reg
    .endr

    li s11, 0 /* nonce */

_rej_sign_dilithium:
    /* Uniform GAMMA1 */
    li  a1, STACK_RHOPRIME
    add a1, fp, a1
    
    li  a0, STACK_Y
    add a0, fp, a0

    addi a2, s11, 0 /* Compute nonce */
    la   a3, gamma1_vec_const

    LOOPI L, 2
        jal  x1, poly_uniform_gamma1_dilithium
        addi a2, a2, 1 /* a2 should be preserved after execution */
    
    addi s11, s11, L

    /* NTT(Y) -> Z */
    li  a0, STACK_Y
    add a0, fp, a0 /* in */
    li  a2, STACK_Z
    add a2, fp, a2 /* out */
    la  a1, twiddles_fwd

  .irp reg,t0,t1,t2,t3,t4,t5,t6,a0,a1,a2,a3,a4,a5,a6,a7
     push \reg
  .endr

    LOOPI L, 2
        jal x1, ntt_dilithium
        addi a1, a1, -1024

    .irp reg,a7,a6,a5,a4,a3,a2,a1,a0,t6,t5,t4,t3,t2,t1,t0
      pop \reg
    .endr

    /* Matrix-vector multiplication */

    /* Load source pointers */
    li  a0, STACK_Z
    add a0, fp, a0
    li  a1, STACK_MAT
    add a1, fp, a1

    /* Load destination pointer */
    li  a2, STACK_W1
    add a2, fp, a2

    /* Load offset for resetting pointer */
    li s0, POLYVECL_BYTES

    .rept K
        jal  x1, poly_pointwise_dilithium
        addi a2, a2, -1024
        .rept L-1
            jal  x1, poly_pointwise_acc_dilithium
            addi a2, a2, -1024
        .endr
        /* Reset input vector pointer */
        sub  a0, a0, s0
        addi a2, a2, 1024
    .endr

    /* Inverse NTT on w1 */
    li  a0, STACK_W1
    add a0, fp, a0
    la  a1, twiddles_inv
   
    .irp reg,t0,t1,t2,t3,t4,t5,t6,a0,a1,a2,a3,a4,a5,a6,a7
        push \reg
    .endr

    LOOPI K, 3
        jal x1, intt_dilithium
        /* Reset the twiddle pointer */
        addi a1, a1, -960
        /* Go to next input polynomial */
        addi a0, a0, 1024
    
    .irp reg,a7,a6,a5,a4,a3,a2,a1,a0,t6,t5,t4,t3,t2,t1,t0
        pop \reg
    .endr

    /* Load source pointers */

    /* Decompose */
    li   a2, STACK_W1 /* Input */
    add  a2, fp, a2
    addi a1, a2, 0    /* Output inplace */
    li   a0, STACK_W0 /* Output */
    add  a0, fp, a0
    
    LOOPI K, 2
        jal x1, poly_decompose_dilithium
        nop

    /* Pack w1 */
    li  a1, STACK_W1 /* Get *w1 */
    add a1, fp, a1
    /* Use an offset of 16 to accomodate for the alignment hack for CTILDE */
    li  a0, STACK_SIG
    add a0, fp, a0
    lw  a0, 0(a0) /* Get *sig */
#if CTILDEBYTES == 48
    addi a0, a0, 16
#endif

    LOOPI K, 2
        jal x1, polyw1_pack_dilithium
        nop

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

    /* Send packed w1 to the Keccak core. */
    /* set packed w1 length to K*POLYW1_PACKEDBYTES */
    li a1, 0
    LOOPI K, 1
        addi a1, a1, POLYW1_PACKEDBYTES
    /* Use an offset of 16 to accomodate for the alignment hack for CTILDE */
    li   a0, STACK_SIG
    add  a0, fp, a0
    lw   a0, 0(a0) /* get *sig */
    addi s0, a0, 0 /* save a0 */
#if CTILDEBYTES == 48
    addi a0, a0, 16
#endif
    jal  x1, keccak_send_message

    /* Setup WDR */
    li t1, 8

#if CTILDEBYTES == 32
    bn.wsrr w8, 0xA   /* KECCAK_DIGEST */
    addi    a0, s0, 0 /* restore a0 */
    /* Get temp buffer */
    li   t0, STACK_CP
    add  t0, fp, t0
    bn.sid  t1, 0(t0) /* Store CTILDE into temp buffer */
    LOOPI 8, 4
        lw t2, 0(t0)
        sw t2, 0(a0)
        addi t0, t0, 4
        addi a0, a0, 4
    
    addi a0, a0, -CTILDEBYTES
#elif CTILDEBYTES == 48
    bn.wsrr w8, 0xA   /* KECCAK_DIGEST */
    addi    a0, s0, 0 /* restore a0 */

    /* Get temp buffer */
    li   t0, STACK_CP
    add  t0, fp, t0
    bn.sid  t1, 0(t0) /* Store CTILDE into temp buffer */
    LOOPI 8, 4
        lw t2, 0(t0)
        sw t2, 0(a0)
        addi t0, t0, 4
        addi a0, a0, 4

    bn.wsrr w8, 0xA   /* KECCAK_DIGEST */

    bn.sid  t1, 0(t0) /* Store CTILDE into temp buffer */
    LOOPI 4, 4
        lw t2, 0(t0)
        sw t2, 0(a0)
        addi t0, t0, 4
        addi a0, a0, 4
    
    addi a0, a0, -CTILDEBYTES
#elif CTILDEBYTES == 64
    bn.wsrr w8, 0xA   /* KECCAK_DIGEST */
    addi    a0, s0, 0 /* restore a0 */

    /* Get temp buffer */
    li   t0, STACK_CP
    add  t0, fp, t0
    bn.sid  t1, 0(t0) /* Store CTILDE into temp buffer */
    LOOPI 8, 4
        lw t2, 0(t0)
        sw t2, 0(a0)
        addi t0, t0, 4
        addi a0, a0, 4

    bn.wsrr w8, 0xA   /* KECCAK_DIGEST */

    bn.sid  t1, 0(t0) /* Store CTILDE into temp buffer */
    LOOPI 8, 4
        lw t2, 0(t0)
        sw t2, 0(a0)
        addi t0, t0, 4
        addi a0, a0, 4
    
    addi a0, a0, -CTILDEBYTES
#endif

    /* Finish the SHAKE-256 operation. */

    /* Challenge */
    /* CTILDE was temporarily stored in STACK_CP. Re-use here because it is aligned,
       for CTILDEBYTES = 48 as well */
    li   a1, STACK_CP
    add  a1, fp, a1
    li   a0, STACK_CP
    add  a0, fp, a0
    jal  x1, poly_challenge

    /* NTT(cp) */
    li   a0, STACK_CP
    add  a0, fp, a0 /* Input */
    addi a2, a0, 0  /* Output inplace */
    la   a1, twiddles_fwd

    .irp reg,t0,t1,t2,t3,t4,t5,t6,a0,a1,a2,a3,a4,a5,a6,a7
        push \reg
    .endr

    jal x1, ntt_dilithium /* Only one polynomial */

    .irp reg,a7,a6,a5,a4,a3,a2,a1,a0,t6,t5,t4,t3,t2,t1,t0
        pop \reg
    .endr

    /* z = cp * s1 */
    li  a0, STACK_CP
    add a0, fp, a0
    li  a1, STACK_S1
    add a1, fp, a1
    li  a2, STACK_Z
    add a2, fp, a2

    LOOPI L, 2
        jal  x1, poly_pointwise_dilithium
        addi a0, a0, -1024

    /* Inverse NTT on z */
    li  a0, STACK_Z
    add a0, fp, a0
    la  a1, twiddles_inv
   
    .irp reg,t0,t1,t2,t3,t4,t5,t6,a0,a1,a2,a3,a4,a5,a6,a7
        push \reg
    .endr

    LOOPI L, 3
        jal  x1, intt_dilithium
        /* Reset the twiddle pointer */
        addi a1, a1, -960
        /* Go to next input polynomial */
        addi a0, a0, 1024
    
    .irp reg,a7,a6,a5,a4,a3,a2,a1,a0,t6,t5,t4,t3,t2,t1,t0
        pop \reg
    .endr

    /* z = z + y */
    li  a0, STACK_Z
    add a0, fp, a0
    li  a1, STACK_Y
    add a1, fp, a1
    li  a2, STACK_Z
    add a2, fp, a2
    
    LOOPI L, 2
        jal x1, poly_add_dilithium
        nop

    /* reduce32(z) to move to mod^{+-} for bound check */
    li  a0, STACK_Z
    add a0, fp, a0
    li  a1, STACK_Z
    add a1, fp, a1
    
    LOOPI L, 2
        jal x1, poly_reduce32_dilithium
        nop

    /* chknorm */
    li  t0, GAMMA1
    li  t1, BETA
    sub a1, t0, t1
    li  s0, STACK_Z
    add s0, fp, s0

    /* Cannot use hardware loop due to branch to _rej_sign_dilithium */
    .rept L
        addi a0, s0, 0
        jal x1, poly_chknorm_dilithium
        addi s0, s0, 1024
        
        /* Reject */
        bne a0, zero, _rej_sign_dilithium
    .endr

    /* h = cp * s2 */
    li  a0, STACK_CP
    add a0, fp, a0
    li  a1, STACK_S2
    add a1, fp, a1
    li  a2, STACK_H
    add a2, fp, a2

    LOOPI K, 2
        jal  x1, poly_pointwise_dilithium
        addi a0, a0, -1024

    /* Inverse NTT on h */
    li  a0, STACK_H
    add a0, fp, a0
    la  a1, twiddles_inv
   
    .irp reg,t0,t1,t2,t3,t4,t5,t6,a0,a1,a2,a3,a4,a5,a6,a7
        push \reg
    .endr

    LOOPI K, 3
        jal  x1, intt_dilithium
        /* Reset the twiddle pointer */
        addi a1, a1, -960
        /* Go to next input polynomial */
        addi a0, a0, 1024

    .irp reg,a7,a6,a5,a4,a3,a2,a1,a0,t6,t5,t4,t3,t2,t1,t0
        pop \reg
    .endr

    /* w0 = w0 + h */
    li     x4, 0
    li     t1, 1
    li     a0, STACK_W0
    add    a0, fp, a0
    la     t0, modulus
    bn.lid t1, 0(t0)
    LOOPI K, 6
        LOOPI 32, 4
            bn.lid      x4, 0(a0)
            bn.addv.8S  w0, w0, w1
            bn.addvm.8S w0, bn0, w0
            bn.sid      x4, 0(a0++)
        NOP

    li  a0, STACK_W0
    add a0, fp, a0
    li  a1, STACK_H
    add a1, fp, a1
    li  a2, STACK_W0
    add a2, fp, a2

    LOOPI K, 2
        jal x1, poly_sub_dilithium
        nop 

    /* reduce32(z) to move to mod^{+-} for bound check */
    li  a0, STACK_W0
    add a0, fp, a0
    li  a1, STACK_W0
    add a1, fp, a1
    
    LOOPI K, 2
        jal x1, poly_reduce32_dilithium
        nop

    /* chknorm */
    li  t0, GAMMA2
    li  t1, BETA
    sub a1, t0, t1
    li  s0, STACK_W0
    add s0, fp, s0

    /* Cannot use hardware loop due to branch to _rej_sign_dilithium */
    .rept K
        addi a0, s0, 0
        jal  x1, poly_chknorm_dilithium
        /* reject */
        bne  a0, zero, _rej_sign_dilithium
        addi s0, s0, 1024
    .endr

    /* h = cp * t0 */
    li  a0, STACK_CP
    add a0, fp, a0
    li  a1, STACK_T0
    add a1, fp, a1
    li  a2, STACK_H
    add a2, fp, a2

    LOOPI K, 2
        jal  x1, poly_pointwise_dilithium
        addi a0, a0, -1024

    /* Inverse NTT on h */
    li  a0, STACK_H
    add a0, fp, a0
    la  a1, twiddles_inv

    .irp reg,t0,t1,t2,t3,t4,t5,t6,a0,a1,a2,a3,a4,a5,a6,a7
        push \reg
    .endr

    LOOPI K, 3
        jal  x1, intt_dilithium
        /* Reset the twiddle pointer */
        addi a1, a1, -960
        /* Go to next input polynomial */
        addi a0, a0, 1024

    .irp reg,a7,a6,a5,a4,a3,a2,a1,a0,t6,t5,t4,t3,t2,t1,t0
        pop \reg
    .endr

    /* w0 = w0 + h */
    li     x4, 0
    li     t1, 1
    li     a0, STACK_W0
    add    a0, fp, a0
    la     t0, modulus
    bn.lid t1, 0(t0)
    LOOPI K, 6
        LOOPI 32, 4
            bn.lid      x4, 0(a0)
            bn.addv.8S  w0, w0, w1
            bn.addvm.8S w0, bn0, w0
            bn.sid      x4, 0(a0++)
        NOP

    li  a0, STACK_W0
    add a0, fp, a0
    li  a1, STACK_H
    add a1, fp, a1
    li  a2, STACK_W0
    add a2, fp, a2

    LOOPI K, 2
        jal x1, poly_add_dilithium
        nop

    /* reduce32(z) to move to mod^{+-} for bound check */
    li  a0, STACK_H
    add a0, fp, a0
    li  a1, STACK_H
    add a1, fp, a1
    
    LOOPI K, 2
        jal x1, poly_reduce32_dilithium
        nop

    /* chknorm */
    li  a1, GAMMA2
    li  s0, STACK_H
    add s0, fp, s0

    /* Cannot use hardware loop due to branch to _rej_sign_dilithium */
    .rept K
        addi a0, s0, 0
        jal  x1, poly_chknorm_dilithium
        /* reject */
        bne  a0, zero, _rej_sign_dilithium
        addi s0, s0, 1024
    .endr

    /* make hint */
    li  s0, 0
    li  s1, STACK_H
    add a0, fp, s1
    li  a1, STACK_W0
    add a1, fp, a1
    li  a2, STACK_W1
    add a2, fp, a2

    LOOPI K, 4
        add  a0, fp, s1
        jal  x1, poly_make_hint_dilithium
        addi s1, s1, 1024
        add  s0, s0, a0

    li   t0, OMEGA
    li   t1, 1
    /* This checks t0 < s0. Writes 1 if true, 0 else */
    sub t2, t0, s0
    srli t2, t2, 31
    /* reject */
    beq  t1, t2, _rej_sign_dilithium

    /* Pack sig */
    li   a0, STACK_SIG
    add  a0, fp, a0
    lw   a0, 0(a0)  /* get *sig */
    /* c is already in sig */
    addi a0, a0, CTILDEBYTES /* increment *sig */
    /* z */
    li   a1, STACK_Z
    add  a1, fp, a1
    LOOPI L, 2
        jal x1, polyz_pack_dilithium
        nop

    /* encode h */
    /* save *sig + CTILDEBYTES + L*POLYZ_PACKEDBYTES */
    addi s0, a0, 0

    /* Set rest of sig to 0 */
    li     t0, 31
    
#if OMEGA == 80
    bn.sid t0, 0(a0++)
    bn.sid t0, 0(a0++)

    LOOPI 5, 2
        sw   zero, 0(a0)
        addi a0, a0, 4
#elif OMEGA == 55
    bn.sid t0, 0(a0++)

    LOOPI 7, 2
        sw   zero, 0(a0)
        addi a0, a0, 4
    /* Set last byte to zero */
    lw t1, 0(a0)
    srli t1, t1, 8
    slli t1, t1, 8
    sw t1, 0(a0)
#elif OMEGA == 75
    bn.sid t0, 0(a0++)
    bn.sid t0, 0(a0++)

    LOOPI 4, 2
        sw   zero, 0(a0)
        addi a0, a0, 4
    lw t1, 0(a0)
    srli t1, t1, 24
    slli t1, t1, 24
    sw t1, 0(a0)
#endif

    addi a0, s0, 0 /* reset *sig */
    li   a1, STACK_H
    add  a1, fp, a1
    jal  x1, polyvec_encode_h_dilithium

    /* Return success and signature length */
    li a0, 0
    li a1, CRYPTO_BYTES

    /* Free space on the stack */
    addi sp, fp, 0
  ret