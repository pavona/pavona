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

#define STACK_SIZE 15360

.section .text.start

.equ x2, sp
.equ x8, s0
.equ x9, s1
.equ x10, a0
.equ x11, a1
.equ x12, a2
.equ x13, a3
.equ x14, a4
.equ x18, s2
.equ x19, s3
.equ x20, s4
.equ x21, s5

main:
    /* Load stack pointer */
    la sp, stack_end

    la s0, xv
    la s1, xu
    la s2, r
    la s3, cv
    la s4, cu
    li s5, NSHARES
    slli s5, s5, 9 /* NSHARES * 512 */

    /* dmem[ra] <= poly_masked_compare_bc22(dmem[xv], nshares). */
    addi a0, s0, 0
    addi a1, s3, 0
    addi a2, x0, SHARE_STR_DV
    addi a3, x0, NSHARES
    addi a4, s2, 0
    addi a5, x0, KYBER_K
    jal  x1, poly_masked_compare_bc22

    bn.subi w0, w0, 0
    /* dmem[ra] <= poly_masked_compare_bc22(dmem[xu], nshares). */
    loopi KYBER_K, 9
        addi a0, s1, 0
        addi a1, s4, 0
        addi a2, x0, SHARE_STR_DU
        addi a3, x0, NSHARES
        addi a4, s2, 0
        addi a5, x0, KYBER_K
        jal  x1, poly_polyvec_masked_compare_bc22
        add  s1, s1, s5
        addi s4, s4, SHARE_STR_DU

    /* Combine comparison results. */
    la   a0, r
    addi a1, x0, NSHARES
    jal  x1, finalize_cmp_bc22

    /* Unmask comparison result. */
    addi   x4, x0, 1
    la     a0, r
    addi   a1, x0, NSHARES
    addi   a1, a1, -1
    bn.lid x0, 0(a0++)
    loop a1, 2
        bn.lid x4, 0(a0++)
        bn.xor w0, w0, w1

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

r:
    .word 0xffffffff
    .word 0xffffffff
    .word 0xffffffff
    .word 0xffffffff
    .word 0xffffffff
    .word 0xffffffff
    .word 0xffffffff
    .word 0xffffffff
    .zero 32 * (NSHARES - 1)
