/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * Standalone padding test for SHA-512.
 */

.section .text.start

main:
  /* Initialize all-zero register. */
  bn.xor    w31, w31, w31

  /* Load an all-ones constant (to represent the message). */
  bn.not   w30, w31

  /* Load pointers. */
  la        x11, len

  /* Load wide-register pointers. */
  li       x6, 0
  li       x30, 30

  /* Test with an empty message.
       x21 <= dptr_end, end of padding
       dmem[dst..dptr_end] = message padding */
  la        x10, dst
  jal       x1, sha512_pad_message

  /* Store the results (padding byte-length and value).
       x12 <= dptr_end - dst
       [w0..w3] <= dst */
  sub       x12, x21, x10
  bn.lid    x6++, 0(x10)
  bn.lid    x6++, 32(x10)
  bn.lid    x6++, 64(x10)
  bn.lid    x6++, 96(x10)

  /* Reset destination buffer. */
  bn.sid    x30, 0(x10)
  bn.sid    x30, 32(x10)
  bn.sid    x30, 64(x10)
  bn.sid    x30, 96(x10)

  /* Test with a 15-byte message.
       x21 <= dptr_end, end of padding
       dmem[dst+15..dptr_end] = message padding */
  li        x2, 15
  sw        x2, 0(x11)
  la        x10, dst
  add       x10, x10, x2
  jal       x1, sha512_pad_message

  /* Store the results (padding byte-length and value).
       x13 <= dptr_end - (dst+15)
       [w4..w7] <= dst */
  sub       x13, x21, x10
  la        x2, dst
  bn.lid    x6++, 0(x2)
  bn.lid    x6++, 32(x2)
  bn.lid    x6++, 64(x2)
  bn.lid    x6++, 96(x2)

  /* Reset destination buffer. */
  bn.sid    x30, 0(x2)
  bn.sid    x30, 32(x2)
  bn.sid    x30, 64(x2)
  bn.sid    x30, 96(x2)

  /* Test with a 127-byte message.
       x21 <= dptr_end, end of padding
       dmem[dst+127..dptr_end] = message padding */
  li        x2, 127
  sw        x2, 0(x11)
  la        x10, dst
  add       x10, x10, x2
  jal       x1, sha512_pad_message

  /* Store the results (padding byte-length and value).
       x14 <= dptr_end - (dst+127)
       [w8..w15] <= dst */
  sub       x14, x21, x10
  la        x2, dst
  bn.lid    x6++, 0(x2)
  bn.lid    x6++, 32(x2)
  bn.lid    x6++, 64(x2)
  bn.lid    x6++, 96(x2)
  bn.lid    x6++, 128(x2)
  bn.lid    x6++, 160(x2)
  bn.lid    x6++, 192(x2)
  bn.lid    x6++, 224(x2)

  /* Reset destination buffer. */
  bn.sid    x30, 0(x2)
  bn.sid    x30, 32(x2)
  bn.sid    x30, 64(x2)
  bn.sid    x30, 96(x2)
  bn.sid    x30, 128(x2)
  bn.sid    x30, 160(x2)
  bn.sid    x30, 192(x2)
  bn.sid    x30, 224(x2)

  /* Test with a 128-byte message.
       x21 <= dptr_end, end of padding
       dmem[dst+128..dptr_end] = message padding */
  li        x2, 128
  sw        x2, 0(x11)
  la        x10, dst
  jal       x1, sha512_pad_message

  /* Store the results (padding byte-length and value).
       x14 <= dptr_end - dst
       [w16..w19] <= dst */
  sub       x15, x21, x10
  la        x2, dst
  bn.lid    x6++, 0(x2)
  bn.lid    x6++, 32(x2)
  bn.lid    x6++, 64(x2)
  bn.lid    x6++, 96(x2)

  /* Reset destination buffer. */
  bn.sid    x30, 0(x2)
  bn.sid    x30, 32(x2)
  bn.sid    x30, 64(x2)
  bn.sid    x30, 96(x2)

  /* Test with a (2^125 - 1)-byte message (max possible length).
       x21 <= dptr_end, end of padding
       dmem[dst+127..dptr_end] = message padding */
  bn.addi   w20, w31, 1
  bn.rshi   w20, w20, w31 >> 131
  bn.subi   w20, w20, 1
  li        x20, 20
  bn.sid    x20, 0(x11)
  la        x10, dst
  addi      x10, x10, 127 /* (2^125 - 1) mod 128 = 127 */
  jal       x1, sha512_pad_message

  /* Store the results (padding byte-length and value).
       x16 <= dptr_end - (dst+127)
       [w20..w27] <= dst */
  sub       x16, x21, x10
  la        x2, dst
  li        x6, 20
  bn.lid    x6++, 0(x2)
  bn.lid    x6++, 32(x2)
  bn.lid    x6++, 64(x2)
  bn.lid    x6++, 96(x2)
  bn.lid    x6++, 128(x2)
  bn.lid    x6++, 160(x2)
  bn.lid    x6++, 192(x2)
  bn.lid    x6++, 224(x2)

  ecall


.data

/* Buffer for message length. */
.balign 32
len:
.zero 32

/* Destination buffer in memory for padding. */
.balign 32
dst:
.zero 256
