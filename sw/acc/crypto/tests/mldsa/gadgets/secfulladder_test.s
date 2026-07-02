/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#define NSHARES 2
#define STACK_SIZE 1024

.section .text.start

main:
    /* All-zero register. */
    bn.xor w31, w31, w31

    /* Load stack pointer */
    la x2, stack_end

    /* dmem[rb], dmem[coutb] <= secfulladder(dmem[xb], dmem[yb], dmem[cb]) */
    la  x10, xb
    la  x11, yb
    la  x12, cb
    li  x13, 32
    la  x15, rb
    la  x16, coutb
    jal x1, secfulladder

    /* Compute r */
    la     x3, r
    li     x4, 1
    addi   x5, x0, NSHARES
    addi   x5, x5, -1
    /* Compute r[0]. */
    la     x2, rb
    bn.lid x0, 0(x2++)
    loop x5, 2
        bn.lid x4, 0(x2++)
        bn.xor w0, w0, w1
    endloop
    bn.sid x0, 0(x3++)
    /* Compute r[1]. */
    la     x2, coutb
    bn.lid x0, 0(x2++)
    loop x5, 2
        bn.lid x4, 0(x2++)
        bn.xor w0, w0, w1
    endloop
    bn.sid x0, 0(x3++)

    ecall

.data
.balign 32
stack:
    .zero STACK_SIZE
stack_end:
r:
    .zero 64
