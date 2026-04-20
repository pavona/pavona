/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#ifndef NSHARES
    #define NSHARES 2
#endif

.section .text.start

main:
    la  x2, stack_end
    bn.xor w31, w31, w31

    /* MOD <= R | Q for bn.subvm.8S / bn.addvm.8S inside the gadget. */
    li      x5, 2
    la      x6, modulus
    bn.lid  x5, 0(x6)
    li      x5, 3
    la      x6, montg_R
    bn.lid  x5, 0(x6)
    bn.rshi w2, w3, w2 >> 224
    bn.wsrw 0x0, w2

    /* Load C into w17 lane 0. */
    li  x5, 17
    la  x6, c_wdr
    bn.lid x5, 0(x6)

    la  x10, x_arith
    la  x12, lambda0_vec
    la  x13, seca2b_scratch
    la  x14, secboundcheck_buf
    jal x1, secboundcheck

    /* Write w0 (per-lane b) to y_out for dexp check. */
    la  x10, y_out
    li  x11, 0
    bn.sid x11, 0(x10)

    ecall

.data
.balign 32
stack:
    .zero 8192
stack_end:

.balign 32
.globl y_out
y_out:
    .zero 32

.balign 32
seca2b_scratch:
    .zero 1536

.balign 32
secboundcheck_buf:
    .zero 1536
