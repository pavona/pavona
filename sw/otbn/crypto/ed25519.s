/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * This library contains an implementation of the Ed25519 signature scheme
 * based on RFC 8032 and FIPS 186-5:
 *   https://datatracker.ietf.org/doc/html/rfc8032
 *
 * This implementation uses affine (x, y) coordinates at the interface but uses
 * the faster "extended twisted Edwards" coordinates internally. Procedures
 * that accept input in affine form are prefixed with affine_ and those that
 * accept input in extended form are prefixed with ext_.
 *
 * Where RFC 8032 and FIPS 186-5 disagree, such as for certain cases of
 * non-canonical point encodings (e.g. y >= p), we follow FIPS. The terminology
 * in the comments matches the RFC.
 */

/**
 * Hardened values to encode success/failure of signature verification and
 * point decoding.
 *
 * Encoding generated with
 * $ ./util/design/sparse-fsm-encode.py -d 21 -m 2 -n 32 \
 *     -s 1409634733 --language=c --avoid-zero
 *
 * Minimum Hamming distance: 21
 * Maximum Hamming distance: 21
 * Minimum Hamming weight: 21
 * Maximum Hamming weight: 22
 */
/* TODO: It would be nice to use these .equ declarations for success/failure
   magic values, but they cause errors in the assembler from the LI
   instructions.

.equ FAILURE,          0xeda2bfaf
.equ SUCCESS,          0xf77fe650
*/

/**
 * Top-level Ed25519 signature verification operation.
 *
 * Returns SUCCESS or FAILURE.
 *
 * This routine follows RFC 8032, section 5.1.7, but because SHA-512 is not in
 * the same OTBN program we have to slightly rearrange the order of operations.
 * In particular, we assume that Ibex computes step 2 (computation of k =
 * SHA2-512(dom2(F,C) || R_ || A_ || PH(M)), where R_ and A_ are the encoded
 * values of curve points from the signature and public key respectively). This
 * procedure takes k, S, and the encoded points R_ and A_ as arguments, and
 * does the following:
 *
 *   1. Decodes and checks validity of the points R and A.
 *   2. Decodes and checks the range of the scalar value S.
 *   3. Checks the group equation [8][S]B = [8]R + [8][k]A.
 *
 * This verification checks that S < L, and always uses the group equation with
 * the cofactors of 8 rather than the optional version without these also
 * offered by the RFC.
 *
 * This routine runs in variable time.
 *
 * Flags: Flags have no meaning beyond the scope of this subroutine.
 *
 * @param[in]  w31: all-zero
 * @param[in]  dmem[ed25519_hash_k]: precomputed hash k, 512 bits
 * @param[in]  dmem[ed25519_sig_R]: encoded signature point R_, 256 bits
 * @param[in]  dmem[ed25519_sig_S]: signature scalar S, 256 bits
 * @param[in]  dmem[ed25519_public_key]: encoded public key A_, 256 bits
 * @param[out] dmem[ed25519_verify_result]: SUCCESS or FAILURE
 *
 * clobbered registers: x2 to x4, x20 to x23, w1 to w30
 * clobbered flag groups: FG0
 */
.globl ed25519_verify_var
ed25519_verify_var:
  /* Set up for scalar arithmetic.
       [w15:w14] <= mu
       MOD <= L */
  jal      x1, sc_init

  /* Load the 512-bit precomputed hash k.
       [w17:w16] <= k */
  li       x2, 16
  la       x3, ed25519_hash_k
  bn.lid   x2, 0(x3++)
  addi     x2, x2, 1
  bn.lid   x2, 0(x3)

  /* Reduce k modulo L.
       w3 <= [w17:w16] mod L = k mod L */
  jal      x1, sc_reduce
  bn.mov   w3, w18

  /* Load the scalar S (second half of the signature).
      w1 <= dmem[ed25519_sig_S] = S*/
  li       x2, 1
  la       x3, ed25519_sig_S
  bn.lid   x2, 0(x3)

  /* w27 <= MOD = L */
  bn.wsrr  w27, MOD
  /* FG0.C <= (w1 - w27) <? 0 = S <? L */
  bn.cmp   w1, w27
  /* x2 <= FG0[0] = FG0.C */
  csrrs    x2, FG0, x0
  andi     x2, x2, 1

  /* Fail if S >= L. */
  li       x3, 1
  bne      x2, x3, verify_fail

  /* Compute (8 * S) mod L.
       w1 <= (2 * (2 * (2 * w1) mod L) mod L) mod L = (8 * S) mod L */
  bn.addm  w1, w1, w1
  bn.addm  w1, w1, w1
  bn.addm  w1, w1, w1

  /* Set up for field arithmetic in preparation for scalar multiplication and
     point addition.
       MOD <= p
       w19 <= 19
       w30 <= 38 */
  jal      x1, fe_init

  /* Initialize curve parameter d.
       w29 <= dmem[d] = (-121665/121666) mod p */
  li      x2, 29
  la      x3, ed25519_d
  bn.lid  x2, 0(x3)

  /* Load the encoded point R_ (first half of the signature).
       w11 <= R_ */
  li       x2, 11
  la       x3, ed25519_sig_R
  bn.lid   x2, 0(x3)

  /* Decode the signature point R.
       x20 <= SUCCESS or FAILURE
       [w11:w10] <= decode(w11) = decode(R_) = (R.x, R.y) */
  jal     x1, affine_decode_var

  /* If R was not a valid point (x20 != SUCCESS), fail. */
  li      x21, 0xf77fe650
  bne     x20, x21, verify_fail

  /* Save R (in affine coordinates) for later.
       [w5:w4] <= [w11:w10] = R */
  bn.mov  w4, w10
  bn.mov  w5, w11

  /* Load the encoded public key A_.
       w11 <= dmem[ed25519_public_key] = A_ */
  li       x2, 11
  la       x3, ed25519_public_key
  bn.lid   x2, 0(x3)

  /* Decode the public key point A.
       x20 <= SUCCESS or FAILURE
       [w11:w10] <= decode(w11) = decode(A_) = (A.x, A.y) */
  jal      x1, affine_decode_var

  /* If A was not a valid point (x20 != SUCCESS), fail. */
  bne      x20, x21, verify_fail

  /* Convert A to extended coordinates.
      [w9:w6] <= extended(A) = (A.X, A.Y, A.Z, A.T) */
  bn.mov   w6, w10
  bn.mov   w7, w11
  jal      x1, affine_to_ext

  /* [w13:w10] <= w3 * [w9:w6] = [k]A */
  bn.mov   w28, w3
  jal      x1, ext_scmul_var

  /* Convert R to extended coordinates.
       [w9:w6] <= extended(R) = (R.X, R.Y, R.Z, R.T) */
  bn.mov   w6, w4
  bn.mov   w7, w5
  jal      x1, affine_to_ext

  /* [w13:w10] <= [w13:w10] + [w9:w6] =  [k]A + R */
  bn.mov   w14, w6
  bn.mov   w15, w7
  bn.mov   w16, w8
  bn.mov   w17, w9
  jal      x1, ext_add

  /* Compute the right-hand side of the curve equation with three doublings.
       [w13:w10] <= ([k]A + R) * 2^3 = [8]R + [8][k]A */
  /* [w13:w10] <= [w13:w10] + [w13:w10] = [2]([k]A + R) */
  jal      x1, ext_double
  /* [w13:w10] <= [w13:w10] + [w13:w10] = [4]([k]A + R) */
  jal      x1, ext_double
  /* [w13:w10] <= [w13:w10] + [w13:w10] = [8]([k]A + R)*/
  jal      x1, ext_double

  /* Store the right-hand side for later.
       [w5:w2] <= [w13:w10] = [8]R + [8][k]A */
  bn.mov   w2, w10
  bn.mov   w3, w11
  bn.mov   w4, w12
  bn.mov   w5, w13

  /* Load the base point B (in affine coordinates).
       w6 <= dmem[ed25519_Bx] = B.x
       w7 <= dmem[ed25519_By] = B.y */
  li       x2, 6
  la       x3, ed25519_Bx
  bn.lid   x2++, 0(x3)
  la       x3, ed25519_By
  bn.lid   x2, 0(x3)

  /* Convert B to extended coordinates.
       [w9:w6] <= extended(B) = (B.X, B.Y, B.Z, B.T) */
  jal      x1, affine_to_ext

  /* Compute the left-hand side of the curve equation.
       [w13:w10] <= w1 * [w9:w6] = [8][S]B */
  bn.mov   w28, w1
  jal      x1, ext_scmul_var

  /* Compare both sides of the equation for equality.
       dmem[ed25519_verify_result] <= SUCCESS if [w5:w2] == [w13:w10],
                                      otherwise FAILURE */
  jal      x1, ext_equal_var

  ret

  verify_fail:
  /* Write the FAILURE magic value.
       dmem[ed25519_verify_result] <= x23 = FAILURE */
  li       x22, 0xeda2bfaf
  la       x2, ed25519_verify_result
  sw       x22, 0(x2)
  ret

