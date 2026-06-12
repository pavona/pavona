/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.globl secp256k1_isoncurve_proj

/**
 * Checks if a projective point is a valid curve point on curve secp256k1
 *
 * Returns rhs = x^3 + b*z^3  mod p
 *     and lhs = z*y^2  mod p
 *         with x,y,z being the projective coordinates of the curve point
 *              b and p being the domain parameters of secp256k1
 *
 * This routine checks if a point with given projective x-, y- and
 * z-coordinate is a valid curve point on secp256k1.
 * The routine checks whether the coordinates are a solution of the modified
 * Weierstrass equation zy^2 = x^3 + axz^2 + bz^3  mod p.
 * The routine makes use of the property that the domain parameter 'a' is zero
 * for the secp256k1 curve (so the axz^2 term vanishes) and computes b*z^3 for
 * b = 7 with a constant time addition chain, hence the routine is limited to
 * secp256k1.
 * The routine does not return a boolean result but computes the left side
 * and the right sight of the Weierstrass equation and leaves the final
 * comparison to the caller.
 * The routine runs in constant time.
 *
 * Flags: Flags have no meaning beyond the scope of this subroutine.
 *
 * @param[in]      w31: all-zero
 * @param[in]  dmem[x]: projective x-coordinate of input point
 * @param[in]  dmem[y]: projective y-coordinate of input point
 * @param[in]  dmem[z]: projective z-coordinate of input point
 * @param[out]     w18: lhs, left side of equation = (x^3 + b*z^3) mod p
 * @param[out]     w19: rhs, right side of equation = z*y^2 mod p
 *
 * clobbered registers: x2, x3, w18 to w27
 * clobbered flag groups: FG0
 */
secp256k1_isoncurve_proj:
  /* Set up for coordinate arithmetic.
       MOD <= p
       w28 <= r256
       w29 <= p */
  jal       x1, setup_modp

  /* load projective z-coordinate of curve point from dmem
     w26 <= dmem[z] */
  la        x3, z
  li        x2, 26
  bn.lid    x2, 0(x3)

  /* w19 <= z^2 = w26*w26 */
  bn.mov    w25, w26
  bn.mov    w24, w26
  jal       x1, mul_modp

  /* w19 <= z^3 = z^2 * z = w19*w26 */
  bn.mov    w25, w19
  bn.mov    w24, w26
  jal       x1, mul_modp

  /* w27 <= b*z^3 = 7*w19
     (constant time addition chain 2,4,6,7) */
  bn.addm   w27, w19, w19
  bn.addm   w24, w27, w27
  bn.addm   w27, w24, w27
  bn.addm   w27, w27, w19

  /* load projective x-coordinate of curve point from dmem
     w26 <= dmem[x] */
  la        x3, x
  li        x2, 26
  bn.lid    x2, 0(x3)

  /* w19 <= x^2 = w26*w26 */
  bn.mov    w25, w26
  bn.mov    w24, w26
  jal       x1, mul_modp

  /* w19 = x^3 <= x^2 * x = w25*w24 = w26*w19 */
  bn.mov    w25, w19
  bn.mov    w24, w26
  jal       x1, mul_modp

  /* for curve secp256k1, 'a' is zero, therefore the axz^2 term is omitted.
     w18 <= x^3 + b*z^3 mod p = w19 + w27 mod p = lhs */
  bn.addm   w18, w19, w27

  /* Load projective y-coordinate of curve point from dmem
     w24 <= dmem[y] */
  la        x3, y
  li        x2, 24
  bn.lid    x2, 0(x3)

  /* w19 <= w24*w24 mod p = y^2 mod p */
  bn.mov    w25, w24
  jal       x1, mul_modp

  /* load projective z-coordinate of curve point from dmem
     w24 <= dmem[z] */
  la        x3, z
  li        x2, 24
  bn.lid    x2, 0(x3)

  /* w19 <= w24*w19 mod p = z*y^2 mod p = rhs */
  bn.mov    w25, w19
  jal       x1, mul_modp

  ret
