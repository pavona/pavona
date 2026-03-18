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

    /* Load stack pointer */
    la x2, stack_end

    /* Load R || Q to mod. */
    addi    x4, x0, 0
    la      x5, modulus_bn
    bn.lid  x4++, 0(x5)
    bn.rshi w0, w31, w0 >> 240
    la      x5, modulus_inv
    bn.lid  x4, 0(x5)
    bn.or   w0, w0, w1 << 32 /* mod = R | Q */
    bn.wsrw mod, w0

    /* dmem[ra] <= onebitdecompress_bgr21(dmem[xb], nshares) */
    bn.wsrr w16, mod
    la      x10, xb
    li      x11, NSHARES
    la      x12, ra
    jal     x1, onebitdecompress_bgr21

    /* Compute r */
    la   x2, ra
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
modulus_bn:
    .word 0x0d010d01
    .word 0x0d010d01
    .word 0x0d010d01
    .word 0x0d010d01
    .word 0x0d010d01
    .word 0x0d010d01
    .word 0x0d010d01
    .word 0x0d010d01

.globl modulus_inv
modulus_inv:
    .word 0x00000cff
    .word 0x00000000
    .word 0x00000000
    .word 0x00000000
    .word 0x00000000
    .word 0x00000000
    .word 0x00000000
    .word 0x00000000

/* ((Q + 1) / 2) * (2^16) % 3329. */
.globl modulus_over_2_m2_16
modulus_over_2_m2_16:
    .word 0x0af70af7
    .word 0x0af70af7
    .word 0x0af70af7
    .word 0x0af70af7
    .word 0x0af70af7
    .word 0x0af70af7
    .word 0x0af70af7
    .word 0x0af70af7

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
    .zero 512 * NSHARES
