/* Copyright zeroRISC Inc. */
/* Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192). */
/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors. */
/* Modified by Ruben Niederhagen and Hoang Nguyen Hien Pham - authors of */
/* "Improving ML-KEM & ML-DSA on OpenTitan - Efficient Multiplication Vector Instructions for OTBN" */
/* (https://eprint.iacr.org/2025/2028). */
/* Copyright Ruben Niederhagen and Hoang Nguyen Hien Pham. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

/**
 * Inverse Number Theoretic Transform (INTT).
 *
 * Return r = INTT(x) for ML-KEM with n = 256 and q = 3329.
 *
 * On return, x10 and x12 have been advanced by one polynomial (512 bytes),
 * so that consecutive calls walk a polynomial vector.
 *
 * This routine is constant time.
 *
 * @param[in]  x10: dmem pointer to x
 * @param[in]  x11: dmem pointer to the twiddle factors const_tw_intt, whose
 *                  last element folds in the final scaling by n^-1
 * @param[out] x12: dmem pointer to r
 * @param[in]  w16 (sw0): sw0.0 = q = 3329 (1st 16-bit lane),
 *                        sw0.2 = -q^-1 mod 2^16 = 3327 (3rd 16-bit lane)
 * @param[in]  w31: all-zero register
 * @param[in]  mod: 2q
 *
 * clobbered registers: x4, x10, x12, w0 to w15, w17 to w25, mod, acch, acc
 * clobbered flag groups: none
 */

