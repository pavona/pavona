/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * Standalone test for the secp256k1 projective curve point test
 *
 * Computes both sides of the projective Weierstrass equation for the base
 * point scaled by a non-trivial z; both sides must be equal.
 */

.section .text.start
start:
  /* init all-zero reg */
  bn.xor   w31, w31, w31

  /* Compute both sides of the projective Weierstrass equation.
       w18 <= lhs = (x^3 + b*z^3) mod p
       w19 <= rhs = (z*y^2) mod p */
  jal      x1, secp256k1_isoncurve_proj

  ecall

.data

/* projective x-coordinate of the test point (G scaled by z) */
.globl x
.balign 32
x:
  .word 0xbc22207b
  .word 0x1ec9e5af
  .word 0x8334722f
  .word 0xdda1a9df
  .word 0x34030638
  .word 0xc08fb8ea
  .word 0xade2a2a7
  .word 0xb7e7ae2d

/* projective y-coordinate of the test point (G scaled by z) */
.globl y
.balign 32
y:
  .word 0xef3f0fc0
  .word 0xa951ecce
  .word 0x3e6f35db
  .word 0x604a5384
  .word 0x77921040
  .word 0x34df31bb
  .word 0x896d7012
  .word 0xdc072fba

/* projective z-coordinate of the test point */
.globl z
.balign 32
z:
  .word 0x00000001
  .word 0xdeadbeef
  .word 0xdeadbeef
  .word 0xdeadbeef
  .word 0xdeadbeef
  .word 0xdeadbeef
  .word 0xdeadbeef
  .word 0x00000000
