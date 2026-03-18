/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

#define N_WDR 16 /* Number of WDRs to store N coeffs */

#if NSHARES == 2
    /* For NSHARES = 8, ALPHA = 15. So we assume that ALPHA is always 15. */
    #define ALPHA 13
    #define ALPHAm1 12
    #define OFFSET_BIT_A 416 /* ALPHA * 32 */
#else
    /* For NSHARES = 8, ALPHA = 15. So we assume that ALPHA is always 15. */
    #define ALPHA 15
    #define ALPHAm1 14
    #define OFFSET_BIT_A 480 /* ALPHA * 32 */
#endif

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
 * Name: poly_hocompress_cgmz21b (NI)
 *
 * Return Boolean shares of Compressq(x, d) when d = {4,5}, given arithmetic shares
 * mod q of x.
 * (alternatively, this is also called masked ciphertext compression.)
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
 * @param[in]  x10: dptr_xb, dmem pointer to the input arithmetic shares of x
 * @param[in]  x11: nshares, the number of shares
 * @param[out] x12: dptr_rb, dmem pointer to the bitsliced compressed output
 * @param[in]  x13: k, the security level
 *
 * clobbered registers: TODO
 * clobbered flag groups: TODO
 */

.globl poly_hocompress_cgmz21b
poly_hocompress_cgmz21b:
    /* Save fp to stack */
    addi sp, sp, -32
    sw   fp, 0(sp)
    addi fp, sp, 0

    /* Save registers. */
    sw   s0, 4(fp)
    sw   s1, 8(fp)
    sw   s2, 12(fp)
    sw   s3, 16(fp)
    addi s0, a1, 0
    addi s1, a2, 0

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
    bn.subi   wmask, bn0, 1
    bn.shv.8s wmask, wmask >> 31
    bn.shv.8s wpa, wmask << ALPHAm1

    #define wtmp w5
    #define wre w6
    #define wro w7

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
    #define wb17 w24
    #define wb18 w25
    #define wb19 w26
    #define wb20 w27

#if NSHARES == 2

    /* For DV in {4,5}, in order to avoid division by Q, we need to compute:
     *  - x << (DV + ALPHA) --> x is maximum 20 bits.
     *  - x += 1665
     *  - x *=m where m = ((1 << 37) + Q // 2) // Q = 41285357 (m is 26 bits).
     *  - x >>= k where k = 37.
     *  - x &= ((1 << DV) - 1). */
    /* Compute y[0] = Compressq(x[0], dv + alpha) + 2**(alpha - 1). */
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
    bn.xor wb17, wb17, wb17

    addi x4, x0, 4
    bne  a3, x4, _handle_kn4_dv
_handle_k4_dv:
    /* Adjust space for temporary variable y.  */
    loop a1, 1
        addi sp, sp, -576
    addi t1, sp, 0 /* ptr_y */

    bn.xor wb18, wb18, wb18
    loopi N_WDR, 141
        bn.lid                   x0, 0(a0++)
        /* Handle even-positioned coeffs. */
        bn.trn1.16h              wtmp, w0, bn0
        bn.shv.8s                wtmp, wtmp << 18
        bn.addv.8s               wtmp, wtmp, wq2
        bn.mulv.8s.even.acc.z.hi wtmp, wtmp, wm
        bn.mulv.8s.odd.acc.z.hi  wtmp, wtmp, wm
        bn.shv.8s                wre, wtmp >> 5
        /* Handle odd-positioned coeffs. */
        bn.trn2.16h              wtmp, w0, bn0
        bn.shv.8s                wtmp, wtmp << 18
        bn.addv.8s               wtmp, wtmp, wq2
        bn.mulv.8s.even.acc.z.hi wtmp, wtmp, wm
        bn.mulv.8s.odd.acc.z.hi  wtmp, wtmp, wm
        bn.shv.8s                wro, wtmp >> 5
        /* Compute + 2**(alpha - 1) mod 2**(dv + alpha). */
        bn.addv.8s               wre, wre, wpa
        bn.addv.8s               wro, wro, wpa
        /* Prepare for other coeffs. */
        bn.shv.8s wb1, wb1 << 1
        bn.shv.8s wb2, wb2 << 1
        bn.shv.8s wb3, wb3 << 1
        bn.shv.8s wb4, wb4 << 1
        bn.shv.8s wb5, wb5 << 1
        bn.shv.8s wb6, wb6 << 1
        bn.shv.8s wb7, wb7 << 1
        bn.shv.8s wb8, wb8 << 1
        bn.shv.8s wb9, wb9 << 1
        bn.shv.8s wb10, wb10 << 1
        bn.shv.8s wb11, wb11 << 1
        bn.shv.8s wb12, wb12 << 1
        bn.shv.8s wb13, wb13 << 1
        bn.shv.8s wb14, wb14 << 1
        bn.shv.8s wb15, wb15 << 1
        bn.shv.8s wb16, wb16 << 1
        bn.shv.8s wb17, wb17 << 1
        bn.shv.8s wb18, wb18 << 1
        /* Transform wre to bitsliced representation. */
        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb1, wb1, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb1, wb1, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb2, wb2, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb2, wb2, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb3, wb3, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb3, wb3, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb4, wb4, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb4, wb4, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb5, wb5, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb5, wb5, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb6, wb6, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb6, wb6, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb7, wb7, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb7, wb7, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb8, wb8, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb8, wb8, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb9, wb9, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb9, wb9, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb10, wb10, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb10, wb10, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb11, wb11, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb11, wb11, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb12, wb12, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb12, wb12, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb13, wb13, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb13, wb13, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb14, wb14, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb14, wb14, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb15, wb15, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb15, wb15, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb16, wb16, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb16, wb16, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb17, wb17, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb17, wb17, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb18, wb18, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb18, wb18, wtmp << 16

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
    bn.sid x4++, 512(t1)
    bn.sid x4++, 544(t1)
    /* Update output address. */
    addi t1, t1, 576

    /* Compute y[i] = Compressq(x[i], d + alpha) for i = 2,...,nshares. */
    addi t0, a1, -1 /* nshares - 1. */
    loop t0, 178
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
        bn.xor wb17, wb17, wb17
        bn.xor wb18, wb18, wb18

        loopi N_WDR, 139
            bn.lid                   x0, 0(a0++)
            /* Handle even-positioned coeffs. */
            bn.trn1.16h              wtmp, w0, bn0
            bn.shv.8s                wtmp, wtmp << 18
            bn.addv.8s               wtmp, wtmp, wq2
            bn.mulv.8s.even.acc.z.hi wtmp, wtmp, wm
            bn.mulv.8s.odd.acc.z.hi  wtmp, wtmp, wm
            bn.shv.8s                wre, wtmp >> 5
            /* Handle odd-positioned coeffs. */
            bn.trn2.16h              wtmp, w0, bn0
            bn.shv.8s                wtmp, wtmp << 18
            bn.addv.8s               wtmp, wtmp, wq2
            bn.mulv.8s.even.acc.z.hi wtmp, wtmp, wm
            bn.mulv.8s.odd.acc.z.hi  wtmp, wtmp, wm
            bn.shv.8s                wro, wtmp >> 5
            /* Prepare for other coeffs. */
            bn.shv.8s wb1, wb1 << 1
            bn.shv.8s wb2, wb2 << 1
            bn.shv.8s wb3, wb3 << 1
            bn.shv.8s wb4, wb4 << 1
            bn.shv.8s wb5, wb5 << 1
            bn.shv.8s wb6, wb6 << 1
            bn.shv.8s wb7, wb7 << 1
            bn.shv.8s wb8, wb8 << 1
            bn.shv.8s wb9, wb9 << 1
            bn.shv.8s wb10, wb10 << 1
            bn.shv.8s wb11, wb11 << 1
            bn.shv.8s wb12, wb12 << 1
            bn.shv.8s wb13, wb13 << 1
            bn.shv.8s wb14, wb14 << 1
            bn.shv.8s wb15, wb15 << 1
            bn.shv.8s wb16, wb16 << 1
            bn.shv.8s wb17, wb17 << 1
            bn.shv.8s wb18, wb18 << 1
            /* Transform wre to bitsliced representation. */
            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb1, wb1, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb1, wb1, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb2, wb2, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb2, wb2, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb3, wb3, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb3, wb3, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb4, wb4, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb4, wb4, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb5, wb5, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb5, wb5, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb6, wb6, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb6, wb6, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb7, wb7, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb7, wb7, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb8, wb8, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb8, wb8, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb9, wb9, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb9, wb9, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb10, wb10, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb10, wb10, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb11, wb11, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb11, wb11, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb12, wb12, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb12, wb12, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb13, wb13, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb13, wb13, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb14, wb14, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb14, wb14, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb15, wb15, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb15, wb15, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb16, wb16, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb16, wb16, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb17, wb17, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb17, wb17, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb18, wb18, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb18, wb18, wtmp << 16

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
        bn.sid x4++, 512(t1)
        bn.sid x4++, 544(t1)
        /* Update output address. */
        addi t1, t1, 576

    /* Compute z = seca2b_bc22(y, k = VA, share_str = k * 32, nshares). */
    addi a0, sp, 0 /* ptr_y */
    addi a1, x0, 18 /* dv + alpha */
    addi a2, x0, 576
    addi a3, s0, 0 /* nshares */
    addi a4, sp, 0 /* ptr_z */
    jal  x1, seca2b_bc22

    /* Compute z >>= alpha, i.e., keep only the bits z[alpha]...z[alpha + dv]. */
    addi t0, sp, 0 /* ptr_z */
    addi t0, t0, OFFSET_BIT_A
    addi t1, s1, 0 /* ptr_r */
    loop s0, 5
        loopi 5, 3
            /* Whitening. */
            bn.xor w0, w0, w0
            bn.lid x0, 0(t0++)
            bn.sid x0, 0(t1++)
        /* After copy DV bits of z to r, we need to adjust address of z again. */
        add t0, t0, OFFSET_BIT_A

    beq x0, x0, _handle_common_dv

_handle_kn4_dv:
    /* Adjust space for temporary variable y.  */
    loop a1, 1
        addi sp, sp, -544
    addi t1, sp, 0 /* ptr_y */

    loopi N_WDR, 134
        bn.lid                   x0, 0(a0++)
        /* Handle even-positioned coeffs. */
        bn.trn1.16h              wtmp, w0, bn0
        bn.shv.8s                wtmp, wtmp << 17
        bn.addv.8s               wtmp, wtmp, wq2
        bn.mulv.8s.even.acc.z.hi wtmp, wtmp, wm
        bn.mulv.8s.odd.acc.z.hi  wtmp, wtmp, wm
        bn.shv.8s                wre, wtmp >> 5
        /* Handle odd-positioned coeffs. */
        bn.trn2.16h              wtmp, w0, bn0
        bn.shv.8s                wtmp, wtmp << 17
        bn.addv.8s               wtmp, wtmp, wq2
        bn.mulv.8s.even.acc.z.hi wtmp, wtmp, wm
        bn.mulv.8s.odd.acc.z.hi  wtmp, wtmp, wm
        bn.shv.8s                wro, wtmp >> 5
        /* Compute + 2**(alpha - 1) mod 2**(dv + alpha). */
        bn.addv.8s               wre, wre, wpa
        bn.addv.8s               wro, wro, wpa
        /* Prepare for other coeffs. */
        bn.shv.8s wb1, wb1 << 1
        bn.shv.8s wb2, wb2 << 1
        bn.shv.8s wb3, wb3 << 1
        bn.shv.8s wb4, wb4 << 1
        bn.shv.8s wb5, wb5 << 1
        bn.shv.8s wb6, wb6 << 1
        bn.shv.8s wb7, wb7 << 1
        bn.shv.8s wb8, wb8 << 1
        bn.shv.8s wb9, wb9 << 1
        bn.shv.8s wb10, wb10 << 1
        bn.shv.8s wb11, wb11 << 1
        bn.shv.8s wb12, wb12 << 1
        bn.shv.8s wb13, wb13 << 1
        bn.shv.8s wb14, wb14 << 1
        bn.shv.8s wb15, wb15 << 1
        bn.shv.8s wb16, wb16 << 1
        bn.shv.8s wb17, wb17 << 1
        /* Transform wre to bitsliced representation. */
        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb1, wb1, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb1, wb1, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb2, wb2, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb2, wb2, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb3, wb3, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb3, wb3, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb4, wb4, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb4, wb4, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb5, wb5, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb5, wb5, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb6, wb6, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb6, wb6, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb7, wb7, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb7, wb7, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb8, wb8, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb8, wb8, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb9, wb9, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb9, wb9, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb10, wb10, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb10, wb10, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb11, wb11, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb11, wb11, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb12, wb12, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb12, wb12, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb13, wb13, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb13, wb13, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb14, wb14, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb14, wb14, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb15, wb15, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb15, wb15, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb16, wb16, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb16, wb16, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb17, wb17, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb17, wb17, wtmp << 16

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
    bn.sid x4++, 512(t1)
    /* Update output address. */
    addi t1, t1, 544

    /* Compute y[i] = Compressq(x[i], d + alpha) for i = 2,...,nshares. */
    addi t0, a1, -1 /* nshares - 1. */
    loop t0, 169
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
        bn.xor wb17, wb17, wb17

        loopi N_WDR, 132
            bn.lid                   x0, 0(a0++)
            /* Handle even-positioned coeffs. */
            bn.trn1.16h              wtmp, w0, bn0
            bn.shv.8s                wtmp, wtmp << 17
            bn.addv.8s               wtmp, wtmp, wq2
            bn.mulv.8s.even.acc.z.hi wtmp, wtmp, wm
            bn.mulv.8s.odd.acc.z.hi  wtmp, wtmp, wm
            bn.shv.8s                wre, wtmp >> 5
            /* Handle odd-positioned coeffs. */
            bn.trn2.16h              wtmp, w0, bn0
            bn.shv.8s                wtmp, wtmp << 17
            bn.addv.8s               wtmp, wtmp, wq2
            bn.mulv.8s.even.acc.z.hi wtmp, wtmp, wm
            bn.mulv.8s.odd.acc.z.hi  wtmp, wtmp, wm
            bn.shv.8s                wro, wtmp >> 5
            /* Prepare for other coeffs. */
            bn.shv.8s wb1, wb1 << 1
            bn.shv.8s wb2, wb2 << 1
            bn.shv.8s wb3, wb3 << 1
            bn.shv.8s wb4, wb4 << 1
            bn.shv.8s wb5, wb5 << 1
            bn.shv.8s wb6, wb6 << 1
            bn.shv.8s wb7, wb7 << 1
            bn.shv.8s wb8, wb8 << 1
            bn.shv.8s wb9, wb9 << 1
            bn.shv.8s wb10, wb10 << 1
            bn.shv.8s wb11, wb11 << 1
            bn.shv.8s wb12, wb12 << 1
            bn.shv.8s wb13, wb13 << 1
            bn.shv.8s wb14, wb14 << 1
            bn.shv.8s wb15, wb15 << 1
            bn.shv.8s wb16, wb16 << 1
            bn.shv.8s wb17, wb17 << 1
            /* Transform wre to bitsliced representation. */
            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb1, wb1, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb1, wb1, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb2, wb2, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb2, wb2, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb3, wb3, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb3, wb3, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb4, wb4, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb4, wb4, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb5, wb5, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb5, wb5, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb6, wb6, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb6, wb6, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb7, wb7, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb7, wb7, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb8, wb8, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb8, wb8, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb9, wb9, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb9, wb9, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb10, wb10, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb10, wb10, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb11, wb11, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb11, wb11, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb12, wb12, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb12, wb12, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb13, wb13, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb13, wb13, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb14, wb14, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb14, wb14, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb15, wb15, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb15, wb15, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb16, wb16, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb16, wb16, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb17, wb17, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb17, wb17, wtmp << 16

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
        bn.sid x4++, 512(t1)
        /* Update output address. */
        addi t1, t1, 544

    /* Compute z = seca2b_bc22(y, k = VA, share_str = k * 32, nshares). */
    addi a0, sp, 0 /* ptr_y */
    addi a1, x0, 17 /* dv + alpha */
    addi a2, x0, 544
    addi a3, s0, 0 /* nshares */
    addi a4, sp, 0 /* ptr_z */
    jal  x1, seca2b_bc22

    /* Compute z >>= alpha, i.e., keep only the bits z[alpha]...z[alpha + dv]. */
    addi t0, sp, 0 /* ptr_z */
    addi t0, t0, OFFSET_BIT_A
    addi t1, s1, 0 /* ptr_r */
    loop s0, 5
        loopi 4, 3
            /* Whitening. */
            bn.xor w0, w0, w0
            bn.lid x0, 0(t0++)
            bn.sid x0, 0(t1++)
        /* After copy DV bits of z to r, we need to adjust address of z again. */
        add t0, t0, OFFSET_BIT_A

