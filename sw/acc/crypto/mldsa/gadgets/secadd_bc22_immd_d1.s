/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

.equ x0, zero
.equ x1, ra
.equ x2, sp
.equ x5, t0
.equ x6, t1
.equ x7, t2
.equ x10, a0
.equ x11, a1
.equ x12, a2
.equ x13, a3
.equ x16, a6
.equ x28, t3
.equ x29, t4
.equ x30, t5
.equ x31, t6

.equ w31, bn0

/*
 * Name: secadd_bc22_immd_d1
 *
 * Bitsliced SecAdd for d = 1 with y hard-coded to nq = 0x801FFF.  No
 * DMEM scratch for y: nq is built into w7 lane 0 at function entry,
 * then rotated 1 bit per iteration; per stripe the LSB of w7 is
 * broadcast to 8 lanes via bn.cmp + bn.sel.
 *
 * @param[in]   x10: dptr_x, kbits * 32 B
 * @param[in]   x12: kbits
 * @param[in]   x13: kbits_out (kbits or kbits+1)
 * @param[out]  x16: dptr_z, kbits_out * 32 B
 * @param[in]   w31: all-zero
 *
 * clobbered registers: x5 to x7, x28 to x31, w0 to w8
 * clobbered flag groups: FG0
 */
.globl secadd_bc22_immd_d1
secadd_bc22_immd_d1:
    li   t0, 0
    li   t1, 1
    li   t2, 2
    li   t4, 4

    bn.not w6, w31                /* w6 = all-ones */

    /* Build nq = 0x801FFF in w7 lane 0 (= 2^23 + 2^13 - 1). */
    bn.xor w7, w7, w7
    bn.addi w7, w7, 1
    bn.shv.8S w7, w7 << 23        /* lane 0 = 0x800000 */
    bn.xor w8, w8, w8
    bn.addi w8, w8, 1
    bn.shv.8S w8, w8 << 13        /* w8 lane 0 = 0x2000 */
    bn.subi w8, w8, 1             /* w8 lane 0 = 0x1FFF */
    bn.add w7, w7, w8             /* w7 lane 0 = 0x801FFF */

    bn.xor w8, w8, w8
    bn.addi w8, w8, 1             /* w8 = 1 (lane 0 bit 0) */

    /* Bit 0. */
    bn.xor w0, w0, w0
    bn.xor w1, w1, w1
    bn.xor w2, w2, w2
    bn.xor w3, w3, w3
    bn.lid t1, 0(a0++)
    bn.and w3, w7, w8
    bn.cmp w3, w31
    bn.sel w2, w31, w6, FG0.Z
    bn.rshi w7, w31, w7 >> 1
    bn.xor w4, w1, w2
    bn.sid t4, 0(a6++)
    bn.and w0, w1, w2

    /* Bits 1..kbits-1. */
    addi t6, a2, -1
    loop t6, 11
        bn.lid t1, 0(a0++)
        bn.and w3, w7, w8
        bn.cmp w3, w31
        bn.sel w2, w31, w6, FG0.Z
        bn.rshi w7, w31, w7 >> 1
        bn.xor w3, w1, w2
        bn.xor w4, w3, w0
        bn.sid t4, 0(a6++)
        bn.and w5, w1, w2
        bn.and w0, w0, w3
        bn.xor w0, w0, w5

    /* kbits_out == kbits: drop final carry. */
    beq  a3, a2, _secadd_bc22_immd_d1_done

    /* kbits_out == kbits + 1: z[kbits] = carry ^ y[kbits]. */
    bn.and w3, w7, w8
    bn.cmp w3, w31
    bn.sel w2, w31, w6, FG0.Z
    bn.xor w4, w0, w2
    bn.sid t4, 0(a6)

_secadd_bc22_immd_d1_done:
    ret
