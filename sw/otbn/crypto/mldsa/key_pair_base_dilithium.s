/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors */
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
      /* Write to the KECCAK_MSG wide special register (index 8).
         KECCAK_MSG <= w0 */
      bn.wsrw 0x9, w0

_no_full_wdr:
  /* Compute the remaining message length.
       t0 <= x10 & 31 = len mod 32 */
  andi t0, x11, 31

  /* If the remaining length is zero, return early. */
  beq t0, x0, _keccak_send_message_end

  bn.lid  x0, 0(x10)
  bn.wsrw 0x9, w0

  _keccak_send_message_end:
  ret

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
.globl key_pair_base_dilithium
key_pair_base_dilithium:
    /* Stack address mapping */
    #define STACK_SEEDBUF -160
        #define STACK_RHO -160
        #define STACK_RHOPRIME -128
        #define STACK_KEY -64
    #define STACK_PK_ADDR -164
    #define STACK_SK_ADDR -168
    #define STACK_TR      -256
#if DILITHIUM_MODE == 2
    #define STACK_MAT -16640 /* Prev - K*L*1024 */
    #define STACK_S1  -20736 /* Prev - L*1024 */
    #define STACK_S2  -24832 /* Prev - K*1024 */
    #define STACK_T1  -28928 /* Prev - K*1024 */
    #define STACK_T0  -33024 /* Prev - K*1024 */
    #define STACK_S1_HAT  -37120 /* Prev - L*1024 */
    #define SHAKE_CONTEXT -37120 /* Prev - 256 */
#elif DILITHIUM_MODE == 3
    #define STACK_MAT -30976 /* Prev - K*L*1024 */
    #define STACK_S1  -36096 /* Prev - L*1024 */
    #define STACK_S2  -42240 /* Prev - K*1024 */
    #define STACK_T1  -48384 /* Prev - K*1024 */
    #define STACK_T0  -54528 /* Prev - K*1024 */
    #define STACK_S1_HAT  -59648 /* Prev - L*1024 */
    #define SHAKE_CONTEXT -59648 /* Prev - 256 */
#elif DILITHIUM_MODE == 5
    #define STACK_MAT -57600 /* Prev - K*L*1024 */
    #define STACK_S1  -64768 /* Prev - L*1024 */
    #define STACK_S2  -72960 /* Prev - K*1024 */
    #define STACK_T1  -81152 /* Prev - K*1024 */
    #define STACK_T0  -89344 /* Prev - K*1024 */
    #define STACK_S1_HAT  -96512 /* Prev - L*1024 */
    #define SHAKE_CONTEXT -96512 /* Prev - 256 */
#endif
    /* Initialize the frame pointer */
    addi fp, sp, 0

    /* Reserve space on the stack */
#if DILITHIUM_MODE == 2
    li  t0, -37120
#elif DILITHIUM_MODE == 3
    li  t0, -59648
#elif DILITHIUM_MODE == 5
    li  t0, -96512
