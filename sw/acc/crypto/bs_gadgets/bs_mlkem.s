/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

#define N_WDR 16

/* Register aliases */
.equ x2, sp
.equ x3, fp
.equ x5, t0
.equ x6, t1
.equ x7, t2
.equ x8, s0
.equ x9, s1
.equ x10, a0
.equ x11, a1
.equ x12, a2
.equ x13, a3
.equ x14, a4
.equ x15, a5
.equ x16, a6
.equ x17, a7
.equ x18, s2
.equ x19, s3
.equ x20, s4
.equ x21, s5
.equ x22, s6
.equ x23, s7
.equ x24, s8
.equ x25, s9
.equ x26, s10
.equ x27, s11
.equ x28, t3
.equ x29, t4
.equ x30, t5
.equ x31, t6

.equ w31, bn0

#define wb0 w2
#define wb1 w3
#define wb2 w4
#define wb3 w5
#define wb4 w6
#define wb5 w7
#define wb6 w8
#define wb7 w9
#define wb8 w10
#define wb9 w11
#define wb10 w12
#define wb11 w13
#define wtmp w14
#define wmask w15

/*
 * Name: poly_to_bs_12
 *
 * Return bitsliced representation of a value x in [0, KYBER_Q).
 * Vectorized for polynomial.
 *
 * @param[in]  x10: dptr_x, dmem pointer to the input masked value
 * @param[out] x11: dptr_r, dmem pointer to the output bitslice representation
 *
 * clobbered registers: x4, x10, w0, w2 to w15
 * clobbered flag groups: FG0
 */
.globl poly_to_bs_12
poly_to_bs_12:

    /* Create mask. */
    bn.xor     wmask, wmask, wmask
    bn.subi    wmask, bn0, 1
    bn.shv.16h wmask, wmask >> 15

    loopi N_WDR, 48
        bn.lid     x0, 0(a0++)
        bn.and     wtmp, w0, wmask
        bn.shv.16h wb0, wb0 << 1
        bn.xor     wb0, wb0, wtmp
        bn.shv.16h w0, w0 >> 1
        bn.and     wtmp, w0, wmask
        bn.shv.16h wb1, wb1 << 1
        bn.xor     wb1, wb1, wtmp
        bn.shv.16h w0, w0 >> 1
        bn.and     wtmp, w0, wmask
        bn.shv.16h wb2, wb2 << 1
        bn.xor     wb2, wb2, wtmp
        bn.shv.16h w0, w0 >> 1
        bn.and     wtmp, w0, wmask
        bn.shv.16h wb3, wb3 << 1
        bn.xor     wb3, wb3, wtmp
        bn.shv.16h w0, w0 >> 1
        bn.and     wtmp, w0, wmask
        bn.shv.16h wb4, wb4 << 1
        bn.xor     wb4, wb4, wtmp
        bn.shv.16h w0, w0 >> 1
        bn.and     wtmp, w0, wmask
        bn.shv.16h wb5, wb5 << 1
        bn.xor     wb5, wb5, wtmp
        bn.shv.16h w0, w0 >> 1
        bn.and     wtmp, w0, wmask
        bn.shv.16h wb6, wb6 << 1
        bn.xor     wb6, wb6, wtmp
        bn.shv.16h w0, w0 >> 1
        bn.and     wtmp, w0, wmask
        bn.shv.16h wb7, wb7 << 1
        bn.xor     wb7, wb7, wtmp
        bn.shv.16h w0, w0 >> 1
        bn.and     wtmp, w0, wmask
        bn.shv.16h wb8, wb8 << 1
        bn.xor     wb8, wb8, wtmp
        bn.shv.16h w0, w0 >> 1
        bn.and     wtmp, w0, wmask
        bn.shv.16h wb9, wb9 << 1
        bn.xor     wb9, wb9, wtmp
        bn.shv.16h w0, w0 >> 1
        bn.and     wtmp, w0, wmask
        bn.shv.16h wb10, wb10 << 1
        bn.xor     wb10, wb10, wtmp
        bn.shv.16h w0, w0 >> 1
        bn.and     wtmp, w0, wmask
        bn.shv.16h wb11, wb11 << 1
        bn.xor     wb11, wb11, wtmp
    addi   x4, x0, 2
    bn.sid x4++, 0(a1)
    bn.sid x4++, 32(a1)
    bn.sid x4++, 64(a1)
    bn.sid x4++, 96(a1)
    bn.sid x4++, 128(a1)
    bn.sid x4++, 160(a1)
    bn.sid x4++, 192(a1)
    bn.sid x4++, 224(a1)
    bn.sid x4++, 256(a1)
    bn.sid x4++, 288(a1)
    bn.sid x4++, 320(a1)
    bn.sid x4++, 352(a1)
    ret


