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
 * Name: linearrefreshmodq_rp10_mlkem (NI)
 *
 * Return new arithmetic shares mod q = 3329 of the value x.
 * Vectorized for polynomial.
 *
 * Source: Alg.4 [RP10]
 *         [RP10]: "Provably Secure Higher-Order Masking of AES"
 *         Link: http://link.springer.com/10.1007/978-3-642-15031-9_28

 * Note: The algorithm is also provided in [CGTZ23] (Alg.12). This implementation
 *       follows Alg.12 of [CGTZ23] since it accumulates the result onto the
 *       last share (instead of the first share) which is needed for performance
 *       of 1bitB2A from [SPOG19], as specified in Alg.2 in [CGTZ23] for
 *       free-SNI security.
 *       [CGTZ23]: "Improved Gadgets for the High-Order Masking of Dilithium"
 *       Link: https://tches.iacr.org/index.php/TCHES/article/view/11160
 *
 * @param[in]  w16: R | Q
 * @param[in]  x10: dptr_xa, dmem pointer to arithmetic shares of x
 * @param[in]  x11: nshares, the number of shares
 * @param[out] x12: dptr_ra, dmem pointer to arithmetic shares of r
 *
 * clobbered registers: TODO
 * clobbered flag groups: TODO
 */
.global linearrefreshmodq_rp10_mlkem
linearrefreshmodq_rp10_mlkem:
    /* Save fp to stack */
    addi sp, sp, -32
    sw   fp, 0(sp)
    addi fp, sp, 0

    /* Save registers. */
    sw   s0, 4(fp)
    sw   s1, 8(fp)
    sw   s2, 12(fp)
    sw   s3, 16(fp)
    addi s0, a0, 0
    addi s1, a1, 0

    /* Adjust stack for temporary variable. */
    addi sp, sp, -NB_POLY
    addi s2, sp, 0 /* ptr_y[nshares] */
    addi sp, sp, -NB_POLY /* ptr_rand */

    /* Compute address of x[nshares]. */
    addi s1, s1, -1 /* nshares - 1 */
    addi t0, a0, 0
    loop s1, 2
        addi t0, t0, NB_POLY /* t0 = ptr_x[nshares] */
    /* Copy x[nshares] to y[nshares]. */
    addi t1, s2, 0 /* ptr_y[nshares]. */
    loopi N_WDR, 2
        bn.lid x0, 0(t0++)
        bn.sid x0, 0(t1++)

    addi x4, x0, 1
    addi s3, x0, 2
    /* Loop over i = 1,..., nshares - 1. */
    loop s1, 12 /* s1 is still nshares - 1. */
        /* Generate randomness mod q in rand[i]. */
        addi a0, sp, 0 /* ptr_rand */
        jal  x1, poly_rej_samp
        addi a0, a0, -NB_POLY /* Reset to ptr_rand. */
        loopi N_WDR, 7
            bn.lid       x0, 0(a0++) /* rand[i] */
            bn.lid       x4, 0(s0++) /* x[i] */
            bn.addvm.16h w2, w1, w0 /* y[i] = (x[i] + r[i]) mod q */
            bn.sid       s3, 0(a2++)
            bn.lid       x4, 0(s2) /* y[nshares] */
            bn.subvm.16h w2, w1, w0 /* y[nshares] = (y[nshares] - r[i]) mod q */
            bn.sid       s3, 0(s2++) /* t5 = ptr_y[nshare] */
        addi s2, s2, -NB_POLY /* point back to ptr_y[nshares]. */

    /* Copy y[nshares] to the output. */
    loopi N_WDR, 2
        bn.lid x0, 0(s2++)
        bn.sid x0, 0(a2++)

    /* Restore registers. */
    lw s0, 4(fp)
    lw s1, 8(fp)
    lw s2, 12(fp)
    lw s3, 16(fp)

    /* Restore sp and fp. */
    addi sp, fp, 0
    lw   fp, 0(sp)
    addi sp, sp, 32
    ret
