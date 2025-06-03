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
.global poly_add_base_dilithium
poly_add_base_dilithium:
    

    /* Init mask */
    bn.addi w7, w31, 1
    bn.or w7, w31, w7 << 32
    bn.subi w7, w7, 1

    /* Set up constants for input/state */
    li x6, 2
    li x5, 3
    li x4, 6

    LOOPI 32, 9
        bn.lid x6, 0(x10++)
        bn.lid x5, 0(x11++)

        LOOPI 8, 5
            /* Mask one coefficient to working registers */
            bn.and w4, w2, w7
            bn.and w5, w3, w7
            /* Shift out used coefficient */
            bn.rshi w2, w31, w2 >> 32

            bn.addm w4, w4, w5
            bn.rshi w3, w4, w3 >> 32
        
        bn.sid x5, 0(x12++)

    ret

/**
 * Constant Time Dilithium polynomial addition - pseudo vectorized
 *
 * Returns: add(input1, input2) NOT reduced
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
.global poly_add_pseudovec_base_dilithium
poly_add_pseudovec_base_dilithium:
    

    /* Init mask */
    bn.addi w7, w31, 1
    bn.or w7, w31, w7 << 32
    bn.subi w7, w7, 1

    /* Set up constants for input/state */
    li x6, 2
    li x5, 3
    li x4, 6

    LOOPI 32, 4
        bn.lid x6, 0(x10++)
        bn.lid x5, 0(x11++)

        bn.add w6, w2, w3
        
        bn.sid x4, 0(x12++)

    ret

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
.global poly_sub_base_dilithium
poly_sub_base_dilithium:
    

    /* Init mask */
    bn.addi w7, w31, 1
    bn.or w7, w31, w7 << 32
    bn.subi w7, w7, 1

    /* Set up constants for input/state */
    li x6, 2
    li x5, 3
    li x4, 6

    LOOPI 32, 9
        bn.lid x6, 0(x10++)
        bn.lid x5, 0(x11++)

        LOOPI 8, 5
            /* Mask one coefficient to working registers */
            bn.and w4, w2, w7
            bn.and w5, w3, w7
            /* Shift out used coefficient */
            bn.rshi w2, w31, w2 >> 32

            bn.subm w4, w4, w5
            bn.rshi w3, w4, w3 >> 32
        
        bn.sid x5, 0(x12++)

    ret