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
 * decompose_dilithium
 *
 * For finite field element a, compute high and low bits a0, a1 such that a
 * mod^+ Q = a1*ALPHA + a0 with -ALPHA/2 < a0 <= ALPHA/2 except if a1 =
 * (Q-1)/ALPHA where we set a1 = 0 and -ALPHA/2 <= a0 = a mod^+ Q - Q < 0.
 * Assumes a to be standard representative.
 * 
 * Returns: output element vector "a0" in w1, output element vector "a1" in w2
 *
 * @param[in] w0: input element vector
 * @param[in] w5-w11: constants in the following order: decompose_127_const,
 * decompose_const, reduce32_const, decompose_43_const, gamma2_vec_const,
 * qm1half_const, modulus
 *
 * clobbered registers: w1-w4, t0, t3-t4
 */
.global decompose_dilithium
decompose_dilithium:
    /* "a", "a{0,1}" refer to the variable names from the reference code */ 

    /* Compute "a1" */
    bn.addv.8S w2, w0, w5         /* "a" + 127 */
    bn.shv.8S  w2, w2 >> 7   /* ("a" + 127) >> 7 */
#if GAMMA2 == (Q-1)/88
    bn.mulv.8S w2, w2, w6         /* "a1" * 11275 */
    bn.shv.8S  w4, w7 << 23  /* 1 << 23 */
    bn.addv.8S w2, w2, w4         /* ("a1" * 11275) + (1 << 23) */ 
    bn.shv.8S  w2, w2 >> 24  /* (("a1" * 11275) + (1 << 23)) >> 24 */ 
    bn.subv.8S w3, w8, w2         /* 43 - "a1" */
    bn.shv.8S w30, w3 >> 31
    bn.subv.8S w30, bn0, w30 /* Build mask from MSBs */
    bn.and w3, w2, w30           /* ((43 - "a1") >> 31) & "a1" */
    bn.xor w2, w2, w3            /* "a1" ^= ((43 - "a1") >> 31) & "a1" */
#elif GAMMA2 == (Q-1)/32
    bn.mulv.8S w2, w2, w6    /* "a1" * 1025 */
    bn.shv.8S  w4, w7 << 21  /* 1 << 21 */
    bn.addv.8S w2, w2, w4    /* ("a1" * 1025) + (1 << 21) */ 
    bn.shv.8S  w2, w2 >> 22  /* (("a1" * 1025) + (1 << 21)) >> 22 */ 
    bn.and     w2, w2, w8    /* & 15 */
#endif

    /* Compute "a0" */
    bn.mulv.8S w4, w9, w2          /* "a1" * GAMMA2 */
    bn.shv.8S  w4, w4 << 1    /* "a1" * GAMMA2 * 2 */
    bn.subv.8S w1, w0, w4          /* a - "a1" * GAMMA2 * 2 */
    bn.subv.8S w4, w10, w1         /* (Q-1)/2 - "a0" */
    bn.shv.8S  w30, w4 >> 31
    bn.subv.8S w30, bn0, w30 /* Build mask from MSBs */
    bn.and     w4, w11, w30        /* (((Q-1)/2 - "a0") >> 31) & Q */ 
    bn.subv.8S w1, w1, w4          /* a0 -= (((Q-1)/2 - "a0") >> 31) & Q */
    
    ret