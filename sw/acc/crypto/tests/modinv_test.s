/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * Test for an RSA keygen subroutine: modular inverse.
 */

.section .text.start

main:
  /* Init all-zero register. */
  bn.xor    w31, w31, w31

  /* Load the number of limbs for this test. */
  li        x30, 4

  /* Load DMEM pointers. */
  la        x11, argument
  la        x12, modulus
  la        x13, result
  la        x14, rsa_n
  la        x15, rsa_p
  la        x16, rsa_q
  la        x17, rsa_d_p
  la        x18, rsa_d_q

  /* Load required constants. */
  li        x20, 20
  li        x21, 21

  /* Compute the modular inverse.
       dmem[result] <= (dmem[argument]^-1) mod dmem[modulus] */
  jal       x1, modinv

  /* Read the inverse into registers for the test framework to check.
       [w0..w3] <= dmem[result] */
  li        x2, 0
  loop      x30, 2
    bn.lid    x2, 0(x13++)
    addi      x2, x2, 1

  ecall

.data

/*
Argument: randomly-generated number in the range [0,2^1024).

Python script to generate argument:
import random
import math
a = random.randrange(0, 1 << 1024)

Full hex value for reference:
0x8853cbf3fe42ffb703d22de5b82dccd9977807da0cf7c9dc2e2df4563d9d48d85f395e8869da543909b1869b53fd6ce413dfd8ae7715199ebce5767778d1a60f80d8f5b776f2a536c94050964e6243566cb03a4cacb49c4e5ac3cb272e1bb8bd50fbe92ba04862dad86e9366ed75d63bee9e5e58e2bbb6583351514b8c728e7f
*/
.balign 32
argument:
.word 0x8c728e7f
.word 0x3351514b
.word 0xe2bbb658
.word 0xee9e5e58
.word 0xed75d63b
.word 0xd86e9366
.word 0xa04862da
.word 0x50fbe92b
.word 0x2e1bb8bd
.word 0x5ac3cb27
.word 0xacb49c4e
.word 0x6cb03a4c
.word 0x4e624356
.word 0xc9405096
.word 0x76f2a536
.word 0x80d8f5b7
.word 0x78d1a60f
.word 0xbce57677
.word 0x7715199e
.word 0x13dfd8ae
.word 0x53fd6ce4
.word 0x9b1869b
.word 0x69da5439
.word 0x5f395e88
.word 0x3d9d48d8
.word 0x2e2df456
.word 0xcf7c9dc
.word 0x977807da
.word 0xb82dccd9
.word 0x3d22de5
.word 0xfe42ffb7
.word 0x8853cbf3

/*
Modulus: randomly-generated number in the range [2^1023,2^1024) such that
GCD(65537, modulus) = 1.

Python script to generate modulus:
import random
import math
a = 0x8853cbf3fe42ffb703d22de5b82dccd9977807da0cf7c9dc2e2df4563d9d48d85f395e8869da543909b1869b53fd6ce413dfd8ae7715199ebce5767778d1a60f80d8f5b776f2a536c94050964e6243566cb03a4cacb49c4e5ac3cb272e1bb8bd50fbe92ba04862dad86e9366ed75d63bee9e5e58e2bbb6583351514b8c728e7f
while True:
  m = random.randrange(1 << 1023, 1 << 1024)
  if math.gcd(m, a) == 1:
    break

Full hex value for reference:
0xa1f2ca9b5cfaa6a3cc0f58c0505a44b7898874f88a9faee8de008a3e1323b8957506623de6da5976589ed46e82df1eb91f76c7a7b439f36721f8a349ba9b4785e1de7c51d5b52cb56efbf6d731f50578fa02d94591377cd73cd9c0364c8e4d943e3bc2779ab4901795adc515d5355bb4d5c4fb18dfaa27983ba43010805a81ee
*/
.balign 32
modulus:
.word 0x805a81ee
.word 0x3ba43010
.word 0xdfaa2798
.word 0xd5c4fb18
.word 0xd5355bb4
.word 0x95adc515
.word 0x9ab49017
.word 0x3e3bc277
.word 0x4c8e4d94
.word 0x3cd9c036
.word 0x91377cd7
.word 0xfa02d945
.word 0x31f50578
.word 0x6efbf6d7
.word 0xd5b52cb5
.word 0xe1de7c51
.word 0xba9b4785
.word 0x21f8a349
.word 0xb439f367
.word 0x1f76c7a7
.word 0x82df1eb9
.word 0x589ed46e
.word 0xe6da5976
.word 0x7506623d
.word 0x1323b895
.word 0xde008a3e
.word 0x8a9faee8
.word 0x898874f8
.word 0x505a44b7
.word 0xcc0f58c0
.word 0x5cfaa6a3
.word 0xa1f2ca9b

/* Buffer for result (1024 bits). */
.balign 32
result:
.zero 128