/**
 * Top-level Ed25519ph signature generation operation.
 *
 * Returns an 512-bit signature (R_ || S).
 *
 * Briefly, the signature generation algorithm is:
 *   1. Compute h = SHA-512(d). Denote the second half of h as prefix.
 *   2. Compute r = SHA-512(domain-separator || prefix || PH(M))
 *   3. Construct the secret scalar s from the first half of h.
 *   4. Compute the public key A = [s]B. Encode A as A_.
 *   5. Compute the signature point R = [r]B. Encode R as R_.
 *   6. Compute k = SHA-512(domain-separator || R_ || A_ || PH(M))
 *   7. Compute the signature scalar S = (r + k * s) mod L.
 *
 * The "domain separator" in steps 2 and 6 is, as defined in IETF RFC 8032 and
 * FIPS 186-5:
 *   "SigEd25519 no Ed25519 collisions" || byte(1) || byte(ctx_len) || ctx
 *
 * This routine runs in constant time.
 *
 * Flags: Flags have no meaning beyond the scope of this subroutine.
 *
 * @param[in]  dmem[ed25519_d]: secret key (256 bits)
 * @param[in]  dmem[ed25519_ctx]: context string (ctx_len bytes)
 * @param[in]  dmem[ed25519_ctx_len]: length of context string in bytes
 * @param[in]  dmem[ed25519_message]: pre-hashed message (512 bits)
 * @param[out] dmem[ed25519_sig_R]: R component of signature (256 bits)
 * @param[out] dmem[ed25519_sig_S]: S component of signature (256 bits)
 *
 * clobbered registers: x2 to x4, x20 to x23, w1 to w30
 * clobbered flag groups: FG0
 */
.globl ed25519_sign_prehashed
ed25519_sign_prehashed:
  /* Initialize all-zero register. */
  bn.xor   w31, w31, w31

  /* Call the SHA-512 routine to hash d.
       dmem[ed25519_hash_h] <= SHA-512(d) = h */
  jal      x1, sha512_init
  li       x18, 32
  la       x20, ed25519_d
  jal      x1, sha512_update
  la       x18, ed25519_hash_h
  jal      x1, sha512_final

  /* Append the context length to the domain separator prefix.
       dmem[ed25519_prehash_dom_sep+33] <= ctx_len */
  la       x2, ed25519_ctx_len
  lw       x2, 0(x2)
  slli     x2, x2, 8
  la       x3, ed25519_prehash_dom_sep
  lw       x4, 32(x3)
  or       x4, x4, x2
  sw       x4, 0(x3)

  /* dmem[ed25519_r] <= SHA-512(domain-separator || h[63:32] || PH(M)) */
  jal      x1, sha512_init
  li       x18, 34
  la       x20, ed25519_prehash_dom_sep
  jal      x1, sha512_update
  la       x18, ed25519_ctx_len
  lw       x18, 0(x18)
  la       x20, ed25519_ctx
  jal      x1, sha512_update
  li       x18, 32
  la       x20, ed25519_hash_h
  addi     x20, x20, 32
  jal      x1, sha512_update
  li       x18, 64
  la       x20, ed25519_message
  jal      x1, sha512_update
  la       x18, ed25519_hash_r
  jal      x1, sha512_final

  /* Set up for scalar arithmetic.
       [w15:w14] <= mu
       MOD <= L */
  jal      x1, sc_init

  /* Load the 256-bit lower half of the hash h.
       w16 <= h[255:0] */
  li       x2, 16
  la       x3, ed25519_hash_h
  bn.lid   x2, 0(x3)

  /* Recover the secret scalar s from h.
       w16 <= s */
  jal      x1, sc_clamp

  /* Reduce s modulo L. Note: s is only 255 bits, so this full 512-bit
     reduction could be much faster (in fact, since clamping guarantees 3L < s
     < 4L, we can simply subtract 3L instead). However, this routine is not
     performance-critical, so we use the generalized routine and set the high
     bits to zero.
       w18 <= [w31,w16] mod L = s mod L */
  bn.mov   w17, w31
  jal      x1, sc_reduce

  /* Save s for later.
       w5 <= s mod L */
  bn.mov   w5, w18

  /* Load the 512-bit hash r.
       [w17:w16] <= r */
  li       x2, 16
  la       x3, ed25519_hash_r
  bn.lid   x2, 0(x3++)
  addi     x2, x2, 1
  bn.lid   x2, 0(x3)

  /* Reduce r modulo L.
       w18 <= [w17:w16] mod L = r mod L */
  jal      x1, sc_reduce

  /* Save r for later.
       w1 <= w18 = r mod L */
  bn.mov   w1, w18

  /* Set up for field arithmetic in preparation for scalar multiplication.
       MOD <= p
       w19 <= 19 */
  jal      x1, fe_init

  /* Initialize curve parameter d.
       w29 <= dmem[d] = (-121665/121666) mod p */
  li      x2, 29
  la      x3, ed25519_d
  bn.lid  x2, 0(x3)

  /* Load the base point B (in affine coordinates).
       w6 <= dmem[ed25519_Bx] = B.x
       w7 <= dmem[ed25519_By] = B.y */
  li       x2, 6
  la       x3, ed25519_Bx
  bn.lid   x2++, 0(x3)
  la       x3, ed25519_By
  bn.lid   x2, 0(x3)

  /* Convert B to extended coordinates.
       [w9:w6] <= extended(B) = (B.X, B.Y, B.Z, B.T) */
  jal      x1, affine_to_ext

  /* Compute the signature point R = [r]B.
       [w13:w10] <= w1 * [w9:w6] = [r]B */
  bn.mov   w28, w1
  jal      x1, ext_scmul

  /* Convert R to affine coordinates.
       w10 <= R.x, w11 <= R.y */
  jal      x1, ext_to_affine

  /* Encode R.
       w11 <= encode(w10, w11) = R_ */
  jal      x1, affine_encode

  /* Write encoded R (R_) to DMEM.
       dmem[ed25519_sig_R] <= w11 = R_ */
  li       x2, 11
  la       x3, ed25519_sig_R
  bn.sid   x2, 0(x3)

  /* Compute the public key point A = [s]B.
       [w13:w10] <= w5 * [w9:w6] = [s]B */
  bn.mov   w28, w5
  jal      x1, ext_scmul

  /* Convert A to affine coordinates.
       w10 <= A.x, w11 <= A.y */
  jal      x1, ext_to_affine

  /* Encode A.
       w11 <= encode(w10, w11) = A_ */
  jal      x1, affine_encode

  /* Write encoded A (A_) to DMEM.
       dmem[ed25519_public_key] <= w11 = A_ */
  li       x2, 11
  la       x3, ed25519_public_key
  bn.sid   x2, 0(x3)

  /* TODO: we could start with the pre-computed domain separator prefix here potentially */
  /* dmem[ed25519_hash_k] <= SHA-512(domain-separator || R_ || A_ || PH(M)) */
  jal      x1, sha512_init
  li       x18, 34
  la       x20, ed25519_prehash_dom_sep
  jal      x1, sha512_update
  la       x18, ed25519_ctx_len
  lw       x18, 0(x18)
  la       x20, ed25519_ctx
  jal      x1, sha512_update
  li       x18, 32
  la       x20, ed25519_sig_R
  jal      x1, sha512_update
  li       x18, 32
  la       x20, ed25519_public_key
  jal      x1, sha512_update
  li       x18, 64
  la       x20, ed25519_message
  jal      x1, sha512_update
  la       x18, ed25519_hash_k
  jal      x1, sha512_final

  /* Set up for scalar arithmetic.
       [w15:w14] <= mu
       MOD <= L */
  jal      x1, sc_init

  /* Load the 512-bit hash k.
       [w17:w16] <= k */
  li       x2, 16
  la       x3, ed25519_hash_k
  bn.lid   x2, 0(x3++)
  addi     x2, x2, 1
  bn.lid   x2, 0(x3)

  /* Reduce k modulo L.
       w18 <= [w17:w16] mod L = k mod L */
  jal      x1, sc_reduce

  /* Save k for later.
       w4 <= k mod L */
  bn.mov   w4, w18

  /* Compute the signature scalar S = (r + (k * s)) mod L. Note: s is not fully
     reduced modulo L here, but that is permitted according to the
     specification of sc_mul, which only requires that its inputs fit in 256
     bits. */

  /* w18 <= (w4 * w5) mod L = (k * s) mod L */
  bn.mov   w21, w4
  bn.mov   w22, w5
  jal      x1, sc_mul

  /* w4 <= (w5 + w18) mod L = (r + k * s) mod L = S */
  bn.addm  w4, w5, w18

  /* Write S to dmem.
       dmem[ed25519_sig_S] <= w4 = S */
  li       x2, 4
  la       x3, ed25519_sig_S
  bn.sid   x2, 0(x3)

  ret

