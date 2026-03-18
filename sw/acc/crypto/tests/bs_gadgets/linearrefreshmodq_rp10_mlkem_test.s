/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#ifndef NSHARES
    #define NSHARES 2
#endif

#define N_WDR 16
#define NB_POLY 512
#define STACK_SIZE 20000

.section .text.start

main:
    /* All-zero register. */
    bn.xor w31, w31, w31

    /* MOD <= dmem[modulus] = KYBER_Q */
    la      x6, modulus_bn
    bn.lid  x0, 0(x6)
    bn.rshi w0, w31, w0 >> 240
    bn.wsrw mod, w0

    /* Load stack pointer. */
    la  x2, stack_end

    /* dmem[ra] <= linearrefreshmodq_rp10_mlkem(dmem[xa], nshares) */
    bn.wsrr w16, mod
    la      x10, xa
    li      x11, NSHARES
    la      x12, ra
    jal     x1, linearrefreshmodq_rp10_mlkem

    /* Compute r */
    la   x2, ra
    la   x3, r
    li   x4, 1
    addi x5, x11, -1
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
modulus_bn:
    .word 0x0d010d01
    .word 0x0d010d01
    .word 0x0d010d01
    .word 0x0d010d01
    .word 0x0d010d01
    .word 0x0d010d01
    .word 0x0d010d01
    .word 0x0d010d01

.globl modulus_times_19
modulus_times_19:
	.word 0xf713f713
	.word 0xf713f713
	.word 0xf713f713
	.word 0xf713f713
	.word 0xf713f713
	.word 0xf713f713
	.word 0xf713f713
	.word 0xf713f713

.globl mont
mont:
    .word 0x08ed08ed
    .word 0x08ed08ed
    .word 0x08ed08ed
    .word 0x08ed08ed
    .word 0x08ed08ed
    .word 0x08ed08ed
    .word 0x08ed08ed
    .word 0x08ed08ed

r:
    .zero 32 * N_WDR
