/* Copyright lowRISC contributors (OpenTitan project). */
/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/* Copyright 2016 The Chromium OS Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE.dcrypto file.
 *
 * Derived from the P-256 implementation in p256_base.s, which in turn is
 * derived from code in
 * https://chromium.googlesource.com/chromiumos/platform/ec/+/refs/heads/cr50_stab/chip/g/dcrypto/dcrypto_p256.c
 */

.globl secp256k1_base_mult
.globl secp256k1_generate_k
.globl secp256k1_generate_random_key
.globl secp256k1_key_from_seed
.globl secp256k1_scalar_remask
.globl mul_modp
.globl setup_modp
.globl mod_mul_256x256
.globl mod_mul_320x128
.globl scalar_mult_int
.globl proj_add
.globl proj_to_affine

/* Exposed only for testing or SCA purposes. */
.globl mod_inv
.globl proj_double

.text

/**
 * Reduce a 512-bit value by a 256-bit secp256k1 modulus (either n or p).
 *
 * Returns c = x mod m
 *
 * Expects a 512 bit input, a 256 bit modulus and pre-computed parameter u for
 * Barrett reduction (usually greek mu in literature). u is expected without
 * the leading 1 at bit 256. u has to be pre-computed as
 * u = floor(2^512/m) - 2^256. Since 2^255 < m < 2^256, u fits in 256 bits.
 *
 * The quotient estimation mostly follows the description in the "Handbook of
 * Applied Cryptography" Algorithm 14.42 and is identical to the P-256
 * implementation (see p256_reduce for details):
 *   - The computation of q2 ignores the MSbs of q1 and u to allow using
 *     a 256x256 bit multiplication. This is compensated later by
 *     individual (conditional) additions.
 *   - The truncations in step 2 of HAC 14.42 in the form of (... mod b^(k+1) )
 *     are not implemented here and the full register width is used. This
 *     allows to omit computation of r1 (since r1=x) and step 3 of HAC 14.42
 *
 * IMPORTANT: the final correction step differs from p256_reduce. For the
 * P-256 moduli it can be shown that the quotient estimate q3 satisfies
 * q3 >= floor(x/m) - 1, so that a single conditional subtraction of the
 * modulus suffices. This is NOT true for the secp256k1 group order n: since
 * (2^512 mod n) =~ 0.615 * 2^256 (vs. =~ 0.402 * 2^256 for the P-256 order),
 * there are inputs x < 2^256 * n with q3 = floor(x/n) - 2, leaving remainders
 * of up to r =~ 2.115 * n, which can even exceed 2^257 (breaking the P-256
 * style bit-256 check). This routine therefore performs two full-width
 * conditional subtractions of the modulus instead. The remainder before
 * correction provably satisfies r < 3*m for ANY modulus 2^255 < m < 2^256:
 * with x = q1*2^255 + x0 (x0 < 2^255), v = 2^512 mod m (v < m), and
 * s = q1*mu mod 2^257, the remainder is exactly
 *   r = x0 + (q1*v + m*s) / 2^257
 * and with q1 < 2m this is bounded by r < 2^255 + m^2/2^256 + m < 3m.
 * Two conditional subtractions thus always yield the fully reduced result.
 *
 * Flags: Flags have no meaning beyond the scope of this subroutine.
 *
 * @param[in]  [w19,w20]: x, input (512 bits) such that x < 2^256 * m
 * @param[in]  w22: correction factor, msb(x) * u
 * @param[in]  w29: m, modulus, curve order n or finite field modulus p
 * @param[in]  w28: u, lower 256 bit of Barrett constant for m
 * @param[in]  w31: all-zero
 * @param[in]  MOD: m, modulus
 * @param[out]  w19: c, result
 *
 * clobbered registers: w19, w20, w21, w22, w23, w24, w25
 * clobbered flag groups: FG0
 */
secp256k1_reduce:
  /* Compute q1' = q1[255:0] = x >> 255
     w21 = q1' = [w20, w19] >> 255 */
  bn.rshi   w21, w20, w19 >> 255

  /* Compute q2 = q1*u
     Instead of full q2 (which would be up to 514 bits) we ignore the MSb of u
     and the MSb of q1 and correct this later. This allows using a 256x256
     multiplier.
     => max. length q2': 512 bit
     q2' = q1[255:0]*u[255:0] = [w20, w19] = w21 * w28 */
  bn.mulqacc.z          w21.0, w28.0,  0
  bn.mulqacc            w21.1, w28.0, 64
  bn.mulqacc.so  w23.L, w21.0, w28.1, 64
  bn.mulqacc            w21.2, w28.0,  0
  bn.mulqacc            w21.1, w28.1,  0
  bn.mulqacc            w21.0, w28.2,  0
  bn.mulqacc            w21.3, w28.0, 64
  bn.mulqacc            w21.2, w28.1, 64
  bn.mulqacc            w21.1, w28.2, 64
  bn.mulqacc.so  w23.U, w21.0, w28.3, 64
  bn.mulqacc            w21.3, w28.1,  0
  bn.mulqacc            w21.2, w28.2,  0
  bn.mulqacc            w21.1, w28.3,  0
  bn.mulqacc            w21.3, w28.2, 64
  bn.mulqacc.so  w24.L, w21.2, w28.3, 64
  bn.mulqacc.so  w24.U, w21.3, w28.3,  0
  bn.add    w20, w20, w31

  /* q3 = q2 >> 257
     In this step, the compensation for the neglected MSbs of q1 and u is
     carried out underway. To add them in the q2 domain, they would have to be
     left shifted by 256 bit first. To directly add them we first shift q2' by
     256 bit to the right (by dropping the lower 256 bit), perform the
     additions, and shift the result another bit to the right. */

  /* w25 = q1[256] = x[511:256] >> 255 */
  bn.rshi   w25, w31, w20 >> 255

  /* compensate for neglected MSB of u, by adding full q1
     this is unconditional since MSB of u is always 1

     N.B. The dummy instruction below is to clear flags after subtraction,
     as [w25, w24] contain values that may be correlated with the input to
     secp256k1_reduce, which in turn may be a secret share as noted above.

     [w25, w24] = q2'' <= q2'[511:256] + q1 = [w25, w24] <= w24 + [w25, w21] */
  bn.add    w24, w24, w21
  bn.addc   w25, w25, w31
  bn.add    w31, w31, w31  /* dummy instruction to clear flags */

  /* compensate for neglected MSB of q1, by conditionally adding u

     N.B. The dummy instruction below is to clear flags after subtraction,
     as [w25, w24] contain values that may be correlated with the input to
     secp256k1_reduce, which in turn may be a secret share as noted above.

     [w25, w24] = q2''' <= q2'' + [0 or u] = [w25, w24] + w22 */
  bn.add    w24, w24, w22
  bn.addc   w25, w25, w31
  bn.add    w31, w31, w31  /* dummy instruction to clear flags */

  /* q3 = w21 = q2''' >> 1 */
  bn.rshi   w21, w25, w24 >> 1

  /* [w23, w22] <= q3 * p

    N.B. The bn.mulqacc.so.z instruction below is to clear the value of ACC as
    well as the flags set by the prior mulqacc.so instructions, as
    secp256k1_reduce may be called on secret shares of the same value
    back-to-back. For instance, secp256k1_sign calls mod_mul_320x128 to
    multiplicatively mask a pair of additive secret shares; while these are
    indeed indistinguishable from random values once reduced mod n, the values
    left in ACC after the below multiplications are unreduced and have the
    potential to leak information about their multiplicands. */
  bn.mulqacc.z            w29.0, w21.0,  0
  bn.mulqacc              w29.1, w21.0, 64
  bn.mulqacc.so    w22.L, w29.0, w21.1, 64
  bn.mulqacc              w29.2, w21.0,  0
  bn.mulqacc              w29.1, w21.1,  0
  bn.mulqacc              w29.0, w21.2,  0
  bn.mulqacc              w29.3, w21.0, 64
  bn.mulqacc              w29.2, w21.1, 64
  bn.mulqacc              w29.1, w21.2, 64
  bn.mulqacc.so    w22.U, w29.0, w21.3, 64
  bn.mulqacc              w29.3, w21.1,  0
  bn.mulqacc              w29.2, w21.2,  0
  bn.mulqacc              w29.1, w21.3,  0
  bn.mulqacc              w29.3, w21.2, 64
  bn.mulqacc.so    w23.L, w29.2, w21.3, 64
  bn.mulqacc.so    w23.U, w29.3, w21.3,  0
  bn.mulqacc.so.z  w31.U, w31.0, w31.0,  0  /* dummy instruction to clear state */

  /* We compute the final remainder r by subtracting the estimate q3*m from
     x. Since q3 never overestimates the true quotient, r is non-negative; as
     derived in the comment above, r < 3m (but r may exceed 2^257, so the high
     word w20 has to participate in the corrections below).

     [w20, w22] = r <= [w20, w19] - [w23, w22] = x - q3*m  */
  bn.sub    w22, w19, w22
  bn.subb   w20, w20, w23

  /* First full-width conditional subtraction of the modulus. The select
     condition is the borrow of (r - m), i.e. the modulus is kept off if
     r < m. The selection is constant time and the borrow depends only on the
     magnitude of the Barrett remainder, equivalent to the L-flag based
     selection in the P-256 version.

     [w25,w21] = r <= r - (r >= m ? m : 0)  (now r < 2m) */
  bn.sub    w23, w22, w29
  bn.subb   w24, w20, w31
  bn.sel    w21, w22, w23, FG0.C
  bn.sel    w25, w20, w24, FG0.C

  /* Second full-width conditional subtraction of the modulus. The input is
     below 2m < 2^257 here, so the fully reduced result fits into 256 bits
     and only the lower word needs to be selected.

     N.B. The dummy instruction below is to clear flags after the
     subtractions, as their state may depend on values derived from a secret
     share.

     w19 = r <= r - (r >= m ? m : 0)  (now r < m) */
  bn.sub    w23, w21, w29
  bn.subb   w24, w25, w31
  bn.sel    w19, w21, w23, FG0.C
  bn.sub    w31, w31, w31  /* dummy instruction to clear flags */

  ret

/**
 * 256-bit modular multiplication for secp256k1 coordinate and scalar fields.
 *
 * Returns c = a * b mod m
 *
 * Expects two 256 bit operands, 256 bit modulus and pre-computed parameter u
 * for Barrett reduction (usually greek mu in literature). See the note above
 * `secp256k1_reduce` for details.
 *
 * Flags: Flags have no meaning beyond the scope of this subroutine.
 *
 * @param[in]  w24: a, first 256 bit operand (a * b < 2^256 * p)
 * @param[in]  w25: b, second 256 bit operand (a * b < 2^256 * p)
 * @param[in]  w29: m, modulus, curve order n or finite field modulus p
 * @param[in]  w28: u, lower 256 bit of Barrett constant for m
 * @param[in]  w31: all-zero
 * @param[in]  MOD: m, modulus
 * @param[out]  w19: c, result
 *
 * clobbered registers: w19, w20, w21, w22, w23, w24, w25
 * clobbered flag groups: FG0
 */