/**
 * Extract the secret scalar s from a hash (see RFC 8032, section 5.1.5).
 *
 * Returns s = 2^254 + (h[253:3] << 3)
 *
 * This is referred to as "clamping" in some places and is a way of
 * manipulating the hash value to be a number that 1) is a multiple of the
 * cofactor 8 and 2) has the MSB at position 254, while preserving
 * unpredictability.
 *
 * From the RFC:
 *
 *     2.  Prune the buffer: The lowest three bits of the first octet are
 *         cleared, the highest bit of the last octet is cleared, and the
 *         second highest bit of the last octet is set.
 *     3.  Interpret the buffer as [a] little-endian integer, forming a
 *         secret scalar s.
 *
 * This routine runs in constant time.
 *
 * Flags: Flags have no meaning beyond the scope of this subroutine.
 *
 * @param[in]  w16: input h, 256 bits
 * @param[in]  w31: all-zero
 * @param[out] w16: output s
 *
 * clobbered registers: w16, w17
 * clobbered flag groups: FG0
 */
sc_clamp:
  /* w16 <= w16 >> 3 = h[255:3] */
  bn.rshi  w16, w31, w16 >> 3
  /* w16 <= w16 << 5 = h[253:3] << 5 */
  bn.rshi  w16, w16, w31 >> 251
  /* w17 <= 1 */
  bn.addi  w17, w31, 1
  /* w16 <= [w17:w16] >> 2 = (1 << 254) + (h[255:3] << 3) */
  bn.rshi  w16, w17, w16 >> 2
  ret

/**
 * Convert a point from affine (x, y) to extended (X, Y, Z, T) coordinates.
 *
 * Returns (X, Y, Z, T) = (x, y, 1, (x*y) mod p)
 *
 * The standard way to represent a point on an elliptic curve is with (X, Y)
 * coordinates. However, alternative point representations using multiple
 * related variables are often much faster. In this case, an "extended twisted
 * Edwards" point (X, Y, Z, T) is related to an affine point (x, y) with the
 * following equations (in terms of the coordinate finite field modulo p):
 *   x = (X / Z)
 *   y = (Y / Z)
 *   x*y = T / Z
 *
 * To convert an affine point into extended form, therefore, we can just set
 * X=x, Y=y, Z=1, and T=(x*y) mod p.
 *
 * More details can be found in the original paper and the Explicit Formulas
 * Database:
 *   https://eprint.iacr.org/2008/522.pdf
 *   https://hyperelliptic.org/EFD/g1p/auto-twisted.html
 *
 * Here, we follow the same convention as the Explicit Formulas Database and
 * represent affine coordinates with lowercase (x, y) and extended coordinates
 * with uppercase (X, Y, Z, T).
 *
 * This routine runs in constant time.
 *
 * Flags: Flags have no meaning beyond the scope of this subroutine.
 *
 * @param[in]  w6: input x (x < p)
 * @param[in]  w7: input y (y < p)
 * @param[in]  w19: constant, w19 = 19
 * @param[in]  MOD: p, modulus = 2^255 - 19
 * @param[in]  w31: all-zero
 * @param[out] w6: output X (X < p)
 * @param[out] w7: output Y (Y < p)
 * @param[out] w8: output Z (Z < p)
 * @param[out] w9: output T (T < p)
 *
 * clobbered registers: w6 to w9, w18, w20 to w23
 * clobbered flag groups: FG0
 */
affine_to_ext:
  /* w8 <= 1 = Z */
  bn.addi  w8, w31, 1

  /* w22 <= (w6 * w7) mod p = T */
  bn.mov  w22, w6
  bn.mov  w23, w7
  jal     x1, fe_mul
  /* w9 <= w22 = T */
  bn.mov  w9, w22

  /* X=x and Y=y, so nothing needs to be done for these. */

  ret

/**
 * Convert a point from extended (X, Y, Z, T) to affine (x, y) coordinates.
 *
 * Returns (x, y) = ((X * Z^-1) mod p, (Y * Z^-1) mod p)
 *
 * See `affine_to_ext` for background on affine vs extended coordinates. To
 * convert a point from extended to affine coordinates, we need to compute:
 *   x = (X / Z)
 *   y = (Y / Z)
 *
 * As always, operations on the coordinates are in terms of the coordinate
 * field modulo p. Therefore, to divide by Z, what we actually need to do is
 * compute the inverse of Z modulo p, and then multiply by X and Y. The T input
 * is not actually needed for this computation, so it is omitted here.
 *
 * This routine runs in constant time.
 *
 * Flags: Flags have no meaning beyond the scope of this subroutine.
 *
 * @param[in]  w10: input X (X < p)
 * @param[in]  w11: input Y (Z < p)
 * @param[in]  w12: input Z (Z < p)
 * @param[in]  w19: constant, w19 = 19
 * @param[in]  w31: all-zero
 * @param[in]  MOD: p, modulus = 2^255 - 19
 * @param[out] w10: output x (x < p)
 * @param[out] w11: output y (y < p)
 *
 * clobbered registers: w10, w11, w14 to w18, w20 to w23
 * clobbered flag groups: FG0
 */
ext_to_affine:
  /* w22 <= (Z^-1) mod p */
  bn.mov  w16, w12
  jal     x1, fe_inv
  /* w23 <= w22 = (Z^-1) mod p */
  bn.mov  w23, w22

  /* w22 <= (w10 * w23) mod p = (X * Z^-1) mod p = x */
  bn.mov  w22, w10
  jal     x1, fe_mul
  /* w10 <= w22 = x */
  bn.mov  w10, w22

  /* w22 <= (w11 * w23) mod p = (Y * Z^-1) mod p = y */
  bn.mov  w22, w11
  jal     x1, fe_mul
  /* w11 <= w22 = y */
  bn.mov  w11, w22

  ret

/**
 * Encode a point as described in RFC 8032, section 5.1.2.
 *
 * Returns enc = y | (lsb(x) << 255).
 *
 * The input point is in affine coordinates (x, y). From the RFC:
 *
 *   First, encode the y-coordinate as a little-endian string of 32 octets.
 *   The most significant bit of the final octet is always zero. To form the
 *   encoding of the point, copy the least significant bit of the x-coordinate
 *   to the most significant bit of the final octet.
 *
 * This encoding is sufficient for Ed25519 because each y corresponds to at
 * most two x coordinates, which have different least-significant bits.
 *
 * This routine runs in constant time.
 *
 * Flags: Flags have no meaning beyond the scope of this subroutine.
 *
 * @param[in]  w10: input x (x < p)
 * @param[in]  w11: input y (y < p)
 * @param[in]  w31: all-zero
 * @param[out] w11: enc, resulting encoded point
 *
 * clobbered registers: w10, w11
 * clobbered flag groups: FG0
 */
.globl affine_encode
affine_encode:
  /* w10 <= lsb(x) << 255 */
  bn.rshi  w10, w10, w31 >> 1
  /* w11 <= w11 | w10 = y | (lsb(x) << 255) = enc */
  bn.or    w11, w11, w10
  ret

