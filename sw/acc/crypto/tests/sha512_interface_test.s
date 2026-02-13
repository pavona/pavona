/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * Standalone test for SHA-512 interface.
 *
 * Test data from the NIST examples:
 * https://csrc.nist.gov/CSRC/media/Projects/Cryptographic-Standards-and-Guidelines/documents/examples/SHA512.pdf
 */

.section .text.start

main:
  /* Initialize all-zero register. */
  bn.xor    w31, w31, w31

  /* Test 1: SHA512("abc") */
  jal       x1, sha512_init
  li        x18, 3
  la        x20, test1_msg
  jal       x1, sha512_update
  la        x18, test1_digest
  jal       x1, sha512_final

  /* Test 2: SHA512("abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu") */
  jal       x1, sha512_init
  li        x18, 112
  la        x20, test2_msg
  jal       x1, sha512_update
  la        x18, test2_digest
  jal       x1, sha512_final

  /* Test 3: same as test 2 but with more updates. */
  jal       x1, sha512_init
  li        x18, 40
  la        x20, test2_msg
  jal       x1, sha512_update
  li        x18, 0
  la        x20, test2_msg
  jal       x1, sha512_update
  la        x20, test2_msg
  addi      x20, x20, 40
  li        x18, 72
  jal       x1, sha512_update
  la        x18, test3_digest
  jal       x1, sha512_final

  /* Test 4: Ed25519ph hashing pattern (with 0 context length):
       h = SHA512(d)
       r = SHA512(b'SigEd25519 no Ed25519 collisions' + bytes([1,0]) + h[32:] + PH(M)) */
  jal       x1, sha512_init
  li        x18, 32
  la        x20, test4_sk
  jal       x1, sha512_update
  la        x18, test4_digest
  jal       x1, sha512_final

  jal       x1, sha512_init
  li        x18, 34
  la        x20, test4_dom_sep
  jal       x1, sha512_update
  li        x18, 0
  la        x20, test4_dom_sep
  jal       x1, sha512_update
  li        x18, 32
  la        x20, test4_digest
  addi      x20, x20, 32
  jal       x1, sha512_update
  li        x18, 64
  la        x20, test4_phmsg
  jal       x1, sha512_update
  la        x18, test4_digest
  jal       x1, sha512_final

  /* w0, w1 <= test 1 digest */
  li        x2, 0
  la        x3, test1_digest
  bn.lid    x2++, 0(x3)
  bn.lid    x2++, 32(x3)

  /* w2, w3 <= test 2 digest */
  la        x3, test2_digest
  bn.lid    x2++, 0(x3)
  bn.lid    x2++, 32(x3)

  /* w4, w5 <= test 3 digest */
  la        x3, test3_digest
  bn.lid    x2++, 0(x3)
  bn.lid    x2++, 32(x3)

  /* w6, w7 <= test 4 digest */
  la        x3, test4_digest
  bn.lid    x2++, 0(x3)
  bn.lid    x2++, 32(x3)

  ecall


.data

/* Temporary buffer for test 1 result. */
.balign 32
test1_digest:
.zero 64

/* Temporary buffer for test 2 result. */
.balign 32
test2_digest:
.zero 64

/* Temporary buffer for test 3 result. */
.balign 32
test3_digest:
.zero 64

/* Temporary buffer for test 4 result. */
.balign 32
test4_digest:
.zero 64

/* Test 1 input message (plus space for padding). */
.balign 32
test1_msg:
.word 0x00636261
.zero 124

/* Test 2/3 input message (plus space for padding). */
.balign 32
test2_msg:
.word 0x64636261
.word 0x68676665
.word 0x65646362
.word 0x69686766
.word 0x66656463
.word 0x6a696867
.word 0x67666564
.word 0x6b6a6968
.word 0x68676665
.word 0x6c6b6a69
.word 0x69686766
.word 0x6d6c6b6a
.word 0x6a696867
.word 0x6e6d6c6b
.word 0x6b6a6968
.word 0x6f6e6d6c
.word 0x6c6b6a69
.word 0x706f6e6d
.word 0x6d6c6b6a
.word 0x71706f6e
.word 0x6e6d6c6b
.word 0x7271706f
.word 0x6f6e6d6c
.word 0x73727170
.word 0x706f6e6d
.word 0x74737271
.word 0x71706f6e
.word 0x75747372
.zero 144

/* Test 4: Ed25519ph domain separator + context len prefix (34 bytes, ctx_len=0) */
test4_dom_sep:
.word 0x45676953
.word 0x35353264
.word 0x6e203931
.word 0x6445206f
.word 0x31353532
.word 0x6f632039
.word 0x73696c6c
.word 0x736e6f69
.word 0x00000001

/* Test 4: Ed25519ph secret key value (32 bytes)
     From RFC 8032, section 7.3, test 1 */
.balign 32
test4_sk:
.word 0x24e63f83
.word 0x9d7b2309
.word 0x5877ec62
.word 0x1e912075
.word 0xec9c759a
.word 0x5b75191d
.word 0xb901a97d
.word 0x423dca6d

/* Test 4: Ed25519ph pre-hashed message (64 bytes)
     From RFC 8032, section 7.3, test 1  */
test4_phmsg:
.word 0xa135afdd
.word 0xba7a6193
.word 0x497341cc
.word 0x314120ae
.word 0x4efae612
.word 0xa27ea989
.word 0xe6ee9e0a
.word 0x9ad3554b
.word 0x2a999221
.word 0xa8c14f27
.word 0x233cba36
.word 0xbdebfea3
.word 0x23444d45
.word 0x0ee83c64
.word 0x4fc99a2a
.word 0x9fa44ca5