mod_mul_256x256:
  /* Compute the integer product of the operands x = a * b
     x = [w20, w19] = a * b = w24 * w25
     => max. length x: 512 bit */
  bn.mulqacc.z          w24.0, w25.0,  0
  bn.mulqacc            w24.1, w25.0, 64
  bn.mulqacc.so  w19.L, w24.0, w25.1, 64
  bn.mulqacc            w24.2, w25.0,  0
  bn.mulqacc            w24.1, w25.1,  0
  bn.mulqacc            w24.0, w25.2,  0
  bn.mulqacc            w24.3, w25.0, 64
  bn.mulqacc            w24.2, w25.1, 64
  bn.mulqacc            w24.1, w25.2, 64
  bn.mulqacc.so  w19.U, w24.0, w25.3, 64
  bn.mulqacc            w24.3, w25.1,  0
  bn.mulqacc            w24.2, w25.2,  0
  bn.mulqacc            w24.1, w25.3,  0
  bn.mulqacc            w24.3, w25.2, 64
  bn.mulqacc.so  w20.L, w24.2, w25.3, 64
  bn.mulqacc.so  w20.U, w24.3, w25.3,  0

  /* Store correction factor to compensate for later neglected MSb of x.
     x is 512 bit wide and therefore the 255 bit right shifted version q1
     (below) contains 257 bit. Bit 256 of q1 is neglected to allow using a
     256x256 multiplier. For the MSb of x being set we temporary store u
     (or zero) here to be used in a later constant time correction of a
     multiplication with u. Note that this requires the MSb flag being carried
     over from the multiplication routine.

     N.B. The dummy instruction following the selection is for clearing ACC and
     flags set by the prior multiplications which may input secret values. See
     the block comments in secp256k1_reduce for more details. */
  bn.sel         w22, w28, w31, M
  bn.mulqacc.so.z  w31.U, w31.0, w31.0,  0  /* dummy instruction to clear state */

  /* Reduce product modulo m (tail-call). */
  jal       x0, secp256k1_reduce

/**
 * 320- by 128-bit modular multiplication for secp256k1 coordinate and scalar
 * fields.
 *
 * Returns c = a * b mod m
 *
 * Expects two operands, 256 bit modulus and pre-computed parameter u
 * for Barrett reduction (usually greek mu in literature). See the note above
 * `secp256k1_reduce` for details.
 *
 * Flags: Flags have no meaning beyond the scope of this subroutine.
 *
 * @param[in]  w24: a0, low part of 320-bit operand a (256 bits)
 * @param[in]  w25: a1, high part of 320-bit operand a (64 bits)
 * @param[in]  w26: b, second operand (128 bits)
 * @param[in]  w29: m, modulus, curve order n or finite field modulus p
 * @param[in]  w28: u, lower 256 bit of Barrett constant for m
 * @param[in]  w31: all-zero
 * @param[in]  MOD: m, modulus
 * @param[out]  w19: c, result
 *
 * clobbered registers: w19, w20, w21, w22, w23, w24, w25
 * clobbered flag groups: FG0
 */
mod_mul_320x128:
  /* Compute the integer product of the operands x = a * b
     x = [w20, w19] = a * b = w24 * w25
     => max. length of x: 448 bit */
  bn.mulqacc.z          w24.0, w26.0, 0
  bn.mulqacc            w24.0, w26.1, 64
  bn.mulqacc.so  w19.L, w24.1, w26.0, 64
  bn.mulqacc            w24.1, w26.1, 0
  bn.mulqacc            w24.2, w26.0, 0
  bn.mulqacc            w24.2, w26.1, 64
  bn.mulqacc.so  w19.U, w24.3, w26.0, 64
  bn.mulqacc            w24.3, w26.1, 0
  bn.mulqacc            w25.0, w26.0, 0
  bn.mulqacc.wo    w20, w25.0, w26.1, 64

  /* Store correction factor to compensate for later neglected MSb of x.
     x is 512 bit wide and therefore the 255 bit right shifted version q1
     (below) contains 257 bit. Bit 256 of q1 is neglected to allow using a
     256x256 multiplier. For the MSb of x being set we temporary store u
     (or zero) here to be used in a later constant time correction of a
     multiplication with u. Note that this requires the MSb flag being carried
     over from the multiplication routine.

     N.B. The dummy instruction following the selection is for clearing ACC and
     flags set by the prior multiplications which may input secret values. See
     the block comments in secp256k1_reduce for more details. */
  bn.sel    w22, w28, w31, M
  bn.mulqacc.wo.z    w31, w31.0, w31.0, 0

  /* Reduce product modulo m (tail-call). */
  jal       x0, secp256k1_reduce

/**
 * 256-bit modular multiplication for the secp256k1 coordinate field.
 *
 * Returns c = a * b mod p
 *
 * Uses a specialized algorithm to quickly multiply modulo the secp256k1
 * coordinate modulus p = 2^256 - 2^32 - 977. With the 33-bit constant
 * c0 = 2^256 - p = 2^32 + 977 = 0x1000003d1 we have 2^256 == c0 (mod p), so
 * the 512-bit product x = x1*2^256 + x0 folds as x == x0 + c0*x1 (mod p).
 * Two folds, one carry correction and one conditional subtraction produce
 * the fully reduced result:
 *
 *   x = a * b                    (x < 2^512)
 *   y = x0 + c0*x1               (y < 2^256 + 2^289, i.e. y >> 256 <= 2^33)
 *   z = y0 + c0*y1               (z < 2^256 + 2^67)
 *   if z carried past 2^256:
 *     z = (z mod 2^256) + c0     (then z < 2^68 < p; cannot carry again)
 *   z = z mod p                  (single conditional subtraction, bn.addm)
 *
 * All steps are straight-line constant-time code. The single carry-based
 * selection depends only on an arithmetic carry of the (randomized) product,
 * analogous to the M-flag based selection in mod_mul_256x256.
 *
 * The result is fully reduced for ANY operands a, b < 2^256; the operands do
 * not need to be smaller than p.
 *
 * Flags: Flags have no meaning beyond the scope of this subroutine.
 *
 * @param[in]  w24: a, first 256 bit operand
 * @param[in]  w25: b, second 256 bit operand
 * @param[in]  w28: r256, constant, 2^256 mod p = 2^256 - p (= c0)
 * @param[in]  w31: all-zero
 * @param[in]  MOD: p, modulus of the secp256k1 underlying finite field
 * @param[out]  w19: c, result
 *
 * clobbered registers: w19, w20, w21, w22
 * clobbered flag groups: FG0
 */
mul_modp:
  /* Compute the integer product of the operands x = a * b
     x = [w20, w19] = a * b = w24 * w25
     => max. length x: 512 bit */
  bn.mulqacc.z          w24.0, w25.0,  0
  bn.mulqacc            w24.1, w25.0, 64
  bn.mulqacc.so  w19.L, w24.0, w25.1, 64
  bn.mulqacc            w24.2, w25.0,  0
  bn.mulqacc            w24.1, w25.1,  0
  bn.mulqacc            w24.0, w25.2,  0
  bn.mulqacc            w24.3, w25.0, 64
  bn.mulqacc            w24.2, w25.1, 64
  bn.mulqacc            w24.1, w25.2, 64
  bn.mulqacc.so  w19.U, w24.0, w25.3, 64
  bn.mulqacc            w24.3, w25.1,  0
  bn.mulqacc            w24.2, w25.2,  0
  bn.mulqacc            w24.1, w25.3,  0
  bn.mulqacc            w24.3, w25.2, 64
  bn.mulqacc.so  w20.L, w24.2, w25.3, 64
  bn.mulqacc.so  w20.U, w24.3, w25.3,  0
  /* The final shift-out above leaves ACC = 0. */

  /* First fold: y = x0 + c0*x1. The folding constant c0 is the lowest limb
     of w28 (the upper limbs of w28 are zero) and c0*x1 < 2^289.
       [w22, w21] <= c0 * x1 = w28.0 * w20 */
  bn.mulqacc.z          w28.0, w20.0,  0
  bn.mulqacc.so  w21.L, w28.0, w20.1, 64
  bn.mulqacc            w28.0, w20.2,  0
  bn.mulqacc.so  w21.U, w28.0, w20.3, 64
  bn.mulqacc.wo  w22,   w31.0, w31.0,  0

  /* y = [w22, w19] <= x0 + c0*x1 = w19 + [w22, w21]
     The high part y1 = w22 is at most 2^33. */
  bn.add    w19, w19, w21
  bn.addc   w22, w22, w31

  /* Second fold: z = y0 + c0*y1, with c0*y1 < 2^67.
       w22 <= c0 * y1 = w28.0 * w22.0 */
  bn.mulqacc.z          w28.0, w22.0,  0
  bn.mulqacc.wo  w22,   w31.0, w31.0,  0

  /* w19 <= z mod 2^256 = (y0 + c0*y1) mod 2^256, FG0.C <= carry */
  bn.add    w19, w19, w22

  /* If the addition above wrapped around 2^256, fold the missing 2^256 in as
     another c0. In the carry case z mod 2^256 < 2^67, so this addition can
     never carry again.
       w19 <= w19 + (FG0.C ? c0 : 0) */
  bn.sel    w22, w28, w31, FG0.C
  bn.add    w19, w19, w22

  /* Final reduction: w19 < 2^256 < 2p, so a single conditional subtraction
     of p fully reduces.
       w19 <= w19 mod p */
  bn.addm   w19, w19, w31

  /* Clear ACC and the M/L/Z flags, as they depend on intermediate products
     (FG0.C is always zero here). */
  bn.mulqacc.wo.z  w31, w31.0, w31.0, 0

  ret


/**
 * Set up for coordinate field operations modulo the prime p.
 *
 * Loads the constants required by `mul_modp` and other coordinate-arithmetic
 * routines. Note that for secp256k1, r256 = 2^256 - p = 2^32 + 977 is at the
 * same time the lower part of the Barrett constant for p, because
 * floor(2^512/p) = 2^256 + (2^32 + 977). The Barrett-based multiplication
 * routines (mod_mul_256x256, mod_mul_320x128) therefore also work for the
 * coordinate field with this setup.
 *
 * Flags: Flags have no meaning beyond the scope of this subroutine.
 *
 * @param[in]  w31: all-zero
 * @param[out] MOD: p, modulus of secp256k1 underlying finite field
 * @param[out] w28: r256, constant, 2^256 mod p = 2^256 - p
 * @param[out] w29: p, modulus
 *
 * clobbered registers: x2, x3, w28, w29
 * clobbered flag groups: FG0
 */
