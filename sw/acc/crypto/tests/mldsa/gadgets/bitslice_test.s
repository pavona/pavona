/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.section .text.start

main:
    la  x2, stack_end
    bn.xor w31, w31, w31

    /* kbits = 23 */
    la  x10, r23
    la  x11, in23
    li  x12, 32
    jal x1, bitslice

    /* kbits = 32 */
    la  x10, r32
    la  x11, in32
    li  x12, 32
    jal x1, bitslice_k32

    ecall

.data
.balign 32
stack:
    .zero 2048
stack_end:
    .byte 0
