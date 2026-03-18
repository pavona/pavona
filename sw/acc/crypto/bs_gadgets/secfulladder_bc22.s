/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

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
 * @param[in]  x11: share stride, distance between shares of x
 * @param[in]  x12: dptr_y, dmem pointer to Boolean shares of y
 * @param[in]  x13: share stride, distance between shares of y
 * @param[in]  x14: nshares, the number of shares
 * @param[out] x15: dptr_r, dmem pointer to Boolean shares of r
 * @param[in]  x16: share stride, distance between shares of r
 * @param[in]  x17: dptr_c, dmem pointer to the Boolean shares of cin
 * @param[in]  x29: share stride, distance between shares of cin
 * @param[out] x30: dptr_c, dmem pointer to the Boolean shares of cout
 * @param[in]  x31: share stride, distance between shares of cout
 *
 * clobbered registers: x2 to x13, x15 to x16, x18, x28 to x31, w0 to w8
 * clobbered flag groups: FG0
 */
.globl secfulladder_bc22
secfulladder_bc22:
#if NSHARES == 2
    /* Save addresses. */
    add t0, a0, x0
    add t1, a2, x0
    add t2, a5, x0
    add t3, a7, x0

    /* Load x. */
    bn.xor w0, w0, w0
    bn.lid x0, 0(t0) /* x[0] */
    add    t0, t0, a1
    addi   x4, x0, 1
    bn.xor w1, w1, w1
    bn.lid x4++, 0(t0) /* x[1] */
    /* Load y. */
    bn.xor w2, w2, w2
    bn.lid x4++, 0(t1) /* y[0] */
    add    t1, t1, a3
    bn.xor w3, w3, w3
    bn.lid x4, 0(t1) /* y[1] */

    /* Compute sharewise a = x ^ y. */
    bn.xor w4, w4, w4
    bn.xor w4, w0, w2
    bn.xor w5, w5, w5
    bn.xor w5, w1, w3

    /* Compute r = cin ^ a. */
    bn.xor w2, w2, w2
    addi   x4, x0, 2
    bn.lid x4++, 0(t3)
    add    t3, t3, t4
    bn.xor w3, w3, w3
    bn.lid x4++, 0(t3)

    bn.xor w6, w6, w6
    bn.xor w6, w4, w2
    addi   x4, x0, 6
    bn.sid x4, 0(t2)
    add    t2, t2, a6
    bn.xor w6, w6, w6
    bn.xor w6, w5, w3
    bn.sid x4, 0(t2)

    /* Compute cout = x ^ secand(a, x ^ cin). */
    /* a: w4 -- w5
     * x: w0 -- w1
     * cin: w2 -- w3 */
    bn.xor w6, w6, w6
    bn.xor w6, w0, w2
    bn.xor w7, w7, w7
    bn.xor w7, w1, w3

    /* a: w4 -- w5
     * x ^ cin: w6 -- w7
     * x: w0 -- w1.  */
    /* PINI */
    bn.wsrr w8, urnd
    /* Handle cout_01. */
    bn.xor  w2, w2, w2
    bn.and  w2, w4, w6
    bn.xor  w3, w3, w3
    bn.xor  w3, w7, w8
    bn.and  w3, w4, w3
    bn.xor  w9, w9, w9
    bn.not  w9, w4
    bn.and  w9, w9, w8
    bn.xor  w3, w3, w9
    bn.xor  w2, w2, w3
    bn.xor  w3, w3, w3
    bn.xor  w3, w2, w0
    add     t2, t5, x0
    addi    x4, x0, 3
    bn.sid  x4, 0(t2)
    add     t2, t2, t6
    /* Handle cout_10. */
    bn.xor  w2, w2, w2
    bn.and  w2, w5, w7
    bn.xor  w3, w3, w3
    bn.xor  w3, w6, w8
    bn.and  w3, w5, w3
    bn.xor  w9, w9, w9
    bn.not  w9, w5
    bn.and  w9, w9, w8
    bn.xor  w3, w3, w9
    bn.xor  w2, w2, w3
    bn.xor  w3, w3, w3
    bn.xor  w3, w2, w1
    bn.sid  x4, 0(t2)

    /* Point to next bit. */
    addi a0, a0, 32
    addi a2, a2, 32
    addi a5, a5, 32
    ret

