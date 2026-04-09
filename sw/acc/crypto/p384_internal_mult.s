/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */


/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */
/*
 *   P-384 specific routines for internal scalar multiplication of curve points.
 */

 .section .text

/**
 * Fetch curve point from dmem, randomize z-coordinate and store point in dmem
 *
 * returns P = (x, y, z) = (x_a*z, y_a*z, z)
 *         with P being a valid P-384 curve point in projective coordinates
 *              x_a and y_a being the affine coordinates as fetched from dmem
 *              z being a randomized z-coordinate
 *
 * This routines fetches the affine x- and y-coordinates of a curve point from
 * dmem and computes a valid set of projective coordinates. The z-coordinate is
 * randomized and x and y are scaled appropriately. The resulting projective
 * coordinates are stored at dmem[dptr_p_p] using 6 consecutive 256-bit cells,
 * i.e. each coordinate is stored 512 bit aligned, little endian.
 * This routine runs in constant time.
 *
 * @param[in]  x20: dptr_x, pointer to dmem location containing affine
 *                          x-coordinate of input point
 * @param[in]  x21: dptr_y, pointer to dmem location containing affine
 *                          y-coordinate of input point
 * @param[in]  [w13, w12]: p, modulus of P-384 underlying finite field
 * @param[in]  w31: all-zero
 * @param[in]  x18: dptr_p_p, pointer to dmem location to store resulting point
 *                            in projective space
 *
 * Flags: When leaving this subroutine, the M, L and Z flags of FG0 depend on
 *        the upper limb of projective y-coordinate.
 *
 * clobbered registers: x10, x11 to x13
  *                     w2, w3, w8 to w11, w16 to w24, w29, w30
 * clobbered flag groups: FG0
 */
 .globl store_proj_randomize
store_proj_randomize:

  /* get a 384-bit random number from URND
    [w17, w16] = random(384) */
  bn.wsrr   w16, 2
  bn.wsrr   w17, 2
  bn.rshi   w17, w31, w17 >> 128

  /* reduce random number
     [w23, w22] = z <= [w17, w16] mod p */
  bn.sub   w18, w16, w12
  bn.subb  w19, w17, w13
  bn.sel   w22, w16, w18, C
  bn.sel   w23, w17, w19, C

  /* Move z-coordinate into regs for later use
     [w3, w2] <= z, [w11, w10] <= z */
  bn.mov w2,  w22
  bn.mov w3,  w23
  bn.mov w10, w22
  bn.mov w11, w23

  /* store z-coordinate
     dmem[x20+128] = [w10, w11] */
  li        x10, 10
  li        x11, 11
  bn.sid    x10, 128(x18)
  bn.sid    x11, 160(x18)

  /* fetch x-coordinate from dmem
     [w16, w17] = x <= [dmem[dptr_x], dmem[dptr_x+32]] */
  li        x12, 16
  li        x13, 17
  bn.lid    x12,  0(x20)
  bn.lid    x13, 32(x20)

  /* scale and store x-coordinate
     [dmem[dptr_p_p], dmem[dptr_p_p+32]] = [w17, w16] =
       x_p <= [w11, w10] * [w17, w16] = z*x  mod p */

  jal       x1, p384_mulmod_p
  bn.sid    x12,  0(x18)
  bn.sid    x13, 32(x18)

  /* fetch y-coordinate from dmem
     [w11, w10] = x <= [dmem[dptr_y], dmem[dptr_y+32]] */
  bn.lid    x12,  0(x21)
  bn.lid    x13, 32(x21)

  /* scale and store y-coordinate
     [dmem[dptr_p_p+64], dmem[dptr_p_p+96]] = [w17, w16] =
       y_p <= [w11, w10] * [w17, w16] = z*y  mod p */
  bn.mov w10, w2
  bn.mov w11, w3
  jal       x1, p384_mulmod_p
  bn.sid    x12, 64(x18)
  bn.sid    x13, 96(x18)

  ret

