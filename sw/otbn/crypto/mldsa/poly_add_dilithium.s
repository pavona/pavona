/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors */
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
.global poly_add_dilithium
poly_add_dilithium:
    /* Set up constants for input/state */
    li x6, 2
    li x5, 3
    li x4, 4

    LOOPI 32, 4
        bn.lid x6, 0(x10++)
        bn.lid x5, 0(x11++)
        
        bn.addvm.8S w2, w2, w3
        
        bn.sid x6, 0(x12++)

    ret