setup_modp:
  /* Load the modulus p from DMEM and store it in MOD.
     MOD <= w29 <= p = dmem[secp256k1_p] */
  li        x2, 29
  la        x3, secp256k1_p
  bn.lid    x2, 0(x3)
  bn.wsrw   MOD, w29

  /* Compute the constant r256 for reduction modulo p.
       w28 <= 2^256 - p = r256 */
  bn.sub    w28, w31, w29
  ret

/**
 * secp256k1 point addition in projective coordinates
 *
 * returns R = (x_r, y_r, z_r) <= P+Q = (x_p, y_p, z_p) + (x_q, y_q, z_q)
 *         with R, P and Q being valid secp256k1 curve points
 *           in projective coordinates
 *
 * This routine adds two valid secp256k1 curve points in projective space.
 * Point addition is performed based on the complete formulas of Bosma and
 * Lenstra for Weierstrass curves as first published in [1] and
 * optimized in [2].
 * The implemented version follows Algorithm 7 of [2], which is an optimized
 * variant for Weierstrass curves with domain parameter 'a' set to a=0.
 * Numbering of the steps below and naming of symbols follows the
 * terminology of Algorithm 7 of [2].
 * The two multiplications with b3 = 3*b = 21 are implemented as constant
 * time addition chains (2,4,5,10,20,21), so no domain parameter has to be
 * provided in a register.
 * The routine is limited to secp256k1 curve points due to:
 *   - the fixed a=0 domain parameter
 *   - usage of a secp256k1 optimized modular multiplication kernel
 * Since the formulas are complete, the routine is correct for all inputs,
 * including P = Q, P = -Q and the point at infinity (0 : y != 0 : 0).
 * This routine runs in constant time.
 *
 * [1] https://doi.org/10.1006/jnth.1995.1088
 * [2] https://doi.org/10.1007/978-3-662-49890-3_16
 *     (https://eprint.iacr.org/2015/1060, Renes-Costello-Batina)
 *
 * @param[in]  w8: x_p, x-coordinate of input point P
 * @param[in]  w9: y_p, y-coordinate of input point P
 * @param[in]  w10: z_p, z-coordinate of input point P
 * @param[in]  w11: x_q, x-coordinate of input point Q
 * @param[in]  w12: y_q, y-coordinate of input point Q
 * @param[in]  w13: z_q, z-coordinate of input point Q
 * @param[in]  w28: r256, constant, 2^256 mod p = 2^256 - p
 * @param[in]  w31: all-zero.
 * @param[in]  MOD: p, modulus of secp256k1 underlying finite field
 * @param[out]  w11: x_r, x-coordinate of resulting point R
 * @param[out]  w12: y_r, y-coordinate of resulting point R
 * @param[out]  w13: z_r, z-coordinate of resulting point R
 *
 * Flags: Flags have no meaning beyond the scope of this subroutine.
 *
 * clobbered registers: w11 to w25
 * clobbered flag groups: FG0
 */
proj_add:
  /* mapping of parameters to symbols of [2] (Algorithm 7):
     X1 = x_p; Y1 = y_p; Z1 = z_p; X2 = x_q; Y2 = y_q; Z2 = z_q
     X3 = x_r; Y3 = y_r; Z3 = z_r */

  /* 1: w14 = t0 <= X1*X2 = w8*w11 */
  bn.mov    w24, w8
  bn.mov    w25, w11
  jal       x1, mul_modp
  bn.mov    w14, w19

  /* 2: w15 = t1 <= Y1*Y2 = w9*w12 */
  bn.mov    w24, w9
  bn.mov    w25, w12
  jal       x1, mul_modp
  bn.mov    w15, w19

  /* 3: w16 = t2 <= Z1*Z2 = w10*w13 */
  bn.mov    w24, w10
  bn.mov    w25, w13
  jal       x1, mul_modp
  bn.mov    w16, w19

  /* 4: w17 = t3 <= X1+Y1 = w8+w9 */
  bn.addm   w17, w8, w9

  /* 5: w18 = t4 <= X2+Y2 = w11+w12 */
  bn.addm   w18, w11, w12

  /* 6: w19 = t3 <= t3*t4 = w17*w18 */
  bn.mov    w24, w17
  bn.mov    w25, w18
  jal       x1, mul_modp

  /* 7: w18 = t4 <= t0+t1 = w14+w15 */
  bn.addm   w18, w14, w15

  /* 8: w17 = t3 <= t3-t4 = w19-w18 */
  bn.subm   w17, w19, w18

  /* 9: w18 = t4 <= Y1+Z1 = w9+w10 */
  bn.addm   w18, w9, w10

  /* 10: w19 = X3 <= Y2+Z2 = w12+w13 */
  bn.addm   w19, w12, w13

  /* 11: w18 = t4 <= t4*X3 = w18*w19 */
  bn.mov    w24, w18
  bn.mov    w25, w19
  jal       x1, mul_modp
  bn.mov    w18, w19

  /* 12: w19 = X3 <= t1+t2 = w15+w16 */
  bn.addm   w19, w15, w16

  /* 13: w18 = t4 <= t4-X3 = w18-w19 */
  bn.subm   w18, w18, w19

  /* 14: w19 = X3 <= X1+Z1 = w8+w10 */
  bn.addm   w19, w8, w10

  /* 15: w12 = Y3 <= X2+Z2 = w11+w13 */
  bn.addm   w12, w11, w13

  /* 16: w19 = X3 <= X3*Y3 = w19*w12 */
  bn.mov    w24, w19
  bn.mov    w25, w12
  jal       x1, mul_modp

  /* 17: w12 = Y3 <= t0+t2 = w14+w16 */
  bn.addm   w12, w14, w16

  /* 18: w12 = Y3 <= X3-Y3 = w19-w12 */
  bn.subm   w12, w19, w12

  /* 19: w19 = X3 <= t0+t0 = w14+w14 */
  bn.addm   w19, w14, w14

  /* 20: w14 = t0 <= X3+t0 = w19+w14 */
  bn.addm   w14, w19, w14

  /* 21: w16 = t2 <= b3*t2 = 21*w16
     (addition chain 2,4,5,10,20,21) */
  bn.addm   w24, w16, w16
  bn.addm   w24, w24, w24
  bn.addm   w24, w24, w16
  bn.addm   w24, w24, w24
  bn.addm   w24, w24, w24
  bn.addm   w16, w24, w16

  /* 22: w13 = Z3 <= t1+t2 = w15+w16 */
  bn.addm   w13, w15, w16

  /* 23: w15 = t1 <= t1-t2 = w15-w16 */
  bn.subm   w15, w15, w16

  /* 24: w12 = Y3 <= b3*Y3 = 21*w12
     (addition chain 2,4,5,10,20,21) */
  bn.addm   w24, w12, w12
  bn.addm   w24, w24, w24
  bn.addm   w24, w24, w12
  bn.addm   w24, w24, w24
  bn.addm   w24, w24, w24
  bn.addm   w12, w24, w12

  /* 25: w11 = X3 <= t4*Y3 = w18*w12 */
  bn.mov    w24, w18
  bn.mov    w25, w12
  jal       x1, mul_modp
  bn.mov    w11, w19

  /* 26: w16 = t2 <= t3*t1 = w17*w15 */
  bn.mov    w24, w17
  bn.mov    w25, w15
  jal       x1, mul_modp
  bn.mov    w16, w19

  /* 27: w11 = X3 <= t2-X3 = w16-w11 */
  bn.subm   w11, w16, w11

  /* 28: w12 = Y3 <= Y3*t0 = w12*w14 */
  bn.mov    w24, w12
  bn.mov    w25, w14
  jal       x1, mul_modp
  bn.mov    w12, w19

  /* 29: w15 = t1 <= t1*Z3 = w15*w13 */
  bn.mov    w24, w15
  bn.mov    w25, w13
  jal       x1, mul_modp
  bn.mov    w15, w19

  /* 30: w12 = Y3 <= t1+Y3 = w15+w12 */
  bn.addm   w12, w15, w12

  /* 31: w14 = t0 <= t0*t3 = w14*w17 */
  bn.mov    w24, w14
  bn.mov    w25, w17
  jal       x1, mul_modp
  bn.mov    w14, w19

  /* 32: w19 = Z3 <= Z3*t4 = w13*w18 */
  bn.mov    w24, w13
  bn.mov    w25, w18
  jal       x1, mul_modp

  /* 33: w13 = Z3 <= Z3+t0 = w19+w14 */
  bn.addm   w13, w19, w14

  ret


/**
 * Convert projective coordinates of a secp256k1 curve point to affine
 * coordinates
 *
 * returns P = (x_a, y_a) = (x/z mod p, y/z mod p)
 *         with P being a valid secp256k1 curve point
 *              x_a and y_a being the affine coordinates of said curve point
 *              x, y and z being a set of projective coordinates of said point
 *              and p being the modulus of the secp256k1 underlying finite
 *              field.
 *
 * This routine computes the affine coordinates for a set of projective
 * coordinates of a valid secp256k1 curve point. The routine performs the
 * required divisions by computing the multiplicative modular inverse of the
 * projective z-coordinate in the underlying finite field of the secp256k1
 * curve. For inverse computation Fermat's little theorem is used, i.e.
 * we compute z^-1 = z^(p-2) mod p.
 *
 * For exponentiation, we use the addition chain from libsecp256k1's field
 * inversion (https://github.com/bitcoin-core/secp256k1, field_*_impl.h),
 * which requires 255 squarings and 15 multiplications based on the
 * intermediate values
 *   x2 = z^(2^2 - 1), x3 = z^(2^3 - 1), x22 = z^(2^22 - 1),
 *   x44 = z^(2^44 - 1), ... , x223 = z^(2^223 - 1),
 * exploiting that p - 2 = (2^223 - 1)*2^33 + (2^22 - 1)*2^11 + 0b01011001101.
 *
 * This routine runs in constant time.
 *
 * Flags: Flags have no meaning beyond the scope of this subroutine.
 *
 * @param[in]  w8: x, x-coordinate of curve point (projective)
 * @param[in]  w9: y, y-coordinate of curve point (projective)
 * @param[in]  w10: z, z-coordinate of curve point (projective)
 * @param[in]  w28: r256, constant, 2^256 mod p = 2^256 - p
 * @param[in]  MOD: p, modulus of the finite field of secp256k1
 * @param[out]  w11: x_a, x-coordinate of curve point (affine)
 * @param[out]  w12: y_a, y-coordinate of curve point (affine)
 * @param[out]  w14: z^-1, modular inverse of the projective z-coordinate
 *
 * clobbered registers: w10 to w16, w19, w24, w25
 * clobbered flag groups: FG0
 */