/**
 * P-384 scalar point multiplication in projective space
 *
 * returns R = k*P = k*(x_p, y_p)
 *         where P is a valid P-384 curve point in affine coordinates,
 *               k is a 384-bit scalar,
 *               R is a valid P-384 curve point in projective coordinates.
 *
 * This routine performs scalar multiplication based on the group laws
 * of Weierstrass curves.
 * A constant time double-and-add algorithm (sometimes referred to as
 * double-and-add-always) is used.
 * Due to the P-384 optimized implementations of the internally called routines
 * for point addition and doubling, this routine is limited to P-384 curves.
 * The routine makes use of blinding by additive splitting the
 * exponent/scalar d into two shares. The double-and-add loop operates on both
 * shares in parallel applying the Strauss-Shamir trick:
 * The routine receives the scalar in two shares k0, k1 such that
 *   k = (k0 + k1) mod n
 * The loop operates on both shares in parallel, computing (k0 + k1) * P as
 * follows:
 *  Q = (0, 1, 0) # origin
 *  for i in 448..0:
 *    Q = 2 * Q
 *    A = if (k0[i] ^ k1[i]) then P else 2P
 *    B = Q + A
 *    Q = if (k0[i] | k1[i]) then B else Q
 *
 * Each share k0/k1 is 448 bits, even though it represents a 384-bit value.
 * This is a side-channel protection measure.
 *
 * @param[in]  x17: dptr_k0, pointer to first share k0 of scalar k
 *                           (0 < k < n) in dmem (448-bit)
 * @param[in]  x19: dptr_k1, pointer to second share k1 of scalar k
 *                           (0 < k < n) in dmem (448-bit)
 * @param[in]  x20: dptr_x, pointer to affine x-coordinate in dmem
 * @param[in]  x21: dptr_y, pointer to affine y-coordinate in dmem
 * @param[in]  x28: dptr_b, pointer to domain parameter b of P-384 in dmem
 * @param[in]  [w13, w12]: p, modulus of P-384 underlying finite field
 * @param[in]  [w11, w10]: n, domain parameter of P-384 curve
 *                            (order of base point G)
 * @param[in]  w31: all-zero
 * @param[out]  [w26,w25]: x, x-coordinate of resulting point R (projective).
 * @param[out]  [w28,w27]: y, y-coordinate of resulting point R (projective).
 * @param[out]  [w30,w29]: z, z-coordinate of resulting point R (projective).
 *
 * Projective coordinates of a point are kept in dmem in little endian format
 * with the individual coordinates 512 bit aligned. The coordinates are stored
 * in x,y,z order (i.e. x at lowest, z at highest address). Thus, a 384 bit
 * curve point occupies 6 consecutive 256-bit dmem cells.
 *
 * Flags: When leaving this subroutine, the M, L and Z flags of FG0 depend on
 *        the computed affine y-coordinate.
 *
 * clobbered registers: x2 to x7, x10 to x13, x18, x22 to x27, x30, w0 to w11, w16 to w31, acc
 * clobbered flag groups: FG0, FG1
 */
 .globl scalar_mult_int_p384
