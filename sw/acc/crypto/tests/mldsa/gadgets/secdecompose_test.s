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
    bn.wsrr w16, 0x0

#if DILITHIUM_MODE == 2

    la  x10, w1_out
    la  x11, w_in
    li  x12, NSHARES
    la  x13, seccompress_scratch
    li  x14, 1024
    la  x15, seccompress_b
    la  x16, t_packed
    jal x1, secdecompose

    /* w0_unmasked[i] = w_in_s0[i] + w_in_s1[i] mod q.  secdecompose left
     * arithmetic w0 in place: share 0 = w_s0 - alpha*w1, share 1 = w_s1. */
    la   x10, w_in
    addi x11, x10, 1024
    la   x12, w0_unmasked
    li   x4, 1
    li   x5, 2
    LOOPI 32, 4
        bn.lid x4, 0(x10++)
        bn.lid x5, 0(x11++)
        bn.addvm.8S w1, w1, w2
        bn.sid x4, 0(x12++)

    ecall

#else

    la  x10, w1_out
    la  x11, w_in
    la  x13, secdecompose_scratch
    li  x14, 1024
    la  x15, w0_packed_share0
    la  x16, w0_packed_share1
    la  x17, seca2b_scratch
    jal x1, secdecompose

    /* Zero-pad 19-stripe packed shares to 24-stripe Boolean for b2a. */
    li   x7, 0
    li   x28, 31
    la   x5, b2a_in
    la   x6, w0_packed_share0
    loopi 19, 2
        bn.lid x7, 0(x6++)
        bn.sid x7, 0(x5++)
    loopi 5, 1
        bn.sid x28, 0(x5++)
    bn.xor w0, w0, w0
    la   x6, w0_packed_share1
    loopi 19, 2
        bn.lid x7, 0(x6++)
        bn.sid x7, 0(x5++)
    loopi 5, 1
        bn.sid x28, 0(x5++)

    /* b2a -> bitsliced arithmetic shares of U; unbitslice each share. */
    la  x10, b2a_out
    la  x11, b2a_in
    la  x13, seca2b_scratch
    jal x1, secb2amodq_bc22

    la   x10, u_share0
    la   x11, b2a_out
    jal  x1, unbitslice

    la   x10, u_share1
    la   x11, b2a_out
    addi x11, x11, 768
    jal  x1, unbitslice

    /* u_unmasked[i] = u_share0[i] + u_share1[i] mod q. */
    la   x10, u_share0
    la   x11, u_share1
    la   x12, u_unmasked
    li   x4, 1
    li   x5, 2
    LOOPI 32, 4
        bn.lid x4, 0(x10++)
        bn.lid x5, 0(x11++)
        bn.addvm.8S w1, w1, w2
        bn.sid x4, 0(x12++)

    ecall

#endif

.data
.balign 32
stack:

#if DILITHIUM_MODE == 2

    .zero 2048
stack_end:
    .byte 0

.balign 32
t_packed:
    .zero 2048

.balign 32
seccompress_scratch:
    .zero 4096

.balign 32
seccompress_b:
    .zero 2048

.balign 32
.globl w0_unmasked
w0_unmasked:
    .zero 1024

#else

    .zero 8192
stack_end:

.balign 32
secdecompose_scratch:
    .zero 3296

.balign 32
w0_packed_share0:
    .zero 608
.balign 32
w0_packed_share1:
    .zero 608

.balign 32
b2a_in:
    .zero NSHARES * 768

.balign 32
b2a_out:
    .zero NSHARES * 768

.balign 32
u_share0:
    .zero 1024

.balign 32
u_share1:
    .zero 1024

.balign 32
.globl u_unmasked
u_unmasked:
    .zero 1024

.balign 32
seca2b_scratch:
    .zero 1536

#endif
