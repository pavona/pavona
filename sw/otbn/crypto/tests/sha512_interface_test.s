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
  la        x2, test2_msg
  la        x18, test2_digest
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

/* Test 1 input message (plus space for padding). */
.balign 32
test1_msg:
.word 0x00636261
.zero 124

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
