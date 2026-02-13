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
 * Constant Time Dilithium polynomial addition
 *
 * Returns: add(input1, input2) reduced mod q (taken from MOD WDR)
 *
 * This implements the polynomial addition for e.g. Dilithium, where n=256.
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
.global poly_add
poly_add:
    /* Set up constants for input/state */
    li x4, 1

    LOOPI 32, 4
        bn.lid      x0, 0(x10++)
        bn.lid      x4, 0(x11++)
        bn.addvm.8S w0, w0, w1
        bn.sid      x0, 0(x12++)
    ret
