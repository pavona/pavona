/* Copyright zeroRISC Inc. */
/* Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192). */
/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors. */
/* Modified by Ruben Niederhagen and Hoang Nguyen Hien Pham - authors of */
/* "Improving ML-KEM & ML-DSA on OpenTitan - Efficient Multiplication Vector Instructions for OTBN" */
/* (https://eprint.iacr.org/2025/2028). */
/* Copyright Ruben Niederhagen and Hoang Nguyen Hien Pham. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */


/*
 * Testwrapper for mlkem_keypair
*/

.section .text.start

#ifndef NSHARES
    #define NSHARES 2
#endif
#ifndef KYBER_K
    #define KYBER_K 3
#endif
#define STACK_SIZE 9216

#if KYBER_K == 2
  #define CRYPTO_PUBLICKEYBYTES  800
  #define CRYPTO_SECRETKEYBYTES  1632
  #define CRYPTO_CIPHERTEXTBYTES 768
#elif KYBER_K == 3
  #define CRYPTO_PUBLICKEYBYTES  1184
  #define CRYPTO_SECRETKEYBYTES  2400
  #define CRYPTO_CIPHERTEXTBYTES 1088
#elif KYBER_K == 4
  #define CRYPTO_PUBLICKEYBYTES  1568
  #define CRYPTO_SECRETKEYBYTES  3168
  #define CRYPTO_CIPHERTEXTBYTES 1568
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

.globl main
main:
    la sp, stack_end

    /* MOD <= dmem[modulus] = KYBER_Q */
    la      t0, modulus
    bn.lid  x0++, 0(t0)
    la      t0, modulus_inv
    addi    x4, x0, 1
    bn.lid  x4, 0(t0)
    bn.or   w0, w0, w1 << 32 /* MOD = R | Q */
    bn.wsrw mod, w0

    /* Load stack pointer */
    la   a0, coins
    la   a1, ek
#if NSHARES == 1
    la   a2, dk
#else
	la   a2, masked_packed_dk
#endif
    li   a3, KYBER_K
    jal  x1, crypto_kem_keypair
	bn.subi w0, w0, 10
#if NSHARES != 1
    la a0, masked_packed_dk
    la a1, masked_unpacked_dk
    loopi KYBER_K, 4
        loopi NSHARES, 2
            jal x1, poly_frombytes
            nop
        nop
    addi s0, a0, 0 /* Start of ek. */

    /* Unmask dk. */
    la   t0, masked_unpacked_dk
    la   t1, masked_unpacked_dk
    li   x4, 1
    li   t2, NSHARES
    slli t3, t2, 9 /* NSHARES * 512 */
    addi t2, t2, -1
    loopi KYBER_K, 10
        addi t4, t0, 0
        loopi 16, 7
            addi   t5, t0, 512
            bn.lid x0, 0(t0++)
            loop t2, 3
                bn.lid       x4, 0(t5)
                bn.addvm.16h w0, w0, w1
                addi         t5, t5, 512
            bn.sid x0, 0(t1++)
        add t0, t4, t3

    /* Pack unmasked dk. */
    la  a0, masked_unpacked_dk
    la  a1, dk
    loopi KYBER_K, 2
        jal x1, poly_tobytes
        nop
    addi s1, a1, 0

    /* Copy ek to dk. */
    li   t0, CRYPTO_PUBLICKEYBYTES
    srli t0, t0, 5
    addi t0, t0, 1
#if NSHARES == 2
    addi t0, t0, 2
#else
	addi t0, t0, 1
#endif
    loop t0, 2
        bn.lid x0, 0(s0++)
        bn.sid x0, 0(s1++)
#endif

    ecall

.data
.balign 32
stack:
    .zero STACK_SIZE
.globl stack_end
stack_end:

ek:
    .zero CRYPTO_PUBLICKEYBYTES
dk:
    .zero CRYPTO_SECRETKEYBYTES

#if NSHARES != 1
masked_packed_dk:
    .zero 384 * KYBER_K * NSHARES + CRYPTO_PUBLICKEYBYTES + 32 + 32 * NSHARES

masked_unpacked_dk:
    .zero 512 * KYBER_K * NSHARES
#endif
