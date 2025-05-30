/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors */
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
.globl poly_pointwise_dilithium
poly_pointwise_dilithium:
    /* Set up constants for input/state */
    li x4, 2
    li x5, 3
    li x6, 4

    LOOPI 32, 4
        bn.lid x4, 0(x10++)
        bn.lid x5, 0(x11++)
        
        bn.mulvm.8S w2, w2, w3, 0
        
        bn.sid x4, 0(x12++)

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
 * @param[in/out] x12: dmem pointer to result
 *
 * clobbered registers: x4-x6, w2-w4
 */
.globl poly_pointwise_acc_dilithium
poly_pointwise_acc_dilithium:
    /* Set up constants for input/state */
    li x4, 2
    li x5, 3
    li x6, 4

    LOOPI 32, 6
        bn.lid x4, 0(x10++)
        bn.lid x5, 0(x11++)
        
        bn.mulvm.8S w2, w2, w3
        
        /* Accumulate onto output polynomial */
        bn.lid x5, 0(x12)
        bn.addvm.8S w2, w2, w3
        
        bn.sid x4, 0(x12++)

    ret