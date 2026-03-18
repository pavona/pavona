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
 * Name: seca2b_bc22 (PINI)
 *
 * Return Boolean shares mod 2**k of a value x given its arithmetic shares mod 2**k.
 * Bitsliced.
 *
 * Source: Alg.8 [BC22]
 *         [BC22]: "Bitslicing Arithmetic/Boolean Masking Conversions for Fun and Profit: with Application to Lattice-Based KEMs"
 *         Link: https://tches.iacr.org/index.php/TCHES/article/view/9831
 *
 * @param[in]  x10: dptr_xa, dmem pointer to the input arithmetic shares mod 2**k of x
 * @param[in]  x11: k, bitsize of x.
 * @param[in]  x12: share stride, distance between shares
 * @param[in]  x13: nshares, the number of shares
 * @param[out] x14: dptr_rb, dmem pointer to the output Boolean shares
 *
 * clobbered registers: TODO
 * clobbered flag groups: TODO
 */
.globl seca2b_bc22
seca2b_bc22:
#if NSHARES == 2
    /* Save fp to stack */
    addi sp, sp, -32
    sw   fp, 0(sp)
    addi fp, sp, 0

    /* Adjust stack your temp variables. */
    slli t0, a2, 1
    sub  sp, sp, t0 /* ptr_s */
    add  t1, sp, x0
    sub  sp, sp, t0 /* ptr_sp */

    /* Copy x[0,..,nshares//2] to s and extend s to nshares. */
    add t2, t1, x0 /* Save ptr_s. */
    loop a1, 3
        bn.xor w0, w0, w0
        bn.lid x0, 0(a0++)
        bn.sid x0, 0(t1++)
    bn.xor w0, w0, w0
    loop a1, 1
        bn.sid x0, 0(t1++)

    /* Copy x[nshares//2,..,nshares] to sp and extend sp to nshares. */
    add t0, sp, x0
    loop a1, 1
        bn.sid x0, 0(t0++)
    loop a1, 3
        bn.lid x0, 0(a0++)
        bn.sid x0, 0(t0++)
        bn.xor w0, w0, w0

    /* Save registers. */
    add t0, a1, x0
    add t1, a2, x0
    add t3, a4, x0

    /* Compute r = secadd_bc22(s, sp, k, nshares). */
    addi a0, t2, 0 /* ptr_s */
    addi a1, t1, 0
    addi a2, sp, 0 /* ptr_sp */
    addi a3, t1, 0
    addi a4, x0, 2 /* nshares */
    addi a5, t3, 0 /* ptr_r */
    addi a6, t1, 0
    addi a7, t0, 0 /* k */
    jal  x1, secadd_bc22

    /* Restore sp and fp. */
    addi sp, fp, 0
    lw   fp, 0(sp)
    addi sp, sp, 32
    ret

#else
    /* Save fp to stack */
    addi sp, sp, -64
    sw   fp, 0(sp)
    addi fp, sp, 0

    /* All-zero register. */
    bn.xor bn0, bn0, bn0

    /* Save registers. */
    sw s0, 4(fp)
    sw s1, 8(fp)
    sw s2, 12(fp)
    sw s3, 16(fp)
    sw s4, 20(fp)
    sw s5, 24(fp)
    sw s6, 28(fp)
    sw s7, 32(fp)

    /* Save input and output pointers. */
    addi s0, a0, 0
    addi s1, a1, 0
    addi s2, a2, 0
    addi s3, a3, 0
    addi s4, a4, 0

    /* Adjust sp to accommodate temporary values of recursive calls. */
    loop s3, 1
        sub sp, sp, s2
    addi s5, sp, 0 /* ptr_y */
    loop s3, 1
        sub sp, sp, s2 /* ptr_yprime */

    /* If nshares > 1, continue. Else, return. */
    addi x4, x0, 1
    beq  s3, x4, _handle_one_share

    /* Compute number of shares for each recursive call. */
    srli s6, s3, 1 /* s6 = nshares // 2 */
    sub  s7, s3, s6 /* s7 = nshares - (nshares // 2) */

    /* Compute y = seca2b_bc22(x[0],...,x[nshares // 2], nshares // 2). */
    /* a0 = ptr_x */
    /* a1 is already k. */
    /* a2 is already share stride. */
    addi a3, s6, 0
    addi a4, s5, 0 /* ptr_y */
    jal  x1, seca2b_bc22

    /* Zeroize y[nshares // 2 + 1]...yb[nshares]. */
    /* Point to y[nshares // 2 + 1]. */
    addi t0, s5, 0 /* ptr_y */
    loop s6, 1
        add t0, t0, s2
    /* Zeroize. */
    addi x4, x0, 31
    loop s7, 3
        loop s1, 1
            bn.sid x4, 0(t0++)
        nop

    /* Compute yprime = seca2b_bc22(x[nshares//2 + 1],...,x[nshares], nshares // 2). */
    /* Zeroize yprime[0]...yprime[nshares - (nshares // 2) + 1]. */
    addi a4, sp, 0 /* ptr_yprime */
    /* Zeroize. */
    addi x4, x0, 31
    loop s6, 3
        loop s1, 1
            bn.sid x4, 0(a4++)
        nop
    /* Point to x[nshares // 2 + 1]. */
    addi a0, s0, 0
    loop s6, 1
        add a0, a0, s2
    addi a1, s1, 0
    addi a2, s2, 0
    addi a3, s7, 0
    /* a4 already points to yprime[nshares//2 + 1]. */
    jal  x1, seca2b_bc22

    /* Compute r = secadd_bc22(y, yprime, k, share stride, nshares). */
    addi a0, s5, 0 /* ptr_y */
    addi a1, s2, 0
    addi a2, sp, 0 /* ptr_yprime */
    addi a3, s2, 0
    addi a4, s3, 0 /* nshares */
    addi a5, s4, 0 /* ptr_r */
    addi a6, s2, 0
    addi a7, s1, 0 /* k */
    jal  x1, secadd_bc22
    beq  x0, x0, _end

_handle_one_share:
    /* a0 = ptr_x */
    /* a4 = ptr_r */
    loop a1, 3
        /* Whitening. */
        bn.xor w0, w0, w0
        bn.lid x0, 0(a0++)
        bn.sid x0, 0(a4++)

_end:
    /* Restore registers. */
    lw s0, 4(fp)
    lw s1, 8(fp)
    lw s2, 12(fp)
    lw s3, 16(fp)
    lw s4, 20(fp)
    lw s5, 24(fp)
    lw s6, 28(fp)
    lw s7, 32(fp)

    /* Restore sp and fp. */
    addi sp, fp, 0
    lw   fp, 0(sp)
    addi sp, sp, 64
    ret

#endif /* NSHARES == 2 */
