/* Copyright lowRISC contributors (OpenTitan project). */
/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/* Public interface. */
.globl modinv

/**
 * Compute the inverse of a given value modulo a given number.
 *
 * Returns d such that (d*a) = 1 mod m and 0 <= d < m.
 *
 * Requires that m is nonzero, and that GCD(a, m) = 1.
 *
 * This is a specialized version of binary extended GCD, as described in HAC
 * Algorithm 14.61 and implemented in constant time in BoringSSL here:
 *   https://boringssl.googlesource.com/boringssl/+/dcabfe2d8940529a69e007660fa7bf6c15954ecc/crypto/fipsmodule/bn/gcd_extra.c#170
 *
 * BoringSSL's version includes a few improvements beyond being constant-time,
 * such as avoiding signed integers. This modified algorithm has also been
 * proven mathematically correct in Coq, see:
 *   https://github.com/mit-plv/fiat-crypto/pull/333
 *
 * In pseudocode,the BoringSSL algorithm is:
 *   A, B, C, D = 1, 0, 0, 1
 *   u = x
 *   v = y
 *   // Loop invariants:
 *   //   A*x - B*y = u
 *   //   D*y - C*x = v
 *   //   gcd(u, v) = gcd(x, y)
 *   //   bitlen(u) + bitlen(v) <= i
 *   //   0 < u <= x
 *   //   0 <= v <= y
 *   //   0 <= A, C < y
 *   //   0 <= B, D <= x
 *   for i=bitlen(x) + bitlen(y)..1:
 *     if u and v both odd:
 *       if v < u:
 *         u = u - v
 *         A = (A + C) mod y
 *         B = (B + D) mod x
 *       else:
 *         v = v - u
 *         C = (A + C) mod y
 *         D = (B + D) mod x
 *     // At this point, the invariant holds and >= 1 of u and v is even
 *     if u is even:
 *       u >>= 1
 *       if (A[0] | B[0]):
 *         A = (A + y) / 2
 *         B = (B + x) / 2
 *       else:
 *         A >>= 1
 *         B >>= 1
 *     if v is even:
 *       v >>= 1
 *       if (C[0] | D[0]):
 *         C = (C + x) / 2
 *         D = (D + y) / 2
 *       else:
 *         C >>= 1
 *         D >>= 1
 *    // End of loop. Guarantees the invariant plus u = gcd(x,y).
 *
 * As described in HAC note 14.64, this algorithm computes a modular inverse
 * when gcd(x,y) = 1. Specifically, at termination, A = x^-1 mod y because:
 *   (A*x) mod y = (A*x - B*y) mod y = u mod y = 1
 *
 * Of course, all the if statements are implemented with constant-time selects.
 *
 * The fully specialized and constant-time version of the pseudocode is:
 *
 * The fully specialized and constant-time version of the pseudocode is:
 *   A, C = 1, 0
 *   u = a
 *   v = m
 *   // Loop invariants:
 *   //   A*x - B*y = u
 *   //   D*y - C*x = v
 *   //   gcd(u, v) = gcd(x, y)
 *   //   bitlen(u) + bitlen(v) <= i
 *   //   gcd(u, v) = 1
 *   //   bitlen(u) + bitlen(v) <= i
 *   //   0 < u <= a
 *   //   0 <= v <= m
 *   //   0 <= A, C < m
 *   //   0 <= B, D < a
 *   for i=(bitlen(a) + bitlen(m))..1:
 *     both_odd = u[0] & v[0]
 *     v_lt_u = v < u
 *     u = u - ((both_odd && v_lt_u) ? v : 0)
 *     v = v - ((both_odd && !v_lt_u) ? u : 0)
 *     ac = (A + C) mod m
 *     A = (both_odd && v_lt_u) ? ac : A
 *     C = (both_odd && !v_lt_u) ? ac : C
 *     bd = (B + D) mod a
 *     B = (both_odd && v_lt_u) ? bd : B
 *     D = (both_odd && !v_lt_u) ? bd : D
 *     u_even = !u[0]
 *     a_or_b_odd = A[0] | B[0]
 *     u = u_even ? u >> 1 : u
 *     A = (u_even && a_or_b_odd) ? (A + m) : A
 *     A = u_even ? (A >> 1) : A
 *     B = (u_even && a_or_b_odd) ? (B + a) : B
 *     B = u_even ? (B >> 1) : B
 *     v_even = !v[0]
 *     c_or_d_odd = C[0] | D[0]
 *     v = v_even ? v >> 1 : v
 *     C = (v_even && c_or_d_odd) ? (C + m) : C
 *     C = v_even ? (C >> 1) : C
 *     D = (u_even && c_or_d_odd) ? (D + a) : D
 *     D = u_even ? (D >> 1) : D
 *   if u != 1:
 *     FAIL("Not invertible")
 *   return A
 *
 * This routine runs in constant time.
 *
 * Flags: Flags have no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x11: dptr_a, pointer to argument a in DMEM (n limbs)
 * @param[in]  x12: dptr_m, pointer to modulus m in DMEM (n limbs)
 * @param[in]  x13: dptr_A, pointer to result buffer in DMEM (n limbs)
 * @param[in]  x14: dptr_B, pointer to a temporary buffer in DMEM (n limbs)
 * @param[in]  x15: dptr_C, pointer to a temporary buffer in DMEM (n limbs)
 * @param[in]  x16: dptr_D, pointer to a temporary buffer in DMEM (n limbs)
 * @param[in]  x17: dptr_u, pointer to a temporary buffer in DMEM (n limbs)
 * @param[in]  x18: dptr_v, pointer to a temporary buffer in DMEM (n limbs)
 * @param[in]  x20: 20, constant
 * @param[in]  x21: 21, constant
 * @param[in]  x30: plen, number of 256-bit limbs for modulus m and result d
 * @param[in]  w31: all-zero
 * @param[out] dmem[dptr_A..dptr_A+(plen*32)]: result, modular inverse d
 *
 * clobbered registers: x2 to x6, x31, w20 to w26
 * clobbered flag groups: FG0, FG1
 */
