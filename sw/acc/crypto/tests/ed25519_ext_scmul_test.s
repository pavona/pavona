/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/* Copyright lowRISC contributors. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.section .text.start

/**
 * Standalone test for Ed25519 scalar-point multiplication.
 *
 * Based on test 1 from IETF RFC 8032, section 7.3. This should correspond to
 * the scalar multiplication in the signing operation.
 *
 * Test point (extended coordinates):
 *   X = 0x216936d3cd6e53fec0a4e231fdd6dc5c692cc7609525a7b2c9562d608f25d51a
 *   Y = 0x6666666666666666666666666666666666666666666666666666666666666658
 *   Z = 0x0000000000000000000000000000000000000000000000000000000000000001
 *   T = 0x67875f0fd78b766566ea4e8e64abe37d20f09f80775152f56dde8ab3a5b7dda3
 *
 * Test exponent:
 *   e = 0x063cda541de0d7115caa4666554c18b54bc5182467403cf0fe227b85e151da21
 */

main:
  /* Initialize all-zero register. */
  bn.xor   w31, w31, w31

  /* [w6:w9] <= (dmem[X], dmem[Y], dmem[Z], dmem[T]) = P */
  li       x2, 6
  la       x3, X
  bn.lid   x2++, 0(x3)
  la       x3, Y
  bn.lid   x2++, 0(x3)
  la       x3, Z
  bn.lid   x2++, 0(x3)
  la       x3, T
  bn.lid   x2++, 0(x3)

  /* w28 <= dmem[exp] */
  li       x2, 28
  la       x3, exp
  bn.lid   x2, 0(x3)

  /* w29 <= dmem[ed25519_d] */
  li       x2, 29
  la       x3, ed25519_d
  bn.lid   x2, 0(x3)

  /* Set up for field arithmetic.
       MOD <= p
       w19 <= 19
       w30 <= 38 */
  jal      x1, fe_init

  /* Call the scalar-point multiplication routine. */
  jal      x1, ext_scmul

/*
 * @param[in]   w6: input X1 (X1 < p)
 * @param[in]   w7: input Y1 (Y1 < p)
 * @param[in]   w8: input Z1 (Z1 < p)
 * @param[in]   w9: input T1 (T1 < p)
 * @param[in]  w19: constant, w19 = 19
 * @param[in]  w28: a, scalar input, a < L
 * @param[in]  w29: constant, d = (-121665/121666) mod p
 * @param[in]  w30: constant, 38
 * @param[in]  w31: all-zero
 * @param[in]  MOD: p, modulus = 2^255 - 19
 * @param[out] w10: output X2
 * @param[out] w11: output Y2
 * @param[out] w12: output Z2
 * @param[out] w13: output T2
 *
 * clobbered registers: w10 to w18, w20 to w28
 * clobbered flag groups: FG0
*/
  ecall

.data

.balign 32
exp:
.word 0xe151da21
.word 0xfe227b85
.word 0x67403cf0
.word 0x4bc51824
.word 0x554c18b5
.word 0x5caa4666
.word 0x1de0d711
.word 0x063cda54

.balign 32
X:
.word 0x8f25d51a
.word 0xc9562d60
.word 0x9525a7b2
.word 0x692cc760
.word 0xfdd6dc5c
.word 0xc0a4e231
.word 0xcd6e53fe
.word 0x216936d3

.balign 32
Y:
.word 0x66666658
.word 0x66666666
.word 0x66666666
.word 0x66666666
.word 0x66666666
.word 0x66666666
.word 0x66666666
.word 0x66666666

.balign 32
Z:
.word 0x00000001
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000

.balign 32
T:
.word 0xa5b7dda3
.word 0x6dde8ab3
.word 0x775152f5
.word 0x20f09f80
.word 0x64abe37d
.word 0x66ea4e8e
.word 0xd78b7665
.word 0x67875f0f


/* Curve constant d copied from ed25519.s */
.balign 32
ed25519_d:
.word 0x135978a3
.word 0x75eb4dca
.word 0x4141d8ab
.word 0x00700a4d
.word 0x7779e898
.word 0x8cc74079
.word 0x2b6ffe73
.word 0x52036cee
