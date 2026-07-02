/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#define NSHARES 2
#define STACK_SIZE 1024

.section .text.start

main:
    /* All-zero register. */
    bn.xor w31, w31, w31

    /* Load stack pointer. */
    la  x2, stack_end

    /* dmem[rb5] <= secadd(dmem[xb5], dmem[yb5]), k = 5 */
    la  x10, xb5
    la  x11, yb5
    li  x12, 5
    li  x13, 160
    la  x15, rb5
    jal x1, secadd

    /* dmem[rb24] <= secadd(dmem[xb24], dmem[yb24]), k = 24 */
    la  x10, xb24
    la  x11, yb24
    li  x12, 24
    li  x13, 768
    la  x15, rb24
    jal x1, secadd

    /* dmem[rb32] <= secadd(dmem[xb32], dmem[yb32]), k = 32 */
    la  x10, xb32
    la  x11, yb32
    li  x12, 32
    li  x13, 1024
    la  x15, rb32
    jal x1, secadd

    /* Recombine each result: r[i] = rb[i] ^ rb[i + k]. */
    li     x4, 1

    la     x2, rb5
    la     x3, r5
    li     x6, 5
    loop x6, 5
        addi   x7, x2, 160
        bn.lid x0, 0(x2++)
        bn.lid x4, 0(x7)
        bn.xor w0, w0, w1
        bn.sid x0, 0(x3++)
    endloop

    la     x2, rb24
    la     x3, r24
    li     x6, 24
    loop x6, 5
        addi   x7, x2, 768
        bn.lid x0, 0(x2++)
        bn.lid x4, 0(x7)
        bn.xor w0, w0, w1
        bn.sid x0, 0(x3++)
    endloop

    la     x2, rb32
    la     x3, r32
    li     x6, 32
    loop x6, 5
        addi   x7, x2, 1024
        bn.lid x0, 0(x2++)
        bn.lid x4, 0(x7)
        bn.xor w0, w0, w1
        bn.sid x0, 0(x3++)
    endloop

    ecall

.data
.balign 32
stack:
    .zero STACK_SIZE
stack_end:
r5:
    .zero 160
r24:
    .zero 768
r32:
    .zero 1024
