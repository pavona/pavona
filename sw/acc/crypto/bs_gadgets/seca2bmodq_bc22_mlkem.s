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

#define wx w0
#define wr w1
#define wcin w2
#define wcout w2
#define wa w3

/*
 * Name: seca2bmodq_bc22_mlkem (PINI)
 *
 * Return Boolean shares mod 2**k (k = 12) of a value x mod q = 3329 given its
 * arithmetic shares. (It is required that q < 2**k).
 * Bitsliced.
 *
 * Source: Alg.10 [BC22]
 *         [BC22]: "Bitslicing Arithmetic/Boolean Masking Conversions for Fun and Profit: with Application to Lattice-Based KEMs"
 *         Link: https://tches.iacr.org/index.php/TCHES/article/view/9831
 *
 * @param[in]  x10: dptr_xa, dmem pointer to the input arithmetic shares mod q of x
 * @param[in]  x11: nshares, the number of shares
 * @param[out] x12: dptr_rb, dmem pointer to the output Boolean shares
 *
 * clobbered registers: TODO
 * clobbered flag groups: TODO
 */
.globl seca2bmodq_bc22_mlkem
seca2bmodq_bc22_mlkem:
    /* Save fp to stack */
    addi sp, sp, -32
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

    /* Save input and output pointers. */
    addi s0, a0, 0
    addi s1, a1, 0
    addi s2, a2, 0

    /* Adjust sp to accommodate temporary values of recursive calls. */
    loop a1, 1
        addi sp, sp, -416
    addi s3, sp, 0 /* ptr_y, ptr_s, ptr_u */
    loop a1, 1
        addi sp, sp, -384
    addi s6, sp, 0 /* ptr_tmp */
    loop a1, 1
        addi sp, sp, -416 /* ptr_p, ptr_yprime, ptr_sprime, ptr_a */

    /* If nshares == 2, we handle it with specialized secadd_bc for one share.
     * And so there is no more recursive call. */
    addi x4, x0, 2
    beq  s1, x4, _handle_2shares

    /* Compute number of shares for each recursive call. */
    srli s4, s1, 1 /* s4 = nshares // 2 */
    sub  s5, s1, s4 /* s5 = nshares - (nshares // 2) */

    /* When s4 == 1, we compute x[0] + 2**(k + 1) - p with the special secadd
     * for one share. Then we extend the result to s1 shares. */
    addi x4, x0, 1
    bne  s4, x4, _handle_secaddnq_normal
    /* a0 already points to x. */
    addi t0, s3, 0 /* ptr_y */
    addi x4, x0, 1
    /* cin = 0 */
    bn.xor wcin, wcin, wcin

    /* Bit 0 -- 7: 1. */
    loopi 8, 9
        /* Whitening. */
        bn.xor wx, wx, wx
        bn.xor wr, wr, wr
        /* Compute r = x ^ p ^ cin. */
        bn.lid x0, 0(a0++)
        bn.not wa, wx /* a = x ^ p */
        bn.xor wr, wa, wcin /* r = a ^ cin */
        bn.sid x4, 0(t0++) /* Save r. */
        /* Compute cout = x ^ ((x ^ p) & (x ^ cin)) = x ^ (a & (x ^ cin)). */
        bn.xor wcout, wx, wcin /* cout = x ^ cin */
        bn.and wcout, wa, wcout /* cout &= a */
        bn.xor wcout, wcout, wx /* cout ^= x */

    /* Bit 8: 0. */
    /* Whitening. */
    bn.xor wx, wx, wx
    bn.xor wr, wr, wr
    /* Compute r = x ^ 0 ^ cin = x ^ cin. */
    bn.lid x0, 0(a0++)
    bn.xor wr, wx, wcin /* r = x ^ cin */
    bn.sid x4, 0(t0++) /* Save r. */
    /* Compute cout = x ^ ((x ^ p) & (x ^ cin)) = x ^ (x & r). */
    bn.and wcout, wx, wr /* cout = x & r */
    bn.xor wcout, wcout, wx /* cout ^= x */

    /* Bit 9: 1. */
    /* Whitening. */
    bn.xor wx, wx, wx
    bn.xor wr, wr, wr
    /* Compute r = x ^ p ^ cin. */
    bn.lid x0, 0(a0++)
    bn.not wa, wx /* a = x ^ p */
    bn.xor wr, wa, wcin /* r = a ^ cin */
    bn.sid x4, 0(t0++) /* Save r. */
    /* Compute cout = x ^ ((x ^ p) & (x ^ cin)) = x ^ (a & (x ^ cin)). */
    bn.xor wcout, wx, wcin /* cout = x ^ cin */
    bn.and wcout, wa, wcout /* cout &= a */
    bn.xor wcout, wcout, wx /* cout ^= x */

    /* Bit 10 -- 11: 0. */
    loopi 2, 7
        /* Whitening. */
        bn.xor wx, wx, wx
        bn.xor wr, wr, wr
        /* Compute r = x ^ 0 ^ cin = x ^ cin. */
        bn.lid x0, 0(a0++)
        bn.xor wr, wx, wcin /* r = x ^ cin */
        bn.sid x4, 0(t0++) /* Save r. */
        /* Compute cout = x ^ ((x ^ p) & (x ^ cin)) = x ^ (x & r). */
        bn.and wcout, wx, wr /* cout = x & r */
        bn.xor wcout, wcout, wx /* cout ^= x */

    /* Bit 12: 1. */
    /* Whitening. */
    bn.xor wr, wr, wr
    /* Compute r = x ^ p ^ cin = p ^ cin. (x only has k bits, while p has k + 1 bits). */
    bn.not wr, wcin /* r = p ^ cin */
    bn.sid x4, 0(t0++) /* Save r. */

    /* Extend the result to s1 shares. */
    bn.xor w0, w0, w0
    loop s5, 3
        loopi 13, 1
            bn.sid x0, 0(t0++)
        nop
    beq x0, x0, _handle_other_half

