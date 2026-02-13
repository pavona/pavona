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
 * Constant Time Dilithium base multiplication (pointwise)
 *
 * Returns: poly_pointwise(input1, input2)
 *
 * This implements the base multiplication for Dilithium, where n=256,q=8380417.
 *
 * Flags: -
 *
 * @param[in]  x10: dptr_input1, dmem pointer to first word of input1 polynomial
 * @param[in]  x11: dptr_input2, dmem pointer to first word of input2 polynomial
 * @param[in]  w31: all-zero
 * @param[out] x12: dmem pointer to result
 *
 * clobbered registers: x4-x6, w2-w4
 */
.globl poly_pointwise
poly_pointwise:
    /* Set up constants for input/state */
    li x4, 1

    LOOPI 32, 9
        bn.lid x0, 0(x10++)
        bn.lid x4, 0(x11++)

        bn.mulv.8S.even.acc.z.lo w0, w0, w1
        bn.mulv.l.8S.even.lo     w0, w0, sw0.1
        bn.mulv.l.8S.even.acc.hi w0, w0, sw0.0
        bn.mulv.8S.odd.acc.z.lo  w0, w0, w1
        bn.mulv.l.8S.odd.lo      w0, w0, sw0.1
        bn.mulv.l.8S.odd.acc.hi  w0, w0, sw0.0

        bn.sid x0, 0(x12++)

    ret

/**
 * Constant Time Dilithium base multiplication (pointwise) with accumulation
 *
 * Returns: poly_pointwise_acc(input1, input2)
 *
 * This implements the base multiplication for Dilithium, where n=256,q=8380417.
 * Accumulates onto the output polynomial.
 *
 * Flags: -
 *
 * @param[in]  x10: dptr_input1, dmem pointer to first word of input1 polynomial
 * @param[in]  x11: dptr_input2, dmem pointer to first word of input2 polynomial
 * @param[in]  w31: all-zero
 * @param[in]  w16: sw0, where s0.0 = Q and sw0.1 = Q^-1 mod 2^32
 * @param[in/out] x12: dmem pointer to result
 *
 * clobbered registers: x4-x6, w2-w4
 */
.globl poly_pointwise_acc
poly_pointwise_acc:
    /* Set up constants for input/state */
    li x4, 1

    LOOPI 32, 11
        bn.lid x0, 0(x10++)
        bn.lid x4, 0(x11++)

        bn.mulv.8S.even.acc.z.lo w0, w0, w1
        bn.mulv.l.8S.even.lo     w0, w0, sw0.1
        bn.mulv.l.8S.even.acc.hi w0, w0, sw0.0
        bn.mulv.8S.odd.acc.z.lo  w0, w0, w1
        bn.mulv.l.8S.odd.lo      w0, w0, sw0.1
        bn.mulv.l.8S.odd.acc.hi  w0, w0, sw0.0

        /* Accumulate onto output polynomial */
        bn.lid      x4, 0(x12)
        bn.addvm.8S w0, w0, w1

        bn.sid x0, 0(x12++)

    ret
