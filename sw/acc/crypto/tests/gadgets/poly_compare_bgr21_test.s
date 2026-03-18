/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/* This gadget is specific to ML-KEM. */

#ifndef NSHARES
    #define NSHARES 2
#endif

#ifndef KYBER_K
    #define KYBER_K 3
#endif

#if KYBER_K == 4
    #define DU 11
    #define DV 5
#else
    #define DU 10
    #define DV 4
#endif

#define N_WDR 16
#define NB_POLY 512
#define STACK_SIZE 16384

.section .text.start

/* This test does the following:
 *  (1) Compute rb = poly_compare(ca, c, dv, nshares)
 *  (2) Check dexp =? r where dexp = all-ones.
 *  (3) Compute rb = poly_compare(ca, c, du, nshares)
 *  (4) Check dexp =? r where dexp = all-ones. */
main:
        /* Load Q to MOD. */
    la      x4, modulus_bn
    bn.lid  x0, 0(x4)
    bn.rshi w0, w31, w0 >> 240
    bn.wsrw MOD, w0

    /* Test poly_compare_bgr21 for DV. */
    /* Load stack pointer */
    la x2, stack_end

    /* dmem[rb] <= poly_compare(dmem[ca], dmem[c], d, nshares) */
    la  x10, ca
    la  x11, cv
    li  x12, DV
    li  x13, NSHARES
    la  x14, res
    li  x15, KYBER_K
    jal x1, poly_compare_bgr21

    /* Compute w and x. */
    la     x2, res
    la     x3, r
    li     x5, NSHARES
    addi   x5, x5, -1
    /* Compute w. */
    bn.lid x0, 0(x2++)
    loop x5, 2
        bn.lid x4, 0(x2++)
        bn.xor w0, w0, w1/* Load stack pointer */
    bn.sid x0, 0(x3++)
    /* Compute x. */
    bn.lid x0, 0(x2++)
    loop x5, 2
        bn.lid x4, 0(x2++)
        bn.xor w0, w0, w1
    bn.sid x0, 0(x3++)

    /* Test poly_compare_bgr21 for DU. */
    /* Load stack pointer */
    la x2, stack_end

    /* dmem[rb] <= poly_compare(dmem[ca], dmem[c], d, nshares) */
    la  x10, ca
    la  x11, cu
    li  x12, DU
    li  x13, NSHARES
    la  x14, res
    li  x15, KYBER_K
    jal x1, poly_compare_bgr21

    /* Compute w and x. */
    la     x2, res
    la     x3, r
    addi   x3, x3, 64
    li     x5, NSHARES
    addi   x5, x5, -1
    /* Compute w. */
    bn.lid x0, 0(x2++)
    loop x5, 2
        bn.lid x4, 0(x2++)
        bn.xor w0, w0, w1
    bn.sid x0, 0(x3++)
    /* Compute x. */
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

.globl modulus_bn
modulus_bn:
    .word 0x0d010d01
    .word 0x0d010d01
    .word 0x0d010d01
    .word 0x0d010d01
    .word 0x0d010d01
    .word 0x0d010d01
    .word 0x0d010d01
    .word 0x0d010d01

res:
    .zero 32 * NSHARES * 2
r:
    .zero 128
