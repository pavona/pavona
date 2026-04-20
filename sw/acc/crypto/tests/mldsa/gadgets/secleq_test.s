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

    /* Load C into w17 lane 0. */
    li  x5, 17
    la  x6, c_wdr
    bn.lid x5, 0(x6)

    la  x11, x_in
    jal x1, secleq

    /* Write w0 (per-lane b) to y_out for dexp check. */
    la  x10, y_out
    li  x11, 0
    bn.sid x11, 0(x10)

    ecall

.data
.balign 32
stack:
    .zero 4096
stack_end:

.balign 32
.globl y_out
y_out:
    .zero 32
