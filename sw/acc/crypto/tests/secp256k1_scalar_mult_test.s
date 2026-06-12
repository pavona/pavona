/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * Standalone test for secp256k1 scalar point multiplication
 *
 * Performs multiplication of a curve point by a scalar. The scalar is
 * provided in two shares; the curve point is provided in affine form in DMEM.
 *
 * See comment at the end of the file for expected values of the affine
 * coordinates of the resulting point.
 */

.section .text.start
start:
  /* Init all-zero register. */
  bn.xor    w31, w31, w31

  /* Load first share of scalar k from dmem.
       w0,w1 = dmem[k0] */
  la        x16, k0
  li        x2, 0
  bn.lid    x2, 0(x16++)
  li        x2, 1
  bn.lid    x2, 0(x16)

  /* Load second share of scalar k from dmem.
       w2,w3 = dmem[k1] */
  la        x16, k1
  li        x2, 2
  bn.lid    x2, 0(x16++)
  li        x2, 3
  bn.lid    x2, 0(x16)

  /* Call internal scalar multiplication routine.
     Returns point in projective coordinates.
     (w8, w9, w10) <= (X, Y, Z) = k*(x,y) */
  la        x21, x
  la        x22, y
  jal       x1, scalar_mult_int

  /* Convert to affine coordinates.
       w11 <= x
       w12 <= y */
  jal       x1, proj_to_affine

  ecall


.data

/* scalar k (first share; second share is zero) */
.globl k0
.balign 32
k0:
  .word 0xfe6d1071
  .word 0x21d0a016
  .word 0xb0b2c781
  .word 0x9590ef5d
  .word 0x3fdfa379
  .word 0x1b76ebe8
  .word 0x74210263
  .word 0x1420fc41
  .zero 32
.globl k1
.balign 32
k1:
  .zero 64

/* example curve point x-coordinate (2G) */
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

/* example curve point y-coordinate (2G) */
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