/**
 * Decode a point (see RFC 8032, section 5.1.3).
 *
 * Returns (x, y), the decoded point in affine coordinates.
 *
 * Broadly, point decoding involves:
 *   - Extracting the y value and lsb(x)
 *   - Solving the curve equation to get two candidates for x.
 *   - Use lsb(x) to select the correct candidate.
 *
 * Some implementations of Ed25519 disagree about how to decode points in
 * particular whether to accept the following:
 *   (a) non-canonical values of y in the range [p,2^255)
 *   (b) points with a recovered x value of 0 but a sign bit of 1 (i.e. "-0")
 *
 * Following FIPS 186-5, this implementation rejects both (a) and (b).
 *
 * Since no points in Ed25519 are secret, the inputs to this routine are all
 * public values and constant-time code is not a concern here.
 *
 * This routine runs in variable time.
 *
 * Flags: Flags have no meaning beyond the scope of this subroutine.
 *
 * @param[in]  w11: encoded point: y | (lsb(x) << 255)
 * @param[in]  w19: constant, w19 = 19
 * @param[in]  w29: constant, d = (-121665/121666) mod p
 * @param[in]  w30: constant, 38
 * @param[in]  w31: all-zero
 * @param[in]  MOD: p, modulus = 2^255 - 19
 * @param[out] x20: SUCCESS or FAILURE code
 * @param[out] w10: output x (x < p) (only valid if x20=SUCCESS)
 * @param[out] w11: output y (y < p) (only valid if x20=SUCCESS)
 *
 * clobbered registers: w10, w11, w14 to w18, w20 to w28
 * clobbered flag groups: FG0
 */
.globl affine_decode_var
affine_decode_var:
  /* Extract lsb(x) from the encoded point.
       w24 <= w11 >> 255 = lsb(x) */
  bn.rshi  w24, w31, w11 >> 255

  /* Extract y from the encoded point.
       w11 <= w11[254:0] = y */
  bn.rshi  w11, w11, w31 >> 255
  bn.rshi  w11, w31, w11 >> 1

  /* Reduce y modulo p and check if the value changed. If the values are equal,
     the FG0 value will be exactly 8; FG0.Z (bit position 3) will be true and M,
      L, and Z will be false. */
  bn.addm  w14, w11, w31
  bn.cmp   w11, w14
  li       x3, 8
  csrrs    x2, FG0, x0
  beq      x2, x3, decode_y_ok

  /* If we get here, then y >= p; reject the point. */
  li       x20, 0xeda2bfaf
  bn.mov   w10, w31
  bn.mov   w11, w31
  ret

  decode_y_ok:

  /* Solve the curve equation to get a candidate root. From RFC 8032,
     section 5.1.3, step 2:

       To recover the x-coordinate, the curve equation implies
       x^2 = (y^2 - 1) / (d y^2 + 1) (mod p).  The denominator is always
       non-zero mod p.  Let u = y^2 - 1 and v = d y^2 + 1.  To compute
       the square root of (u/v), the first step is to compute the
       candidate root r = (u/v)^((p+3)/8).  This can be done with the
       following trick, using a single modular powering for both the
       inversion of v and the square root:

                          (p+3)/8      3        (p-5)/8
                 r = (u/v)        = u v  (u v^7)         (mod p)

     Note: the RFC uses the name "x" for the candidate root, but we use "r"
     instead to distinguish the candidate root from the final computed x
     coordinate.

     The RFC doesn't give the mathematical background for why this formula
     works, but here's some quick intuition:
       - Euler's criterion states that if n has a square root modulo p, then
         n^((p-1) / 2) mod p = 1 (and if there's no square root, it's p-1).
       - Fermat's Little Theorem states that the inverse of n modulo p (where p
         is prime and 0 < n < p) is n^(p-1).
       - The "candidate root" r is such that r^4 = (u/v)^2 if (u/v) is square
         mod p, or -(u/v)^2 if (u/v) is nonsquare. This follows from Euler's
         criterion, because
           r^4 = (u/v)^((p+3)/2) = (u/v)^((p-1)/2) * (u/v)^2
       - If the provided point is valid, then (u/v) = x^2 and (u/v) must be
         square modulo p.
   */

   /* Store the constant 1, which will be used to compute u and v.
        w25 <= 1 */
   bn.addi   w25, w31, 1

   /* Compute u and v. */

   /* w22 <= (w11^2) mod p = y^2 mod p */
   bn.mov   w22, w11
   jal      x1, fe_square
   /* w26 <= (w22 - w25) mod p <= (y^2 - 1) mod p = u */
   bn.subm  w26, w22, w25
   /* w22 <= (w22 * w29) mod p = (y^2 * d) mod p */
   bn.mov   w23, w29
   jal      x1, fe_mul
   /* w25 <= (w22 + w25) mod p = (y^2 * d + 1) mod p = v */
   bn.addm  w25, w22, w25

   /* Compute the candidate root r = (u*(v^3))((u*(v^7))^((p-5)/8)) mod p. */

   /* w27 <= (w26 * w25) mod p = (u * v) mod p */
   bn.mov   w22, w26
   bn.mov   w23, w25
   jal      x1, fe_mul
   bn.mov   w27, w22
   /* w28 <= (w25^2) mod p = (v^2) mod p */
   bn.mov   w22, w25
   jal      x1, fe_square
   bn.mov   w28, w22
   /* w27 <= (w27 * w28) mod p = (u * v^3) mod p */
   bn.mov   w22, w27
   bn.mov   w23, w28
   jal      x1, fe_mul
   bn.mov   w27, w22
   /* w22 <= (w28^2) mod p = (v^4) mod p */
   bn.mov   w22, w28
   jal      x1, fe_square
   /* w22 <= (w22 * w27) mod p = (u * v^7) mod p */
   bn.mov   w23, w27
   jal      x1, fe_mul
   /* w22 <= (w22^((p-5)/8)) mod p = (u * v^7)^((p-5)/8) mod p */
   bn.mov   w16, w22
   jal      x1, fe_pow_2252m3
   /* w22 <= (w22 * w27) mod p = r */
   bn.mov   w23, w27
   jal      x1, fe_mul

  /* Use the candidate root to derive two possible square roots of x^2. From
     RFC 8032, section 5.1.3, step 3 (with the candidate root again shown as r
     instead of x to avoid confusion):

       Again, there are three cases:
       1.  If v r^2 = u (mod p), r is a square root.
       2.  If v r^2 = -u (mod p), set r <-- r * 2^((p-1)/4), which is a
           square root.
       3.  Otherwise, no square root exists for (u/v) modulo p, and decoding
           fails.

     Again the RFC doesn't really explain the mathematics here. Recall from the
     last step that:
        (u/v) = x^2       if u and v represent a valid y coordinate
        r^4   = (u/v)^2   if (u/v) is square mod p
        r^4   = - (u/v)^2 if (u/v) is nonsquare mod p

     If (u/v) is nonsquare mod p, then it cannot be that (u/v) = x^2, so the
     point cannot be valid. The case-analysis from the RFC refines the
     candidate root so that we reject the nonsquare case, and obtain r such
     that r^2 = x^2.

     The three cases represented in the RFC represent the three possible values
     of r^2 in this situation:
       1. r^2 == (u/v), in which case r^2 = x^2 and we're done.
       2. r^2 == - (u/v), in which case (r * sqrt(-1))^2 = x^2. Since we're
          working modulo p, sqrt(-1) is a real number; 2^((p-1)/4) is indeed a
          valid square root of -1 mod p.
       3. Otherwise, (u/v) is nonsquare and we can reject the point.
  */

  /* Compute (r^2 * v) mod p. */

  /* Save the original r value for later.
        w27 <= w22 = r */
  bn.mov   w27, w22

  /* w22 <= (w22^2) mod p = (r^2) mod p */
  jal      x1, fe_square
  /* w22 <= (w22 * w25) mod p = (r^2 * v) mod p */
  bn.mov   w23, w25
  jal      x1, fe_mul

  /* Check for case 1: (r^2 * v) mod p == u. */

  /* x3 <= 8 */
  addi     x3, x0, 8

  /* FG0.Z <= (w22 - w26 == 0) = ((r^2 * v) mod p == u) */
  bn.cmp   w22, w26
  /* x2 <= FG0[3] = FG0.Z = ((r^2 * v) mod p == u) */
  csrrs    x2, FG0, x0
  and      x2, x2, x3

  /* Go to step 3, case 1 if we are in case 1. */
  beq      x2, x3, decode_step3_case1

  /* Check for case 2: (r^2 * v) mod p == (- u) mod p */

  /* w28 <= (w31 - w26) mod p = (0 - u) mod p */
  bn.subm  w28, w31, w26

  /* FG0.Z <= (w22 - w28 == 0) = ((r^2 * v) mod p == (-u) mod p) */
  bn.cmp   w22, w28
  /* x2 <= FG0[3] = FG0.Z = ((r^2 * v) mod p == (-u) mod p) */
  csrrs    x2, FG0, x0
  and      x2, x2, x3

  /* Go to step 3, case 2 if we are in case 2. */
  beq      x2, x3, decode_step3_case2

  /* If we get here, then r^2 was not equal to either (u/v) or - (u/v), so we
     are in case 3, (u/v) is nonsquare mod p, and point decoding fails. */
  li       x20, 0xeda2bfaf
  bn.mov   w10, w31
  bn.mov   w11, w31
  ret

  decode_step3_case2:
  /* Multiply r by sqrt(-1) = 2^((p-1)/4). */

  /* w23 <= dmem[ed25519_sqrt_m1] = sqrt(-1) mod p */
  la       x2, ed25519_sqrt_m1
  li       x3, 23
  bn.lid   x3, 0(x2)

  /* w27 <= (w27 * w23) mod p = (r * sqrt(-1)) mod p */
  bn.mov   w22, w27
  jal      x1, fe_mul
  bn.mov   w27, w22

  /* From here, r^2 = x^2 and we can proceed with the same steps as case 1. */

  decode_step3_case1:
  /* Once we're here, we know that r^2 = x^2, and therefore r is either x or
     -x. Following RFC 8032, section 5.1.3, step 4, we set the resulting
     point's x coordinate to r if lsb(x) from the encoded point matches lsb(r),
     and set x to (-r) mod p otherwise.

     We also need to check for the special case in which x=0 and lsb(x)=1,
     which we should reject in line with FIPS 186-5.

     Code here expects:
       w24: lsb(x)
       w27: r such that r^2 = x^2 (mod p).
       w31: all-zero
  */

  /* Compute (-r) mod p.
       w10 <= (w31 - w27) mod p = (-r) mod p */
  bn.subm  w10, w31, w27

  /* Set FG.L to be 1 iff the LSBs of r and x are mismatched.
       FG0.L <= lsb(w27 ^ w24) = lsb(r ^ lsb(x)) = (lsb(x) != lsb(r)) */
  bn.xor   w14, w27, w24

  /* If the LSBs are mismatched, select (-r) mod p; otherwise select r.
       w10 <= FG0.L ? w10 : w27
                = if (lsb(x) != lsb(r)) then (-r) mod p else r */
  bn.sel   w10, w10, w27, FG0.L

  /* If the LSBs are still mismatched, then reject the point. This should only
     be possible in the invalid x=0, lsb(x)=1 case. Note that rejecting this
     case is not critical for security. */
  bn.xor   w14, w10, w24
  csrrs    x2, FG0, x0
  andi     x2, x2, 4
  beq      x2, x0, decode_success

  /* Exit with FAILURE. */
  li       x20, 0xeda2bfaf
  bn.mov   w10, w31
  bn.mov   w11, w31
  ret

  decode_success:
  /* TODO: add an extra check that the curve equation is satisfied to protect
     against glitching? */

  /* Exit point decoding with SUCCESS. */
  li       x20, 0xf77fe650
  ret

