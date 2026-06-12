/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * Standalone test for secp256k1 ECDH shared key generation
 *
 * Computes a shared key from a private scalar (in arithmetic shares) and a
 * public curve point. The shared key is returned as two boolean shares; the
 * test unmasks it and compares against the expected affine x-coordinate of
 * d*Q.
 */

.section .text.start
start:
  /* Call secp256k1 shared key generation to get a boolean-masked key.
       dmem[x] <= x0
       dmem[y] <= x1 */
  jal      x1, secp256k1_shared_key

  /* Load the two shares.
       w11 <= dmem[x] = x0
       w12 <= dmem[y] = x1 */
  li        x3, 11
  la        x4, x
  bn.lid    x3++, 0(x4)
  la        x4, y
  bn.lid    x3, 0(x4)

  /* Unmask the shared key, x.
       w11 <= x0 ^ x1 = x */
  bn.xor    w11, w11, w12

  ecall

.data

/* Secret key d in arithmetic shares (second share is zero). */
.globl d0
.balign 32
d0:
  .word 0xc7df1a56
  .word 0xfbd94efe
  .word 0xaa847f52
  .word 0x2d869bf4
  .word 0x543b963b
  .word 0xe5f2cbee
  .word 0x9144233d
  .word 0xc0fbe256
  .zero 32
.globl d1
.balign 32
d1:
  .zero 64

/* public curve point x-coordinate (2G) */
.globl x
.balign 32
x:
  .word 0x5c709ee5
  .word 0xabac09b9
  .word 0x8cef3ca7
  .word 0x5c778e4b
  .word 0x95c07cd8
  .word 0x3045406e
  .word 0x41ed7d6d
  .word 0xc6047f94

/* public curve point y-coordinate (2G) */
.globl y
.balign 32
y:
  .word 0x50cfe52a
  .word 0x236431a9
  .word 0x3266d0e1
  .word 0xf7f63265
  .word 0x466ceaee
  .word 0xa3c58419
  .word 0xa63dc339
  .word 0x1ae168fe

/* projective z buffer used by the shared key routine */
.globl z
.balign 32
z:
  .zero 32