proj_to_affine:

  /* Fully reduce z. */
  bn.addm   w10, w10, w31

  /* w19 <= z^2 */
  bn.mov    w24, w10
  bn.mov    w25, w10
  jal       x1, mul_modp

  /* w12 <= z^2 * z = z^(2^2 - 1) = x2 */
  bn.mov    w24, w19
  bn.mov    w25, w10
  jal       x1, mul_modp
  bn.mov    w12, w19

  /* w19 <= x2^2 = z^6 */
  bn.mov    w24, w19
  bn.mov    w25, w19
  jal       x1, mul_modp

  /* w13 <= z^6 * z = z^(2^3 - 1) = x3 */
  bn.mov    w24, w19
  bn.mov    w25, w10
  jal       x1, mul_modp
  bn.mov    w13, w19

  /* w19 <= x3^(2^3) * x3 = z^(2^6 - 1) = x6 */
  bn.mov    w24, w19
  loopi     3, 3
    bn.mov    w25, w19
    jal       x1, mul_modp
    bn.mov    w24, w19
  bn.mov    w25, w13
  jal       x1, mul_modp

  /* w19 <= x6^(2^3) * x3 = z^(2^9 - 1) = x9 */
  bn.mov    w24, w19
  loopi     3, 3
    bn.mov    w25, w19
    jal       x1, mul_modp
    bn.mov    w24, w19
  bn.mov    w25, w13
  jal       x1, mul_modp

  /* w16 <= x9^(2^2) * x2 = z^(2^11 - 1) = x11 */
  bn.mov    w24, w19
  loopi     2, 3
    bn.mov    w25, w19
    jal       x1, mul_modp
    bn.mov    w24, w19
  bn.mov    w25, w12
  jal       x1, mul_modp
  bn.mov    w16, w19

  /* w14 <= x11^(2^11) * x11 = z^(2^22 - 1) = x22 */
  bn.mov    w24, w19
  loopi     11, 3
    bn.mov    w25, w19
    jal       x1, mul_modp
    bn.mov    w24, w19
  bn.mov    w25, w16
  jal       x1, mul_modp
  bn.mov    w14, w19

  /* w15 <= x22^(2^22) * x22 = z^(2^44 - 1) = x44 */
  bn.mov    w24, w19
  loopi     22, 3
    bn.mov    w25, w19
    jal       x1, mul_modp
    bn.mov    w24, w19
  bn.mov    w25, w14
  jal       x1, mul_modp
  bn.mov    w15, w19

  /* w16 <= x44^(2^44) * x44 = z^(2^88 - 1) = x88 (x11 is dead) */
  bn.mov    w24, w19
  loopi     44, 3
    bn.mov    w25, w19
    jal       x1, mul_modp
    bn.mov    w24, w19
  bn.mov    w25, w15
  jal       x1, mul_modp
  bn.mov    w16, w19

  /* w19 <= x88^(2^88) * x88 = z^(2^176 - 1) = x176 */
  bn.mov    w24, w19
  loopi     88, 3
    bn.mov    w25, w19
    jal       x1, mul_modp
    bn.mov    w24, w19
  bn.mov    w25, w16
  jal       x1, mul_modp

  /* w19 <= x176^(2^44) * x44 = z^(2^220 - 1) = x220 */
  bn.mov    w24, w19
  loopi     44, 3
    bn.mov    w25, w19
    jal       x1, mul_modp
    bn.mov    w24, w19
  bn.mov    w25, w15
  jal       x1, mul_modp

  /* w19 <= x220^(2^3) * x3 = z^(2^223 - 1) = x223 */
  bn.mov    w24, w19
  loopi     3, 3
    bn.mov    w25, w19
    jal       x1, mul_modp
    bn.mov    w24, w19
  bn.mov    w25, w13
  jal       x1, mul_modp

  /* w19 <= x223^(2^23) * x22; appends bits 0 || 1^22 to the exponent */
  bn.mov    w24, w19
  loopi     23, 3
    bn.mov    w25, w19
    jal       x1, mul_modp
    bn.mov    w24, w19
  bn.mov    w25, w14
  jal       x1, mul_modp

  /* w19 <= w19^(2^5) * z; appends bits 00001 to the exponent */
  bn.mov    w24, w19
  loopi     5, 3
    bn.mov    w25, w19
    jal       x1, mul_modp
    bn.mov    w24, w19
  bn.mov    w25, w10
  jal       x1, mul_modp

  /* w19 <= w19^(2^3) * x2; appends bits 011 to the exponent */
  bn.mov    w24, w19
  loopi     3, 3
    bn.mov    w25, w19
    jal       x1, mul_modp
    bn.mov    w24, w19
  bn.mov    w25, w12
  jal       x1, mul_modp

  /* w14 <= w19^(2^2) * z = z^(p-2) = z^-1; appends bits 01 to the exponent */
  bn.mov    w24, w19
  loopi     2, 3
    bn.mov    w25, w19
    jal       x1, mul_modp
    bn.mov    w24, w19
  bn.mov    w25, w10
  jal       x1, mul_modp
  bn.mov    w14, w19

  /* convert x-coordinate to affine
     w11 = x_a = x/z = x * z^(-1) = w8 * w14 */
  bn.mov    w24, w8
  bn.mov    w25, w14
  jal       x1, mul_modp
  bn.mov    w11, w19

  /* convert y-coordinate to affine
     w12 = y_a = y/z = y * z^(-1) = w9 * w14 */
  bn.mov    w24, w9
  bn.mov    w25, w14
  jal       x1, mul_modp
  bn.mov    w12, w19

  ret


/**
 * Variable time modular multiplicative inverse computation
 *
 * returns x_inv = x^-1 mod m
 *
 * This routine computes the modular multiplicative inverse for any x < m in
 * the field GF(m).
 * For inverse computation Fermat's little theorem is used, i.e.
 * we compute x^-1 = x^(m-2) mod m.
 * For exponentiation we use a standard, variable time square and multiply
 * algorithm. (The timing varies based on the modulus alone, not the input x,
 * so it is safe to use for a non-secret modulus and a secret operand).
 *
 * @param[in]  w0: x, a 256 bit operand with x < m
 * @param[in]  w29: m, modulus, 2^256 > m > 2^255.
 * @param[in]  w28: u, lower 256 bit of pre-computed Barrett constant
 * @param[in]  w31, all-zero
 * @param[in]  MOD: m, modulus
 * @param[out]  w1: x_inv, modular multiplicative inverse
 *
 * Flags: Flags have no meaning beyond the scope of this subroutine.
 *
 * clobbered registers: w1, w2, w3, w19, w24, w25
 * clobbered flag groups: FG0
 */
mod_inv:

  /* subtract 2 from modulus for Fermat's little theorem
     w2 = MOD - 2 = m - 2 */
  bn.wsrr   w2, MOD
  bn.subi   w2, w2, 2

  /* init square and multiply: w1 = 1 */
  bn.addi   w1, w31, 1

  /* square and multiply loop */
  loopi     256, 14

    /* square: w3 = w19 = w24*w25 = w1^2  mod m */
    bn.mov    w24, w1
    bn.mov    w25, w1
    jal       x1, mod_mul_256x256
    bn.mov    w3, w19

    /* shift MSB into carry flag
       w2 = 2*w2 = w2 << 1 */
    bn.add    w2, w2, w2

    /* skip multiplication if C flag not set */
    bn.sel    w1, w1, w3, C
    csrrs     x2, FG0, x0
    andi      x2, x2, 1
    beq       x2, x0, nomul

    /* multiply: w1 = w19 = w24*w25 = w3*w0  mod m */
    bn.mov    w24, w3
    bn.mov    w25, w0
    jal       x1, mod_mul_256x256
    bn.mov    w1, w19

    nomul:
    nop

  ret


/**
 * Fetch curve point from dmem and randomize z-coordinate
 *
 * returns P = (x, y, z) = (x_a*z, y_a*z, z)
 *         with P being a valid secp256k1 curve point in projective
 *              coordinates
 *              x_a and y_a being the affine coordinates as fetched from dmem
 *              z being a randomized z-coordinate
 *
 * This routines fetches the affine x- and y-coordinates of a curve point from
 * dmem and computes a valid set of projective coordinates. The z-coordinate is
 * randomized and x and y are scaled appropriately.
 * This routine runs in constant time.
 *
 * @param[in]  x10: constant 24
 * @param[in]  x21: dptr_x, pointer to dmem location containing affine
 *                          x-coordinate of input point
 * @param[in]  x22: dptr_y, pointer to dmem location containing affine
 *                          y-coordinate of input point
 * @param[in]  w28: r256, constant, 2^256 mod p = 2^256 - p
 * @param[in]  w31: all-zero
 * @param[in]  MOD: p, modulus of secp256k1 underlying finite field
 * @param[out] w14: x, projective x-coordinate
 * @param[out] w15: y, projective y-coordinate
 * @param[out] w16: z, random projective z-coordinate
 *
 * Flags: When leaving this subroutine, the M, L and Z flags of FG0 depend on
 *        the scaled projective y-coordinate.
 *
 * clobbered registers: w14 to w16, w19 to w26
 * clobbered flag groups: FG0
 */
fetch_proj_randomize:

  /* get random number from URND */
  bn.wsrr   w16, URND

  /* reduce random number
     w16 = z <= w16 mod p */
  bn.addm   w16, w16, w31

  /* fetch x-coordinate from dmem
     w24 = x_a <= dmem[x22] = dmem[dptr_x] */
  bn.lid    x10, 0(x21)

  /* scale x-coordinate
     w14 = x <= w24*w16 = x_a*z  mod p */
  bn.mov    w25, w16
  jal       x1, mul_modp
  bn.mov    w14, w19

  /* fetch y-coordinate from dmem
     w24 = y_a <= dmem[x22] = dmem[dptr_y] */
  bn.lid    x10, 0(x22)

  /* scale y-coordinate
     w15 = y <= w24*w16 = y_a*z  mod p */
  bn.mov    w25, w16
  jal       x1, mul_modp
  bn.mov    w15, w19

  ret


