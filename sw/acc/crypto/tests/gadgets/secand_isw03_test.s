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
    #define STACK_SIZE 20000
#else
    #define N_WDR 32
    #define NB_POLY 1024
    #define STACK_SIZE 20000
#endif

.section .text.start

/* This test does the following:
 *  (1) Compute rb = secand_isw03(xb, yb, nshares)
 *  (2) Compute r = rb[1] ^ ... ^ rb[nshares]
 *  (4) Check dexp =? r where dexp = x & y. */
main:
    /* Load stack pointer. */
    la  x2, stack_end

    /* dmem[rb] <= secand_isw03(dmem[xb], dmem[yb], nshares) */
    la  x10, xb
    la  x11, yb
    li  x12, NSHARES
    la  x13, rb
    li  x14, N_WDR
    li  x15, NB_POLY
    jal x1, secand_isw03

    /* Compute r */
    la   x2, rb
    la   x3, r
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
    ecall

.data
.balign 32
stack:
    .zero STACK_SIZE
stack_end:
r:
    .zero 32 * N_WDR
