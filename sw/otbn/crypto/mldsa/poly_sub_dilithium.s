/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

/**
 * Constant Time Dilithium polynomial subtraction
 *
 * Returns: sub(input1, input2) reduced mod q
 *
 * This implements the polynomial subtraction for Dilithium, where n=256,q=8380417.
 *
 * Flags: -
 * 
 * @param[in]  x10: dptr_input1, dmem pointer to first word of input1 polynomial
 * @param[in]  x11: dptr_input2, dmem pointer to first word of input2 polynomial
 * @param[in]  w31: all-zero
 * @param[out] x12: dmem pointer to result
 *
 * clobbered registers: x4 to x5
 *                      w2 to w3
 */
.globl poly_sub_dilithium
poly_sub_dilithium:
    /* Set up constants for input/state */
    li x4, 2
    li x5, 3

    LOOPI 32, 4
        bn.lid x4, 0(x10++)
        bn.lid x5, 0(x11++)
        
        bn.subvm.8S w2, w2, w3
        
        bn.sid x4, 0(x12++)

    ret