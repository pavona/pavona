/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#ifndef NSHARES
    #define NSHARES 2
#endif
#ifndef SCHEME
    #define SCHEME 0
#endif

#if SCHEME == 0
    #define BITSIZE 16
    #define SHARE_STR 512
#else
    #define BITSIZE 32
    #define SHARE_STR 1024
#endif

#define STACK_SIZE 1024

.section .text.start

main:
    /* Load stack pointer. */
    la  x2, stack_end

    /* dmem[rb] <= secadd_bc22(dmem[xb], dmem[yb], nshares) */
    la  x10, xb
    la  x11, yb
    li  x12, BITSIZE
    li  x13, SHARE_STR
    li  x14, NSHARES
    la  x15, rb
    jal x1, secadd_bc22

    /* Compute r */
    la     x2, rb
    la     x3, r
    li     x4, 1
    li     x5, NSHARES
    addi   x5, x5, -1
    li     x6, BITSIZE
    loop x6, 7
        addi   x7, x2, SHARE_STR
        bn.lid x0, 0(x2++)
        loop x5, 3
            bn.lid x4, 0(x7)
            bn.xor w0, w0, w1
            addi   x7, x7, SHARE_STR
        bn.sid x0, 0(x3++)

    ecall

.data
.balign 32
stack:
    .zero STACK_SIZE
stack_end:
r:
    .zero 32 * BITSIZE
