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

/* Register aliases */
.equ x2, sp
.equ x3, fp
.equ x5, t0
.equ x6, t1
.equ x7, t2
.equ x8, s0
.equ x9, s1
.equ x10, a0
.equ x11, a1
.equ x12, a2
.equ x13, a3
.equ x14, a4
.equ x15, a5
.equ x16, a6
.equ x17, a7
.equ x18, s2
.equ x19, s3
.equ x20, s4
.equ x21, s5
.equ x22, s6
.equ x23, s7
.equ x24, s8
.equ x25, s9
.equ x26, s10
.equ x27, s11
.equ x28, t3
.equ x29, t4
.equ x30, t5
.equ x31, t6


/* Config to start a SHAKE-128 operation. */
#define SHAKE128_CFG 0x2

/*
 * Name:        poly_gen_matrix_init
 *
 * Description: Initialze a SHAKE128 operation to prepare for rejection sampling
 *              on uniform random bytes using `poly_gen_matrix`.
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  a0: pointer to seed (KYBER_SYMBYTES = 32)
 * @param[in]  a1: pointer to i||j (2 bytes)
 *
 * clobbered registers: x5, w0
 * clobbered flag groups: none
 */

.globl poly_gen_matrix_init
.type poly_gen_matrix_init, @function
poly_gen_matrix_init:
  /* Initialize a SHAKE128 operation. */
  addi  t0, x0, 34
  slli  t0, t0, 5
  addi  t0, t0, SHAKE128_CFG
  csrrw x0, kmac_cfg, t0

  /* Send the message to the Keccak core. */
  bn.lid  x0, 0(a0)
  bn.wsrw kmac_msg, w0
  li      t0, 2
  csrrw   x0, kmac_partial_write, t0
  bn.lid  x0, 0(a1)
  bn.wsrw kmac_msg, w0
  ret

/*
 * Name:        poly_gen_matrix
 *
 * Description: Run rejection sampling on uniform random bytes to generate
 *              256 uniform random integers mod q; this function assumes
 *              `poly_gen_matrix_init` has been called first with the
 *              appropriate seed and indices
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[out] a1: dmem pointer to polynomial
 * @param[in]  kmac_digest: SHAKE-128 squeeze set up by poly_gen_matrix_init
 * @param[in]  w31: all-zero register
 *
 * clobbered registers: x5 to x7, x11, x14, x16, x18, x20 to x21, w8, w10 to w14, w17, w31
 * clobbered flag groups: FG0
 */

.globl poly_gen_matrix
.type poly_gen_matrix, @function
poly_gen_matrix:
  /* t0 = 508, a1 + 508 is the last valid address */
  addi t0, a1, 512

  #define accumulator w0
  #define coeff_mask w1
  #define cand w2
  #define mod w3
  #define wtmp w4
  #define accumulator_new w5
  #define shake_reg w6
  #define accumulator_count t1

  /* Geenrate constant 0x0fff. */
  bn.addi coeff_mask, w31, 1
  bn.rshi coeff_mask, coeff_mask, w31 >> 244
  bn.subi coeff_mask, coeff_mask, 1

  /* Load modulus. */
  li      x4, 3
  la      t1, modulus_bn
  bn.lid  x4, 0(t1)
  bn.rshi mod, w31, mod >> 240 /* Only keep mod in lowest word */

  /* Counts number of remaining accumulator slots */
  li accumulator_count, 16

  /* Loop until 256 coefficients have been written to the output */
