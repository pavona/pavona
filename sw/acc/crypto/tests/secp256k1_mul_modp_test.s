/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * Standalone test for secp256k1 field multiplication.
 *
 * Runs several edge cases through mul_modp; the cases include unreduced
 * operands (mul_modp accepts any 256-bit values) and products that exercise
 * the carry path of the second folding step.
 */

.section .text.start
start:
  /* Initialize all-zero register. */
  bn.xor    w31, w31, w31

  /* Set up the modulus and the folding/Barrett constant r256.
       MOD <= w29 <= p; w28 <= r256 */
  jal       x1, setup_modp

  /* case 0: p minus 1 squared
       w0 <= (a0 * b0) mod p */
  li        x2, 24
  la        x3, value_a0
  bn.lid    x2++, 0(x3)
  la        x3, value_b0
  bn.lid    x2, 0(x3)
  jal       x1, mul_modp
  bn.mov    w0, w19

  /* case 1: generic operands
       w1 <= (a1 * b1) mod p */
  li        x2, 24
  la        x3, value_a1
  bn.lid    x2++, 0(x3)
  la        x3, value_b1
  bn.lid    x2, 0(x3)
  jal       x1, mul_modp
  bn.mov    w1, w19

  /* case 2: all-ones operands (unreduced, exercises the fold-2 carry)
       w2 <= (a2 * b2) mod p */
  li        x2, 24
  la        x3, value_a2
  bn.lid    x2++, 0(x3)
  la        x3, value_b2
  bn.lid    x2, 0(x3)
  jal       x1, mul_modp
  bn.mov    w2, w19

  /* case 3: a equal to p (unreduced input, canonical zero result)
       w3 <= (a3 * b3) mod p */
  li        x2, 24
  la        x3, value_a3
  bn.lid    x2++, 0(x3)
  la        x3, value_b3
  bn.lid    x2, 0(x3)
  jal       x1, mul_modp
  bn.mov    w3, w19

  /* case 4: basepoint coordinates
       w4 <= (a4 * b4) mod p */
  li        x2, 24
  la        x3, value_a4
  bn.lid    x2++, 0(x3)
  la        x3, value_b4
  bn.lid    x2, 0(x3)
  jal       x1, mul_modp
  bn.mov    w4, w19

  /* case 5: tiny operands (high product half is zero)
       w5 <= (a5 * b5) mod p */
  li        x2, 24
  la        x3, value_a5
  bn.lid    x2++, 0(x3)
  la        x3, value_b5
  bn.lid    x2, 0(x3)
  jal       x1, mul_modp
  bn.mov    w5, w19

  ecall

.data

/* operand a0 = 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2e */
.balign 32
value_a0:
  .word 0xfffffc2e
  .word 0xfffffffe
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff

/* operand b0 = 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2e */
.balign 32
value_b0:
  .word 0xfffffc2e
  .word 0xfffffffe
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff

/* operand a1 = 0xa8da539ffce03337030a5a44bcd3266608a32b364bb3295cace17a9da3175abc */
.balign 32
value_a1:
  .word 0xa3175abc
  .word 0xace17a9d
  .word 0x4bb3295c
  .word 0x08a32b36
  .word 0xbcd32666
  .word 0x030a5a44
  .word 0xfce03337
  .word 0xa8da539f

/* operand b1 = 0x72c7c6bec94cf13ab2a1c47c60cb522e04a0e4330df8714c96a2db313c873171 */
.balign 32
value_b1:
  .word 0x3c873171
  .word 0x96a2db31
  .word 0x0df8714c
  .word 0x04a0e433
  .word 0x60cb522e
  .word 0xb2a1c47c
  .word 0xc94cf13a
  .word 0x72c7c6be

/* operand a2 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff */
.balign 32
value_a2:
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff

/* operand b2 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff */
.balign 32
value_b2:
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff

/* operand a3 = 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f */
.balign 32
value_a3:
  .word 0xfffffc2f
  .word 0xfffffffe
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff

/* operand b3 = 0x1 */
.balign 32
value_b3:
  .word 0x00000001
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000

/* operand a4 = 0x79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798 */
.balign 32
value_a4:
  .word 0x16f81798
  .word 0x59f2815b
  .word 0x2dce28d9
  .word 0x029bfcdb
  .word 0xce870b07
  .word 0x55a06295
  .word 0xf9dcbbac
  .word 0x79be667e

/* operand b4 = 0x483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8 */
.balign 32
value_b4:
  .word 0xfb10d4b8
  .word 0x9c47d08f
  .word 0xa6855419
  .word 0xfd17b448
  .word 0x0e1108a8
  .word 0x5da4fbfc
  .word 0x26a3c465
  .word 0x483ada77

/* operand a5 = 0x1000003d1 */
.balign 32
value_a5:
  .word 0x000003d1
  .word 0x00000001
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000

/* operand b5 = 0x1000003d1 */
.balign 32
value_b5:
  .word 0x000003d1
  .word 0x00000001
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
