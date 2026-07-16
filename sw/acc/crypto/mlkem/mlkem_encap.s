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


/* Config to start a SHA3_256 operation. */
#define SHA3_256_CFG 0x8
/* Config to start a SHA3_512 operation. */
#define SHA3_512_CFG 0x10

/*
 * Name:        crypto_kem_enc
 *
 * Description: Generates cipher text and shared
 *              secret for given public key
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10 (a0): dmem pointer to input random bytes (32)
 * @param[in]  x11 (a1): dmem pointer to input public key
 * @param[out] x12 (a2): dmem pointer to output ciphertext
 * @param[out] x13 (a3): dmem pointer to output shared secret
 * @param[in]  x14 (a4): k, the security level
 *
 * clobbered registers: x4 to x29, w0 to w31, acc, acch, mod
 * clobbered flag groups: FG0
 */
.globl crypto_kem_enc
.type crypto_kem_enc, @function
crypto_kem_enc:
  addi x4, x0, 2
  beq  a4, x4, _pk_len_k2
  addi x4, x0, 3
  beq  a4, x4, _pk_len_k3
  addi t0, x0, 1568
  beq  x0, x0, _continue
_pk_len_k3:
  addi t0, x0, 1184
  beq  x0, x0, _continue
_pk_len_k2:
  addi t0, x0, 800

_continue:
  /* Save input addresses. */
  add s0, a0, x0
  add s1, a1, x0

  /* Compute H(pk). */
  add     a0, a1, x0 /* a1 = ptr_pk */
  add     a1, t0, x0
  slli    t0, a1, 5
  addi    t0, t0, SHA3_256_CFG
  csrrw   x0, kmac_cfg, t0
  jal     x1, keccak_send_message
  bn.wsrr w1, kmac_digest

  /* Compute hash_g(coins||H(pk)). ***/
  addi  a1, x0, 64
  slli  t0, a1, 5
  addi  t0, t0, SHA3_512_CFG
  csrrw x0, kmac_cfg, t0

  /* Send the message. */
  add     t0, s0, x0
  bn.lid  x0, 0(t0)
  bn.wsrw kmac_msg, w0
  bn.wsrw kmac_msg, w1

  /* Read the digest. */
  bn.wsrr w0, kmac_digest
  bn.sid  x0, 0(a3)
  la      t0, indcpa_enc_seed
  bn.wsrr w0, kmac_digest
  bn.sid  x0, 0(t0)

  /*** indcpa_enc ***/
  add  a0, s0, x0 /* coins */
  add  a1, s1, x0 /* pk */
  add  a3, a2, x0 /* ct */
  la   a2, indcpa_enc_seed
  /* a4 is still k. */
  jal  x1, indcpa_enc

  ret