_rej_sample_loop:
  /* First squeeze */
  bn.wsrr shake_reg, kmac_digest

  /* With one SHAKE squeeze, we get 32 bytes of data. From this, we can try to
    build 20 coefficients with 3 bytes each two (3 bytes --> 2 coeffs) and are left with 2 bytes
    remainder. We then take the two remaining bytes and one byte from the
    next squeeze operation and try to get another 2 coefficient, leaving us
    with 31 bytes from which we can, again, try to read 20 coefficients and
    are left with 1 byte remainder. From the next 32 bytes, we take 2 bytes
    and try to build 2 coefficients with the remaining 1 byte. Finally, we
    are left with 30 bytes which we can try to turn into 20 coefficients
    without any remainder. lcm(3, 32) = 96, meaning we use 96 bytes of SHAKE
    output each (full) iteration of the main loop. In case we reach the
    target amount of coefficients, we jump to _end_rej_sample_loop and exit. */

  jal        x1, _poly_uniform_inner_loop /* Process floor(32 bytes / 3 bytes) * 3 bytes = 30 bytes */
  beq        a1, t0, _end_rej_sample_loop /* Check if we have finished in the previous loop */

  /* 2 bytes of first squeeze + 1 byte of second squeeze */
  bn.rshi    cand, shake_reg, w31 >> 16     /* Move remaining 2 bytes to the top of cand */
  bn.wsrr    shake_reg, kmac_digest                 /* Squeeze KECCAK_DIGEST */
  bn.rshi    cand, shake_reg, cand >> 240   /* Get one more byte from new shake data*/
  bn.rshi    shake_reg, w31, shake_reg >> 8 /* Shift out used byte in shake_reg */

  /* mask candidate */
  bn.and     wtmp, coeff_mask, cand
  bn.cmp     wtmp, mod
  csrrs      t3, fg0, x0       /* Read flags */
  andi       t3, t3, 1             /* Mask carry flag to detect underflow */
  bn.rshi    accumulator_new, wtmp, accumulator >> 16
  bn.sel     accumulator, accumulator_new, accumulator, FG0.C
  sub        accumulator_count, accumulator_count, t3 /* Move to next slot iff not rejected */
  bne        accumulator_count, x0, _skip_store2a
  bn.sid     x0, 0(a1++)           /* Store to memory */
  li         accumulator_count, 16 /* Set all slots to available */
  /* if we have written the last coefficient, exit */
  beq        a1, t0, _end_rej_sample_loop
_skip_store2a:
  bn.rshi    cand, w31, cand >> 12
  bn.and     cand, coeff_mask, cand
  bn.cmp     cand, mod
  csrrs      t3, fg0, x0      /* Read flags */
  andi       t3, t3, 1            /* Mask carry flag to detect underflow */
  bn.rshi    accumulator_new, cand, accumulator >> 16
  bn.sel     accumulator, accumulator_new, accumulator, FG0.C
  sub        accumulator_count, accumulator_count, t3 /* Move to next slot iff not rejected */
  bne        accumulator_count, x0, _skip_store2
  bn.sid     x0, 0(a1++)           /* Store to memory */
  li         accumulator_count, 16 /* Set all slots to available */

  /* if we have written the last coefficient, exit */
  beq        a1, t0, _end_rej_sample_loop
_skip_store2:
  jal        x1, _poly_uniform_inner_loop /* Process floor(31/3)*3 = 30 bytes */
  beq        a1, t0, _end_rej_sample_loop /* Check if we have finished in the previous loop */

  /* 1 byte of second squeeze + 2 bytes of third squeeze */
  bn.rshi    cand, shake_reg, w31 >> 8       /* move remaining 1 byte to the top of cand */
  bn.wsrr    shake_reg, kmac_digest                  /* Squeeze KECCAK_DIGEST */
  bn.rshi    cand, shake_reg, cand >> 248    /* Get one 2 more bytes from new shake data */
  bn.rshi    shake_reg, w31, shake_reg >> 16 /* Shift out used 2 bytes */

  /* mask candidate */
  bn.and     wtmp, coeff_mask, cand
  bn.cmp     wtmp, mod
  csrrs      t3, fg0, x0       /* Read flags */
  andi       t3, t3, 1             /* Mask carry flag to detect underflow */
  bn.rshi    accumulator_new, wtmp, accumulator >> 16
  bn.sel     accumulator, accumulator_new, accumulator, FG0.C
  sub        accumulator_count, accumulator_count, t3 /* Move to next slot iff not rejected */
  bne        accumulator_count, x0, _skip_store4a
  bn.sid     x0, 0(a1++)           /* Store to memory */
  li         accumulator_count, 16 /* Set all slots to available */

  /* if we have written the last coefficient, exit */
  beq        a1, t0, _end_rej_sample_loop
_skip_store4a:
  bn.rshi    cand, w31, cand >> 12
  bn.and     cand, coeff_mask, cand
  bn.cmp     cand, mod
  csrrs      t3, fg0, x0       /* Read flags */
  andi       t3, t3, 1             /* Mask carry flag to detect underflow */
  bn.rshi    accumulator_new, cand, accumulator >> 16
  bn.sel     accumulator, accumulator_new, accumulator, FG0.C
  sub        accumulator_count, accumulator_count, t3 /* Move to next slot iff not rejected */
  bne        accumulator_count, x0, _skip_store4
  bn.sid     x0, 0(a1++)           /* Store to memory */
  li         accumulator_count, 16 /* Set all slots to available */
  /* if we have written the last coefficient, exit */
  beq        a1, t0, _end_rej_sample_loop
