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
 * Name: secfulladder_bc22 (PINI)
 *
 * Return Boolean shares of a value r = (x + y + c) mod 2^2, given Boolean
 * shares of x and y mod 2.
 * Bitsliced.
 *
 * Source: Alg.5 [BC22]
 *         [BC22]: "Bitslicing Arithmetic/Boolean Masking Conversions for Fun and Profit: with Application to Lattice-Based KEMs"
 *         Link: https://tches.iacr.org/index.php/TCHES/article/view/9831
 *
 * @param[in]  x10: dptr_x, dmem pointer to Boolean shares of x
 * @param[in]  x11: dptr_y, dmem pointer to Boolean shares of y
 * @param[in]  x12: dptr_c, dmem pointer to Boolean shares of the carry c
 * @param[in]  x13: share stride, distance between shares
 * @param[in]  x14: nshares, the number of shares
 * @param[out] x15: dptr_r, dmem pointer to the output Boolean shares of r[0]
 * @param[out] x16: dptr_r, dmem pointer to the output Boolean shares of r[1]
 *
 * clobbered registers: x2 to x13, x15 to x16, x18 to x22, x28 to x31, w0 to w8
 * clobbered flag groups: FG0
 */
.globl secfulladder_bc22
secfulladder_bc22:
    /* Save fp to stack */
    addi sp, sp, -32
    sw   fp, 0(sp)
    addi fp, sp, 0

    /* Save input addresses. */
    sw   s0, 4(fp)
    sw   s1, 8(fp)
    sw   s2, 12(fp)
    sw   s3, 16(fp)
    sw   s4, 20(fp)
    sw   s5, 24(fp)
    sw   s6, 28(fp)
    addi s0, a0, 0
    addi s1, a1, 0
    addi s2, a2, 0
    addi s3, a6, 0
    addi s5, a5, 0
    addi s6, a3, 0

    /* Adjust stack for temporary variable a. */
    loop a4, 1
        addi sp, sp, -32
    addi s4, sp, 0 /* ptr_a */
    loop a4, 1
        addi sp, sp, -32 /* ptr_t */

    #define wx w0
    #define wy w1
    #define wc w1
    #define wa w2
    #define wt w2
    #define wr w3
    /* Compute a = x ^ y. */
    addi x4, x0, 1
    addi t0, x0, 2
    addi t2, x0, 3
    addi t1, s4, 0 /* ptr_a */
    loop a4, 9
        /* Whitening. */
        bn.xor wx, wx, wx
        bn.xor wy, wy, wy
        bn.xor wa, wa, wa
        /* Computation. */
        bn.lid x0, 0(a0)
        bn.lid x4, 0(a1)
        bn.xor wa, wx, wy
        bn.sid t0, 0(t1++)
        /* Adjust addresses. */
        add    a0, a0, a3
        add    a1, a1, a3

    /* Compute r[0] = c ^ a. */
    addi t1, s4, 0 /* ptr_a */
    loop a4, 8
        /* Whitening. */
        bn.xor wa, wa, wa
        bn.xor wc, wc, wc
        bn.xor wr, wr, wr
        /* Computation. */
        bn.lid t0, 0(t1++)
        bn.lid x4, 0(a2++)
        bn.xor wr, wa, wc
        bn.sid t2, 0(a5)
        /* Adjust addresses. */
        add    a5, a5, a3

    /* Compute r[1] = x ^ secand_cs20(a, x ^ c). */
    /* Compute t = x ^ c. */
    addi a0, s0, 0 /* ptr_x */
    addi a2, s2, 0 /* ptr_c */
    addi t1, sp, 0 /* ptr_t */
    loop a4, 8
        /* Whitening. */
        bn.xor wx, wx, wx
        bn.xor wc, wc, wc
        bn.xor wt, wt, wt
        /* Computation. */
        bn.lid x0, 0(a0)
        bn.lid x4, 0(a2++)
        bn.xor wt, wx, wc
        bn.sid t0, 0(t1++)
        /* Adjust addresses. */
        add    a0, a0, a3
    /* Compute t = secand_cs20(a, t). */
    addi a0, s4, 0 /* ptr_a */
    addi a1, x0, 32
    addi a2, sp, 0 /* ptr_t */
    addi a3, x0, 32 /* share stride */
    /* a4 is already nshares. */
    addi a5, x0, 32 /* output share stride */
    addi a6, a2, 0
    jal  x1, secand_cs20
    /* Compute r[1] = x ^ t. */
    addi a0, s0, 0 /* ptr_x */
    addi t1, sp, 0 /* ptr_t */
    addi t0, x0, 2
    addi t2, x0, 3
    addi a6, s3, 0 /* ptr_r */
    loop a4, 8 /* a4 is nshares. */
        /* Whitening. */
        bn.xor wx, wx, wx
        bn.xor wt, wt, wt
        bn.xor wr, wr, wr
        /* Computation. */
        bn.lid x0, 0(a0)
        bn.lid t0, 0(t1++)
        bn.xor wr, wx, wt
        bn.sid t2, 0(a6++)
        /* Adjust addresses. */
        add    a0, a0, s6

    /* Restore output pointer. */
    /* Since this functio will be used in secadd_cs20, we need to reserve input
     * to the carry a2, the number of shares a4 and output carry a6. We want a0
     * and a1 to automatically points to next bit. */
    addi a0, s0, 32
    addi a1, s1, 32
    addi a5, s5, 32
    /* a4 is still nshares */
    addi a3, s6, 0
    addi a2, s2, 0
    addi a6, s3, 0

    /* Restore registers. */
    lw s0, 4(fp)
    lw s1, 8(fp)
    lw s2, 12(fp)
    lw s3, 16(fp)
    lw s4, 20(fp)
    lw s5, 24(fp)
    lw s6, 28(fp)

    /* Restore sp and fp. */
    addi sp, fp, 0
    lw   fp, 0(sp)
    addi sp, sp, 32
    ret
