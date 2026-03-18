/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

#define NB_POLY 512
#define N_WDR 16
#define N_COEFFS 16

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
 * Name: masked_cbd_bc22 (PINI)
 *
 * Return arithmetic shares of r = HW(x) - HW(y) mod q = 3329, given Boolean
 * shares of x and y mod 2**eta. k = 12 (q < 2**k).
 * Bitsliced.
 *
 * Source: Alg.17 [BC22]
 *         [BC22]: "Bitslicing Arithmetic/Boolean Masking Conversions for Fun and Profit: with Application to Lattice-Based KEMs"
 *         Link: https://tches.iacr.org/index.php/TCHES/article/view/9831
 *
 * @param[in]  x10: dptr_x, dmem pointer to Boolean shares of x
 * @param[in]  x11: dptr_y, dmem pointer to Boolean shares of y
 * @param[in]  x12: eta
 * @param[in]  x13: nshares, the number of shares
 * @param[out] x14: dptr_r, dmem pointer to arithmetic shares of r
 *
 * clobbered registers: TODO
 * clobbered flag groups: TODO
 */
.globl masked_cbd_bc22
masked_cbd_bc22:
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
    sw s6, 28(fp)

    /* Save input/output addresses. */
    addi s0, a0, 0
    addi s1, a1, 0
    addi s2, a2, 0
    addi s3, a3, 0
    addi s4, a4, 0

    /* Adjust stack for temporary variables. */
    slli t0, a2, 6 /* l = (2 * eta) * 32 */
    loop a3, 1
        sub sp, sp, t0
    addi s5, sp, 0 /* ptr_s */
    loop a3, 1
        addi sp, sp, -32
    addi s6, sp, 0 /* ptr_sum */
    loop a3, 1
        addi sp, sp, -384

    /* Copy x to s[1,..,eta] and ~y to s[eta + 1,..,2 * eta]. */
    addi t0, s5, 0 /* ptr_s */
    slli x4, a2, 5 /* eta * 32 */
    add  t1, s5, x4 /* ptr_s[eta + 1] */
    addi t2, a3, -1 /* nshares - 1 */
    /* Handle first share. */
    loop a2, 7
        /* Whitening. */
        bn.xor w0, w0, w0
        /* Copy x[0]. */
        bn.lid x0, 0(a0++)
        bn.sid x0, 0(t0++)
        /* Whitening. */
        bn.xor w0, w0, w0
        /* Copy ~y[0]. */
        bn.lid x0, 0(a1++)
        bn.not w0, w0
        bn.sid x0, 0(t1++)
    add t0, t0, x4
    add t1, t1, x4
    /* Handle share 2...nshares. */
    loop t2, 9
        loop a2, 6
            /* Whitening. */
            bn.xor w0, w0, w0
            /* Copy x. */
            bn.lid x0, 0(a0++)
            bn.sid x0, 0(t0++)
            /* Whitening. */
            bn.xor w0, w0, w0
            /* Copy y. */
            bn.lid x0, 0(a1++)
            bn.sid x0, 0(t1++)
        add t0, t0, x4
        add t1, t1, x4

    /* We need to loop over i = 1,...,k where k = ceil(log2(l + 1)) = 3 for both
     * eta = 2 and eta = 3. Then the inner loop is over j = 1,...,l where
     * l >>= i, so j is in {eta, eta/2, eta/4}, i.e., {2, 1, 0} for eta = 2 and
     * {3, 1, 0} for eta = 3. Thus, in the third iteration i = k, the inner loop
     * is not executed at all. */
    /*----------------------- Iteration i = 1, l = 2 * eta -----------------------*/
    /* Since l mod 2 = 0, we clear the carry sum. */
    addi   t0, s6, 0 /* ptr_sum */
    bn.xor w0, w0, w0
    loop a3, 1
        bn.sid x0, 0(t0++)

    /* l >>= 1: loop j = 1,..., l = 1,...,eta. */
    /* Inputs to secfulladder_bc22. */
    slli t0, a2, 6 /* (2 * eta) * 32 */
    addi a0, s5, 0 /* s[0] */
    addi a1, t0, 0
    addi a2, s5, 32 /* s[1] */
    addi a3, t0, 0
    addi a4, s3, 0
    addi a5, s6, 0 /* ptr_sum = r */
    addi a6, x0, 32
    addi a7, s6, 0 /* ptr_sum = cin */
    addi t4, x0, 32
    addi t5, s5, 0 /* s[0] = cout */
    addi t6, t0, 0
    loop s2, 5
        /* Compute c, s[j] = secfulladder_bc22(s[2j], s[2j + 1], eta, nshares, c). */
        /* a0 already points to s[2j] */
        /* a1 is already share stride of s. */
        /* a2 already points to s[2j + 1] */
        /* a3 is already share stride of s. */
        /* a4 is already nshares. */
        /* a5 already points to sum = r. */
        /* a6 is already share stride of sum = r. */
        /* a7 already points to sum = cin. */
        /* t4 is already share stride of sum = cin. */
        /* t5 already points to s[j] = cout. */
        /* t6 is already share stride of s = cout. */
        jal  x1, secfulladder_bc22
        /* After secfulladder_bc22:
        *  - a0 and a2 points to s[2j + 1] and s[2j + 2] --> need to be adjusted.
        *  - a1 and a3 are still share stride of s.
        *  - a4 is still nshares.
        *  - a5 points to sum + 32 (output) --> need to be adjusted to sum.
        *  - a6 is still share stride of sum.
        *  - a7 points to sum (cin).
        *  - t4 is still share stride of sum.
        *  - t5 points to s[j] (cout) --> need to be adjusted to s[j + 1].
        *  - a6 is still share stride of s. */
        /* Adjust addresses. */
        addi a0, a0, 32 /* s[2 * (j + 1)] */
        addi a2, a2, 32 /* s[2 * (j + 1) + 1] */
        addi a5, a5, -32 /* sum */
        addi t5, t5, 32 /* s[j + 1] */

    /* Copy sum to ptr_tmp[1]. */
    addi t0, sp, 0 /* ptr_tmp[1] */
    loop s3, 4
        /* Whitening. */
        bn.xor w0, w0, w0
        bn.lid x0, 0(a5++) /* a5 still points to sum. */
        bn.sid x0, 0(t0)
        addi   t0, t0, 384

    /*----------------------- Iteration i = 2, l = eta -----------------------*/
    addi t0, x0, 2
    beq  s2, t0, _handle_eta_2
    /* Since l mod 2 = 1 if eta = 3, we compute sum = s[l] = s[3]. */
    addi t0, s6, 0 /* ptr_sum */
    addi t1, s5, 0 /* ptr_s */
    addi t1, t1, 64 /* 2 * 32 */
    slli x4, s2, 6 /* (2 * eta) * 32 */
    loop s3, 4
        /* Whitening. */
        bn.xor w0, w0, w0
        bn.lid x0, 0(t1)
        bn.sid x0, 0(t0++)
        add    t1, t1, x4
    beq x0, x0, _continue_1