_skip_store4:
  jal        x1, _poly_uniform_inner_loop /* Process floor(30/3)*3 = 30 bytes */
  beq        a1, t0, _end_rej_sample_loop /* Check if we have finished in the previous loop */

  /* No remainder! Start all over again. */
  beq        x0, x0, _rej_sample_loop
_end_rej_sample_loop:

  ret

_poly_uniform_inner_loop:
  /* Skip the per-iteration total coefficient count checks in this hot loop if
     we have more than 20 candidates remaining. */
  sub        t2, a1, t0  /* Get -(number of bytes remaining to write out) */
  addi       t2, t2, 64  /* Add 64 bytes = 2 wide words >= 20 coeffs */
  sra        t2, t2, 31  /* Fill register with resulting sign bit */
  bne        t2, x0, _fast_inner_loop  /* _fast_inner_loop skips checks of t0 */

  loopi 20, 12
    beq        a1, t0, _skip_store1

    /* Get the candidate coefficient */
    bn.and     cand, coeff_mask, shake_reg
    bn.cmp     cand, mod
    csrrs      t3, fg0, x0 /* Read flags */

    /* Add it to the accumulator if not rejected */
    andi       t3, t3, 1 /* Mask carry flag to detect underflow */
    bn.rshi    accumulator_new, cand, accumulator >> 16
    bn.sel     accumulator, accumulator_new, accumulator, FG0.C
    sub        accumulator_count, accumulator_count, t3 /* Move to next slot iff not rejected */
    bne        accumulator_count, x0, _skip_store1    /* Accumulator not full yet */
    bn.sid     x0, 0(a1++)                              /* Store to memory */
    li         accumulator_count, 16                    /* Set all slots to available */
_skip_store1:
    /* Shift out the 12 bits we have read for the next potential coefficient */
    bn.rshi    shake_reg, w31, shake_reg >> 12
  endloop

  ret

_fast_inner_loop:
  #define cand_count t2
  li cand_count, 20

  /* Eagerly fill the accumulator (fine since 16 < 20) */
  sub cand_count, cand_count, accumulator_count
  loop accumulator_count, 8
    /* Get the candidate coefficient */
    bn.and     cand, coeff_mask, shake_reg
    bn.cmp     cand, mod
    csrrs      t3, fg0, x0 /* Read flags */

    /* Add it to the accumulator if not rejected */
    andi       t3, t3, 1 /* Mask carry flag to detect underflow */
    bn.rshi    accumulator_new, cand, accumulator >> 16
    bn.sel     accumulator, accumulator_new, accumulator, FG0.C
    sub        accumulator_count, accumulator_count, t3 /* Move to next slot iff not rejected */
    /* Shift out the 12 bits we have read for the next potential coefficient */
    bn.rshi    shake_reg, w31, shake_reg >> 12
  endloop

  /* Possibly flush accumulator if we filled it (~3% of time) */
  bne        accumulator_count, x0, _handle_rest
  bn.sid     x0, 0(a1++)           /* Store to memory */
  li         accumulator_count, 16 /* Set all slots to available */

_handle_rest:
  loop cand_count, 11
    /* Get the candidate coefficient */
    bn.and     cand, coeff_mask, shake_reg
    bn.cmp     cand, mod
    csrrs      t3, fg0, x0 /* Read flags */

    /* Add it to the accumulator if not rejected */
    andi       t3, t3, 1 /* Mask carry flag to detect underflow */
    bn.rshi    accumulator_new, cand, accumulator >> 16
    bn.sel     accumulator, accumulator_new, accumulator, FG0.C
    sub        accumulator_count, accumulator_count, t3   /* Move to next slot iff not rejected */
    bne        accumulator_count, x0, _skip_store1_fast /* Accumulator not full yet */
    bn.sid     x0, 0(a1++)                                /* Store to memory */
    li         accumulator_count, 16                      /* Set all slots to available */
_skip_store1_fast:
    /* Shift out the 12 bits we have read for the next potential coefficient */
    bn.rshi    shake_reg, w31, shake_reg >> 12
  endloop

  ret
