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
 * Masked ML-DSA keygen test wrapper. Links the shared mldsa_dmem layout, sets
 * up the runtime broadcast constants, and runs the hardened keygen kernel;
 * zeta_shares is preloaded by the testcase. K and s1/s2 come out as random
 * boolean shares, so this XORs them back for the testcase to check.
 */

.section .text.start

#if DILITHIUM_MODE == 2
  #define CRYPTO_PUBLICKEYBYTES 1312
  #define MLDSA_K 4
  #define MLDSA_L 4
  #define GAMMA1_MINUS_BETA 130994
  #define GAMMA2 95232
  #define GAMMA2_MINUS_BETA 95154
  #define NUM_ETA_POLYS 8
  #define POLYETA_PACKEDBYTES 96
  #define POLYETA_WDRS 3
#elif DILITHIUM_MODE == 3
  #define CRYPTO_PUBLICKEYBYTES 1952
  #define MLDSA_K 6
  #define MLDSA_L 5
  #define GAMMA1_MINUS_BETA 524092
  #define GAMMA2 261888
  #define GAMMA2_MINUS_BETA 261692
  #define NUM_ETA_POLYS 11
  #define POLYETA_PACKEDBYTES 128
  #define POLYETA_WDRS 4
#elif DILITHIUM_MODE == 5
  #define CRYPTO_PUBLICKEYBYTES 2592
  #define MLDSA_K 8
  #define MLDSA_L 7
  #define GAMMA1_MINUS_BETA 524168
  #define GAMMA2 261888
  #define GAMMA2_MINUS_BETA 261768
  #define NUM_ETA_POLYS 15
  #define POLYETA_PACKEDBYTES 96
  #define POLYETA_WDRS 3
#endif

.globl main
main:
  bn.xor  w31, w31, w31

  /* MOD = R | Q. */
  li      x5, 2
  la      x6, modulus
  bn.lid  x5, 0(x6)
  li      x5, 3
  la      x6, montg_R
  bn.lid  x5, 0(x6)
  bn.rshi w2, w3, w2 >> 224
  bn.wsrw 0x0, w2

  /* Populate the runtime parameter fields keygen + _setup_masked_vectors read. */
  la x5, mldsa_params
  li x6, MLDSA_K
  sw x6, 0(x5)
  li x6, MLDSA_L
  sw x6, 4(x5)
  li x6, GAMMA1_MINUS_BETA
  sw x6, 16(x5)
  li x6, CRYPTO_PUBLICKEYBYTES
  sw x6, 24(x5)
  li x6, GAMMA2
  sw x6, 28(x5)
  li x6, GAMMA2_MINUS_BETA
  sw x6, 32(x5)

  jal x1, _setup_masked_vectors
  jal x1, crypto_sign_keypair

  /* Unmask K = K_shares[0] ^ K_shares[1]. */
  li     x4, 1
  la     x5, K_shares
  la     x6, K_unmasked
  bn.lid x0, 0(x5)
  bn.lid x4, 32(x5)
  bn.xor w0, w0, w1
  bn.sid x0, 0(x6)

  /* Unmask s1/s2 shares, compacting in place. */
  la   x28, s1s2_shares
  la   x29, s1s2_shares
  li   x30, NUM_ETA_POLYS
expsk_unmask_loop:
  addi x5, x28, 0
  addi x6, x28, POLYETA_PACKEDBYTES
  loopi POLYETA_WDRS, 4
    bn.lid x0, 0(x5++)
    bn.lid x4, 0(x6++)
    bn.xor w0, w0, w1
    bn.sid x0, 0(x29++)
  endloop
  addi x28, x28, POLYETA_PACKEDBYTES
  addi x28, x28, POLYETA_PACKEDBYTES
  addi x30, x30, -1
  bne  x30, x0, expsk_unmask_loop

  ecall

/* pk/sk/s1s2_shares/K_shares live in the shared mldsa_dmem layout. */
.bss
.balign 32
.globl K_unmasked
K_unmasked:
  .zero 32