#else

    /* For DV in {4,5}, in order to avoid division by Q, we need to compute:
     *  - x << (DV + ALPHA) --> x is maximum 20 bits.
     *  - x += 1665
     *  - x *=m where m = ((1 << 37) + Q // 2) // Q = 41285357 (m is 26 bits).
     *  - x >>= k where k = 37.
     *  - x &= ((1 << DV) - 1). */
    /* Compute y[0] = Compressq(x[0], dv + alpha) + 2**(alpha - 1). */
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
    bn.xor wb17, wb17, wb17
    bn.xor wb18, wb18, wb18
    bn.xor wb19, wb19, wb19

    addi x4, x0, 4
    bne  a3, x4, _handle_kn4_dv
_handle_k4_dv:
    /* Adjust space for temporary variable y.  */
    loop a1, 1
        addi sp, sp, -640
    addi t1, sp, 0 /* ptr_y */

    bn.xor wb20, wb20, wb20
    loopi N_WDR, 155
        bn.lid                   x0, 0(a0++)
        /* Handle even-positioned coeffs. */
        bn.trn1.16h              wtmp, w0, bn0
        bn.shv.8s                wtmp, wtmp << 20
        bn.addv.8s               wtmp, wtmp, wq2
        bn.mulv.8s.even.acc.z.hi wtmp, wtmp, wm
        bn.mulv.8s.odd.acc.z.hi  wtmp, wtmp, wm
        bn.shv.8s                wre, wtmp >> 5
        /* Handle odd-positioned coeffs. */
        bn.trn2.16h              wtmp, w0, bn0
        bn.shv.8s                wtmp, wtmp << 20
        bn.addv.8s               wtmp, wtmp, wq2
        bn.mulv.8s.even.acc.z.hi wtmp, wtmp, wm
        bn.mulv.8s.odd.acc.z.hi  wtmp, wtmp, wm
        bn.shv.8s                wro, wtmp >> 5
        /* Compute + 2**(alpha - 1) mod 2**(dv + alpha). */
        bn.addv.8s               wre, wre, wpa
        bn.addv.8s               wro, wro, wpa
        /* Prepare for other coeffs. */
        bn.shv.8s wb1, wb1 << 1
        bn.shv.8s wb2, wb2 << 1
        bn.shv.8s wb3, wb3 << 1
        bn.shv.8s wb4, wb4 << 1
        bn.shv.8s wb5, wb5 << 1
        bn.shv.8s wb6, wb6 << 1
        bn.shv.8s wb7, wb7 << 1
        bn.shv.8s wb8, wb8 << 1
        bn.shv.8s wb9, wb9 << 1
        bn.shv.8s wb10, wb10 << 1
        bn.shv.8s wb11, wb11 << 1
        bn.shv.8s wb12, wb12 << 1
        bn.shv.8s wb13, wb13 << 1
        bn.shv.8s wb14, wb14 << 1
        bn.shv.8s wb15, wb15 << 1
        bn.shv.8s wb16, wb16 << 1
        bn.shv.8s wb17, wb17 << 1
        bn.shv.8s wb18, wb18 << 1
        bn.shv.8s wb19, wb19 << 1
        bn.shv.8s wb20, wb20 << 1
        /* Transform wre to bitsliced representation. */
        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb1, wb1, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb1, wb1, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb2, wb2, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb2, wb2, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb3, wb3, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb3, wb3, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb4, wb4, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb4, wb4, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb5, wb5, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb5, wb5, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb6, wb6, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb6, wb6, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb7, wb7, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb7, wb7, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb8, wb8, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb8, wb8, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb9, wb9, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb9, wb9, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb10, wb10, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb10, wb10, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb11, wb11, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb11, wb11, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb12, wb12, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb12, wb12, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb13, wb13, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb13, wb13, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb14, wb14, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb14, wb14, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb15, wb15, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb15, wb15, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb16, wb16, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb16, wb16, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb17, wb17, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb17, wb17, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb18, wb18, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb18, wb18, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb19, wb19, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb19, wb19, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb20, wb20, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb20, wb20, wtmp << 16
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
    bn.sid x4++, 512(t1)
    bn.sid x4++, 544(t1)
    bn.sid x4++, 576(t1)
    bn.sid x4++, 608(t1)
    /* Update output address. */
    addi t1, t1, 640

    /* Compute y[i] = Compressq(x[i], d + alpha) for i = 2,...,nshares. */
    addi t0, a1, -1 /* nshares - 1. */
    loop t0, 196
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
        bn.xor wb17, wb17, wb17
        bn.xor wb18, wb18, wb18
        bn.xor wb19, wb19, wb19
        bn.xor wb20, wb20, wb20

        loopi N_WDR, 153
            bn.lid                   x0, 0(a0++)
            /* Handle even-positioned coeffs. */
            bn.trn1.16h              wtmp, w0, bn0
            bn.shv.8s                wtmp, wtmp << 20
            bn.addv.8s               wtmp, wtmp, wq2
            bn.mulv.8s.even.acc.z.hi wtmp, wtmp, wm
            bn.mulv.8s.odd.acc.z.hi  wtmp, wtmp, wm
            bn.shv.8s                wre, wtmp >> 5
            /* Handle odd-positioned coeffs. */
            bn.trn2.16h              wtmp, w0, bn0
            bn.shv.8s                wtmp, wtmp << 20
            bn.addv.8s               wtmp, wtmp, wq2
            bn.mulv.8s.even.acc.z.hi wtmp, wtmp, wm
            bn.mulv.8s.odd.acc.z.hi  wtmp, wtmp, wm
            bn.shv.8s                wro, wtmp >> 5
            /* Prepare for other coeffs. */
            bn.shv.8s wb1, wb1 << 1
            bn.shv.8s wb2, wb2 << 1
            bn.shv.8s wb3, wb3 << 1
            bn.shv.8s wb4, wb4 << 1
            bn.shv.8s wb5, wb5 << 1
            bn.shv.8s wb6, wb6 << 1
            bn.shv.8s wb7, wb7 << 1
            bn.shv.8s wb8, wb8 << 1
            bn.shv.8s wb9, wb9 << 1
            bn.shv.8s wb10, wb10 << 1
            bn.shv.8s wb11, wb11 << 1
            bn.shv.8s wb12, wb12 << 1
            bn.shv.8s wb13, wb13 << 1
            bn.shv.8s wb14, wb14 << 1
            bn.shv.8s wb15, wb15 << 1
            bn.shv.8s wb16, wb16 << 1
            bn.shv.8s wb17, wb17 << 1
            bn.shv.8s wb18, wb18 << 1
            bn.shv.8s wb19, wb19 << 1
            bn.shv.8s wb20, wb20 << 1
            /* Transform wre to bitsliced representation. */
            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb1, wb1, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb1, wb1, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb2, wb2, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb2, wb2, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb3, wb3, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb3, wb3, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb4, wb4, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb4, wb4, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb5, wb5, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb5, wb5, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb6, wb6, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb6, wb6, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb7, wb7, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb7, wb7, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb8, wb8, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb8, wb8, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb9, wb9, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb9, wb9, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb10, wb10, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb10, wb10, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb11, wb11, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb11, wb11, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb12, wb12, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb12, wb12, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb13, wb13, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb13, wb13, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb14, wb14, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb14, wb14, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb15, wb15, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb15, wb15, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb16, wb16, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb16, wb16, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb17, wb17, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb17, wb17, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb18, wb18, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb18, wb18, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb19, wb19, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb19, wb19, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb20, wb20, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb20, wb20, wtmp << 16
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
        bn.sid x4++, 512(t1)
        bn.sid x4++, 544(t1)
        bn.sid x4++, 576(t1)
        bn.sid x4++, 608(t1)
        /* Update output address. */
        addi t1, t1, 640

    /* Compute z = seca2b_bc22(y, k = VA, share_str = k * 32, nshares). */
    addi a0, sp, 0 /* ptr_y */
    addi a1, x0, 20 /* dv + alpha */
    addi a2, x0, 640
    addi a3, s0, 0 /* nshares */
    addi a4, sp, 0 /* ptr_z */
    jal  x1, seca2b_bc22

    /* Compute z >>= alpha, i.e., keep only the bits z[alpha]...z[alpha + dv]. */
    addi t0, sp, 0 /* ptr_z */
    addi t0, t0, OFFSET_BIT_A
    addi t1, s1, 0 /* ptr_r */
    loop s0, 5
        loopi 5, 3
            /* Whitening. */
            bn.xor w0, w0, w0
            bn.lid x0, 0(t0++)
            bn.sid x0, 0(t1++)
        /* After copy DV bits of z to r, we need to adjust address of z again. */
        add t0, t0, OFFSET_BIT_A

    beq x0, x0, _handle_common_dv

