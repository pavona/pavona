/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#ifndef NSHARES
    #define NSHARES 2
#endif
#define STACK_SIZE 8192

.section .text.start

main:
    /* Load stack pointer */
    la x2, stack_end

    /* dmem[rb] <= seca2bmodq_bc22_mlkem(dmem[xa], k, share stride, nshares). */
    la  x10, xa
    li  x11, NSHARES
    la  x12, rb
    jal x1, seca2bmodq_bc22_mlkem

    /* Compute r */
    la     x2, rb
    la     x3, r
    li     x4, 1
    li     x5, NSHARES
    addi   x5, x5, -1
    loopi 12, 7
        addi   x7, x2, 384
        bn.lid x0, 0(x2++)
        loop x5, 3
            bn.lid x4, 0(x7)
            bn.xor w0, w0, w1
            addi   x7, x7, 384
        bn.sid x0, 0(x3++)

    ecall

.data
.balign 32
stack:
    .zero STACK_SIZE
stack_end:
r:
    .zero 32 * 12
