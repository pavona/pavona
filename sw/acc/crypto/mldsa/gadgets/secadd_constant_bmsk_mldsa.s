/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

.equ x1,  ra
.equ x2,  sp
.equ x5,  t0
.equ x6,  t1
.equ x7,  t2
.equ x10, a0
.equ x11, a1
.equ x12, a2
.equ x13, a3
.equ x14, a4
.equ x28, t3
.equ x29, t4
.equ x30, t5
.equ x31, t6

.equ w31, bn0

#define MLDSA_KBITS       23
#define SHARE_STR_BYTES   768    /* (k+1) * 32 */

/*
 * Name: secadd_constant_bmsk_mldsa (PINI)
 *
 * Fused steps 5+6 of [BC22] Alg.7 specialised for ML-DSA q at d = 2:
 *   z <- sp + BitCopyMask(sp[k], q)        (in-place over dptr_z)
 *
 * Per-bit unrolled per q = 0x7FE001 run structure (bit 0 + bits 1..12 +
 * bits 13..22).  Bit k of z is zeroed.
 *
 * @param[in]   x10: dptr_z, in/out ((k+1) * 2 * 32 bytes, bit k = 0 on exit).
 * @param[in]   w31: all-zero.
 *
 * clobbered registers: x5 to x7, x10 to x14, x28 to x31, w0 to w23
 * clobbered flag groups: FG0
 */

/* WDR layout: w20/w21 = b[0]/b[1]; w22/w23 = carry[0]/[1]. */

.macro BMSK_BIT_C0
    bn.lid  t0, 0(a0)
    bn.lid  t1, 0(a1)
    bn.xor  w8, w22, w4            /* z = c ^ sp */
    bn.xor  w9, w23, w5
    bn.sid  t2, 0(a0++)
    bn.sid  t3, 0(a1++)
    /* c' = SecAnd(c, sp). */
    bn.and  w12, w22, w4
    bn.and  w13, w23, w5
    bn.wsrr w14, urnd
    bn.and  w15, w22, w5
    bn.xor  w15, w15, w14
    bn.and  w16, w23, w4
    bn.xor  w16, w16, w14
    bn.xor  w22, w12, w15
    bn.xor  w23, w13, w16
.endm

.macro BMSK_BIT_C1
    bn.lid  t0, 0(a0)
    bn.lid  t1, 0(a1)
    bn.xor  w6, w4, w20            /* xpy = sp ^ b */
    bn.xor  w7, w5, w21
    bn.xor  w8, w22, w6            /* z = c ^ xpy */
    bn.xor  w9, w23, w7
    bn.sid  t2, 0(a0++)
    bn.sid  t3, 0(a1++)
    bn.xor  w10, w4, w22           /* xpc = sp ^ c */
    bn.xor  w11, w5, w23
    /* c' = sp ^ SecAnd(xpy, xpc). */
    bn.and  w12, w6, w10
    bn.and  w13, w7, w11
    bn.wsrr w14, urnd
    bn.and  w15, w6, w11
    bn.xor  w15, w15, w14
    bn.and  w16, w7, w10
    bn.xor  w16, w16, w14
    bn.xor  w12, w12, w15
    bn.xor  w13, w13, w16
    bn.xor  w22, w4, w12
    bn.xor  w23, w5, w13
.endm

.globl secadd_constant_bmsk_mldsa
secadd_constant_bmsk_mldsa:
    /* WDR id registers. */
    li   t0, 4
    li   t1, 5
    li   t2, 8
    li   t3, 9
    li   t4, 20
    li   t5, 21
    li   t6, 31

    addi a1, a0, SHARE_STR_BYTES

    /* Load b = sp[k]; zero carry. */
    li   a2, MLDSA_KBITS
    slli a2, a2, 5
    add  a3, a0, a2
    add  a4, a1, a2
    bn.lid t4, 0(a3)
    bn.lid t5, 0(a4)
    bn.xor w22, w22, w22
    bn.xor w23, w23, w23

    /* bit 0 (q=1) */
    BMSK_BIT_C1
    /* bits 1..12 (q=0) */
    loopi 12, 15
        BMSK_BIT_C0
    /* bits 13..22 (q=1) */
    loopi 10, 21
        BMSK_BIT_C1

    /* Zero z[k]. */
    bn.sid t6, 0(a3)
    bn.sid t6, 0(a4)

    ret