/*
 * Name: poly_from_bs_16
 *
 * Return normal representation of a bitsliced value x in [0, KYBER_Q).
 * Vectorized for polynomial.
 *
 * @param[in]  x10: dptr_x, dmem pointer to the input bitsliced representation
 * @param[out] x11: dptr_r, dmem pointer to the output masked value
 *
 * clobbered registers: x4, x11, w0, w2 to w14
 * clobbered flag groups: FG0
 */
.globl poly_from_bs_12
poly_from_bs_12:
    /* Load data w0 -- w11. */
    addi   x4, x0, 2
    bn.lid x4++, 0(a0)
    bn.lid x4++, 32(a0)
    bn.lid x4++, 64(a0)
    bn.lid x4++, 96(a0)
    bn.lid x4++, 128(a0)
    bn.lid x4++, 160(a0)
    bn.lid x4++, 192(a0)
    bn.lid x4++, 224(a0)
    bn.lid x4++, 256(a0)
    bn.lid x4++, 288(a0)
    bn.lid x4++, 320(a0)
    bn.lid x4++, 352(a0)

    /* Bitslicing to wr. */
    loopi N_WDR, 47
        bn.shv.16h w0, wb0 >> 15
        bn.shv.16h wb0, wb0 << 1
        bn.shv.16h wtmp, wb1 >> 15
        bn.shv.16h wb1, wb1 << 1
        bn.shv.16h wtmp, wtmp << 1
        bn.xor     w0, w0, wtmp
        bn.shv.16h wtmp, wb2 >> 15
        bn.shv.16h wb2, wb2 << 1
        bn.shv.16h wtmp, wtmp << 2
        bn.xor     w0, w0, wtmp
        bn.shv.16h wtmp, wb3 >> 15
        bn.shv.16h wb3, wb3 << 1
        bn.shv.16h wtmp, wtmp << 3
        bn.xor     w0, w0, wtmp
        bn.shv.16h wtmp, wb4 >> 15
        bn.shv.16h wb4, wb4 << 1
        bn.shv.16h wtmp, wtmp << 4
        bn.xor     w0, w0, wtmp
        bn.shv.16h wtmp, wb5 >> 15
        bn.shv.16h wb5, wb5 << 1
        bn.shv.16h wtmp, wtmp << 5
        bn.xor     w0, w0, wtmp
        bn.shv.16h wtmp, wb6 >> 15
        bn.shv.16h wb6, wb6 << 1
        bn.shv.16h wtmp, wtmp << 6
        bn.xor     w0, w0, wtmp
        bn.shv.16h wtmp, wb7 >> 15
        bn.shv.16h wb7, wb7 << 1
        bn.shv.16h wtmp, wtmp << 7
        bn.xor     w0, w0, wtmp
        bn.shv.16h wtmp, wb8 >> 15
        bn.shv.16h wb8, wb8 << 1
        bn.shv.16h wtmp, wtmp << 8
        bn.xor     w0, w0, wtmp
        bn.shv.16h wtmp, wb9 >> 15
        bn.shv.16h wb9, wb9 << 1
        bn.shv.16h wtmp, wtmp << 9
        bn.xor     w0, w0, wtmp
        bn.shv.16h wtmp, wb10 >> 15
        bn.shv.16h wb10, wb10 << 1
        bn.shv.16h wtmp, wtmp << 10
        bn.xor     w0, w0, wtmp
        bn.shv.16h wtmp, wb11 >> 15
        bn.shv.16h wb11, wb11 << 1
        bn.shv.16h wtmp, wtmp << 11
        bn.xor     w0, w0, wtmp
        bn.sid     x0, 0(a1++)
    ret