_handle_secaddnq_normal:
    /* Compute y = seca2bmodq_bc22_mlkem(x[0],...,x[nshares // 2], nshares // 2). */
    /* a0 = ptr_x */
    addi a1, s4, 0 /* nshares // 2 */
    addi a2, s6, 0 /* ptr_tmp */
    jal  x1, seca2bmodq_bc22_mlkem

    /* Initialize c = 0. */
    addi   t0, s3, 384 /* ptr_c */
    bn.xor w0, w0, w0
    loop   s4, 2
        bn.sid x0, 0(t0)
        addi   t0, t0, 416

    /* Compute p = 2**(k + 1) - q = 4863 = b1001011111111 and bitslice p. */
    addi    t0, sp, 0 /* ptr_p */
    bn.subi w1, w0, 1
    addi    x4, x0, 1
    bn.sid  x4, 0(t0++)
    addi    t1, s4, -1
    loop t1, 1
        bn.sid x0, 0(t0++)

    /* Compute s = secadd_bc22(p, y, k + 1, nshares // 2). */
    addi a0, sp, 0 /* ptr_p */
    addi a1, x0, 32
    addi a2, s6, 0 /* ptr_tmp */
    addi a3, x0, 384
    addi a4, s4, 0 /* nshares // 2 */
    addi a5, s3, 0 /* ptr_s */
    addi a6, x0, 416
    addi a7, s3, 384 /* cin */
    addi t4, x0, 416
    addi t5, s3, 384 /* cout */
    addi t6, x0, 416
    /* Bit 0 -- 7: p = 1. */
    loopi 8, 2
        jal  x1, secfulladder_bc22
        addi a0, a0, -32 /* Reset a0 to ptr_p. */

    /* Bit 8: p = 0. */
    bn.xor w0, w0, w0
    bn.sid x0, 0(a0)
    addi   a0, sp, 0
    jal    x1, secfulladder_bc22
    /* Bit 9: p = 1. */
    bn.xor  w0, w0, w0
    bn.subi w0, w0, 1
    addi    a0, sp, 0
    bn.sid  x0, 0(a0)
    jal     x1, secfulladder_bc22
    /* Bit 10 -- 11: p = 0. */
    bn.xor w0, w0, w0
    addi   a0, sp, 0
    bn.sid x0, 0(a0)
    jal    x1, secfulladder_bc22
    addi   a0, sp, 0
    jal    x1, secfulladder_bc22

    /* Bit 12: p = 1. */
    /* Compute r[12] = p[12] ^ y[12] ^ c = ~c since p[12] = 1 and y[12] = 0. */
    /* Whitening. */
    bn.xor w0, w0, w0
    bn.xor w1, w1, w1
    /* Computation. */
    bn.lid x0, 0(a7)
    bn.not w1, w0
    addi   x4, x0, 1
    bn.sid x4, 0(a7)

    /* Extend s to s1 shares. */
    addi t0, s3, 0
    loop s4, 1
        addi t0, t0, 416
    bn.xor w0, w0, w0
    loop s5, 3
        loopi 13, 1
            bn.sid x0, 0(t0++)
        nop

