/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */
/* Modified by Ruben Niederhagen and Hoang Nguyen Hien Pham - authors of */
/* "Improving ML-KEM & ML-DSA on OpenTitan - Efficient Multiplication Vector Instructions for OTBN" */
/* (https://eprint.iacr.org/2025/2028) */
/* Copyright Ruben Niederhagen and Hoang Nguyen Hien Pham. */

.text
/* Register aliases */
.equ x0, zero
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

/* Index of the Keccak command special register. */
#define KECCAK_CFG_REG 0x7d9
/* Config to start a SHAKE-128 operation. */
#define SHAKE128_CFG 0x2
/* Config to start a SHAKE-256 operation. */
#define SHAKE256_CFG 0xA
/* Config to start a SHA3_256 operation. */
#define SHA3_256_CFG 0x8
/* Config to start a SHA3_512 operation. */
#define SHA3_512_CFG 0x10

/*
 * Name:        poly_gen_matrix_init
 *
 * Description: Initialze a SHAKE128 operation to prepare for rejection sampling
 *              on uniform random bytes using `poly_gen_matrix`.
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  a0: pointer to seed (KYBER_SYMBYTES = 32)
 * @param[in]  w30: i||j (2 bytes)
 *
 * clobbered registers: a0, t0, w0
 */

.globl poly_gen_matrix_init
poly_gen_matrix_init:
  /* Initialize a SHAKE128 operation. */
  addi  t0, zero, 34
  slli  t0, t0, 5
  addi  t0, t0, SHAKE128_CFG
  csrrw zero, KECCAK_CFG_REG, t0

  /* Send the message to the Keccak core. */
  bn.lid x0, 0(a0)             /* a0 still contains the input buffer */
  bn.wsrw 0x9, w0              /* Write to KECCAK_MSG_REG */
  bn.wsrw 0x9, w30             /* Write to KECCAK_MSG_REG */

  ret

/*
 * Name:        poly_gen_matrix
 *
 * Description: Run rejection sampling on uniform random bytes to generate
 *              uniform random integers mod q
 *
 * Arguments:   - int16_t *r: pointer to output buffer
 *              - unsigned int len: requested number of 16-bit integers (uniform mod q)
 *              - const uint8_t *buf: pointer to input buffer (assumed to be uniformly random bytes)
 *              - unsigned int buflen: length of input buffer in bytes
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  a0: pointer to seed (KYBER_SYMBYTES = 32)
 * @param[out] a1: dmem pointer to polynomial
 *
 * clobbered registers: a0-a5, t0-s4, w8, w14
 */

.globl poly_gen_matrix
poly_gen_matrix:
  /* 32 byte align the sp */
  andi a5, sp, 31
  beq  a5, zero, _aligned
  sub  sp, sp, a5
_aligned:
  /* save fp to stack, use 32 bytes to keep it 32-byte aligned */
  addi sp, sp, -32
  sw   fp, 0(sp)

  addi fp, sp, 0

  /* Adjust sp to accomodate local variables */
  addi sp, sp, -64

  /* Space for tmp buffer to hold a WDR */
  #define STACK_WDR2GPR -32

  /* t0 = 508, a1 + 508 is the last valid address */
  addi t0, a1, 512

  /* Compare for flag bits */
  li a6, 3

  /* For masking coeff with 0xFFF */
  bn.xor bn0, bn0, bn0
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
  /* Loop until 256 coefficients have been written to the output */
