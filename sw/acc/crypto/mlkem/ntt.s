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
 * Number Theoretic Transform (NTT).
 *
 * Return r = NTT(x) for ML-KEM with n = 256 and q = 3329.
 *
 * On return, x10 and x12 have been advanced by one polynomial (512 bytes),
 * so that consecutive calls walk a polynomial vector.
 *
 * This routine is constant time.
 *
 * @param[in]  x10: dmem pointer to x
 * @param[in]  x11: dmem pointer to the twiddle factors twiddles_ntt
 * @param[out] x12: dmem pointer to r
 * @param[in]  w31: all-zero register
 * @param[in]  mod: 2q
 *
 * clobbered registers: x4, x10, x12, w0 to w15, w17 to w25, acc, acch
 * clobbered flag groups: none
 */

.globl ntt
.type ntt, @function
ntt:
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

  /* Load twiddle factors for Layer 1--4. */
  addi   x4, x0, 17
  bn.lid x4, 0(x11)

  /* Layer 1, stride 128. */
  bn.mulv.l.16h.acc.z.lo w24, w8, sw1.0
  bn.mulv.l.16h.lo       w24, w24, sw0.2
  bn.mulv.l.16h.acc.hi   w24, w24, sw0.0
  bn.subvm.16h           w8, w0, w24
  bn.addvm.16h           w0, w0, w24

  bn.mulv.l.16h.acc.z.lo w24, w9, sw1.0
  bn.mulv.l.16h.lo       w24, w24, sw0.2
  bn.mulv.l.16h.acc.hi   w24, w24, sw0.0
  bn.subvm.16h           w9, w1, w24
  bn.addvm.16h           w1, w1, w24

  bn.mulv.l.16h.acc.z.lo w24, w10, sw1.0
  bn.mulv.l.16h.lo       w24, w24, sw0.2
  bn.mulv.l.16h.acc.hi   w24, w24, sw0.0
  bn.subvm.16h           w10, w2, w24
  bn.addvm.16h           w2, w2, w24

  bn.mulv.l.16h.acc.z.lo w24, w11, sw1.0
  bn.mulv.l.16h.lo       w24, w24, sw0.2
  bn.mulv.l.16h.acc.hi   w24, w24, sw0.0
  bn.subvm.16h           w11, w3, w24
  bn.addvm.16h           w3, w3, w24

  bn.mulv.l.16h.acc.z.lo w24, w12, sw1.0
  bn.mulv.l.16h.lo       w24, w24, sw0.2
  bn.mulv.l.16h.acc.hi   w24, w24, sw0.0
  bn.subvm.16h           w12, w4, w24
  bn.addvm.16h           w4, w4, w24

  bn.mulv.l.16h.acc.z.lo w24, w13, sw1.0
  bn.mulv.l.16h.lo       w24, w24, sw0.2
  bn.mulv.l.16h.acc.hi   w24, w24, sw0.0
  bn.subvm.16h           w13, w5, w24
  bn.addvm.16h           w5, w5, w24

  bn.mulv.l.16h.acc.z.lo w24, w14, sw1.0
  bn.mulv.l.16h.lo       w24, w24, sw0.2
  bn.mulv.l.16h.acc.hi   w24, w24, sw0.0
  bn.subvm.16h           w14, w6, w24
  bn.addvm.16h           w6, w6, w24

  bn.mulv.l.16h.acc.z.lo w24, w15, sw1.0
  bn.mulv.l.16h.lo       w24, w24, sw0.2
  bn.mulv.l.16h.acc.hi   w24, w24, sw0.0
  bn.subvm.16h           w15, w7, w24
  bn.addvm.16h           w7, w7, w24

  /* Layer 2, stride 64. */
  bn.mulv.l.16h.acc.z.lo w24, w4, sw1.1
  bn.mulv.l.16h.lo       w24, w24, sw0.2
  bn.mulv.l.16h.acc.hi   w24, w24, sw0.0
  bn.subvm.16h           w4, w0, w24
  bn.addvm.16h           w0, w0, w24

  bn.mulv.l.16h.acc.z.lo w24, w5, sw1.1
  bn.mulv.l.16h.lo       w24, w24, sw0.2
  bn.mulv.l.16h.acc.hi   w24, w24, sw0.0
  bn.subvm.16h           w5, w1, w24
  bn.addvm.16h           w1, w1, w24

  bn.mulv.l.16h.acc.z.lo w24, w6, sw1.1
  bn.mulv.l.16h.lo       w24, w24, sw0.2
  bn.mulv.l.16h.acc.hi   w24, w24, sw0.0
  bn.subvm.16h           w6, w2, w24
  bn.addvm.16h           w2, w2, w24

  bn.mulv.l.16h.acc.z.lo w24, w7, sw1.1
  bn.mulv.l.16h.lo       w24, w24, sw0.2
  bn.mulv.l.16h.acc.hi   w24, w24, sw0.0
  bn.subvm.16h           w7, w3, w24
  bn.addvm.16h           w3, w3, w24

  bn.mulv.l.16h.acc.z.lo w24, w12, sw1.2
  bn.mulv.l.16h.lo       w24, w24, sw0.2
  bn.mulv.l.16h.acc.hi   w24, w24, sw0.0
  bn.subvm.16h           w12, w8, w24
  bn.addvm.16h           w8, w8, w24

  bn.mulv.l.16h.acc.z.lo w24, w13, sw1.2
  bn.mulv.l.16h.lo       w24, w24, sw0.2
  bn.mulv.l.16h.acc.hi   w24, w24, sw0.0
  bn.subvm.16h           w13, w9, w24
  bn.addvm.16h           w9, w9, w24

  bn.mulv.l.16h.acc.z.lo w24, w14, sw1.2
  bn.mulv.l.16h.lo       w24, w24, sw0.2
  bn.mulv.l.16h.acc.hi   w24, w24, sw0.0
  bn.subvm.16h           w14, w10, w24
  bn.addvm.16h           w10, w10, w24

  bn.mulv.l.16h.acc.z.lo w24, w15, sw1.2
  bn.mulv.l.16h.lo       w24, w24, sw0.2
  bn.mulv.l.16h.acc.hi   w24, w24, sw0.0
  bn.subvm.16h           w15, w11, w24
  bn.addvm.16h           w11, w11, w24

  /* Layer 3, stride 32. */
  bn.mulv.l.16h.acc.z.lo w24, w2, sw1.3
  bn.mulv.l.16h.lo       w24, w24, sw0.2
  bn.mulv.l.16h.acc.hi   w24, w24, sw0.0
  bn.subvm.16h           w2, w0, w24
  bn.addvm.16h           w0, w0, w24

  bn.mulv.l.16h.acc.z.lo w24, w3, sw1.3
  bn.mulv.l.16h.lo       w24, w24, sw0.2
  bn.mulv.l.16h.acc.hi   w24, w24, sw0.0
  bn.subvm.16h           w3, w1, w24
  bn.addvm.16h           w1, w1, w24

  bn.mulv.l.16h.acc.z.lo w24, w6, sw1.4
  bn.mulv.l.16h.lo       w24, w24, sw0.2
  bn.mulv.l.16h.acc.hi   w24, w24, sw0.0
  bn.subvm.16h           w6, w4, w24
  bn.addvm.16h           w4, w4, w24

  bn.mulv.l.16h.acc.z.lo w24, w7, sw1.4
  bn.mulv.l.16h.lo       w24, w24, sw0.2
  bn.mulv.l.16h.acc.hi   w24, w24, sw0.0
  bn.subvm.16h           w7, w5, w24
  bn.addvm.16h           w5, w5, w24

  bn.mulv.l.16h.acc.z.lo w24, w10, sw1.5
  bn.mulv.l.16h.lo       w24, w24, sw0.2
  bn.mulv.l.16h.acc.hi   w24, w24, sw0.0
  bn.subvm.16h           w10, w8, w24
  bn.addvm.16h           w8, w8, w24

  bn.mulv.l.16h.acc.z.lo w24, w11, sw1.5
  bn.mulv.l.16h.lo       w24, w24, sw0.2
  bn.mulv.l.16h.acc.hi   w24, w24, sw0.0
  bn.subvm.16h           w11, w9, w24
  bn.addvm.16h           w9, w9, w24

  bn.mulv.l.16h.acc.z.lo w24, w14, sw1.6
  bn.mulv.l.16h.lo       w24, w24, sw0.2
  bn.mulv.l.16h.acc.hi   w24, w24, sw0.0
  bn.subvm.16h           w14, w12, w24
  bn.addvm.16h           w12, w12, w24

  bn.mulv.l.16h.acc.z.lo w24, w15, sw1.6
  bn.mulv.l.16h.lo       w24, w24, sw0.2
  bn.mulv.l.16h.acc.hi   w24, w24, sw0.0
  bn.subvm.16h           w15, w13, w24
  bn.addvm.16h           w13, w13, w24

  /* Layer 4, stride 16. */
  bn.mulv.l.16h.acc.z.lo w24, w1, sw1.7
  bn.mulv.l.16h.lo       w24, w24, sw0.2
  bn.mulv.l.16h.acc.hi   w24, w24, sw0.0
  bn.subvm.16h           w1, w0, w24
  bn.addvm.16h           w0, w0, w24

  bn.mulv.l.16h.acc.z.lo w24, w3, sw1.8
  bn.mulv.l.16h.lo       w24, w24, sw0.2
  bn.mulv.l.16h.acc.hi   w24, w24, sw0.0
  bn.subvm.16h           w3, w2, w24
  bn.addvm.16h           w2, w2, w24

  bn.mulv.l.16h.acc.z.lo w24, w5, sw1.9
  bn.mulv.l.16h.lo       w24, w24, sw0.2
  bn.mulv.l.16h.acc.hi   w24, w24, sw0.0
  bn.subvm.16h           w5, w4, w24
  bn.addvm.16h           w4, w4, w24

  bn.mulv.l.16h.acc.z.lo w24, w7, sw1.10
  bn.mulv.l.16h.lo       w24, w24, sw0.2
  bn.mulv.l.16h.acc.hi   w24, w24, sw0.0
  bn.subvm.16h           w7, w6, w24
  bn.addvm.16h           w6, w6, w24

  bn.mulv.l.16h.acc.z.lo w24, w9, sw1.11
  bn.mulv.l.16h.lo       w24, w24, sw0.2
  bn.mulv.l.16h.acc.hi   w24, w24, sw0.0
  bn.subvm.16h           w9, w8, w24
  bn.addvm.16h           w8, w8, w24

  bn.mulv.l.16h.acc.z.lo w24, w11, sw1.12
  bn.mulv.l.16h.lo       w24, w24, sw0.2
  bn.mulv.l.16h.acc.hi   w24, w24, sw0.0
  bn.subvm.16h           w11, w10, w24
  bn.addvm.16h           w10, w10, w24

  bn.mulv.l.16h.acc.z.lo w24, w13, sw1.13
  bn.mulv.l.16h.lo       w24, w24, sw0.2
  bn.mulv.l.16h.acc.hi   w24, w24, sw0.0
  bn.subvm.16h           w13, w12, w24
  bn.addvm.16h           w12, w12, w24

  bn.mulv.l.16h.acc.z.lo w24, w15, sw1.14
  bn.mulv.l.16h.lo       w24, w24, sw0.2
  bn.mulv.l.16h.acc.hi   w24, w24, sw0.0
  bn.subvm.16h           w15, w14, w24
  bn.addvm.16h           w14, w14, w24

  /* Transpose for Layer 5--7. */
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

  /* Layer 5, stride 8. */
  bn.lid               x4, 32(x11)
  bn.mulv.16h.acc.z.lo w8, w22, w17
  bn.mulv.l.16h.lo     w8, w8, sw0.2
  bn.mulv.l.16h.acc.hi w8, w8, sw0.0
  bn.subvm.16h         w22, w18, w8
  bn.addvm.16h         w18, w18, w8

  bn.mulv.16h.acc.z.lo w8, w23, w17
  bn.mulv.l.16h.lo     w8, w8, sw0.2
  bn.mulv.l.16h.acc.hi w8, w8, sw0.0
  bn.subvm.16h         w23, w19, w8
  bn.addvm.16h         w19, w19, w8

  bn.mulv.16h.acc.z.lo w8, w24, w17
  bn.mulv.l.16h.lo     w8, w8, sw0.2
  bn.mulv.l.16h.acc.hi w8, w8, sw0.0
  bn.subvm.16h         w24, w20, w8
  bn.addvm.16h         w20, w20, w8

  bn.mulv.16h.acc.z.lo w8, w25, w17
  bn.mulv.l.16h.lo     w8, w8, sw0.2
  bn.mulv.l.16h.acc.hi w8, w8, sw0.0
  bn.subvm.16h         w25, w21, w8
  bn.addvm.16h         w21, w21, w8

  bn.lid               x4, 64(x11)
  bn.mulv.16h.acc.z.lo w8, w4, w17
  bn.mulv.l.16h.lo     w8, w8, sw0.2
  bn.mulv.l.16h.acc.hi w8, w8, sw0.0
  bn.subvm.16h         w4, w0, w8
  bn.addvm.16h         w0, w0, w8

  bn.mulv.16h.acc.z.lo w8, w5, w17
  bn.mulv.l.16h.lo     w8, w8, sw0.2
  bn.mulv.l.16h.acc.hi w8, w8, sw0.0
  bn.subvm.16h         w5, w1, w8
  bn.addvm.16h         w1, w1, w8

  bn.mulv.16h.acc.z.lo w8, w6, w17
  bn.mulv.l.16h.lo     w8, w8, sw0.2
  bn.mulv.l.16h.acc.hi w8, w8, sw0.0
  bn.subvm.16h         w6, w2, w8
  bn.addvm.16h         w2, w2, w8

  bn.mulv.16h.acc.z.lo w8, w7, w17
  bn.mulv.l.16h.lo     w8, w8, sw0.2
  bn.mulv.l.16h.acc.hi w8, w8, sw0.0
  bn.subvm.16h         w7, w3, w8
  bn.addvm.16h         w3, w3, w8

  /* Layer 6, stride 4. */
  bn.lid               x4, 96(x11)
  bn.mulv.16h.acc.z.lo w8, w20, w17
  bn.mulv.l.16h.lo     w8, w8, sw0.2
  bn.mulv.l.16h.acc.hi w8, w8, sw0.0
  bn.subvm.16h         w20, w18, w8
  bn.addvm.16h         w18, w18, w8

  bn.mulv.16h.acc.z.lo w8, w21, w17
  bn.mulv.l.16h.lo     w8, w8, sw0.2
  bn.mulv.l.16h.acc.hi w8, w8, sw0.0
  bn.subvm.16h         w21, w19, w8
  bn.addvm.16h         w19, w19, w8

  bn.lid               x4, 128(x11)
  bn.mulv.16h.acc.z.lo w8, w24, w17
  bn.mulv.l.16h.lo     w8, w8, sw0.2
  bn.mulv.l.16h.acc.hi w8, w8, sw0.0
  bn.subvm.16h         w24, w22, w8
  bn.addvm.16h         w22, w22, w8

  bn.mulv.16h.acc.z.lo w8, w25, w17
  bn.mulv.l.16h.lo     w8, w8, sw0.2
  bn.mulv.l.16h.acc.hi w8, w8, sw0.0
  bn.subvm.16h         w25, w23, w8
  bn.addvm.16h         w23, w23, w8

  bn.lid               x4, 160(x11)
  bn.mulv.16h.acc.z.lo w8, w2, w17
  bn.mulv.l.16h.lo     w8, w8, sw0.2
  bn.mulv.l.16h.acc.hi w8, w8, sw0.0
  bn.subvm.16h         w2, w0, w8
  bn.addvm.16h         w0, w0, w8

  bn.mulv.16h.acc.z.lo w8, w3, w17
  bn.mulv.l.16h.lo     w8, w8, sw0.2
  bn.mulv.l.16h.acc.hi w8, w8, sw0.0
  bn.subvm.16h         w3, w1, w8
  bn.addvm.16h         w1, w1, w8

  bn.lid               x4, 192(x11)
  bn.mulv.16h.acc.z.lo w8, w6, w17
  bn.mulv.l.16h.lo     w8, w8, sw0.2
  bn.mulv.l.16h.acc.hi w8, w8, sw0.0
  bn.subvm.16h         w6, w4, w8
  bn.addvm.16h         w4, w4, w8

  bn.mulv.16h.acc.z.lo w8, w7, w17
  bn.mulv.l.16h.lo     w8, w8, sw0.2
  bn.mulv.l.16h.acc.hi w8, w8, sw0.0
  bn.subvm.16h         w7, w5, w8
  bn.addvm.16h         w5, w5, w8

  /* Layer 7, stride 2. */
  bn.lid               x4, 224(x11)
  bn.mulv.16h.acc.z.lo w8, w19, w17
  bn.mulv.l.16h.lo     w8, w8, sw0.2
  bn.mulv.l.16h.acc.hi w8, w8, sw0.0
  bn.subvm.16h         w19, w18, w8
  bn.addvm.16h         w18, w18, w8

  bn.lid               x4, 256(x11)
  bn.mulv.16h.acc.z.lo w8, w21, w17
  bn.mulv.l.16h.lo     w8, w8, sw0.2
  bn.mulv.l.16h.acc.hi w8, w8, sw0.0
  bn.subvm.16h         w21, w20, w8
  bn.addvm.16h         w20, w20, w8

  bn.lid               x4, 288(x11)
  bn.mulv.16h.acc.z.lo w8, w23, w17
  bn.mulv.l.16h.lo     w8, w8, sw0.2
  bn.mulv.l.16h.acc.hi w8, w8, sw0.0
  bn.subvm.16h         w23, w22, w8
  bn.addvm.16h         w22, w22, w8

  bn.lid               x4, 320(x11)
  bn.mulv.16h.acc.z.lo w8, w25, w17
  bn.mulv.l.16h.lo     w8, w8, sw0.2
  bn.mulv.l.16h.acc.hi w8, w8, sw0.0
  bn.subvm.16h         w25, w24, w8
  bn.addvm.16h         w24, w24, w8

  bn.lid               x4, 352(x11)
  bn.mulv.16h.acc.z.lo w8, w1, w17
  bn.mulv.l.16h.lo     w8, w8, sw0.2
  bn.mulv.l.16h.acc.hi w8, w8, sw0.0
  bn.subvm.16h         w1, w0, w8
  bn.addvm.16h         w0, w0, w8

  bn.lid               x4, 384(x11)
  bn.mulv.16h.acc.z.lo w8, w3, w17
  bn.mulv.l.16h.lo     w8, w8, sw0.2
  bn.mulv.l.16h.acc.hi w8, w8, sw0.0
  bn.subvm.16h         w3, w2, w8
  bn.addvm.16h         w2, w2, w8

  bn.lid               x4, 416(x11)
  bn.mulv.16h.acc.z.lo w8, w5, w17
  bn.mulv.l.16h.lo     w8, w8, sw0.2
  bn.mulv.l.16h.acc.hi w8, w8, sw0.0
  bn.subvm.16h         w5, w4, w8
  bn.addvm.16h         w4, w4, w8

  bn.lid               x4, 448(x11)
  bn.mulv.16h.acc.z.lo w8, w7, w17
  bn.mulv.l.16h.lo     w8, w8, sw0.2
  bn.mulv.l.16h.acc.hi w8, w8, sw0.0
  bn.subvm.16h         w7, w6, w8
  bn.addvm.16h         w6, w6, w8

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
