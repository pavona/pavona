/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/* This gadget is specific to ML-KEM. */

.section .text.start

/* This test does the following:
 *  (1) Compute rb = poly_compare(ca, c, dv, nshares)
 *  (2) Check dexp =? r where dexp = all-ones.
 *  (3) Compute rb = poly_compare(ca, c, du, nshares)
 *  (4) Check dexp =? r where dexp = all-ones. */
main:
    /* Load R | Q to MOD and w16. */
    la      x4, modulus_bn
    bn.lid  x0, 0(x4)
    bn.rshi w0, w31, w0 >> 240
    la      x4, modulus_inv
    addi    x5, x0, 1
    bn.lid  x5, 0(x4)
    bn.xor  w16, w0, w1 << 32
    bn.wsrw mod, w16

    /* Run poly_rej_samp. */
    la  x2, stack_end
    la  x11, rand
    la  x10, r_one
    jal x1, poly_rej_samp

    /* Run poly_rej_samp_19q. */
    la  x10, r_two
    la  x11, rand
    jal x1, poly_rej_samp_19q

    /* Test whether the results are all less than 19*Q. The final result is saved
     * to w31. */
    la        x10, modulus_times_19
    addi      x4, x0, 1
    bn.lid    x4, 0(x10)
    bn.shv.8s w1, w1 >> 16
    la        x10, r_two
    bn.xor    w31, w31, w31
    bn.xor    w4, w4, w4
    loopi 16, 9
        bn.lid      x0, 0(x10++)
        bn.trn1.16h w2, w0, w31
        bn.subv.8s  w2, w1, w2
        bn.shv.8s   w2, w2 >> 31
        bn.trn2.16h w3, w0, w31
        bn.subv.8s  w3, w1, w3
        bn.shv.8s   w3, w3 >> 31
        bn.trn1.16h w0, w2, w3
        bn.add      w4, w4, w0

    ecall

.data
.balign 32
stack:
    .zero 20000
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

r_one:
    .zero 512

r_two:
    .zero 512
