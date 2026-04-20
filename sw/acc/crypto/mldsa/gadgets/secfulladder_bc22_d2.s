/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

.equ x0,  zero
.equ x4,  tp
.equ x5,  t0
.equ x6,  t1
.equ x7,  t2
.equ x10, a0
.equ x11, a1
.equ x12, a2
.equ x13, a3
.equ x14, a4
.equ x15, a5
.equ x16, a6
.equ x28, t3
.equ x29, t4
.equ x30, t5
.equ x31, t6

.equ w31, bn0

/*
 * Name: secfulladder_bc22 (PINI, d=2 only)
 *
 * Return Boolean shares of a value r = (x + y + c) mod 2^2, given Boolean
 * shares of x, y, and the incoming carry c.  Bitsliced.
 *
 * d=2 specialization of secfulladder_bc22.s: hand-unrolled, no stack frame,
 * intermediate `a` and `t` values kept in WDRs (no DMEM scratch).
 * secand_cs20_d2 is inlined.  Same ABI as the generic; nshares (a4) ignored.
 *
 * Source: Alg.5 [BC22]
 *
 * @param[in]    x10/a0: dptr_x
 * @param[in]    x11/a1: dptr_y
 * @param[in]    x12/a2: dptr_c
 * @param[in]    x13/a3: share stride
 * @param[in]    x14/a4: nshares (ignored, fixed to 2)
 * @param[inout] x15/a5: dptr_r0   (advanced by 32 on return)
 * @param[inout] x16/a6: dptr_r1   (preserved; written in place)
 *
 * Post-call (for secadd_bc22's bit-loop):
 *   a0 += 32, a1 += 32, a5 += 32 (advance to next bit slice).
 *   a2, a3, a4, a6 unchanged.
 *
 * clobbered registers: x4 to x7, x28 to x31, w0 to w10
 * clobbered flag groups: FG0
 */
.globl secfulladder_bc22
secfulladder_bc22:
    /* WDR index constants. */
    addi x4, x0, 1                 /* w1 = x[0]                            */
    addi t0, x0, 2                 /* w2 = x[1]                            */
    addi t1, x0, 3                 /* w3 = a[0] (= x[0]^y[0])              */
    addi t2, x0, 4                 /* w4 = a[1]                            */
    addi t3, x0, 5                 /* w5 = c[0] then t[0]                  */
    addi t4, x0, 6                 /* w6 = c[1] then t[1]                  */
    addi t6, x0, 0                 /* w0 = scratch (rand + write temp)     */

    /* --- Share 0: x[0] -> w1, a[0] -> w3, c[0] -> w5 ----------------- */
    bn.xor w1, w1, w1
    bn.xor w3, w3, w3
    bn.xor w5, w5, w5
    bn.lid x4, 0(a0)               /* w1 = x[0]                            */
    bn.lid t1, 0(a1)               /* w3 = y[0]                            */
    bn.xor w3, w1, w3              /* w3 = a[0] = x[0] ^ y[0]              */
    bn.lid t3, 0(a2)               /* w5 = c[0]                            */

    /* --- Share 1: x[1] -> w2, a[1] -> w4, c[1] -> w6 ----------------- */
    bn.xor w2, w2, w2
    bn.xor w4, w4, w4
    bn.xor w6, w6, w6
    add    t5, a0, a3
    bn.lid t0, 0(t5)               /* w2 = x[1]                            */
    add    t5, a1, a3
    bn.lid t2, 0(t5)               /* w4 = y[1]                            */
    bn.xor w4, w2, w4              /* w4 = a[1] = x[1] ^ y[1]              */
    addi   t5, a2, 32              /* c shares are at stride 32 (caller's  */
    bn.lid t4, 0(t5)               /* w6 = c[1]   stack-scratch layout)    */

    /* --- r[0] = c ^ a -> dmem[a5..a5+a3] ------------------------------ */
    bn.xor w0, w0, w0              /* whiten w0 (residual from caller)     */
    bn.xor w0, w5, w3              /* w0 = r[0][0] = c[0] ^ a[0]           */
    bn.sid t6, 0(a5)
    bn.xor w0, w0, w0              /* whiten w0 between share writes       */
    bn.xor w0, w6, w4              /* w0 = r[0][1]                         */
    add    t5, a5, a3
    bn.sid t6, 0(t5)

    /* --- t = x ^ c (overwrites c slots w5, w6) ----------------------- */
    bn.xor w5, w1, w5              /* w5 = t[0] = x[0] ^ c[0]              */
    bn.xor w6, w2, w6              /* w6 = t[1] = x[1] ^ c[1]              */

    /* --- Inlined secand_cs20_d2: tb = a & t (PINI, d=2) -------------- */
    bn.xor w7, w7, w7
    bn.and w7, w3, w5              /* tb[0] = a[0] & t[0]                  */
    bn.xor w8, w8, w8
    bn.and w8, w4, w6              /* tb[1] = a[1] & t[1]                  */

    bn.wsrr w0, urnd               /* w0 = r (fresh randomness)            */

    /* PINI pair (i, j) = (0, 1). */
    bn.xor w9,  w6, w0             /* wtmp1 = t[1] ^ r                     */
    bn.and w9,  w9, w3             /* wtmp1 &= a[0]                        */
    bn.not w10, w3                 /* wtmp0 = ~a[0]                        */
    bn.and w10, w10, w0            /* wtmp0 &= r                           */
    bn.xor w10, w10, w9            /* wtmp0 ^= wtmp1                       */
    bn.xor w7,  w7, w10            /* tb[0] ^= wtmp0                       */

    /* PINI pair (i, j) = (1, 0). */
    bn.xor w9,  w5, w0             /* wtmp1 = t[0] ^ r                     */
    bn.and w9,  w9, w4             /* wtmp1 &= a[1]                        */
    bn.not w10, w4                 /* wtmp0 = ~a[1]                        */
    bn.and w10, w10, w0            /* wtmp0 &= r                           */
    bn.xor w10, w10, w9            /* wtmp0 ^= wtmp1                       */
    bn.xor w8,  w8, w10            /* tb[1] ^= wtmp0                       */

    /* tb[0..1] now holds the secand output (= new t[0..1]).             */

    /* --- r[1] = x ^ t -> dmem[a6..a6+a3] ------------------------------ */
    bn.xor w0, w0, w0              /* whiten w0 (post-PINI residual)       */
    bn.xor w0, w1, w7              /* w0 = r[1][0] = x[0] ^ t[0]           */
    bn.sid t6, 0(a6)
    bn.xor w0, w0, w0              /* whiten w0 between share writes       */
    bn.xor w0, w2, w8              /* w0 = r[1][1]                         */
    addi   t5, a6, 32              /* r[1] (= output carry) is at stride 32 */
    bn.sid t6, 0(t5)

    /* --- Advance per the secadd_bc22 bit loop's expectations --------- */
    addi a0, a0, 32
    addi a1, a1, 32
    addi a5, a5, 32
    /* a2, a3, a4, a6 preserved. */

    ret
