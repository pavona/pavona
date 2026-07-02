/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.section .text.start

main:
    la  x2, stack_end
    bn.xor w31, w31, w31

    /* MOD <= R | Q for bn.subvm.8s unmasking. */
    li      x5, 2
    la      x6, modulus
    bn.lid  x5, 0(x6)
    li      x5, 3
    la      x6, montg_R
    bn.lid  x5, 0(x6)
    bn.rshi w2, w3, w2 >> 224
    bn.wsrw 0x0, w2

    /* ===== eta = 2 ===== */
    la   x6, nonce_e2
    lw   x12, 0(x6)
    la   x10, s_e2
    la   x11, rho_e2
    la   x13, mpue_arena
    la   x14, mpue_b2a_buf
    li   x15, 2
    jal  x1, masked_poly_uniform_eta

    la   x10, s_e2
    addi x11, x10, 1024
    la   x12, r_e2
    li   x4, 1
    li   x5, 2
    loopi 32, 4
        bn.lid x4, 0(x10++)
        bn.lid x5, 0(x11++)
        bn.addvm.8s w1, w1, w2
        bn.sid x4, 0(x12++)

    /* ===== eta = 4 ===== */
    la   x6, nonce_e4
    lw   x12, 0(x6)
    la   x10, s_e4
    la   x11, rho_e4
    la   x13, mpue_arena
    la   x14, mpue_b2a_buf
    li   x15, 4
    jal  x1, masked_poly_uniform_eta

    la   x10, s_e4
    addi x11, x10, 1024
    la   x12, r_e4
    li   x4, 1
    li   x5, 2
    loopi 32, 4
        bn.lid x4, 0(x10++)
        bn.lid x5, 0(x11++)
        bn.addvm.8s w1, w1, w2
        bn.sid x4, 0(x12++)

    ecall

.data
.balign 32
stack:
    .zero 4096
stack_end:

.balign 32
.globl r_e2
r_e2:
    .zero 1024
.balign 32
.globl r_e4
r_e4:
    .zero 1024

.balign 32
mpue_arena:
    .zero 3104
.balign 32
mpue_b2a_buf:
    .zero 1536