_handle_eta_2:
    /* Since l mod 2 = 0 if eta = 2, we clear the carry sum. */
    addi   t0, s6, 0 /* ptr_sum */
    bn.xor w0, w0, w0
    loop s3, 1
        bn.sid x0, 0(t0++)

_continue_1:
    /* l >> 1: loop j = 1,...,l // 2 --> 1 iteration. */
    /* Inputs to secfulladder_bc22. */
    slli t0, s2, 6
    addi a0, s5, 0 /* s[0] */
    addi a1, t0, 0
    addi a2, s5, 32 /* s[1] */
    addi a3, t0, 0
    addi a4, s3, 0
    addi a5, s6, 0 /* ptr_sum = r */
    addi a6, x0, 32
    addi a7, s6, 0 /* ptr_sum = cin */
    addi t4, x0, 32
    addi t5, s5, 0 /* s[0] = cout */
    addi t6, t0, 0
    /* Compute c, s[j] = secfulladder_bc22(s[2j], s[2j + 1], eta, nshares, c). */
    /* a0 already points to s[2j] */
    /* a1 is already share stride of s. */
    /* a2 already points to s[2j + 1] */
    /* a3 is already share stride of s. */
    /* a4 is already nshares. */
    /* a5 already points to sum = r. */
    /* a6 is already share stride of sum = r. */
    /* a7 already points to sum = cin. */
    /* t4 is already share stride of sum = cin. */
    /* t5 already points to s[j] = cout. */
    /* t6 is already share stride of s = cout. */
    jal  x1, secfulladder_bc22
    /* After secfulladder_bc22:
    *  - a0 and a2 points to s[2j + 1] and s[2j + 2] --> need to be adjusted.
    *  - a1 and a3 are still share stride of s.
    *  - a4 is still nshares.
    *  - a5 points to sum + 32 (output) --> need to be adjusted to sum.
    *  - a6 is still share stride of sum.
    *  - a7 points to sum (cin).
    *  - t4 is still share stride of sum.
    *  - t5 points to s[j] (cout) --> need to be adjusted to s[j + 1].
    *  - a6 is still share stride of s. */

    /* Copy sum to ptr_tmp[2]. */
    addi t0, sp, 32 /* ptr_tmp[2] */
    loop s3, 4
        /* Whitening. */
        bn.xor w0, w0, w0
        bn.lid x0, 0(a7++) /* a7 still points to sum. */
        bn.sid x0, 0(t0)
        addi   t0, t0, 384

    /*----------------------- Iteration i = 3, l = eta / 2 -----------------------*/
    /* Since l mod 2 = 1, we compute tmp[3] = s[l] = s[1]. */
    addi t0, sp, 0 /* ptr_tmp */
    addi t0, t0, 64
    addi t1, s5, 0 /* ptr_s */
    slli t2, s2, 6

    loop s3, 5
        /* Whitening. */
        bn.xor w0, w0, w0
        bn.lid x0, 0(t1)
        bn.sid x0, 0(t0)
        add    t1, t1, t2
        addi   t0, t0, 384

    /* Clear bit k --> 12 of tmp. */
    addi   t0, sp, 0 /* ptr_tmp */
    addi   t0, t0, 96
    bn.xor w0, w0, w0
    loop s3, 3
        loopi 9, 1
            bn.sid x0, 0(t0++)
        addi t0, t0, 96 /* point to next share. */

    /* Compute r = secb2amodq_bc22_mlkem(tmp, nshares). */
    addi a0, sp, 0 /* ptr_tmp */
    addi a1, s3, 0 /* nshares */
    addi a2, s4, 0 /* ptr_r */
    jal  x1, secb2amodq_bc22_mlkem

    /* Compute r[0] = r[0] - eta mod q. */
    addi   t0, s4, 0 /* ptr_r */
    addi   t1, s5, 0 /* ptr_s */
    sw     s2, 0(t1)
    bn.lid x0, 0(t1)
    loopi N_COEFFS, 1
        bn.rshi w1, w0, w1 >> 16
    loopi N_WDR, 3
        bn.lid       x0, 0(t0)
        bn.subvm.16h w0, w0, w1
        bn.sid       x0, 0(t0++)

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
