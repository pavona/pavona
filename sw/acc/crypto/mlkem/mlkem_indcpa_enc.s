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
#define POLY -512

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
 * Name:        indcpa_enc
 *
 * Description: Encryption function of the CPA-secure
 *              public-key encryption scheme underlying Kyber.
 *
 * Arguments:   - uint8_t *c: pointer to output ciphertext
 *                            (of length KYBER_INDCPA_BYTES bytes)
 *              - const uint8_t *m: pointer to input message
 *                                  (of length KYBER_INDCPA_MSGBYTES bytes)
 *              - const uint8_t *pk: pointer to input public key
 *                                   (of length KYBER_INDCPA_PUBLICKEYBYTES)
 *              - const uint8_t *coins: pointer to input random coins used as seed
 *                                      (of length KYBER_SYMBYTES) to deterministically
 *                                      generate all randomness
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10 (a0): dmem pointer to input message
 * @param[in]  x11 (a1): dmem pointer to input packed pk
 * @param[in]  x12 (a2): dmem pointer to input coins
 * @param[out] x13 (a3): dmem pointer to output ciphertext
 * @param[in]  x14: KYBER_K
 *
 * clobbered registers: x4 to x29, w0 to w31, acc, acch, mod
 * clobbered flag groups: FG0
 */
