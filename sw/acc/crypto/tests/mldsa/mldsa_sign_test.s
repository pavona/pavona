/* Copyright zeroRISC Inc. */
/* Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192). */
/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors. */
/* Modified by Ruben Niederhagen and Hoang Nguyen Hien Pham - authors of */
/* "Improving ML-KEM & ML-DSA on OpenTitan - Efficient Multiplication Vector Instructions for OTBN" */
/* (https://eprint.iacr.org/2025/2028). */
/* Copyright Ruben Niederhagen and Hoang Nguyen Hien Pham. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */


/**
 * Test for crypto_sign_signature_internal
*/

.section .text.start

#if DILITHIUM_MODE == 2
#define K 4
#define L 4
#define TAU 39
#define OMEGA 80
#define GAMMA1_MINUS_BETA 130994
#define POLYW1_PACKEDBYTES 192
#define CRYPTO_PUBLICKEYBYTES 1312
#define GAMMA2 95232
#define GAMMA2_MINUS_BETA 95154
#define SK_S2_OFFSET 512
#define SK_T0_OFFSET 896
#define CRYPTO_BYTES 2420
#elif DILITHIUM_MODE == 3
#define K 6
#define L 5
#define TAU 49
#define OMEGA 55
#define GAMMA1_MINUS_BETA 524092
#define POLYW1_PACKEDBYTES 128
#define CRYPTO_PUBLICKEYBYTES 1952
#define GAMMA2 261888
#define GAMMA2_MINUS_BETA 261692
#define SK_S2_OFFSET 768
#define SK_T0_OFFSET 1536
#define CRYPTO_BYTES 3309
#elif DILITHIUM_MODE == 5
#define K 8
#define L 7
#define TAU 60
#define OMEGA 75
#define GAMMA1_MINUS_BETA 524168
#define POLYW1_PACKEDBYTES 128
#define CRYPTO_PUBLICKEYBYTES 2592
#define GAMMA2 261888
#define GAMMA2_MINUS_BETA 261768
#define SK_S2_OFFSET 800
#define SK_T0_OFFSET 1568
#define CRYPTO_BYTES 4627
#endif

#define POLYVECK_BYTES (K * 1024)

#define MLDSA_PARAM_K_OFFSET 0
#define MLDSA_PARAM_L_OFFSET 4
#define MLDSA_PARAM_TAU_OFFSET 8
#define MLDSA_PARAM_OMEGA_OFFSET 12
#define MLDSA_PARAM_GAMMA1_MINUS_BETA_OFFSET 16
#define MLDSA_PARAM_POLYW1_PACKEDBYTES_OFFSET 20
#define MLDSA_PARAM_CRYPTO_PUBLICKEYBYTES_OFFSET 24
#define MLDSA_PARAM_GAMMA2_OFFSET 28
#define MLDSA_PARAM_GAMMA2_MINUS_BETA_OFFSET 32
#define MLDSA_PARAM_SK_S2_OFFSET_OFFSET 36
#define MLDSA_PARAM_SK_T0_OFFSET_OFFSET 40
#define MLDSA_PARAM_CRYPTO_BYTES_OFFSET 44

/* Entry point. */
.globl main
main:
  /* Init all-zero register. */
#ifdef RTL_ISS_TEST
  xor  x2, x2, x2
  xor  x3, x3, x3
  xor  x4, x4, x4
  xor  x5, x5, x5
  xor  x6, x6, x6
  xor  x7, x7, x7
  xor  x8, x8, x8
  xor  x9, x9, x9
  xor  x10, x10, x10
  xor  x11, x11, x11
  xor  x12, x12, x12
  xor  x13, x13, x13
  xor  x14, x14, x14
  xor  x15, x15, x15
  xor  x16, x16, x16
  xor  x17, x17, x17
  xor  x18, x18, x18
  xor  x19, x19, x19
  xor  x20, x20, x20
  xor  x21, x21, x21
  xor  x22, x22, x22
  xor  x23, x23, x23
  xor  x24, x24, x24
  xor  x25, x25, x25
  xor  x26, x26, x26
  xor  x27, x27, x27
  xor  x28, x28, x28
  xor  x29, x29, x29
  xor  x30, x30, x30
  xor  x31, x31, x31

  bn.xor  w0, w0, w0
  bn.xor  w1, w1, w1
  bn.xor  w2, w2, w2
  bn.xor  w3, w3, w3
  bn.xor  w4, w4, w4
  bn.xor  w5, w5, w5
  bn.xor  w6, w6, w6
  bn.xor  w7, w7, w7
  bn.xor  w8, w8, w8
  bn.xor  w9, w9, w9
  bn.xor  w10, w10, w10
  bn.xor  w11, w11, w11
  bn.xor  w12, w12, w12
  bn.xor  w13, w13, w13
  bn.xor  w14, w14, w14
  bn.xor  w15, w15, w15
  bn.xor  w16, w16, w16
  bn.xor  w17, w17, w17
  bn.xor  w18, w18, w18
  bn.xor  w19, w19, w19
  bn.xor  w20, w20, w20
  bn.xor  w21, w21, w21
  bn.xor  w22, w22, w22
  bn.xor  w23, w23, w23
  bn.xor  w24, w24, w24
  bn.xor  w25, w25, w25
  bn.xor  w26, w26, w26
  bn.xor  w27, w27, w27
  bn.xor  w28, w28, w28
  bn.xor  w29, w29, w29
  bn.xor  w30, w30, w30