#endif
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
            jal  x1, poly_uniform_base_dilithium
            pop  a2
            addi a2, a2, 1
        addi a2, a2, 256
        addi a2, a2, -L

    /* Sample s1 */

    li a2, 0 /* initialize the nonce */

    /* Load output pointer */
    li  a1, STACK_S1
    add a1, fp, a1

    LOOPI L, 3
        /* Load pointer to input */
        addi a0, fp, STACK_RHOPRIME
        jal  x1, poly_uniform_eta_base_dilithium
        addi a2, a2, 1
    
    /* Sample s2 */

    /* initialize the nonce */
    li a2, L

    /* Load output pointer */
    li  a1, STACK_S2
    add a1, fp, a1

    LOOPI K, 3
        /* Load pointer to input */
        addi a0, fp, STACK_RHOPRIME
        jal  x1, poly_uniform_eta_base_dilithium /* Implicit increment of output pointer */
        addi a2, a2, 1
    
    /* NTT(s1) */
    /* Load pointer to input polynomial */
    li  a0, STACK_S1
    add a0, fp, a0
    /* Load pointer to twiddle factors */
    la  a1, twiddles_fwd
    /* Load pointer to output polynomial */
    li  a2, STACK_S1_HAT
    add a2, fp, a2

    .irp reg,t0,t1,t2,t3,t4,t5,t6,a0,a1,a2,a3,a4,a5,a6,a7
        push \reg
    .endr

    LOOPI L, 4
        jal x1, ntt_base_dilithium
        addi a0, a0, 1024
        addi a1, a1, -1152
        addi a1, a1, -1024

    .irp reg,a7,a6,a5,a4,a3,a2,a1,a0,t6,t5,t4,t3,t2,t1,t0
        pop \reg
    .endr

    /* Matrix-vector multiplication */

    /* Load source pointers */
    li  a0, STACK_S1_HAT
    add a0, fp, a0
    li  a1, STACK_MAT
    add a1, fp, a1

    /* Load destination pointer */
    li  a2, STACK_T1
    add a2, fp, a2

    /* Load offset for resetting pointer */
    li s1, POLYVECL_BYTES

    .rept K
        jal  x1, poly_pointwise_base_dilithium
        addi a2, a2, -1024

        .rept L-1
            jal  x1, poly_pointwise_acc_base_dilithium
            addi a2, a2, -1024
        .endr
        sub  a0, a0, s1   /* Reset input vector pointer */
        addi a2, a2, 1024 /* Write next output polynomial */
    .endr

    /* reduce32 t1 */
    li   a0, STACK_T1
    add  a0, fp, a0
    addi a1, a0, 0

    LOOPI K, 2
        jal x1, poly_reduce32_pos_dilithium
        nop

    /* Inverse NTT on t1 */
    li  a0, STACK_T1
    add a0, fp, a0
    la  a1, twiddles_inv

    .irp reg,t0,t1,t2,t3,t4,t5,t6,a0,a1,a2,a3,a4,a5,a6,a7
        push \reg
    .endr

    LOOPI K, 3
        jal  x1, intt_base_dilithium
        addi a1, a1, -2048 /* Reset the twiddle pointer */
        addi a0, a0, 960 /* Go to next input poly, +64 already to a0 in intt */

    /* Restore caller-saved registers */
    .irp reg,a7,a6,a5,a4,a3,a2,a1,a0,t6,t5,t4,t3,t2,t1,t0
        pop \reg
    .endr

    /* t1+s2 */

    /* Load source pointers */
    li  a0, STACK_S2
    add a0, fp, a0
    li  a1, STACK_T1
    add a1, fp, a1

    /* Load destination pointer */
    li  a2, STACK_T1
    add a2, fp, a2

    LOOPI K, 2
        jal x1, poly_add_base_dilithium
        nop

    /* power2round */

    /* Load source pointer */
    li  a0, STACK_T1
    add a0, fp, a0

    /* Load destination pointer */
    li  a1, STACK_T0
    add a1, fp, a1
    li  a2, STACK_T1
    add a2, fp, a2

    LOOPI K, 2
        jal x1, poly_power2round_base_dilithium
        nop

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
    li  a1, STACK_T1
    add a1, fp, a1

    /* Pack t1 */
    LOOPI K, 2
        jal x1, polyt1_pack_dilithium
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

    /* Load pointer to s1 */
    li  a1, STACK_S1
    add a1, fp, a1

    /* Store s1 */
    LOOPI L, 2
        jal x1, polyeta_pack_dilithium
        nop

    /* Load pointer to s2 */
    li  a1, STACK_S2
    add a1, fp, a1

    /* Store packed(s2) */
    LOOPI K, 2
        jal x1, polyeta_pack_dilithium
        nop

    /* Load pointer to t0 */
    li  a1, STACK_T0
    add a1, fp, a1

    /* Store packed(t0) */
    LOOPI K, 2
        jal x1, polyt0_pack_base_dilithium
        nop

    /* Free space on the stack */
    addi sp, fp, 0
    ret
