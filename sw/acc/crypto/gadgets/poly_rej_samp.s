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

#ifndef TEST
  #define TEST 0
#endif

#ifndef SCHEME
  #define SCHEME 0
#endif

#if SCHEME == 1

.equ x2,  sp
.equ x5,  t0
.equ x6,  t1
.equ x7,  t2
.equ x10, a0
.equ x14, a4

/*
 * Name: poly_rej_samp (ML-DSA)
 *
 * Return 256 coefficients uniform in [0, q), q = 8380417, packed 8 * 32-bit
 * per WDR (= 32 WDRs = 1024 bytes).  Source: URND.
 *
 * Lane-parallel rejection: each iteration draws one URND, masks to 23 bits
 * per lane, and accepts the WDR iff all 8 lanes are < q.  Per-lane reject
 * probability is ~0.1% at q/2^23, so ~0.8% of WDRs need a redraw.
 *
 * @param[in]      a0: ptr_r, dmem pointer to output polynomial (1024 bytes)
 * @param[in]  w31: all-zero
 *
 * The caller / link must provide `modulus_bn` as 8 * 0x007FE001 packed.
 */
.globl poly_rej_samp
poly_rej_samp:
    /* w11 = 0x007FFFFF * 8 (23-bit per-lane mask). */
    bn.not  w11, w31
    bn.rshi w11, w31, w11 >> 233
    bn.or   w11, w11, w11 << 32
    bn.or   w11, w11, w11 << 64
    bn.or   w11, w11, w11 << 128

    /* w13 = 0xFF000000 * 8 (top byte of each 32-bit lane). */
    bn.shv.8S w13, w11 << 24

    /* w12 = q * 8. */
    li      t0, 12
    la      t1, modulus_bn
    bn.lid  t0, 0(t1)

    li      t0, 14
    li      t2, 32

_prs_mldsa_retry:
    bn.wsrr    w14, URND
    bn.and     w14, w14, w11
    bn.subv.8S w15, w14, w12
    bn.and     w15, w15, w13
    bn.cmp     w15, w13
    csrrs      a4, 0x7C0, x0
    andi       a4, a4, 8
    beq        a4, x0, _prs_mldsa_retry
    bn.sid     t0, 0(a0++)
    addi       t2, t2, -1
    bne        t2, x0, _prs_mldsa_retry
    ret

#else

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

.equ w31, bn0

/*
 * Name: poly_rej_samp
 *
 * Return a polynomial of wrandom coefficients mod q, obtained by running
 * rejection sampling on uniform wrandom bytes from URND.
 * TODO: Is RND good enough?
 *
 * Flags: TODO.
 *
 * @param[out] a0: ptr_r, dmem pointer to output polynomial
 *
 * clobbered registers: TODO
 * clobbered flag groups: TODO
 */

.globl poly_rej_samp
poly_rej_samp:
  /* save fp to stack, use 32 bytes to keep it 32-byte aligned */
  addi sp, sp, -32
  sw   fp, 0(sp)
  addi fp, sp, 0

  /* All-x0 register. */
  bn.xor bn0, bn0, bn0

  /* t0 = 508, a0 + 508 is the last valid address */
  addi t0, a0, 512

  /* For masking coeff with 0xFFF */
  #define coeff_mask w10
  bn.addi coeff_mask, bn0, 1
  bn.rshi coeff_mask, coeff_mask, bn0 >> 244
  bn.subi coeff_mask, coeff_mask, 1

  #define cand w11
  #define mod w12
  li      s2, 12
  la      t1, modulus_bn
  bn.lid  s2, 0(t1)
  bn.rshi mod, bn0, mod >> 240 /* Only keep mod in lowest word */

  #define accumulator w13
  li s4, 13
  #define accumulator_count s5
  li s5, 16  /* Counts number of remaining accumulator slots */

  #define wtmp w14
  #define accumulator_new w17

#if TEST == 1
  li x4, 8
#endif

  /* Loop until 256 coefficients have been written to the output */
_rej_sample_loop:
  #define wrandom w8

#if TEST == 0
  bn.wsrr    wrandom, URND
#else
  bn.lid     x4, 0(a1++)
