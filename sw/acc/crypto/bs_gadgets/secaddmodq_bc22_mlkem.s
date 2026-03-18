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
 * Name: secaddmodq_bc22_mlkem (PINI)
 *
 * Return k-bit Boolean shares of (x + y) mod q, given k-bit Boolean shares of x
 * and y (0 < x, y < q), where q = 3329.
 * Bitsliced.
 *
 * Source: Alg.7 in [BC22]
 *         [BC22]: "Bitslicing Arithmetic/Boolean Masking Conversions for Fun and Profit: with Application to Lattice-Based KEMs"
 *         Link: https://tches.iacr.org/index.php/TCHES/article/view/9831
 *
 * @param[in]  x10: dptr_x, dmem pointer to Boolean shares of x
 * @param[in]  x11: dptr_y, dmem pointer to Boolean shares of y
 * @param[in]  x12: nshares, the number of shares
 * @param[out] x13: dptr_r, dmem pointer to the output Boolean shares of r
 *
 * clobbered registers: x2 to x18, x28 to x31, w0 to w8, w31
 * clobbered flag groups: FG0
 */
.globl secaddmodq_bc22_mlkem
secaddmodq_bc22_mlkem:
    /* Save fp to stack */
    addi sp, sp, -32
    sw   fp, 0(sp)
    addi fp, sp, 0

    /* Save registers. */
    sw s0, 4(fp)
    sw s1, 8(fp)
    sw s2, 12(fp)

    /* Save input and output pointers. */
    addi s0, a2, 0
    addi s1, a3, 0

    /* Adjust stack for temporary variables. */
    loop a2, 3
        loopi 13, 1
            addi sp, sp, -32
        nop
    addi s2, sp, 0 /* ptr_s, ptr_sprime */
    loop a2, 3
        loopi 13, 1
            addi sp, sp, -32 /* ptr_p, ptr_a */
        nop

    /* All-zero register. */
    bn.xor bn0, bn0, bn0

    /* Compute s = secadd_bc22(x, y, k + 1, nshares). */
    /* Since x and y are k-bit Boolean shares, we need to copy them to space
     * for k+1-bit Boolean shares before performing secadd_bc22 on (k + 1) bits. */
    addi t0, s2, 0 /* ptr_s */
    addi t1, sp, 0 /* ptr_p */
    addi x4, x0, 31
    loop a2, 7
        loopi 12, 4
            bn.lid x0, 0(a0++)
            bn.sid x0, 0(t0++)
            bn.lid x0, 0(a1++)
            bn.sid x0, 0(t1++)
        /* Clear bit k. */
        bn.sid x4, 0(t0++)
        bn.sid x4, 0(t1++)

    addi a0, s2, 0 /* ptr_s */
    addi a1, x0, 416
    addi a2, sp, 0 /* ptr_p */
    addi a3, x0, 416
    addi a4, s0, 0 /* nshares */
    addi a5, s2, 0 /* ptr_s */
    addi a6, x0, 416
    addi a7, x0, 13 /* k + 1 */
    jal  x1, secadd_bc22

    /* Compute p = 2**(k + 1) - q = 4863 = b1001011111111 and bitslice p. */
    addi    t0, sp, 0 /* ptr_p */
    addi    x4, x0, 31
    bn.subi w0, bn0, 1
    loopi 8, 1
        bn.sid x0, 0(t0++) /* bit 0 -- 7. */
    bn.sid x4, 0(t0++) /* bit 8. */
    bn.sid x0, 0(t0++) /* bit 9. */
    bn.sid x4, 0(t0++) /* bit 10. */
    bn.sid x4, 0(t0++) /* bit 11. */
    bn.sid x0, 0(t0++) /* bit 12. */
    /* Clear the rest of p. */
    addi t1, s0, -1 /* nshares - 1 */
    loop t1, 3
        loopi 13, 1
            bn.sid x4, 0(t0++)
        nop
    /* Compute sprime = secadd_bc22(s, p, k + 1, nshares). */
    addi a0, s2, 0 /* ptr_s */
    addi a1, x0, 416
    addi a2, sp, 0 /* ptr_p */
    addi a3, x0, 416
    addi a4, s0, 0 /* nshares */
    addi a5, s2, 0 /* ptr_sprime */
    addi a6, x0, 416
    addi a7, x0, 13 /* k + 1 */
    jal  x1, secadd_bc22

    /* Compute a = bitcopymask_bc22_mlkem(sprime[k], (k + 1) * 32, nshares). */
    addi a0, s2, 384 /* ptr_sprime[k] */
    addi a1, x0, 416 /* share_str = (k + 1) * 32 */
    addi a2, s0, 0 /* nshares */
    addi a3, sp, 0 /* ptr_a */
    jal  x1, bitcopymask_bc22_mlkem

    /* Compute r = secadd_bc22(a, sprime, k, nshares). */
    addi a0, sp, 0 /* ptr_a */
    addi a1, x0, 384
    addi a2, s2, 0 /* ptr_sprime */
    addi a3, x0, 416
    addi a4, s0, 0 /* nshares */
    addi a5, s1, 0 /* ptr_r */
    addi a6, x0, 384
    addi a7, x0, 12 /* k */
    jal  x1, secadd_bc22

    /* Restore registers. */
    lw s0, 4(fp)
    lw s1, 8(fp)
    lw s2, 12(fp)

    /* Restore sp and fp. */
    addi sp, fp, 0
    lw   fp, 0(sp)
    addi sp, sp, 32
    ret