_handle_kn4_dv:
    /* Adjust space for temporary variable y.  */
    loop a1, 1
        addi sp, sp, -608
    addi t1, sp, 0 /* ptr_y */

    loopi N_WDR, 148
        bn.lid                   x0, 0(a0++)
        /* Handle even-positioned coeffs. */
        bn.trn1.16h              wtmp, w0, bn0
        bn.shv.8s                wtmp, wtmp << 19
        bn.addv.8s               wtmp, wtmp, wq2
        bn.mulv.8s.even.acc.z.hi wtmp, wtmp, wm
        bn.mulv.8s.odd.acc.z.hi  wtmp, wtmp, wm
        bn.shv.8s                wre, wtmp >> 5
        /* Handle odd-positioned coeffs. */
        bn.trn2.16h              wtmp, w0, bn0
        bn.shv.8s                wtmp, wtmp << 19
        bn.addv.8s               wtmp, wtmp, wq2
        bn.mulv.8s.even.acc.z.hi wtmp, wtmp, wm
        bn.mulv.8s.odd.acc.z.hi  wtmp, wtmp, wm
        bn.shv.8s                wro, wtmp >> 5
        /* Compute + 2**(alpha - 1) mod 2**(dv + alpha). */
        bn.addv.8s               wre, wre, wpa
        bn.addv.8s               wro, wro, wpa
        /* Prepare for other coeffs. */
        bn.shv.8s wb1, wb1 << 1
        bn.shv.8s wb2, wb2 << 1
        bn.shv.8s wb3, wb3 << 1
        bn.shv.8s wb4, wb4 << 1
        bn.shv.8s wb5, wb5 << 1
        bn.shv.8s wb6, wb6 << 1
        bn.shv.8s wb7, wb7 << 1
        bn.shv.8s wb8, wb8 << 1
        bn.shv.8s wb9, wb9 << 1
        bn.shv.8s wb10, wb10 << 1
        bn.shv.8s wb11, wb11 << 1
        bn.shv.8s wb12, wb12 << 1
        bn.shv.8s wb13, wb13 << 1
        bn.shv.8s wb14, wb14 << 1
        bn.shv.8s wb15, wb15 << 1
        bn.shv.8s wb16, wb16 << 1
        bn.shv.8s wb17, wb17 << 1
        bn.shv.8s wb18, wb18 << 1
        bn.shv.8s wb19, wb19 << 1
        /* Transform wre to bitsliced representation. */
        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb1, wb1, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb1, wb1, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb2, wb2, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb2, wb2, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb3, wb3, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb3, wb3, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb4, wb4, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb4, wb4, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb5, wb5, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb5, wb5, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb6, wb6, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb6, wb6, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb7, wb7, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb7, wb7, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb8, wb8, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb8, wb8, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb9, wb9, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb9, wb9, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb10, wb10, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb10, wb10, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb11, wb11, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb11, wb11, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb12, wb12, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb12, wb12, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb13, wb13, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb13, wb13, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb14, wb14, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb14, wb14, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb15, wb15, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb15, wb15, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb16, wb16, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb16, wb16, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb17, wb17, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb17, wb17, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb18, wb18, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb18, wb18, wtmp << 16

        bn.and    wtmp, wre, wmask
        bn.shv.8s wre, wre >> 1
        bn.xor    wb19, wb19, wtmp
        bn.and    wtmp, wro, wmask
        bn.shv.8s wro, wro >> 1
        bn.xor    wb19, wb19, wtmp << 16

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
    bn.sid x4++, 512(t1)
    bn.sid x4++, 544(t1)
    bn.sid x4++, 576(t1)
    /* Update output address. */
    addi t1, t1, 608

    /* Compute y[i] = Compressq(x[i], d + alpha) for i = 2,...,nshares. */
    addi t0, a1, -1 /* nshares - 1. */
    loop t0, 187
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
        bn.xor wb17, wb17, wb17
        bn.xor wb18, wb18, wb18
        bn.xor wb19, wb19, wb19

        loopi N_WDR, 146
            bn.lid                   x0, 0(a0++)
            /* Handle even-positioned coeffs. */
            bn.trn1.16h              wtmp, w0, bn0
            bn.shv.8s                wtmp, wtmp << 19
            bn.addv.8s               wtmp, wtmp, wq2
            bn.mulv.8s.even.acc.z.hi wtmp, wtmp, wm
            bn.mulv.8s.odd.acc.z.hi  wtmp, wtmp, wm
            bn.shv.8s                wre, wtmp >> 5
            /* Handle odd-positioned coeffs. */
            bn.trn2.16h              wtmp, w0, bn0
            bn.shv.8s                wtmp, wtmp << 19
            bn.addv.8s               wtmp, wtmp, wq2
            bn.mulv.8s.even.acc.z.hi wtmp, wtmp, wm
            bn.mulv.8s.odd.acc.z.hi  wtmp, wtmp, wm
            bn.shv.8s                wro, wtmp >> 5
            /* Prepare for other coeffs. */
            bn.shv.8s wb1, wb1 << 1
            bn.shv.8s wb2, wb2 << 1
            bn.shv.8s wb3, wb3 << 1
            bn.shv.8s wb4, wb4 << 1
            bn.shv.8s wb5, wb5 << 1
            bn.shv.8s wb6, wb6 << 1
            bn.shv.8s wb7, wb7 << 1
            bn.shv.8s wb8, wb8 << 1
            bn.shv.8s wb9, wb9 << 1
            bn.shv.8s wb10, wb10 << 1
            bn.shv.8s wb11, wb11 << 1
            bn.shv.8s wb12, wb12 << 1
            bn.shv.8s wb13, wb13 << 1
            bn.shv.8s wb14, wb14 << 1
            bn.shv.8s wb15, wb15 << 1
            bn.shv.8s wb16, wb16 << 1
            bn.shv.8s wb17, wb17 << 1
            bn.shv.8s wb18, wb18 << 1
            bn.shv.8s wb19, wb19 << 1
            /* Transform wre to bitsliced representation. */
            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb1, wb1, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb1, wb1, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb2, wb2, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb2, wb2, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb3, wb3, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb3, wb3, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb4, wb4, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb4, wb4, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb5, wb5, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb5, wb5, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb6, wb6, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb6, wb6, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb7, wb7, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb7, wb7, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb8, wb8, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb8, wb8, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb9, wb9, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb9, wb9, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb10, wb10, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb10, wb10, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb11, wb11, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb11, wb11, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb12, wb12, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb12, wb12, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb13, wb13, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb13, wb13, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb14, wb14, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb14, wb14, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb15, wb15, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb15, wb15, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb16, wb16, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb16, wb16, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb17, wb17, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb17, wb17, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb18, wb18, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb18, wb18, wtmp << 16

            bn.and    wtmp, wre, wmask
            bn.shv.8s wre, wre >> 1
            bn.xor    wb19, wb19, wtmp
            bn.and    wtmp, wro, wmask
            bn.shv.8s wro, wro >> 1
            bn.xor    wb19, wb19, wtmp << 16

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
        bn.sid x4++, 512(t1)
        bn.sid x4++, 544(t1)
        bn.sid x4++, 576(t1)
        /* Update output address. */
        addi t1, t1, 608

    /* Compute z = seca2b_bc22(y, k = VA, share_str = k * 32, nshares). */
    addi a0, sp, 0 /* ptr_y */
    addi a1, x0, 19 /* dv + alpha */
    addi a2, x0, 608
    addi a3, s0, 0 /* nshares */
    addi a4, sp, 0 /* ptr_z */
    jal  x1, seca2b_bc22

    /* Compute z >>= alpha, i.e., keep only the bits z[alpha]...z[alpha + dv]. */
    addi t0, sp, 0 /* ptr_z */
    addi t0, t0, OFFSET_BIT_A
    addi t1, s1, 0 /* ptr_r */
    loop s0, 5
        loopi 4, 3
            /* Whitening. */
            bn.xor w0, w0, w0
            bn.lid x0, 0(t0++)
            bn.sid x0, 0(t1++)
        /* After copy DV bits of z to r, we need to adjust address of z again. */
        add t0, t0, OFFSET_BIT_A

#endif /* NSHARES == 2 */

_handle_common_dv:
    /* Restore registers. */
    lw s0, 4(fp)
    lw s1, 8(fp)
    lw s2, 12(fp)

    /* Restore sp and fp. */
    addi sp, fp, 0
    lw   fp, 0(sp)
    addi sp, sp, 32
    ret

/*
 * Name: poly_polyvec_hocompress_cgmz21b (NI)
 *
 * Return Boolean shares of Compressq(x, d) when d = {10,11}, given arithmetic shares
 * mod q of x.
 * (alternatively, this is also called masked ciphertext compression.)
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
 * @param[in]  x10: dptr_xb, dmem pointer to the input arithmetic shares of x
 * @param[in]  x11: nshares, the number of shares
 * @param[out] x12: dptr_rb, dmem pointer to the bitsliced compressed output
 * @param[in]  x13: k, the security level
 *
 * clobbered registers: TODO
 * clobbered flag groups: TODO
 */
.globl poly_polyvec_hocompress_cgmz21b
poly_polyvec_hocompress_cgmz21b:
#if NSHARES == 2
    /* Save fp to stack */
    addi sp, sp, -32
    sw   fp, 0(sp)
    addi fp, sp, 0

    /* Save registers. */
    sw   s0, 4(fp)
    sw   s1, 8(fp)
    sw   s2, 12(fp)
    addi s0, a1, 0
    addi s1, a2, 0

    /* Load all constants. */
    #define wm w1
    addi       x4, x0, 1
    la         t0, const_m_du
    bn.lid     x4++, 0(t0)

    #define wq2_du w2
    la     t0, const_1664
    bn.lid x4, 0(t0)
    #define wmask_du w30
    #define wpa_du_k4 w30
    bn.xor    bn0, bn0, bn0
    bn.subi   wmask_du, bn0, 1
    bn.shv.8s wmask_du, wmask_du >> 31

    #define wtmp0_du w3
    #define wtmp1_du w4
    #define wtmp2_du w5

    #define wb1_du w6
    #define wb2_du w7
    #define wb3_du w8
    #define wb4_du w9
    #define wb5_du w10
    #define wb6_du w11
    #define wb7_du w12
    #define wb8_du w13
    #define wb9_du w14
    #define wb10_du w15
    #define wb11_du w16
    #define wb12_du w17
    #define wb13_du w18
    #define wb14_du w19
    #define wb15_du w20
    #define wb16_du w21
    #define wb17_du w22
    #define wb18_du w23
    #define wb19_du w24
    #define wb20_du w25
    #define wb21_du w26
    #define wb22_du w27
    #define wb23_du w28
    #define wb24_du w29
    /* Clear the registers. */
    bn.xor wb1_du, wb1_du, wb1_du
    bn.xor wb2_du, wb2_du, wb2_du
    bn.xor wb3_du, wb3_du, wb3_du
    bn.xor wb4_du, wb4_du, wb4_du
    bn.xor wb5_du, wb5_du, wb5_du
    bn.xor wb6_du, wb6_du, wb6_du
    bn.xor wb7_du, wb7_du, wb7_du
    bn.xor wb8_du, wb8_du, wb8_du
    bn.xor wb9_du, wb9_du, wb9_du
    bn.xor wb10_du, wb10_du, wb10_du
    bn.xor wb11_du, wb11_du, wb11_du
    bn.xor wb12_du, wb12_du, wb12_du
    bn.xor wb13_du, wb13_du, wb13_du
    bn.xor wb14_du, wb14_du, wb14_du
    bn.xor wb15_du, wb15_du, wb15_du
    bn.xor wb16_du, wb16_du, wb16_du
    bn.xor wb17_du, wb17_du, wb17_du
    bn.xor wb18_du, wb18_du, wb18_du
    bn.xor wb19_du, wb19_du, wb19_du
    bn.xor wb20_du, wb20_du, wb20_du
    bn.xor wb21_du, wb21_du, wb21_du
    bn.xor wb22_du, wb22_du, wb22_du
    bn.xor wb23_du, wb23_du, wb23_du
    bn.xor wb24_du, wb24_du, wb24_du

    addi x4, x0, 4
    bne  a3, x4, _handle_kn4_du