_rej_sample_loop:
  /* First squeeze */
  .equ w8, shake_reg
  bn.wsrr shake_reg, 0xA /* KECCAK_DIGEST */

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
  bn.rshi    cand, shake_reg, bn0 >> 16     /* Move remaining 2 bytes to the top of cand */
  bn.wsrr    shake_reg, 0xA                 /* Squeeze KECCAK_DIGEST */
  bn.rshi    cand, shake_reg, cand >> 240   /* Get one more byte from new shake data*/
  bn.rshi    shake_reg, bn0, shake_reg >> 8 /* Shift out used byte in shake_reg */

  /* mask candidate */
  bn.and     wtmp, coeff_mask, cand
  bn.cmp     wtmp, mod
  csrrs      a4, 0x7C0, zero       /* Read flags */
  andi       a4, a4, 1             /* Mask carry flag to detect underflow */
  bn.rshi    accumulator_new, wtmp, accumulator >> 16
  bn.sel     accumulator, accumulator_new, accumulator, FG0.C
  sub        accumulator_count, accumulator_count, a4 /* Move to next slot iff not rejected */
  bne        accumulator_count, zero, _skip_store2a
  bn.sid     s4, 0(a1++)           /* Store to memory */
  li         accumulator_count, 16 /* Set all slots to available */
  /* if we have written the last coefficient, exit */
  beq        a1, t0, _end_rej_sample_loop
_skip_store2a:
  bn.rshi    cand, bn0, cand >> 12
  bn.and     cand, coeff_mask, cand
  bn.cmp     cand, mod
  csrrs      a4, 0x7C0, zero      /* Read flags */
  andi       a4, a4, 1            /* Mask carry flag to detect underflow */
  bn.rshi    accumulator_new, cand, accumulator >> 16
  bn.sel     accumulator, accumulator_new, accumulator, FG0.C
  sub        accumulator_count, accumulator_count, a4 /* Move to next slot iff not rejected */
  bne        accumulator_count, zero, _skip_store2
  bn.sid     s4, 0(a1++)           /* Store to memory */
  li         accumulator_count, 16 /* Set all slots to available */

  /* if we have written the last coefficient, exit */
  beq        a1, t0, _end_rej_sample_loop
_skip_store2:
  jal        x1, _poly_uniform_inner_loop /* Process floor(31/3)*3 = 30 bytes */
  beq        a1, t0, _end_rej_sample_loop /* Check if we have finished in the previous loop */

  /* 1 byte of second squeeze + 2 bytes of third squeeze */
  bn.rshi    cand, shake_reg, bn0 >> 8       /* move remaining 1 byte to the top of cand */
  bn.wsrr    shake_reg, 0xA                  /* Squeeze KECCAK_DIGEST */
  bn.rshi    cand, shake_reg, cand >> 248    /* Get one 2 more bytes from new shake data */
  bn.rshi    shake_reg, bn0, shake_reg >> 16 /* Shift out used 2 bytes */

  /* mask candidate */
  bn.and     wtmp, coeff_mask, cand
  bn.cmp     wtmp, mod
  csrrs      a4, 0x7C0, zero       /* Read flags */
  andi       a4, a4, 1             /* Mask carry flag to detect underflow */
  bn.rshi    accumulator_new, wtmp, accumulator >> 16
  bn.sel     accumulator, accumulator_new, accumulator, FG0.C
  sub        accumulator_count, accumulator_count, a4 /* Move to next slot iff not rejected */
  bne        accumulator_count, zero, _skip_store4a
  bn.sid     s4, 0(a1++)           /* Store to memory */
  li         accumulator_count, 16 /* Set all slots to available */

  /* if we have written the last coefficient, exit */
  beq        a1, t0, _end_rej_sample_loop
_skip_store4a:
  bn.rshi    cand, bn0, cand >> 12
  bn.and     cand, coeff_mask, cand
  bn.cmp     cand, mod
  csrrs      a4, 0x7C0, zero       /* Read flags */
  andi       a4, a4, 1             /* Mask carry flag to detect underflow */
  bn.rshi    accumulator_new, cand, accumulator >> 16
  bn.sel     accumulator, accumulator_new, accumulator, FG0.C
  sub        accumulator_count, accumulator_count, a4 /* Move to next slot iff not rejected */
  bne        accumulator_count, zero, _skip_store4
  bn.sid     s4, 0(a1++)           /* Store to memory */
  li         accumulator_count, 16 /* Set all slots to available */
  /* if we have written the last coefficient, exit */
  beq        a1, t0, _end_rej_sample_loop