#endif

  jal        x1, _poly_rej_samp_inner_loop /* Process floor(32 bytes / 3 bytes) * 3 bytes = 30 bytes */
  beq        a0, t0, _end_rej_sample_loop /* Check if we have finished in the previous loop */

  /* 2 bytes of first squeeze + 1 byte of second squeeze */
  bn.rshi    cand, wrandom, bn0 >> 16 /* Move remaining 2 bytes to the top of cand */
#if TEST == 0
  bn.wsrr    wrandom, URND /* Squeeze KECCAK_DIGEST */
#else
  bn.lid     x4, 0(a1++)
#endif
  bn.rshi    cand, wrandom, cand >> 240 /* Get one more byte from new shake data*/
  bn.rshi    wrandom, bn0, wrandom >> 8 /* Shift out used byte in wrandom */

  /* mask candidate */
  bn.and     wtmp, coeff_mask, cand
  bn.cmp     wtmp, mod
  csrrs      a4, 0x7C0, x0 /* Read flags */
  andi       a4, a4, 1 /* Mask carry flag to detect underflow */
  bn.rshi    accumulator_new, wtmp, accumulator >> 16
  bn.sel     accumulator, accumulator_new, accumulator, FG0.C
  sub        accumulator_count, accumulator_count, a4 /* Move to next slot iff not rejected */
  bne        accumulator_count, x0, _skip_store2a
  bn.sid     s4, 0(a0++) /* Store to memory */
  li         accumulator_count, 16 /* Set all slots to available */
  /* if we have written the last coefficient, exit */
  beq        a0, t0, _end_rej_sample_loop
_skip_store2a:
  bn.rshi    cand, bn0, cand >> 12
  bn.and     cand, coeff_mask, cand
  bn.cmp     cand, mod
  csrrs      a4, 0x7C0, x0 /* Read flags */
  andi       a4, a4, 1 /* Mask carry flag to detect underflow */
  bn.rshi    accumulator_new, cand, accumulator >> 16
  bn.sel     accumulator, accumulator_new, accumulator, FG0.C
  sub        accumulator_count, accumulator_count, a4 /* Move to next slot iff not rejected */
  bne        accumulator_count, x0, _skip_store2
  bn.sid     s4, 0(a0++) /* Store to memory */
  li         accumulator_count, 16 /* Set all slots to available */

  /* if we have written the last coefficient, exit */
  beq        a0, t0, _end_rej_sample_loop
_skip_store2:
  jal        x1, _poly_rej_samp_inner_loop /* Process floor(31/3)*3 = 30 bytes */
  beq        a0, t0, _end_rej_sample_loop /* Check if we have finished in the previous loop */

  /* 1 byte of second squeeze + 2 bytes of third squeeze */
  bn.rshi    cand, wrandom, bn0 >> 8 /* move remaining 1 byte to the top of cand */
#if TEST == 0
  bn.wsrr    wrandom, URND
#else
  bn.lid     x4, 0(a1++)
#endif
  bn.rshi    cand, wrandom, cand >> 248 /* Get one 2 more bytes from new shake data */
  bn.rshi    wrandom, bn0, wrandom >> 16 /* Shift out used 2 bytes */

  /* mask candidate */
  bn.and     wtmp, coeff_mask, cand
  bn.cmp     wtmp, mod
  csrrs      a4, 0x7C0, x0 /* Read flags */
  andi       a4, a4, 1 /* Mask carry flag to detect underflow */
  bn.rshi    accumulator_new, wtmp, accumulator >> 16
  bn.sel     accumulator, accumulator_new, accumulator, FG0.C
  sub        accumulator_count, accumulator_count, a4 /* Move to next slot iff not rejected */
  bne        accumulator_count, x0, _skip_store4a
  bn.sid     s4, 0(a0++) /* Store to memory */
  li         accumulator_count, 16 /* Set all slots to available */

  /* if we have written the last coefficient, exit */
  beq        a0, t0, _end_rej_sample_loop
_skip_store4a:
  bn.rshi    cand, bn0, cand >> 12
  bn.and     cand, coeff_mask, cand
  bn.cmp     cand, mod
  csrrs      a4, 0x7C0, x0 /* Read flags */
  andi       a4, a4, 1 /* Mask carry flag to detect underflow */
  bn.rshi    accumulator_new, cand, accumulator >> 16
  bn.sel     accumulator, accumulator_new, accumulator, FG0.C
  sub        accumulator_count, accumulator_count, a4 /* Move to next slot iff not rejected */
  bne        accumulator_count, x0, _skip_store4
  bn.sid     s4, 0(a0++) /* Store to memory */
  li         accumulator_count, 16 /* Set all slots to available */
  /* if we have written the last coefficient, exit */
  beq        a0, t0, _end_rej_sample_loop
