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

/* Given a Boolean-shared polynomial xb = [xb_1, xb_2,...,xb_nshares],
 * refresh_bbd16 outputs a new Boolean-shared polynomial
 * rb = [rb_1, rb_2,...,rb_nshares]. This test does the following:
 *  (1) Compute rb = refresh_bbd16(xb)
 *  (2) Compute r = rb_1 ^ ... ^ rb_nshares
 *  (4) Check dexp =? r where dexp = x = xb_1 ^ ... ^ xb_nshares. */
main:
    /* dmem[rb] <= refresh_bbd16(dmem[xb], nshares) */
    la  x10, xb
    li  x11, NSHARES
    la  x12, rb
    jal x1, refresh_bbd16

    /* Compute r */
    la   x2, rb
    la   x3, r
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
r:
    .zero 32 * N_WDR
