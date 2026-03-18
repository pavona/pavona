/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/* This function is specific to ML-KEM. */

#ifndef NSHARES
    #define NSHARES 2
#endif

#ifndef SCHEME
    #define SCHEME 0
#endif

#define N_WDR 16
#define NB_POLY 512
#define STACK_SIZE 20000

.section .text.start

/* This test does the following:
 *  (1) Compute r = amask(x, nshares)
 *  (2) Compute r = (r[1] +  ... + r[nshares]) mod Q
 *  (4) Check r =? x. */
main:
    /* Load Q to MOD. */
    la      x4, modulus_bn
    bn.lid  x0, 0(x4)
    bn.rshi w0, w31, w0 >> 240
    bn.wsrw MOD, w0

    /* Load stack pointer. */
    la  x2, stack_end
    /* dmem[r] <= amask(dmem[x], nshares) */
    la  x10, x
    li  x11, NSHARES
    la  x12, xa
    jal x1, amask

    /* Compute r */
    la   x2, xa
    la   x3, r
    li   x4, 1
    li   x5, NSHARES
    addi x5, x5, -1
    loopi N_WDR, 7
        addi   x6, x2, NB_POLY
        bn.lid x0, 0(x2++)
        loop x5, 3
            bn.lid       x4, 0(x6)
            bn.addvm.16h w0, w0, w1
            addi         x6, x6, NB_POLY
        bn.sid x0, 0(x3++)
    ecall

.data
.balign 32
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