_skip_store4:
  jal        x1, _poly_rej_samp_inner_loop /* Process floor(30/3)*3 = 30 bytes */
  beq        a0, t0, _end_rej_sample_loop /* Check if we have finished in the previous loop */

  /* No remainder! Start all over again. */
  beq        x0, x0, _rej_sample_loop
_end_rej_sample_loop:
  addi       sp, fp, 0
  lw         fp, 0(sp)
  addi       sp, sp, 32
  ret

_poly_rej_samp_inner_loop:
  /* Skip the per-iteration total coefficient count checks in this hot loop if
     we have more than 20 candidates remaining. */
  sub        t2, a0, t0 /* Get -(number of bytes remaining to write out) */
  addi       t2, t2, 64 /* Add 64 bytes = 2 wide words >= 20 coeffs */
  sra        t2, t2, 31 /* Fill register with resulting sign bit */
  bne        t2, x0, _fast_inner_loop  /* _fast_inner_loop skips checks of t0 */
  loopi 20, 12
    beq      a0, t0, _skip_store1
    /* Get the candidate coefficient */
    bn.and   cand, coeff_mask, wrandom
    bn.cmp   cand, mod
    csrrs    a4, 0x7C0, x0 /* Read flags */

    /* Add it to the accumulator if not rejected */
    andi     a4, a4, 1 /* Mask carry flag to detect underflow */
    bn.rshi  accumulator_new, cand, accumulator >> 16
    bn.sel   accumulator, accumulator_new, accumulator, FG0.C
    sub      accumulator_count, accumulator_count, a4 /* Move to next slot iff not rejected */
    bne      accumulator_count, x0, _skip_store1 /* Accumulator not full yet */
    bn.sid   s4, 0(a0++) /* Store to memory */
    li       accumulator_count, 16 /* Set all slots to available */
_skip_store1:
    /* Shift out the 12 bits we have read for the next potential coefficient */
    bn.rshi  wrandom, bn0, wrandom >> 12
  ret

_fast_inner_loop:
  #define cand_count t2
  li cand_count, 20

  /* Eagerly fill the accumulator (fine since 16 < 20) */
  sub       cand_count, cand_count, accumulator_count
  loop accumulator_count, 8
    /* Get the candidate coefficient */
    bn.and  cand, coeff_mask, wrandom
    bn.cmp  cand, mod
    csrrs   a4, 0x7C0, x0 /* Read flags */

    /* Add it to the accumulator if not rejected */
    andi    a4, a4, 1 /* Mask carry flag to detect underflow */
    bn.rshi accumulator_new, cand, accumulator >> 16
    bn.sel  accumulator, accumulator_new, accumulator, FG0.C
    sub     accumulator_count, accumulator_count, a4 /* Move to next slot iff not rejected */
    /* Shift out the 12 bits we have read for the next potential coefficient */
    bn.rshi wrandom, bn0, wrandom >> 12

  /* Possibly flush accumulator if we filled it (~3% of time) */
  bne    accumulator_count, x0, _handle_rest
  bn.sid s4, 0(a0++) /* Store to memory */
  li     accumulator_count, 16 /* Set all slots to available */

_handle_rest:
  loop cand_count, 11
    /* Get the candidate coefficient */
    bn.and   cand, coeff_mask, wrandom
    bn.cmp   cand, mod
    csrrs    a4, 0x7C0, x0 /* Read flags */

    /* Add it to the accumulator if not rejected */
    andi     a4, a4, 1 /* Mask carry flag to detect underflow */
    bn.rshi  accumulator_new, cand, accumulator >> 16
    bn.sel   accumulator, accumulator_new, accumulator, FG0.C
    sub      accumulator_count, accumulator_count, a4 /* Move to next slot iff not rejected */
    bne      accumulator_count, x0, _skip_store1_fast /* Accumulator not full yet */
    bn.sid   s4, 0(a0++) /* Store to memory */
    li       accumulator_count, 16 /* Set all slots to available */
_skip_store1_fast:
    /* Shift out the 12 bits we have read for the next potential coefficient */
    bn.rshi  wrandom, bn0, wrandom >> 12

  ret

#endif /* SCHEME == 1 */
