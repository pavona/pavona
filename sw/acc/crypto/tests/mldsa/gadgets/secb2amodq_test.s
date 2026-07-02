/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#define NSHARES 2
#define Q_KBITS 23
#define SHARE_STR 768

.equ x5, t0
.equ x6, t1
.equ x7, t2
.equ x10, a0
.equ x11, a1
.equ x12, a2
.equ x13, a3
.equ x28, t3
.equ x29, t4

.section .text.start

/* Round-trip: za = secb2amodq(xb); zb2 = seca2bmodq(za); reconstruct.
 * Layouts: share-major bit-inner, share_str = (k+1)*32 = 768. */
main:
    la  x2, stack_end
    bn.xor w31, w31, w31

    la  x10, za
    la  x11, xb
    la  x13, seca2b_scratch
    jal x1, secb2amodq

    la  x10, zb2
    la  x11, za
    la  x13, seca2b_scratch
    jal x1, seca2bmodq

    /* XOR-unmask zb2 into r. */
    la   x10, zb2
    la   x11, r
    li   x12, SHARE_STR
    li   x13, Q_KBITS
    li   x29, NSHARES
    addi x29, x29, -1
    li   x4, 1
    li   x5, 0
    loop x13, 9
        addi x28, x10, 0
        bn.lid x5, 0(x28)
        loop x29, 3
            add    x28, x28, x12
            bn.lid x4, 0(x28)
            bn.xor w0, w0, w1
        endloop
        bn.sid x5, 0(x11)
        addi x10, x10, 32
        addi x11, x11, 32
    endloop

    ecall

.data
.balign 32
stack:
    .zero 8192
stack_end:
r:
    .zero Q_KBITS * 32

.balign 32
seca2b_scratch:
    .zero 1536
