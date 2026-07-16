/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/*
 * Constant-time whitening step for NTT, INTT and pair-pointwise multiplication.
 *
 * clobbered registers: w0 to w15, w17 to w25
 * clobbered flag groups: none
 */
.globl whitening
.type whitening, @function
whitening:
    bn.xor w0, w0, w0
    bn.xor w1, w1, w1
    bn.xor w2, w2, w2
    bn.xor w3, w3, w3
    bn.xor w4, w4, w4
    bn.xor w5, w5, w5
    bn.xor w6, w6, w6
    bn.xor w7, w7, w7
    bn.xor w8, w8, w8
    bn.xor w9, w9, w9
    bn.xor w10, w10, w10
    bn.xor w11, w11, w11
    bn.xor w12, w12, w12
    bn.xor w13, w13, w13
    bn.xor w14, w14, w14
    bn.xor w15, w15, w15
    bn.xor w17, w17, w17
    bn.xor w18, w18, w18
    bn.xor w19, w19, w19
    bn.xor w20, w20, w20
    bn.xor w21, w21, w21
    bn.xor w22, w22, w22
    bn.xor w23, w23, w23
    bn.xor w24, w24, w24
    bn.xor w25, w25, w25
    ret
