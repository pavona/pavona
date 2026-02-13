/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * Standalone test for Ed25519 signature verification.
 *
 * This test is from RFC 8032 section 7.1, and the message input is
 * SHA-512('abc'). The value k = SHA-512(R_ || A_ || PH(M)) was precomputed.
 *
 * Raw test data for easier copy-paste:
 *   A_ : ec172b93ad5e563bf4932c70e1245034c35467ef2efd4d64ebf819683467e2bf
 *   R_ : dc2a4459e7369633a52b1bf277839a00201009a3efbf3ecb69bea2186c26b589
 *    S : 09351fc9ac90b3ecfdfbc7c66431e0303dca179c138ac17ad9bef1177331a704
 *    k : 5ea8a61daa7bb05bc0c58f108ad46822e2ee812b418666d4b53e8160c268422edfcf89131f99e5a11f6df1c58753050b56122c166df6708fa961d63341e7aae5
 */

.section .text.start
main:
  /* Initialize all-zero register. */
  bn.xor    w31, w31, w31

  /* Call verification. */
  jal       x1, ed25519_verify_var

  /* Read the verification result into register x2. */
  la        x3, ed25519_verify_result
  lw        x2, 0(x3)

  ecall

.data

/* Encoded public key point A_. */
.balign 32
.globl ed25519_public_key
ed25519_public_key:
.word 0x932b17ec
.word 0x3b565ead
.word 0x702c93f4
.word 0x345024e1
.word 0xef6754c3
.word 0x644dfd2e
.word 0x6819f8eb
.word 0xbfe26734

/* Encoded point R_, first half of signature. */
.balign 32
.globl ed25519_sig_R
ed25519_sig_R:
.word 0x59442adc
.word 0x339636e7
.word 0xf21b2ba5
.word 0x009a8377
.word 0xa3091020
.word 0xcb3ebfef
.word 0x18a2be69
.word 0x89b5266c

/* Scalar value S, second half of signature. */
.balign 32
.globl ed25519_sig_S
ed25519_sig_S:
.word 0xc91f3509
.word 0xecb390ac
.word 0xc6c7fbfd
.word 0x30e03164
.word 0x9c17ca3d
.word 0x7ac18a13
.word 0x17f1bed9
.word 0x04a73173

/* Precomputed hash SHA-512(R_ || A_ || M) */
.balign 32
.globl ed25519_hash_k
ed25519_hash_k:
.word 0x1da6a85e
.word 0x5bb07baa
.word 0x108fc5c0
.word 0x2268d48a
.word 0x2b81eee2
.word 0xd4668641
.word 0x60813eb5
.word 0x2e4268c2
.word 0x1389cfdf
.word 0xa1e5991f
.word 0xc5f16d1f
.word 0x0b055387
.word 0x162c1256
.word 0x8f70f66d
.word 0x33d661a9
.word 0xe5aae741
