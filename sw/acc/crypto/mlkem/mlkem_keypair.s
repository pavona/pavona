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

#ifdef HARDENED
#define NSHARES 2
#else
#define NSHARES 1
#endif

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

/*
 * Name:        crypto_kem_keypair
 *
 * Description: Generates public and private key
 *              for CCA-secure Kyber key encapsulation mechanism
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10 (a0): pointer to seed (2*KYBER_SYMBYTES = 64)
 * @param[out] x11 (a1): dmem pointer to kem_pk
 * @param[out] x12 (a2): dmem pointer to kem_sk
 * @param[in]  x13 (a3): k, the security level
 *
 * clobbered registers: a0-a4, t0-t5, w8, w16
 */

.globl crypto_kem_keypair
.type crypto_kem_keypair, @function
crypto_kem_keypair:
    /* Save addresses. */
    la t0, dptr_coins
    sw a0, 0(t0)
    la t0, dptr_pk
    sw a1, 0(t0)
    la t0, k
    sw a3, 0(t0)

#ifdef HARDENED
    /* Refresh the Boolean shares of seed d (coins + 0, coins + 32). */
    addi s0, a0, 0
    addi s1, a1, 0
    addi s2, a2, 0
    addi a1, x0, 1
    addi a2, x0, 32
    addi a4, a0, 0
    jal  x1, refreshios
    addi a0, s0, 0
    addi a1, s1, 0
    addi a2, s2, 0
#endif

    /*** indcpa_keypair ***/
    jal  x1, indcpa_keypair

    la   t0, k
    lw   t0, 0(t0)
    addi x4, x0, 2
    beq  t0, x4, _pk_len_k2
    addi x4, x0, 3
    beq  t0, x4, _pk_len_k3
    addi s0, x0, 1568
    beq  x0, x0, _continue
_pk_len_k3:
    addi s0, x0, 1184
    beq  x0, x0, _continue
_pk_len_k2:
    addi s0, x0, 800

_continue:
    srli t0, s0, 5
    la   t1, dptr_sk
    lw   t1, 0(t1)
    la   t2, dptr_pk
    lw   t2, 0(t2)
    loop t0, 2
      bn.lid x0, 0(t2++)
      bn.sid x0, 0(t1++)
    endloop

    /* Compute H(pk). */
    la      t0, dptr_pk
    lw      a0, 0(t0)
    add     a1, x0, s0
    slli    t0, a1, 5
    addi    t0, t0, SHA3_256_CFG
    csrrw   x0, kmac_cfg, t0
    jal     x1, keccak_send_message
    bn.wsrr w0, kmac_digest
    bn.sid  x0, 0(t1++)

    /* Copy z to sk. */
    la     t0, dptr_coins
    lw     t0, 0(t0)
#ifdef HARDENED
    bn.lid x0, 64(t0)
    bn.sid x0, 0(t1)
    bn.xor w0, w0, w0 /* Whitening. */
    bn.lid x0, 96(t0)
    bn.sid x0, 32(t1)
#else
    bn.lid x0, 32(t0)
    bn.sid x0, 0(t1)
#endif
    ret
