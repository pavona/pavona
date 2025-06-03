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
 *
 * @param[in]  x10: *sig
 * @param[in]  x11: *msg
 * @param[in]  x12: msglen
 * @param[in]  x13: *sk
 * @param[out] x10: 0 (success)
 * @param[out] x11: siglen
 *
 */
.global sign_plain_dilithium
sign_plain_dilithium:
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
    #define STACK_SHAKE_CONTEXT -48928 /* Prev - 256 */

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
    #define STACK_SHAKE_CONTEXT -76448 /* Prev - 256 */
    
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
    #define STACK_SHAKE_CONTEXT -118720 /* Prev - 256 */
#endif

    /* Initialize the frame pointer */
    addi fp, sp, 0

    /* Reserve space on the stack */
#if DILITHIUM_MODE == 2
    li  t0, -48928
#elif DILITHIUM_MODE == 3
    li  t0, -76448
#elif DILITHIUM_MODE == 5
    li  t0, -118720
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
        jal x1, polyeta_unpack_base_dilithium
        nop
    
    /* Unpack s2 */
    /* Load pointer to s2 */
    li  a0, STACK_S2
    add a0, fp, a0

    LOOPI K, 2
        jal x1, polyeta_unpack_base_dilithium
        nop

    /* Unpack t0 */
    /* Load pointer to t0 */
    li  a0, STACK_T0
    add a0, fp, a0

    LOOPI K, 2
        jal x1, polyt0_unpack_base_dilithium
        nop

    /* CRH(tr, msg) */
    /* Setup WDR */
    li t1, 8

    .irp reg,t0,t1,t2,t3,t4,t5,t6,a0,a1,a2,a3,a4,a5,a6,a7
        push \reg
    .endr
    
    li  x10, STACK_SHAKE_CONTEXT
    add x10, fp, x10
    li x11, 32
    jal x1, sha3_init

    /* Send TR to the Keccak */
    li  x10, STACK_SHAKE_CONTEXT
    add x10, fp, x10
    li  a1, STACK_TR
    add a1, fp, a1
    li x12, TRBYTES
    jal x1, sha3_update

    /* Send CTXLEN to the Keccak */
    li  x10, STACK_SHAKE_CONTEXT
    add x10, fp, x10
    li t2, STACK_CTXLEN
    add a1, fp, t2
    lw t2, 0(a1) /* t2 <= ctxlen */
    slli t2, t2, 8
    sw t2, 0(a1)
    li x12, 2
    jal x1, sha3_update

    /* Send CTX to the Keccak */
    li  x10, STACK_SHAKE_CONTEXT
    add x10, fp, x10
    li t2, STACK_CTX
    add x11, fp, t2
    lw x11, 0(x11) /* x11 <= *ctx */
    li t2, STACK_CTXLEN
    add t2, fp, t2
    lw x12, 0(t2) /* a1 <= ctxlen */
    srli x12, x12, 8
    jal x1, sha3_update

    /* Send MSG to the Keccak */
    li  x10, STACK_SHAKE_CONTEXT
    add x10, fp, x10
    li  a1, STACK_MSG
    add a1, fp, a1
    lw  a1, 0(a1)
    li  a2, STACK_MSGLEN
    add a2, fp, a2
    lw  a2, 0(a2)
    jal x1, sha3_update

    li  x10, STACK_SHAKE_CONTEXT
    add x10, fp, x10
    jal x1, shake_xof
    
    li  x10, STACK_SHAKE_CONTEXT
    add x10, fp, x10
    la x11, STACK_MU
    add x11, fp, x11
    li x12, 64
    jal x1, shake_out

    .irp reg,a7,a6,a5,a4,a3,a2,a1,a0,t6,t5,t4,t3,t2,t1,t0
        pop \reg
    .endr

    /* Expand matrix */
    /* Initialize the nonce */
    li a2, 0

    li a1, STACK_MAT
    add a1, fp, a1
    li  a3, STACK_SHAKE_CONTEXT
    add a3, fp, a3
    LOOPI K, 10
        LOOPI L, 7
            /* Load parameters */
            addi a0, fp, STACK_RHO
            push a2
            jal  x1, poly_uniform_base_dilithium
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

    .irp reg,t0,t1,t2,t3,t4,t5,t6,a0,a1,a2,a3,a4,a5,a6,a7
        push \reg
    .endr
    
    li  x10, STACK_SHAKE_CONTEXT
    add x10, fp, x10
    li x11, 32
    jal x1, sha3_init

    /* Send Key -> RND -> MU to the Keccak */
    li  x10, STACK_SHAKE_CONTEXT
    add x10, fp, x10
    li  a1, STACK_KEY
    add a1, fp, a1
    li x12, SEEDBYTES
    addi x12, x12, RNDBYTES
    addi x12, x12, CRHBYTES
    jal x1, sha3_update

    li  x10, STACK_SHAKE_CONTEXT
    add x10, fp, x10
    jal x1, shake_xof
    
    li  x10, STACK_SHAKE_CONTEXT
    add x10, fp, x10
    la x11, STACK_RHOPRIME
    add x11, fp, x11
    li x12, 64
    jal x1, shake_out

    .irp reg,a7,a6,a5,a4,a3,a2,a1,a0,t6,t5,t4,t3,t2,t1,t0
        pop \reg
    .endr

    /* NTT(s1) */
    li   a0, STACK_S1
    add  a0, fp, a0
    addi a2, a0, 0 /* Inplace */
    la   a1, twiddles_fwd

    .irp reg,t0,t1,t2,t3,t4,t5,t6,a0,a1,a2,a3,a4,a5,a6,a7
       push \reg
    .endr

    LOOPI L, 4
        jal x1, ntt_base_dilithium
        addi a0, a0, 1024
        /* Reset twiddle pointer */
        addi a1, a1, -1152
        addi a1, a1, -1024

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

    LOOPI K, 4
        jal x1, ntt_base_dilithium
        addi a0, a0, 1024
        /* Reset twiddle pointer */
        addi a1, a1, -1152
        addi a1, a1, -1024

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

    LOOPI K, 4
        jal x1, ntt_base_dilithium
        addi a0, a0, 1024
        /* Reset twiddle pointer */
        addi a1, a1, -1152
        addi a1, a1, -1024

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

    li  a4, STACK_SHAKE_CONTEXT
    add a4, fp, a4

    LOOPI L, 2
        jal  x1, poly_uniform_gamma1_base_dilithium
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

    LOOPI L, 4
        jal x1, ntt_base_dilithium
        addi a0, a0, 1024
        /* Reset twiddle pointer */
        addi a1, a1, -1152
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
        jal  x1, poly_pointwise_base_dilithium
        addi a2, a2, -1024
        .rept L-1
            jal  x1, poly_pointwise_acc_base_dilithium
            addi a2, a2, -1024
        .endr
        /* Reset input vector pointer */
        sub  a0, a0, s0
        addi a2, a2, 1024
    .endr

    /* reduce32 w1 */
    li   a0, STACK_W1
    add  a0, fp, a0
    addi a1, a0, 0

    LOOPI K, 2
        jal x1, poly_reduce32_pos_dilithium
        nop

    /* Inverse NTT on w1 */
    li  a0, STACK_W1
    add a0, fp, a0
    la  a1, twiddles_inv
   
    .irp reg,t0,t1,t2,t3,t4,t5,t6,a0,a1,a2,a3,a4,a5,a6,a7
        push \reg
    .endr

    LOOPI K, 3
        jal  x1, intt_base_dilithium
        addi a1, a1, -2048 /* Reset the twiddle pointer */
        addi a0, a0, 960 /* Go to next input poly, +64 already to a0 in intt */
    
    .irp reg,a7,a6,a5,a4,a3,a2,a1,a0,t6,t5,t4,t3,t2,t1,t0
        pop \reg
    .endr

    /* Decompose */
    li   a2, STACK_W1 /* Input */
    add  a2, fp, a2
    addi a1, a2, 0    /* Output inplace */
    li   a0, STACK_W0 /* Output */
    add  a0, fp, a0
    
    LOOPI K, 2
        jal x1, poly_decompose_dilithium
        nop

    /* Move w0 to unsigned domain in [0, q-1] */
    li   a0, STACK_W0
    add  a0, fp, a0
    LOOPI 4, 2
        jal x1, poly_caddq_base_dilithium
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

    /* Setup WDR */
    li t1, 8

    /* Random oracle */
    .irp reg,t0,t1,t2,t3,t4,t5,t6,a0,a1,a2,a3,a4,a5,a6,a7
        push \reg
    .endr
    
    li  x10, STACK_SHAKE_CONTEXT
    add x10, fp, x10
    li x11, 32
    jal x1, sha3_init

    /* Send MU to Keccak */
    li  x10, STACK_SHAKE_CONTEXT
    add x10, fp, x10
    li  a1, STACK_MU
    add a1, fp, a1
    li x12, CRHBYTES
    jal x1, sha3_update

    /* Send w1 to Keccak */
    li  x10, STACK_SHAKE_CONTEXT
    add x10, fp, x10
    /* Use an offset of 16 to accomodate for the alignment hack for CTILDE */
    li   a1, STACK_SIG
    add  a1, fp, a1
    lw   a1, 0(a1) /* get *sig */
    addi s0, a1, 0 /* save a0 */
    #if CTILDEBYTES == 48
        addi a1, a1, 16
    #endif
    li a2, 0 /* set packed w1 length to K*POLYW1_PACKEDBYTES */
    LOOPI K, 1
        addi a2, a2, POLYW1_PACKEDBYTES
    jal x1, sha3_update

    li  x10, STACK_SHAKE_CONTEXT
    add x10, fp, x10
    jal x1, shake_xof

    .irp reg,a7,a6,a5,a4,a3,a2,a1,a0,t6,t5,t4,t3,t2,t1,t0
        pop \reg
    .endr