scalar_mult_int_p384:

  /* set regfile pointers to in/out regs of mulmod routine. Set here to avoid
     resetting in very call to point addition routine */
  li        x22, 10
  li        x23, 11
  li        x24, 16
  li        x25, 17

  /* fetch 1st share of scalar from dmem
     s0 = [w1, w0] <= dmem[dptr_k0] = [dmem[x17], dmem[x17+32]] = k0 */
  li        x2, 0
  bn.lid    x2++, 0(x17)
  bn.lid    x2++, 32(x17)

  /* fetch 2nd share of scalar from dmem
     s0 = [w3, w2] <= dmem[dptr_k1] = [dmem[x19], dmem[x19+32]] = k1 */
  bn.lid    x2++, 0(x19)
  bn.lid    x2++, 32(x19)

  /* left align both shares for probing of MSB in loop body */
  bn.rshi   w1, w1, w0 >> 192
  bn.rshi   w0, w0, w31 >> 192
  bn.rshi   w3, w3, w2 >> 192
  bn.rshi   w2, w2, w31 >> 192

  /* Store first scalar share to scratchpad. */
  li        x2, 0
  la        x3, scalarmult_k0
  bn.sid    x2++,  0(x3)
  bn.sid    x2++, 32(x3)

  /* Dummy operation in between share accesses. */
  bn.xor    w31, w31, w31

  /* Store second scalar share to scratchpad. */
  la        x3, scalarmult_k1
  bn.sid    x2++,  0(x3)
  bn.sid    x2++, 32(x3)

  /* Convert P to projective coordinates and copy to scratchpad. */
  la        x18, scalarmult_P
  jal       x1, store_proj_randomize

  /* load randomized point P */
  li        x2, 25
  bn.lid    x2++,   0(x18)
  bn.lid    x2++,  32(x18)
  bn.lid    x2++,  64(x18)
  bn.lid    x2++,  96(x18)
  bn.lid    x2++, 128(x18)
  bn.lid    x2++, 160(x18)

  /* double point P
     2P = ([w30,w29], [w28,w27], [w26, w25]) <= 2*P */
  addi      x27, x18, 0
  jal       x1, proj_add_p384

  /* Store point 2P.
     dmem[scalarmult_2P] = [w30:w25] = 2P */
  la        x3, scalarmult_2P
  li        x2, 25
  bn.sid    x2++,   0(x3)
  bn.sid    x2++,  32(x3)
  bn.sid    x2++,  64(x3)
  bn.sid    x2++,  96(x3)
  bn.sid    x2++, 128(x3)
  bn.sid    x2++, 160(x3)

  /* Initialize the point Q = (0, 1, 0) in registers [w30:w25]. */
  bn.xor    w25, w25, w25
  bn.xor    w26, w26, w26
  bn.addi   w27, w26, 1
  bn.xor    w28, w28, w28
  bn.xor    w29, w29, w29
  bn.xor    w30, w30, w30

  /* Double-and-add loop with decreasing index.

     Loop invariants (i=448..0):
       x27 = scalarmult_Q (tmp)
       [w30:w25] = Q = ((k >> i) * P)
       dmem[x4:x4+64] = P
       dmem[x5:x5+64] = 2*P
       dmem[x6:x6+64] = (k0 << (i+64)) % 2^512
       dmem[x7:x7+64] = (k1 << (i+64)) % 2^512
   */
  la        x4, scalarmult_P
  la        x5, scalarmult_2P
  la        x6, scalarmult_k0
  la        x7, scalarmult_k1
  la        x27, scalarmult_Q
  loopi     448, 67

    /* Double point Q.
       Q = ([w30,w29], [w28,w27], [w26, w25]) <= Q + dmem[x27] */
    jal       x1, proj_double_p384

    /* Store Q in dmem and load scalar shares, interleaving to avoid
       consecutive share access.
         dmem[scalarmult_Q] <= [w30:w25]
         [w1:w0] <= dmem[scalarmult_k0]
         [w3:w2] <= dmem[scalarmult_k1] */
    li        x2, 25
    li        x3, 0
    bn.sid    x2++,   0(x27)
    bn.sid    x2++,  32(x27)
    bn.lid    x3++,   0(x6)
    bn.lid    x3++,  32(x6)
    bn.sid    x2++,  64(x27)
    bn.sid    x2++,  96(x27)
    bn.lid    x3++,   0(x7)
    bn.lid    x3++,  32(x7)
    bn.sid    x2++, 128(x27)
    bn.sid    x2++, 160(x27)

    /* Probe the MSB xor and or of the combined scalars. Randomize other bits
       to obfuscate power signals.
         FG0.L <= w1[255] ^ w3[255] = k0[i] ^ k1[i]
         FG1.L <= w1[255] | w3[255] = k0[i] | k1[i]
    */
    bn.wsrr   w18, urnd
    bn.rshi   w20, w18, w1 >> 255
    bn.wsrr   w19, urnd
    bn.rshi   w21, w19, w3 >> 255
    bn.cmp    w20, w21
    bn.or     w20, w20, w21, FG1

    /* Load P and 2P one limb at a time, using the L flag to select one. We
       select P if the L flag is set and 2P otherwise (in the case that both
       MSBs were zero, the addition result gets discarded).
       [w24:w18] <= L ? dmem[scalarmult_P] : dmem[scalarmult_2P] */
    li    x2, 25
    loopi 6, 4
      bn.lid    x24, 0(x4++)
      bn.lid    x25, 0(x5++)
      bn.sel    w11, w16, w17, L
      bn.movr   x2++, x23
    addi  x4, x4, -192
    addi  x5, x5, -192

    /* Shift the scalar shares one place and store them. */
    bn.add    w0, w0, w0
    bn.addc   w1, w1, w1
    li        x2, 0
    bn.sid    x2++,  0(x6)
    bn.sid    x2++, 32(x6)
    bn.xor    w31, w31, w31 /* dummy instruction between share accesses */
    bn.add    w2, w2, w2
    bn.addc   w3, w3, w3
    bn.sid    x2++,  0(x7)
    bn.sid    x2++, 32(x7)

    /* [w30:w25] <= [w30:w25] + dmem[scalarmult_Q] */
    jal       x1, proj_add_p384

    /* Get a pseudorandom 384-bit scaling factor and reduce modulo p. */
    bn.wsrr   w4, urnd
    bn.wsrr   w5, urnd
    bn.rshi   w5, w31, w5 >> 128
    bn.sub    w2, w4, w12
    bn.subb   w3, w5, w13
    bn.sel    w10, w4, w2, C
    bn.sel    w11, w5, w3, C

    /* Select either Q or Q_a based on FG1.L, randomizing as we go. */
    li        x2, 1
    bn.lid    x0,  0(x27)
    bn.lid    x2, 32(x27)
    bn.sel    w16, w25, w0, FG1.L
    bn.sel    w17, w26, w1, FG1.L
    jal       x1, p384_mulmod_p
    bn.mov    w25, w16
    bn.mov    w26, w17
    bn.lid    x0, 64(x27)
    bn.lid    x2, 96(x27)
    bn.sel    w16, w27, w0, FG1.L
    bn.sel    w17, w28, w1, FG1.L
    jal       x1, p384_mulmod_p
    bn.mov    w27, w16
    bn.mov    w28, w17
    bn.lid    x0, 128(x27)
    bn.lid    x2, 160(x27)
    bn.sel    w16, w29, w0, FG1.L
    bn.sel    w17, w30, w1, FG1.L
    jal       x1, p384_mulmod_p
    bn.mov    w29, w16
    bn.mov    w30, w17

  ret

.section .scratchpad, "aw"

.balign 32
scalarmult_k0:
.zero 64

.balign 32
scalarmult_k1:
.zero 64

.balign 32
scalarmult_P:
.zero 192

.balign 32
scalarmult_2P:
.zero 192

.balign 32
scalarmult_Q:
.zero 192
