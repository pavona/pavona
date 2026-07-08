/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * Test for check_pk, the FIPS 203 Section 7.2 modulus check on the ML-KEM
 * encapsulation key. Exercises a valid public key (must pass) and public keys
 * with an out-of-range coefficient (must be rejected). The number of incorrect
 * results is accumulated in w0, which must be zero on success.
 */

/* Hardened boolean values. Should match the values in `hardened_asm.h`. */
.equ HARDENED_BOOL_TRUE, 0x739
.equ HARDENED_BOOL_FALSE, 0x1d4

.section .text.start

main:
  bn.xor w31, w31, w31   /* all-zero register */
  bn.xor w3, w3, w3      /* w3 = failure counter (check_pk clobbers w0-w2,w4) */

  /* Test 1: a valid public key (all coefficients 0 < q) must return TRUE. */
  li  x14, 4
  la  x12, valid_pk
  jal x1, check_pk
  addi x5, x0, HARDENED_BOOL_TRUE
  beq  x10, x5, _t1_ok
  bn.addi w3, w3, 1
_t1_ok:

  /* Test 2: a coefficient equal to q must return FALSE. */
  li  x14, 4
  la  x12, invalid_pk_eq
  jal x1, check_pk
  addi x5, x0, HARDENED_BOOL_FALSE
  beq  x10, x5, _t2_ok
  bn.addi w3, w3, 1
_t2_ok:

  /* Test 3: a coefficient greater than q must return FALSE. */
  li  x14, 4
  la  x12, invalid_pk_gt
  jal x1, check_pk
  addi x5, x0, HARDENED_BOOL_FALSE
  beq  x10, x5, _t3_ok
  bn.addi w3, w3, 1
_t3_ok:

  /* Test 4: a bad coefficient in the last polynomial must return FALSE. */
  li  x14, 4
  la  x12, invalid_pk_last
  jal x1, check_pk
  addi x5, x0, HARDENED_BOOL_FALSE
  beq  x10, x5, _t4_ok
  bn.addi w3, w3, 1
_t4_ok:

  /* Report the failure count in w0. */
  bn.mov w0, w3
  ecall

.data
/* K=4 (ML-KEM-1024): each polyvec is 4*256 coefficients = 2048 bytes. */
.balign 32
valid_pk:
  .zero 2048

.balign 32
invalid_pk_eq:
  .word 0x00000d01   /* first coefficient = q = 3329 */
  .zero 2044

.balign 32
invalid_pk_gt:
  .word 0x00000fff   /* first coefficient = 4095 > q */
  .zero 2044

.balign 32
invalid_pk_last:
  .zero 2016
  .word 0x00000d01   /* last word, first coefficient = q = 3329 */
  .zero 28
