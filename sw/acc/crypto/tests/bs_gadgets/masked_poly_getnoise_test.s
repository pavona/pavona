/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#ifndef NSHARES
    #define NSHARES 2
#endif

#ifndef KYBER_K
    #define KYBER_K 3
#endif

#if KYBER_K == 2
    #define ETA1 3
#else
    #define ETA1 2
#endif

#define ETA2 2
#define N_WDR 16
#define NB_POLY 512
#define STACK_SIZE 20000


.section .text.start

main:
    /* MOD <= dmem[modulus] = KYBER_Q */
    la      x6, modulus_bn
    bn.lid  x0, 0(x6)
    bn.rshi w0, w31, w0 >> 240
    bn.wsrw 0x0, w0

    /* Load stack pointer */
    la x2, stack_end

    /* dmem[ra] <= masked_poly_getnoise_eta_1(dmem[xb], dmem[yb], nshares) */
    la  x10, seed
    la  x11, nonce
    jal x1, poly_getnoise_eta_init

    li  x10, ETA1
    la  x11, ra
    jal x1, masked_poly_getnoise_eta_1

    /* Compute r */
    la   x2, ra
    la   x3, reta_1
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

    /* Load stack pointer */
    la x2, stack_end

    /* dmem[ra] <= masked_poly_getnoise_eta_1(dmem[xb], dmem[yb], nshares) */
    la  x10, seed
    la  x11, nonce
    jal x1, poly_getnoise_eta_init

    li  x10, ETA2
    la  x11, ra
    jal x1, masked_poly_getnoise_eta_2

    /* Compute r */
    la   x2, ra
    la   x3, reta_2
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

reta_1:
    .zero 32 * N_WDR

reta_2:
    .zero 32 * N_WDR