/**
 * Multiply a point by a scalar in extended twisted Edwards coordinates.
 *
 * Returns (X2, Y2, Z2, T2) = a * (X1, Y1, Z1, T1)
 *
 * This implementation uses a constant-time double-and-add operation, which
 * iterates over the bits of the scalar, computes both the double and
 * double-and-add cases for each, then selects one based on the next scalar
 * bit.
 *
 * Note: To speed up both signing and verification (signing especially), many
 * implementations use a specialized implementation of multiplication by the
 * base point that looks up precomputed values from a table as described in the
 * original Ed25519 paper. However, this raises side-channel concerns because
 * the table lookups would be based on slices of the secret scalar.
 * Additionally, each point is 512 bits (even if stored in affine coordinates)
 * so given limited DMEM space we would only be able to use a maximum of 8
 * lookup values, even assuming we consume all of DMEM.
 *
 * This routine runs in constant time.
 *
 * Flags: Flags have no meaning beyond the scope of this subroutine.
 *
 * @param[in]   w6: input X1 (X1 < p)
 * @param[in]   w7: input Y1 (Y1 < p)
 * @param[in]   w8: input Z1 (Z1 < p)
 * @param[in]   w9: input T1 (T1 < p)
 * @param[in]  w19: constant, w19 = 19
 * @param[in]  w28: a, scalar input, a < L
 * @param[in]  w29: constant, d = (-121665/121666) mod p
 * @param[in]  w30: constant, 38
 * @param[in]  w31: all-zero
 * @param[in]  MOD: p, modulus = 2^255 - 19
 * @param[out] w10: output X2
 * @param[out] w11: output Y2
 * @param[out] w12: output Z2
 * @param[out] w13: output T2
 *
 * clobbered registers: w10 to w18, w20 to w28
 * clobbered flag groups: FG0
 */
.globl ext_scmul
ext_scmul:
  /* Initialize the intermediate result P to the origin point.
       [w13:w10] <= (0, 1, 1, 0) */
  bn.mov   w10, w31
  bn.addi  w11, w31, 1
  bn.addi  w12, w31, 1
  bn.mov   w13, w31

  /* Shift the 253-bit scalar value so the MSB is in position 255.
       w28 <= w28 << 3 = a << 3 */
  bn.rshi  w28, w28, w31 >> 253

  /* Loop over the 253 bits of the scalar a.

     Loop intermediate values:
       P (intermediate result, starts at P = origin)

     Loop invariants (at start of loop iteration i):
       w28 = a << (i + 3)
       [w9:w6] = (X1, Y1, Z1, T1)
       [w13:w10] = P = (a[252:253-i]) * (X1, Y1, Z1, T1)
    */
  loopi  253, 20
    /* Compute 2P = (P + P).
         [w13:w10] <= [w13:w10] + [w13:w10] = 2P  */
    jal      x1, ext_double

    /* Copy the value of the original point (X1, Y1, Z1, T1).
         [w17:w14] <= [w9:w6] = (X1,Y1,Z1,T1) */
    bn.mov   w14, w6
    bn.mov   w15, w7
    bn.mov   w16, w8
    bn.mov   w17, w9

    /* Save the value of 2P for later.
         [w9:w6] <= [w13:w10] = 2P */
    bn.mov   w6, w10
    bn.mov   w7, w11
    bn.mov   w8, w12
    bn.mov   w9, w13

    /* Add the original point to 2P.
         [w13:w10] <= [w13:w10] + [w17:w14] = 2P + (X1, Y1, Z1, T1) */
    jal      x1, ext_add

    /* Set the M flag to the current bit of the scalar.
         FG0.M <= w28[255] = (a << (i + 3))[255] = a[252-i] */
    bn.addi  w28, w28, 0

    /* Select either the double or double-add case.
         [w13:w10] <= FG0.M ? [w10:w13] : [w9:w6]
                    = a[252-i] ? 2P + (X1, Y1, Z1, T1) : 2P
                    = a[252:253-(i+1)] * (X1, Y1, Z1, T1) */
    bn.sel   w10, w10, w6, FG0.M
    bn.sel   w11, w11, w7, FG0.M
    bn.sel   w12, w12, w8, FG0.M
    bn.sel   w13, w13, w9, FG0.M

    /* Restore (X1, Y1, Z1, T1) to original registers.
         [w9:w6] <= [w17:w14] = (X1, Y1, Z1, T1) */
    bn.mov   w6, w14
    bn.mov   w7, w15
    bn.mov   w8, w16
    bn.mov   w9, w17

    /* Shift the scalar value to prepare for the next loop iteration.
         w28 <= w28 >> 1 = a << ((i + 1) + 3) */
    bn.rshi  w28, w28, w31 >> 255

  /* End loop. From the loop invariants, we know
       [w13:w10] = P = a * (X1, Y1, Z1, T1) */
  ret

