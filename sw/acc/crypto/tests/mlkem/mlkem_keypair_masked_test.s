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

.globl main
main:
  bn.xor w31, w31, w31

  la x2, stack_end

  /* mod = mqinv | q. */
  li      x4, 16
  la      x5, const_q
  bn.lid  x4++, 0(x5)
  bn.rshi w16, w31, w16 >> 240
  la      x5, const_mqinv
  bn.lid  x4, 0(x5)
  bn.or   w16, w16, w17 << 32
  bn.wsrw mod, w16

  la   x10, coins
  la   x11, ek
  la   x12, dk
  li   x13, KYBER_K
  jal  x1, crypto_kem_keypair

  /* Unpack the masked dk secret polys into keygen-dead scratch. */
  la x10, dk
  la x11, mpolyvec_sk
  loopi KYBER_K, 4
    loopi NSHARES, 2
      jal x1, poly_frombytes
      nop
    nop
  addi x8, x10, 0 /* Start of ek in the masked dk. */

  /* Unmask dk: sum the arithmetic shares mod q. */
  la   x5, mpolyvec_sk
  la   x6, mpolyvec_sk
  li   x4, 1
  li   x7, NSHARES
  slli x28, x7, 9 /* NSHARES * 512 */
  addi x7, x7, -1
  loopi KYBER_K, 10
    addi x29, x5, 0
    loopi 16, 7
      addi   x30, x5, 512
      bn.lid x0, 0(x5++)
      loop x7, 3
        bn.lid       x4, 0(x30)
        bn.addvm.16h w0, w0, w1
        addi         x30, x30, 512
      bn.sid x0, 0(x6++)
    add x5, x29, x28

  /* Repack the plain dk in place (poly_frombytes read all shares first). */
  la  x10, mpolyvec_sk
  la  x11, dk
  loopi KYBER_K, 2
    jal x1, poly_tobytes
    nop
  addi x9, x11, 0

  /* Move ek (and H(ek) || z shares) down to the plain dk offset. src > dst,
   * copied forward, so there is no overwrite hazard. */
  li   x5, CRYPTO_PUBLICKEYBYTES
  srli x5, x5, 5
  addi x5, x5, 3
  loop x5, 2
    bn.lid x0, 0(x8++)
    bn.sid x0, 0(x9++)

  ecall