_handle_other_half:
    /* Compute yprime = seca2bmodq_bc22_mlkem(x[nshares // 2 + 1],...,x[nshares], nshares - nshares // 2). */
    addi a0, s0, 0 /* ptr_x */
    loop s4, 1
        addi a0, a0, 384 /* ptr_x[nshares // 2 + 1] */
    addi a1, s5, 0 /* nshares - nshares // 2 */
    addi a2, s6, 0 /* ptr_tmp */
    jal  x1, seca2bmodq_bc22_mlkem
    /* Clear yprime[0]...yprime[nshares // 2]. */
    bn.xor w0, w0, w0
    addi   t0, s6, 0 /* ptr_tmp */
    addi   t1, sp, 0 /* ptr_sprime */
    loop s4, 3
        loopi 13, 1
            bn.sid x0, 0(t1++)
        nop
    /* Extend yprime to sprime. */
    loop s5, 5
        loopi 12, 3
            bn.lid x0, 0(t0++)
            bn.sid x0, 0(t1++)
            /* Whitening. */
            bn.xor w0, w0, w0
        bn.sid x0, 0(t1++)

    /* Jump to common parts. */
    beq x0, x0, _handle_common

_handle_2shares:

    /* Compute s = secadd_bc22(p, x[0], nshares = 1, k + 1): specialized for one share.
     * With p = p = 2**(k + 1) - q = 4863 = b1001011111111. */
    addi t0, s3, 0 /* ptr_s */
    /* a0 already points to x[0]. */
    addi x4, x0, 1
    /* cin = 0 */
    bn.xor wcin, wcin, wcin

    /* Bit 0 -- 7: 1. */
    loopi 8, 9
        /* Whitening. */
        bn.xor wx, wx, wx
        bn.xor wr, wr, wr
        /* Compute r = x ^ p ^ cin. */
        bn.lid x0, 0(a0++)
        bn.not wa, wx /* a = x ^ p */
        bn.xor wr, wa, wcin /* r = a ^ cin */
        bn.sid x4, 0(t0++) /* Save r. */
        /* Compute cout = x ^ ((x ^ p) & (x ^ cin)) = x ^ (a & (x ^ cin)). */
        bn.xor wcout, wx, wcin /* cout = x ^ cin */
        bn.and wcout, wa, wcout /* cout &= a */
        bn.xor wcout, wcout, wx /* cout ^= x */

    /* Bit 8: 0. */
    /* Whitening. */
    bn.xor wx, wx, wx
    bn.xor wr, wr, wr
    /* Compute r = x ^ 0 ^ cin = x ^ cin. */
    bn.lid x0, 0(a0++)
    bn.xor wr, wx, wcin /* r = x ^ cin */
    bn.sid x4, 0(t0++) /* Save r. */
    /* Compute cout = x ^ ((x ^ p) & (x ^ cin)) = x ^ (x & r). */
    bn.and wcout, wx, wr /* cout = x & r */
    bn.xor wcout, wcout, wx /* cout ^= x */

    /* Bit 9: 1. */
    /* Whitening. */
    bn.xor wx, wx, wx
    bn.xor wr, wr, wr
    /* Compute r = x ^ p ^ cin. */
    bn.lid x0, 0(a0++)
    bn.not wa, wx /* a = x ^ p */
    bn.xor wr, wa, wcin /* r = a ^ cin */
    bn.sid x4, 0(t0++) /* Save r. */
    /* Compute cout = x ^ ((x ^ p) & (x ^ cin)) = x ^ (a & (x ^ cin)). */
    bn.xor wcout, wx, wcin /* cout = x ^ cin */
    bn.and wcout, wa, wcout /* cout &= a */
    bn.xor wcout, wcout, wx /* cout ^= x */

    /* Bit 10 -- 11: 0. */
    loopi 2, 7
        /* Whitening. */
        bn.xor wx, wx, wx
        bn.xor wr, wr, wr
        /* Compute r = x ^ 0 ^ cin = x ^ cin. */
        bn.lid x0, 0(a0++)
        bn.xor wr, wx, wcin /* r = x ^ cin */
        bn.sid x4, 0(t0++) /* Save r. */
        /* Compute cout = x ^ ((x ^ p) & (x ^ cin)) = x ^ (x & r). */
        bn.and wcout, wx, wr /* cout = x & r */
        bn.xor wcout, wcout, wx /* cout ^= x */

    /* Bit 12: 1. */
    /* Whitening. */
    bn.xor wr, wr, wr
    /* Compute r = x ^ p ^ cin = p ^ cin. (x only has k bits, while p has k + 1 bits). */
    bn.not wr, wcin /* r = p ^ cin */
    bn.sid x4, 0(t0++) /* Save r. */

    /* Extend s to 2 shares, i.e., clear next share of s. */
    bn.xor w0, w0, w0
    loopi 13, 1
        bn.sid x0, 0(t0++)

    /* Clear first share of sprime and copy x[1] to second share of sprime with
     * share stride = 416. */
    addi t0, sp, 0 /* ptr_sprime */
    loopi 13, 1
        bn.sid x0, 0(t0++)
    loopi 12, 3
        bn.lid x0, 0(a0++) /* a0 already points to x[1]. */
        bn.sid x0, 0(t0++)
        /* Whitening. */
        bn.xor w0, w0, w0
    bn.sid x0, 0(t0++)