/**
 * Multiply a point by a scalar in extended twisted Edwards coordinates.
 *
 * Returns (X2, Y2, Z2, T2) = a * (X1, Y1, Z1, T1)
 *
 * Note: To save code size at the cost of verification performance, we could
 * use the constant-time variant instead.
 *
 * This routine runs in variable time.
 *
 * Flags: Flags have no meaning beyond the scope of this subroutine.
 *
 * @param[in]   w6: input X1 (X1 < p)
 * @param[in]   w7: input Y1 (Y1 < p)
 * @param[in]   w8: input Z1 (Z1 < p)
 * @param[in]   w9: input T1 (T1 < p)
 * @param[in]  w19: constant, w19 = 19
 * @param[in]  w28: a, scalar input, a < L
 * @param[in]  w29: constant, d = (-121665/121666) mod p
 * @param[in]  w30: constant, 38
 * @param[in]  w31: all-zero
 * @param[in]  MOD: p, modulus = 2^255 - 19
 * @param[out] w10: output X2
 * @param[out] w11: output Y2
 * @param[out] w12: output Z2
 * @param[out] w13: output T2
 *
 * clobbered registers: w10 to w18, w20 to w28
 * clobbered flag groups: FG0
 */
.globl ext_scmul_var
ext_scmul_var:
  /* Initialize the intermediate result P to the origin point.
       [w13:w10] <= (0, 1, 1, 0) */
  bn.mov   w10, w31
  bn.addi  w11, w31, 1
  bn.addi  w12, w31, 1
  bn.mov   w13, w31

  /* Shift the 253-bit scalar value so the MSB is in position 255.
       w28 <= w28 << 3 = a << 3 */
  bn.rshi  w28, w28, w31 >> 253

  /* Loop over the 253 bits of the scalar a.

     Loop intermediate values:
       P (intermediate result, starts at P = origin)

     Loop invariants (at start of loop iteration i):
       w28 = a << (i + 3)
       [w9:w6] = (X1, Y1, Z1, T1)
       [w13:w10] = P = (a[252:253-i]) * (X1, Y1, Z1, T1)
    */
  loopi  253, 11
    /* Compute 2P = (P + P).
         [w13:w10] <= [w13:w10] + [w13:w10] = 2P  */
    jal      x1, ext_double

    /* Set the M flag to the current bit of the scalar.
         FG0.M <= w28[255] = (a << (i + 3))[255] = a[252-i] */
    bn.addi  w28, w28, 0

    /* Extract the M flag.
         x2 <= FG0[1] << 1 = FG0.M ? 2 : 0 */
    csrrs    x2, FG0, x0
    andi     x2, x2, 2

    /* If the flag is unset (a[252-i] = 0), skip the addition step. */
    beq      x2, x0, _ext_scmul_var_loop_end

    /* Add the original point to 2P.
         [w13:w10] <= [w13:w10] + [w9:w6] = 2P + (X1, Y1, Z1, T1) */
    bn.mov   w14, w6
    bn.mov   w15, w7
    bn.mov   w16, w8
    bn.mov   w17, w9
    jal      x1, ext_add

   _ext_scmul_var_loop_end:
    /* Shift the scalar value to prepare for the next loop iteration.
         w28 <= w28 >> 1 = a << ((i + 1) + 3) */
    bn.rshi  w28, w28, w31 >> 255

  ret

/**
 * Add a point to itself in extended twisted Edwards coordinates.
 *
 * Returns (X3, Y3, Z3, T3) = (X1, Y1, Z1, T1) + (X1, Y1, Z1, T1)
 *
 * This implementation follows RFC 8032, section 5.1.4:
 *   https://datatracker.ietf.org/doc/html/rfc8032#section-5.1.4
 *
 * The formula is:
 *  A = X1^2
 *  B = Y1^2
 *  C = 2*Z1^2
 *  H = A+B
 *  E = H-(X1+Y1)^2
 *  G = A-B
 *  F = C+G
 *  X3 = E*F
 *  Y3 = G*H
 *  T3 = E*H
 *  Z3 = F*G
 *
 * Note: to save code size at the cost of performance, we could use `ext_add`
 * for everything instead.
 *
 * This routine runs in constant time.
 *
 * Flags: Flags have no meaning beyond the scope of this subroutine.
 *
 * @param[in]  w19: constant, w19 = 19
 * @param[in]  w30: constant, 38
 * @param[in]  w31: all-zero
 * @param[in]  MOD: p, modulus = 2^255 - 19
 * @param[in,out] w10: input X1 (X1 < p), output X3
 * @param[in,out] w11: input Y1 (Y1 < p), output Y3
 * @param[in,out] w12: input Z1 (Z1 < p), output Z3
 * @param[in,out] w13: input T1 (T1 < p), output T3
 *
 * clobbered registers: w10 to w18, w20 to w27
 * clobbered flag groups: FG0
 */
.globl ext_double
ext_double:
  /* w24 = (X1^2) = A */
  bn.mov    w22, w10
  jal       x1, fe_square
  bn.mov    w24, w22

  /* w22 <= Y1^2 = B */
  bn.mov    w22, w11
  jal       x1, fe_square

  /* w25 <= A + B = H */
  bn.addm   w25, w24, w22

  /* w24 <= A - B = G */
  bn.subm   w24, w24, w22

  /* w27 <= 2 * (Z1^2) = C */
  bn.mov    w22, w12
  jal       x1, fe_square
  bn.addm   w27, w22, w22

  /* w23 <= H - (X1+Y1)^2 = E */
  bn.addm   w22, w10, w11
  jal       x1, fe_square
  bn.subm   w23, w25, w22

  /* w10 <= (C+G)*E = X3 */
  bn.addm   w22, w27, w24
  jal       x1, fe_mul
  bn.mov    w10, w22

  /* w13 <= H*E = T3 */
  bn.mov    w22, w25
  jal       x1, fe_mul
  bn.mov    w13, w22

  /* w11 <= H*G <= Y3 */
  bn.mov    w22, w25
  bn.mov    w23, w24
  jal       x1, fe_mul
  bn.mov    w11, w22

  /* w12 <= (C+G)*G <= Z3 */
  bn.addm   w22, w27, w24
  jal       x1, fe_mul
  bn.mov    w12, w22

  ret

/**
 * Add two points in extended twisted Edwards coordinates.
 *
 * Returns (X3, Y3, Z3, T3) = (X1, Y1, Z1, T1) + (X2, Y2, Z2, T2)
 *
 * Overwrites the first operand (X1, Y1, Z1, T1) with the result. The second
 * operand is not modified.
 *
 * This implementation closely follows RFC 8032, section 5.1.4:
 *   https://datatracker.ietf.org/doc/html/rfc8032#section-5.1.4
 *
 * A point is represented as 4 integers (X, Y, Z, T) in the field modulo
 * p=2^255-19. As per the RFC, we can compute addition on any two points (X1,
 * Y1, Z1, T1) and (X2, Y2, Z2, T2) with the formula:
 *
 *   A = (Y1-X1)*(Y2-X2)
 *   B = (Y1+X1)*(Y2+X2)
 *   C = T1*2*d*T2
 *   D = Z1*2*Z2
 *   E = B-A
 *   F = D-C
 *   G = D+C
 *   H = B+A
 *   X3 = E*F
 *   Y3 = G*H
 *   T3 = E*H
 *   Z3 = F*G
 *
 * In the formula above, all arithmetic (+, *, -) is modulo p=2^255-19, and the
 * constant d is as described in section 5.1:
 *   https://datatracker.ietf.org/doc/html/rfc8032#section-5.1
 *
 * This routine runs in constant time.
 *
 * Flags: Flags have no meaning beyond the scope of this subroutine.
 *
 * @param[in]  w19: constant, 19
 * @param[in]  MOD: p, modulus = 2^255 - 19
 * @param[in]  w29: constant, d = (-121665/121666) mod p
 * @param[in]  w30: constant, 38
 * @param[in]  w31: all-zero
 * @param[in,out] w10: input X1 (X1 < p), output X3
 * @param[in,out] w11: input Y1 (Y1 < p), output Y3
 * @param[in,out] w12: input Z1 (Z1 < p), output Z3
 * @param[in,out] w13: input T1 (T1 < p), output T3
 * @param[in]     w14: input X2 (X2 < p)
 * @param[in]     w15: input Y2 (Y2 < p)
 * @param[in]     w16: input Z2 (Z2 < p)
 * @param[in]     w17: input T2 (T2 < p)
 *
 * clobbered registers: w10 to w13, w18, w20 to w23, w24 to w27
 * clobbered flag groups: FG0
 */
