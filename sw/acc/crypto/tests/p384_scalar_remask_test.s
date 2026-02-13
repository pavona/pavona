/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * Test for P-384 scalar remasking.
 */

.section .text.start
  /* Call the remask routine. */
  la   x12, d0
  la   x13, d1
  jal  x1, p384_scalar_remask

  /* Because of the randomization, we need to unmask the scalar to get a
     deterministic expected value to check. */

  /* Initialize all-zero register. */
  bn.xor  w31, w31, w31

  /* Load the re-masked scalar.
       [w0,w1] <= d0
       [w2,w3] <= d1 */
  li      x2, 0
  bn.lid  x2++, 0(x12)
  bn.lid  x2++, 32(x12)
  bn.lid  x2++, 0(x13)
  bn.lid  x2++, 32(x13)

  /* Load curve order n from DMEM.
       [w12,w13] <= dmem[p256_n] = n */
  la        x2, p384_n
  li        x3, 12
  bn.lid    x3++, 0(x2)
  bn.lid    x3, 32(x2)

  /* [w10,w11] <= n << 64 */
  bn.rshi   w10, w12, w31 >> 192
  bn.rshi   w11, w13, w12 >> 192

  /* Add shares to unmask and then [w18,w19] <= (d0 + d1) mod (n << 64) */
  bn.add  w0, w0, w2
  bn.addc w1, w1, w3
  bn.sub  w2, w0, w10
  bn.subb w3, w1, w11
  bn.sel  w18, w0, w2, FG0.C
  bn.sel  w19, w1, w3, FG0.C
  bn.mov  w20, w31

  /* Compute Solinas constant k for modulus n (we know it is only 191 bits, so
     no need to compute the high part):
     w14 <= 2^256 - n[255:0] = (2^384 - n) mod (2^256) = 2^384 - n */
  bn.sub    w14, w31, w12

  /* Fully reduce modulo n.
       [w16,w17] <= (d0 + d1) mod n = d */
  jal     x1, p384_reduce_n

  ecall

.section .data

.balign 32
d0:
.word 0xacec764b
.word 0x95ba6d97
.word 0x917fee76
.word 0x3c0210fa
.word 0x6ba975df
.word 0x693c9b74
.word 0xa299e16d
.word 0xbe50f1f1
.word 0xe37c609b
.word 0xf78c155f
.word 0x1c081d31
.word 0x1ea1b0ad
.word 0xca31b450
.word 0x74f48736

.balign 32
d1:
.word 0x06542907
.word 0x52447f77
.word 0x46fb9344
.word 0x53629451
.word 0xef3a0ba1
.word 0xa6853d1f
.word 0x6fcb3618
.word 0xea2248ce
.word 0xa4d668b2
.word 0x646ca778
.word 0xa4f18320
.word 0x7de5b16c
.word 0x35ce4bb0
.word 0x8b0b78c9
