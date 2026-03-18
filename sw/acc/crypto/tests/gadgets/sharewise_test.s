/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#ifndef NSHARES
    #define NSHARES 2
#endif

#ifndef SCHEME
    #define SCHEME 0 /* 0: ML-KEM, 1: ML-DSA. */
#endif

#if SCHEME == 0
    #define N_WDR 16
    #define NB_POLY 512
#else
    #define N_WDR 32
    #define NB_POLY 1024
#endif

.section .text.start

/* This test does the following:
 *  - sharewise_xor:
 *      - Compute rb[i] = xb[i] ^ yb[i]
 *      - Compute r = rb[1] ^ ... ^ rb[nshares]
 *      - Check r =? dexp where dexp = x ^ y
 *  - sharewise_lsl:
 *      - Compute rb[i] = xb[i] << 5
 *      - Compute r = rb[1] ^ ... ^ rb[nshares]
 *      - Check r =? dexp where dexp = x << 5
 *  - sharewise_lsr:
 *      - Compute rb[i] = xb[i] >> 9
 *      - Compute r = rb[1] ^ ... ^ rb[nshares]
 *      - Check r =? dexp where dexp = x >> 9
 *  - sharewise_msb:
 *      - Compute rb[i] = MSB(xb[i])
 *      - Compute r = rb[1] ^ ... ^ rb[nshares]
 *      - Check r =? dexp where dexp = MSB(x)
 *  - sharewise_bitext:
 *      - Compute rb[i] = (xb[i] & 1) repeated [register bit size] times
 *      - Compute r = rb[1] ^ ... ^ rb[nshares]
 *      - Check r =? dexp where dexp = (x[i] & 1) repeated [register bit size] times
 */
main:
    /* Test sharewise_xor */
    /* dmem[rb] <= sharewise_xor(dmem[xb], dmem[yb], nshares) */
    la   x10, xb
    la   x11, yb
    li   x12, NSHARES
    la   x13, rb
    jal  x1, sharewise_xor
    /* Compute r */
    la   x2, rb
    la   x3, r_xor
    li   x4, 1
    addi x5, x12, -1
    loopi N_WDR, 7
        addi   x6, x2, NB_POLY
        bn.lid x0, 0(x2++)
        loop x5, 3
            bn.lid x4, 0(x6)
            bn.xor w0, w0, w1
            addi   x6, x6, NB_POLY
        bn.sid x0, 0(x3++)

    /* Test sharewise_lsl */
    /* dmem[rb] <= sharewise_xor(dmem[xb], s, nshares) */
    la   x10, xb
    li   x11, 5
    li   x12, NSHARES
    la   x13, rb
    jal  x1, sharewise_lsl
    /* Compute r */
    la   x2, rb
    la   x3, r_lsl
    li   x4, 1
    addi x5, x12, -1
    loopi N_WDR, 7
        addi   x6, x2, NB_POLY
        bn.lid x0, 0(x2++)
        loop x5, 3
            bn.lid x4, 0(x6)
            bn.xor w0, w0, w1
            addi   x6, x6, NB_POLY
        bn.sid x0, 0(x3++)


    /* Test sharewise_lsr */
    /* dmem[rb] <= sharewise_xor(dmem[xb], s, nshares) */
    la   x10, xb
    li   x11, 9
    li   x12, NSHARES
    la   x13, rb
    jal  x1, sharewise_lsr
    /* Compute r */
    la   x2, rb
    la   x3, r_lsr
    li   x4, 1
    addi x5, x12, -1
    loopi N_WDR, 7
        addi   x6, x2, NB_POLY
        bn.lid x0, 0(x2++)
        loop x5, 3
            bn.lid x4, 0(x6)
            bn.xor w0, w0, w1
            addi   x6, x6, NB_POLY
        bn.sid x0, 0(x3++)


    /* Test sharewise_msb */
    /* dmem[rb] <= sharewise_xor(dmem[xb], nshares) */
    la   x10, xb
    li   x11, NSHARES
    la   x12, rb
    jal  x1, sharewise_msb
    /* Compute r */
    la   x2, rb
    la   x3, r_msb
    li   x4, 1
    addi x5, x11, -1
    loopi N_WDR, 7
        addi   x6, x2, NB_POLY
        bn.lid x0, 0(x2++)
        loop x5, 3
            bn.lid x4, 0(x6)
            bn.xor w0, w0, w1
            addi   x6, x6, NB_POLY
        bn.sid x0, 0(x3++)


    /* Test sharewise_bitext */
    /* dmem[rb] <= sharewise_xor(dmem[xb], nshares) */
    la   x10, xb
    li   x11, NSHARES
    la   x12, rb
    jal  x1, sharewise_bitext
    /* Compute r */
    la   x2, rb
    la   x3, r_bitext
    li   x4, 1
    addi x5, x11, -1
    loopi N_WDR, 7
        addi   x6, x2, NB_POLY
        bn.lid x0, 0(x2++)
        loop x5, 3
            bn.lid x4, 0(x6)
            bn.xor w0, w0, w1
            addi   x6, x6, NB_POLY
        bn.sid x0, 0(x3++)

    ecall

.data
.balign 32
r_xor:
    .zero 32 * N_WDR

r_lsl:
    .zero 32 * N_WDR

r_lsr:
    .zero 32 * N_WDR

r_msb:
    .zero 32 * N_WDR

r_bitext:
    .zero 32 * N_WDR
