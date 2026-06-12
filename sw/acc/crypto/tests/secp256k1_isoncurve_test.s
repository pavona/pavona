/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * Standalone test for the secp256k1 curve point test
 *
 * Computes both sides of the Weierstrass equation for the base point;
 * both sides must be equal.
 */

.section .text.start
start:
  /* init all-zero reg */
  bn.xor   w31, w31, w31

  /* Compute both sides of the Weierstrass equation.
       w18 <= lhs = (x^3 + b) mod p
       w19 <= rhs = (y^2) mod p */
  jal      x1, secp256k1_isoncurve

  ecall

.data

/* affine x-coordinate of the test point (basepoint G) */
.globl x
.balign 32
x:
  .word 0x16f81798
  .word 0x59f2815b
  .word 0x2dce28d9
  .word 0x029bfcdb
  .word 0xce870b07
  .word 0x55a06295
  .word 0xf9dcbbac
  .word 0x79be667e

/* affine y-coordinate of the test point (basepoint G) */
.globl y
.balign 32
y:
  .word 0xfb10d4b8
  .word 0x9c47d08f
  .word 0xa6855419
  .word 0xfd17b448
  .word 0x0e1108a8
  .word 0x5da4fbfc
  .word 0x26a3c465
  .word 0x483ada77
