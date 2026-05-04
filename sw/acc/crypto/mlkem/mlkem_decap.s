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

#define POLY -512

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
 * Name:        indcpa_dec
 *
 * Description: Decryption function of the CPA-secure
 *              public-key encryption scheme underlying Kyber.
 *
 * Arguments:   - uint8_t *m: pointer to output decrypted message
 *                            (of length KYBER_INDCPA_MSGBYTES)
 *              - const uint8_t *c: pointer to input ciphertext
 *                                  (of length KYBER_INDCPA_BYTES)
 *              - const uint8_t *sk: pointer to input secret key
 *                                   (of length KYBER_INDCPA_SECRETKEYBYTES)
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10 (a0): dmem pointer to input ciphertext
 * @param[in]  x11 (a1): dmem pointer to input packed sk
 * @param[out] x13 (a3): dmem pointer to output message
 * @param[in]  x14: KYBER_K
 *
 * clobbered registers: a0-a4, t0-t5, w8, w16
 */
.globl indcpa_dec
indcpa_dec:
  /* Stack layout (worst-case K=4). V and SKPV follow B contiguously:
   *   STACK_DEC_B + K*512    : poly v
   *   STACK_DEC_B + (K+1)*512: secret key polyvec */
  #define STACK_DEC_M_ADDR     -32
  #define STACK_DEC_B        -4640

  /* Store parameters to stack */
  sw a3, STACK_DEC_M_ADDR(fp)

  /*** unpack_ciphertext ***/
  li  a2, STACK_DEC_B
  add a2, fp, a2
  la  a3, const_8
  la  a5, const_0x0fff
  jal x1, unpack_ciphertext

  /*** unpack_sk ***/
  jal x1, unpack_sk

  bn.wsrr   w16, 0x0 /* w16 = R | Q */
  bn.shv.8S w0, w16 << 1 /* w0 = 2*R | 2*Q */
  bn.wsrw   0x0, w0 /* MOD = 2*R | 2*Q */
  /*** NTT ***/
  li  a0, STACK_DEC_B
  add a0, fp, a0
  la  a1, twiddles_ntt
  add a2, zero, a0
  /* K iterations */
  LOOP x14, 2
    jal x1, ntt
    nop

  /* After NTT, w16 is still R | Q and MOD is still 2*R | 2*Q */
  /*** Vector vector multiplication ***/
  /* x29 = a0 - K * 512 */
  slli t0, x14, 9
  sub  x29, a0, t0
  addi a1, a2, 512
  add  a3, zero, x29
  la   x28, twiddles_basemul
  jal  x1, basemul
  /* K-1 iterations */
  addi t0, x14, -1
  LOOP t0, 5
    addi a3, a3, POLY
    la   x28, twiddles_basemul
    jal  x1, basemul_acc
    nop

  /* After basemul, w16 is still R | Q and MOD is still 2*R | 2*Q */
  /*** INTT ***/
  /* a0 -= K * 512 */
  slli t0, x14, 9
  sub  a0, a0, t0
  la      a1, twiddles_intt
  add     a2, zero, a0
  jal     x1, intt
  bn.wsrw 0x0, w16 /* Restore MOD = R | Q */

  /*** SUB ***/
  li   a0, STACK_DEC_B
  add  a0, fp, a0
  slli t0, x14, 9
  add  a0, a0, t0
  addi a1, a2, POLY
  addi a2, a2, POLY
  jal  x1, poly_sub

  /*** poly_tomsg ***/
  addi a0, a1, POLY
  la   a1, modulus_over_2
  lw   a2, STACK_DEC_M_ADDR(fp)
  la   a3, const_1290167
  jal  x1, poly_tomsg

  ret

/*
 * Name:        crypto_kem_dec
 *
 * Description: Generates shared secret for given
 *              cipher text and private key
 *
 * Arguments:   - uint8_t *ss: pointer to output shared secret
 *                (an already allocated array of KYBER_SSBYTES bytes)
 *              - const uint8_t *ct: pointer to input cipher text
 *                (an already allocated array of KYBER_CIPHERTEXTBYTES bytes)
 *              - const uint8_t *sk: pointer to input private key
 *                (an already allocated array of KYBER_SECRETKEYBYTES bytes)
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10 (a0): dmem pointer to input ct
 * @param[in]  x11 (a1): dmem pointer to input sk
 * @param[out] x12 (a2): dmem pointer to output key_a
 * @param[in]  x14: KYBER_K
 *
 * clobbered registers: a0-a4, t0-t5, w8, w16
 */
