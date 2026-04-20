/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#ifndef NSHARES
    #define NSHARES 2
#endif
#define STACK_SIZE 1024

.section .text.start

main:
    /* Load stack pointer */
    la x2, stack_end

    /* dmem[rb] <= secfulladder_bc22(dmem[xb], dmem[yb], nshares) */
    la  x10, xb
    la  x11, yb
    la  x12, cb
    la  x13, 32
    li  x14, NSHARES
    la  x15, rb
    la  x16, coutb
    jal x1, secfulladder_bc22

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
    bn.sid x0, 0(x3++)
    /* Compute r[1]. */
    la     x2, coutb
    bn.lid x0, 0(x2++)
    loop x5, 2
        bn.lid x4, 0(x2++)
        bn.xor w0, w0, w1
    bn.sid x0, 0(x3++)

    ecall

.data
.balign 32
stack:
    .zero STACK_SIZE
stack_end:
r:
    .zero 64
