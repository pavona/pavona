/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * Entrypoint for ML-KEM keygen / encap / decap operations.
 *
 * This binary has 9 modes: {keygen, encap, decap} x {ML-KEM-512, ML-KEM-768,
 * ML-KEM-1024}. The mode is read from `dmem[mode]`.
 *
 * Unprotected I/O formats follow FIPS 203.
 * In the HARDENED build:
 *  - keygen `coins` holds two boolean shares each of d and z
 *    (d0 || d1 || z0 || z1, 128 bytes),
 *  - `dk` is the masked decapsulation key: per secret polynomial two
 *    packed 12-bit arithmetic shares (2 x 384 bytes), followed by ek,
 *    H(ek), and the two boolean shares of z (64 bytes),
 *  - decap `ss` holds two 32-byte boolean shares of the shared secret.
 *  - encap only operates on public data; it uses the same unprotected
 *    code path in both builds.
 */

#ifdef HARDENED
  #define NSHARES 2
#else
  #define NSHARES 1
#endif

/* Buffers are sized for the worst case (ML-KEM-1024). */
#define KYBER_K_MAX 4

/**
 * Mode magic values, generated with
 * $ ./util/design/sparse-fsm-encode.py -d 6 -m 9 -n 11 \
 *     --avoid-zero -s 482917365
 *
 * Call the same utility with the same arguments and a higher -m to generate
 * additional value(s) without changing the others or sacrificing mutual HD.
 */
.equ MODE_KEYGEN_512,  0x07d
.equ MODE_KEYGEN_768,  0x1ab
.equ MODE_KEYGEN_1024, 0x4e6
.equ MODE_ENCAP_512,   0x64b
.equ MODE_ENCAP_768,   0x297
.equ MODE_ENCAP_1024,  0x725
.equ MODE_DECAP_512,   0x6b8
.equ MODE_DECAP_768,   0x5d1
.equ MODE_DECAP_1024,  0x372

.globl MODE_KEYGEN_512
.globl MODE_KEYGEN_768
.globl MODE_KEYGEN_1024
.globl MODE_ENCAP_512
.globl MODE_ENCAP_768
.globl MODE_ENCAP_1024
.globl MODE_DECAP_512
.globl MODE_DECAP_768
.globl MODE_DECAP_1024

.section .text.start
.globl start
.type start, @function
start:
  /* All-zero register. */
  bn.xor  w31, w31, w31

  /* mod = mqinv | q.*/
  li      x5, 16
  la      x6, const_q
  bn.lid  x5++, 0(x6)
  bn.rshi w16, w31, w16 >> 240
  la      x6, const_mqinv
  bn.lid  x5, 0(x6)
  bn.or   w16, w16, w17 << 32
  bn.wsrw mod, w16

  /* Read mode and dispatch. */
  la      x5, mode
  lw      x5, 0(x5)

  addi    x3, x0, MODE_KEYGEN_512
  beq     x5, x3, _mlkem_keygen_512
  addi    x3, x0, MODE_KEYGEN_768
  beq     x5, x3, _mlkem_keygen_768
  addi    x3, x0, MODE_KEYGEN_1024
  beq     x5, x3, _mlkem_keygen_1024

  addi    x3, x0, MODE_ENCAP_512
  beq     x5, x3, _mlkem_encap_512
  addi    x3, x0, MODE_ENCAP_768
  beq     x5, x3, _mlkem_encap_768
  addi    x3, x0, MODE_ENCAP_1024
  beq     x5, x3, _mlkem_encap_1024

  addi    x3, x0, MODE_DECAP_512
  beq     x5, x3, _mlkem_decap_512
  addi    x3, x0, MODE_DECAP_768
  beq     x5, x3, _mlkem_decap_768
  addi    x3, x0, MODE_DECAP_1024
  beq     x5, x3, _mlkem_decap_1024

  /* Invalid mode. */
  unimp
  unimp
  unimp

_mlkem_keygen_512:
  addi    x13, x0, 2
  beq     x0, x0, _mlkem_keygen_common
_mlkem_keygen_768:
  addi    x13, x0, 3
  beq     x0, x0, _mlkem_keygen_common
_mlkem_keygen_1024:
  addi    x13, x0, 4
_mlkem_keygen_common:
  /* Stack pointer. */
  la      x2, stack_end
  /* KYBER_K in x13 (a3). */
  la      x10, coins
  la      x11, ek
  la      x12, dk
  jal     x1, crypto_kem_keypair
  ecall

_mlkem_encap_512:
  addi    x14, x0, 2
  beq     x0, x0, _mlkem_encap_common
_mlkem_encap_768:
  addi    x14, x0, 3
  beq     x0, x0, _mlkem_encap_common
_mlkem_encap_1024:
  addi    x14, x0, 4
_mlkem_encap_common:
  /* Stack pointer. */
  la      x2, stack_end
  /* KYBER_K in x14 (a4). */
  la      x10, coins
  la      x11, ek
  la      x12, ct
  la      x13, ss
  jal     x1, crypto_kem_enc
  ecall

_mlkem_decap_512:
  addi    x13, x0, 2
  beq     x0, x0, _mlkem_decap_common
_mlkem_decap_768:
  addi    x13, x0, 3
  beq     x0, x0, _mlkem_decap_common
_mlkem_decap_1024:
  addi    x13, x0, 4
_mlkem_decap_common:
  /* Stack pointer. */
  la      x2, stack_end
  /* KYBER_K in x13 (a3). */
  la      x10, ct
  la      x11, dk
  la      x12, ss
  jal     x1, crypto_kem_dec
  ecall

/* The .bss DMEM layout lives in mlkem/mlkem_dmem.s (the shared single
 * source of truth), linked in via the :dmem / :dmem_hardened dependency. */
