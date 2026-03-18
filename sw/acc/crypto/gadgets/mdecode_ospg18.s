/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

#define N 256 /* Number of coefficients in a polynomial. */

/* We define the number of bytes that a polynomial occupies only for ML-KEM for
 * for now. We can generalize this for ML-DSA if these gadgets are needed. */
#ifndef SCHEME
    #define SCHEME 0 /* 0: ML-KEM, 1: ML-DSA. */
#endif

#if SCHEME == 0
    #define NB_POLY 512 /* Number of bytes occupied by a polynomial */
    #define N_WDR 16 /* Number of WDRs to store N coeffs */
    #define BITSIZE 16 /* Register bit size */
    #define N_COEFFS 16 /* Number of coeffs fitting in a WDR */
#else
    #define NB_POLY 1024 /* Number of bytes occupied by a polynomial */
    #define N_WDR 32 /* Number of WDRs to store N coeffs */
    #define BITSIZE 32 /* Regiter bit size */
    #define N_COEFFS 8 /* Number of coeffs fitting in a WDR */
#endif

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
 * Name: mdecode_ospg18 (NI)
 *
 * Return 1-bit Boolean shares of the message m, given its arithmetic shares mod q.
 * (alternatively, this is also called masked 1-bit compression.)
 * Vectorized for polynomial.
 *
 * Source: Alg.2 [OSPG18]
 *         [OSPG18]: "Practical CCA2-Secure and Masked Ring-LWE Implementation"
 *         Link: https://tches.iacr.org/index.php/TCHES/article/view/836
 *
 * Note: The algorithm is adapted to A2B mod q conversion in [FBR+21] (Fig.3).
 *       This implementation follows Alg.2 of [OSPG18], with TransformPower2
 *       replaced by seca2bmodq of [SPOG19] and with addition replaced by
 *       secadd from [CGTV15]. Note that any A2B mod q conversion and any secure
 *       addition gadget will work.
 *       [FBR+21]: "Masked Accelerators and Instruction Set Extensions for Post-Quantum Cryptography"
 *       Link: https://tches.iacr.org/index.php/TCHES/article/view/9303
 *       We assume that the bit size of the masks is always 16.
 *
 * Flags: -
 *
 * @param[in]  x10: dptr_xb, dmem pointer to the input arithmetic shares
 * @param[in]  x11: nshares, the number of shares
 * @param[out] x12: dptr_rb, dmem pointer to the output Boolean shares
 *
 * clobbered registers: TODO
 * clobbered flag groups: TODO
 */
.globl mdecode_ospg18
mdecode_ospg18:
    /* Save fp to stack */
    addi sp, sp, -32
    sw   fp, 0(sp)
    addi fp, sp, 0

    /* Adjust stack for temporary variable. */
    loop a1, 1
        addi sp, sp, -NB_POLY
    sw   sp, 16(fp) /* ptr_q2 */
    addi s0, sp, 0

    /* All-zero register. */
    bn.xor bn0, bn0, bn0

    /* Algorithm 2 of [OSPG18] has one problem. The first share is subtracted
     * from floor(q/4) = 832. This will lead 832 to be compressed 1 instead of 0.
     * More concretely, compressq(x,1) = 0 if x in [833, 2496] and 0 otherwise.
     * The idea of [OSPG18] is to first shift the arithmetic values mod q by
     * adding -floor(q/4) --> A2Bq --> shift the Boolean value by adding
     * -floor(q/2) --> the MSB of the result is the compression bit.
     * Now for x = 832, x - floor(q/4) = 0 then MSB(0 - floor(q/2)) = 1 --> WRONG!!!
     *
     * The fix is that we need to subtract ceil(q/4) = 833 instead. For x = 832,
     * x - 833 = -1 = 3328. Then MSB(3328 - floor(q/2) = 1664) = 0. */
    /* Compute a vector of ceil(Q/4) = 833. */
    addi        x4, x0, 1
    la          t0, modulus_bn
    bn.lid      x4, 0(t0)
    bn.mov      w2, w1
    bn.shv.16h  w1, w1 >> 2
    bn.subi     w0, bn0, 1
    bn.shv.16h  w0, w0 >> 15
    bn.addv.16h w1, w1, w0
    /* Compute a vector of -floor(q/2) mod 2**k where k = 16. */
    addi        x4, x0, 2
    bn.shv.16h  w2, w2 >> 1
    bn.subv.16h w2, bn0, w2
    loopi N_WDR, 1
        bn.sid x4, 0(s0++)
    addi t0, a1, -1 /* t0 = nshares - 1. */
    li   x4, 31
    loop t0, 3
        loopi N_WDR, 1
            bn.sid x4, 0(s0++)
        nop

    /* Since the message polynomial is not used after this routine, we can
     * overwrite the input to save memory and improve performance. */
    /* Save input and output addresses. */
    sw a0, 4(fp)
    sw a1, 8(fp)
    sw a2, 12(fp)
    /* Compute x[0] = (x[0] - ceil(q/4)) mod q. */
    loopi N_WDR, 3
        bn.lid       x0, 0(a0)
        bn.subvm.16h w0, w0, w1
        bn.sid       x0, 0(a0++)

    /* Compute x = seca2bmodq(x, nshares). */
    lw   a0, 4(fp)
    /* a1 is already nshares. */
    addi a2, a0, 0 /* Output inplace. */
    jal  x1, seca2bmodq_spog19

    /* Compute x = secadd_cgtv15(x, q2, nshares). */
    lw   a0, 4(fp)
    lw   a1, 16(fp)
    lw   a2, 8(fp)
    addi a3, a0, 0 /* Output inplace. */
    jal  x1, secadd_cgtv15

    /* Extract MSBs. */
    lw   a0, 4(fp)
    lw   a1, 8(fp)
    lw   a2, 12(fp)
    addi x4, x0, 1
    loop a1, 8
        loopi N_WDR, 6
            bn.lid     x0, 0(a0++)
            bn.shv.16h w0, w0 >> 11 /* Extract MSBs. */
            loopi N_COEFFS, 2
                bn.rshi w1, w0, w1 >> 1
                bn.rshi w0, bn0, w0 >> 16
            nop
        bn.sid x4, 0(a2++)

    /* Restore sp and fp. */
    addi       sp, fp, 0
    lw         fp, 0(sp)
    addi       sp, sp, 32
    ret