#else
    /* Save fp to stack */
    addi sp, sp, -64
    sw   fp, 0(sp)
    addi fp, sp, 0

    /* Save input addresses. */
    sw   s0, 4(fp)
    sw   s1, 8(fp)
    sw   s2, 12(fp)
    sw   a2, 16(fp)
    sw   a3, 20(fp)
    sw   a5, 24(fp)
    sw   a6, 28(fp)
    sw   t4, 32(fp)
    sw   t5, 36(fp)
    sw   t6, 40(fp)
    addi s0, a0, 0
    addi s1, a1, 0

    /* Adjust stack for temporary variable a. */
    loop a4, 1
        addi sp, sp, -32
    addi s2, sp, 0 /* ptr_a */
    loop a4, 1
        addi sp, sp, -32 /* ptr_t */

    #define wx w0
    #define wy w1
    #define wc w1
    #define wa w2
    #define wt w2
    #define wr w3

    /* Compute r = x ^ y ^ cin. */
    /* Compute a = x ^ y. */
    addi x4, x0, 1
    addi t0, x0, 2
    addi t1, s2, 0 /* ptr_a */
    loop a4, 9
        /* Whitening. */
        bn.xor wx, wx, wx
        bn.xor wy, wy, wy
        bn.xor wa, wa, wa
        /* Computation. */
        bn.lid x0, 0(a0)
        bn.lid x4, 0(a2)
        bn.xor wa, wx, wy
        bn.sid t0, 0(t1++)
        /* Adjust addresses. */
        add    a0, a0, a1
        add    a2, a2, a3

    /* Compute cout = x ^ secand_cs20(a, x ^ cin). */
    /* Compute t = x ^ cin. */
    addi a0, s0, 0 /* ptr_x */
    addi a2, a7, 0 /* ptr_cin */
    addi t1, sp, 0 /* ptr_t */
    loop a4, 9
        /* Whitening. */
        bn.xor wx, wx, wx
        bn.xor wc, wc, wc
        bn.xor wt, wt, wt
        /* Computation. */
        bn.lid x0, 0(a0)
        bn.lid x4, 0(a2)
        bn.xor wt, wx, wc
        bn.sid t0, 0(t1++)
        /* Adjust addresses. */
        add    a0, a0, a1
        add    a2, a2, t4
    /* Compute t = secand_cs20(a, t). */
    addi a0, s2, 0 /* ptr_a */
    addi a1, x0, 32
    addi a2, sp, 0 /* ptr_t */
    addi a3, x0, 32
    /* a4 is already nshares. */
    addi a5, sp, 0 /* ptr_t */
    addi a6, x0, 32
    jal  x1, secand_cs20

    /* Compute r = x ^ y ^ cin = a ^ cin. */
    /* We put this step here so that in case we use the same input and output
     * pointer for x (which is the case in secaddmodq_bc2_mlkem), we don't
     * overwrite input before it's fully being used. */
    /* Compute a = cin ^ a. */
    addi x4, x0, 1
    addi t0, x0, 2
    addi t2, x0, 3
    addi t1, s2, 0 /* ptr_a */
    addi a2, a7, 0 /* ptr_cin */
    lw   t4, 32(fp) /* share stride of cin */
    loop a4, 8
        /* Whitening. */
        bn.xor wa, wa, wa
        bn.xor wc, wc, wc
        bn.xor wr, wr, wr
        /* Computation. */
        bn.lid t0, 0(t1)
        bn.lid x4, 0(a2)
        bn.xor wr, wa, wc
        bn.sid t2, 0(t1++)
        /* Adjust addresses. */
        add    a2, a2, t4

    /* Back to computation of cout. */
    /* Compute cout = x ^ t. */
    addi a0, s0, 0 /* ptr_x */
    addi t1, sp, 0 /* ptr_t */
    lw   a1, 36(fp) /* ptr_cout */
    lw   t6, 40(fp) /* share stride of cout */
    loop a4, 9
        /* Whitening. */
        bn.xor wx, wx, wx
        bn.xor wt, wt, wt
        bn.xor wr, wr, wr
        /* Computation. */
        bn.lid x0, 0(a0)
        bn.lid t0, 0(t1++)
        bn.xor wr, wx, wt
        bn.sid t2, 0(a1)
        /* Adjust addresses. */
        add    a0, a0, s1
        add    a1, a1, t6

    /* Once everything is done, we copy the addition result to its output space. */
    /* Copy a to r. */
    addi a0, s2, 0 /* ptr_a */
    lw   a1, 24(fp) /* ptr_r */
    lw   a6, 28(fp) /* share stride of r */
    loop a4, 4
        /* Whitening. */
        bn.xor w0, w0, w0
        /* Computation. */
        bn.lid x0, 0(a0++)
        bn.sid x0, 0(a1)
        /* Adjust addresses. */
        add    a1, a1, a6

    /* Restore output pointer. */
    /* Since this function will be used in secadd_bc22, we need to reserve input
     * carry a2, the number of shares a4 and output carry a6. We want a0, a1 and
     * a5 to automatically points to next bit (for the adder chain). */
    addi a0, s0, 32
    lw   a2, 16(fp)
    addi a2, a2, 32
    lw   a5, 24(fp)
    addi a5, a5, 32
    /* a4 is still nshares */
    addi a1, s1, 0
    lw   a3, 20(fp)
    /* a7 is still cin. */
    /* t4 is already share stride of cin. */
    lw   t5, 36(fp)
    /* t6 is already share stride of cout. */

    /* Restore registers. */
    lw s0, 4(fp)
    lw s1, 8(fp)
    lw s2, 12(fp)

    /* Restore sp and fp. */
    addi sp, fp, 0
    lw   fp, 0(sp)
    addi sp, sp, 64
    ret
#endif /* NSHARES == 2 */
