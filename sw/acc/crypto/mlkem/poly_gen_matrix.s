/* Copyright zeroRISC Inc. */
/* Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192). */
/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors. */
/* Modified by Ruben Niederhagen and Hoang Nguyen Hien Pham - authors of */
/* "Improving ML-KEM & ML-DSA on OpenTitan - Efficient Multiplication Vector Instructions for OTBN" */
/* (https://eprint.iacr.org/2025/2028). */
/* Copyright Ruben Niederhagen and Hoang Nguyen Hien Pham. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

/* Config to start a SHAKE-128 operation. */
#define SHAKE128_CFG 0x2

/**
 * Initialization of the SHAKE-128 operation for poly_gen_matrix.
 *
 * Configure a SHAKE-128 operation for a 34-byte message and absorb
 * seed || i || j, so that a subsequent call to `poly_gen_matrix` can squeeze
 * the bytes it rejection-samples from.
 *
 * This routine is constant time.
 *
 * @param[in]  x10: dmem pointer to the seed (KYBER_SYMBYTES = 32 bytes)
 * @param[in]  x11: dmem pointer to the matrix indices i || j (2 bytes)
 *
 * clobbered registers: x5, w0
 * clobbered flag groups: none
 */

.globl poly_gen_matrix_init
.type poly_gen_matrix_init, @function
poly_gen_matrix_init:
  /* Initialize a SHAKE128 operation. */
  addi  x5, x0, 34
  slli  x5, x5, 5
  addi  x5, x5, SHAKE128_CFG
  csrrw x0, kmac_cfg, x5

  /* Send the message to the Keccak core. */
  bn.lid  x0, 0(x10)
  bn.wsrw kmac_msg, w0
  li      x5, 2
  csrrw   x0, kmac_partial_write, x5
  bn.lid  x0, 0(x11)
  bn.wsrw kmac_msg, w0
  ret

/**
 * Rejection sampling of one entry of the matrix A.
 *
 * Squeeze uniformly random bytes and rejection-sample them into 256
 * coefficients that are uniform over Z_q for q = 3329, keeping every 12-bit
 * value below q and discarding the rest. Assumes that `poly_gen_matrix_init`
 * has been called beforehand with the appropriate seed and matrix indices.
 *
 * On return, x11 has been advanced by one polynomial (512 bytes).
 *
 * @param[out] x11: dmem pointer to the output polynomial
 * @param[in]  kmac_digest: SHAKE-128 squeeze set up by poly_gen_matrix_init
 * @param[in]  w31: all-zero register
 *
 * clobbered registers: x4 to x7, x11, x28, w0 to w6
 * clobbered flag groups: FG0
 */

.globl poly_gen_matrix
.type poly_gen_matrix, @function
poly_gen_matrix:
  /* dptr_r + 512 is the last valid address. */
  addi x5, x11, 512

  #define accumulator w0
  #define coeff_mask w1
  #define cand w2
  #define mod w3
  #define wtmp w4
  #define accumulator_new w5
  #define shake_reg w6
  #define accumulator_count x6
  #define cand_count x7

  /* Generate constant 0x0fff. */
  bn.addi coeff_mask, w31, 1
  bn.rshi coeff_mask, coeff_mask, w31 >> 244
  bn.subi coeff_mask, coeff_mask, 1

  /* Load modulus. */
  li      x4, 3
  la      x6, const_q
  bn.lid  x4, 0(x6)
  bn.rshi mod, w31, mod >> 240 /* Only keep mod in lowest word */

  /* Counts number of remaining accumulator slots. */
  li accumulator_count, 16

  /* Loop until 256 coefficients have been written to the output. */
_rej_sample_loop:
  /* Each candidate coefficient is 12 bits wide, so 3 bytes yield 2
   * candidates, while one SHAKE squeeze yields 32 bytes. Since 3 does not
   * divide 32, the split of a squeeze into candidates shifts by one byte
   * every time, and the pattern only repeats after lcm(3, 32) = 96 bytes.
   * One full iteration of this loop therefore consumes three squeezes and
   * produces 96 / 3 * 2 = 64 candidates:
   *
   *   squeeze 1: 30 bytes                    -> 20 candidates, 2 bytes left
   *   carry:      2 bytes + 1 byte of next   ->  2 candidates
   *   squeeze 2: 30 of the remaining 31      -> 20 candidates, 1 byte left
   *   carry:      1 byte  + 2 bytes of next  ->  2 candidates
   *   squeeze 3: the remaining 30 bytes      -> 20 candidates, none left
   *
   * A candidate is only accepted if it is smaller than q, so the number of
   * coefficients actually written out is smaller and varies. As soon as 256
   * coefficients have been written, we leave via _end_rej_sample_loop. */
  bn.wsrr    shake_reg, kmac_digest
  jal        x1, _poly_uniform_inner_loop
  beq        x11, x5, _end_rej_sample_loop

  /* 2 bytes of first squeeze + 1 byte of second squeeze. */
  bn.rshi    cand, shake_reg, w31 >> 16
  bn.wsrr    shake_reg, kmac_digest
  bn.rshi    cand, shake_reg, cand >> 240
  bn.rshi    shake_reg, w31, shake_reg >> 8

  bn.and     wtmp, coeff_mask, cand
  bn.cmp     wtmp, mod
  csrrs      x28, fg0, x0 /* Read flags. */
  andi       x28, x28, 1  /* Mask carry flag to detect underflow. */
  bn.rshi    accumulator_new, wtmp, accumulator >> 16
  bn.sel     accumulator, accumulator_new, accumulator, FG0.C
  sub        accumulator_count, accumulator_count, x28 /* Move to next slot iff not rejected. */
  bne        accumulator_count, x0, _skip_store2a
  bn.sid     x0, 0(x11++)
  li         accumulator_count, 16 /* Set all slots to available. */
  beq        x11, x5, _end_rej_sample_loop