/**
 * secp256k1 point doubling in projective space
 *
 * returns R = (x_r, y_r, z_r) <= 2*P = 2*(x_p, y_p, z_p)
 *         with R, P being valid secp256k1 curve points
 *
 * This routine doubles a given secp256k1 curve point in projective
 * coordinates. The implementation follows Algorithm 9 of [1], the
 * exception-free doubling formulas for short Weierstrass curves with domain
 * parameter a=0. The multiplication with b3 = 3*b = 21 is implemented as a
 * constant time addition chain (2,4,5,10,20,21).
 *
 * The formulas are exception-free; in particular, doubling the point at
 * infinity (0 : y != 0 : 0) again yields a representation of the point at
 * infinity with nonzero y-coordinate, so (in contrast to the P-256
 * implementation) no special case handling is required.
 *
 * This routine runs in constant time.
 *
 * [1] https://doi.org/10.1007/978-3-662-49890-3_16
 *     (https://eprint.iacr.org/2015/1060, Renes-Costello-Batina)
 *
 * @param[in]  w8: x_p, x-coordinate of input point
 * @param[in]  w9: y_p, y-coordinate of input point
 * @param[in]  w10: z_p, z-coordinate of input point
 * @param[in]  w28: r256, constant, 2^256 mod p = 2^256 - p
 * @param[in]  w31: all-zero.
 * @param[in]  MOD: p, modulus of secp256k1 underlying finite field
 * @param[out]  w8: x_r, x-coordinate of resulting point
 * @param[out]  w9: y_r, y-coordinate of resulting point
 * @param[out]  w10: z_r, z-coordinate of resulting point
 *
 * Flags: Flags have no meaning beyond the scope of this subroutine.
 *
 * clobbered registers: w14 to w19, w24, w25
 * clobbered flag groups: FG0
 */
proj_double:
  /* mapping of parameters to symbols of [1] (Algorithm 9):
     X = x_p; Y = y_p; Z = z_p; X3 = x_r; Y3 = y_r; Z3 = z_r */

  /* 1: w14 = t0 <= Y*Y = w9*w9 */
  bn.mov    w24, w9
  bn.mov    w25, w9
  jal       x1, mul_modp
  bn.mov    w14, w19

  /* 2-4: w17 = Z3 <= 8*t0 = 8*Y^2 */
  bn.addm   w17, w14, w14
  bn.addm   w17, w17, w17
  bn.addm   w17, w17, w17

  /* 5: w15 = t1 <= Y*Z = w9*w10 */
  bn.mov    w24, w9
  bn.mov    w25, w10
  jal       x1, mul_modp
  bn.mov    w15, w19

  /* 6: w19 = t2 <= Z*Z = w10*w10 */
  bn.mov    w24, w10
  bn.mov    w25, w10
  jal       x1, mul_modp

  /* 7: w16 = t2 <= b3*t2 = 21*w19
     (addition chain 2,4,5,10,20,21) */
  bn.addm   w24, w19, w19
  bn.addm   w24, w24, w24
  bn.addm   w24, w24, w19
  bn.addm   w24, w24, w24
  bn.addm   w24, w24, w24
  bn.addm   w16, w24, w19

  /* 8: w18 = X3 <= t2*Z3 = w16*w17 */
  bn.mov    w24, w16
  bn.mov    w25, w17
  jal       x1, mul_modp
  bn.mov    w18, w19

  /* 9: w10 = Y3 <= t0+t2 = w14+w16 (z_p is dead, reuse w10) */
  bn.addm   w10, w14, w16

  /* 10: w17 = Z3 <= t1*Z3 = w15*w17 */
  bn.mov    w24, w15
  bn.mov    w25, w17
  jal       x1, mul_modp
  bn.mov    w17, w19

  /* 11: w15 = t1 <= t2+t2 = w16+w16 */
  bn.addm   w15, w16, w16

  /* 12: w16 = t2 <= t1+t2 = w15+w16 */
  bn.addm   w16, w15, w16

  /* 13: w14 = t0 <= t0-t2 = w14-w16 */
  bn.subm   w14, w14, w16

  /* 14: w10 = Y3 <= t0*Y3 = w14*w10 */
  bn.mov    w24, w14
  bn.mov    w25, w10
  jal       x1, mul_modp
  bn.mov    w10, w19

  /* 15: w10 = Y3 <= X3+Y3 = w18+w10 */
  bn.addm   w10, w18, w10

  /* 16: w19 = t1 <= X*Y = w8*w9 */
  bn.mov    w24, w8
  bn.mov    w25, w9
  jal       x1, mul_modp

  /* 17: w19 = X3 <= t0*t1 = w14*w19 */
  bn.mov    w24, w14
  bn.mov    w25, w19
  jal       x1, mul_modp

  /* 18: w8 = X3 <= X3+X3 = w19+w19; place outputs */
  bn.addm   w8, w19, w19
  bn.mov    w9, w10
  bn.mov    w10, w17

  ret


/**
 * secp256k1 scalar point multiplication in affine space
 *
 * returns R = k*P = k*(x_p, y_p)
 *         with R, P being valid secp256k1 curve points in affine
 *              coordinates
 *              k being a 256 bit scalar
 *
 * This routine performs scalar multiplication based on the group laws
 * of Weierstrass curves.
 * A constant time double-and-add algorithm (sometimes referred to as
 * double-and-add-always) is used.
 * Due to the secp256k1 optimized implementations of the called routines for
 * point addition and doubling, this routine is limited to secp256k1.
 *
 * The routine receives the scalar in two shares k0, k1 such that
 *   k = (k0 + k1) mod n
 * The loop operates on both shares in parallel, computing (k0 + k1) * P as
 * follows:
 *  Q = (0, 1, 0) # origin
 *  for i in 319..0:
 *    Q = 2 * Q
 *    A = if (k0[i] ^ k1[i]) then P else 2P
 *    B = Q + A
 *    Q = if (k0[i] | k1[i]) then B else Q
 *
 *
 * Each share k0/k1 is 320 bits, even though it represents a 256-bit value.
 * This is a side-channel protection measure.
 *
 * @param[in]  x21: dptr_x, pointer to affine x-coordinate in dmem
 * @param[in]  x22: dptr_y, pointer to affine y-coordinate in dmem
 * @param[in]  w0: lower 256 bits of k0, first share of scalar
 * @param[in]  w1: upper 64 bits of k0, first share of scalar
 * @param[in]  w2: lower 256 bits of k1, second share of scalar
 * @param[in]  w3: upper 64 bits of k1, second share of scalar
 * @param[in]  w31: all-zero
 * @param[in]  MOD: p, modulus, 2^256 > p > 2^255.
 * @param[out]  w8: x, x-coordinate of curve point (projective)
 * @param[out]  w9: y, y-coordinate of curve point (projective)
 * @param[out]  w10: z, z-coordinate of curve point (projective)
 *
 * Flags: When leaving this subroutine, the M, L and Z flags of FG0 depend on
 *        the computed affine y-coordinate.
 *
 * clobbered registers: x2, x3, x10, w0 to w30
 * clobbered flag groups: FG0
 */
scalar_mult_int:
  /* Set up for coordinate arithmetic.
       MOD <= p
       w28 <= r256
       w29 <= p */
  jal       x1, setup_modp

  /* get randomized projective coodinates of curve point
     P = (x_p, y_p, z_p) = (w8, w9, w10) = (w14, w15, w16) =
     (x*z mod p, y*z mod p, z) */
  li        x10, 24
  jal       x1, fetch_proj_randomize
  bn.mov    w8, w14
  bn.mov    w9, w15
  bn.mov    w10, w16

  /* Init 2P, this will be used for the addition part in the double-and-add
     loop when the bit at the current index is 1 for both shares of the scalar.
     2P = (w4, w5, w6) <= (w8, w9, w10) <= 2*(w8, w9, w10) = 2*P */
  jal       x1, proj_double
  bn.mov    w4, w8
  bn.mov    w5, w9
  bn.mov    w6, w10

  /* Shift first share of k so its MSB is in the most significant position of
     a word.

     N.B. This has been intentionally separated from accesses to [w2,w3] below
     to avoid potential transient side channel leakage from accessing k0 and k1
     in sequential instructions.

     w0,w1 <= [w0, w1] << 192 = k0 << 192 */
  bn.wsrr   w20, URND
  bn.rshi   w1, w1, w0 >> 64
  bn.rshi   w0, w0, w20 >> 64

  /* init double-and-add with point in infinity
     Q = (w8, w9, w10) <= (0, 1, 0) */
  bn.mov    w8, w31
  bn.addi   w9, w31, 1
  bn.mov    w10, w31

  /* Shift second share of k so its MSB is in the most significant position of a
     word as well.

     w2,w3 <= [w2, w3] << 192 = k1 << 192 */
  bn.rshi   w3, w3, w2 >> 64
  bn.rshi   w2, w2, w20 >> 64

  /* double-and-add loop with decreasing index */
  loopi     320, 64

    /* double point Q
       Q = (w8, w9, w10) <= 2*(w8, w9, w10) = 2*Q */
    jal       x1, proj_double

    /* prepare a mostly-randomized word with LSb matching the MSb of k0 for
       performing a MSb check on k0 and k1 after the following call. */
    bn.wsrr   w20, URND
    bn.rshi   w7, w20, w1 >> 255

    /* re-fetch and randomize P again
       P = (w14, w15, w16) */
    jal       x1, fetch_proj_randomize

    /* probe if MSb of either of the two scalars (k0 or k1) but not both is 1.
       - If only one MSb is set, select P for addition
       - If both MSbs are set, select 2P for addition
       - If neither MSB is set, also 2P will be selected but this will be
         discarded later

       w26 <= MSb(k1) */
    bn.wsrr   w20, URND
    bn.rshi   w26, w20, w3 >> 255

    /* N.B. The L bit here is secret. For side channel protection in the
       selects below, it is vital that neither option is equal to the
       destination register (e.g. bn.sel w0, w0, w1). In this case, the
       hamming distance from the destination's previous value to its new value
       will be 0 in one of the cases and potentially reveal L.

       The select itself is split in two shares, i.e., if L = L0 xor L1, then
       L ? a : b = L1 ? (L0 ? b : a) : (L0 ? a : b).
       Thus, we calculate a select over L0 (the LSB of w7) and over L1 (the LSB of w26).

       P = (w11, w12, w13)
        <= (w0[255] xor w1[255])?P=(w14, w15, w16):2P=(w4, w5, w6) */

    /* init regs with random numbers from URND */
    bn.wsrr   w20, URND
    bn.wsrr   w21, URND
    bn.wsrr   w22, URND

    /* (L0 ? a : b) */
    bn.or     w7, w7, w31
    bn.sel    w20, w14, w4, L
    bn.sel    w21, w15, w5, L
    bn.sel    w22, w16, w6, L

    /* init regs with random numbers from URND */
    bn.wsrr   w23, URND
    bn.wsrr   w24, URND
    bn.wsrr   w25, URND

    /* (L0 ? b : a) */
    bn.sel    w23, w4, w14, L
    bn.sel    w24, w5, w15, L
    bn.sel    w25, w6, w16, L

    /* init regs with random numbers from URND */
    bn.wsrr   w11, URND
    bn.wsrr   w12, URND
    bn.wsrr   w13, URND

    /* wipe the L flag */
    bn.or     w12, w12, w31

    /* L1 ? (L0 ? b : a) : (L0 ? a : b) */
    bn.or     w26, w26, w31
    bn.sel    w11, w23, w20, L
    bn.sel    w12, w24, w21, L
    bn.sel    w13, w25, w22, L

    /* add points
       Q+P = (w11, w12, w13) <= (w11, w12, w13) + (w8, w9, w10) */
    jal       x1, proj_add

    /* probe if MSb of either one or both of the two
       scalars (k0 or k1) is 1.*/

    /* duplicate point P to allow distinct source/destination registers for
       the select instructions below.
       Q = (w20, w21, w22) <= (w8, w9, w10) */
    bn.mov    w20, w8
    bn.mov    w21, w9
    bn.mov    w22, w10

    /* init destination registers with random numbers from URND */
    bn.wsrr   w23, URND
    bn.wsrr   w24, URND
    bn.wsrr   w25, URND

    /* N.B. The select instructions below must use distinct
       source/destination registers and source and destination must not be
       equal for any source and destination pair to avoid revealing L.

       The select is split in two shares, i.e., if L = L0 or L1, then
       L ? a : b = L0 ? a : (L1 ? a : b). Thus, we calculate a select
       over L0 (the LSB of w7) and over L1 (the LSB of w26).

       Select doubling result (Q) or addition result (Q+P)
         Q = w0[255] or w1[255]?Q+P=(w11, w12, w13):Q=(w20, w21, w22) */
    bn.or     w7, w7, w31
    bn.sel    w23, w11, w20, L
    bn.sel    w24, w12, w21, L
    bn.sel    w25, w13, w22, L

    /* init destination registers with random numbers from URND */
    bn.wsrr   w8, URND
    bn.wsrr   w9, URND
    bn.wsrr   w10, URND

    /* wipe the L flag */
    bn.or     w10, w10, w31

    bn.or     w26, w26, w31
    bn.sel    w8, w11, w23, L
    bn.sel    w9, w12, w24, L
    bn.sel    w10, w13, w25, L

    /* Load random to pad the shift and re-randomize the coordinates of Q. */
    bn.wsrr   w7, URND

    /* Shift k0 left 1 bit.

     N.B. This has been intentionally separated from accesses to [w2,w3] below
     to avoid potential transient side channel leakage from accessing k0 and k1
     in sequential instructions. */
    bn.rshi   w1, w1, w0 >> 255
    bn.rshi   w0, w0, w7 >> 255

    /* w4 = w4 * w7 */
    bn.mov    w24, w4
    bn.mov    w25, w7
    jal       x1, mul_modp
    bn.mov    w4, w19

    /* w5 = w5 * w7 */
    bn.mov    w24, w5
    bn.mov    w25, w7
    jal       x1, mul_modp
    bn.mov    w5, w19

    /* w6 = w6 * w7 */
    bn.mov    w24, w6
    bn.mov    w25, w7
    jal       x1, mul_modp
    bn.mov    w6, w19

    /* Shift k1 left 1 bit. */
    bn.rshi   w3, w3, w2 >> 255
    bn.rshi   w2, w2, w7 >> 255

  /* Check if the z-coordinate of Q is 0. If so, fail; this represents the
     point at infinity and means the scalar was zero mod n, which likely
     indicates a fault attack. Tail-call.

     FG0.Z <= if (w10 == 0) then 1 else 0 */
  bn.cmp    w10, w31
  jal       x0, trigger_fault_if_fg0_z


