/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#define NSHARES 2

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

main:
    la  x2, stack_end
    bn.xor w31, w31, w31

    /* MOD = R | Q (low half = q) for bn.addvm/subvm. */
    li      x5, 2
    la      x6, modulus
    bn.lid  x5, 0(x6)
    li      x5, 3
    la      x6, montg_R
    bn.lid  x5, 0(x6)
    bn.rshi w2, w3, w2 >> 224
    bn.wsrw 0x0, w2

    /* k = 3 (eta = 2). */
    la  x10, out_k3
    la  x11, xb0_k3
    la  x12, xb1_k3
    li  x13, 3
    la  x14, seca2b_scratch
    la  x15, eta_buf
    jal x1, secb2amodq_eta

    la  x10, out_k3
    la  x11, r_k3
    li  x5, 0
    li  x6, 1
    loopi 32, 6
        bn.lid x5, 0(x10)
        addi   x4, x10, 1024
        bn.lid x6, 0(x4)
        bn.addvm.8s w0, w0, w1
        bn.sid x5, 0(x11++)
        addi   x10, x10, 32
    endloop

    /* k = 4 (eta = 4). */
    la  x10, out_k4
    la  x11, xb0_k4
    la  x12, xb1_k4
    li  x13, 4
    la  x14, seca2b_scratch
    la  x15, eta_buf
    jal x1, secb2amodq_eta

    la  x10, out_k4
    la  x11, r_k4
    li  x5, 0
    li  x6, 1
    loopi 32, 6
        bn.lid x5, 0(x10)
        addi   x4, x10, 1024
        bn.lid x6, 0(x4)
        bn.addvm.8s w0, w0, w1
        bn.sid x5, 0(x11++)
        addi   x10, x10, 32
    endloop

    ecall

.data
.balign 32
stack:
    .zero 8192
stack_end:

.balign 32
r_k3:
    .zero 1024
.balign 32
r_k4:
    .zero 1024

.balign 32
seca2b_scratch:
    .zero 1536

.balign 32
eta_buf:
    .zero 1536
