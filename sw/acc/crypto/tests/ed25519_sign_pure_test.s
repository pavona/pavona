/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.section .text.start

/**
 * Standalone test for incremental pure Ed25519 signing.
 *
 * Test data from IETF RFC 8032, section 7.1 (TEST 2):
 * https://datatracker.ietf.org/doc/html/rfc8032#section-7.1
 *
 * SECRET KEY:
 * 4ccd089b28ff96da9db6c346ec114e0f
 * 5b8a319f35aba624da8cf6ed4fb8a6fb
 *
 * PUBLIC KEY:
 * 3d4017c3e843895a92b70aa74d1b7ebc
 * 9c982ccf2ec4968cc0cd55f12af4660c
 *
 * MESSAGE (1 byte):
 * 72
 *
 * SIGNATURE:
 * 92a009a9f0d4cab8720e820b5f642540
 * a2b27b5416503f8fb3762223ebdb69da
 * 085ac1e43e15996e458f3613d0f11d8c
 * 387b2eaeb4302aeeb00d291612bb0c00
 */

main:
  /* Initialize all-zero register. */
  bn.xor   w31, w31, w31

  /* Call the SHA-512 routine to hash d.
       dmem[ed25519_hash_h] <= SHA-512(d) = h */
  jal      x1, sha512_init
  li       x18, 32
  la       x20, ed25519_sk
  jal      x1, sha512_update
  la       x18, ed25519_hash_h
  jal      x1, sha512_final

  /* INIT phase: hash prefix + message chunk. */
  jal      x1, ed25519_sign_pure_init

  /* MID phase: finalize nonce, point math, start challenge hash. */
  jal      x1, ed25519_sign_pure_mid

  /* FINAL phase: finalize challenge hash, compute S. */
  jal      x1, ed25519_sign_pure_final

  ecall

.data

.balign 4
.globl ed25519_message_len
ed25519_message_len:
.word 0x00000001

.balign 32
.globl ed25519_sk
ed25519_sk:
.word 0x9b08cd4c
.word 0xda96ff28
.word 0x46c3b69d
.word 0x0f4e11ec
.word 0x9f318a5b
.word 0x24a6ab35
.word 0xedf68cda
.word 0xfba6b84f

/* Message: 0x72 (1 byte) */
.balign 32
.globl ed25519_message
ed25519_message:
.word 0x00000072
.zero 28

.balign 32
.globl ed25519_sig_R
ed25519_sig_R:
.zero 32

.balign 32
.globl ed25519_sig_S
ed25519_sig_S:
.zero 32