_skip_store4:
  jal        x1, _poly_uniform_inner_loop /* Process floor(30/3)*3 = 30 bytes */
  beq        a1, t0, _end_rej_sample_loop /* Check if we have finished in the previous loop */

  /* No remainder! Start all over again. */
  beq        zero, zero, _rej_sample_loop
_end_rej_sample_loop:

  addi       sp, fp, 0 /* sp <- fp */
  lw         fp, 0(sp)   /* Pop ebp */
  addi       sp, sp, 32
  add        sp, sp, a5 /* Correct alignment offset (unalign) */

  ret

_poly_uniform_inner_loop:
  /* Skip the per-iteration total coefficient count checks in this hot loop if
     we have more than 20 candidates remaining. */
  sub        t2, a1, t0  /* Get -(number of bytes remaining to write out) */
  addi       t2, t2, 64  /* Add 64 bytes = 2 wide words >= 20 coeffs */
  sra        t2, t2, 31  /* Fill register with resulting sign bit */
  bne        t2, zero, _fast_inner_loop  /* _fast_inner_loop skips checks of t0 */

  loopi 20, 12
    beq        a1, t0, _skip_store1

    /* Get the candidate coefficient */
    bn.and     cand, coeff_mask, shake_reg
    bn.cmp     cand, mod
    csrrs      a4, 0x7C0, zero /* Read flags */

    /* Add it to the accumulator if not rejected */
    andi a4, a4, 1 /* Mask carry flag to detect underflow */
    bn.rshi    accumulator_new, cand, accumulator >> 16
    bn.sel     accumulator, accumulator_new, accumulator, FG0.C
    sub        accumulator_count, accumulator_count, a4 /* Move to next slot iff not rejected */
    bne        accumulator_count, zero, _skip_store1    /* Accumulator not full yet */
    bn.sid     s4, 0(a1++)                              /* Store to memory */
    li         accumulator_count, 16                    /* Set all slots to available */
_skip_store1:
    /* Shift out the 12 bits we have read for the next potential coefficient */
    bn.rshi    shake_reg, bn0, shake_reg >> 12

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
    csrrs      a4, 0x7C0, zero /* Read flags */

    /* Add it to the accumulator if not rejected */
    andi       a4, a4, 1 /* Mask carry flag to detect underflow */
    bn.rshi    accumulator_new, cand, accumulator >> 16
    bn.sel     accumulator, accumulator_new, accumulator, FG0.C
    sub        accumulator_count, accumulator_count, a4 /* Move to next slot iff not rejected */
    /* Shift out the 12 bits we have read for the next potential coefficient */
    bn.rshi    shake_reg, bn0, shake_reg >> 12

  /* Possibly flush accumulator if we filled it (~3% of time) */
  bne        accumulator_count, zero, _handle_rest
  bn.sid     s4, 0(a1++)           /* Store to memory */
  li         accumulator_count, 16 /* Set all slots to available */

_handle_rest:
  loop cand_count, 11
    /* Get the candidate coefficient */
    bn.and     cand, coeff_mask, shake_reg
    bn.cmp     cand, mod
    csrrs      a4, 0x7C0, zero /* Read flags */

    /* Add it to the accumulator if not rejected */
    andi a4, a4, 1 /* Mask carry flag to detect underflow */
    bn.rshi    accumulator_new, cand, accumulator >> 16
    bn.sel     accumulator, accumulator_new, accumulator, FG0.C
    sub        accumulator_count, accumulator_count, a4   /* Move to next slot iff not rejected */
    bne        accumulator_count, zero, _skip_store1_fast /* Accumulator not full yet */
    bn.sid     s4, 0(a1++)                                /* Store to memory */
    li         accumulator_count, 16                      /* Set all slots to available */
_skip_store1_fast:
    /* Shift out the 12 bits we have read for the next potential coefficient */
    bn.rshi    shake_reg, bn0, shake_reg >> 12

  ret
