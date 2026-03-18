/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

#define N_WDR 16 /* Number of WDRs to store N coeffs */

/* For NSHARES = 8, ALPHA = 15. So we assume that ALPHA is always 15. */
#define ALPHA 15
#define ALPHAm1 14
#define OFFSET_BIT_A 480 /* ALPHA * 32 */

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
 * Name: masked_poly_tomsg (NI)
 *
 * Return Boolean shares of Compressq(x, 1), given arithmetic shares
 * mod q of x.
 * (alternatively, this is also called masked one-bit compression.)
 * Bitsliced.
 *
 * Source: Alg.2 [CGMZ21b]
 *         [CGMZ21b]: "High-order Polynomial Comparison and Masking Lattice-based Encryption"
 *         Link: https://eprint.iacr.org/2021/1615
 *
 * Note: This algorithm is a generalization of the technique introduced in
 *       [FBR+21], which was for first-order only. To summarize, it includes (1)
 *       performing modulus switching from Q to 2**(d + a) for d is the
 *       compression factor and 2**a > Q * nshares, (2) converting to Boolean
 *       shares and (3) shift out a redundant bits.
 *       This technique is also used in [BC22] but with their bitsliced SecA2B
 *       (Alg.8). This implementation follows [BC22].
 *       [FBR+21]: "Masked Accelerators and Instruction Set Extensions for Post-Quantum Cryptography"
 *       Link: https://tches.iacr.org/index.php/TCHES/article/view/9303
 *       [BC22]: "Bitslicing Arithmetic/Boolean Masking Conversions for Fun and Profit: with Application to Lattice-Based KEMs"
 *       Link: https://tches.iacr.org/index.php/TCHES/article/view/9831
 *
 * @param[in]  x10: dptr_xb, dmem pointer to arithmetic shares of x
 * @param[in]  x11: nshares, the number of shares
 * @param[out] x12: dptr_rb, dmem pointer to the bitsliced compressed output
 *
 * clobbered registers: TODO
 * clobbered flag groups: TODO
 */

