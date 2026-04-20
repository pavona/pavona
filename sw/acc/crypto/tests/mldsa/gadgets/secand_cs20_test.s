/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#ifndef NSHARES
    #define NSHARES 2
#endif
#define STACK_SIZE 1024

.section .text.start

main:
    /* Load stack pointer. */
    la  x2, stack_end

    /* dmem[rb] <= secand_cs20(dmem[xb], dmem[yb], nshares) */
    la  x10, xb
    li  x11, 32
    la  x12, yb
    li  x13, 32
    li  x14, NSHARES
    li  x15, 32
    la  x16, rb
    jal x1, secand_cs20

    /* Compute r */
    la     x2, rb
    la     x3, r
    li     x4, 1
    li     x5, NSHARES
    addi   x5, x5, -1
    bn.lid x0, 0(x2++)
    loop x5, 2
        bn.lid x4, 0(x2++)
        bn.xor w0, w0, w1
    bn.sid x0, 0(x3)

    ecall

.data
.balign 32
stack:
    .zero STACK_SIZE
stack_end:
r:
    .zero 32
