/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * Standalone test for secp256k1 point doubling in projective space
 *
 * Doubles the base point (z = 1) and then the point at infinity (0, 1, 0);
 * the latter must map to a representation of the point at infinity again
 * (the formulas are exception-free).
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

  /* (w8,w9,w10) <= 2*G */
  jal      x1, proj_double

  /* save result to w0..w2 */
  bn.mov   w0, w8
  bn.mov   w1, w9
  bn.mov   w2, w10

  /* load the point at infinity (0, 1, 0) into w8..w10 */
  bn.mov   w8, w31
  bn.addi  w9, w31, 1
  bn.mov   w10, w31

  /* (w8,w9,w10) <= 2*infinity = infinity */
  jal      x1, proj_double

  ecall
