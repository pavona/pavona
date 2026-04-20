/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

.equ x1,  ra
.equ x2,  sp
.equ x5,  t0
.equ x6,  t1
.equ x7,  t2
.equ x10, a0
.equ x11, a1
.equ x12, a2
.equ x13, a3
.equ x14, a4
.equ x15, a5
.equ x16, a6
.equ x17, a7
.equ x28, t3
.equ x29, t4
.equ x30, t5
.equ x31, t6

.equ w31, bn0

#define MLDSA_KBITS         23
#define MLDSA_KBITS_PLUS_1  24
#define SHARE_STR_BYTES     768    /* (k+1) * 32 */

/*
 * Name: secaddmodq_bc22 (PINI)
 *
 * Compute Boolean sharing z = (x + y) mod q from k-bit Boolean sharings of
 * x, y with 0 <= x, y < q.  Implements [BC22] Alg.7 (SecAddModp):
 *   1: nq^{B,k+1} <- (2^{k+1} - q, 0, ..., 0)   (immediate 0x801FFF)
 *   2: s^{B,k+1}  <- SecAdd(x^{B,k}, y^{B,k})
 *   3: sp^{B,k+1} <- SecAdd(s, nq)
 *   4: b^{B,1}    <- sp[k]
 *   5: a^{B,k}    <- BitCopyMask(b, q)
 *   6: z^{B,k}    <- SecAdd(a, sp)
 *
 * Steps 4+5+6 are fused inside `secadd_constant_bmsk_mldsa`.
 *
 * Limitations: ML-DSA only (q = 0x7FE001 hardcoded; matches external nq).
 *              d = 2 only (via `secadd_constant_bmsk_mldsa`).
 *
 * @param[in]   x10: dptr_z, output ((k+1) * nshares * 32 bytes, bit k = 0).
 * @param[in]   x11: dptr_x, input  ((k+1) * nshares * 32 bytes, bit k = 0).
 * @param[in]   x12: dptr_y, input  ((k+1) * nshares * 32 bytes, bit k = 0).
 * @param[in]   x14: nshares.
 * @param[in]   w31: all-zero.
 *
 * clobbered registers: x5 to x7, x10 to x17, x28 to x31, w0 to w23
 * clobbered flag groups: FG0
 */
.globl secaddmodq_bc22
secaddmodq_bc22:
    addi a7, a0, 0                /* park z_out in a7 */

    /* Step 2: s = SecAdd(x, y) -> z_out. */
    addi a0, a1, 0
    addi a1, a2, 0
    li   a2, MLDSA_KBITS_PLUS_1
    li   a3, SHARE_STR_BYTES
    addi a5, a7, 0
    jal  x1, secadd_bc22

    /* Step 3: sp = SecAdd(s, nq) -> z_out, in place. */
    bn.xor w17, w17, w17
    bn.addi w17, w17, 1
    bn.shv.8S w17, w17 << 23
    bn.xor w18, w18, w18
    bn.addi w18, w18, 1
    bn.shv.8S w18, w18 << 13
    bn.subi w18, w18, 1
    bn.add w17, w17, w18           /* w17 lane 0 = nq = 0x801FFF */
    addi a0, a7, 0
    li   a2, MLDSA_KBITS_PLUS_1
    li   a3, SHARE_STR_BYTES
    li   a4, 2
    addi a5, a7, 0
    jal  x1, secadd_bc22_immd_d2

    /* Step 4+5+6: z = sp + BitCopyMask(sp[k], q) -> z_out, in-place. */
    addi a0, a7, 0
    jal  x1, secadd_constant_bmsk_mldsa

    ret