.globl ext_add
ext_add:
  /* Compute A = (Y1 - X1) * (Y2 - X2). */

  /* w22 <= Y1 - X1 */
  bn.subm  w22, w11, w10
  /* w23 <= Y2 - X2 */
  bn.subm  w23, w15, w14
  /* w22 <= w22 * w23 = A */
  jal      x1, fe_mul
  /* w24 <= w22 = A */
  bn.mov   w24, w22

  /* Compute B = (Y1 + X1) * (Y2 + X2). */

  /* w22 <= Y1 + X1 */
  bn.addm  w22, w11, w10
  /* w23 <= Y2 + X2 */
  bn.addm  w23, w15, w14
  /* w22 <= w22 * w23 = B */
  jal      x1, fe_mul
  /* w25 <= w22 = B */
  bn.mov   w25, w22

  /* Compute C = T1*2*d*T2. */

  /* w22 <= w13 = T1 */
  bn.mov   w22, w13
  /* w23 <= w29 + w29 <= 2*d */
  bn.addm  w23, w29, w29
  /* w22 <= w22 * w23 = T1*2*d */
  jal      x1, fe_mul
  /* w23 <= w17 = T2 */
  bn.mov   w23, w17
  /* w22 <= w22 * w23 = C */
  jal      x1, fe_mul
  /* w26 <= w22 = C */
  bn.mov   w26, w22

  /* Compute D = Z1*2*Z2. */

  /* w22 <= w12 = Z1 */
  bn.mov   w22, w12
  /* w23 <= 2 */
  bn.addi  w23, w31, 2
  /* w22 <= w22 * w23 = Z1*2 */
  jal      x1, fe_mul
  /* w23 <= w16 = Z2 */
  bn.mov   w23, w16
  /* w22 <= w22 * w23 = D */
  jal      x1, fe_mul
  /* w27 <= w22 = D */
  bn.mov   w27, w22

  /* Compute X3 = (B - A) * (D - C). */

  /* w22 <= w25 - w24 = B - A */
  bn.subm  w22, w25, w24
  /* w23 <= w27 - w26 = D - C */
  bn.subm  w23, w27, w26
  /* w22 <= w22 * w23 = X3 */
  jal      x1, fe_mul
  /* w10 <= w22 = X3 */
  bn.mov   w10, w22

  /* Compute Z3 = (D + C) * (D - C). */

  /* w22 <= w27 + w26 = D + C */
  bn.addm  w22, w27, w26
  /* w22 <= w22 * w23 = Z3 */
  jal      x1, fe_mul
  /* w12 <= w22 = Z3 */
  bn.mov   w12, w22

  /* Compute Y3 = (D + C) * (B + A). */

  /* w22 <= w27 + w26 = D + C */
  bn.addm  w22, w27, w26
  /* w23 <= w25 + w24 = B + A */
  bn.addm  w23, w25, w24
  /* w22 <= w22 * w23 = Y3 */
  jal      x1, fe_mul
  /* w11 <= w22 = Y3 */
  bn.mov   w11, w22

  /* Compute T3 = (B - A) * (B + A). */

  /* w22 <= w25 - w24 = B - A */
  bn.subm  w22, w25, w24
  /* w22 <= w22 * w23 = T3 */
  jal      x1, fe_mul
  /* w13 <= w22 = T3 */
  bn.mov   w13, w22

  ret

/**
 * Check if two points in extended coordinates are equal.
 *
 * If the input points (X1, Y1, Z1, T1) and (X2, Y2, Z2, T2) are not equal,
 * this procedure writes FAILURE to dmem[ed25519_verify_result]. If the points
 * are equal, it appends the third and final byte of the SUCCESS magic value to
 * dmem[ed25519_verify_result] by shifting the current value left by 8 and then
 * ORing with the final byte.
 *
 * As per RFC 8032, returns 1 iff:
 *   (X1 * Z2 - X2 * Z1) mod p = 0, and
 *   (Y1 * Z2 - Y2 * Z2) mod p = 0.
 *
 * This routine runs in variable time.
 *
 * @param[in]  w2: input X1 (X1 < p)
 * @param[in]  w3: input Y1 (Y1 < p)
 * @param[in]  w4: input Z1 (Z1 < p)
 * @param[in]  w5: input T1 (T1 < p)
 * @param[in]  w10: input X2 (X2 < p)
 * @param[in]  w11: input Y2 (Y2 < p)
 * @param[in]  w12: input Z2 (Z2 < p)
 * @param[in]  w13: input T2 (T2 < p)
 * @param[in]  w19: constant, w19 = 19
 * @param[in]  w31: all-zero
 * @param[in]  MOD: p, modulus = 2^255 - 19
 * @param[out] dmem[ed25519_verify_result]: result, SUCCESS or FAILURE
 *
 * clobbered registers: w14 to w17
 * clobbered flag groups: FG0
 */
ext_equal_var:
  /* x22 <= FAILURE */
  li       x22, 0xeda2bfaf
  /* x23 <= SUCCESS */
  li       x23, 0xf77fe650

  /* Compute (X1 * Z2). */

  /* w22 <= w2 = X1 */
  bn.mov   w22, w2
  /* w23 <= w12 = Z2 */
  bn.mov   w23, w12
  /* w22 <= w22 * w23 = X1 * Z2 */
  jal      x1, fe_mul
  /* w16 <= w22 <= X1 * Z2 */
  bn.mov   w16, w22

  /* Compute (X2 * Z1). */

  /* w22 <= w10 = X2 */
  bn.mov   w22, w10
  /* w23 <= w4 = Z1 */
  bn.mov   w23, w4
  /* w22 <= w22 * w23 = X2 * Z1 */
  jal      x1, fe_mul

  /* First check. */

  /* w16 <= w16 - w22 <= (X1 * Z2) - (X2 * Z1) */
  bn.sub  w16, w16, w22
  /* x2 <= FG0[3] = FG0.Z << 3 = result of check 1 */
  csrrs    x2, FG0, x0
  andi     x2, x2, 8

  /* Fail if the FG0.Z flag was unset. */
  li       x3, 8
  bne      x2, x3, ext_equal_var_fail

  /* Compute (Y1 * Z2). */

  /* w22 <= w3 = Y1 */
  bn.mov   w22, w3
  /* w23 <= w12 = Z2 */
  bn.mov   w23, w12
  /* w22 <= w22 * w23 = Y1 * Z2 */
  jal      x1, fe_mul
  /* w6 <= w22 <= Y1 * Z2 */
  bn.mov   w16, w22

  /* Compute (Y2 * Z1). */

  /* w22 <= w11 = Y2 */
  bn.mov   w22, w11
  /* w23 <= w4 = Z1 */
  bn.mov   w23, w4
  /* w22 <= w22 * w23 = Y2 * Z1 */
  jal      x1, fe_mul

  /* Second check. */

  /* w16 <= w16 - w22 <= (Y1 * Z2) - (Y2 * Z1) */
  bn.sub  w16, w16, w22
  /* x2 <= FG0[3] = FG0.Z << 3 = result of check 2 */
  csrrs    x2, FG0, x0
  andi     x2, x2, 8

  /* Fail if the FG0.Z flag was unset. */
  li       x3, 8
  bne      x2, x3, ext_equal_var_fail

  /* If we got here, both checks passed; write the SUCCESS value to DMEM.

     TODO: this should be hardened against glitching attacks that simply jump
     to this point in the code, perhaps by separating the SUCCESS code into
     multiple shares that get XORed into the final value at multiple points in
     the successful code path. */

  /* Write the SUCCESS magic value.
       dmem[ed25519_verify_result] <= x23 = SUCCESS */
  la       x4, ed25519_verify_result
  sw       x23, 0(x4)

  ret

  ext_equal_var_fail:
  /* Write the FAILURE magic value.
       dmem[ed25519_verify_result] <= x22 = FAILURE */
  la       x4, ed25519_verify_result
  sw       x22, 0(x4)
  ret

