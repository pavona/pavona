/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.section .text.start

#if DILITHIUM_MODE == 2
#define CRYPTO_BYTES 2420
#elif DILITHIUM_MODE == 3
#define CRYPTO_BYTES 3309
#elif DILITHIUM_MODE == 5
#define CRYPTO_BYTES 4627
#endif

.globl main
main:
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

  li      x5, 2
  la      x6, modulus
  bn.lid  x5, 0(x6)

  li      x5, 3
  la      x6, montg_R
  bn.lid  x5, 0(x6)
  bn.rshi w2, w3, w2 >> 224
  bn.wsrw 0x0, w2

  /* External-mu mode: testgen supplies dmem[mu]; signer skips the
   * initial SHAKE over tr||ctxlen||ctx||msg. */
  la x10, sig
  li x13, NSHARES

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
/* sig doubles as P1 scratch past CRYPTO_BYTES; size for the worst case. */
#if DILITHIUM_MODE == 3
  .zero 16                /* sig at 16 mod 32 so z (sig+48) is 32-aligned */
#endif
sig:
  .zero 4640
