/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#define BITSIZE 12
#define NB_POLY 512

.section .text.start

main:
    /* dmem[rbs] <= poly_to_bs(dmem[xa], nshares). */
    la  x10, xa
    la  x11, rbs
    jal x1, poly_to_bs_12

    /* dmem[rn] <= poly_from_bs(dmem[rbs], nshares). */
    la  x10, rbs
    la  x11, rn
    jal x1, poly_from_bs_12

    ecall

.data
.balign 32
rbs:
    .zero 32 * 12
rn:
    .zero NB_POLY