.globl masked_poly_tomsg
masked_poly_tomsg:
    /* Save fp to stack */
    addi sp, sp, -32
    sw   fp, 0(sp)
    addi fp, sp, 0

    /* Save registers. */
    sw   s0, 4(fp)
    sw   s1, 8(fp)
    addi s0, a1, 0
    addi s1, a2, 0

    /* Adjust space for temporary variable y.  */
    loop a1, 1
        addi sp, sp, -512 /* ptr_y */

    /* All-zero register. */
    bn.xor bn0, bn0, bn0

    /* Load all constants. */
    #define wm w1
    #define wq2 w2
    addi      x4, x0, 1
    la        t0, const_m_dv
    bn.lid    x4++, 0(t0)
    la        t0, modulus_over_2
    bn.lid    x4++, 0(t0)
    bn.shv.8s wq2, wq2 >> 16

    /* Create 1-bit mask and 2**(alpha - 1). */
    #define wpa w3
    #define wmask w4
    bn.subi    wmask, bn0, 1
    bn.shv.8s  wpa, wmask >> 31
    bn.shv.8s  wpa, wpa << ALPHAm1
    bn.shv.16h wmask, wmask >> 15

    #define wtmp w5
    #define wr w6

    #define wb1 w8
    #define wb2 w9
    #define wb3 w10
    #define wb4 w11
    #define wb5 w12
    #define wb6 w13
    #define wb7 w14
    #define wb8 w15
    #define wb9 w16
    #define wb10 w17
    #define wb11 w18
    #define wb12 w19
    #define wb13 w20
    #define wb14 w21
    #define wb15 w22
    #define wb16 w23

    /* In order to avoid division by Q, we need to compute:
     *  - x << (1 + ALPHA) --> x is 28 bits.
     *  - x += 1665
     *  - x *=m where m = ((1 << 37) + Q // 2) // Q = 41285357 (m is 26 bits).
     *  - x >>= k where k = 37.
     *  - x &= 1. */
    /* Compute y[0] = Compressq(x[0], dv + alpha) + 2**(alpha - 1). */
    addi t1, sp, 0 /* ptr_y */
    /* Clear the registers. */
    bn.xor wb1, wb1, wb1
    bn.xor wb2, wb2, wb2
    bn.xor wb3, wb3, wb3
    bn.xor wb4, wb4, wb4
    bn.xor wb5, wb5, wb5
    bn.xor wb6, wb6, wb6
    bn.xor wb7, wb7, wb7
    bn.xor wb8, wb8, wb8
    bn.xor wb9, wb9, wb9
    bn.xor wb10, wb10, wb10
    bn.xor wb11, wb11, wb11
    bn.xor wb12, wb12, wb12
    bn.xor wb13, wb13, wb13
    bn.xor wb14, wb14, wb14
    bn.xor wb15, wb15, wb15
    bn.xor wb16, wb16, wb16

    loopi N_WDR, 78
        bn.lid                   x0, 0(a0++)
        /* Handle even-positioned coeffs. */
        bn.trn1.16h              wtmp, w0, bn0
        bn.shv.8s                wtmp, wtmp << 16
        bn.addv.8s               wtmp, wtmp, wq2
        bn.mulv.8s.even.acc.z.hi wtmp, wtmp, wm
        bn.mulv.8s.odd.acc.z.hi  wtmp, wtmp, wm
        bn.shv.8s                wr, wtmp >> 5
        /* Handle odd-positioned coeffs. */
        bn.trn2.16h              wtmp, w0, bn0
        bn.shv.8s                wtmp, wtmp << 16
        bn.addv.8s               wtmp, wtmp, wq2
        bn.mulv.8s.even.acc.z.hi wtmp, wtmp, wm
        bn.mulv.8s.odd.acc.z.hi  wtmp, wtmp, wm
        bn.shv.8s                wtmp, wtmp >> 5
        /* Compute + 2**(alpha - 1) mod 2**(1 + alpha). */
        bn.addv.8s               wr, wr, wpa
        bn.addv.8s               wtmp, wtmp, wpa
        bn.trn1.16h              wr, wr, wtmp
        /* Prepare for other coeffs. */
        bn.shv.16h wb1, wb1 << 1
        bn.shv.16h wb2, wb2 << 1
        bn.shv.16h wb3, wb3 << 1
        bn.shv.16h wb4, wb4 << 1
        bn.shv.16h wb5, wb5 << 1
        bn.shv.16h wb6, wb6 << 1
        bn.shv.16h wb7, wb7 << 1
        bn.shv.16h wb8, wb8 << 1
        bn.shv.16h wb9, wb9 << 1
        bn.shv.16h wb10, wb10 << 1
        bn.shv.16h wb11, wb11 << 1
        bn.shv.16h wb12, wb12 << 1
        bn.shv.16h wb13, wb13 << 1
        bn.shv.16h wb14, wb14 << 1
        bn.shv.16h wb15, wb15 << 1
        bn.shv.16h wb16, wb16 << 1
        /* Transform wre to bitsliced representation. */
        bn.and     wtmp, wr, wmask
        bn.shv.16h wr, wr >> 1
        bn.xor     wb1, wb1, wtmp
        bn.and     wtmp, wr, wmask
        bn.shv.16h wr, wr >> 1
        bn.xor     wb2, wb2, wtmp
        bn.and     wtmp, wr, wmask
        bn.shv.16h wr, wr >> 1
        bn.xor     wb3, wb3, wtmp
        bn.and     wtmp, wr, wmask
        bn.shv.16h wr, wr >> 1
        bn.xor     wb4, wb4, wtmp
        bn.and     wtmp, wr, wmask
        bn.shv.16h wr, wr >> 1
        bn.xor     wb5, wb5, wtmp
        bn.and     wtmp, wr, wmask
        bn.shv.16h wr, wr >> 1
        bn.xor     wb6, wb6, wtmp
        bn.and     wtmp, wr, wmask
        bn.shv.16h wr, wr >> 1
        bn.xor     wb7, wb7, wtmp
        bn.and     wtmp, wr, wmask
        bn.shv.16h wr, wr >> 1
        bn.xor     wb8, wb8, wtmp
        bn.and     wtmp, wr, wmask
        bn.shv.16h wr, wr >> 1
        bn.xor     wb9, wb9, wtmp
        bn.and     wtmp, wr, wmask
        bn.shv.16h wr, wr >> 1
        bn.xor     wb10, wb10, wtmp
        bn.and     wtmp, wr, wmask
        bn.shv.16h wr, wr >> 1
        bn.xor     wb11, wb11, wtmp
        bn.and     wtmp, wr, wmask
        bn.shv.16h wr, wr >> 1
        bn.xor     wb12, wb12, wtmp
        bn.and     wtmp, wr, wmask
        bn.shv.16h wr, wr >> 1
        bn.xor     wb13, wb13, wtmp
        bn.and     wtmp, wr, wmask
        bn.shv.16h wr, wr >> 1
        bn.xor     wb14, wb14, wtmp
        bn.and     wtmp, wr, wmask
        bn.shv.16h wr, wr >> 1
        bn.xor     wb15, wb15, wtmp
        bn.xor     wb16, wb16, wr
    addi   x4, x0, 8
    bn.sid x4++, 0(t1)
    bn.sid x4++, 32(t1)
    bn.sid x4++, 64(t1)
    bn.sid x4++, 96(t1)
    bn.sid x4++, 128(t1)
    bn.sid x4++, 160(t1)
    bn.sid x4++, 192(t1)
    bn.sid x4++, 224(t1)
    bn.sid x4++, 256(t1)
    bn.sid x4++, 288(t1)
    bn.sid x4++, 320(t1)
    bn.sid x4++, 352(t1)
    bn.sid x4++, 384(t1)
    bn.sid x4++, 416(t1)
    bn.sid x4++, 448(t1)
    bn.sid x4++, 480(t1)
    /* Update output address. */
    addi t1, t1, 512

    /* Compute y[i] = Compressq(x[i], 1 + alpha) for i = 2,...,nshares. */
    addi t0, a1, -1 /* nshares - 1. */
    loop t0, 111
        /* Clear the registers. */
        bn.xor wb1, wb1, wb1
        bn.xor wb2, wb2, wb2
        bn.xor wb3, wb3, wb3
        bn.xor wb4, wb4, wb4
        bn.xor wb5, wb5, wb5
        bn.xor wb6, wb6, wb6
        bn.xor wb7, wb7, wb7
        bn.xor wb8, wb8, wb8
        bn.xor wb9, wb9, wb9
        bn.xor wb10, wb10, wb10
        bn.xor wb11, wb11, wb11
        bn.xor wb12, wb12, wb12
        bn.xor wb13, wb13, wb13
        bn.xor wb14, wb14, wb14
        bn.xor wb15, wb15, wb15
        bn.xor wb16, wb16, wb16
        loopi N_WDR, 76
            bn.lid                   x0, 0(a0++)
            /* Handle even-positioned coeffs. */
            bn.trn1.16h              wtmp, w0, bn0
            bn.shv.8s                wtmp, wtmp << 16
            bn.addv.8s               wtmp, wtmp, wq2
            bn.mulv.8s.even.acc.z.hi wtmp, wtmp, wm
            bn.mulv.8s.odd.acc.z.hi  wtmp, wtmp, wm
            bn.shv.8s                wr, wtmp >> 5
            /* Handle odd-positioned coeffs. */
            bn.trn2.16h              wtmp, w0, bn0
            bn.shv.8s                wtmp, wtmp << 16
            bn.addv.8s               wtmp, wtmp, wq2
            bn.mulv.8s.even.acc.z.hi wtmp, wtmp, wm
            bn.mulv.8s.odd.acc.z.hi  wtmp, wtmp, wm
            bn.shv.8s                wtmp, wtmp >> 5
            /* Combine the results. */
            bn.trn1.16h              wr, wr, wtmp
            /* Prepare for other coeffs. */
            bn.shv.16h wb1, wb1 << 1
            bn.shv.16h wb2, wb2 << 1
            bn.shv.16h wb3, wb3 << 1
            bn.shv.16h wb4, wb4 << 1
            bn.shv.16h wb5, wb5 << 1
            bn.shv.16h wb6, wb6 << 1
            bn.shv.16h wb7, wb7 << 1
            bn.shv.16h wb8, wb8 << 1
            bn.shv.16h wb9, wb9 << 1
            bn.shv.16h wb10, wb10 << 1
            bn.shv.16h wb11, wb11 << 1
            bn.shv.16h wb12, wb12 << 1
            bn.shv.16h wb13, wb13 << 1
            bn.shv.16h wb14, wb14 << 1
            bn.shv.16h wb15, wb15 << 1
            bn.shv.16h wb16, wb16 << 1
            /* Transform wre to bitsliced representation. */
            bn.and     wtmp, wr, wmask
            bn.shv.16h wr, wr >> 1
            bn.xor     wb1, wb1, wtmp
            bn.and     wtmp, wr, wmask
            bn.shv.16h wr, wr >> 1
            bn.xor     wb2, wb2, wtmp
            bn.and     wtmp, wr, wmask
            bn.shv.16h wr, wr >> 1
            bn.xor     wb3, wb3, wtmp
            bn.and     wtmp, wr, wmask
            bn.shv.16h wr, wr >> 1
            bn.xor     wb4, wb4, wtmp
            bn.and     wtmp, wr, wmask
            bn.shv.16h wr, wr >> 1
            bn.xor     wb5, wb5, wtmp
            bn.and     wtmp, wr, wmask
            bn.shv.16h wr, wr >> 1
            bn.xor     wb6, wb6, wtmp
            bn.and     wtmp, wr, wmask
            bn.shv.16h wr, wr >> 1
            bn.xor     wb7, wb7, wtmp
            bn.and     wtmp, wr, wmask
            bn.shv.16h wr, wr >> 1
            bn.xor     wb8, wb8, wtmp
            bn.and     wtmp, wr, wmask
            bn.shv.16h wr, wr >> 1
            bn.xor     wb9, wb9, wtmp
            bn.and     wtmp, wr, wmask
            bn.shv.16h wr, wr >> 1
            bn.xor     wb10, wb10, wtmp
            bn.and     wtmp, wr, wmask
            bn.shv.16h wr, wr >> 1
            bn.xor     wb11, wb11, wtmp
            bn.and     wtmp, wr, wmask
            bn.shv.16h wr, wr >> 1
            bn.xor     wb12, wb12, wtmp
            bn.and     wtmp, wr, wmask
            bn.shv.16h wr, wr >> 1
            bn.xor     wb13, wb13, wtmp
            bn.and     wtmp, wr, wmask
            bn.shv.16h wr, wr >> 1
            bn.xor     wb14, wb14, wtmp
            bn.and     wtmp, wr, wmask
            bn.shv.16h wr, wr >> 1
            bn.xor     wb15, wb15, wtmp
            bn.xor     wb16, wb16, wr
        addi   x4, x0, 8
        bn.sid x4++, 0(t1)
        bn.sid x4++, 32(t1)
        bn.sid x4++, 64(t1)
        bn.sid x4++, 96(t1)
        bn.sid x4++, 128(t1)
        bn.sid x4++, 160(t1)
        bn.sid x4++, 192(t1)
        bn.sid x4++, 224(t1)
        bn.sid x4++, 256(t1)
        bn.sid x4++, 288(t1)
        bn.sid x4++, 320(t1)
        bn.sid x4++, 352(t1)
        bn.sid x4++, 384(t1)
        bn.sid x4++, 416(t1)
        bn.sid x4++, 448(t1)
        bn.sid x4++, 480(t1)
        /* Update output address. */
        addi t1, t1, 512

    /* Compute z = seca2b_bc22(y, k = alpha + 1, share_str = k * 32, nshares). */
    addi a0, sp, 0 /* ptr_y */
    addi a1, x0, 16 /* alpha + 1 */
    addi a2, x0, 512
    addi a3, s0, 0 /* nshares */
    addi a4, sp, 0 /* ptr_z */
    jal  x1, seca2b_bc22

    /* Compute z >>= alpha, i.e., keep only the bits z[alpha]...z[alpha + 1]. */
    addi t0, sp, 0 /* ptr_z */
    addi t0, t0, OFFSET_BIT_A
    addi t1, s1, 0 /* ptr_r */
    loop s0, 5
        /* Whitening. */
        bn.xor w0, w0, w0
        bn.lid x0, 0(t0++)
        bn.sid x0, 0(t1++)
        /* After copy DV bits of z to r, we need to adjust address of z again. */
        add t0, t0, OFFSET_BIT_A

    /* Restore registers. */
    lw s0, 4(fp)
    lw s1, 8(fp)

    /* Restore sp and fp. */
    addi sp, fp, 0
    lw   fp, 0(sp)
    addi sp, sp, 32
    ret