/**
 * secp256k1 scalar multiplication with base point G
 *
 * returns R = d*G = d*(x_g, y_g)
 *         with R and G being valid secp256k1 curve points in affine
 *              coordinates, furthermore G being the curves base point,
 *              d being a 256 bit scalar
 *
 * Performs a scalar multiplication of a scalar with the base point G of curve
 * secp256k1.
 *
 * This routine assumes that the scalar d is provided in two shares, d0 and d1,
 * where:
 *   d = (d0 + d1) mod n
 *
 * The shares d0 and d1 are up to 320 bits each to provide extra redundancy.
 *
 * This routine runs in constant time.
 *
 * @param[in]   dmem[d0]:  first share of scalar d (320 bits)
 * @param[in]   dmem[d1]:  second share of scalar d (320 bits)
 * @param[out]  dmem[x]:   affine x-coordinate (256 bits)
 * @param[out]  dmem[y]:   affine y-coordinate (256 bits)
 *
 * Flags: Flags have no meaning beyond the scope of this subroutine.
 *
 * clobbered registers: x2, x3, x16, x17, x19, x20, x21, x22, w0 to w29
 * clobbered flag groups: FG0
 */
secp256k1_base_mult:

  /* init all-zero register */
  bn.xor    w31, w31, w31

  /* Load first share of secret key d from dmem.
       w0,w1 = dmem[d0] */
  la        x16, d0
  li        x2, 0
  bn.lid    x2, 0(x16++)
  li        x2, 1
  bn.lid    x2, 0(x16)

  /* Load second share of secret key d from dmem.
       w2,w3 = dmem[d1] */
  la        x16, d1
  li        x2, 2
  bn.lid    x2, 0(x16++)
  li        x2, 3
  bn.lid    x2, 0(x16)

  /* call internal scalar multiplication routine
     R = (x_p, y_p, z_p) = (w8, w9, w10) <= d*P = (w0 + w1)*P */
  la        x21, secp256k1_gx
  la        x22, secp256k1_gy
  jal       x1, scalar_mult_int

  /* Convert masked result back to affine coordinates.
     R = (x_a, y_a) = (w11, w12) */
  jal       x1, proj_to_affine

  /* store result (affine coordinates) in dmem
     dmem[x] <= x_a = w11
     dmem[y] <= y_a = w12 */
  li        x2, 11
  la        x21, x
  bn.sid    x2++, 0(x21)
  la        x22, y
  bn.sid    x2, 0(x22)

  /* Compute both sides of the Weierstrass equation.
       w18 <= (x^3 + b) mod p
       w19 <= (y^2) mod p */
  jal      x1, secp256k1_isoncurve

  /* Compare the two sides of the equation to check if the result
     is a valid point as an FI countermeasure.
     The check fails if both sides are not equal.
     FG0.Z <= (y^2) mod p == (x^3 + b) mod p */
  bn.cmp   w18, w19
  jal      x1, trigger_fault_if_not_fg0_z

  ret


/**
 * Generate a nonzero random value in the scalar field.
 *
 * Returns t, a random value that is nonzero mod n, in shares.
 *
 * This follows a modified version of the method in FIPS 186-4 sections B.4.1
 * and B.5.1 for generation of secret scalar values d and k. The computation
 * in FIPS 186-4 is:
 *   seed = RBG(seedlen) // seedlen >= 320
 *   return (seed mod (n-1)) + 1
 *
 * The important features here are that (a) the seed is at least 64 bits longer
 * than n in order to minimize bias after the reduction and (b) the resulting
 * scalar is guaranteed to be nonzero.
 *
 * We deviate from FIPS a little bit here because for side-channel protection,
 * we do not want to fully reduce the seed modulo (n-1) or combine the shares.
 * Instead, we do the following:
 *   seed0 = RBG(320)
 *   seed1 = RBG(320)
 *   x = URND(127) + 1 // random value for masking
 *   if (seed0 * x + seed1 * x) mod n == 0:
 *     retry
 *   return seed0, seed1
 *
 * Essentially, we get two independent seeds and interpret these as additive
 * shares of the scalar t = (seed0 + seed1) mod n. Then, we need to ensure t is
 * nonzero. Multiplying each share with a random masking parameter allows us to
 * safely add them, and then check if this result is 0; if it is, then t must
 * be 0 mod n and we need to retry.
 *
 * Flags: Flags have no meaning beyond the scope of this subroutine.
 *
 * @param[in]  w31:  all-zero
 * @param[out] w15,w16:  first share of secret scalar t (320 bits)
 * @param[out] w17,w18:  second share of secret scalar t (320 bits)
 *
 * clobbered registers: x2, x3, x20, w12 to w29
 * clobbered flag groups: FG0
 */
secp256k1_random_scalar:
  /* Load the curve order n.
     w29 <= dmem[secp256k1_n] = n */
  li        x2, 29
  la        x3, secp256k1_n
  bn.lid    x2, 0(x3)

  /* Copy n into the MOD register. */
  bn.wsrw   MOD, w29

  /* Load Barrett constant for n.
     w28 <= u_n = dmem[secp256k1_u_n]  */
  li        x2, 28
  la        x3, secp256k1_u_n
  bn.lid    x2, 0(x3)

  random_scalar_retry:
  /* Obtain 768 bits of randomness from RND. */
  bn.wsrr   w15, RND
  bn.wsrr   w16, RND
  bn.wsrr   w17, RND

  /* XOR with bits from URND, just in case there's any vulnerability in EDN
     that lets the attacker recover bits before they reach ACC. */
  bn.wsrr   w20, URND
  bn.xor    w15, w15, w20
  bn.wsrr   w20, URND
  bn.xor    w16, w16, w20
  bn.wsrr   w20, URND
  bn.xor    w17, w17, w20

  /* Shift bits to get 320-bit seeds.
     w18 <= w16[255:192]
     w16 <= w16[63:0] */
  bn.rshi   w18, w31, w16 >> 192
  bn.rshi   w20, w16, w31 >> 64
  bn.rshi   w16, w31, w20 >> 192

  /* Generate a random masking parameter.
     w14 <= URND(127) + 1 = x */
  bn.wsrr   w14, URND
  bn.addi   w14, w14, 1
  bn.addi   w31, w31, 0  /* dummy instruction to clear flags */

  /* w12 <= ([w15,w16] * w14) mod n = (seed0 * x) mod n */
  bn.mov    w24, w15
  bn.mov    w25, w16
  bn.mov    w26, w14
  jal       x1, mod_mul_320x128
  bn.mov    w12, w19

  /* w13 <= ([w17,w18] * w14) mod n = (seed1 * x) mod n */
  bn.mov    w24, w17
  bn.mov    w25, w18
  bn.mov    w26, w14
  jal       x1, mod_mul_320x128
  bn.mov    w13, w19

  /* w12 <= (w12 + w13) mod n = ((seed0 + seed1) * x) mod n */
  bn.addm   w12, w12, w13

  /* Compare to 0.
     FG0.Z <= (w12 =? w31) = ((seed0 + seed1) mod n =? 0) */
  bn.cmp    w12, w31

  /* Read the FG0.Z flag (position 3).
     x2 <= 8 if FG0.Z else 0 */
  csrrw     x2, FG0, x0
  andi      x2, x2, 8

  /* Retry if x2 != 0. */
  bne       x2, x0, random_scalar_retry

  /* If we get here, then (seed0 + seed1) mod n is nonzero mod n; return. */

  ret

