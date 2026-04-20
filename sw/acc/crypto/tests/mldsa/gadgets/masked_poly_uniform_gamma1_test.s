/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.section .text.start

main:
    la  x2, stack_end
    bn.xor w31, w31, w31

    /* MOD <= R | Q for bn.addvm.8S unmasking. */
    li      x5, 2
    la      x6, modulus
    bn.lid  x5, 0(x6)
    li      x5, 3
    la      x6, montg_R
    bn.lid  x5, 0(x6)
    bn.rshi w2, w3, w2 >> 224
    bn.wsrw 0x0, w2

    la   x6, nonce
    lw   x12, 0(x6)
    la   x10, y_shares
    la   x11, rho_shares
    la   x13, seca2b_scratch
    la   x14, gamma1_buf
    jal  x1, masked_poly_uniform_gamma_1

    /* r = y_shares[0] + y_shares[1] mod q (lane-wise). */
    la   x10, y_shares
    addi x11, x10, 1024
    la   x12, r
    li   x4, 1
    li   x5, 2
    LOOPI 32, 4
        bn.lid x4, 0(x10++)
        bn.lid x5, 0(x11++)
        bn.addvm.8S w1, w1, w2
        bn.sid x4, 0(x12++)

    ecall

.data
.balign 32
stack:
    .zero 8192
stack_end:

.balign 32
seca2b_scratch:
    .zero 1536

.balign 32
gamma1_buf:
    .zero 1536
