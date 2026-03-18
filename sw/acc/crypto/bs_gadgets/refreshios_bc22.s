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
 * Name: refreshios_bc22 (PINI)
 *
 * Return new Boolean shares of x mod 2^k, given old Boolean shares of x.
 * Bitsliced.
 *
 * Source: Alg.18 [BC22]
 *         [BC22]: "Bitslicing Arithmetic/Boolean Masking Conversions for Fun and Profit: with Application to Lattice-Based KEMs"
 *         Link: https://tches.iacr.org/index.php/TCHES/article/view/9831
 *
 * @param[in]  x10: dptr_x, dmem pointer to Boolean shares of x
 * @param[in]  x11: k, bitsize of x.
 * @param[in]  x12: share stride, distance between shares
 * @param[in]  x13: nshares, the number of shares
 * @param[out] x14: dptr_r, dmem pointer to the output Boolean shares of r
 *
 * clobbered registers: TODO
 * clobbered flag groups: TODO
 */
.globl refreshios_bc22
refreshios_bc22:
    addi x4, x0, 2
    beq  a3, x4, _handle_2shares
    addi x4, x0, 1
    beq  a3, x4, _handle_one_share

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

    /* Save input and output pointers. */
    addi s0, a0, 0
    addi s1, a3, 0
    addi s2, a4, 0

    /* Adjust sp to accommodate temporary values of recursive calls. */
    loop a3, 1
        sub sp, sp, a2 /* ptr_tmp */

    /* Compute number of shares for each recursive call. */
    srli s3, s1, 1 /* s3 = nshares // 2 */
    sub  s4, s1, s3 /* s4 = nshares - (nshares // 2) */

    /* Compute z = refreshios_bc22(x[0...nshares // 2]). */
    /* a0 = ptr_x */
    /* a1 is already k. */
    /* a2 is already share stride. */
    addi a3, s3, 0 /* nshares // 2 */
    addi a4, sp, 0 /* ptr_tmp */
    jal  x1, refreshios_bc22

    /* Compute z = refreshios_bc22(x[nshares // 2 + 1...nshares]). */
    addi a0, s0, 0 /* ptr_x */
    addi a4, sp, 0 /* ptr_tmp */
    loop s3, 2
        add a0, a0, a2
        add a4, a4, a2
    /* a1 is already k. */
    /* a2 is already share stride. */
    addi a3, s4, 0 /* nshares - nshares // 2 */
    jal x1, refreshios_bc22

    /* Compute zi ^= ri and z_(nshares//2)+i ^= ri for i = 0,...,nshares // 2. */
    addi t0, sp, 0 /* ptr_tmp */
    addi t1, sp, 0 /* ptr_tmp */
    addi t2, s2, 0 /* ptr_r */
    addi t3, s2, 0 /* ptr_r */
    loop s3, 2
        add t1, t1, a2
        add t3, t3, a2

    addi x4, x0, 1
    loop s3, 13
        loop a1, 11
            bn.wsrr w2, urnd
            /* Whitening. */
            bn.xor  w0, w0, w0
            bn.xor  w1, w1, w1
            bn.lid  x0, 0(t0++)
            bn.xor  w1, w0, w2
            bn.sid  x4, 0(t2++)
            /* Whitening. */
            bn.xor  w0, w0, w0
            bn.xor  w1, w1, w1
            bn.lid  x0, 0(t1++)
            bn.xor  w1, w0, w2
            bn.sid  x4, 0(t3++)
        nop

    andi t0, s1, 1
    bne  t0, x4, _end
    loop a1, 3
        /* Whitening. */
        bn.xor w0, w0, w0
        bn.lid x0, 0(t1++)
        bn.sid x0, 0(t3++)
_end:
    /* Restore registers. */
    lw s0, 4(fp)
    lw s1, 8(fp)
    lw s2, 12(fp)
    lw s3, 16(fp)
    lw s4, 20(fp)

    /* Restore sp and fp. */
    addi sp, fp, 0
    lw   fp, 0(sp)
    addi sp, sp, 32
    ret

_handle_one_share:
    loop a1, 3
        /* Whitening. */
        bn.xor w0, w0, w0
        bn.lid x0, 0(a0++)
        bn.sid x0, 0(a4++)
    ret

_handle_2shares:
    add  t0, a0, a2 /* point to 2nd share */
    add  t1, a4, a2 /* point to 2nd share */
    addi x4, x0, 1
    loop a1, 11
        bn.wsrr w2, urnd
        /* Whitening. */
        bn.xor  w0, w0, w0
        bn.xor  w1, w1, w1
        bn.lid  x0, 0(a0++)
        bn.xor  w1, w0, w2
        bn.sid  x4, 0(a4++)
        /* Whitening. */
        bn.xor  w0, w0, w0
        bn.xor  w1, w1, w1
        bn.lid  x0, 0(t0++)
        bn.xor  w1, w0, w2
        bn.sid  x4, 0(t1++)
    ret