/**
 * Generate the secret key d from a random seed.
 *
 * Flags: Flags have no meaning beyond the scope of this subroutine.
 *
 * @param[out]  dmem[d0]:  first share of private key d
 * @param[out]  dmem[d1]:  second share of private key d
 *
 * clobbered registers: x2, x3, x20, w20, w21, w29
 * clobbered flag groups: FG0
 */
secp256k1_generate_random_key:
  /* Init all-zero register. */
  bn.xor    w31, w31, w31

  /* Generate a random scalar in two 320-bit shares.
       w15, w16 <= d0
       w17, w18 <= d1 */
  jal  x1, secp256k1_random_scalar

  /* Write first share to DMEM.
       dmem[d0] <= w15, w16 = d0 */
  la        x20, d0
  li        x2, 15
  bn.sid    x2, 0(x20++)
  li        x2, 16
  bn.sid    x2, 0(x20)

  /* Write second share to DMEM.
       dmem[d1] <= w17, w18 = d1 */
  la        x20, d1
  li        x2, 17
  bn.sid    x2, 0(x20++)
  li        x2, 18
  bn.sid    x2, 0(x20)

  ret

/**
 * Generate the secret scalar k from a random seed.
 *
 * Flags: Flags have no meaning beyond the scope of this subroutine.
 *
 * @param[out]  dmem[k0]:  first share of secret scalar k
 * @param[out]  dmem[k1]:  second share of secret scalar k
 *
 * clobbered registers: x2, x3, x20, w20, w21, w29
 * clobbered flag groups: FG0
 */
secp256k1_generate_k:
  /* Init all-zero register. */
  bn.xor    w31, w31, w31

  /* Generate a random scalar in two 320-bit shares.
       w15, w16 <= k0
       w17, w18 <= k1 */
  jal  x1, secp256k1_random_scalar

  /* Write first share to DMEM.
       dmem[k0] <= w15, w16 = k0 */
  la        x20, k0
  li        x2, 15
  bn.sid    x2, 0(x20++)
  li        x2, 16
  bn.sid    x2, 0(x20)

  /* Write second share to DMEM.
       dmem[k1] <= w17, w18 = k1 */
  la        x20, k1
  li        x2, 17
  bn.sid    x2, 0(x20++)
  li        x2, 18
  bn.sid    x2, 0(x20)

  ret

/**
 * Convert boolean shares to arithmetic ones using Goubin's algorithm.
 *
 * Returns x0, x1 such that (s0 ^ s1) = (x0 + x1) mod 2^321.
 *
 * The input consists of two 320-bit shares, s0 and s1. Bits at position 320
 * and above in the input shares will be ignored. We compute the result mod
 * 2^321 so that the high bit of x0 will reveal the carry modulo 2^320.
 *
 * We then use Goubin's boolean-to-arithmetic masking algorithm to switch from
 * this boolean masking scheme to an arithmetic one without ever unmasking the
 * seed. See Algorithm 1 here:
 * https://link.springer.com/content/pdf/10.1007/3-540-44709-1_2.pdf
 *
 * The algorithm is reproduced here for reference:
 *   Input:
 *     s0, s1: k-bit shares such that x = s0 ^ s1
 *     gamma: random k-bit number
 *   Output: x0, k-bit number such that x = (x0 + s1) mod 2^k
 *   Pseudocode:
 *     T := ((s0 ^ gamma) - gamma) mod 2^k
 *     T2 := T ^ s0
 *     G := gamma ^ s1
 *     A := ((s0 ^ G) - G) mod 2^k
 *     return x0 := (A ^ T2)
 *
 * The output x1 is always (s1 mod 2^320).
 *
 * This routine runs in constant time.
 *
 * We are aware that MSB of the intermediate values here may leak 1-bit of
 * secret seed. We observed this with formal masking analysis tool and FPGA
 * experiments. The algorithm runs with 64-bit excess randomness, so we don't
 * expect that to be possible to use that leakage and retrieve secret values.
 * We also verified that the leakage disappeared after running the routine on
 * 320-bit instead of 321-bit.
 *
 * Flags: Flags have no meaning beyond the scope of this subroutine.
 *
 * @param[in]  [w21, w20]: s0, first share of seed (320 bits)
 * @param[in]  [w11, w10]: s1, second share of seed (320 bits)
 * @param[in]         w31: all-zero
 * @param[out] [w21, w20]: result x0 (321 bits)
 * @param[out] [w11, w10]: result x1 (320 bits)
 *
 * clobbered registers: w1 to w5, w20 to w23
 * clobbered flag groups: FG0
 */
boolean_to_arithmetic:
  /* Mask out excess bits from seed shares.
       [w21, w20] <= s0 mod 2^320
       [w11, w10] <= s1 mod 2^320 = x1 */
  bn.rshi   w21, w21, w31 >> 64
  bn.rshi   w21, w31, w21 >> 192
  bn.rshi   w31, w31, w31 >> 192  /* dummy instruction to flush ALU datapath */
  bn.rshi   w11, w11, w31 >> 64
  bn.rshi   w11, w31, w11 >> 192

  /* Fetch 321 bits of randomness from URND.
       [w2, w1] <= gamma */
  bn.wsrr   w1, URND
  bn.wsrr   w2, URND
  bn.rshi   w2, w31, w2 >> 191

  /* [w4, w3] <= [w21, w20] ^ [w2, w1] = s0 ^ gamma */
  bn.xor    w3, w20, w1
  bn.xor    w4, w21, w2

  /* Subtract gamma. This may result in bits above 2^321, but these will be
     stripped off in the next step.
       [w4, w3] <= [w4, w3] - [w2, w1] = ((s0 ^ gamma) - gamma) mod 2^512 */
  bn.sub    w3, w3, w1
  bn.subb   w4, w4, w2
  bn.sub    w31, w31, w31  /* dummy instruction to clear flags */

  /* Truncate subtraction result to 321 bits.
       [w4, w3] <= [w4, w3] mod 2^321 = T */
  bn.rshi   w4, w4, w31 >> 65
  bn.rshi   w4, w31, w4 >> 191

  /* [w4, w3] <= [w4, w3] ^ [w21, w20] = T2 */
  bn.xor    w3, w3, w20
  bn.xor    w4, w4, w21

  /* [w2, w1] <= [w2, w1] ^ [w11, w10] = gamma ^ s1 = G */
  bn.xor    w1, w1, w10
  bn.xor    w2, w2, w11

  /* [w21, w20] <= [w21, w20] ^ [w2, w1] = s0 ^ G */
  bn.xor    w20, w20, w1
  bn.xor    w21, w21, w2

  /* [w21, w20] <= [w21, w20] - [w2, w1] = ((s0 ^ G) - G) mod 2^512 */
  bn.sub    w20, w20, w1
  bn.subb   w21, w21, w2
  bn.sub    w31, w31, w31  /* dummy instruction to clear flags */

  /* [w21, w20] <= [w21, w20] mod 2^321 = A */
  bn.rshi   w21, w21, w31 >> 65
  bn.rshi   w21, w31, w21 >> 191

  /* apply fresh mask to w20 and w21 before xoring with w3 and w4 */
  bn.wsrr   w28, RND
  bn.wsrr   w29, RND
  bn.xor    w20, w28, w20
  bn.xor    w21, w29, w21

  /* [w21, w20] <= [w21, w20] ^ [w4, w3] = A ^ T2 = x0 */
  bn.xor    w20, w20, w3
  bn.xor    w21, w21, w4

  /* remove fresh mask */
  bn.xor    w20, w28, w20
  bn.xor    w21, w29, w21
  bn.xor    w31, w31, w31  /* dummy instruction to clear flags */

  ret

/**
 * secp256k1 ECDSA secret key generation.
 *
 * Returns the secret key d in two 320-bit shares d0 and d1, such that:
 *    d = (d0 + d1) mod n
 * ...where n is the curve order.
 *
 * This implementation follows FIPS 186-4 section B.4.1, where we
 * generate d using N+64 random bits (320 bits in this case) as a seed. But
 * while FIPS computes d = (seed mod (n-1)) + 1 to ensure a nonzero key, we
 * instead just compute d = seed mod n. The caller MUST ensure that if this
 * routine is used, then other routines that use d (e.g. signing, public key
 * generation) are checking if d is 0.
 *
 * Most complexity in this routine comes from masking. The input seed is
 * provided in two 320-bit shares, seed0 and seed1, such that:
 *   seed = seed0 ^ seed1
 * Bits at position 320 and above in the input shares will be ignored.
 *
 * We then use Goubin's boolean-to-arithmetic masking algorithm to switch from
 * this boolean masking scheme to an arithmetic one without ever unmasking the
 * seed. See Algorithm 1 here:
 * https://link.springer.com/content/pdf/10.1007/3-540-44709-1_2.pdf
 *
 * For a Coq proof of the correctness of the basic computational logic here
 * see:
 *   https://gist.github.com/jadephilipoom/24f44c59cbe59327e2f753867564fa28#file-masked_reduce-v-L226
 *
 * The proof does not cover leakage properties; it mostly just shows that this
 * logic correctly computes (seed mod n) and the carry-handling works.
 *
 * This routine runs in constant time.
 *
 * Flags: Flags have no meaning beyond the scope of this subroutine.
 *
 * @param[in]  [w21, w20]: seed0, first share of seed (320 bits)
 * @param[in]  [w11, w10]: seed1, second share of seed (320 bits)
 * @param[in]         w31: all-zero
 * @param[out] [w21, w20]: d0, first share of private key d (320 bits)
 * @param[out] [w11, w10]: d1, second share of private key d (320 bits)
 *
 * clobbered registers: x2, x3, w1 to w4, w20 to w29
 * clobbered flag groups: FG0
 */
