/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/* 1 KiB scratch in the bus-inaccessible DMEM scratchpad, used by the masking
 * gadgets. */
.section .scratchpad, "aw"
.balign 32
.globl scratch
scratch:
    .zero 1024
