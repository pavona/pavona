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
 * Name:        crypto_kem_enc
 *
 * Description: Generates cipher text and shared
 *              secret for given public key
 *
 * Arguments:   - uint8_t *ct: pointer to output cipher text
 *                (an already allocated array of KYBER_CIPHERTEXTBYTES bytes)
 *              - uint8_t *ss: pointer to output shared secret
 *                (an already allocated array of KYBER_SSBYTES bytes)
 *              - const uint8_t *pk: pointer to input public key
 *                (an already allocated array of KYBER_PUBLICKEYBYTES bytes)
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  dmem[coins]: input random bytes (32)
 * @param[out] dmem[ct]: output ciphertext
 * @param[out] dmem[ss]: output shared secret
 * @param[in]  dmem[ek]: input public key
 * @param[in]  x14: KYBER_K
 *
 * clobbered registers: x4 to x29, w0 to w31, acc, acch, mod
 * clobbered flag groups: FG0
 */
.globl crypto_kem_enc
crypto_kem_enc:

  /*** hash_h(pk) ***/
  la      a0, ek
  /* a1 = KYBER_PUBLICKEYBYTES = KYBER_K * 384 + 32 */
  slli    a1, x14, 7
  slli    t0, x14, 8
  add     a1, a1, t0
  addi    a1, a1, 32
  slli    t0, a1, 5
  addi    t0, t0, SHA3_256_CFG
  csrrw   x0, KECCAK_CFG_REG, t0
  jal     x1, keccak_send_message
  bn.wsrr w8, kmac_digest

  /*** Set up for hash_g(randombytes||hash_h(pk)) ***/
  addi  a1, x0, 64
  slli  t0, a1, 5
  addi  t0, t0, SHA3_512_CFG
  csrrw x0, KECCAK_CFG_REG, t0

  /* Send the message. */
  la      t0, coins
  bn.lid  x0, 0(t0)
  bn.wsrw kmac_msg, w0
  bn.wsrw kmac_msg, w8

  /* Read the digest. */
  la      t0, ss
  bn.wsrr w0, kmac_digest
  bn.sid  x0, 0(t0)
  la      a2, indcpa_enc_seed
  bn.wsrr w0, kmac_digest
  bn.sid  x0, 0(a2)

  /*** indcpa_enc ***/
  la   a0, coins
  la   a1, ek
  la   a3, ct
  jal  x1, indcpa_enc

  ret

.bss

/* Intermediate buffer to store the 64-byte hash result. */
.balign 32
indcpa_enc_seed:
.zero 64