_handle_k4_du:
    /* Adjust space for temporary variable y. */
    loop a1, 1
        addi sp, sp, -768
    addi t1, sp, 0 /* ptr_y */

    loopi N_WDR, 209
        bn.lid           x0, 0(a0++)
        /* Handle even-positioned coeffs. */
        bn.trn1.16h      wtmp0_du, w0, bn0
        /* Handle coeff[0] - coeff[4] - coeff[8] - coeff[12]. */
        bn.trn1.8s      wtmp1_du, wtmp0_du, bn0
        bn.rshi         wtmp1_du, wtmp1_du, bn0 >> 232
        bn.add          wtmp1_du, wtmp1_du, wq2_du
        bn.mulqacc.so.z wtmp2_du.l, wtmp1_du.0, wm.0, 0
        bn.mulqacc.so.z wtmp2_du.u, wtmp1_du.2, wm.0, 0
        bn.mulqacc.so.z wtmp1_du.l, wtmp1_du.1, wm.0, 0
        bn.mulqacc.so.z wtmp1_du.u, wtmp1_du.3, wm.0, 0
        bn.trn2.4d      wtmp1_du, wtmp2_du, wtmp1_du
        /* Handle coeff[2] - coeff[6] - coeff[10] - coeff[14]. */
        bn.trn2.8s      wtmp0_du, wtmp0_du, bn0
        bn.rshi         wtmp0_du, wtmp0_du, bn0 >> 232
        bn.add          wtmp0_du, wtmp0_du, wq2_du
        bn.mulqacc.so.z wtmp2_du.l, wtmp0_du.0, wm.0, 0
        bn.mulqacc.so.z wtmp2_du.u, wtmp0_du.2, wm.0, 0
        bn.mulqacc.so.z wtmp0_du.l, wtmp0_du.1, wm.0, 0
        bn.mulqacc.so.z wtmp0_du.u, wtmp0_du.3, wm.0, 0
        bn.trn2.4d      wtmp0_du, wtmp2_du, wtmp0_du
        /* Combine the result. */
        bn.trn1.8s      wtmp0_du, wtmp1_du, wtmp0_du

        /* Handle odd-positioned coeffs. */
        bn.trn2.16h     w0, w0, bn0
        /* Handle coeff[1] - coeff[5] - coeff[9] - coeff[13]. */
        bn.trn1.8s      wtmp1_du, w0, bn0
        bn.rshi         wtmp1_du, wtmp1_du, bn0 >> 232
        bn.add          wtmp1_du, wtmp1_du, wq2_du
        bn.mulqacc.so.z wtmp2_du.l, wtmp1_du.0, wm.0, 0
        bn.mulqacc.so.z wtmp2_du.u, wtmp1_du.2, wm.0, 0
        bn.mulqacc.so.z wtmp1_du.l, wtmp1_du.1, wm.0, 0
        bn.mulqacc.so.z wtmp1_du.u, wtmp1_du.3, wm.0, 0
        bn.trn2.4d      wtmp1_du, wtmp2_du, wtmp1_du
        /* Handle coeff[3] - coeff[7] - coeff[11] - coeff[15]. */
        bn.trn2.8s      w0, w0, bn0
        bn.rshi         w0, w0, bn0 >> 232
        bn.add          w0, w0, wq2_du
        bn.mulqacc.so.z wtmp2_du.l, w0.0, wm.0, 0
        bn.mulqacc.so.z wtmp2_du.u, w0.2, wm.0, 0
        bn.mulqacc.so.z w0.l, w0.1, wm.0, 0
        bn.mulqacc.so.z w0.u, w0.3, wm.0, 0
        bn.trn2.4d      w0, wtmp2_du, w0
        /* Combine the result. */
        bn.trn1.8s      wtmp1_du, wtmp1_du, w0
        /* Compute + 2**(alpha - 1) mod 2**(du + alpha). */
        bn.shv.8s       wpa_du_k4, wpa_du_k4 << ALPHAm1
        bn.addv.8s      wtmp0_du, wtmp0_du, wpa_du_k4
        bn.addv.8s      wtmp1_du, wtmp1_du, wpa_du_k4
        bn.shv.8s       wmask_du, wpa_du_k4 >> ALPHAm1
        /* Bitslicing. */
        bn.shv.8s wb1_du, wb1_du << 1
        bn.shv.8s wb2_du, wb2_du << 1
        bn.shv.8s wb3_du, wb3_du << 1
        bn.shv.8s wb4_du, wb4_du << 1
        bn.shv.8s wb5_du, wb5_du << 1
        bn.shv.8s wb6_du, wb6_du << 1
        bn.shv.8s wb7_du, wb7_du << 1
        bn.shv.8s wb8_du, wb8_du << 1
        bn.shv.8s wb9_du, wb9_du << 1
        bn.shv.8s wb10_du, wb10_du << 1
        bn.shv.8s wb11_du, wb11_du << 1
        bn.shv.8s wb12_du, wb12_du << 1
        bn.shv.8s wb13_du, wb13_du << 1
        bn.shv.8s wb14_du, wb14_du << 1
        bn.shv.8s wb15_du, wb15_du << 1
        bn.shv.8s wb16_du, wb16_du << 1
        bn.shv.8s wb17_du, wb17_du << 1
        bn.shv.8s wb18_du, wb18_du << 1
        bn.shv.8s wb19_du, wb19_du << 1
        bn.shv.8s wb20_du, wb20_du << 1
        bn.shv.8s wb21_du, wb21_du << 1
        bn.shv.8s wb22_du, wb22_du << 1
        bn.shv.8s wb23_du, wb23_du << 1
        bn.shv.8s wb24_du, wb24_du << 1

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb1_du, wb1_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb1_du, wb1_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb2_du, wb2_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb2_du, wb2_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb3_du, wb3_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb3_du, wb3_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb4_du, wb4_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb4_du, wb4_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb5_du, wb5_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb5_du, wb5_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb6_du, wb6_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb6_du, wb6_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb7_du, wb7_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb7_du, wb7_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb8_du, wb8_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb8_du, wb8_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb9_du, wb9_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb9_du, wb9_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb10_du, wb10_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb10_du, wb10_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb11_du, wb11_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb11_du, wb11_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb12_du, wb12_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb12_du, wb12_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb13_du, wb13_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb13_du, wb13_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb14_du, wb14_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb14_du, wb14_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb15_du, wb15_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb15_du, wb15_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb16_du, wb16_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb16_du, wb16_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb17_du, wb17_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb17_du, wb17_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb18_du, wb18_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb18_du, wb18_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb19_du, wb19_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb19_du, wb19_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb20_du, wb20_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb20_du, wb20_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb21_du, wb21_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb21_du, wb21_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb22_du, wb22_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb22_du, wb22_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb23_du, wb23_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb23_du, wb23_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb24_du, wb24_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb24_du, wb24_du, wtmp2_du << 16

    addi   x4, x0, 6
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
    bn.sid x4++, 512(t1)
    bn.sid x4++, 544(t1)
    bn.sid x4++, 576(t1)
    bn.sid x4++, 608(t1)
    bn.sid x4++, 640(t1)
    bn.sid x4++, 672(t1)
    bn.sid x4++, 704(t1)
    bn.sid x4++, 736(t1)
    /* Update output address. */
    addi t1, t1, 768

    /* Compute y[i] = Compressq(x[i], d + alpha) for i = 2,...,nshares. */
    addi t0, a1, -1 /* nshares - 1. */
    loop t0, 256
        /* Clear the registers. */
        bn.xor wb1_du, wb1_du, wb1_du
        bn.xor wb2_du, wb2_du, wb2_du
        bn.xor wb3_du, wb3_du, wb3_du
        bn.xor wb4_du, wb4_du, wb4_du
        bn.xor wb5_du, wb5_du, wb5_du
        bn.xor wb6_du, wb6_du, wb6_du
        bn.xor wb7_du, wb7_du, wb7_du
        bn.xor wb8_du, wb8_du, wb8_du
        bn.xor wb9_du, wb9_du, wb9_du
        bn.xor wb10_du, wb10_du, wb10_du
        bn.xor wb11_du, wb11_du, wb11_du
        bn.xor wb12_du, wb12_du, wb12_du
        bn.xor wb13_du, wb13_du, wb13_du
        bn.xor wb14_du, wb14_du, wb14_du
        bn.xor wb15_du, wb15_du, wb15_du
        bn.xor wb16_du, wb16_du, wb16_du
        bn.xor wb17_du, wb17_du, wb17_du
        bn.xor wb18_du, wb18_du, wb18_du
        bn.xor wb19_du, wb19_du, wb19_du
        bn.xor wb20_du, wb20_du, wb20_du
        bn.xor wb21_du, wb21_du, wb21_du
        bn.xor wb22_du, wb22_du, wb22_du
        bn.xor wb23_du, wb23_du, wb23_du
        bn.xor wb24_du, wb24_du, wb24_du

        loopi N_WDR, 205
            bn.lid          x0, 0(a0++)
            /* Handle even-positioned coeffs. */
            bn.trn1.16h     wtmp0_du, w0, bn0
            /* Handle coeff[0] - coeff[4] - coeff[8] - coeff[12]. */
            bn.trn1.8s      wtmp1_du, wtmp0_du, bn0
            bn.rshi         wtmp1_du, wtmp1_du, bn0 >> 232
            bn.add          wtmp1_du, wtmp1_du, wq2_du
            bn.mulqacc.so.z wtmp2_du.l, wtmp1_du.0, wm.0, 0
            bn.mulqacc.so.z wtmp2_du.u, wtmp1_du.2, wm.0, 0
            bn.mulqacc.so.z wtmp1_du.l, wtmp1_du.1, wm.0, 0
            bn.mulqacc.so.z wtmp1_du.u, wtmp1_du.3, wm.0, 0
            bn.trn2.4d      wtmp1_du, wtmp2_du, wtmp1_du
            /* Handle coeff[2] - coeff[6] - coeff[10] - coeff[14]. */
            bn.trn2.8s      wtmp0_du, wtmp0_du, bn0
            bn.rshi         wtmp0_du, wtmp0_du, bn0 >> 232
            bn.add          wtmp0_du, wtmp0_du, wq2_du
            bn.mulqacc.so.z wtmp2_du.l, wtmp0_du.0, wm.0, 0
            bn.mulqacc.so.z wtmp2_du.u, wtmp0_du.2, wm.0, 0
            bn.mulqacc.so.z wtmp0_du.l, wtmp0_du.1, wm.0, 0
            bn.mulqacc.so.z wtmp0_du.u, wtmp0_du.3, wm.0, 0
            bn.trn2.4d      wtmp0_du, wtmp2_du, wtmp0_du
            /* Combine the result. */
            bn.trn1.8s      wtmp0_du, wtmp1_du, wtmp0_du

            /* Handle odd-positioned coeffs. */
            bn.trn2.16h     w0, w0, bn0
            /* Handle coeff[1] - coeff[5] - coeff[9] - coeff[13]. */
            bn.trn1.8s      wtmp1_du, w0, bn0
            bn.rshi         wtmp1_du, wtmp1_du, bn0 >> 232
            bn.add          wtmp1_du, wtmp1_du, wq2_du
            bn.mulqacc.so.z wtmp2_du.l, wtmp1_du.0, wm.0, 0
            bn.mulqacc.so.z wtmp2_du.u, wtmp1_du.2, wm.0, 0
            bn.mulqacc.so.z wtmp1_du.l, wtmp1_du.1, wm.0, 0
            bn.mulqacc.so.z wtmp1_du.u, wtmp1_du.3, wm.0, 0
            bn.trn2.4d      wtmp1_du, wtmp2_du, wtmp1_du
            /* Handle coeff[3] - coeff[7] - coeff[11] - coeff[15]. */
            bn.trn2.8s      w0, w0, bn0
            bn.rshi         w0, w0, bn0 >> 232
            bn.add          w0, w0, wq2_du
            bn.mulqacc.so.z wtmp2_du.l, w0.0, wm.0, 0
            bn.mulqacc.so.z wtmp2_du.u, w0.2, wm.0, 0
            bn.mulqacc.so.z w0.l, w0.1, wm.0, 0
            bn.mulqacc.so.z w0.u, w0.3, wm.0, 0
            bn.trn2.4d      w0, wtmp2_du, w0
            /* Combine the result. */
            bn.trn1.8s      wtmp1_du, wtmp1_du, w0
            /* Bitslicing. */
            bn.shv.8s wb1_du, wb1_du << 1
            bn.shv.8s wb2_du, wb2_du << 1
            bn.shv.8s wb3_du, wb3_du << 1
            bn.shv.8s wb4_du, wb4_du << 1
            bn.shv.8s wb5_du, wb5_du << 1
            bn.shv.8s wb6_du, wb6_du << 1
            bn.shv.8s wb7_du, wb7_du << 1
            bn.shv.8s wb8_du, wb8_du << 1
            bn.shv.8s wb9_du, wb9_du << 1
            bn.shv.8s wb10_du, wb10_du << 1
            bn.shv.8s wb11_du, wb11_du << 1
            bn.shv.8s wb12_du, wb12_du << 1
            bn.shv.8s wb13_du, wb13_du << 1
            bn.shv.8s wb14_du, wb14_du << 1
            bn.shv.8s wb15_du, wb15_du << 1
            bn.shv.8s wb16_du, wb16_du << 1
            bn.shv.8s wb17_du, wb17_du << 1
            bn.shv.8s wb18_du, wb18_du << 1
            bn.shv.8s wb19_du, wb19_du << 1
            bn.shv.8s wb20_du, wb20_du << 1
            bn.shv.8s wb21_du, wb21_du << 1
            bn.shv.8s wb22_du, wb22_du << 1
            bn.shv.8s wb23_du, wb23_du << 1
            bn.shv.8s wb24_du, wb24_du << 1

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb1_du, wb1_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb1_du, wb1_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb2_du, wb2_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb2_du, wb2_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb3_du, wb3_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb3_du, wb3_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb4_du, wb4_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb4_du, wb4_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb5_du, wb5_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb5_du, wb5_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb6_du, wb6_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb6_du, wb6_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb7_du, wb7_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb7_du, wb7_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb8_du, wb8_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb8_du, wb8_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb9_du, wb9_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb9_du, wb9_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb10_du, wb10_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb10_du, wb10_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb11_du, wb11_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb11_du, wb11_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb12_du, wb12_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb12_du, wb12_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb13_du, wb13_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb13_du, wb13_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb14_du, wb14_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb14_du, wb14_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb15_du, wb15_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb15_du, wb15_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb16_du, wb16_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb16_du, wb16_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb17_du, wb17_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb17_du, wb17_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb18_du, wb18_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb18_du, wb18_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb19_du, wb19_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb19_du, wb19_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb20_du, wb20_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb20_du, wb20_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb21_du, wb21_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb21_du, wb21_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb22_du, wb22_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb22_du, wb22_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb23_du, wb23_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb23_du, wb23_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb24_du, wb24_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb24_du, wb24_du, wtmp2_du << 16

        addi   x4, x0, 6
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
        bn.sid x4++, 512(t1)
        bn.sid x4++, 544(t1)
        bn.sid x4++, 576(t1)
        bn.sid x4++, 608(t1)
        bn.sid x4++, 640(t1)
        bn.sid x4++, 672(t1)
        bn.sid x4++, 704(t1)
        bn.sid x4++, 736(t1)
        /* Update output address. */
        addi t1, t1, 768

    /* Compute z = seca2b_bc22(y, k = VA, share_str = k * 32, nshares). */
    addi a0, sp, 0 /* ptr_y */
    addi a1, x0, 24 /* dv + alpha */
    addi a2, x0, 768
    addi a3, s0, 0 /* nshares */
    addi a4, sp, 0 /* ptr_z */
    jal  x1, seca2b_bc22

    /* Compute z >>= alpha, i.e., keep only the bits z[alpha]...z[alpha + dv]. */
    addi t0, sp, 0 /* ptr_z */
    addi t0, t0, OFFSET_BIT_A
    addi t1, s1, 0 /* ptr_r */
    loop s0, 5
        loopi 11, 3
            /* Whitening. */
            bn.xor w0, w0, w0
            bn.lid x0, 0(t0++)
            bn.sid x0, 0(t1++)
        /* After copy DV bits of z to r, wtmp0_du need to adjust address of z again. */
        add t0, t0, OFFSET_BIT_A

    beq x0, x0, _handle_common_du