#if CTILDEBYTES == 32
    li  x10, STACK_SHAKE_CONTEXT
    add x10, fp, x10
    addi x11, s0, 0 /* Store CTILDE into STACK_SIG */
    li x12, 32
    jal x1, shake_out

    addi a0, s0, 0
    bn.lid t1, 0(a0)

    /* Get temp buffer */
    li   t0, STACK_CP
    add  t0, fp, t0
    bn.sid  t1, 0(t0) /* Store CTILDE into temp buffer */

#elif CTILDEBYTES == 48
    li  x10, STACK_SHAKE_CONTEXT
    add x10, fp, x10
    addi x11, s0, 0 /* Store CTILDE into STACK_SIG */
    li x12, 32
    jal x1, shake_out

    li  x10, STACK_SHAKE_CONTEXT
    add x10, fp, x10
    addi x11, s0, 0 /* Store CTILDE into STACK_SIG */
    addi x11, x11, 32
    li x12, 32
    jal x1, shake_out

    addi a0, s0, 0 /* restore *sig */
    /* Get temp buffer */
    li   t0, STACK_CP
    add  t0, fp, t0
    LOOPI 12, 4
        lw t2, 0(a0)
        sw t2, 0(t0)
        addi a0, a0, 4
        addi t0, t0, 4

