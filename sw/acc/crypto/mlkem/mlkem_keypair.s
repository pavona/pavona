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
 * Name:        indcpa_keypair
 *
 * Description: Generates public and private key for the CPA-secure
 *              public-key encryption scheme underlying Kyber
 *
 * Arguments:   - uint8_t *pk: pointer to output public key
 *                             (of length KYBER_INDCPA_PUBLICKEYBYTES bytes)
 *              - uint8_t *sk: pointer to output private key
 *                             (of length KYBER_INDCPA_SECRETKEYBYTES bytes)
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10 (a0): pointer to seed (KYBER_SYMBYTES = 32)
 * @param[out] x11 (a1): dmem pointer to public key pk_addr
 * @param[out] x12 (a2): dmem pointer to secret key sk_addr
 * @param[in]  x14: KYBER_K
 *
 * clobbered registers: a0-a4, t0-t5, w8, w16
 */

indcpa_keypair:
  /* Stack address mapping. Worst-case (K=4) sizes throughout. */
  #define STACK_PK_ADDR        -32
  #define STACK_SK_ADDR        -24
  #define STACK_COINS_ADDR     -16
  #define STACK_BUF           -128
    #define STACK_PUBLICSEED  -128
    #define STACK_NOISESEED    -96
    #define STACK_NONCE        -64
  #define STACK_TMP           -640
  #define STACK_A            -2688
  #define STACK_SKPV         -4736

  /* Store parameters to stack */
  sw  a0, STACK_COINS_ADDR(fp)
  sw  a1, STACK_PK_ADDR(fp)
  sw  a2, STACK_SK_ADDR(fp)

  /*** hash_g ***/
  /* Initialize a SHA3-512 operation. */
  addi  a1, zero, 33
  slli  t0, a1, 5
  addi  t0, t0, SHA3_512_CFG
  csrrw zero, KECCAK_CFG_REG, t0
  addi  a1, zero, 32
  jal   x1, keccak_send_message
  addi  a0, fp, STACK_BUF
  sw    x14, 0(a0)
  addi  a1, zero, 1
  jal   x1, keccak_send_message
  addi  a2, fp, STACK_BUF
  li    t0, 8
  LOOPI 2, 2
    bn.wsrr w8, 0xA /* KECCAK_DIGEST */
    bn.sid  t0, 0(a2++) /* Store into buffer */

  /*** CBD skpv ***/
  li   a5, STACK_A
  li   a1, STACK_SKPV
  add  a1, fp, a1
  li   a3, STACK_NONCE
  add  a3, a3, fp
  li   a2, 0
  /* K iterations */
  LOOP x14, 6
    add  t1, fp, a5
    addi a0, fp, STACK_NOISESEED
    sw   a2, STACK_NONCE(fp)
    jal  x1, poly_getnoise_eta_init
    jal  x1, poly_getnoise_eta_1
    addi a2, a2, 1

  bn.wsrr   w16, 0x0 /* w16 = MOD = R | Q */
  bn.shv.8S w22, w16 << 1 /* w22 = 2*R | 2*Q */
  bn.wsrw   0x0, w22 /* MOD = 2*R | 2*Q */
  /*** NTT skpv ***/
  li   a0, STACK_SKPV
  add  a0, fp, a0
  la   a1, twiddles_ntt
  add  a2, zero, a0
  /* K iterations */
  LOOP x14, 2
    jal x1, ntt
    nop
  bn.wsrw 0x0, w16 /* Restore MOD = R | Q */

  /*** Packing sk ***/
  li   a0, STACK_SKPV
  add  a0, fp, a0
  lw   a3, STACK_SK_ADDR(fp)
  jal  x1, pack_sk

  bn.wsrw 0x0, w22 /* MOD = 2*R | 2*Q */
  /*** Matrix-vector multiplication ***/
  li   a1, STACK_A
  add  a1, fp, a1
  bn.xor w30, w30, w30
  /* K iterations */
  LOOP x14, 28
    /* Gen 1st mat poly */
    addi a0, fp, STACK_PUBLICSEED
    jal  x1, poly_gen_matrix_init
    jal  x1, poly_gen_matrix
    bn.addi w30, w30, 1

    /* Mutliply this generated poly with sk */
    addi a1, a1, POLY /* point back to A[0][0] */
    li   x29, STACK_SKPV
    add  x29, fp, x29 /* point to sk[0] */
    add  a3, a1, x0   /* output at A[0][0] */
    la   x28, twiddles_basemul
    jal  x1, basemul

    /* K-1 iterations */
    addi t1, x14, -1
    LOOP t1, 10
      /* Gen next mat poly */
      addi a0, fp, STACK_PUBLICSEED
      jal  x1, poly_gen_matrix_init
      jal  x1, poly_gen_matrix
      bn.addi w30, w30, 1

      /* Mutliply this generated poly with sk */
      addi a1, a1, POLY /* points back to A[0][1] */
      addi a3, a1, POLY /* points back to A[0][0] for accumulation */
      la   x28, twiddles_basemul
      jal  x1, basemul_acc
      addi a1, a1, POLY /* points back to A[0][1] */

    /* w30 += 256 - K (= KYBER_GEN_MATRIX_NONCE) */
    bn.addi w30, w30, 256
    LOOP x14, 1
      bn.subi w30, w30, 1
    nop
  bn.wsrw 0x0, w16 /* Restore MOD = R | Q */

  /* After basemul, w16 is still R | Q */
  /*** poly_tomont ***/
  li  a0, STACK_A
  add a0, fp, a0
  la  a1, const_tomont
  /* K iterations */
  LOOP x14, 2
    jal x1, poly_tomont
    nop

  /*** CBD e ***/
  li   a5, STACK_TMP
  li   a1, STACK_SKPV
  add  a1, fp, a1
  li   a3, STACK_NONCE
  add  a3, a3, fp
  addi a2, x14, 0
  /* K iterations */
  LOOP x14, 6
    add  t1, fp, a5
    addi a0, fp, STACK_NOISESEED
    sw   a2, STACK_NONCE(fp)
    jal  x1, poly_getnoise_eta_init
    jal  x1, poly_getnoise_eta_1
    addi a2, a2, 1

  /* After cbd, w16 is still R | Q */
  bn.shv.8S w0, w16 << 1 /* w0 = 2*R | 2*Q */
  bn.wsrw   0x0, w0 /* MOD = 2*R | 2*Q */
  /*** NTT e ***/
  li   a0, STACK_SKPV
  add  a0, fp, a0
  la   a1, twiddles_ntt
  add  a2, zero, a0
  /* K iterations */
  LOOP x14, 2
    jal x1, ntt
    nop
  bn.wsrw 0x0, w16 /* Restore MOD = R | Q */

  /* Polyvec add */
  li   a0, STACK_A
  add  a0, fp, a0
  li   a1, STACK_SKPV
  add  a1, fp, a1
  add  a2, x0, a0
  /* K iterations */
  LOOP x14, 2
    jal x1, poly_add
    nop

  /*** Packing ***/
  lw   a3, STACK_PK_ADDR(fp)
  li   a0, STACK_A
  add  a0, fp, a0
  addi a1, fp, STACK_PUBLICSEED
  jal  x1, pack_pk

  ret