/**
 * Raise a coordinate field element (modulo p) to the power of ((p-5) / 8).
 *
 * Returns c = a^(2^252-3) mod p.
 *
 * This calculation is used during point decoding (see RFC 8032, section
 * 5.1.3):
 *
 * Note: Most of this chain is the same as fe_inv. To save code size, it would
 * be possible to have both fe_inv and this routine share some code. For some
 * performance gains, it may well be possible to find a more efficient chain.
 *
 * This routine runs in constant time.
 *
 * Flags: Flags have no meaning beyond the scope of this subroutine.
 *
 * @param[in]  w19: constant, w19 = 19
 * @param[in]  w16: a, first operand, a < p
 * @param[in]  MOD: p, modulus = 2^255 - 19
 * @param[in]  w31: all-zero
 * @param[out] w22: c, result
 *
 * clobbered registers: w14, w15, w17, w18, w20 to w23
 * clobbered flag groups: FG0
 */
fe_pow_2252m3:
  /* w22 <= w16^2 = a^2 */
  bn.mov  w22, w16
  jal     x1, fe_square
  /* w23 <= w22 = a^2 */
  bn.mov  w23, w22

  /* w22 <= w22^4 = a^8 */
  jal     x1, fe_square
  jal     x1, fe_square

  /* w22 <= w22 * w23 = a^10 */
  jal     x1, fe_mul
  /* w15 <= w22 = a^10 */
  bn.mov  w15, w22

  /* w22 <= w22 * w16 = a^11 */
  bn.mov  w23, w16
  jal     x1, fe_mul
  /* w14 <= w22 <= a^11 */
  bn.mov  w14, w22

  /* w22 <= w15^2 = a^20 */
  bn.mov  w22, w15
  jal     x1, fe_square

  /* w22 <= w22 * w14 = a^31 = a^(2^5 - 1) */
  bn.mov  w23, w14
  jal     x1, fe_mul
  /* w23 <= w22 = a^(2^5 - 1) */
  bn.mov  w23, w22

  /* w22 <= w22^(2^5) = a^(2^10-2^5) */
  loopi   5,2
    jal     x1, fe_square
    nop

  /* w22 <= w22 * w23 = a^(2^10-1) */
  jal     x1, fe_mul
  /* w23 <= w22 <= a^(2^10-1) */
  bn.mov  w23, w22
  /* w15 <= w22 <= a^(2^10-1) */
  bn.mov  w15, w22

  /* w22 <= w22^(2^10) = a^(2^20-2^10) */
  loopi   10,2
    jal     x1, fe_square
    nop

  /* w22 <= w22 * w23 = a^(2^20-1) */
  jal     x1, fe_mul
  /* w23 <= w22 <= a^(2^20-1) */
  bn.mov  w23, w22

  /* w22 <= w22^(2^20) = a^(2^40-2^20) */
  loopi   20,2
    jal     x1, fe_square
    nop

  /* w22 <= w22 * w23 = a^(2^40-1) */
  jal     x1, fe_mul

  /* w22 <= w22^(2^10) = a^(2^50-2^10) */
  loopi   10,2
    jal     x1, fe_square
    nop

  /* w22 <= w22 * w15 = a^(2^50-1) */
  bn.mov  w23, w15
  jal     x1, fe_mul
  /* w23 <= w22 <= a^(2^50-1) */
  bn.mov  w23, w22
  /* w15 <= w22 <= a^(2^50-1) */
  bn.mov  w15, w22

  /* w22 <= w22^(2^50) = a^(2^100-2^50) */
  loopi   50,2
    jal     x1, fe_square
    nop

  /* w22 <= w22 * w23 = a^(2^100-1) */
  jal     x1, fe_mul
  /* w23 <= w22 <= a^(2^100-1) */
  bn.mov  w23, w22

  /* w22 <= w22^(2^100) = a^(2^200-2^100) */
  loopi   100,2
    jal     x1, fe_square
    nop

  /* w22 <= w22 * w23 = a^(2^200-1) */
  jal     x1, fe_mul

  /* w22 <= w22^(2^50) = a^(2^250-2^50) */
  loopi   50,2
    jal     x1, fe_square
    nop

  /* w22 <= w22 * w15 = a^(2^250-1) */
  bn.mov  w23, w15
  jal     x1, fe_mul

  /* w22 <= w22^4 = a^(2^252-2^2) */
  jal     x1, fe_square
  jal     x1, fe_square

  /* w22 <= w22 * w16 = a^(2^252 - 2^2 + 1) = a^(2^252 - 3) */
  bn.mov  w23, w16
  jal     x1, fe_mul

  ret

.section .scratchpad

/* Hash of the secret key (512 bits). Intermediate value for sign. */
.balign 32
.weak ed25519_hash_h
ed25519_hash_h:
  .zero 64

/* Hash value r (512 bits). Intermediate value for sign. */
.balign 32
.weak ed25519_hash_r
ed25519_hash_r:
  .zero 64

.data

/* Affine x coordinate of base point B (see RFC 8032, section 5.1). */
.balign 32
ed25519_Bx:
  .word 0x8f25d51a
  .word 0xc9562d60
  .word 0x9525a7b2
  .word 0x692cc760
  .word 0xfdd6dc5c
  .word 0xc0a4e231
  .word 0xcd6e53fe
  .word 0x216936d3

/* Affine y coordinate of base point B (see RFC 8032, section 5.1). */
.balign 32
ed25519_By:
  .word 0x66666658
  .word 0x66666666
  .word 0x66666666
  .word 0x66666666
  .word 0x66666666
  .word 0x66666666
  .word 0x66666666
  .word 0x66666666

/* Square root of -1 modulo p=2^255-19.
   Equal to (2^((p-1)/4)) mod p. */
.balign 32
ed25519_sqrt_m1:
  .word 0x4a0ea0b0
  .word 0xc4ee1b27
  .word 0xad2fe478
  .word 0x2f431806
  .word 0x3dfbd7a7
  .word 0x2b4d0099
  .word 0x4fc1df0b
  .word 0x2b832480

/* Constant d where d=(-121665/121666) mod p (from RFC 8032 section 5.1) */
.balign 32
ed25519_d:
  .word 0x135978a3
  .word 0x75eb4dca
  .word 0x4141d8ab
  .word 0x00700a4d
  .word 0x7779e898
  .word 0x8cc74079
  .word 0x2b6ffe73
  .word 0x52036cee

/* Ed25519 pre-hash domain separator (256 bits).
     Equal to 'SigEd25519 no Ed25519 collisions' followed by a 1 byte (33 bytes total). */
ed25519_prehash_dom_sep:
  .word 0x45676953
  .word 0x35353264
  .word 0x6e203931
  .word 0x6445206f
  .word 0x31353532
  .word 0x6f632039
  .word 0x73696c6c
  .word 0x736e6f69
  .word 0x00000001

.bss

/* Context string length in bytes for pre-hashed EdDSA */
.balign 4
.weak ed25519_ctx_len
ed25519_ctx_len:
  .zero 4

/* Verification result code (32 bits). Output for verify.
   If verification is successful, this will be SUCCESS = 0xf77fe650.
   Otherwise, this will be FAILURE = 0xeda2bfaf. */
.balign 4
.weak ed25519_verify_result
ed25519_verify_result:
  .zero 4

/* Signature point R (256 bits). Input for verify and output for sign. */
.balign 32
.weak ed25519_sig_R
ed25519_sig_R:
  .zero 32

/* Signature scalar S (253 bits). Input for verify and output for sign. */
.balign 32
.weak ed25519_sig_S
ed25519_sig_S:
  .zero 32

/* Encoded public key A_ (256 bits). Input for verify. */
.balign 32
.weak ed25519_public_key
ed25519_public_key:
  .zero 32

/* Hash value k (512 bits). Input for verify, intermediate for sign. */
.balign 32
.weak ed25519_hash_k
ed25519_hash_k:
  .zero 64

/* Context string for pre-hashed EdDSA (up to 255 bytes).

   Note: If the context length is not a multiple of 32 bytes, the bytes up to
   the next multiple of 32 should be initialized in order to prevent read
   errors. The value of these bytes is ignored. */
.balign 32
.weak ed25519_ctx
ed25519_ctx:
  .zero 256

/* Message (pre-hashed, 64 bytes). */
.balign 32
.weak ed25519_message
ed25519_message:
  .zero 64