.globl intt
.type intt, @function
intt:
  /* Load x. */
  add    x4, x0, x0
  bn.lid x4++, 0(x10)
  bn.lid x4++, 32(x10)
  bn.lid x4++, 64(x10)
  bn.lid x4++, 96(x10)
  bn.lid x4++, 128(x10)
  bn.lid x4++, 160(x10)
  bn.lid x4++, 192(x10)
  bn.lid x4++, 224(x10)
  bn.lid x4++, 256(x10)
  bn.lid x4++, 288(x10)
  bn.lid x4++, 320(x10)
  bn.lid x4++, 352(x10)
  bn.lid x4++, 384(x10)
  bn.lid x4++, 416(x10)
  bn.lid x4++, 448(x10)
  bn.lid x4++, 480(x10)
  addi   x10, x10, 512 /* Point to next polynomial. */

  /* Transpose for Layer 7--5. */
  bn.trn1.8s w18, w0, w1
  bn.trn2.8s w19, w0, w1
  bn.trn1.8s w20, w2, w3
  bn.trn2.8s w21, w2, w3
  bn.trn1.8s w22, w4, w5
  bn.trn2.8s w23, w4, w5
  bn.trn1.8s w24, w6, w7
  bn.trn2.8s w25, w6, w7

  bn.trn1.4d w0, w18, w20
  bn.trn2.4d w2, w18, w20
  bn.trn1.4d w1, w19, w21
  bn.trn2.4d w3, w19, w21
  bn.trn1.4d w4, w22, w24
  bn.trn2.4d w6, w22, w24
  bn.trn1.4d w5, w23, w25
  bn.trn2.4d w7, w23, w25

  bn.trn1.2q w18, w0, w4
  bn.trn2.2q w22, w0, w4
  bn.trn1.2q w19, w1, w5
  bn.trn2.2q w23, w1, w5
  bn.trn1.2q w20, w2, w6
  bn.trn2.2q w24, w2, w6
  bn.trn1.2q w21, w3, w7
  bn.trn2.2q w25, w3, w7

  bn.trn1.8s w0, w8, w9
  bn.trn2.8s w1, w8, w9
  bn.trn1.8s w2, w10, w11
  bn.trn2.8s w3, w10, w11
  bn.trn1.8s w4, w12, w13
  bn.trn2.8s w5, w12, w13
  bn.trn1.8s w6, w14, w15
  bn.trn2.8s w7, w14, w15

  bn.trn1.4d w8, w0, w2
  bn.trn2.4d w10, w0, w2
  bn.trn1.4d w9, w1, w3
  bn.trn2.4d w11, w1, w3
  bn.trn1.4d w12, w4, w6
  bn.trn2.4d w14, w4, w6
  bn.trn1.4d w13, w5, w7
  bn.trn2.4d w15, w5, w7

  bn.trn1.2q w0, w8, w12
  bn.trn2.2q w4, w8, w12
  bn.trn1.2q w1, w9, w13
  bn.trn2.2q w5, w9, w13
  bn.trn1.2q w2, w10, w14
  bn.trn2.2q w6, w10, w14
  bn.trn1.2q w3, w11, w15
  bn.trn2.2q w7, w11, w15

  /* Layer 7, stride 2. */
  addi                 x4, x0, 17
  bn.lid               x4, 0(x11)
  bn.subvm.16h         w8, w18, w19
  bn.addvm.16h         w18, w18, w19
  bn.mulv.16h.acc.z.lo w19, w8, w17
  bn.mulv.l.16h.lo     w19, w19, sw0.2
  bn.mulv.l.16h.acc.hi w19, w19, sw0.0

  bn.lid               x4, 32(x11)
  bn.subvm.16h         w8, w20, w21
  bn.addvm.16h         w20, w20, w21
  bn.mulv.16h.acc.z.lo w21, w8, w17
  bn.mulv.l.16h.lo     w21, w21, sw0.2
  bn.mulv.l.16h.acc.hi w21, w21, sw0.0

  bn.lid               x4, 64(x11)
  bn.subvm.16h         w8, w22, w23
  bn.addvm.16h         w22, w22, w23
  bn.mulv.16h.acc.z.lo w23, w8, w17
  bn.mulv.l.16h.lo     w23, w23, sw0.2
  bn.mulv.l.16h.acc.hi w23, w23, sw0.0

  bn.lid               x4, 96(x11)
  bn.subvm.16h         w8, w24, w25
  bn.addvm.16h         w24, w24, w25
  bn.mulv.16h.acc.z.lo w25, w8, w17
  bn.mulv.l.16h.lo     w25, w25, sw0.2
  bn.mulv.l.16h.acc.hi w25, w25, sw0.0

  bn.lid               x4, 128(x11)
  bn.subvm.16h         w8, w0, w1
  bn.addvm.16h         w0, w0, w1
  bn.mulv.16h.acc.z.lo w1, w8, w17
  bn.mulv.l.16h.lo     w1, w1, sw0.2
  bn.mulv.l.16h.acc.hi w1, w1, sw0.0

  bn.lid               x4, 160(x11)
  bn.subvm.16h         w8, w2, w3
  bn.addvm.16h         w2, w2, w3
  bn.mulv.16h.acc.z.lo w3, w8, w17
  bn.mulv.l.16h.lo     w3, w3, sw0.2
  bn.mulv.l.16h.acc.hi w3, w3, sw0.0

  bn.lid               x4, 192(x11)
  bn.subvm.16h         w8, w4, w5
  bn.addvm.16h         w4, w4, w5
  bn.mulv.16h.acc.z.lo w5, w8, w17
  bn.mulv.l.16h.lo     w5, w5, sw0.2
  bn.mulv.l.16h.acc.hi w5, w5, sw0.0

  bn.lid               x4, 224(x11)
  bn.subvm.16h         w8, w6, w7
  bn.addvm.16h         w6, w6, w7
  bn.mulv.16h.acc.z.lo w7, w8, w17
  bn.mulv.l.16h.lo     w7, w7, sw0.2
  bn.mulv.l.16h.acc.hi w7, w7, sw0.0

  /* Layer 6, stride 4. */
  bn.lid               x4, 256(x11)
  bn.subvm.16h         w8, w18, w20
  bn.addvm.16h         w18, w18, w20
  bn.mulv.16h.acc.z.lo w20, w8, w17
  bn.mulv.l.16h.lo     w20, w20, sw0.2
  bn.mulv.l.16h.acc.hi w20, w20, sw0.0

  bn.subvm.16h         w8, w19, w21
  bn.addvm.16h         w19, w19, w21
  bn.mulv.16h.acc.z.lo w21, w8, w17
  bn.mulv.l.16h.lo     w21, w21, sw0.2
  bn.mulv.l.16h.acc.hi w21, w21, sw0.0

  bn.lid               x4, 288(x11)
  bn.subvm.16h         w8, w22, w24
  bn.addvm.16h         w22, w22, w24
  bn.mulv.16h.acc.z.lo w24, w8, w17
  bn.mulv.l.16h.lo     w24, w24, sw0.2
  bn.mulv.l.16h.acc.hi w24, w24, sw0.0

  bn.subvm.16h         w8, w23, w25
  bn.addvm.16h         w23, w23, w25
  bn.mulv.16h.acc.z.lo w25, w8, w17
  bn.mulv.l.16h.lo     w25, w25, sw0.2
  bn.mulv.l.16h.acc.hi w25, w25, sw0.0

  bn.lid               x4, 320(x11)
  bn.subvm.16h         w8, w0, w2
  bn.addvm.16h         w0, w0, w2
  bn.mulv.16h.acc.z.lo w2, w8, w17
  bn.mulv.l.16h.lo     w2, w2, sw0.2
  bn.mulv.l.16h.acc.hi w2, w2, sw0.0

  bn.subvm.16h         w8, w1, w3
  bn.addvm.16h         w1, w1, w3
  bn.mulv.16h.acc.z.lo w3, w8, w17
  bn.mulv.l.16h.lo     w3, w3, sw0.2
  bn.mulv.l.16h.acc.hi w3, w3, sw0.0

  bn.lid               x4, 352(x11)
  bn.subvm.16h         w8, w4, w6
  bn.addvm.16h         w4, w4, w6
  bn.mulv.16h.acc.z.lo w6, w8, w17
  bn.mulv.l.16h.lo     w6, w6, sw0.2
  bn.mulv.l.16h.acc.hi w6, w6, sw0.0

  bn.subvm.16h         w8, w5, w7
  bn.addvm.16h         w5, w5, w7
  bn.mulv.16h.acc.z.lo w7, w8, w17
  bn.mulv.l.16h.lo     w7, w7, sw0.2
  bn.mulv.l.16h.acc.hi w7, w7, sw0.0

  /* Layer 5, stride 8. */
  bn.lid               x4, 384(x11)
  bn.subvm.16h         w8, w18, w22
  bn.addvm.16h         w18, w18, w22
  bn.mulv.16h.acc.z.lo w22, w8, w17
  bn.mulv.l.16h.lo     w22, w22, sw0.2
  bn.mulv.l.16h.acc.hi w22, w22, sw0.0

  bn.subvm.16h         w8, w19, w23
  bn.addvm.16h         w19, w19, w23
  bn.mulv.16h.acc.z.lo w23, w8, w17
  bn.mulv.l.16h.lo     w23, w23, sw0.2
  bn.mulv.l.16h.acc.hi w23, w23, sw0.0

  bn.subvm.16h         w8, w20, w24
  bn.addvm.16h         w20, w20, w24
  bn.mulv.16h.acc.z.lo w24, w8, w17
  bn.mulv.l.16h.lo     w24, w24, sw0.2
  bn.mulv.l.16h.acc.hi w24, w24, sw0.0

  bn.subvm.16h         w8, w21, w25
  bn.addvm.16h         w21, w21, w25
  bn.mulv.16h.acc.z.lo w25, w8, w17
  bn.mulv.l.16h.lo     w25, w25, sw0.2
  bn.mulv.l.16h.acc.hi w25, w25, sw0.0

  bn.lid               x4, 416(x11)
  bn.subvm.16h         w8, w0, w4
  bn.addvm.16h         w0, w0, w4
  bn.mulv.16h.acc.z.lo w4, w8, w17
  bn.mulv.l.16h.lo     w4, w4, sw0.2
  bn.mulv.l.16h.acc.hi w4, w4, sw0.0

  bn.subvm.16h         w8, w1, w5
  bn.addvm.16h         w1, w1, w5
  bn.mulv.16h.acc.z.lo w5, w8, w17
  bn.mulv.l.16h.lo     w5, w5, sw0.2
  bn.mulv.l.16h.acc.hi w5, w5, sw0.0

  bn.subvm.16h         w8, w2, w6
  bn.addvm.16h         w2, w2, w6
  bn.mulv.16h.acc.z.lo w6, w8, w17
  bn.mulv.l.16h.lo     w6, w6, sw0.2
  bn.mulv.l.16h.acc.hi w6, w6, sw0.0

  bn.subvm.16h         w8, w3, w7
  bn.addvm.16h         w3, w3, w7
  bn.mulv.16h.acc.z.lo w7, w8, w17
  bn.mulv.l.16h.lo     w7, w7, sw0.2
  bn.mulv.l.16h.acc.hi w7, w7, sw0.0

  /* Transpose back. */
  bn.trn1.8s w8, w0, w1
  bn.trn2.8s w9, w0, w1
  bn.trn1.8s w10, w2, w3
  bn.trn2.8s w11, w2, w3
  bn.trn1.8s w12, w4, w5
  bn.trn2.8s w13, w4, w5
  bn.trn1.8s w14, w6, w7
  bn.trn2.8s w15, w6, w7

  bn.trn1.4d w0, w8, w10
  bn.trn2.4d w2, w8, w10
  bn.trn1.4d w1, w9, w11
  bn.trn2.4d w3, w9, w11
  bn.trn1.4d w4, w12, w14
  bn.trn2.4d w6, w12, w14
  bn.trn1.4d w5, w13, w15
  bn.trn2.4d w7, w13, w15

  bn.trn1.2q w8, w0, w4
  bn.trn2.2q w12, w0, w4
  bn.trn1.2q w9, w1, w5
  bn.trn2.2q w13, w1, w5
  bn.trn1.2q w10, w2, w6
  bn.trn2.2q w14, w2, w6
  bn.trn1.2q w11, w3, w7
  bn.trn2.2q w15, w3, w7

  bn.trn1.8s w0, w18, w19
  bn.trn2.8s w1, w18, w19
  bn.trn1.8s w2, w20, w21
  bn.trn2.8s w3, w20, w21
  bn.trn1.8s w4, w22, w23
  bn.trn2.8s w5, w22, w23
  bn.trn1.8s w6, w24, w25
  bn.trn2.8s w7, w24, w25

  bn.trn1.4d w18, w0, w2
  bn.trn2.4d w20, w0, w2
  bn.trn1.4d w19, w1, w3
  bn.trn2.4d w21, w1, w3
  bn.trn1.4d w22, w4, w6
  bn.trn2.4d w24, w4, w6
  bn.trn1.4d w23, w5, w7
  bn.trn2.4d w25, w5, w7

  bn.trn1.2q w0, w18, w22
  bn.trn2.2q w4, w18, w22
  bn.trn1.2q w1, w19, w23
  bn.trn2.2q w5, w19, w23
  bn.trn1.2q w2, w20, w24
  bn.trn2.2q w6, w20, w24
  bn.trn1.2q w3, w21, w25
  bn.trn2.2q w7, w21, w25

  /* Layer 4, stride 16. */
  bn.lid                 x4, 448(x11)
  bn.subvm.16h           w24, w0, w1
  bn.addvm.16h           w0, w0, w1
  bn.mulv.l.16h.acc.z.lo w1, w24, sw1.0
  bn.mulv.l.16h.lo       w1, w1, sw0.2
  bn.mulv.l.16h.acc.hi   w1, w1, sw0.0

  bn.subvm.16h           w24, w2, w3
  bn.addvm.16h           w2, w2, w3
  bn.mulv.l.16h.acc.z.lo w3, w24, sw1.1
  bn.mulv.l.16h.lo       w3, w3, sw0.2
  bn.mulv.l.16h.acc.hi   w3, w3, sw0.0

  bn.subvm.16h           w24, w4, w5
  bn.addvm.16h           w4, w4, w5
  bn.mulv.l.16h.acc.z.lo w5, w24, sw1.2
  bn.mulv.l.16h.lo       w5, w5, sw0.2
  bn.mulv.l.16h.acc.hi   w5, w5, sw0.0

  bn.subvm.16h           w24, w6, w7
  bn.addvm.16h           w6, w6, w7
  bn.mulv.l.16h.acc.z.lo w7, w24, sw1.3
  bn.mulv.l.16h.lo       w7, w7, sw0.2
  bn.mulv.l.16h.acc.hi   w7, w7, sw0.0

  bn.subvm.16h           w24, w8, w9
  bn.addvm.16h           w8, w8, w9
  bn.mulv.l.16h.acc.z.lo w9, w24, sw1.4
  bn.mulv.l.16h.lo       w9, w9, sw0.2
  bn.mulv.l.16h.acc.hi   w9, w9, sw0.0

  bn.subvm.16h           w24, w10, w11
  bn.addvm.16h           w10, w10, w11
  bn.mulv.l.16h.acc.z.lo w11, w24, sw1.5
  bn.mulv.l.16h.lo       w11, w11, sw0.2
  bn.mulv.l.16h.acc.hi   w11, w11, sw0.0

  bn.subvm.16h           w24, w12, w13
  bn.addvm.16h           w12, w12, w13
  bn.mulv.l.16h.acc.z.lo w13, w24, sw1.6
  bn.mulv.l.16h.lo       w13, w13, sw0.2
  bn.mulv.l.16h.acc.hi   w13, w13, sw0.0

  bn.subvm.16h           w24, w14, w15
  bn.addvm.16h           w14, w14, w15
  bn.mulv.l.16h.acc.z.lo w15, w24, sw1.7
  bn.mulv.l.16h.lo       w15, w15, sw0.2
  bn.mulv.l.16h.acc.hi   w15, w15, sw0.0

  /* Layer 3, stride 32. */
  bn.subvm.16h           w24, w0, w2
  bn.addvm.16h           w0, w0, w2
  bn.mulv.l.16h.acc.z.lo w2, w24, sw1.8
  bn.mulv.l.16h.lo       w2, w2, sw0.2
  bn.mulv.l.16h.acc.hi   w2, w2, sw0.0

  bn.subvm.16h           w24, w1, w3
  bn.addvm.16h           w1, w1, w3
  bn.mulv.l.16h.acc.z.lo w3, w24, sw1.8
  bn.mulv.l.16h.lo       w3, w3, sw0.2
  bn.mulv.l.16h.acc.hi   w3, w3, sw0.0

  bn.subvm.16h           w24, w4, w6
  bn.addvm.16h           w4, w4, w6
  bn.mulv.l.16h.acc.z.lo w6, w24, sw1.9
  bn.mulv.l.16h.lo       w6, w6, sw0.2
  bn.mulv.l.16h.acc.hi   w6, w6, sw0.0

  bn.subvm.16h           w24, w5, w7
  bn.addvm.16h           w5, w5, w7
  bn.mulv.l.16h.acc.z.lo w7, w24, sw1.9
  bn.mulv.l.16h.lo       w7, w7, sw0.2
  bn.mulv.l.16h.acc.hi   w7, w7, sw0.0

  bn.subvm.16h           w24, w8, w10
  bn.addvm.16h           w8, w8, w10
  bn.mulv.l.16h.acc.z.lo w10, w24, sw1.10
  bn.mulv.l.16h.lo       w10, w10, sw0.2
  bn.mulv.l.16h.acc.hi   w10, w10, sw0.0

  bn.subvm.16h           w24, w9, w11
  bn.addvm.16h           w9, w9, w11
  bn.mulv.l.16h.acc.z.lo w11, w24, sw1.10
  bn.mulv.l.16h.lo       w11, w11, sw0.2
  bn.mulv.l.16h.acc.hi   w11, w11, sw0.0

  bn.subvm.16h           w24, w12, w14
  bn.addvm.16h           w12, w12, w14
  bn.mulv.l.16h.acc.z.lo w14, w24, sw1.11
  bn.mulv.l.16h.lo       w14, w14, sw0.2
  bn.mulv.l.16h.acc.hi   w14, w14, sw0.0

  bn.subvm.16h           w24, w13, w15
  bn.addvm.16h           w13, w13, w15
  bn.mulv.l.16h.acc.z.lo w15, w24, sw1.11
  bn.mulv.l.16h.lo       w15, w15, sw0.2
  bn.mulv.l.16h.acc.hi   w15, w15, sw0.0

  /* Layer 2, stride 64. */
  bn.subvm.16h           w24, w0, w4
  bn.addvm.16h           w0, w0, w4
  bn.mulv.l.16h.acc.z.lo w4, w24, sw1.12
  bn.mulv.l.16h.lo       w4, w4, sw0.2
  bn.mulv.l.16h.acc.hi   w4, w4, sw0.0

  bn.subvm.16h           w24, w1, w5
  bn.addvm.16h           w1, w1, w5
  bn.mulv.l.16h.acc.z.lo w5, w24, sw1.12
  bn.mulv.l.16h.lo       w5, w5, sw0.2
  bn.mulv.l.16h.acc.hi   w5, w5, sw0.0

  bn.subvm.16h           w24, w2, w6
  bn.addvm.16h           w2, w2, w6
  bn.mulv.l.16h.acc.z.lo w6, w24, sw1.12
  bn.mulv.l.16h.lo       w6, w6, sw0.2
  bn.mulv.l.16h.acc.hi   w6, w6, sw0.0

  bn.subvm.16h           w24, w3, w7
  bn.addvm.16h           w3, w3, w7
  bn.mulv.l.16h.acc.z.lo w7, w24, sw1.12
  bn.mulv.l.16h.lo       w7, w7, sw0.2
  bn.mulv.l.16h.acc.hi   w7, w7, sw0.0

  bn.subvm.16h           w24, w8, w12
  bn.addvm.16h           w8, w8, w12
  bn.mulv.l.16h.acc.z.lo w12, w24, sw1.13
  bn.mulv.l.16h.lo       w12, w12, sw0.2
  bn.mulv.l.16h.acc.hi   w12, w12, sw0.0

  bn.subvm.16h           w24, w9, w13
  bn.addvm.16h           w9, w9, w13
  bn.mulv.l.16h.acc.z.lo w13, w24, sw1.13
  bn.mulv.l.16h.lo       w13, w13, sw0.2
  bn.mulv.l.16h.acc.hi   w13, w13, sw0.0

  bn.subvm.16h           w24, w10, w14
  bn.addvm.16h           w10, w10, w14
  bn.mulv.l.16h.acc.z.lo w14, w24, sw1.13
  bn.mulv.l.16h.lo       w14, w14, sw0.2
  bn.mulv.l.16h.acc.hi   w14, w14, sw0.0

  bn.subvm.16h           w24, w11, w15
  bn.addvm.16h           w11, w11, w15
  bn.mulv.l.16h.acc.z.lo w15, w24, sw1.13
  bn.mulv.l.16h.lo       w15, w15, sw0.2
  bn.mulv.l.16h.acc.hi   w15, w15, sw0.0

  /* Layer 1, stride 128. */
  bn.subvm.16h           w24, w0, w8
  bn.addvm.16h           w0, w0, w8
  bn.mulv.l.16h.acc.z.lo w8, w24, sw1.14
  bn.mulv.l.16h.lo       w8, w8, sw0.2
  bn.mulv.l.16h.acc.hi   w8, w8, sw0.0

  bn.subvm.16h           w24, w1, w9
  bn.addvm.16h           w1, w1, w9
  bn.mulv.l.16h.acc.z.lo w9, w24, sw1.14
  bn.mulv.l.16h.lo       w9, w9, sw0.2
  bn.mulv.l.16h.acc.hi   w9, w9, sw0.0

  bn.subvm.16h           w24, w2, w10
  bn.addvm.16h           w2, w2, w10
  bn.mulv.l.16h.acc.z.lo w10, w24, sw1.14
  bn.mulv.l.16h.lo       w10, w10, sw0.2
  bn.mulv.l.16h.acc.hi   w10, w10, sw0.0

  bn.subvm.16h           w24, w3, w11
  bn.addvm.16h           w3, w3, w11
  bn.mulv.l.16h.acc.z.lo w11, w24, sw1.14
  bn.mulv.l.16h.lo       w11, w11, sw0.2
  bn.mulv.l.16h.acc.hi   w11, w11, sw0.0

  bn.subvm.16h           w24, w4, w12
  bn.addvm.16h           w4, w4, w12
  bn.mulv.l.16h.acc.z.lo w12, w24, sw1.14
  bn.mulv.l.16h.lo       w12, w12, sw0.2
  bn.mulv.l.16h.acc.hi   w12, w12, sw0.0

  bn.subvm.16h           w24, w5, w13
  bn.addvm.16h           w5, w5, w13
  bn.mulv.l.16h.acc.z.lo w13, w24, sw1.14
  bn.mulv.l.16h.lo       w13, w13, sw0.2
  bn.mulv.l.16h.acc.hi   w13, w13, sw0.0

  bn.subvm.16h           w24, w6, w14
  bn.addvm.16h           w6, w6, w14
  bn.mulv.l.16h.acc.z.lo w14, w24, sw1.14
  bn.mulv.l.16h.lo       w14, w14, sw0.2
  bn.mulv.l.16h.acc.hi   w14, w14, sw0.0

  bn.subvm.16h           w24, w7, w15
  bn.addvm.16h           w7, w7, w15
  bn.mulv.l.16h.acc.z.lo w15, w24, sw1.14
  bn.mulv.l.16h.lo       w15, w15, sw0.2
  bn.mulv.l.16h.acc.hi   w15, w15, sw0.0

  /* At the end of 7th layer, all coeffs are in [0,2q). Here, we switch
   * mod back to q so that output of INTT would be in [0,q). */
  bn.wsrr w24, mod
  bn.wsrw mod, w16

  /* Multiply with n^{-1} mod q. */
  bn.mulv.l.16h.acc.z.lo w0, w0, sw1.15
  bn.mulv.l.16h.lo       w0, w0, sw0.2
  bn.mulv.l.16h.acc.hi   w0, w0, sw0.0
  bn.addvm.16h           w0, w0, w31

  bn.mulv.l.16h.acc.z.lo w1, w1, sw1.15
  bn.mulv.l.16h.lo       w1, w1, sw0.2
  bn.mulv.l.16h.acc.hi   w1, w1, sw0.0
  bn.addvm.16h           w1, w1, w31

  bn.mulv.l.16h.acc.z.lo w2, w2, sw1.15
  bn.mulv.l.16h.lo       w2, w2, sw0.2
  bn.mulv.l.16h.acc.hi   w2, w2, sw0.0
  bn.addvm.16h           w2, w2, w31

  bn.mulv.l.16h.acc.z.lo w3, w3, sw1.15
  bn.mulv.l.16h.lo       w3, w3, sw0.2
  bn.mulv.l.16h.acc.hi   w3, w3, sw0.0
  bn.addvm.16h           w3, w3, w31

  bn.mulv.l.16h.acc.z.lo w4, w4, sw1.15
  bn.mulv.l.16h.lo       w4, w4, sw0.2
  bn.mulv.l.16h.acc.hi   w4, w4, sw0.0
  bn.addvm.16h           w4, w4, w31

  bn.mulv.l.16h.acc.z.lo w5, w5, sw1.15
  bn.mulv.l.16h.lo       w5, w5, sw0.2
  bn.mulv.l.16h.acc.hi   w5, w5, sw0.0
  bn.addvm.16h           w5, w5, w31

  bn.mulv.l.16h.acc.z.lo w6, w6, sw1.15
  bn.mulv.l.16h.lo       w6, w6, sw0.2
  bn.mulv.l.16h.acc.hi   w6, w6, sw0.0
  bn.addvm.16h           w6, w6, w31

  bn.mulv.l.16h.acc.z.lo w7, w7, sw1.15
  bn.mulv.l.16h.lo       w7, w7, sw0.2
  bn.mulv.l.16h.acc.hi   w7, w7, sw0.0
  bn.addvm.16h           w7, w7, w31

  /* Since switching mod back and forth between q and 2q is inefficient during the last layer, we
   * use addvm with mod = q here for the other half of the coeffs to reduce them in [0,q). */
  bn.addvm.16h w8, w8, w31
  bn.addvm.16h w9, w9, w31
  bn.addvm.16h w10, w10, w31
  bn.addvm.16h w11, w11, w31
  bn.addvm.16h w12, w12, w31
  bn.addvm.16h w13, w13, w31
  bn.addvm.16h w14, w14, w31
  bn.addvm.16h w15, w15, w31

  /* Restore mod = 2q for the next INTT. */
  bn.wsrw mod, w24

  /* Store r. */
  add    x4, x0, x0
  bn.sid x4++, 0(x12)
  bn.sid x4++, 32(x12)
  bn.sid x4++, 64(x12)
  bn.sid x4++, 96(x12)
  bn.sid x4++, 128(x12)
  bn.sid x4++, 160(x12)
  bn.sid x4++, 192(x12)
  bn.sid x4++, 224(x12)
  bn.sid x4++, 256(x12)
  bn.sid x4++, 288(x12)
  bn.sid x4++, 320(x12)
  bn.sid x4++, 352(x12)
  bn.sid x4++, 384(x12)
  bn.sid x4++, 416(x12)
  bn.sid x4++, 448(x12)
  bn.sid x4++, 480(x12)
  addi   x12, x12, 512 /* Point to next polynomial. */
  ret
