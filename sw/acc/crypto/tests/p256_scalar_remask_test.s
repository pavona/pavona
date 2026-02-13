/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * Test for p256 scalar remasking.
 */

.section .text.start
  /* Call the remask routine. */
  la   x12, d0
  la   x13, d1
  jal  x1, p256_scalar_remask

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
       w29 <= dmem[p256_n] = n */
  la        x2, p256_n
  li        x3, 29
  bn.lid    x3, 0(x2)
  bn.wsrw   MOD, w29

  /* Load Barrett constant for n.
     w28 <= u_n = dmem[p256_u_n]  */
  li        x2, 28
  la        x3, p256_u_n
  bn.lid    x2, 0(x3)

  /* [w10,w11] <= n << 64 */
  bn.rshi   w10, w29, w31 >> 192
  bn.rshi   w11, w31, w29 >> 192

  /* Add shares to unmask and then [w24,w25] <= (d0 + d1) mod (n << 64) */
  bn.add  w0, w0, w2
  bn.addc w1, w1, w3
  bn.sub  w2, w0, w10
  bn.subb w3, w1, w11
  bn.sel  w24, w0, w2, FG0.C
  bn.sel  w25, w1, w3, FG0.C

  /* Fully reduce by n using the 320x128b multiplication routine with 1.
       w19 >= (d0 + d1) mod n = d */
  bn.addi w26, w31, 1
  jal     x1, mod_mul_320x128

  ecall

.section .data

.balign 32
d0:
.word 0x6c5a00d3
.word 0xa3db8043
.word 0x86c7a5bd
.word 0xf360edf3
.word 0xab93f51c
.word 0xe0e1f615
.word 0x202805cf
.word 0x632670fc
.word 0x1e2c8656
.word 0x38cd7d12

.balign 32
d1:
.word 0x18dc2504
.word 0x1204e3af
.word 0x0915566d
.word 0x2d51bba6
.word 0x09725b4f
.word 0xc1ac5056
.word 0xf9b75b7f
.word 0xb9bad234
.word 0xe1d379aa
.word 0xc73282ec