#elif  CTILDEBYTES == 64
    li  x10, STACK_SHAKE_CONTEXT
    add x10, fp, x10
    addi x11, s0, 0 /* Store CTILDE into STACK_SIG */
    li x12, 64
    jal x1, shake_out

    addi a0, s0, 0 /* restore *sig */
    bn.lid t1, 0(a0)

    /* Get temp buffer */
    li   t0, STACK_CP
    add  t0, fp, t0
    bn.sid  t1, 0(t0) /* Store CTILDE into temp buffer */

    bn.lid t1, 32(a0)
    bn.sid  t1, 32(t0) /* Store CTILDE into temp buffer */
#endif

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

    jal x1, ntt_base_dilithium /* Only one polynomial */

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
        jal  x1, poly_pointwise_base_dilithium
        addi a0, a0, -1024

    /* Inverse NTT on z */
    li  a0, STACK_Z
    add a0, fp, a0
    la  a1, twiddles_inv
   
    .irp reg,t0,t1,t2,t3,t4,t5,t6,a0,a1,a2,a3,a4,a5,a6,a7
        push \reg
    .endr

    LOOPI L, 3
        jal  x1, intt_base_dilithium
        addi a1, a1, -2048 /* Reset the twiddle pointer */
        addi a0, a0, 960 /* Go to next input poly, +64 already to a0 in intt */
    
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
        jal x1, poly_add_pseudovec_base_dilithium
        nop
    
    /* reduce32 z */
    li   a0, STACK_Z
    add  a0, fp, a0
    addi a1, a0, 0

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
        jal x1, poly_chknorm_base_dilithium
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
        jal  x1, poly_pointwise_base_dilithium
        addi a0, a0, -1024

    /* Inverse NTT on h */
    li  a0, STACK_H
    add a0, fp, a0
    la  a1, twiddles_inv
   
    .irp reg,t0,t1,t2,t3,t4,t5,t6,a0,a1,a2,a3,a4,a5,a6,a7
        push \reg
    .endr

    LOOPI K, 3
        jal  x1, intt_base_dilithium
        addi a1, a1, -2048 /* Reset the twiddle pointer */
        addi a0, a0, 960 /* Go to next input poly, +64 already to a0 in intt */

    .irp reg,a7,a6,a5,a4,a3,a2,a1,a0,t6,t5,t4,t3,t2,t1,t0
        pop \reg
    .endr

    /* w0 = w0 - h = w0 - cs2 */
    li  a0, STACK_W0
    add a0, fp, a0
    li  a1, STACK_H
    add a1, fp, a1
    li  a2, STACK_W0
    add a2, fp, a2

    LOOPI K, 2
        jal x1, poly_sub_base_dilithium
        nop 

    /* reduce32 w0 */
    li   a0, STACK_W0
    add  a0, fp, a0
    li a1, STACK_TMP_POLYVEC
    add  a1, fp, a1
    LOOPI K, 2
        jal x1, poly_reduce32_short_dilithium
        nop

    /* chknorm */
    li  t0, GAMMA2
    li  t1, BETA
    sub a1, t0, t1
    li  s0, STACK_TMP_POLYVEC /* reduce32(STACK_W0) */
    add s0, fp, s0

    /* Cannot use hardware loop due to branch to _rej_sign_dilithium */
    .rept K
        addi a0, s0, 0
        jal  x1, poly_chknorm_base_dilithium
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
        jal  x1, poly_pointwise_base_dilithium
        addi a0, a0, -1024

    /* Inverse NTT on h */
    li  a0, STACK_H
    add a0, fp, a0
    la  a1, twiddles_inv

    .irp reg,t0,t1,t2,t3,t4,t5,t6,a0,a1,a2,a3,a4,a5,a6,a7
        push \reg
    .endr

    LOOPI K, 3
        jal  x1, intt_base_dilithium
        addi a1, a1, -2048 /* Reset the twiddle pointer */
        addi a0, a0, 960 /* Go to next input poly, +64 already to a0 in intt */

    .irp reg,a7,a6,a5,a4,a3,a2,a1,a0,t6,t5,t4,t3,t2,t1,t0
        pop \reg
    .endr

    /* w0 = w0 + h */
    li  a0, STACK_W0
    add a0, fp, a0
    li  a1, STACK_H
    add a1, fp, a1
    li  a2, STACK_W0
    add a2, fp, a2

    LOOPI K, 2
        jal x1, poly_add_base_dilithium
        nop

    /* reduce32 h = c*t0 */
    li   a0, STACK_H
    add  a0, fp, a0
    li   a1, STACK_TMP_POLYVEC
    add  a1, fp, a1

    LOOPI K, 2
        jal x1, poly_reduce32_short_dilithium
        nop

    /* chknorm */
    li  a1, GAMMA2
    li  s0, STACK_TMP_POLYVEC /* reduce32(STACK_H) */
    add s0, fp, s0

    /* Cannot use hardware loop due to branch to _rej_sign_dilithium */
    .rept K
        addi a0, s0, 0
        jal  x1, poly_chknorm_base_dilithium
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
    
    /* DEBUG */
    li t0, 0
    bn.movr t0, t0

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
        jal x1, polyz_pack_base_dilithium
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