modinv:
  /* Zero the intermediate buffers.
       dmem[dptr_A..dptr_A+(plen*32)] <= 0
       dmem[dptr_B..dptr_B+(plen*32)] <= 0
       dmem[dptr_C..dptr_C+(plen*32)] <= 0
       dmem[dptr_D..dptr_D+(plen*32)] <= 0 */
  li       x2, 31
  addi     x3, x13, 0
  addi     x4, x14, 0
  addi     x5, x15, 0
  addi     x6, x16, 0
  loop     x30, 4
    bn.sid   x2, 0(x3++)
    bn.sid   x2, 0(x4++)
    bn.sid   x2, 0(x5++)
    bn.sid   x2, 0(x6++)

  /* Set the lowest limb of A to 1.
       dmem[dptr_A] <= 1 */
  bn.addi  w20, w31, 1
  bn.sid   x20, 0(x13)

  /* Set the lowest limb of D to 1.
       dmem[dptr_D] <= 1 */
  bn.addi  w20, w31, 1
  bn.sid   x20, 0(x16)

  /* Copy the argument to the buffer for u.
       dmem[dptr_u..dptr_u+(plen*32)] <= a */
  addi     x3, x11, 0
  addi     x4, x17, 0
  loop     x30, 2
    bn.lid   x20, 0(x3++)
    bn.sid   x20, 0(x4++)

  /* Copy the modulus to the buffer for v.
       dmem[dptr_v..dptr_v+(plen*32)] <= m */
  addi     x3, x12, 0
  addi     x4, x18, 0
  loop     x30, 2
    bn.lid   x20, 0(x3++)
    bn.sid   x20, 0(x4++)

  /* Calculate number of loop iterations = bitlen(m) + bitlen(a).
       x31 <= (x30 << 8) + (x30 << 8) = (x30 << 9) = 512*n */
  slli     x31, x30, 9

  /* Main loop. */
  loop     x31, 187
    /* Load the least significant limb of u.
         w20 <= dmem[dptr_u] = u[255:0] */
    bn.lid   x20, 0(x17)

    /* Load the least significant limb of v.
         w21 <= dmem[dptr_v] = v[255:0] */
    bn.lid   x21, 0(x18)

    /* Construct a flag that is 1 if both u and v are odd.
         FG1.L <= (w20 & w21)[0] = u[0] && v[0] */
    bn.and   w22, w21, w20, FG1

    /* Compare u and v.
         FG0.C <= v < u */
    addi       x2, x17, 0
    addi       x3, x18, 0
    loop       x30, 3
      /* w20 <= u[i] */
      bn.lid   x20, 0(x2++)
      /* w21 <= v[i] */
      bn.lid   x21, 0(x3++)
      /* FG0.C <= v[i] <? u[i] + FG0.C */
      bn.cmpb  w21, w20

    /* Capture FG0.C in a mask.
         w23 <= FG0.C ? 2^256 - 1 : 0 */
    bn.subb  w23, w31, w31

    /* Select a mask that is all 1s if we should subtract v from u.
         w24 <= FG1.L ? w23 : w31 = (u[0] && v[0] && v < u) ? 2^256 - 1 : 0 */
    bn.sel   w24, w23, w31, FG1.L

    /* Select a mask that is all 1s if we should subtract u from v.
         w25 <= FG1.L ? !w23 : w31 = (u[0] && v[0] && u <= v) ? 2^256 - 1 : 0 */
    bn.not   w23, w23
    bn.sel   w25, w23, w31, FG1.L

    /* Clear flags for group 0. */
    bn.sub   w31, w31, w31

    /* Conditionally subtract v from u.
         dmem[dptr_u..dptr_u+(plen*32)] <= dmem[dptr_u] - (dmem[dptr_v] & w24) */
    addi     x2, x17, 0
    addi     x3, x18, 0
    loop     x30, 5
      /* w20 <= u[i] */
      bn.lid   x20, 0(x2)
      /* w21 <= v[i] */
      bn.lid   x21, 0(x3++)
      /* w21 <= v[i] & w24 */
      bn.and   w21, w21, w24
      /* w20, FG0.C <= u[i] - (v[i] & w24) - FG0.C */
      bn.subb  w20, w20, w21
      /* u[i] <= w20 */
      bn.sid   x20, 0(x2++)

    /* Conditionally subtract u from v.
         dmem[dptr_v..dptr_v+(plen*32)] <= dmem[dptr_v] - (dmem[dptr_u] & w25) */
    addi     x2, x17, 0
    addi     x3, x18, 0
    loop     x30, 5
      /* w20 <= u[i] */
      bn.lid   x20, 0(x2++)
      /* w21 <= v[i] */
      bn.lid   x21, 0(x3)
      /* w20 <= u[i] & w25 */
      bn.and   w20, w20, w25
      /* w21, FG0.C <= v[i] - (u[i] & w25) - FG0.C */
      bn.subb  w21, w21, w20
      /* u[i] <= w21 */
      bn.sid   x21, 0(x3++)

    /* Clear flags for both groups. */
    bn.sub   w31, w31, w31, FG0
    bn.sub   w31, w31, w31, FG1

    /* Compare (A + C) to m.
         FG1.C <= A + C < m */
    addi     x2, x12, 0
    addi     x3, x13, 0
    addi     x4, x15, 0
    loop     x30, 5
      /* w20 <= A[i] */
      bn.lid   x20, 0(x3++)
      /* w21 <= C[i] */
      bn.lid   x21, 0(x4++)
      /* w23, FG0.C <= A[i] + C[i] + FG0.C */
      bn.addc  w23, w20, w21
      /* w20 <= m[i] */
      bn.lid   x20, 0(x2++)
      /* FG1.C <= w23 <? m[i] + FG1.C */
      bn.cmpb  w23, w20, FG1

    /* Capture ~FG0.C & FG1.C as a mask that is all 1s if we should subtract
       the modulus.
         w26 <= (~FG0.C & FG1.C) ? 0 : 2^256 - 1 */
    bn.subb  w23, w31, w31, FG0
    bn.subb  w26, w31, w31, FG1
    bn.not   w26, w26
    bn.or    w26, w23, w26

    /* Clear flags for both groups. */
    bn.sub   w31, w31, w31, FG0
    bn.sub   w31, w31, w31, FG1

    /* Update A if we updated u in the previous steps (w24 == 2^256-1). We
       additionally subtract the modulus if *both* w24,w26 == 2^256-1.
         dmem[dptr_A..dptr_A+(plen*32)] <= (w24 == 2^256-1) ? (A + C) mod m : A */
    addi     x2, x12, 0
    addi     x3, x13, 0
    addi     x4, x15, 0
    loop     x30, 9
      /* w20 <= A[i] */
      bn.lid   x20, 0(x3)
      /* w21 <= C[i] */
      bn.lid   x21, 0(x4++)
      /* w21 <= C[i] & w24 */
      bn.and   w21, w21, w24
      /* w20, FG0.C <= w20 + w21 + FG0.C */
      bn.addc  w20, w20, w21
      /* w21 <= m[i] */
      bn.lid   x21, 0(x2++)
      /* w21 <= m[i] & w24 */
      bn.and   w21, w21, w24
      /* w21 <= m[i] & w24 & w26 */
      bn.and   w21, w21, w26
      /* w20, FG1.C <= w20 - w21 - FG1.C  */
      bn.subb  w20, w20, w21, FG1
      /* A[i] <= w20 */
      bn.sid   x20, 0(x3++)

    /* Update C if we updated v in the previous steps (w25 == 2^256-1). We
       additionally subtract the modulus if *both* w25,w26 == 2^256-1.
         dmem[dptr_C..dptr_C+(plen*32)] <= (w25 == 2^256-1) ? (A + C) mod m : C */
    addi     x2, x12, 0
    addi     x3, x13, 0
    addi     x4, x15, 0
    loop     x30, 9
      /* w20 <= C[i] */
      bn.lid   x20, 0(x4)
      /* w21 <= A[i] */
      bn.lid   x21, 0(x3++)
      /* w21 <= A[i] & w25 */
      bn.and   w21, w21, w25
      /* w20, FG0.C <= w20 + w21 + FG0.C */
      bn.addc  w20, w20, w21
      /* w21 <= m[i] */
      bn.lid   x21, 0(x2++)
      /* w21 <= m[i] & w25 */
      bn.and   w21, w21, w25
      /* w21 <= m[i] & w25 & w26 */
      bn.and   w21, w21, w26
      /* w20, FG1.C <= w20 - w21 - FG1.C  */
      bn.subb  w20, w20, w21, FG1
      /* C[i] <= w20 */
      bn.sid   x20, 0(x4++)

    /* Clear flags for both groups. */
    bn.sub   w31, w31, w31, FG0
    bn.sub   w31, w31, w31, FG1

    /* Compare (B + D) to a.
         FG1.C <= B + D < a */
    addi     x2, x11, 0
    addi     x3, x14, 0
    addi     x4, x16, 0
    loop     x30, 5
      /* w20 <= B[i] */
      bn.lid   x20, 0(x3++)
      /* w21 <= D[i] */
      bn.lid   x21, 0(x4++)
      /* w23, FG0.C <= B[i] + D[i] + FG0.C */
      bn.addc  w23, w20, w21
      /* w20 <= a[i] */
      bn.lid   x20, 0(x2++)
      /* FG1.C <= w23 <? m[i] + FG1.C */
      bn.cmpb  w23, w20, FG1

    /* Capture ~FG0.C & FG1.C as a mask that is all 1s if we should subtract
       the modulus.
         w26 <= (~FG0.C & FG1.C) ? 0 : 2^256 - 1 */
    bn.subb  w23, w31, w31, FG0
    bn.subb  w26, w31, w31, FG1
    bn.not   w26, w26
    bn.or    w26, w23, w26

    /* Clear flags for both groups. */
    bn.sub   w31, w31, w31, FG0
    bn.sub   w31, w31, w31, FG1

    /* Update B if we updated u in the previous steps (w24 == 2^256-1). We
       additionally subtract the modulus if *both* w24,w26 == 2^256-1.
         dmem[dptr_B..dptr_B+(plen*32)] <= (w24 == 2^256-1) ? (B + D) mod a : A */
    addi     x2, x11, 0
    addi     x3, x14, 0
    addi     x4, x16, 0
    loop     x30, 9
      /* w20 <= B[i] */
      bn.lid   x20, 0(x3)
      /* w21 <= D[i] */
      bn.lid   x21, 0(x4++)
      /* w21 <= D[i] & w24 */
      bn.and   w21, w21, w24
      /* w20, FG0.C <= w20 + w21 + FG0.C */
      bn.addc  w20, w20, w21
      /* w21 <= a[i] */
      bn.lid   x21, 0(x2++)
      /* w21 <= a[i] & w24 */
      bn.and   w21, w21, w24
      /* w21 <= a[i] & w24 & w26 */
      bn.and   w21, w21, w26
      /* w20, FG1.C <= w20 - w21 - FG1.C  */
      bn.subb  w20, w20, w21, FG1
      /* B[i] <= w20 */
      bn.sid   x20, 0(x3++)

    /* Update D if we updated v in the previous steps (w25 == 2^256-1). We
       additionally subtract the modulus if *both* w25,w26 == 2^256-1.
         dmem[dptr_D..dptr_D+(plen*32)] <= (w25 == 2^256-1) ? (A + C) mod m : C */
    addi     x2, x11, 0
    addi     x3, x14, 0
    addi     x4, x16, 0
    loop     x30, 9
      /* w20 <= D[i] */
      bn.lid   x20, 0(x4)
      /* w21 <= B[i] */
      bn.lid   x21, 0(x3++)
      /* w21 <= B[i] & w25 */
      bn.and   w21, w21, w25
      /* w20, FG0.C <= w20 + w21 + FG0.C */
      bn.addc  w20, w20, w21
      /* w21 <= a[i] */
      bn.lid   x21, 0(x2++)
      /* w21 <= a[i] & w25 */
      bn.and   w21, w21, w25
      /* w21 <= a[i] & w25 & w26 */
      bn.and   w21, w21, w26
      /* w20, FG1.C <= w20 - w21 - FG1.C  */
      bn.subb  w20, w20, w21, FG1
      /* C[i] <= w20 */
      bn.sid   x20, 0(x4++)

    /* Get a flag that is set if u is odd.
         FG1.L <= u[0] */
    bn.lid   x20, 0(x17)
    bn.or    w20, w20, w31, FG1

    /* Shift u to the right 1 if FG1.L is unset.
         dmem[dptr_u..dptr_u+(plen*32)] <= FG1.L ? u : u >> 1 */
    addi     x3, x17, 0
    bn.mov   w23, w31
    jal      x1, bignum_rshift1_if_not_fg1L

    /* Create an all-ones mask.
         w23 <= 2^256 - 1 */
    bn.not   w24, w31

    /* Get a flag that is set if A or B is odd.
         FG0.L <= A[0] | B[0] */
    bn.lid   x20, 0(x13)
    bn.lid   x21, 0(x14)
    bn.or    w20, w20, w21

    /* Select a mask for adding moduli to A and B (should do this if u is even
       and at least one of A and B is odd).
         w23 <= (!FG1.L && FG0.L) ? 2^256 - 1 : 0 */
    bn.sel   w24, w31, w24, FG1.L
    bn.sel   w24, w24, w31, FG0.L

    /* Clear flags for group 0. */
    bn.sub   w31, w31, w31

    /* Conditionally add m to A.
         dmem[dptr_A..dptr_A+(plen*32)] <= (!u[0] && (A[0] | B[0])) ? A + m : A */
    addi     x2, x12, 0
    addi     x3, x13, 0
    loop     x30, 5
      /* w20 <= A[i] */
      bn.lid   x20, 0(x3)
      /* w21 <= m[i] */
      bn.lid   x21, 0(x2++)
      /* w21 <= m[i] & w24 */
      bn.and   w21, w21, w24
      /* w20, FG0.C <= A[i] + (m[i] & w23) + FG0.C */
      bn.addc  w20, w20, w21
      /* A[i] <= w20 */
      bn.sid   x20, 0(x3++)

    /* Capture the final carry bit in a register to use as the MSB for the
       shift. */
    bn.addc  w23, w31, w31

    /* Shift A to the right 1 if FG1.L is unset.
         dmem[dptr_A..dptr_A+(plen*32)] <= FG1.L ? A : A >> 1 */
    addi     x3, x13, 0
    jal      x1, bignum_rshift1_if_not_fg1L

    /* Clear flags for group 0. */
    bn.sub   w31, w31, w31

    /* Conditionally add a to B.
         dmem[dptr_B..dptr_B+(plen*32)] <= (!u[0] && (A[0] | B[0])) ? B + a : B */
    addi     x2, x11, 0
    addi     x3, x14, 0
    loop     x30, 5
      /* w20 <= B[i] */
      bn.lid   x20, 0(x3)
      /* w21 <= a[i] */
      bn.lid   x21, 0(x2++)
      /* w21 <= a[i] & w24 */
      bn.and   w21, w21, w24
      /* w20, FG0.C <= B[i] + (a[i] & w23) + FG0.C */
      bn.addc  w20, w20, w21
      /* B[i] <= w20 */
      bn.sid   x20, 0(x3++)

    /* Capture the final carry bit in a register to use as the MSB for the
       shift. */
    bn.addc  w23, w31, w31

    /* Shift B to the right 1 if FG1.L is unset.
         dmem[dptr_B..dptr_B+(plen*32)] <= FG1.L ? B : B >> 1 */
    addi     x3, x14, 0
    jal      x1, bignum_rshift1_if_not_fg1L

    /* Get a flag that is set if v is odd.
         FG1.L <= v[0] */
    bn.lid   x20, 0(x18)
    bn.or    w20, w20, w31, FG1

    /* Shift v to the right 1 if FG1.L is unset.
         dmem[dptr_v..dptr_v+(plen*32)] <= FG1.L ? v : v >> 1 */
    addi     x3, x18, 0
    bn.mov   w23, w31
    jal      x1, bignum_rshift1_if_not_fg1L

    /* Create an all-ones mask.
         w23 <= 2^256 - 1 */
    bn.not   w24, w31

    /* Get a flag that is set if C or D is odd.
         FG0.L <= C[0] | D[0] */
    bn.lid   x20, 0(x15)
    bn.lid   x21, 0(x16)
    bn.or    w20, w20, w21

    /* Select a mask for adding moduli to C and D (should do this if v is even
       and at least one of C and D is odd).
         w23 <= (!FG1.L && FG0.L) ? 2^256 - 1 : 0 */
    bn.sel   w24, w31, w24, FG1.L
    bn.sel   w24, w24, w31, FG0.L

    /* Clear flags for group 0. */
    bn.sub   w31, w31, w31

    /* Conditionally add m to C.
         dmem[dptr_C..dptr_C+(plen*32)] <= (!v[0] && (C[0] | D[0])) ? C + m : C */
    addi     x2, x12, 0
    addi     x3, x15, 0
    loop     x30, 5
      /* w20 <= C[i] */
      bn.lid   x20, 0(x3)
      /* w21 <= m[i] */
      bn.lid   x21, 0(x2++)
      /* w21 <= m[i] & w24 */
      bn.and   w21, w21, w24
      /* w20, FG0.C <= C[i] + (m[i] & w23) + FG0.C */
      bn.addc  w20, w20, w21
      /* C[i] <= w20 */
      bn.sid   x20, 0(x3++)

    /* Capture the final carry bit in a register to use as the MSB for the
       shift. */
    bn.addc  w23, w31, w31

    /* Shift C to the right 1 if FG1.L is unset.
         dmem[dptr_C..dptr_C+(plen*32)] <= FG1.L ? C : C >> 1 */
    addi     x3, x15, 0
    jal      x1, bignum_rshift1_if_not_fg1L

    /* Clear flags for group 0. */
    bn.sub   w31, w31, w31

    /* Conditionally add a to D.
         dmem[dptr_A..dptr_A+(plen*32)] <= (!u[0] && (A[0] | B[0])) ? A + m : A */
    addi     x2, x11, 0
    addi     x3, x16, 0
    loop     x30, 5
      /* w20 <= A[i] */
      bn.lid   x20, 0(x3)
      /* w21 <= m[i] */
      bn.lid   x21, 0(x2++)
      /* w21 <= m[i] & w24 */
      bn.and   w21, w21, w24
      /* w20, FG0.C <= A[i] + (m[i] & w23) + FG0.C */
      bn.addc  w20, w20, w21
      /* A[i] <= w20 */
      bn.sid   x20, 0(x3++)

    /* Capture the final carry bit in a register to use as the MSB for the
       shift. */
    bn.addc  w23, w31, w31

    /* Shift D to the right 1 if FG1.L is unset.
         dmem[dptr_A..dptr_A+(plen*32)] <= FG1.L ? A : A >> 1 */
    addi     x3, x16, 0
    jal      x1, bignum_rshift1_if_not_fg1L

    /* End of loop; no-op so we don't end on a jump. */
    nop

  /* FG0.Z <= u[0] == 1 */
  bn.addi  w23, w31, 1
  bn.lid   x20, 0(x17++)
  bn.cmp   w20, w23

  /* Get the FG0.Z flag into a register.
       x2 <= CSRs[FG0] & 8 = FG0.Z << 3 */
  csrrs    x2, FG0, x0
  andi     x2, x2, 8

  /* If the flag is unset (x2 == 0) then we already know u != 1; in this
     case GCD(65537, m) != 1 and the modular inverse cannot be computed. This
     should never happen under normal operation, so panic and abort the program
     immediately. */
  bne      x2, x0, _modinv_u_low_ok
  unimp

