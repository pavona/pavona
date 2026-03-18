/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

/* Register aliases */
.equ x0, zero
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

/*
 * Name: bitcopymask_bc22_mlkem (PINI)
 *
 * Return k-bit Boolean shares of q * x, given 1-bit Boolean shares of x for
 * q = 3329 and the bitsize k = 12 (since q < 2**k).
 * Bitsliced.
 *
 * Source: Alg.1 in [BC22]
 *         [BC22]: "Bitslicing Arithmetic/Boolean Masking Conversions for Fun and Profit: with Application to Lattice-Based KEMs"
 *         Link: https://tches.iacr.org/index.php/TCHES/article/view/9831
 *
 * @param[in]  x10: dptr_xb, dmem pointer to the input Boolean shares of x
 * @param[in]  x11: share stride, distance between shares of x
 * @param[in]  x12: nshares, the number of shares
 * @param[out] x13: dptr_rb, dmem pointer to the output Boolean shares of r
 *
 * clobbered registers: x4, x10, x13, w0, w31
 * clobbered flag groups: FG0
 */
.globl bitcopymask_bc22_mlkem
bitcopymask_bc22_mlkem:
    /* Since q = 3329 = b110100000001, we copy x to the 1st, 9th, 11th and 12th
     * bit of r and zeroize the rest of r. */
    /* All-zero register. */
    bn.xor bn0, bn0, bn0
    addi   x4, x0, 31
    loop a2, 10
        /* Whitening. */
        bn.xor w0, w0, w0
        bn.lid x0, 0(a0)
        add    a0, a0, a1
        /* Copy x to bit 0. */
        bn.sid x0, 0(a3++)
        /* Clear bit 1 -- 7. */
        loopi 7, 1
            bn.sid x4, 0(a3++)
        /* Copy x to bit 8. */
        bn.sid x0, 0(a3++)
        /* Clear bit 9. */
        bn.sid x4, 0(a3++)
        /* Copy x to bit 10 -- 11. */
        bn.sid x0, 0(a3++)
        bn.sid x0, 0(a3++)
    ret
