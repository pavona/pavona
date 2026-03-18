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
 * Testwrapper for mlkem_decap
*/

.section .text.start

#define STACK_SIZE 16000
#define CRYPTO_BYTES 32

#ifndef NSHARES
  #define NSHARES 2
#endif

#ifndef KYBER_K
  #define KYBER_K 3
#endif

.globl main
main:
    /* Init all-zero register. */
    bn.xor  w31, w31, w31

    /* MOD <= dmem[modulus] = KYBER_Q */
    li      x5, 2
    la      x6, modulus
    bn.lid  x5++, 0(x6)
    la      x6, modulus_inv
    bn.lid  x5, 0(x6)
    bn.or   w2, w2, w3 << 32 /* MOD = R | Q */
    bn.wsrw 0x0, w2

    /* Load stack pointer */
    la   x2, stack_end
    la   x10, ct
    la   x11, dk
    la   x12, ss
    li   x13, KYBER_K
    jal  x1, crypto_kem_dec

    #if NSHARES == 2
    /* Unmask shared key for testing. */
    la     x2, ss
    addi   x4, x0, 1
    bn.lid x0, 0(x2)
    bn.lid x4, 32(x2)
    bn.xor w0, w0, w1
    bn.sid x0, 0(x2)
    #endif

    ecall

.data
.balign 32
.global stack
stack:
  .zero STACK_SIZE
stack_end:

.globl ss
ss:
	#if NSHARES == 2
	.zero CRYPTO_BYTES * NSHARES
	#else
	.zero CRYPTO_BYTES
	#endif