_skip_store2a:
  bn.rshi    cand, w31, cand >> 12
  bn.and     cand, coeff_mask, cand
  bn.cmp     cand, mod
  csrrs      x28, fg0, x0
  andi       x28, x28, 1
  bn.rshi    accumulator_new, cand, accumulator >> 16
  bn.sel     accumulator, accumulator_new, accumulator, FG0.C
  sub        accumulator_count, accumulator_count, x28
  bne        accumulator_count, x0, _skip_store2
  bn.sid     x0, 0(x11++)
  li         accumulator_count, 16
  beq        x11, x5, _end_rej_sample_loop

_skip_store2:
  jal        x1, _poly_uniform_inner_loop
  beq        x11, x5, _end_rej_sample_loop

  /* 1 byte of second squeeze + 2 bytes of third squeeze. */
  bn.rshi    cand, shake_reg, w31 >> 8
  bn.wsrr    shake_reg, kmac_digest
  bn.rshi    cand, shake_reg, cand >> 248
  bn.rshi    shake_reg, w31, shake_reg >> 16

  bn.and     wtmp, coeff_mask, cand
  bn.cmp     wtmp, mod
  csrrs      x28, fg0, x0
  andi       x28, x28, 1
  bn.rshi    accumulator_new, wtmp, accumulator >> 16
  bn.sel     accumulator, accumulator_new, accumulator, FG0.C
  sub        accumulator_count, accumulator_count, x28
  bne        accumulator_count, x0, _skip_store4a
  bn.sid     x0, 0(x11++)
  li         accumulator_count, 16
  beq        x11, x5, _end_rej_sample_loop

_skip_store4a:
  bn.rshi    cand, w31, cand >> 12
  bn.and     cand, coeff_mask, cand
  bn.cmp     cand, mod
  csrrs      x28, fg0, x0
  andi       x28, x28, 1
  bn.rshi    accumulator_new, cand, accumulator >> 16
  bn.sel     accumulator, accumulator_new, accumulator, FG0.C
  sub        accumulator_count, accumulator_count, x28
  bne        accumulator_count, x0, _skip_store4
  bn.sid     x0, 0(x11++)
  li         accumulator_count, 16
  beq        x11, x5, _end_rej_sample_loop

_skip_store4:
  jal        x1, _poly_uniform_inner_loop
  beq        x11, x5, _end_rej_sample_loop
  beq        x0, x0, _rej_sample_loop

_end_rej_sample_loop:
  ret

_poly_uniform_inner_loop:
  /* Skip the per-iteration total coefficient count checks in this hot loop if
   * we have more than 20 candidates remaining. */
  sub  x7, x11, x5               /* Get -(number of bytes remaining to write out). */
  addi x7, x7, 64                /* Add 64 bytes = 2 wide words >= 20 coeffs. */
  sra  x7, x7, 31                /* Fill register with resulting sign bit. */
  bne  x7, x0, _fast_inner_loop  /* _fast_inner_loop skips checks of x5. */

  loopi 20, 12
    beq      x11, x5, _skip_store1
    bn.and   cand, coeff_mask, shake_reg
    bn.cmp   cand, mod
    csrrs    x28, fg0, x0
    andi     x28, x28, 1
    bn.rshi  accumulator_new, cand, accumulator >> 16
    bn.sel   accumulator, accumulator_new, accumulator, FG0.C
    sub      accumulator_count, accumulator_count, x28
    bne      accumulator_count, x0, _skip_store1
    bn.sid   x0, 0(x11++)
    li       accumulator_count, 16
  _skip_store1:
    bn.rshi  shake_reg, w31, shake_reg >> 12 /* Shift out used 12 bits. */
  endloop
  ret

_fast_inner_loop:
  /* Eagerly fill the accumulator (fine since 16 < 20). */
  li  cand_count, 20
  sub cand_count, cand_count, accumulator_count
  loop accumulator_count, 8
    bn.and     cand, coeff_mask, shake_reg
    bn.cmp     cand, mod
    csrrs      x28, fg0, x0
    andi       x28, x28, 1
    bn.rshi    accumulator_new, cand, accumulator >> 16
    bn.sel     accumulator, accumulator_new, accumulator, FG0.C
    sub        accumulator_count, accumulator_count, x28
    bn.rshi    shake_reg, w31, shake_reg >> 12
  endloop

  /* Possibly flush accumulator if we filled it (~3% of time). */
  bne    accumulator_count, x0, _handle_rest
  bn.sid x0, 0(x11++)
  li     accumulator_count, 16

_handle_rest:
  loop cand_count, 11
    bn.and     cand, coeff_mask, shake_reg
    bn.cmp     cand, mod
    csrrs      x28, fg0, x0
    andi       x28, x28, 1
    bn.rshi    accumulator_new, cand, accumulator >> 16
    bn.sel     accumulator, accumulator_new, accumulator, FG0.C
    sub        accumulator_count, accumulator_count, x28
    bne        accumulator_count, x0, _skip_store1_fast
    bn.sid     x0, 0(x11++)
    li         accumulator_count, 16
  _skip_store1_fast:
    bn.rshi    shake_reg, w31, shake_reg >> 12
  endloop
  ret
