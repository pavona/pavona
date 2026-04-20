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
 * Name: secadd_bc22 (PINI)
 *
 * Return Boolean shares of a value r = (x + y) mod 2^k, given Boolean shares of
 * x and y mod 2^k.
 * Bitsliced.
 *
 * Source: Alg.6 [BC22]
 *         [BC22]: "Bitslicing Arithmetic/Boolean Masking Conversions for Fun and Profit: with Application to Lattice-Based KEMs"
 *         Link: https://tches.iacr.org/index.php/TCHES/article/view/9831
 *
 * @param[in]  x10: dptr_x, dmem pointer to Boolean shares of x
 * @param[in]  x11: dptr_y, dmem pointer to Boolean shares of y
 * @param[in]  x12: k, bitsize of x and y.
 * @param[in]  x13: share stride, distance between shares
 * @param[in]  x14: nshares, the number of shares
 * @param[out] x15: dptr_r, dmem pointer to the output Boolean shares of r
 *
 * clobbered registers: x2 to x13, x15 to x16, x18 to x22, x28 to x31, w0 to w10
 * clobbered flag groups: FG0
 */
.globl secadd_bc22
secadd_bc22:
    /* Save fp to stack */
    addi sp, sp, -32
    sw   fp, 0(sp)
    addi fp, sp, 0

    /* Save registers. */
    sw s0, 4(fp)

    /* Adjust stack for temporary variable c. */
    loop a4, 1
        addi sp, sp, -32 /* ptr_c */

    /* Initialize c = 0. */
    bn.xor w0, w0, w0
    addi   t0, sp, 0 /* ptr_c */
    loop a4, 1
        bn.sid x0, 0(t0++)

    /* Ripple-carry adder. */
    addi s0, a2, -1
    /* Loop over i = 0, ..., k-2. */
    loop s0, 4
        /* a0 already points to x[i] */
        /* a1 already points to y[i] */
        addi a2, sp, 0 /* ptr_c */
        /* a3 is already share stride. */
        /* a4 is already nshares. */
        /* a5 already points to r. */
        addi a6, sp, 0 /* ptr_c */
        jal  x1, secfulladder_bc22
        /* After secfulladder_bc22:
         *  - a0 and a1 points to x[i + 1] and y[i + 1].
         *  - a3 is still share stride.
         *  - a4 is still nshares.
         *  - a5 points to r[i + 1].
         *  - a6 points to c. */
        nop

    /* Handle top bit i = k-1. */
    /* Compute r[k-1] = x[k-1] ^ y[k-1] ^ c. */
    addi t0, sp, 0 /* ptr_c */
    addi x4, x0, 1
    addi t1, x0, 2
    addi t2, x0, 3
    loop a4, 13
        /* Whitening. */
        bn.xor w0, w0, w0
        bn.xor w1, w1, w1
        bn.xor w2, w2, w2
        bn.xor w3, w3, w3
        /* Computation. */
        bn.lid x0, 0(a0)
        bn.lid x4, 0(a1)
        bn.lid t1, 0(t0++)
        bn.xor w3, w0, w1
        bn.xor w3, w3, w2
        bn.sid t2, 0(a5)
        /* Adjust addresses. */
        add    a0, a0, a3
        add    a1, a1, a3
        add    a5, a5, a3

    /* Restore registers. */
    lw s0, 4(fp)

    /* Restore sp and fp. */
    addi sp, fp, 0
    lw   fp, 0(sp)
    addi sp, sp, 32
    ret