_modinv_u_low_ok:
  /* x31 <= plen - 1
     FG0.Z <= (u[1] | ... | u[plen - 1] == 0) */
  bn.mov   w23, w31
  addi     x2, x0, 1
  sub      x31, x30, x2
  loop     x31, 2
    bn.lid   x20, 0(x17++)
    bn.or    w23, w20, w23

  /* Get the FG0.Z flag into a register.
       x2 <= CSRs[FG0] & 8 = FG0.Z << 3 */
  csrrs    x2, FG0, x0
  andi     x2, x2, 8

  /* If the flag is unset (x2 == 0) then we know u != 1; in this case GCD(a,
     m) != 1 and the modular inverse cannot be computed. This should never
     happen under normal operation, so panic and abort the program immediately. */
  bne      x2, x0, _modinv_u_ok
  unimp

_modinv_u_ok:
  /* Done; the modular inverse is stored in A. */
  ret

/**
 * Shifts input 1 bit to the right in-place if FG1.L is 0.
 *
 * Returns A' = if FG1.L then A else (msb || A) >> 1.
 *
 * The MSB of the final result will be the LSB of w23.
 *
 * Flags have no meaning beyond the scope of this subroutine.
 *
 * @param[in]   x3: dptr_A, pointer to input A in DMEM
 * @param[in]  x20: 20, constant
 * @param[in]  x21: 21, constant
 * @param[in]  x30: alen, number of 256-bit limbs for input A
 * @param[in]   w23: value to use as the msb
 * @param[in]   w31: all-zero
 * @param[out] dmem[dptr_A..dptr_A+alen*32]: A', result
 *
 * clobbered registers: x2, x3, x4, w20, w21
 * clobbered flag groups: FG0
 */
bignum_rshift1_if_not_fg1L:
  /* Calculate number of loop iterations for bignum shifts.
       x2 <= n - 1 */
  addi     x2, x0, 1
  sub      x2, x30, x2

  /* Conditionally shift the lower limbs. */
  addi      x4, x3, 32
  loop      x2, 5
    /* w20 <= dmem[x3] = A[i] */
    bn.lid    x20, 0(x3)
    /* w21 <= dmem[x4] = A[i+1] */
    bn.lid    x21, 0(x4++)
    /* w21 <= (A >> 1)[i] */
    bn.rshi   w21, w21, w20 >> 1
    /* w20 <= FG1.L ? w20 : w21 */
    bn.sel    w20, w20, w21, FG1.L
    /* dmem[x3] <= w20 */
    bn.sid    x20, 0(x3++)

  /* Last limb is special because there's no next limb; we use the provided
     input value. */
  bn.lid    x20, 0(x3)
  bn.rshi   w21, w23, w20 >> 1
  bn.sel    w21, w20, w21, FG1.L
  bn.sid    x21, 0(x3)

  ret