_handle_kn4_du:
    /* Adjust space for temporary variable y. */
    loop a1, 1
        addi sp, sp, -736 /* ptr_y: 32 * (DU + ALPHA) = 32 * 25 = 800 */

    addi t1, sp, 0 /* ptr_y */

    /* All-zero register. */
    #define wpa_du w29
    bn.xor    bn0, bn0, bn0
    bn.shv.8s wpa_du, wmask_du << ALPHAm1

    loopi N_WDR, 200
        bn.lid          x0, 0(a0++)
        /* Handle even-positioned coeffs. */
        bn.trn1.16h     wtmp0_du, w0, bn0
        /* Handle coeff[0] - coeff[4] - coeff[8] - coeff[12]. */
        bn.trn1.8s      wtmp1_du, wtmp0_du, bn0
        bn.rshi         wtmp1_du, wtmp1_du, bn0 >> 233
        bn.add          wtmp1_du, wtmp1_du, wq2_du
        /* The result is 128 bits. We shift it to the left by 64 bits, then the
         * the resulting accumulator is shifted to the right by 128 bits, meaning
         * after shifting, wtmp0_du get our final result of the division by Q. We write
         * this back to the lowtmp0_dur half of the destination register. */
        bn.mulqacc.so.z wtmp2_du.l, wtmp1_du.0, wm.0, 0
        bn.mulqacc.so.z wtmp2_du.u, wtmp1_du.2, wm.0, 0
        bn.mulqacc.so.z wtmp1_du.l, wtmp1_du.1, wm.0, 0
        bn.mulqacc.so.z wtmp1_du.u, wtmp1_du.3, wm.0, 0
        bn.trn2.4d      wtmp1_du, wtmp2_du, wtmp1_du
        /* Handle coeff[2] - coeff[6] - coeff[10] - coeff[14]. */
        bn.trn2.8s      wtmp0_du, wtmp0_du, bn0
        bn.rshi         wtmp0_du, wtmp0_du, bn0 >> 233
        bn.add          wtmp0_du, wtmp0_du, wq2_du
        bn.mulqacc.so.z wtmp2_du.l, wtmp0_du.0, wm.0, 0
        bn.mulqacc.so.z wtmp2_du.u, wtmp0_du.2, wm.0, 0
        bn.mulqacc.so.z wtmp0_du.l, wtmp0_du.1, wm.0, 0
        bn.mulqacc.so.z wtmp0_du.u, wtmp0_du.3, wm.0, 0
        bn.trn2.4d      wtmp0_du, wtmp2_du, wtmp0_du
        /* Combine the result. */
        bn.trn1.8s      wtmp0_du, wtmp1_du, wtmp0_du

        /* Handle odd-positioned coeffs. */
        bn.trn2.16h     w0, w0, bn0
        /* Handle coeff[1] - coeff[5] - coeff[9] - coeff[13]. */
        bn.trn1.8s      wtmp1_du, w0, bn0
        bn.rshi         wtmp1_du, wtmp1_du, bn0 >> 233
        bn.add          wtmp1_du, wtmp1_du, wq2_du
        bn.mulqacc.so.z wtmp2_du.l, wtmp1_du.0, wm.0, 0
        bn.mulqacc.so.z wtmp2_du.u, wtmp1_du.2, wm.0, 0
        bn.mulqacc.so.z wtmp1_du.l, wtmp1_du.1, wm.0, 0
        bn.mulqacc.so.z wtmp1_du.u, wtmp1_du.3, wm.0, 0
        bn.trn2.4d      wtmp1_du, wtmp2_du, wtmp1_du
        /* Handle coeff[3] - coeff[7] - coeff[11] - coeff[15]. */
        bn.trn2.8s      w0, w0, bn0
        bn.rshi         w0, w0, bn0 >> 233
        bn.add          w0, w0, wq2_du
        bn.mulqacc.so.z wtmp2_du.l, w0.0, wm.0, 0
        bn.mulqacc.so.z wtmp2_du.u, w0.2, wm.0, 0
        bn.mulqacc.so.z w0.l, w0.1, wm.0, 0
        bn.mulqacc.so.z w0.u, w0.3, wm.0, 0
        bn.trn2.4d      w0, wtmp2_du, w0
        /* Combine the result. */
        bn.trn1.8s      wtmp1_du, wtmp1_du, w0
        /* Compute + 2**(alpha - 1) mod 2**(du + alpha). */
        bn.addv.8s      wtmp0_du, wtmp0_du, wpa_du
        bn.addv.8s      wtmp1_du, wtmp1_du, wpa_du
        /* Prepare for other coeffs. */
        bn.shv.8s wb1_du, wb1_du << 1
        bn.shv.8s wb2_du, wb2_du << 1
        bn.shv.8s wb3_du, wb3_du << 1
        bn.shv.8s wb4_du, wb4_du << 1
        bn.shv.8s wb5_du, wb5_du << 1
        bn.shv.8s wb6_du, wb6_du << 1
        bn.shv.8s wb7_du, wb7_du << 1
        bn.shv.8s wb8_du, wb8_du << 1
        bn.shv.8s wb9_du, wb9_du << 1
        bn.shv.8s wb10_du, wb10_du << 1
        bn.shv.8s wb11_du, wb11_du << 1
        bn.shv.8s wb12_du, wb12_du << 1
        bn.shv.8s wb13_du, wb13_du << 1
        bn.shv.8s wb14_du, wb14_du << 1
        bn.shv.8s wb15_du, wb15_du << 1
        bn.shv.8s wb16_du, wb16_du << 1
        bn.shv.8s wb17_du, wb17_du << 1
        bn.shv.8s wb18_du, wb18_du << 1
        bn.shv.8s wb19_du, wb19_du << 1
        bn.shv.8s wb20_du, wb20_du << 1
        bn.shv.8s wb21_du, wb21_du << 1
        bn.shv.8s wb22_du, wb22_du << 1
        bn.shv.8s wb23_du, wb23_du << 1
        /* Transform wtmp0_du to bitsliced representation. */
        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb1_du, wb1_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb1_du, wb1_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb2_du, wb2_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb2_du, wb2_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb3_du, wb3_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb3_du, wb3_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb4_du, wb4_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb4_du, wb4_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb5_du, wb5_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb5_du, wb5_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb6_du, wb6_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb6_du, wb6_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb7_du, wb7_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb7_du, wb7_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb8_du, wb8_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb8_du, wb8_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb9_du, wb9_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb9_du, wb9_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb10_du, wb10_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb10_du, wb10_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb11_du, wb11_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb11_du, wb11_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb12_du, wb12_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb12_du, wb12_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb13_du, wb13_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb13_du, wb13_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb14_du, wb14_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb14_du, wb14_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb15_du, wb15_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb15_du, wb15_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb16_du, wb16_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb16_du, wb16_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb17_du, wb17_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb17_du, wb17_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb18_du, wb18_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb18_du, wb18_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb19_du, wb19_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb19_du, wb19_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb20_du, wb20_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb20_du, wb20_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb21_du, wb21_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb21_du, wb21_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb22_du, wb22_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb22_du, wb22_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb23_du, wb23_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb23_du, wb23_du, wtmp2_du << 16

    addi   x4, x0, 6
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
    bn.sid x4++, 512(t1)
    bn.sid x4++, 544(t1)
    bn.sid x4++, 576(t1)
    bn.sid x4++, 608(t1)
    bn.sid x4++, 640(t1)
    bn.sid x4++, 672(t1)
    bn.sid x4++, 704(t1)
    /* Update output address. */
    addi t1, t1, 736

    /* Compute y[i] = Compressq(x[i], d + alpha) for i = 2,...,nshares. */
    addi t0, a1, -1 /* nshares - 1. */
    loop t0, 247
        /* Clear the registers. */
        bn.xor wb1_du, wb1_du, wb1_du
        bn.xor wb2_du, wb2_du, wb2_du
        bn.xor wb3_du, wb3_du, wb3_du
        bn.xor wb4_du, wb4_du, wb4_du
        bn.xor wb5_du, wb5_du, wb5_du
        bn.xor wb6_du, wb6_du, wb6_du
        bn.xor wb7_du, wb7_du, wb7_du
        bn.xor wb8_du, wb8_du, wb8_du
        bn.xor wb9_du, wb9_du, wb9_du
        bn.xor wb10_du, wb10_du, wb10_du
        bn.xor wb11_du, wb11_du, wb11_du
        bn.xor wb12_du, wb12_du, wb12_du
        bn.xor wb13_du, wb13_du, wb13_du
        bn.xor wb14_du, wb14_du, wb14_du
        bn.xor wb15_du, wb15_du, wb15_du
        bn.xor wb16_du, wb16_du, wb16_du
        bn.xor wb17_du, wb17_du, wb17_du
        bn.xor wb18_du, wb18_du, wb18_du
        bn.xor wb19_du, wb19_du, wb19_du
        bn.xor wb20_du, wb20_du, wb20_du
        bn.xor wb21_du, wb21_du, wb21_du
        bn.xor wb22_du, wb22_du, wb22_du
        bn.xor wb23_du, wb23_du, wb23_du

        loopi N_WDR, 198
            bn.lid          x0, 0(a0++)
            /* Handle even-positioned coeffs. */
            bn.trn1.16h     wtmp0_du, w0, bn0
            /* Handle coeff[0] - coeff[4] - coeff[8] - coeff[12]. */
            bn.trn1.8s      wtmp1_du, wtmp0_du, bn0
            bn.rshi         wtmp1_du, wtmp1_du, bn0 >> 233
            bn.add          wtmp1_du, wtmp1_du, wq2_du
            bn.mulqacc.so.z wtmp2_du.l, wtmp1_du.0, wm.0, 0
            bn.mulqacc.so.z wtmp2_du.u, wtmp1_du.2, wm.0, 0
            bn.mulqacc.so.z wtmp1_du.l, wtmp1_du.1, wm.0, 0
            bn.mulqacc.so.z wtmp1_du.u, wtmp1_du.3, wm.0, 0
            bn.trn2.4d      wtmp1_du, wtmp2_du, wtmp1_du
            /* Handle coeff[2] - coeff[6] - coeff[10] - coeff[14]. */
            bn.trn2.8s      wtmp0_du, wtmp0_du, bn0
            bn.rshi         wtmp0_du, wtmp0_du, bn0 >> 233
            bn.add          wtmp0_du, wtmp0_du, wq2_du
            bn.mulqacc.so.z wtmp2_du.l, wtmp0_du.0, wm.0, 0
            bn.mulqacc.so.z wtmp2_du.u, wtmp0_du.2, wm.0, 0
            bn.mulqacc.so.z wtmp0_du.l, wtmp0_du.1, wm.0, 0
            bn.mulqacc.so.z wtmp0_du.u, wtmp0_du.3, wm.0, 0
            bn.trn2.4d      wtmp0_du, wtmp2_du, wtmp0_du
            /* Combine the result. */
            bn.trn1.8s      wtmp0_du, wtmp1_du, wtmp0_du

            /* Handle odd-positioned coeffs. */
            bn.trn2.16h     w0, w0, bn0
            /* Handle coeff[1] - coeff[5] - coeff[9] - coeff[13]. */
            bn.trn1.8s      wtmp1_du, w0, bn0
            bn.rshi         wtmp1_du, wtmp1_du, bn0 >> 233
            bn.add          wtmp1_du, wtmp1_du, wq2_du
            bn.mulqacc.so.z wtmp2_du.l, wtmp1_du.0, wm.0, 0
            bn.mulqacc.so.z wtmp2_du.u, wtmp1_du.2, wm.0, 0
            bn.mulqacc.so.z wtmp1_du.l, wtmp1_du.1, wm.0, 0
            bn.mulqacc.so.z wtmp1_du.u, wtmp1_du.3, wm.0, 0
            bn.trn2.4d      wtmp1_du, wtmp2_du, wtmp1_du
            /* Handle coeff[3] - coeff[7] - coeff[11] - coeff[15]. */
            bn.trn2.8s      w0, w0, bn0
            bn.rshi         w0, w0, bn0 >> 233
            bn.add          w0, w0, wq2_du
            bn.mulqacc.so.z wtmp2_du.l, w0.0, wm.0, 0
            bn.mulqacc.so.z wtmp2_du.u, w0.2, wm.0, 0
            bn.mulqacc.so.z w0.l, w0.1, wm.0, 0
            bn.mulqacc.so.z w0.u, w0.3, wm.0, 0
            bn.trn2.4d      w0, wtmp2_du, w0
            /* Combine the result. */
            bn.trn1.8s      wtmp1_du, wtmp1_du, w0
            /* Bitslicing. */
            bn.shv.8s wb1_du, wb1_du << 1
            bn.shv.8s wb2_du, wb2_du << 1
            bn.shv.8s wb3_du, wb3_du << 1
            bn.shv.8s wb4_du, wb4_du << 1
            bn.shv.8s wb5_du, wb5_du << 1
            bn.shv.8s wb6_du, wb6_du << 1
            bn.shv.8s wb7_du, wb7_du << 1
            bn.shv.8s wb8_du, wb8_du << 1
            bn.shv.8s wb9_du, wb9_du << 1
            bn.shv.8s wb10_du, wb10_du << 1
            bn.shv.8s wb11_du, wb11_du << 1
            bn.shv.8s wb12_du, wb12_du << 1
            bn.shv.8s wb13_du, wb13_du << 1
            bn.shv.8s wb14_du, wb14_du << 1
            bn.shv.8s wb15_du, wb15_du << 1
            bn.shv.8s wb16_du, wb16_du << 1
            bn.shv.8s wb17_du, wb17_du << 1
            bn.shv.8s wb18_du, wb18_du << 1
            bn.shv.8s wb19_du, wb19_du << 1
            bn.shv.8s wb20_du, wb20_du << 1
            bn.shv.8s wb21_du, wb21_du << 1
            bn.shv.8s wb22_du, wb22_du << 1
            bn.shv.8s wb23_du, wb23_du << 1

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb1_du, wb1_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb1_du, wb1_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb2_du, wb2_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb2_du, wb2_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb3_du, wb3_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb3_du, wb3_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb4_du, wb4_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb4_du, wb4_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb5_du, wb5_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb5_du, wb5_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb6_du, wb6_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb6_du, wb6_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb7_du, wb7_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb7_du, wb7_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb8_du, wb8_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb8_du, wb8_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb9_du, wb9_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb9_du, wb9_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb10_du, wb10_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb10_du, wb10_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb11_du, wb11_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb11_du, wb11_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb12_du, wb12_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb12_du, wb12_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb13_du, wb13_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb13_du, wb13_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb14_du, wb14_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb14_du, wb14_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb15_du, wb15_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb15_du, wb15_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb16_du, wb16_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb16_du, wb16_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb17_du, wb17_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb17_du, wb17_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb18_du, wb18_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb18_du, wb18_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb19_du, wb19_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb19_du, wb19_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb20_du, wb20_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb20_du, wb20_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb21_du, wb21_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb21_du, wb21_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb22_du, wb22_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb22_du, wb22_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb23_du, wb23_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb23_du, wb23_du, wtmp2_du << 16

        addi   x4, x0, 6
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
        bn.sid x4++, 512(t1)
        bn.sid x4++, 544(t1)
        bn.sid x4++, 576(t1)
        bn.sid x4++, 608(t1)
        bn.sid x4++, 640(t1)
        bn.sid x4++, 672(t1)
        bn.sid x4++, 704(t1)
        /* Update output address. */
        addi t1, t1, 736

    /* Compute z = seca2b_bc22(y, k = UA, share_str = k * 32, nshares). */
    addi a0, sp, 0 /* ptr_y */
    addi a1, x0, 23 /* du + alpha */
    addi a2, x0, 736
    addi a3, s0, 0 /* nshares */
    addi a4, sp, 0 /* ptr_z */
    jal  x1, seca2b_bc22

    /* Compute z >>= alpha, i.e., keep only the bits z[alpha]...z[alpha + du]. */
    addi t0, sp, 0 /* ptr_z */
    addi t0, t0, OFFSET_BIT_A
    addi t1, s1, 0 /* ptr_r */
    loop s0, 5
        loopi 10, 3
            /* Whitening. */
            bn.xor w0, w0, w0
            bn.lid x0, 0(t0++)
            bn.sid x0, 0(t1++)
        /* After copy DV bits of z to r, wtmp0_du need to adjust address of z again. */
        add t0, t0, OFFSET_BIT_A

