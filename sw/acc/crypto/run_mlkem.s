/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * Entrypoint for ML-KEM keygen / encap / decap operations.
 *
 * This binary has 9 modes: {keygen, encap, decap} x {ML-KEM-512, ML-KEM-768,
 * ML-KEM-1024}. The mode is read from `dmem[mode]`.
 */

/**
 * Mode magic values, generated with
 * $ ./util/design/sparse-fsm-encode.py -d 6 -m 9 -n 11 \
 *     --avoid-zero -s 482917365
 *
 * Call the same utility with the same arguments and a higher -m to generate
 * additional value(s) without changing the others or sacrificing mutual HD.
 *
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
start:
  /* All-zero register. */
  bn.xor  w31, w31, w31

  /* MOD = R | Q.*/
  li      x5, 2
  la      x6, modulus
  bn.lid  x5++, 0(x6)
  la      x6, modulus_inv
  bn.lid  x5, 0(x6)
  bn.or   w2, w2, w3 << 32
  bn.wsrw 0x0, w2

  /* Stack pointer. */
  la      x2, stack_end

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
  addi    x14, x0, 2
  beq     x0, x0, _mlkem_keygen_common
_mlkem_keygen_768:
  addi    x14, x0, 3
  beq     x0, x0, _mlkem_keygen_common
_mlkem_keygen_1024:
  addi    x14, x0, 4
_mlkem_keygen_common:
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
  la      x11, ct
  la      x12, ss
  la      x13, ek
  jal     x1, crypto_kem_enc
  ecall

_mlkem_decap_512:
  addi    x14, x0, 2
  beq     x0, x0, _mlkem_decap_common
_mlkem_decap_768:
  addi    x14, x0, 3
  beq     x0, x0, _mlkem_decap_common
_mlkem_decap_1024:
  addi    x14, x0, 4
_mlkem_decap_common:
  la      x10, ct
  la      x11, dk
  la      x12, ss
  jal     x1, crypto_kem_dec
  ecall

.bss

.globl stack
.balign 32
stack:
  .zero 6144
stack_end:

/* Operation mode (one of MODE_*). */
.globl mode
.balign 4
mode:
  .zero 4

/* Input random coins (64 bytes for keygen, 32 for encap). */
.globl coins
.balign 32
coins:
  .zero 64

/* Decapsulation key / secret key (worst-case ML-KEM-1024 = 3168 bytes). */
.globl dk
.balign 32
dk:
  .zero 3168

/* Encapsulation key / public key (worst-case ML-KEM-1024 = 1568 bytes). */
.globl ek
.balign 32
ek:
  .zero 1568

/* Ciphertext (worst-case ML-KEM-1024 = 1568 bytes). */
.globl ct
.balign 32
ct:
  .zero 1568

/* Shared secret (32 bytes). */
.globl ss
.balign 32
ss:
  .zero 32