#endif
  bn.xor  w31, w31, w31

  /* MOD <= dmem[modulus] = DILITHIUM_Q */
  li      x5, 2
  la      x6, modulus
  bn.lid  x5, 0(x6)

  /* MOD 2nd word <= DILITHIUM_R */
  li      x5, 3
  la      x6, montg_R
  bn.lid  x5, 0(x6)
  bn.rshi w2, w3, w2 >> 224
  /* Write back MOD */
  bn.wsrw 0x0, w2

  /* Populate mldsa_params with the active mode's values. */
  la    x4, mldsa_params
  li    x5, K
  sw    x5, MLDSA_PARAM_K_OFFSET(x4)
  li    x5, L
  sw    x5, MLDSA_PARAM_L_OFFSET(x4)
  li    x5, TAU
  sw    x5, MLDSA_PARAM_TAU_OFFSET(x4)
  li    x5, OMEGA
  sw    x5, MLDSA_PARAM_OMEGA_OFFSET(x4)
  li    x5, GAMMA1_MINUS_BETA
  sw    x5, MLDSA_PARAM_GAMMA1_MINUS_BETA_OFFSET(x4)
  li    x5, POLYW1_PACKEDBYTES
  sw    x5, MLDSA_PARAM_POLYW1_PACKEDBYTES_OFFSET(x4)
  li    x5, CRYPTO_PUBLICKEYBYTES
  sw    x5, MLDSA_PARAM_CRYPTO_PUBLICKEYBYTES_OFFSET(x4)
  li    x5, GAMMA2
  sw    x5, MLDSA_PARAM_GAMMA2_OFFSET(x4)
  li    x5, GAMMA2_MINUS_BETA
  sw    x5, MLDSA_PARAM_GAMMA2_MINUS_BETA_OFFSET(x4)
  li    x5, SK_S2_OFFSET
  sw    x5, MLDSA_PARAM_SK_S2_OFFSET_OFFSET(x4)
  li    x5, SK_T0_OFFSET
  sw    x5, MLDSA_PARAM_SK_T0_OFFSET_OFFSET(x4)
  li    x5, CRYPTO_BYTES
  sw    x5, MLDSA_PARAM_CRYPTO_BYTES_OFFSET(x4)

  /* Load parameters */
  la x10, sig

  jal x1, crypto_sign_signature_internal

#if DILITHIUM_MODE == 3
  li   x10, CRYPTO_BYTES
  addi x10, x10, -1
  la   x11, sig
  add  x11, x11, x10
  lw   x10, 0(x11)
  slli x10, x10, 24
  srli x10, x10, 24
  sw   x10, 0(x11)
#endif

  ecall

.data

.balign 32
.globl sig
sig:
  .zero CRYPTO_BYTES
  .zero 32

.bss

.balign 4
.globl dptr_sig
dptr_sig:
  .zero 4

.balign 32
.globl rhoprime
rhoprime:
  .zero 64

.balign 32
.globl c_poly
c_poly:
.globl y_poly
y_poly:
  .zero 1024

.balign 32
.globl tmp_poly
tmp_poly:
  .zero 1024

.balign 32
.globl w1_repvec
w1_repvec:
  .zero 256

.balign 32
.globl w0_polyvec
w0_polyvec:
  .zero POLYVECK_BYTES