_handle_common_du:
    /* Restore registers. */
    lw s0, 4(fp)
    lw s1, 8(fp)
    lw s2, 12(fp)

    /* Restore sp and fp. */
    addi sp, fp, 0
    lw   fp, 0(sp)
    addi sp, sp, 32
    ret
#else
    /* Save fp to stack */
    addi sp, sp, -32
    sw   fp, 0(sp)
    addi fp, sp, 0

    /* Save registers. */
    sw   s0, 4(fp)
    sw   s1, 8(fp)
    sw   s2, 12(fp)
    addi s0, a1, 0
    addi s1, a2, 0

    /* Load all constants. */
    #define wm w1
    addi       x4, x0, 1
    la         t0, const_m_du
    bn.lid     x4, 0(t0)

    #define wq2_du w2
    #define wmask_du w2
    #define wpa_du w2
    #define ptr_q2 t2
    #define ptr_one_8 t3
    addi t4, x0, 2
    la   ptr_q2, const_1664
    la   ptr_one_8, const_one_8

    #define wtmp0_du w3
    #define wtmp1_du w4
    #define wtmp2_du w5

    #define wb1_du w6
    #define wb2_du w7
    #define wb3_du w8
    #define wb4_du w9
    #define wb5_du w10
    #define wb6_du w11
    #define wb7_du w12
    #define wb8_du w13
    #define wb9_du w14
    #define wb10_du w15
    #define wb11_du w16
    #define wb12_du w17
    #define wb13_du w18
    #define wb14_du w19
    #define wb15_du w20
    #define wb16_du w21
    #define wb17_du w22
    #define wb18_du w23
    #define wb19_du w24
    #define wb20_du w25
    #define wb21_du w26
    #define wb22_du w27
    #define wb23_du w28
    #define wb24_du w29
    #define wb25_du w30
    /* Clear the registers. */
    bn.xor wb1_du, wb1_du, wb1_du
    bn.xor wb2_du, wb2_du, wb2_du
    bn.xor wb3_du, wb3_du, wb3_du
    bn.xor wb4_du, wb4_du, wb4_du
    bn.xor wb5_du, wb5_du, wb5_du
    bn.xor wb6_du, wb6_du, wb6_du
    bn.xor wb7_du, wb7_du, wb7_du
    bn.xor wb8_du, wb8_du, wb8_du
    bn.xor wb9_du, wb9_du, wb9_du
    bn.xor wb10_du, wb10_du, wb10_du
    bn.xor wb11_du, wb11_du, wb11_du
    bn.xor wb12_du, wb12_du, wb12_du
    bn.xor wb13_du, wb13_du, wb13_du
    bn.xor wb14_du, wb14_du, wb14_du
    bn.xor wb15_du, wb15_du, wb15_du
    bn.xor wb16_du, wb16_du, wb16_du
    bn.xor wb17_du, wb17_du, wb17_du
    bn.xor wb18_du, wb18_du, wb18_du
    bn.xor wb19_du, wb19_du, wb19_du
    bn.xor wb20_du, wb20_du, wb20_du
    bn.xor wb21_du, wb21_du, wb21_du
    bn.xor wb22_du, wb22_du, wb22_du
    bn.xor wb23_du, wb23_du, wb23_du
    bn.xor wb24_du, wb24_du, wb24_du
    bn.xor wb25_du, wb25_du, wb25_du

    addi x4, x0, 4
    bne  a3, x4, _handle_kn4_du

_handle_k4_du:
    /* Adjust space for temporary variable y. */
    loop a1, 1
        addi sp, sp, -832
    addi t1, sp, 0 /* ptr_y */
    #define wz w2
    #define wb26_du w31
    bn.xor wb26_du, wb26_du, wb26_du
    loopi N_WDR, 232
        bn.lid           x0, 0(a0++)
        bn.xor           wz, wz, wz
        /* Handle even-positioned coeffs. */
        bn.trn1.16h      wtmp0_du, w0, wz
        /* Handle coeff[0] - coeff[4] - coeff[8] - coeff[12]. */
        bn.trn1.8s      wtmp1_du, wtmp0_du, wz
        bn.rshi         wtmp1_du, wtmp1_du, wz >> 230
        bn.lid          t4, 0(ptr_q2)
        bn.add          wtmp1_du, wtmp1_du, wq2_du
        bn.mulqacc.so.z wtmp2_du.l, wtmp1_du.0, wm.0, 0
        bn.mulqacc.so.z wtmp2_du.u, wtmp1_du.2, wm.0, 0
        bn.mulqacc.so.z wtmp1_du.l, wtmp1_du.1, wm.0, 0
        bn.mulqacc.so.z wtmp1_du.u, wtmp1_du.3, wm.0, 0
        bn.trn2.4d      wtmp1_du, wtmp2_du, wtmp1_du
        /* Handle coeff[2] - coeff[6] - coeff[10] - coeff[14]. */
        bn.xor          wz, wz, wz
        bn.trn2.8s      wtmp0_du, wtmp0_du, wz
        bn.rshi         wtmp0_du, wtmp0_du, wz >> 230
        bn.lid          t4, 0(ptr_q2)
        bn.add          wtmp0_du, wtmp0_du, wq2_du
        bn.mulqacc.so.z wtmp2_du.l, wtmp0_du.0, wm.0, 0
        bn.mulqacc.so.z wtmp2_du.u, wtmp0_du.2, wm.0, 0
        bn.mulqacc.so.z wtmp0_du.l, wtmp0_du.1, wm.0, 0
        bn.mulqacc.so.z wtmp0_du.u, wtmp0_du.3, wm.0, 0
        bn.trn2.4d      wtmp0_du, wtmp2_du, wtmp0_du
        /* Combine the result. */
        bn.trn1.8s      wtmp0_du, wtmp1_du, wtmp0_du

        /* Handle odd-positioned coeffs. */
        bn.xor          wz, wz, wz
        bn.trn2.16h     w0, w0, wz
        /* Handle coeff[1] - coeff[5] - coeff[9] - coeff[13]. */
        bn.trn1.8s      wtmp1_du, w0, wz
        bn.rshi         wtmp1_du, wtmp1_du, wz >> 230
        bn.lid          t4, 0(ptr_q2)
        bn.add          wtmp1_du, wtmp1_du, wq2_du
        bn.mulqacc.so.z wtmp2_du.l, wtmp1_du.0, wm.0, 0
        bn.mulqacc.so.z wtmp2_du.u, wtmp1_du.2, wm.0, 0
        bn.mulqacc.so.z wtmp1_du.l, wtmp1_du.1, wm.0, 0
        bn.mulqacc.so.z wtmp1_du.u, wtmp1_du.3, wm.0, 0
        bn.trn2.4d      wtmp1_du, wtmp2_du, wtmp1_du
        /* Handle coeff[3] - coeff[7] - coeff[11] - coeff[15]. */
        bn.xor          wz, wz, wz
        bn.trn2.8s      w0, w0, wz
        bn.rshi         w0, w0, wz >> 230
        bn.lid          t4, 0(ptr_q2)
        bn.add          w0, w0, wq2_du
        bn.mulqacc.so.z wtmp2_du.l, w0.0, wm.0, 0
        bn.mulqacc.so.z wtmp2_du.u, w0.2, wm.0, 0
        bn.mulqacc.so.z w0.l, w0.1, wm.0, 0
        bn.mulqacc.so.z w0.u, w0.3, wm.0, 0
        bn.trn2.4d      w0, wtmp2_du, w0
        /* Combine the result. */
        bn.trn1.8s      wtmp1_du, wtmp1_du, w0
        /* Compute + 2**(alpha - 1) mod 2**(du + alpha). */
        bn.lid          t4, 0(ptr_one_8)
        bn.shv.8s       wpa_du, wpa_du << ALPHAm1
        bn.addv.8s      wtmp0_du, wtmp0_du, wpa_du
        bn.addv.8s      wtmp1_du, wtmp1_du, wpa_du
        bn.shv.8s       wmask_du, wpa_du >> ALPHAm1
        /* Bitslicing. */
        bn.shv.8s wb1_du, wb1_du << 1
        bn.shv.8s wb2_du, wb2_du << 1
        bn.shv.8s wb3_du, wb3_du << 1
        bn.shv.8s wb4_du, wb4_du << 1
        bn.shv.8s wb5_du, wb5_du << 1
        bn.shv.8s wb6_du, wb6_du << 1
        bn.shv.8s wb7_du, wb7_du << 1
        bn.shv.8s wb8_du, wb8_du << 1
        bn.shv.8s wb9_du, wb9_du << 1
        bn.shv.8s wb10_du, wb10_du << 1
        bn.shv.8s wb11_du, wb11_du << 1
        bn.shv.8s wb12_du, wb12_du << 1
        bn.shv.8s wb13_du, wb13_du << 1
        bn.shv.8s wb14_du, wb14_du << 1
        bn.shv.8s wb15_du, wb15_du << 1
        bn.shv.8s wb16_du, wb16_du << 1
        bn.shv.8s wb17_du, wb17_du << 1
        bn.shv.8s wb18_du, wb18_du << 1
        bn.shv.8s wb19_du, wb19_du << 1
        bn.shv.8s wb20_du, wb20_du << 1
        bn.shv.8s wb21_du, wb21_du << 1
        bn.shv.8s wb22_du, wb22_du << 1
        bn.shv.8s wb23_du, wb23_du << 1
        bn.shv.8s wb24_du, wb24_du << 1
        bn.shv.8s wb25_du, wb25_du << 1
        bn.shv.8s wb26_du, wb26_du << 1

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb1_du, wb1_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb1_du, wb1_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb2_du, wb2_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb2_du, wb2_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb3_du, wb3_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb3_du, wb3_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb4_du, wb4_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb4_du, wb4_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb5_du, wb5_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb5_du, wb5_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb6_du, wb6_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb6_du, wb6_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb7_du, wb7_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb7_du, wb7_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb8_du, wb8_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb8_du, wb8_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb9_du, wb9_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb9_du, wb9_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb10_du, wb10_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb10_du, wb10_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb11_du, wb11_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb11_du, wb11_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb12_du, wb12_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb12_du, wb12_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb13_du, wb13_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb13_du, wb13_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb14_du, wb14_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb14_du, wb14_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb15_du, wb15_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb15_du, wb15_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb16_du, wb16_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb16_du, wb16_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb17_du, wb17_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb17_du, wb17_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb18_du, wb18_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb18_du, wb18_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb19_du, wb19_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb19_du, wb19_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb20_du, wb20_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb20_du, wb20_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb21_du, wb21_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb21_du, wb21_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb22_du, wb22_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb22_du, wb22_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb23_du, wb23_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb23_du, wb23_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb24_du, wb24_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb24_du, wb24_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb25_du, wb25_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb25_du, wb25_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb26_du, wb26_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb26_du, wb26_du, wtmp2_du << 16
    addi   x4, x0, 6
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
    bn.sid x4++, 512(t1)
    bn.sid x4++, 544(t1)
    bn.sid x4++, 576(t1)
    bn.sid x4++, 608(t1)
    bn.sid x4++, 640(t1)
    bn.sid x4++, 672(t1)
    bn.sid x4++, 704(t1)
    bn.sid x4++, 736(t1)
    bn.sid x4++, 768(t1)
    bn.sid x4++, 800(t1)
    /* Update output address. */
    addi t1, t1, 832

    /* Compute y[i] = Compressq(x[i], d + alpha) for i = 2,...,nshares. */
    addi t0, a1, -1 /* nshares - 1. */
    loop t0, 283
        /* Clear the registers. */
        bn.xor wb1_du, wb1_du, wb1_du
        bn.xor wb2_du, wb2_du, wb2_du
        bn.xor wb3_du, wb3_du, wb3_du
        bn.xor wb4_du, wb4_du, wb4_du
        bn.xor wb5_du, wb5_du, wb5_du
        bn.xor wb6_du, wb6_du, wb6_du
        bn.xor wb7_du, wb7_du, wb7_du
        bn.xor wb8_du, wb8_du, wb8_du
        bn.xor wb9_du, wb9_du, wb9_du
        bn.xor wb10_du, wb10_du, wb10_du
        bn.xor wb11_du, wb11_du, wb11_du
        bn.xor wb12_du, wb12_du, wb12_du
        bn.xor wb13_du, wb13_du, wb13_du
        bn.xor wb14_du, wb14_du, wb14_du
        bn.xor wb15_du, wb15_du, wb15_du
        bn.xor wb16_du, wb16_du, wb16_du
        bn.xor wb17_du, wb17_du, wb17_du
        bn.xor wb18_du, wb18_du, wb18_du
        bn.xor wb19_du, wb19_du, wb19_du
        bn.xor wb20_du, wb20_du, wb20_du
        bn.xor wb21_du, wb21_du, wb21_du
        bn.xor wb22_du, wb22_du, wb22_du
        bn.xor wb23_du, wb23_du, wb23_du
        bn.xor wb24_du, wb24_du, wb24_du
        bn.xor wb25_du, wb25_du, wb25_du
        bn.xor wb26_du, wb26_du, wb26_du

        loopi N_WDR, 228
            bn.lid          x0, 0(a0++)
            bn.xor          wz, wz, wz
            /* Handle even-positioned coeffs. */
            bn.trn1.16h     wtmp0_du, w0, wz
            /* Handle coeff[0] - coeff[4] - coeff[8] - coeff[12]. */
            bn.trn1.8s      wtmp1_du, wtmp0_du, wz
            bn.rshi         wtmp1_du, wtmp1_du, wz >> 230
            bn.lid          t4, 0(ptr_q2)
            bn.add          wtmp1_du, wtmp1_du, wq2_du
            bn.mulqacc.so.z wtmp2_du.l, wtmp1_du.0, wm.0, 0
            bn.mulqacc.so.z wtmp2_du.u, wtmp1_du.2, wm.0, 0
            bn.mulqacc.so.z wtmp1_du.l, wtmp1_du.1, wm.0, 0
            bn.mulqacc.so.z wtmp1_du.u, wtmp1_du.3, wm.0, 0
            bn.trn2.4d      wtmp1_du, wtmp2_du, wtmp1_du
            /* Handle coeff[2] - coeff[6] - coeff[10] - coeff[14]. */
            bn.xor          wz, wz, wz
            bn.trn2.8s      wtmp0_du, wtmp0_du, wz
            bn.rshi         wtmp0_du, wtmp0_du, wz >> 230
            bn.lid          t4, 0(ptr_q2)
            bn.add          wtmp0_du, wtmp0_du, wq2_du
            bn.mulqacc.so.z wtmp2_du.l, wtmp0_du.0, wm.0, 0
            bn.mulqacc.so.z wtmp2_du.u, wtmp0_du.2, wm.0, 0
            bn.mulqacc.so.z wtmp0_du.l, wtmp0_du.1, wm.0, 0
            bn.mulqacc.so.z wtmp0_du.u, wtmp0_du.3, wm.0, 0
            bn.trn2.4d      wtmp0_du, wtmp2_du, wtmp0_du
            /* Combine the result. */
            bn.trn1.8s      wtmp0_du, wtmp1_du, wtmp0_du

            /* Handle odd-positioned coeffs. */
            bn.xor          wz, wz, wz
            bn.trn2.16h     w0, w0, wz
            /* Handle coeff[1] - coeff[5] - coeff[9] - coeff[13]. */
            bn.trn1.8s      wtmp1_du, w0, wz
            bn.rshi         wtmp1_du, wtmp1_du, wz >> 230
            bn.lid          t4, 0(ptr_q2)
            bn.add          wtmp1_du, wtmp1_du, wq2_du
            bn.mulqacc.so.z wtmp2_du.l, wtmp1_du.0, wm.0, 0
            bn.mulqacc.so.z wtmp2_du.u, wtmp1_du.2, wm.0, 0
            bn.mulqacc.so.z wtmp1_du.l, wtmp1_du.1, wm.0, 0
            bn.mulqacc.so.z wtmp1_du.u, wtmp1_du.3, wm.0, 0
            bn.trn2.4d      wtmp1_du, wtmp2_du, wtmp1_du
            /* Handle coeff[3] - coeff[7] - coeff[11] - coeff[15]. */
            bn.xor          wz, wz, wz
            bn.trn2.8s      w0, w0, wz
            bn.rshi         w0, w0, wz >> 230
            bn.lid          t4, 0(ptr_q2)
            bn.add          w0, w0, wq2_du
            bn.mulqacc.so.z wtmp2_du.l, w0.0, wm.0, 0
            bn.mulqacc.so.z wtmp2_du.u, w0.2, wm.0, 0
            bn.mulqacc.so.z w0.l, w0.1, wm.0, 0
            bn.mulqacc.so.z w0.u, w0.3, wm.0, 0
            bn.trn2.4d      w0, wtmp2_du, w0
            /* Combine the result. */
            bn.trn1.8s      wtmp1_du, wtmp1_du, w0
            /* Load mask. */
            bn.lid          t4, 0(ptr_one_8)
            /* Bitslicing. */
            bn.shv.8s wb1_du, wb1_du << 1
            bn.shv.8s wb2_du, wb2_du << 1
            bn.shv.8s wb3_du, wb3_du << 1
            bn.shv.8s wb4_du, wb4_du << 1
            bn.shv.8s wb5_du, wb5_du << 1
            bn.shv.8s wb6_du, wb6_du << 1
            bn.shv.8s wb7_du, wb7_du << 1
            bn.shv.8s wb8_du, wb8_du << 1
            bn.shv.8s wb9_du, wb9_du << 1
            bn.shv.8s wb10_du, wb10_du << 1
            bn.shv.8s wb11_du, wb11_du << 1
            bn.shv.8s wb12_du, wb12_du << 1
            bn.shv.8s wb13_du, wb13_du << 1
            bn.shv.8s wb14_du, wb14_du << 1
            bn.shv.8s wb15_du, wb15_du << 1
            bn.shv.8s wb16_du, wb16_du << 1
            bn.shv.8s wb17_du, wb17_du << 1
            bn.shv.8s wb18_du, wb18_du << 1
            bn.shv.8s wb19_du, wb19_du << 1
            bn.shv.8s wb20_du, wb20_du << 1
            bn.shv.8s wb21_du, wb21_du << 1
            bn.shv.8s wb22_du, wb22_du << 1
            bn.shv.8s wb23_du, wb23_du << 1
            bn.shv.8s wb24_du, wb24_du << 1
            bn.shv.8s wb25_du, wb25_du << 1
            bn.shv.8s wb26_du, wb26_du << 1

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb1_du, wb1_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb1_du, wb1_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb2_du, wb2_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb2_du, wb2_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb3_du, wb3_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb3_du, wb3_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb4_du, wb4_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb4_du, wb4_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb5_du, wb5_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb5_du, wb5_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb6_du, wb6_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb6_du, wb6_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb7_du, wb7_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb7_du, wb7_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb8_du, wb8_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb8_du, wb8_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb9_du, wb9_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb9_du, wb9_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb10_du, wb10_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb10_du, wb10_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb11_du, wb11_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb11_du, wb11_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb12_du, wb12_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb12_du, wb12_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb13_du, wb13_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb13_du, wb13_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb14_du, wb14_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb14_du, wb14_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb15_du, wb15_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb15_du, wb15_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb16_du, wb16_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb16_du, wb16_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb17_du, wb17_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb17_du, wb17_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb18_du, wb18_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb18_du, wb18_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb19_du, wb19_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb19_du, wb19_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb20_du, wb20_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb20_du, wb20_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb21_du, wb21_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb21_du, wb21_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb22_du, wb22_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb22_du, wb22_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb23_du, wb23_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb23_du, wb23_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb24_du, wb24_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb24_du, wb24_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb25_du, wb25_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb25_du, wb25_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb26_du, wb26_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb26_du, wb26_du, wtmp2_du << 16
        addi   x4, x0, 6
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
        bn.sid x4++, 512(t1)
        bn.sid x4++, 544(t1)
        bn.sid x4++, 576(t1)
        bn.sid x4++, 608(t1)
        bn.sid x4++, 640(t1)
        bn.sid x4++, 672(t1)
        bn.sid x4++, 704(t1)
        bn.sid x4++, 736(t1)
        bn.sid x4++, 768(t1)
        bn.sid x4++, 800(t1)
        /* Update output address. */
        addi t1, t1, 832

    /* Compute z = seca2b_bc22(y, k = VA, share_str = k * 32, nshares). */
    addi a0, sp, 0 /* ptr_y */
    addi a1, x0, 26 /* dv + alpha */
    addi a2, x0, 832
    addi a3, s0, 0 /* nshares */
    addi a4, sp, 0 /* ptr_z */
    jal  x1, seca2b_bc22

    /* Compute z >>= alpha, i.e., keep only the bits z[alpha]...z[alpha + dv]. */
    addi t0, sp, 0 /* ptr_z */
    addi t0, t0, OFFSET_BIT_A
    addi t1, s1, 0 /* ptr_r */
    loop s0, 5
        loopi 11, 3
            /* Whitening. */
            bn.xor w0, w0, w0
            bn.lid x0, 0(t0++)
            bn.sid x0, 0(t1++)
        /* After copy DV bits of z to r, wtmp0_du need to adjust address of z again. */
        add t0, t0, OFFSET_BIT_A

    beq x0, x0, _handle_common_du