.globl crypto_kem_dec
crypto_kem_dec:
  #define STACK_KEM_DEC_KEYA_ADDR -8
  #define STACK_KEM_DEC_H_ADDR   -12
  #define STACK_KEM_DEC_SK_ADDR  -16
  #define STACK_KEM_DEC_CT_ADDR  -20
  #define STACK_KEM_DEC_PK_ADDR  -24
  #define STACK_KEM_DEC_CMP_ADDR -32
  /* Worst-case (K=4) stack offsets */
  #define STACK_KEM_DEC_KR     -5280
  #define STACK_KEM_DEC_BUF    -5344
  #define STACK_KEM_DEC_CMP    -3168
  /* Set frame pointer */
  addi fp, sp, 0
  li   t0, -5344
  add  sp, sp, t0

  /* Save parameters to stack */
  sw   a0, STACK_KEM_DEC_CT_ADDR(fp)
  sw   a1, STACK_KEM_DEC_SK_ADDR(fp)
  /* t1 = K * 384 (size of sk = size of pk minus 32-byte seed) */
  slli t0, x14, 7
  slli t1, x14, 8
  add  t1, t1, t0
  add  t0, a1, t1
  sw   t0, STACK_KEM_DEC_PK_ADDR(fp)
  /* t0 = pk + K*384 + 32 (h follows pk) */
  add  t0, t0, t1
  addi t0, t0, 32
  sw   t0, STACK_KEM_DEC_H_ADDR(fp)
  sw   a2, STACK_KEM_DEC_KEYA_ADDR(fp)

  /*** indcpa_dec ***/
  li  a3, STACK_KEM_DEC_BUF
  add a3, fp, a3
  jal x1, indcpa_dec

  /*** Copy hash_h(pk) to buf+32 ***/
  li     x4, 0
  lw     a0, STACK_KEM_DEC_H_ADDR(fp)
  li     a3, STACK_KEM_DEC_BUF
  add    a3, fp, a3
  addi   a3, a3, 32
  bn.lid x4, 0(a0)
  bn.sid x4, 0(a3++)

  /*** hash_g(buf) ***/
  addi  a0, a3, -64
  add   a2, zero, a3
  addi  a1, zero, 64
  slli  t0, a1, 5
  addi  t0, t0, SHA3_512_CFG
  csrrw zero, KECCAK_CFG_REG, t0
  jal   x1, keccak_send_message
  li    t0, 8
  LOOPI 2, 2
    bn.wsrr w8, 0xA /* KECCAK_DIGEST */
    bn.sid  t0, 0(a2++) /* Store into buffer */

  /*** indcpa_enc ***/
  addi a0, a0, -64
  lw   a1, STACK_KEM_DEC_PK_ADDR(fp)
  addi a2, a2, -32
  li   a3, STACK_KEM_DEC_CMP
  add  a3, fp, a3
  sw   a3, STACK_KEM_DEC_CMP_ADDR(fp)
  jal  x1, indcpa_enc

  /*** shake256(z||c,32) ***/
  /* t1 = &kyber_ciphertext_sizes[K] */
  la      t1, kyber_ciphertext_sizes
  slli    t0, x14, 2
  add     t1, t1, t0

  /* a1 = 32 + KYBER_CIPHERTEXTBYTES */
  lw      a1, 0(t1)
  addi    a1, a1, 32
  slli    t0, a1, 5
  addi    t0, t0, SHAKE256_CFG
  csrrw   zero, KECCAK_CFG_REG, t0
  /* z */
  lw      a0, STACK_KEM_DEC_H_ADDR(fp)
  addi    a0, a0, 32
  addi    a1, zero, 32
  jal     x1, keccak_send_message
  /* cmp */
  lw      a0, STACK_KEM_DEC_CT_ADDR(fp)
  lw      a1, 0(t1)
  jal     x1, keccak_send_message
  /* output buffer */
  li      a2, STACK_KEM_DEC_KR
  add     a2, fp, a2
  addi    a2, a2, 32
  li      t0, 8
  bn.wsrr w8, 0xA /* KECCAK_DIGEST */
  bn.sid  t0, 0(a2++) /* Store into buffer */

  /*** verify (constant-time): ct == cmp ? w4 = 0 : w4 = all-ones ***/
  li      t0, 0
  li      t1, 1
  lw      a0, STACK_KEM_DEC_CT_ADDR(fp)
  lw      a1, STACK_KEM_DEC_CMP_ADDR(fp)
  bn.subi w2, w31, 1  /* w2 = 2^256 - 1 (all ones) */
  bn.mov  w4, w31     /* w4 = 0 (difference accumulator) */
  /* t2 = KYBER_CIPHERTEXT_WRS = KYBER_CIPHERTEXTBYTES / 32 */
  la      t2, kyber_ciphertext_sizes
  slli    t3, x14, 2
  add     t2, t2, t3
  lw      t2, 0(t2)
  srli    t2, t2, 5
  LOOP t2, 5
    bn.lid t0, 0(a0++)
    bn.lid t1, 0(a1++)
    bn.cmp w0, w1
    bn.sel w3, w31, w2, FG0.Z  /* w3 = 0 if equal, all ones otherwise */
    bn.or  w4, w4, w3          /* accumulate */

  /*** cmov ***/
  li      a0, STACK_KEM_DEC_KR
  add     a0, fp, a0
  bn.lid  t0, 0(a0++) /* load true key */
  bn.lid  t1, 0(a0)   /* load false key */
  bn.xor  w3, w0, w1
  bn.and  w3, w3, w4
  bn.xor  w0, w0, w3
  lw      a0, STACK_KEM_DEC_KEYA_ADDR(fp)
  bn.sid  t0, 0(a0) /* return key */

  ret

.data

/* KYBER_CIPHERTEXTBYTES indexed by K. K=0,1 unused. */
.balign 4
kyber_ciphertext_sizes:
.word 0     /* K=0 unused */
.word 0     /* K=1 unused */
.word 768   /* K=2 (ML-KEM-512) */
.word 1088  /* K=3 (ML-KEM-768) */
.word 1568  /* K=4 (ML-KEM-1024) */
