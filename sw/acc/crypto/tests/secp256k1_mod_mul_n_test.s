/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * Standalone test for Barrett multiplication modulo the secp256k1 group
 * order n.
 *
 * The first case is an adversarial product for which the Barrett quotient
 * estimate is two too small and the pre-correction remainder exceeds 2^257.
 * It fails if secp256k1_reduce is replaced with a P-256 style single
 * conditional subtraction (see the block comment on secp256k1_reduce).
 */

.section .text.start
start:
  /* Initialize all-zero register. */
  bn.xor    w31, w31, w31

  /* Set up modulus n (curve order) and the Barrett constant.
       MOD <= w29 <= n = dmem[secp256k1_n]
       w28 <= u_n = dmem[secp256k1_u_n] */
  li        x2, 29
  la        x3, secp256k1_n
  bn.lid    x2, 0(x3)
  bn.wsrw   MOD, w29
  li        x2, 28
  la        x3, secp256k1_u_n
  bn.lid    x2, 0(x3)

  /* case 0: adversarial input for which the quotient estimate is off by two
     and the remainder exceeds 2^257 (regression test for the two
     full-width conditional subtractions in secp256k1_reduce; a
     P-256 style single-subtraction correction computes a wrong
     result for this case)
       w0 <= (a0 * b0) mod n */
  li        x2, 24
  la        x3, nvalue_a0
  bn.lid    x2++, 0(x3)
  la        x3, nvalue_b0
  bn.lid    x2, 0(x3)
  jal       x1, mod_mul_256x256
  bn.mov    w0, w19

  /* case 1: n minus 1 squared
       w1 <= (a1 * b1) mod n */
  li        x2, 24
  la        x3, nvalue_a1
  bn.lid    x2++, 0(x3)
  la        x3, nvalue_b1
  bn.lid    x2, 0(x3)
  jal       x1, mod_mul_256x256
  bn.mov    w1, w19

  /* case 2: all-ones times n minus 1 (msg-like unreduced operand)
       w2 <= (a2 * b2) mod n */
  li        x2, 24
  la        x3, nvalue_a2
  bn.lid    x2++, 0(x3)
  la        x3, nvalue_b2
  bn.lid    x2, 0(x3)
  jal       x1, mod_mul_256x256
  bn.mov    w2, w19

  /* case 3: generic operands
       w3 <= (a3 * b3) mod n */
  li        x2, 24
  la        x3, nvalue_a3
  bn.lid    x2++, 0(x3)
  la        x3, nvalue_b3
  bn.lid    x2, 0(x3)
  jal       x1, mod_mul_256x256
  bn.mov    w3, w19

  ecall

.data

/* operand a0 = 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffef1 */
.balign 32
nvalue_a0:
  .word 0xfffffef1
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff

/* operand b0 = 0xd1b6b65fe99ee518afef68839494be4d3cb6355b28ea4a3ee51898271e7986c5 */
.balign 32
nvalue_b0:
  .word 0x1e7986c5
  .word 0xe5189827
  .word 0x28ea4a3e
  .word 0x3cb6355b
  .word 0x9494be4d
  .word 0xafef6883
  .word 0xe99ee518
  .word 0xd1b6b65f

/* operand a1 = 0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364140 */
.balign 32
nvalue_a1:
  .word 0xd0364140
  .word 0xbfd25e8c
  .word 0xaf48a03b
  .word 0xbaaedce6
  .word 0xfffffffe
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff

/* operand b1 = 0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364140 */
.balign 32
nvalue_b1:
  .word 0xd0364140
  .word 0xbfd25e8c
  .word 0xaf48a03b
  .word 0xbaaedce6
  .word 0xfffffffe
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff

/* operand a2 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff */
.balign 32
nvalue_a2:
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff

/* operand b2 = 0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364140 */
.balign 32
nvalue_b2:
  .word 0xd0364140
  .word 0xbfd25e8c
  .word 0xaf48a03b
  .word 0xbaaedce6
  .word 0xfffffffe
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff

/* operand a3 = 0xa8da539ffce03337030a5a44bcd3266608a32b364bb3295cace17a9da3175abc */
.balign 32
nvalue_a3:
  .word 0xa3175abc
  .word 0xace17a9d
  .word 0x4bb3295c
  .word 0x08a32b36
  .word 0xbcd32666
  .word 0x030a5a44
  .word 0xfce03337
  .word 0xa8da539f

/* operand b3 = 0x72c7c6bec94cf13ab2a1c47c60cb522e04a0e4330df8714c96a2db313c873171 */
.balign 32
nvalue_b3:
  .word 0x3c873171
  .word 0x96a2db31
  .word 0x0df8714c
  .word 0x04a0e433
  .word 0x60cb522e
  .word 0xb2a1c47c
  .word 0xc94cf13a
  .word 0x72c7c6be
