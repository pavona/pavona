/* Copyright Ruben Niederhagen and Hoang Nguyen Hien Pham. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/* Test direct load instruction. */

.section .text.start

main:
    la     x2, op
    bn.ld  w1, 0(x2++) /* bn.ld with address increment. */
    bn.ld  w2, 0(x2) /* bn.ld without address increment. */

    bn.add w0, w1, w2
    bn.add w1, w0, w2

    la     x2, r
    bn.sd  w0, 0(x2++) /* bn.sd with address increment. */
    bn.sd  w1, 0(x2) /* bn.sd without address increment. */
    nop
    ecall

.data
.balign 32
op:
    .quad 0x0000000000000001
    .quad 0x0000000000000000
    .quad 0x0000000000000000
    .quad 0x0000000000000000

    .quad 0x0000000000000003
    .quad 0x0000000000000000
    .quad 0x0000000000000000
    .quad 0x0000000000000000

r:
    .zero 32
