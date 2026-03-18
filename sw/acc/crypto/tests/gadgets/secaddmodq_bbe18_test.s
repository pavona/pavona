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
 *  (1) Compute rb = secaddmodq_bbe18(xb, yb, nshares)
 *  (2) Compute r = rb[1] ^ ... ^ rb[nshares]
 *  (4) Check dexp =? r where dexp = (x + y) mod q.
 * Modular addition here means conditional subtraction from q. */
main:
    /* Load stack pointer */
    la x2, stack_end

    /* dmem[rb] <= secaddmodq_bbe18(dmem[xb], dmem[yb], nshares) */
    la  x10, xb
    la  x11, yb
    li  x12, NSHARES
    la  x13, rb
    jal x1, secaddmodq_bbe18

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
/* The stack is for:
 *  - 4 masked polynomial + 32B for secadd_cgtv15
 *  - 1 masked polynomial + 32B for secand_isw03
 *  - 1 masked polynomial + 32B for secaddmodq_bbe18 */
stack:
    .zero STACK_SIZE
stack_end:

.globl modulus_bn
#if SCHEME == 0
modulus_bn:
    .word 0x0d010d01
    .word 0x0d010d01
    .word 0x0d010d01
    .word 0x0d010d01
    .word 0x0d010d01
    .word 0x0d010d01
    .word 0x0d010d01
    .word 0x0d010d01
#else
modulus_bn:
    .word 0x007fe001
    .word 0x007fe001
    .word 0x007fe001
    .word 0x007fe001
    .word 0x007fe001
    .word 0x007fe001
    .word 0x007fe001
    .word 0x007fe001
#endif

r:
    .zero 32 * N_WDR