secp256k1_key_from_seed:
  /* Convert from a boolean to an arithmetic mask using Goubin's algorithm.
       [w21, w20] <= ((seed0 ^ seed1) - seed1) mod 2^321 = x0 */
  jal       x1, boolean_to_arithmetic

  /* At this point, we have arithmetic shares modulo 2^321:
       [w21, w20] : x0
       [w11, w10] : x1

     We know that x1=seed1, and seed and x1 are at most 320 bits. Therefore,
     the highest bit of x0 holds a carry bit modulo 2^320:
       x0 = (seed - x1) mod 2^321
       x0 = (seed - x1) mod 2^320 + (if (x1 <= seed) then 0 else 2^320)

     The carry bit then allows us to replace (mod 2^321) with a conditional
     statement:
       seed = (x0 mod 2^320) + x1 - (x0[320] << 320)

     Note that the carry bit is not very sensitive from a side channel
     perspective; x1 <= seed has some bias related to the highest bit of the
     seed, but since the seed is 64 bits larger than n, this single-bit noisy
     leakage should not be significant.

     From here, we want to convert to shares modulo (n * 2^64) -- these shares
     will be equivalent to the seed modulo n but still retain 64 bits of extra
     masking. We compute the new shares as follows:
       c = (x0[320] << 320) mod (n << 64)
       d0 = ((x0 mod 2^320) - c) mod (n << 64))
       d1 = x1 mod (n << 64)

       d = seed mod n = (d0 + d1) mod n
  */

  /* Load curve order n from DMEM.
       w29 <= dmem[secp256k1_n] = n */
  li        x2, 29
  la        x3, secp256k1_n
  bn.lid    x2, 0(x3)

  /* Compute (n << 64).
       [w29,w28] <= w29 << 64 = n << 64 */
  bn.rshi   w28, w29, w31 >> 192
  bn.rshi   w29, w31, w29 >> 192

  /* [w25,w24] <= (x1 - (n << 64)) mod 2^512 */
  bn.sub    w24, w10, w28
  bn.subb   w25, w11, w29

  /* Compute d1. Because 2^320 < 2 * (n << 64), a conditional subtraction is
     sufficient to reduce. Similarly to the carry bit, the conditional bit here
     is not very sensitive because the shares are large relative to n.

     N.B. Even though the conditional bit isn't sensitive here, other flags set
     by the above subtraction (i.e. the LSB flag) may be; the dummy instruction
     below serves both to clear these flags as well as to separate instructions
     accessing w11 and w21 respectively, as these form the upper words of a
     pair of secret shares.

       [w11,w10] <= x1 mod (n << 64) = d1 */
  bn.sel    w10, w10, w24, FG0.C
  bn.sel    w11, w11, w25, FG0.C
  bn.sub    w23, w23, w23  /* dummy instruction to clear flags */

  /* Isolate the carry bit and shift it back into position.
       w25 <= x0[320] << 64 */
  bn.rshi   w25, w31, w21 >> 64
  bn.rshi   w25, w25, w31 >> 192

  /* Clear the carry bit from the original result.
       [w21,w20] <= x0 mod 2^320 */
  bn.xor    w21, w21, w25

  /* Conditionally subtract (n << 64) to reduce.
       [w21,w20] <= (x0 mod 2^320) mod (n << 64) */
  bn.sub    w26, w20, w28
  bn.subb   w27, w21, w29
  bn.sel    w20, w20, w26, FG0.C
  bn.sel    w21, w21, w27, FG0.C

  /* Compute the correction factor.
       [w25,w24] <= (x[320] << 320) mod (n << 64) = c */
  bn.sub    w26, w31, w28
  bn.subb   w27, w25, w29
  bn.sel    w24, w31, w26, FG0.C
  bn.sel    w25, w25, w27, FG0.C

  /* Compute d0 with a modular subtraction. First we add (n << 64) to protect
     against underflow, then conditionally subtract it again if needed.

     N.B. we also insert a dummy instruction at the end of this routine, as
     the flags set will reveal information regarding the partial share in w21
     in the case that the final conditional subtraction is performed.

       [w21,w20] <= ([w21, w20] - [w25,w24]) mod (n << 64) = d0 */
  bn.add    w20, w20, w28
  bn.addc   w21, w21, w29
  bn.sub    w20, w20, w24
  bn.subb   w21, w21, w25
  bn.sub    w26, w20, w28
  bn.subb   w27, w21, w29
  bn.sel    w20, w20, w26, FG0.C
  bn.sel    w21, w21, w27, FG0.C
  bn.sub    w23, w23, w23  /* dummy instruction to clear flags */

  ret

/**
 * Helper routine to remask a scalar in-place.
 *
 * @param[in]     x12: d0, pointer to share 0 of 320-bit masked scalar.
 * @param[in]     x13: d1, pointer to share 1 of 320-bit masked scalar.
 * @param[in,out] dmem[d0..d0+64]: share 0 of 320-bit masked scalar.
 * @param[in,out] dmem[d1..d1+64]: share 1 of 320-bit masked scalar.
 *
 * clobbered registers: x3-x4, x10-x11, w1-w11, w31
 * clobbered flag groups: none
 */
secp256k1_scalar_remask:
  /* Initialize all-zero register. */
  bn.xor    w31, w31, w31

  /* Get a fresh 320-bit mask m from URND.
       [w8,w9] = URND() */
  bn.wsrr   w8, URND
  bn.wsrr   w9, URND
  bn.rshi   w9, w31, w9 >> 192

  /* Load curve order n from DMEM.
       w11 <= dmem[secp256k1_n] = n */
  la        x10, secp256k1_n
  li        x11, 11
  bn.lid    x11, 0(x10)

  /* Compute (n << 64).
       [w10,w11] <= w11 << 64 = n << 64 */
  bn.rshi   w10, w11, w31 >> 192
  bn.rshi   w11, w31, w11 >> 192

  /* Reduce m modulo (n << 64) with a conditional subtraction.
       [w4,w5] <= m mod (n << 64) */
  bn.sub    w6, w8, w10
  bn.subb   w7, w9, w11
  bn.sel    w4, w8, w6, FG0.C
  bn.sel    w5, w9, w7, FG0.C
  bn.sub    w1, w1, w1  /* dummy instruction to clear flags */

  /* Randomize registers before loading secret share. */
  bn.wsrr   w2, URND
  bn.wsrr   w3, URND
  bn.wsrr   w6, URND
  bn.wsrr   w7, URND
  bn.wsrr   w8, URND
  bn.wsrr   w9, URND

  /* [w6,w7] <= dmem[d0] */
  li       x3, 6
  bn.lid   x3++, 0(x12)
  bn.lid   x3, 32(x12)

  /* [w8,w9] <= d0 + m */
  bn.add    w8, w6, w4
  bn.addc   w9, w7, w5
  bn.sub    w1, w1, w1  /* dummy instruction to clear flags */

  /* [w2,w3] <= (d0 + m) mod (n << 64). */
  bn.sub    w6, w8, w10
  bn.subb   w7, w9, w11
  bn.sel    w2, w8, w6, FG0.C
  bn.sel    w3, w9, w7, FG0.C
  bn.sub    w1, w1, w1  /* dummy instruction to clear flags */

  /* dmem[d0] <= [w2,w3] */
  li       x3, 2
  bn.sid   x3++, 0(x12)
  bn.sid   x3, 32(x12)

  /* Randomize registers before loading secret share. */
  bn.wsrr   w2, URND
  bn.wsrr   w3, URND
  bn.wsrr   w6, URND
  bn.wsrr   w7, URND
  bn.wsrr   w8, URND
  bn.wsrr   w9, URND

  /* [w6,w7] <= dmem[d1] */
  li       x3, 6
  bn.lid   x3++, 0(x13)
  bn.lid   x3, 32(x13)

  /* [w8,w9] <= d1 - m */
  bn.sub    w8, w6, w4
  bn.subb   w9, w7, w5

  /* [w2,w3] <= (d1 - m) mod (n << 64). */
  bn.add    w6, w8, w10, FG1
  bn.addc   w7, w9, w11, FG1
  bn.sel    w2, w6, w8, FG0.C
  bn.sel    w3, w7, w9, FG0.C
  bn.sub    w1, w1, w1  /* dummy instruction to clear flags */
  bn.sub    w1, w1, w1, FG1  /* dummy instruction to clear flags */

  /* dmem[d1] <= [w2,w3] */
  li       x3, 2
  bn.sid   x3++, 0(x13)
  bn.sid   x3, 32(x13)

  ret


.section .data

/* The secp256k1 domain parameter b = 7 is not stored in DMEM; the code
   materializes it (and multiples of it) with immediates or constant time
   addition chains. Only b3 = 3*b is provided for routines that want to load
   it into a register. */

/* secp256k1 constant b3 = 3*b = 21 (used by the complete a=0 formulas) */
.globl secp256k1_b3
.balign 32
secp256k1_b3:
  .word 0x00000015
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000

/* secp256k1 domain parameter p (modulus) */
.globl secp256k1_p
.balign 32
secp256k1_p:
  .word 0xfffffc2f
  .word 0xfffffffe
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff

/* secp256k1 domain parameter n (order of base point) */
.globl secp256k1_n
.balign 32
secp256k1_n:
  .word 0xd0364141
  .word 0xbfd25e8c
  .word 0xaf48a03b
  .word 0xbaaedce6
  .word 0xfffffffe
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff

/* Barrett constant u for n: u = floor(2^512/n) - 2^256 */
.globl secp256k1_u_n
.balign 32
secp256k1_u_n:
  .word 0x2fc9bec0
  .word 0x402da173
  .word 0x50b75fc4
  .word 0x45512319
  .word 0x00000001
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000

/* secp256k1 basepoint G affine x-coordinate */
.globl secp256k1_gx
.balign 32
secp256k1_gx:
  .word 0x16f81798
  .word 0x59f2815b
  .word 0x2dce28d9
  .word 0x029bfcdb
  .word 0xce870b07
  .word 0x55a06295
  .word 0xf9dcbbac
  .word 0x79be667e

/* secp256k1 basepoint G affine y-coordinate */
.globl secp256k1_gy
.balign 32
secp256k1_gy:
  .word 0xfb10d4b8
  .word 0x9c47d08f
  .word 0xa6855419
  .word 0xfd17b448
  .word 0x0e1108a8
  .word 0x5da4fbfc
  .word 0x26a3c465
  .word 0x483ada77

.section .bss

/* random scalar k (in two 320b shares) */
.balign 32
.weak k0
k0:
  .zero 64
.balign 32
.weak k1
k1:
  .zero 64

/* message digest */
.balign 32
.weak msg
msg:
  .zero 32

/* signature R */
.balign 32
.weak r
r:
  .zero 32

/* signature S */
.balign 32
.weak s
s:
  .zero 32

/* public key x-coordinate */
.balign 32
.weak x
x:
  .zero 32

/* public key y-coordinate */
.balign 32
.weak y
y:
  .zero 32

/* private key d (in two 320b shares) */
.balign 32
.weak d0
d0:
  .zero 64
.balign 32
.weak d1
d1:
  .zero 64

/* verification result x_r (aka x_1) */
.balign 32
.weak x_r
x_r:
  .zero 32
