/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

#define NB_POLY 512
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

/*
 * Name: secb2amodq_bc22_mlkem (PINI)
 *
 * Return arithmetic shares mod q = 3329 of x, given its Boolean shares of mod 2^k,
 * with k = 12 (q < 2**k).
 * Bitsliced.
 *
 * Source: Alg.11 [BC22]
 *         [BC22]: "Bitslicing Arithmetic/Boolean Masking Conversions for Fun and Profit: with Application to Lattice-Based KEMs"
 *         Link: https://tches.iacr.org/index.php/TCHES/article/view/9831
 *
 * @param[in]  x10: dptr_x, dmem pointer to Boolean shares of x
 * @param[in]  x11: nshares, the number of shares
 * @param[out] x12: dptr_r, dmem pointer to the output Boolean shares of r
 *
 * clobbered registers: TODO
 * clobbered flag groups: TODO
 */
.globl secb2amodq_bc22_mlkem
secb2amodq_bc22_mlkem:
    /* Save fp to stack */
    addi sp, sp, -32
    sw   fp, 0(sp)
    addi fp, sp, 0

    /* Save registers. */
    sw s0, 4(fp)
    sw s1, 8(fp)
    sw s2, 12(fp)
    sw s3, 16(fp)
    sw s4, 20(fp)
    sw s5, 24(fp)

    /* Save input/output addresses. */
    addi s0, a0, 0
    addi s1, a1, 0
    addi s2, a2, 0

    /* Adjust stack for temporary variables. */
    loop a1, 1
        addi sp, sp, -384
    addi s3, sp, 0 /* ptr_a, ptr_b, ptr_c, ptr_zp (bitsliced) */
    loop a1, 1
        addi sp, sp, -416
    addi s4, sp, 0 /* ptr_s */
    loop a1, 1
        addi sp, sp, -NB_POLY /* ptr_zp */

    /* Sample zi, zpi for i = 1,...,nshares - 1. */
    addi    x4, x0, 30
    la      t0, modulus_bn
    bn.lid  x4, 0(t0)
    addi    a0, a2, 0 /* ptr_r */
    addi    t2, sp, 0 /* ptr_zp */
    addi    t3, a1, -1 /* nshares - 1 */
    bn.wsrr w16, mod
    loop t3, 6
        jal x1, poly_rej_samp
        /* Compute zpi = q - zi. */
        loopi N_WDR, 3
            bn.lid      x0, 0(a2++)
            bn.subv.16h w0, w30, w0 /* Since inputs are < q, we need to only use bn.subv. */
            bn.sid      x0, 0(t2++)
        nop

    /* Instead of clearing the last share of zp and then bitslice it, we bitslice
     * only shares 1...nshares - 1 of zp, and clear the last share of zp (bitsliced). */
    /* Bitslicing zp for shares 1,...,nshares - 1. */
    addi a0, sp, 0 /* ptr_zp */
    addi a1, s3, 0 /* ptr_zp (bitsliced) */
    addi s1, s1 , -1 /* nshares - 1 */
    loop s1, 2
        jal  x1, poly_to_bs_12
        addi a1, a1, 384
    addi s1, s1, 1 /* Restore s1 = nshares. */
    /* Clear the last share of zp (bitsliced). */
    bn.xor w0, w0, w0
    loopi 12, 1
        bn.sid x0, 0(a1++)

    /* Compute a = seca2bmodq_bc22_mlkem(zp, nshares). */
    addi a0, s3, 0 /* ptr_zp (bitsliced) */
    addi a1, s1, 0 /* nshares */
    addi a2, s3, 0 /* ptr_a */
    jal  x1, seca2bmodq_bc22_mlkem

    /* Compute b = secaddmodq_bc22_mlkem(a, x, nshares). */
    /* Inline secaddmodq_bc22_mlkem. */
    /* Compute s = secadd_bc22(a, x, k + 1, nshares). */
    /* Initialize c = 0. */
    bn.xor w0, w0, w0
    addi   t0, s4, 384 /* ptr_c */
    loop s1, 2
        bn.sid x0, 0(t0)
        addi   t0, t0, 416

    /* Ripple-carry adder. */
    addi a0, s3, 0 /* ptr_a */
    addi a1, x0, 384
    addi a2, s0, 0 /* ptr_x */
    addi a3, x0, 384
    addi a4, s1, 0 /* nshares */
    addi a5, s4, 0 /* ptr_s */
    addi a6, x0, 416
    addi a7, s4, 384 /* ptr_c = cin */
    addi t4, x0, 416
    addi t5, s4, 384 /* ptr_c = cout */
    addi t6, x0, 416
    /* Loop over i=1,...,k-1. */
    loopi 12, 2
        /* a0 already points to x[i] */
        /* a1 is already share stride of x. */
        /* a2 already points to y[i] */
        /* a3 is already share stride of y. */
        /* a4 is already nshares. */
        /* a5 already points to r. */
        /* a6 is already share stride of r. */
        /* a7 already points to ptr_c = cin. */
        /* t4 is already share stride of cin. */
        /* t5 already points to ptr_c = cout. */
        /* t6 is already share stride of cout. */
        jal  x1, secfulladder_bc22
        /* After secfulladder_bc22:
         *  - a0 and a2 points to x[i + 1] and y[i + 1].
         *  - a1 and a3 are still share stride of x and y.
         *  - a4 is still nshares.
         *  - a5 points to r[i + 1].
         *  - a6 is still share stride of r.
         *  - a7 points to cin.
         *  - t4 is still share stride of cin.
         *  - t5 points to cout.
         *  - t6 is still share stride of cout. */
        nop
    /* Bit i = k + 1 is already x[k + 1] ^ y[k + 1] ^ c = cout since x[k + 1] = y[k + 1] = 0. */

    /* Compute s = secadd_bc22(s, p, k + 1, nshares) where p = 2**(k + 1) - q = 4863 = b1001011111111. */
    /* Initialize c = 0. */
    addi   t0, sp, 0 /* ptr_c */
    bn.xor w0, w0, w0
    loop s1, 1
        bn.sid x0, 0(t0++)
    addi s5, t0, 0 /* ptr_p */

    addi    t0, s5, 0 /* ptr_p */
    bn.subi w1, w0, 1
    addi    x4, x0, 1
    bn.sid  x4, 0(t0++)
    addi    t1, s1, -1
    loop t1, 1
        bn.sid x0, 0(t0++)

    addi a0, s5, 0 /* ptr_p */
    addi a1, x0, 32
    addi a2, s4, 0 /* ptr_s */
    addi a3, x0, 416
    addi a4, s1, 0 /* nshares */
    addi a5, s4, 0 /* ptr_s */
    addi a6, x0, 416
    addi a7, sp, 0 /* cin */
    addi t4, x0, 32
    addi t5, sp, 0 /* cout */
    addi t6, x0, 32
    /* Bit 0 -- 7: p = 1. */
    loopi 8, 2
        jal  x1, secfulladder_bc22
        addi a0, a0, -32 /* Reset a0 to ptr_p. */

    /* Bit 8: p = 0. */
    bn.xor w0, w0, w0
    bn.sid x0, 0(a0)
    addi   a0, s5, 0
    jal    x1, secfulladder_bc22
    /* Bit 9: p = 1. */
    bn.xor  w0, w0, w0
    bn.subi w0, w0, 1
    addi    a0, s5, 0
    bn.sid  x0, 0(a0)
    jal     x1, secfulladder_bc22
    /* Bit 10 -- 11: p = 0. */
    bn.xor w0, w0, w0
    addi   a0, s5, 0
    bn.sid x0, 0(a0)
    jal    x1, secfulladder_bc22
    addi   a0, s5, 0
    jal    x1, secfulladder_bc22

    /* Bit 12: p = 1. */
    /* Compute r[12] = p[12] ^ s[12] ^ c = ~(s[12] ^ c) since p[12] = 1. */
    addi x4, x0, 1
    addi t1, x0, 2
    /* Whitening. */
    bn.xor w0, w0, w0
    bn.xor w1, w1, w1
    bn.xor w2, w2, w2
    bn.xor w3, w3, w3
    /* Computation. */
    bn.lid x0, 0(a2)
    bn.lid x4, 0(a7)
    bn.xor w3, w0, w1
    bn.not w2, w3
    bn.sid t1, 0(a2)
    add    a2, a2, a3
    add    a7, a7, t4

    addi t2, s1, -1
    loop t2, 9
        /* Whitening. */
        bn.xor w0, w0, w0
        bn.xor w1, w1, w1
        bn.xor w2, w2, w2
        /* Computation. */
        bn.lid x0, 0(a2)
        bn.lid x4, 0(a7)
        bn.xor w2, w0, w1
        bn.sid t1, 0(a2)
        add    a2, a2, a3
        add    a7, a7, t4

    /* Compute a = bitcopymask_bc22_mlkem(s[k], (k + 1) * 32, nshares). */
    addi a0, s4, 384 /* ptr_s[k] */
    addi a1, x0, 416 /* share_str = (k + 1) * 32 */
    addi a2, s1, 0 /* nshares */
    addi a3, s3, 0 /* ptr_a */
    jal  x1, bitcopymask_bc22_mlkem

    /* Compute r = secadd_bc22(a, s, k, nshares). */
    addi a0, s3, 0 /* ptr_a */
    addi a1, x0, 384
    addi a2, s4, 0 /* ptr_s */
    addi a3, x0, 416
    addi a4, s1, 0 /* nshares */
    addi a5, s3, 0 /* ptr_b */
    addi a6, x0, 384
    addi a7, x0, 12 /* k */
    jal  x1, secadd_bc22
    /* End inlining secaddmodq_bc22_mlkem. */

    /* Compute c = refreshios(b, k, k * 32, nshares). */
    addi a0, s3, 0 /* ptr_b */
    addi a1, x0, 12 /* k */
    addi a2, x0, 384 /* k * 32 */
    addi a3, s1, 0 /* nshares */
    addi a4, s3, 0 /* ptr_c */
    jal  x1, refreshios_bc22

    /* Unmask c. */
    addi t0, s3, 0 /* ptr_c */
    addi t2, s1, -1 /* nshares - 1 */
    addi x4, x0, 1
    loopi 12, 7
        addi   t1, t0, 384
        bn.lid x0, 0(t0)
        loop t2, 3
            bn.lid x4, 0(t1)
            bn.xor w0, w0, w1
            addi   t1, t1, 384
        bn.sid x0, 0(t0++)

    /* Put c from bitsliced to normal representation. */
    addi a0, s3, 0 /* ptr_c */
    addi a1, s2, 0 /* ptr_r */
    loop t2, 1
        addi a1, a1, NB_POLY
    jal x1, poly_from_bs_12

    /* Restore registers. */
    lw s0, 4(fp)
    lw s1, 8(fp)
    lw s2, 12(fp)
    lw s3, 16(fp)
    lw s4, 20(fp)
    lw s5, 24(fp)

    /* Restore sp and fp. */
    addi sp, fp, 0
    lw   fp, 0(sp)
    addi sp, sp, 32
    ret