/*
 * Name:        crypto_kem_keypair
 *
 * Description: Generates public and private key
 *              for CCA-secure Kyber key encapsulation mechanism
 *
 * Arguments:   - uint8_t *pk: pointer to output public key
 *                (an already allocated array of KYBER_PUBLICKEYBYTES bytes)
 *              - uint8_t *sk: pointer to output private key
 *                (an already allocated array of KYBER_SECRETKEYBYTES bytes)
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10 (a0): pointer to seed (2*KYBER_SYMBYTES = 64)
 * @param[out] x11 (a1): dmem pointer to kem_pk
 * @param[out] x12 (a2): dmem pointer to kem_sk
 * @param[in]  x14: KYBER_K
 *
 * clobbered registers: a0-a4, t0-t5, w8, w16
 */

.globl crypto_kem_keypair
crypto_kem_keypair:
  /* Set frame pointer */
  addi fp, sp, 0
  li   t0, -4736
  add  sp, sp, t0

  /*** indcpa_keypair ***/
  jal  x1, indcpa_keypair
  li   x4, 0
  lw   a0, STACK_PK_ADDR(fp)
  lw   a1, STACK_SK_ADDR(fp)
  /* a1 += KYBER_INDCPA_SECRETKEYBYTES = K * 384 */
  slli t0, x14, 7
  slli t1, x14, 8
  add  t0, t0, t1
  add  a1, a1, t0
  /* t1 = KYBER_INDCPA_PUBLICKEYBYTES_WRS = K * 12 + 1 */
  slli t0, x14, 3
  slli t1, x14, 2
  add  t1, t0, t1
  addi t1, t1, 1
  LOOP t1, 2
    bn.lid x4, 0(a0++)
    bn.sid x4, 0(a1++)

  /*** hash_h ***/
  lw      a0, STACK_PK_ADDR(fp)
  /* a1 = KYBER_PUBLICKEYBYTES = K * 384 + 32 */
  slli    t0, x14, 7
  slli    a1, x14, 8
  add     a1, a1, t0
  addi    a1, a1, 32
  slli    t0, a1, 5
  addi    t0, t0, SHA3_256_CFG
  csrrw   zero, KECCAK_CFG_REG, t0
  jal     x1, keccak_send_message
  lw      a2, STACK_SK_ADDR(fp)
  /* a2 += KYBER_INDCPA_PUBLICKEYBYTES + KYBER_INDCPA_SECRETKEYBYTES
   *    = (K*384+32) + K*384 = 2*K*384 + 32 */
  slli    t0, x14, 8
  slli    t1, x14, 9
  add     t0, t0, t1
  addi    t0, t0, 32
  add     a2, a2, t0
  li      t0, 8
  bn.wsrr w8, 0xA /* KECCAK_DIGEST */
  bn.sid  t0, 0(a2++) /* Store into buffer */

  /*** Random bytes ***/
  lw      a0, STACK_COINS_ADDR(fp)
  addi    a0, a0, 32
  li      t0, 8
  bn.lid  t0, 0(a0)
  bn.sid  t0, 0(a2++)

  /* Free space on stack */
  addi sp, fp, 0
  ret
