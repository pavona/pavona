/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * Standalone test for secp256k1 point addition in projective space
 *
 * Computes G + G (the doubling corner case of the complete formulas) and
 * G + 2G using the complete projective addition routine. All input points
 * use z = 1. The exact projective result coordinates are checked.
 */

.section .text.start
start:
  /* init all-zero reg */
  bn.xor   w31, w31, w31

  /* Set up the modulus and the folding constant r256.
       MOD <= w29 <= p; w28 <= r256 */
  jal      x1, setup_modp

  /* load P = G into w8..w10 (projective, z = 1) */
  li       x2, 8
  la       x3, secp256k1_gx
  bn.lid   x2++, 0(x3)
  la       x3, secp256k1_gy
  bn.lid   x2, 0(x3)
  bn.addi  w10, w31, 1

  /* load Q = G into w11..w13 (projective, z = 1) */
  li       x2, 11
  la       x3, secp256k1_gx
  bn.lid   x2++, 0(x3)
  la       x3, secp256k1_gy
  bn.lid   x2, 0(x3)
  bn.addi  w13, w31, 1

  /* (w11,w12,w13) <= G + G (P = Q exercises completeness) */
  jal      x1, proj_add

  /* save result to w0..w2 */
  bn.mov   w0, w11
  bn.mov   w1, w12
  bn.mov   w2, w13

  /* load Q = 2G into w11..w13 (projective, z = 1); P = G is still intact
     in w8..w10 since proj_add only clobbers w11 to w25 */
  li       x2, 11
  la       x3, p2_x
  bn.lid   x2++, 0(x3)
  la       x3, p2_y
  bn.lid   x2, 0(x3)
  bn.addi  w13, w31, 1

  /* (w11,w12,w13) <= G + 2G */
  jal      x1, proj_add

  ecall

.data

/* point 2 x-coordinate (2G affine) */
.balign 32
p2_x:
  .word 0x5c709ee5
  .word 0xabac09b9
  .word 0x8cef3ca7
  .word 0x5c778e4b
  .word 0x95c07cd8
  .word 0x3045406e
  .word 0x41ed7d6d
  .word 0xc6047f94

/* point 2 y-coordinate (2G affine) */
.balign 32
p2_y:
  .word 0x50cfe52a
  .word 0x236431a9
  .word 0x3266d0e1
  .word 0xf7f63265
  .word 0x466ceaee
  .word 0xa3c58419
  .word 0xa63dc339
  .word 0x1ae168fe
