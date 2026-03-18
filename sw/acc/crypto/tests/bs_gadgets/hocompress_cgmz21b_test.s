/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#ifndef NSHARES
    #define NSHARES 2
#endif

#if KYBER_K == 4
    #define DV 5
    #define DU 11
    #define SHARE_STR_DV 160
    #define SHARE_STR_DU 352
#else
    #define DV 4
    #define DU 10
    #define SHARE_STR_DV 128
    #define SHARE_STR_DU 320
#endif

#define STACK_SIZE 20000

.section .text.start

main:
    /* Load stack pointer */
    la x2, stack_end

    /* dmem[ra] <= hocompress_cgmz21b(dmem[xa], nshares). */
    la  x10, xa
    li  x11, NSHARES
    la  x12, rbv
    li  x13, KYBER_K
    jal x1, poly_hocompress_cgmz21b

    /* Compute rv. */
    la     x2, rbv
    la     x3, rv
    li     x4, 1
    li     x5, NSHARES
    addi   x5, x5, -1
    li     x6, DV
    loop x6, 7
        addi   x7, x2, SHARE_STR_DV
        bn.lid x0, 0(x2++)
        loop x5, 3
            bn.lid x4, 0(x7)
            bn.xor w0, w0, w1
            addi   x7, x7, SHARE_STR_DV
        bn.sid x0, 0(x3++)

    /* Load stack pointer */
    la x2, stack_end

    /* dmem[ra] <= hocompress_cgmz21b(dmem[xa], nshares). */
    la  x10, xa
    li  x11, NSHARES
    la  x12, rbu
    li  x13, KYBER_K
    jal x1, poly_polyvec_hocompress_cgmz21b

    /* Compute ru. */
    la     x2, rbu
    la     x3, ru
    li     x4, 1
    li     x5, NSHARES
    addi   x5, x5, -1
    li     x6, DU
    loop x6, 7
        addi   x7, x2, SHARE_STR_DU
        bn.lid x0, 0(x2++)
        loop x5, 3
            bn.lid x4, 0(x7)
            bn.xor w0, w0, w1
            addi   x7, x7, SHARE_STR_DU
        bn.sid x0, 0(x3++)

    ecall

.data
.balign 32
stack:
    .zero STACK_SIZE
stack_end:

.globl modulus_over_2
modulus_over_2:
    .word 0x06810681
    .word 0x06810681
    .word 0x06810681
    .word 0x06810681
    .word 0x06810681
    .word 0x06810681
    .word 0x06810681
    .word 0x06810681


.data
.balign 32
.globl const_m_dv
const_m_dv:
    .word 0x0275f6ed
    .word 0x0275f6ed
    .word 0x0275f6ed
    .word 0x0275f6ed
    .word 0x0275f6ed
    .word 0x0275f6ed
    .word 0x0275f6ed
    .word 0x0275f6ed

.globl const_m_du
const_m_du:
    .word 0x680bb055
    .word 0x0013afb7
    .word 0x680bb055
    .word 0x0013afb7
    .word 0x680bb055
    .word 0x0013afb7
    .word 0x680bb055
    .word 0x0013afb7

.globl const_one_8
const_one_8:
    .word 0x00000001
    .word 0x00000001
    .word 0x00000001
    .word 0x00000001
    .word 0x00000001
    .word 0x00000001
    .word 0x00000001
    .word 0x00000001

.globl const_1664
const_1664:
    .word 0x00000680
    .word 0x00000000
    .word 0x00000680
    .word 0x00000000
    .word 0x00000680
    .word 0x00000000
    .word 0x00000680
    .word 0x00000000

rv:
    .zero 32 * DV

ru:
    .zero 32 * DU