.globl indcpa_enc
indcpa_enc:
  /* Store parameters to save registers or memory. */
  addi t2, a1, 0
  la   t0, dptr_coins
  sw   a2, 0(t0)
  la   t0, dptr_ct
  sw   a3, 0(t0)

  /*** poly_frommsg ***/
  la  a1, modulus_over_2
  la  a2, poly_k
  jal x1, poly_frommsg

  /* Prepare for initial `poly_getnoise_eta_1` call, performing the SHAKE
     computation during `unpack_pk` */
  la     t0, dptr_coins
  lw     a0, 0(t0)
  la     a3, nonce
  bn.xor w0, w0, w0
  bn.sid x0, 0(a3)
  jal    x1, poly_getnoise_eta_init

  /*** unpack_pk ***/
  addi a0, t2, 0
  la   a2, pkpv
  la   a3, const_0x0fff
  jal  x1, unpack_pk

  /*** save seed to dmem ***/
  bn.lid x0, 0(a0)
  la     t0, seed
  bn.sid x0, 0(t0)

  /*** CBD sp + NTT ***/
  la   s8, nonce
  la   t0, dptr_coins
  lw   s9, 0(t0)
  la   s10, sp
  li   s11, 0

  addi t0, x14, -1
  LOOP t0, 21
    la   t1, poly_v
    add  a0, x0, s9
    add  a1, x0, s10
    jal  x1, poly_getnoise_eta_1

    add  a0, x0, s9
    add  a3, x0, s8
    addi s11, s11, 1
    sw   s11, 0(s8)
    jal  x1, poly_getnoise_eta_init

    bn.wsrr   w16, 0x0 /* w16 = R | Q */
    bn.shv.8S w0, w16 << 1 /* w0 = 2*R | 2*Q */
    bn.wsrw   0x0, w0 /* MOD = 2*R | 2*Q */

    add  a0, x0, s10
    la   a1, twiddles_ntt
    add  a2, x0, s10
    jal  x1, ntt

    bn.xor w31, w31, w31  /* w31 = 0 */
    addi s10, s10, 2*KYBER_N
    bn.wsrw   0x0, w16 /* MOD = R | Q */

  la   t1, poly_v
  add  a0, x0, s9
  add  a1, x0, s10
  add  a3, x0, s8
  jal  x1, poly_getnoise_eta_1

  bn.wsrr   w16, 0x0 /* w16 = R | Q */
  bn.shv.8S w0, w16 << 1 /* w0 = 2*R | 2*Q */
  bn.wsrw   0x0, w0 /* MOD = 2*R | 2*Q */

  add  a0, x0, s10
  la   a1, twiddles_ntt
  add  a2, x0, s10
  jal  x1, ntt

  /* After NTT, w6 is still R | Q and MOD is still 2*R | 2*Q */
  /** v = sp * pkpv **/
  la   x29, pkpv
  la   a1, sp
  la   a3, poly_v
  la   x28, twiddles_basemul
  jal  x1, basemul
  addi t0, x14, -1
  LOOP t0, 5
    addi a3, a3, POLY
    la   x28, twiddles_basemul
    jal  x1, basemul_acc
    nop

  la   t0, dptr_coins
  lw   a0, 0(t0)
  slli a2, x14, 1
  la   a3, nonce
  sw   a2, 0(a3)
  jal  x1, poly_getnoise_eta_init

  /* After basemul, w16 is still R | Q and MOD is still 2*R | 2*Q */
  /*** INTT v ***/
  la      a0, poly_v
  add     a2, x0, a0
  la      a1, twiddles_intt
  jal     x1, intt
  bn.wsrw 0x0, w16 /* Restore MOD = R | Q */

  /*** CBD epp ***/
  la   a1, epp
  la   t1, poly_tmp
  jal  x1, poly_getnoise_eta_2

  /* Prepare for the first call to poly_gen_matrix. */
  la     a0, seed
  bn.xor w30, w30, w30
  jal    x1, poly_gen_matrix_init

  /** v = v + k + epp **/
  la   a0, poly_k
  la   a1, poly_v
  add  a2, x0, a1
  jal  x1, poly_add
  la   a0, epp
  addi a1, a1, POLY
  addi a2, a2, POLY
  jal  x1, poly_add

  /* w6 is still R | Q */
  bn.shv.8S w0, w16 << 1 /* w0 = 2*R | 2*Q */
  bn.wsrw   0x0, w0 /* MOD = 2*R | 2*Q */
  /*** Matrix vector multiplication ***/
  la   a1, poly_at

  /* Run rejection sampling to generate the public key. */

  /* This is somewhat verbosely unrolled in order to interleave calls to
     `poly_gen_matrix_init`, which initializes the SHAKE128 operation, and
     `poly_gen_matrix`, which makes use of the result. By doing this carefully,
     we can avoid any stalls while reading SHAKE128 results. */

  addi t0, x14, -1
  LOOP t0, 40
    /* Gen 1st mat poly */
    la   a0, seed
    jal  x1, poly_gen_matrix
    bn.addi w30, w30, 0x0100
    jal  x1, poly_gen_matrix_init

    /* Mutliply this generated poly with sk */
    addi a1, a1, POLY /* point back to A[0][0] */
    la   x29, sp /* point to sk[0] */
    add  a3, a1, x0   /* output at A[0][0] */
    la   x28, twiddles_basemul
    jal  x1, basemul

    addi t1, x14, -2
    beq  t1, x0, 2f
    LOOP t1, 11
      /* Gen next mat poly */
      la   a0, seed
      jal  x1, poly_gen_matrix
      bn.addi w30, w30, 0x0100
      jal  x1, poly_gen_matrix_init

      /* Mutliply this generated poly with sk */
      addi a1, a1, POLY /* points back to A[0][1] */
      addi a3, a1, POLY /* points back to A[0][0] for accumulation */
      la   x28, twiddles_basemul
      jal  x1, basemul_acc
      addi a1, a1, POLY /* points back to A[0][1] */
2:

    /* Gen next mat poly */
    la   a0, seed
    jal  x1, poly_gen_matrix
    bn.addi w30, w30, 0x0100
    /* w30 -= KYBER_K * 256 - 1 */
    LOOP x14, 1
      bn.subi w30, w30, 256
    bn.addi w30, w30, 1
    jal  x1, poly_gen_matrix_init

    /* Mutliply this generated poly with sk */
    addi a1, a1, POLY /* points back to A[0][1] */
    addi a3, a1, POLY /* points back to A[0][0] for accumulation */
    la   x28, twiddles_basemul
    jal  x1, basemul_acc
    addi a1, a1, POLY /* points back to A[0][1] */

  /* Gen 1st mat poly */
  la   a0, seed
  jal  x1, poly_gen_matrix
  bn.addi w30, w30, 0x0100
  jal  x1, poly_gen_matrix_init

  /* Mutliply this generated poly with sk */
  addi a1, a1, POLY /* point back to A[0][0] */
  la   x29, sp /* point to sk[0] */
  add  a3, a1, x0   /* output at A[0][0] */
  la   x28, twiddles_basemul
  jal  x1, basemul

  addi t1, x14, -2
  beq t1, x0, 1f
  LOOP t1, 11
    /* Gen next mat poly */
    la   a0, seed
    jal  x1, poly_gen_matrix
    bn.addi w30, w30, 0x0100
    jal  x1, poly_gen_matrix_init

    /* Mutliply this generated poly with sk */
    addi a1, a1, POLY /* points back to A[0][1] */
    addi a3, a1, POLY /* points back to A[0][0] for accumulation */
    la   x28, twiddles_basemul
    jal  x1, basemul_acc
    addi a1, a1, POLY /* points back to A[0][1] */