_handle_common:
    /* Compute u = secadd_bc22(s, sprime, k + 1, nshares). */
    /* Initialize c = 0. */
    addi  t0, s6, 0 /* ptr_c = ptr_tmp */
    bn.xor w0, w0, w0
    loop s1, 1
        bn.sid x0, 0(t0++)

    addi a0, s3, 0 /* ptr_s */
    addi a1, x0, 416
    addi a2, sp, 0 /* ptr_sprime */
    addi a3, x0, 416
    addi a4, s1, 0 /* nshares */
    addi a5, s3, 0 /* ptr_u */
    addi a6, x0, 416
    addi a7, s6, 0 /* ptr_c */
    addi t4, x0, 32
    addi t5, s6, 0 /* ptr_c */
    addi t6, x0, 32
    loopi 12, 2
        jal x1, secfulladder_bc22
        nop
    /* Handle bit 12. */
    /* Compute r[12] = x[12] ^ y[12] ^ c. */
    addi x4, x0, 1
    addi t1, x0, 2
    addi t2, x0, 3
    loop a4, 14
        /* Whitening. */
        bn.xor w0, w0, w0
        bn.xor w1, w1, w1
        bn.xor w2, w2, w2
        bn.xor w3, w3, w3
        /* Computation. */
        bn.lid x0, 0(a0)
        bn.lid x4, 0(a2)
        bn.lid t1, 0(a7)
        bn.xor w3, w0, w1
        bn.xor w3, w3, w2
        bn.sid t2, 0(a5)
        /* Adjust addresses. */
        add    a0, a0, a1
        add    a2, a2, a3
        add    a7, a7, t4
        add    a5, a5, a6

    /* Compute a = bitcopymask_bc22_mlkem(u[k], (k + 1) * 32, nshares). */
    addi a0, s3, 384 /* ptr_u[k] */
    addi a1, x0, 416
    addi a2, s1, 0 /* nshares */
    addi a3, sp, 0 /* ptr_a */
    jal  x1, bitcopymask_bc22_mlkem

    /* Compute u = secadd_bc22(a, u, k, nshares). */
    /* Initialize c = 0. */
    addi  t0, s6, 0 /* ptr_c = ptr_tmp */
    bn.xor w0, w0, w0
    loop s1, 1
        bn.sid x0, 0(t0++)

    addi a0, sp, 0 /* ptr_a */
    addi a1, x0, 384
    addi a2, s3, 0 /* ptr_u */
    addi a3, x0, 416
    addi a4, s1, 0 /* nshares */
    addi a5, s2, 0 /* ptr_r */
    addi a6, x0, 384
    addi a7, s6, 0 /* ptr_c */
    addi t4, x0, 32
    addi t5, s6, 0 /* ptr_c */
    addi t6, x0, 32
    loopi 11, 2
        jal x1, secfulladder_bc22
        nop
    /* Handle bit 11. */
    /* Compute r[11] = x[11] ^ y[11] ^ c. */
    addi x4, x0, 1
    addi t1, x0, 2
    addi t2, x0, 3
    loop a4, 14
        /* Whitening. */
        bn.xor w0, w0, w0
        bn.xor w1, w1, w1
        bn.xor w2, w2, w2
        bn.xor w3, w3, w3
        /* Computation. */
        bn.lid x0, 0(a0)
        bn.lid x4, 0(a2)
        bn.lid t1, 0(a7)
        bn.xor w3, w0, w1
        bn.xor w3, w3, w2
        bn.sid t2, 0(a5)
        /* Adjust addresses. */
        add    a0, a0, a1
        add    a2, a2, a3
        add    a7, a7, t4
        add    a5, a5, a6

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
