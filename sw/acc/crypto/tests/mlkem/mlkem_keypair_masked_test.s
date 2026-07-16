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
 * Masked ML-KEM keygen test wrapper. Links the shared mlkem_dmem layout and
 * runs the hardened keygen kernel; coins is preloaded by the testcase. dk comes
 * out with the secret polynomials in two arithmetic shares, so this unpacks
 * (into the keygen-dead mpolyvec_sk scratch), adds the shares mod q, and repacks
 * the plain dk in place for the check.
 */

.section .text.start

#define NSHARES 2

#ifndef KYBER_K
  #define KYBER_K 3
#endif

#if KYBER_K == 2
  #define CRYPTO_PUBLICKEYBYTES 800
#elif KYBER_K == 3
  #define CRYPTO_PUBLICKEYBYTES 1184
#elif KYBER_K == 4
  #define CRYPTO_PUBLICKEYBYTES 1568
#endif

.equ x2, sp
.equ x5, t0
.equ x6, t1
.equ x7, t2
.equ x8, s0
.equ x9, s1
.equ x10, a0
.equ x11, a1
.equ x12, a2
.equ x13, a3
.equ x28, t3
.equ x29, t4
.equ x30, t5

.globl main
main:
    bn.xor w31, w31, w31

    la sp, stack_end

    /* MOD = R | Q. */
    la      t0, modulus
    bn.lid  x0++, 0(t0)
    la      t0, modulus_inv
    addi    x4, x0, 1
    bn.lid  x4, 0(t0)
    bn.or   w0, w0, w1 << 32
    bn.wsrw mod, w0

    la   a0, coins
    la   a1, ek
    la   a2, dk
    li   a3, KYBER_K
    jal  x1, crypto_kem_keypair

    /* Unpack the masked dk secret polys into keygen-dead scratch. */
    la a0, dk
    la a1, mpolyvec_sk
    loopi KYBER_K, 4
        loopi NSHARES, 2
            jal x1, poly_frombytes
            nop
        nop
    addi s0, a0, 0 /* Start of ek in the masked dk. */

    /* Unmask dk: sum the arithmetic shares mod q. */
    la   t0, mpolyvec_sk
    la   t1, mpolyvec_sk
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

    /* Repack the plain dk in place (poly_frombytes read all shares first). */
    la  a0, mpolyvec_sk
    la  a1, dk
    loopi KYBER_K, 2
        jal x1, poly_tobytes
        nop
    addi s1, a1, 0

    /* Move ek (and H(ek) || z shares) down to the plain dk offset. src > dst,
     * copied forward, so there is no overwrite hazard. */
    li   t0, CRYPTO_PUBLICKEYBYTES
    srli t0, t0, 5
    addi t0, t0, 3
    loop t0, 2
        bn.lid x0, 0(s0++)
        bn.sid x0, 0(s1++)

    ecall