1:

  /* Gen next mat poly */
  la   a0, seed
  jal  x1, poly_gen_matrix

  /* Mutliply this generated poly with sk */
  addi a1, a1, POLY /* points back to A[0][1] */
  addi a3, a1, POLY /* points back to A[0][0] for accumulation */
  la   x28, twiddles_basemul
  jal  x1, basemul_acc

  /* (End of public key rejection sampling) */

  /* Prepare for initial `poly_getnoise_eta_2` call, performing the SHAKE
     computation during `unpack_pk` */
  la   t0, dptr_coins
  lw   a0, 0(t0)
  la   a3, nonce
  sw   x14, 0(a3)
  jal  x1, poly_getnoise_eta_init

  /* After basemul, w16 is still R | Q and MOD is still 2*R | 2*Q */
  /*** INTT ***/
  la  a0, poly_at
  la  a1, twiddles_intt
  add a2, x0, a0
  LOOP x14, 2
    jal x1, intt
    nop
  bn.wsrw 0x0, w16 /* Restore MOD = R | Q */

  /*** CBD ep + ADD ***/
  la   a3, nonce
  la   t0, dptr_coins
  lw   s3, 0(t0)
  la   a5, ep
  la   a6, poly_b
  addi s2, x14, 0

  addi t0, x14, -1
  LOOP t0, 15
    la   t1, poly_tmp
    add  a0, x0, s3
    add  a1, x0, a5
    jal  x1, poly_getnoise_eta_2

    add  a0, x0, s3
    addi s2, s2, 1
    sw   s2, 0(a3)
    jal  x1, poly_getnoise_eta_init

    add  a0, x0, a6
    add  a1, x0, a5
    add  a2, x0, a6
    jal  x1, poly_add

    addi  a5, a5, 2*KYBER_N
    addi  a6, a6, 2*KYBER_N

  la   t1, poly_tmp
  add  a0, x0, s3
  add  a1, x0, a5
  jal  x1, poly_getnoise_eta_2

  add  a0, x0, a6
  add  a1, x0, a5
  add  a2, x0, a6
  jal  x1, poly_add

  /*** pack_ciphertext ***/
  la   a0, poly_b
  la   a1, poly_v
  la   t0, dptr_ct
  lw   a2, 0(t0)
  la   a3, const_1290167
  la   a5, modulus_over_2
  jal  x1, pack_ciphertext
  ret

.bss

/* Randomness input address. */
.balign 4
dptr_coins:
.zero 4

/* Ciphertext output address. */
.balign 4
dptr_ct:
.zero 4

/* Nonce intermediate value (32 bytes). */
.balign 32
nonce:
.zero 32

/* Seed intermediate value (32 bytes). */
.balign 32
seed:
.zero 32

/* Polynomial v intermediate value (512 bytes). */
.balign 32
poly_v:
.zero 512

/* Polynomial-sized temporary buffer (512 bytes). */
.balign 32
poly_tmp:
.zero 512

/* Shared buffer for multiple intermediate polynomials. */
.balign 32
poly_at:
poly_k:
poly_b:
.zero 512

/* Shared buffer for public key polyvec (k*512 bytes, max K=4) and epp. */
.balign 32
pkpv:
epp:
.zero 2048

/* Shared buffer for sp and ep (512 bytes each). */
sp:
ep:
.zero 512