_handle_kn4_du:
    /* Adjust space for temporary variable y. */
    loop a1, 1
        addi sp, sp, -800 /* ptr_y: 32 * (DU + ALPHA) = 32 * 25 = 800 */

    addi t1, sp, 0 /* ptr_y */

    /* All-zero register. */
    bn.xor bn0, bn0, bn0

    loopi N_WDR, 221
        bn.lid          x0, 0(a0++)
        bn.lid          t4, 0(ptr_q2)
        /* Handle even-positioned coeffs. */
        bn.trn1.16h     wtmp0_du, w0, bn0
        /* Handle coeff[0] - coeff[4] - coeff[8] - coeff[12]. */
        bn.trn1.8s      wtmp1_du, wtmp0_du, bn0
        bn.rshi         wtmp1_du, wtmp1_du, bn0 >> 231
        bn.add          wtmp1_du, wtmp1_du, wq2_du
        /* The result is 128 bits. We shift it to the left by 64 bits, then the
         * the resulting accumulator is shifted to the right by 128 bits, meaning
         * after shifting, wtmp0_du get our final result of the division by Q. We write
         * this back to the lowtmp0_dur half of the destination register. */
        bn.mulqacc.so.z wtmp2_du.l, wtmp1_du.0, wm.0, 0
        bn.mulqacc.so.z wtmp2_du.u, wtmp1_du.2, wm.0, 0
        bn.mulqacc.so.z wtmp1_du.l, wtmp1_du.1, wm.0, 0
        bn.mulqacc.so.z wtmp1_du.u, wtmp1_du.3, wm.0, 0
        bn.trn2.4d      wtmp1_du, wtmp2_du, wtmp1_du
        /* Handle coeff[2] - coeff[6] - coeff[10] - coeff[14]. */
        bn.trn2.8s      wtmp0_du, wtmp0_du, bn0
        bn.rshi         wtmp0_du, wtmp0_du, bn0 >> 231
        bn.lid          t4, 0(ptr_q2)
        bn.add          wtmp0_du, wtmp0_du, wq2_du
        bn.mulqacc.so.z wtmp2_du.l, wtmp0_du.0, wm.0, 0
        bn.mulqacc.so.z wtmp2_du.u, wtmp0_du.2, wm.0, 0
        bn.mulqacc.so.z wtmp0_du.l, wtmp0_du.1, wm.0, 0
        bn.mulqacc.so.z wtmp0_du.u, wtmp0_du.3, wm.0, 0
        bn.trn2.4d      wtmp0_du, wtmp2_du, wtmp0_du
        /* Combine the result. */
        bn.trn1.8s      wtmp0_du, wtmp1_du, wtmp0_du

        /* Handle odd-positioned coeffs. */
        bn.trn2.16h     w0, w0, bn0
        /* Handle coeff[1] - coeff[5] - coeff[9] - coeff[13]. */
        bn.trn1.8s      wtmp1_du, w0, bn0
        bn.rshi         wtmp1_du, wtmp1_du, bn0 >> 231
        bn.lid          t4, 0(ptr_q2)
        bn.add          wtmp1_du, wtmp1_du, wq2_du
        bn.mulqacc.so.z wtmp2_du.l, wtmp1_du.0, wm.0, 0
        bn.mulqacc.so.z wtmp2_du.u, wtmp1_du.2, wm.0, 0
        bn.mulqacc.so.z wtmp1_du.l, wtmp1_du.1, wm.0, 0
        bn.mulqacc.so.z wtmp1_du.u, wtmp1_du.3, wm.0, 0
        bn.trn2.4d      wtmp1_du, wtmp2_du, wtmp1_du
        /* Handle coeff[3] - coeff[7] - coeff[11] - coeff[15]. */
        bn.trn2.8s      w0, w0, bn0
        bn.rshi         w0, w0, bn0 >> 231
        bn.lid          t4, 0(ptr_q2)
        bn.add          w0, w0, wq2_du
        bn.mulqacc.so.z wtmp2_du.l, w0.0, wm.0, 0
        bn.mulqacc.so.z wtmp2_du.u, w0.2, wm.0, 0
        bn.mulqacc.so.z w0.l, w0.1, wm.0, 0
        bn.mulqacc.so.z w0.u, w0.3, wm.0, 0
        bn.trn2.4d      w0, wtmp2_du, w0
        /* Combine the result. */
        bn.trn1.8s      wtmp1_du, wtmp1_du, w0
        /* Compute + 2**(alpha - 1) mod 2**(du + alpha). */
        bn.lid          t4, 0(ptr_one_8)
        bn.shv.8s       wpa_du, wpa_du << ALPHAm1
        bn.addv.8s      wtmp0_du, wtmp0_du, wpa_du
        bn.addv.8s      wtmp1_du, wtmp1_du, wpa_du
        bn.shv.8s       wmask_du, wpa_du >> ALPHAm1
        /* Prepare for other coeffs. */
        bn.shv.8s wb1_du, wb1_du << 1
        bn.shv.8s wb2_du, wb2_du << 1
        bn.shv.8s wb3_du, wb3_du << 1
        bn.shv.8s wb4_du, wb4_du << 1
        bn.shv.8s wb5_du, wb5_du << 1
        bn.shv.8s wb6_du, wb6_du << 1
        bn.shv.8s wb7_du, wb7_du << 1
        bn.shv.8s wb8_du, wb8_du << 1
        bn.shv.8s wb9_du, wb9_du << 1
        bn.shv.8s wb10_du, wb10_du << 1
        bn.shv.8s wb11_du, wb11_du << 1
        bn.shv.8s wb12_du, wb12_du << 1
        bn.shv.8s wb13_du, wb13_du << 1
        bn.shv.8s wb14_du, wb14_du << 1
        bn.shv.8s wb15_du, wb15_du << 1
        bn.shv.8s wb16_du, wb16_du << 1
        bn.shv.8s wb17_du, wb17_du << 1
        bn.shv.8s wb18_du, wb18_du << 1
        bn.shv.8s wb19_du, wb19_du << 1
        bn.shv.8s wb20_du, wb20_du << 1
        bn.shv.8s wb21_du, wb21_du << 1
        bn.shv.8s wb22_du, wb22_du << 1
        bn.shv.8s wb23_du, wb23_du << 1
        bn.shv.8s wb24_du, wb24_du << 1
        bn.shv.8s wb25_du, wb25_du << 1
        /* Transform wtmp0_du to bitsliced representation. */
        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb1_du, wb1_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb1_du, wb1_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb2_du, wb2_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb2_du, wb2_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb3_du, wb3_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb3_du, wb3_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb4_du, wb4_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb4_du, wb4_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb5_du, wb5_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb5_du, wb5_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb6_du, wb6_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb6_du, wb6_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb7_du, wb7_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb7_du, wb7_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb8_du, wb8_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb8_du, wb8_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb9_du, wb9_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb9_du, wb9_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb10_du, wb10_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb10_du, wb10_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb11_du, wb11_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb11_du, wb11_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb12_du, wb12_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb12_du, wb12_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb13_du, wb13_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb13_du, wb13_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb14_du, wb14_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb14_du, wb14_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb15_du, wb15_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb15_du, wb15_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb16_du, wb16_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb16_du, wb16_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb17_du, wb17_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb17_du, wb17_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb18_du, wb18_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb18_du, wb18_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb19_du, wb19_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb19_du, wb19_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb20_du, wb20_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb20_du, wb20_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb21_du, wb21_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb21_du, wb21_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb22_du, wb22_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb22_du, wb22_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb23_du, wb23_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb23_du, wb23_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb24_du, wb24_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb24_du, wb24_du, wtmp2_du << 16

        bn.and    wtmp2_du, wtmp0_du, wmask_du
        bn.shv.8s wtmp0_du, wtmp0_du >> 1
        bn.xor    wb25_du, wb25_du, wtmp2_du
        bn.and    wtmp2_du, wtmp1_du, wmask_du
        bn.shv.8s wtmp1_du, wtmp1_du >> 1
        bn.xor    wb25_du, wb25_du, wtmp2_du << 16
    addi   x4, x0, 6
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
    bn.sid x4++, 512(t1)
    bn.sid x4++, 544(t1)
    bn.sid x4++, 576(t1)
    bn.sid x4++, 608(t1)
    bn.sid x4++, 640(t1)
    bn.sid x4++, 672(t1)
    bn.sid x4++, 704(t1)
    bn.sid x4++, 736(t1)
    bn.sid x4++, 768(t1)
    /* Update output address. */
    addi t1, t1, 800

    /* Compute y[i] = Compressq(x[i], d + alpha) for i = 2,...,nshares. */
    addi t0, a1, -1 /* nshares - 1. */
    loop t0, 270
        /* Clear the registers. */
        bn.xor wb1_du, wb1_du, wb1_du
        bn.xor wb2_du, wb2_du, wb2_du
        bn.xor wb3_du, wb3_du, wb3_du
        bn.xor wb4_du, wb4_du, wb4_du
        bn.xor wb5_du, wb5_du, wb5_du
        bn.xor wb6_du, wb6_du, wb6_du
        bn.xor wb7_du, wb7_du, wb7_du
        bn.xor wb8_du, wb8_du, wb8_du
        bn.xor wb9_du, wb9_du, wb9_du
        bn.xor wb10_du, wb10_du, wb10_du
        bn.xor wb11_du, wb11_du, wb11_du
        bn.xor wb12_du, wb12_du, wb12_du
        bn.xor wb13_du, wb13_du, wb13_du
        bn.xor wb14_du, wb14_du, wb14_du
        bn.xor wb15_du, wb15_du, wb15_du
        bn.xor wb16_du, wb16_du, wb16_du
        bn.xor wb17_du, wb17_du, wb17_du
        bn.xor wb18_du, wb18_du, wb18_du
        bn.xor wb19_du, wb19_du, wb19_du
        bn.xor wb20_du, wb20_du, wb20_du
        bn.xor wb21_du, wb21_du, wb21_du
        bn.xor wb22_du, wb22_du, wb22_du
        bn.xor wb23_du, wb23_du, wb23_du
        bn.xor wb24_du, wb24_du, wb24_du
        bn.xor wb25_du, wb25_du, wb25_du

        loopi N_WDR, 217
            bn.lid          x0, 0(a0++)
            bn.lid          t4, 0(ptr_q2)
            /* Handle even-positioned coeffs. */
            bn.trn1.16h     wtmp0_du, w0, bn0
            /* Handle coeff[0] - coeff[4] - coeff[8] - coeff[12]. */
            bn.trn1.8s      wtmp1_du, wtmp0_du, bn0
            bn.rshi         wtmp1_du, wtmp1_du, bn0 >> 231
            bn.add          wtmp1_du, wtmp1_du, wq2_du
            bn.mulqacc.so.z wtmp2_du.l, wtmp1_du.0, wm.0, 0
            bn.mulqacc.so.z wtmp2_du.u, wtmp1_du.2, wm.0, 0
            bn.mulqacc.so.z wtmp1_du.l, wtmp1_du.1, wm.0, 0
            bn.mulqacc.so.z wtmp1_du.u, wtmp1_du.3, wm.0, 0
            bn.trn2.4d      wtmp1_du, wtmp2_du, wtmp1_du
            /* Handle coeff[2] - coeff[6] - coeff[10] - coeff[14]. */
            bn.trn2.8s      wtmp0_du, wtmp0_du, bn0
            bn.rshi         wtmp0_du, wtmp0_du, bn0 >> 231
            bn.lid          t4, 0(ptr_q2)
            bn.add          wtmp0_du, wtmp0_du, wq2_du
            bn.mulqacc.so.z wtmp2_du.l, wtmp0_du.0, wm.0, 0
            bn.mulqacc.so.z wtmp2_du.u, wtmp0_du.2, wm.0, 0
            bn.mulqacc.so.z wtmp0_du.l, wtmp0_du.1, wm.0, 0
            bn.mulqacc.so.z wtmp0_du.u, wtmp0_du.3, wm.0, 0
            bn.trn2.4d      wtmp0_du, wtmp2_du, wtmp0_du
            /* Combine the result. */
            bn.trn1.8s      wtmp0_du, wtmp1_du, wtmp0_du

            /* Handle odd-positioned coeffs. */
            bn.trn2.16h     w0, w0, bn0
            /* Handle coeff[1] - coeff[5] - coeff[9] - coeff[13]. */
            bn.trn1.8s      wtmp1_du, w0, bn0
            bn.rshi         wtmp1_du, wtmp1_du, bn0 >> 231
            bn.lid          t4, 0(ptr_q2)
            bn.add          wtmp1_du, wtmp1_du, wq2_du
            bn.mulqacc.so.z wtmp2_du.l, wtmp1_du.0, wm.0, 0
            bn.mulqacc.so.z wtmp2_du.u, wtmp1_du.2, wm.0, 0
            bn.mulqacc.so.z wtmp1_du.l, wtmp1_du.1, wm.0, 0
            bn.mulqacc.so.z wtmp1_du.u, wtmp1_du.3, wm.0, 0
            bn.trn2.4d      wtmp1_du, wtmp2_du, wtmp1_du
            /* Handle coeff[3] - coeff[7] - coeff[11] - coeff[15]. */
            bn.trn2.8s      w0, w0, bn0
            bn.rshi         w0, w0, bn0 >> 231
            bn.lid          t4, 0(ptr_q2)
            bn.add          w0, w0, wq2_du
            bn.mulqacc.so.z wtmp2_du.l, w0.0, wm.0, 0
            bn.mulqacc.so.z wtmp2_du.u, w0.2, wm.0, 0
            bn.mulqacc.so.z w0.l, w0.1, wm.0, 0
            bn.mulqacc.so.z w0.u, w0.3, wm.0, 0
            bn.trn2.4d      w0, wtmp2_du, w0
            /* Combine the result. */
            bn.trn1.8s      wtmp1_du, wtmp1_du, w0
            /* Load mask. */
            bn.lid          t4, 0(ptr_one_8)
            /* Bitslicing. */
            bn.shv.8s wb1_du, wb1_du << 1
            bn.shv.8s wb2_du, wb2_du << 1
            bn.shv.8s wb3_du, wb3_du << 1
            bn.shv.8s wb4_du, wb4_du << 1
            bn.shv.8s wb5_du, wb5_du << 1
            bn.shv.8s wb6_du, wb6_du << 1
            bn.shv.8s wb7_du, wb7_du << 1
            bn.shv.8s wb8_du, wb8_du << 1
            bn.shv.8s wb9_du, wb9_du << 1
            bn.shv.8s wb10_du, wb10_du << 1
            bn.shv.8s wb11_du, wb11_du << 1
            bn.shv.8s wb12_du, wb12_du << 1
            bn.shv.8s wb13_du, wb13_du << 1
            bn.shv.8s wb14_du, wb14_du << 1
            bn.shv.8s wb15_du, wb15_du << 1
            bn.shv.8s wb16_du, wb16_du << 1
            bn.shv.8s wb17_du, wb17_du << 1
            bn.shv.8s wb18_du, wb18_du << 1
            bn.shv.8s wb19_du, wb19_du << 1
            bn.shv.8s wb20_du, wb20_du << 1
            bn.shv.8s wb21_du, wb21_du << 1
            bn.shv.8s wb22_du, wb22_du << 1
            bn.shv.8s wb23_du, wb23_du << 1
            bn.shv.8s wb24_du, wb24_du << 1
            bn.shv.8s wb25_du, wb25_du << 1

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb1_du, wb1_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb1_du, wb1_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb2_du, wb2_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb2_du, wb2_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb3_du, wb3_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb3_du, wb3_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb4_du, wb4_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb4_du, wb4_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb5_du, wb5_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb5_du, wb5_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb6_du, wb6_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb6_du, wb6_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb7_du, wb7_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb7_du, wb7_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb8_du, wb8_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb8_du, wb8_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb9_du, wb9_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb9_du, wb9_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb10_du, wb10_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb10_du, wb10_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb11_du, wb11_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb11_du, wb11_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb12_du, wb12_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb12_du, wb12_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb13_du, wb13_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb13_du, wb13_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb14_du, wb14_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb14_du, wb14_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb15_du, wb15_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb15_du, wb15_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb16_du, wb16_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb16_du, wb16_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb17_du, wb17_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb17_du, wb17_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb18_du, wb18_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb18_du, wb18_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb19_du, wb19_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb19_du, wb19_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb20_du, wb20_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb20_du, wb20_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb21_du, wb21_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb21_du, wb21_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb22_du, wb22_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb22_du, wb22_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb23_du, wb23_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb23_du, wb23_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb24_du, wb24_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb24_du, wb24_du, wtmp2_du << 16

            bn.and    wtmp2_du, wtmp0_du, wmask_du
            bn.shv.8s wtmp0_du, wtmp0_du >> 1
            bn.xor    wb25_du, wb25_du, wtmp2_du
            bn.and    wtmp2_du, wtmp1_du, wmask_du
            bn.shv.8s wtmp1_du, wtmp1_du >> 1
            bn.xor    wb25_du, wb25_du, wtmp2_du << 16
        addi   x4, x0, 6
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
        bn.sid x4++, 512(t1)
        bn.sid x4++, 544(t1)
        bn.sid x4++, 576(t1)
        bn.sid x4++, 608(t1)
        bn.sid x4++, 640(t1)
        bn.sid x4++, 672(t1)
        bn.sid x4++, 704(t1)
        bn.sid x4++, 736(t1)
        bn.sid x4++, 768(t1)
        /* Update output address. */
        addi t1, t1, 800

    /* Compute z = seca2b_bc22(y, k = UA, share_str = k * 32, nshares). */
    addi a0, sp, 0 /* ptr_y */
    addi a1, x0, 25 /* du + alpha */
    addi a2, x0, 800
    addi a3, s0, 0 /* nshares */
    addi a4, sp, 0 /* ptr_z */
    jal  x1, seca2b_bc22

    /* Compute z >>= alpha, i.e., keep only the bits z[alpha]...z[alpha + du]. */
    addi t0, sp, 0 /* ptr_z */
    addi t0, t0, OFFSET_BIT_A
    addi t1, s1, 0 /* ptr_r */
    loop s0, 5
        loopi 10, 3
            /* Whitening. */
            bn.xor w0, w0, w0
            bn.lid x0, 0(t0++)
            bn.sid x0, 0(t1++)
        /* After copy DV bits of z to r, wtmp0_du need to adjust address of z again. */
        add t0, t0, OFFSET_BIT_A

_handle_common_du:
    /* Restore registers. */
    lw s0, 4(fp)
    lw s1, 8(fp)
    lw s2, 12(fp)

    /* Restore sp and fp. */
    addi sp, fp, 0
    lw   fp, 0(sp)
    addi sp, sp, 32
    ret
#endif /* NSHARES == 2 */
