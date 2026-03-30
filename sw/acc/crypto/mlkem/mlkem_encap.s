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

#define KYBER_N 256
#define KYBER_Q 3329
#define KYBER_SYMBYTES 32   /* size in bytes of hashes, and seeds */
#define KYBER_SSBYTES  32   /* size in bytes of shared key */
#define KYBER_POLYBYTES		384
#define KYBER_ETA2 2
#if (KYBER_K == 2)
  #define KYBER_POLYVECBYTES	768
  #define KYBER_POLYCOMPRESSEDBYTES    128
  #define KYBER_POLYVECCOMPRESSEDBYTES 640
  #define KYBER_ETA1 3

  #define KYBER_INDCPA_MSGBYTES       32
  #define KYBER_INDCPA_PUBLICKEYBYTES 800
  #define KYBER_INDCPA_SECRETKEYBYTES 768
  #define KYBER_INDCPA_BYTES          768

  #define KYBER_PUBLICKEYBYTES  800
  /* 32 bytes of additional space to save H(pk) */
  #define KYBER_SECRETKEYBYTES  1632
  #define KYBER_CIPHERTEXTBYTES 768

  #define KYBER_INDCPA_PUBLICKEYBYTES_WRS 25
  #define KYBER_CIPHERTEXT_WRS 24
  #define KYBER_GEN_MATRIX_NONCE 254
  #define KYBER_GEN_MATRIX_AT_NONCE -511
  #define KYBER_GEN_MATRIX_AT_NONCE_NEG 511
  #define POLY -512
  #define K_POLYS -1024
  #define K_SQUARED_POLYS -2048

#elif (KYBER_K == 3)
  #define KYBER_POLYVECBYTES	1152
  #define KYBER_POLYCOMPRESSEDBYTES    128
  #define KYBER_POLYVECCOMPRESSEDBYTES 960
  #define KYBER_ETA1 2

  #define KYBER_INDCPA_MSGBYTES       32
  #define KYBER_INDCPA_PUBLICKEYBYTES 1184
  #define KYBER_INDCPA_SECRETKEYBYTES 1152
  #define KYBER_INDCPA_BYTES          1088

  #define KYBER_PUBLICKEYBYTES  1184
  /* 32 bytes of additional space to save H(pk) */
  #define KYBER_SECRETKEYBYTES  2400
  #define KYBER_CIPHERTEXTBYTES 1088

  #define KYBER_INDCPA_PUBLICKEYBYTES_WRS 37
  #define KYBER_CIPHERTEXT_WRS 34
  #define KYBER_GEN_MATRIX_NONCE 253
  #define KYBER_GEN_MATRIX_AT_NONCE -767
  #define KYBER_GEN_MATRIX_AT_NONCE_NEG 767
  #define POLY -512
  #define K_POLYS -1536
  #define K_SQUARED_POLYS -4608

#elif (KYBER_K == 4)
  #define KYBER_POLYVECBYTES	1536
  #define KYBER_POLYCOMPRESSEDBYTES    160
  #define KYBER_POLYVECCOMPRESSEDBYTES 1408
  #define KYBER_ETA1 2

  #define KYBER_INDCPA_MSGBYTES       32
  #define KYBER_INDCPA_PUBLICKEYBYTES 1568
  #define KYBER_INDCPA_SECRETKEYBYTES 1536
  #define KYBER_INDCPA_BYTES          1568

  #define KYBER_PUBLICKEYBYTES  1568
  /* 32 bytes of additional space to save H(pk) */
  #define KYBER_SECRETKEYBYTES  3168
  #define KYBER_CIPHERTEXTBYTES 1568

  #define KYBER_INDCPA_PUBLICKEYBYTES_WRS 49
  #define KYBER_CIPHERTEXT_WRS 49
  #define KYBER_GEN_MATRIX_NONCE 252
  #define KYBER_GEN_MATRIX_AT_NONCE -1023
  #define KYBER_GEN_MATRIX_AT_NONCE_NEG 1023
  #define POLY -512
  #define K_POLYS -2048
  #define K_SQUARED_POLYS -8192
#endif

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
 * @param[in]  x10 (a0): dmem pointer to input randombytes (KYBER_SYMBYTES = 32)
 * @param[out] x11 (a1): dmem pointer to output ct
 * @param[out] x12 (a2): dmem pointer to output key_b
 * @param[in]  x13 (a3): dmem pointer to input pk
 *
 * clobbered registers: a0-a4, t0-t5, w8, w16
 */

.globl crypto_kem_enc
crypto_kem_enc:
  #define STACK_KEM_ENC_KEYB_ADDR -20
  #define STACK_KEM_ENC_PK_ADDR   -24
  #define STACK_KEM_ENC_CT_ADDR   -32
  #define STACK_KEM_ENC_BUF     -1120
  #define STACK_KEM_ENC_KR      -1056

  /* Set frame pointer */
  addi fp, sp, 0
#if KYBER_K == 2
    li  t0, -3168
#elif KYBER_K == 3
    li  t0, -4192
#elif KYBER_K == 4
    li  t0, -5216
#endif
  add  sp, sp, t0

  /* Save parameters to stack */
  sw a1, STACK_KEM_ENC_CT_ADDR(fp)
  sw a2, STACK_KEM_ENC_KEYB_ADDR(fp)
  sw a3, STACK_KEM_ENC_PK_ADDR(fp)

  /*** Copy randombytes to buf ***/
  li     x4, 0
  bn.lid x4, 0(a0)
  li     t0, STACK_KEM_ENC_BUF
  add    t0, fp, t0
  bn.sid x4, 0(t0++)
  add    a3, zero, t0

  /*** hash_h(pk) ***/
  lw      a0, STACK_KEM_ENC_PK_ADDR(fp)
  addi    a1, zero, KYBER_PUBLICKEYBYTES
  slli    t0, a1, 5
  addi    t0, t0, SHA3_256_CFG
  csrrw   zero, KECCAK_CFG_REG, t0
  jal     x1, keccak_send_message
  li      t0, 8
  bn.wsrr w8, 0xA /* KECCAK_DIGEST */
  bn.sid  t0, 0(a3++) /* Store into buffer */

  /*** hash_g(randombytes||hash_h(pk)) ***/
  addi  a0, a3, -64
  lw    a3, STACK_KEM_ENC_KEYB_ADDR(fp)
  addi  a1, zero, 64
  slli  t0, a1, 5
  addi  t0, t0, SHA3_512_CFG
  csrrw zero, KECCAK_CFG_REG, t0
  jal   x1, keccak_send_message
  li    t0, 8
  LOOPI 2, 2
    bn.wsrr w8, 0xA /* KECCAK_DIGEST */
    bn.sid  t0, 0(a3++) /* Store into buffer */

  /*** indcpa_enc ***/
  add a0, a0, -64 /* randombytes = m */
  add a2, a3, -32 /* r */
  jal x1, indcpa_enc

  /* Free space on stack */
  addi sp, fp, 0

  ret
