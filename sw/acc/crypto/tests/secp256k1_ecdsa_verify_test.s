/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * Standalone secp256k1 ECDSA verify test
 *
 * Verifies the signature produced by the sign test against the matching
 * public key. The recovered x_r must equal the signature R component and
 * the basic checks must report success.
 */

.section .text.start
start:
  /* call ECDSA signature verification subroutine in secp256k1 lib */
  jal      x1, secp256k1_verify

  /* load results to wregs for comparison with reference */
  li        x2, 0
  la        x3, x_r
  bn.lid    x2, 0(x3)
  la        x3, ok
  lw        x2, 0(x3)

  ecall

.data

.globl msg
.balign 32
msg:
  .word 0x4456fd21
  .word 0x400bdd7d
  .word 0xb54d7452
  .word 0x17d015f1
  .word 0x90d4d90b
  .word 0xb028ad8a
  .word 0x6ce90fef
  .word 0x06d71207

/* signature R */
.globl r
.balign 32
r:
  .word 0xf1571173
  .word 0xa038fe2f
  .word 0xdb121f87
  .word 0xceee234b
  .word 0x064f7dcb
  .word 0xacee27c5
  .word 0xeeb2da32
  .word 0x0cd92b5e

/* signature S */
.globl s
.balign 32
s:
  .word 0x71f090f0
  .word 0x9ccfa8f9
  .word 0xbdc27018
  .word 0x556f9ab7
  .word 0x7609c79b
  .word 0x2dfe19d8
  .word 0xe107f2d3
  .word 0x2269c64d

/* public key x-coordinate */
.globl x
.balign 32
x:
  .word 0xa13f5722
  .word 0x713d9401
  .word 0x345daff9
  .word 0x09169c30
  .word 0x355f88f9
  .word 0xbc142dd5
  .word 0x269e6899
  .word 0xb269fedf

/* public key y-coordinate */
.globl y
.balign 32
y:
  .word 0xa04f5d8f
  .word 0xffc11bc4
  .word 0x52771631
  .word 0x133110d6
  .word 0x6ce4df34
  .word 0x3391480f
  .word 0xb1c3739f
  .word 0xb2510a4c

/* verification result buffer */
.globl x_r
.balign 32
x_r:
  .zero 32

/* basic checks status */
.globl ok
.balign 4
ok:
  .zero 4
