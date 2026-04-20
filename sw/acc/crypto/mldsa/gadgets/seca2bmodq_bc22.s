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
 * Name: seca2bmodq_bc22 (PINI, d = 2)
 *
 * Convert a 2-share arithmetic sharing of x mod p (x^A_p) into a 2-share
 * Boolean sharing z^{B,k}.  Implements [BC22] Alg.10 (SecA2BModp).
 *
 * Alg.10 (lines (n) are no-ops in the d = 2 path):
 *  (1)  if d = 1 then
 *  (2)    z^{B,k}   <- x^A_p
 *   3:  else
 *  (4)    y^{B,k}   <- SecA2BModp^1_k(x^A_p[0])             . d=1 recursion = identity
 *  (5)    y'^{B,k}  <- SecA2BModp^1_k(x^A_p[1])             . d=1 recursion = identity
 *   6:    p^{B,k+1} <- (2^{k+1} - p, 0)                     . immediate 0x801FFF
 *   7:    s^{B,k+1} <- SecAdd^1_{k+1}(p^{B,k+1}, y^{B,k})
 *   8:    s^{B,k+1} <- (y^{B,k+1}, 0)                       . expand to d shares
 *   9:    s'^{B,k}  <- (0, y'^{B,k})                        . expand to d shares
 *  10:    u^{B,k+1} <- SecAdd^d_{k+1}(s^{B,k+1}, s'^{B,k})
 *  11:    b^{B,1}   <- u^{B,k+1}[k]
 *  12:    a^{B,k}   <- BitCopyMask^d_k(b^{B,1}, p)
 *  13:    z^{B,k}   <- SecAdd^d_k(a^{B,k}, u^{B,k+1})
 *
 * @param[in]   x10: dptr_z, output ((k+1) * 2 * 32 bytes, bit k = 0).
 * @param[in]   x11: dptr_x, input  ((k+1) * 2 * 32 bytes, bit k = 0).
 * @param[in]   x13: dptr_scratch, 1536 B caller-provided scratch (must not
 *                   overlap z_in/z_out or any live caller buffer).
 * @param[in]   w31: all-zero.
 *
 * clobbered registers: x2, x5 to x7, x10 to x17, x28 to x31, w0 to w23
 * clobbered flag groups: FG0
 */
.globl seca2bmodq_bc22
seca2bmodq_bc22:
    addi sp, sp, -32
    sw   a3, 0(sp)                 /* preserve scratch across secadd calls */
    addi a7, a0, 0                 /* park z_out */

    /* Step 9: s'^{B,k} <- (0, y'^{B,k}). */
    addi t3, a1, SHARE_STR_BYTES
    addi t1, a3, 0
    li   t2, 31
    loopi MLDSA_KBITS_PLUS_1, 1
        bn.sid t2, 0(t1++)
    bn.xor w0, w0, w0              /* whitening */
    li   t2, 0
    loopi MLDSA_KBITS_PLUS_1, 2
        bn.lid t2, 0(t3++)
        bn.sid t2, 0(t1++)
    bn.xor w0, w0, w0              /* whitening */

    /* Step 7: s^{B,k+1} <- SecAdd^1_{k+1}(p^{B,k+1}, y^{B,k}). */
    addi a0, a1, 0
    li   a2, MLDSA_KBITS
    li   a3, MLDSA_KBITS_PLUS_1
    addi a6, a7, 0
    jal  x1, secadd_bc22_immd_d1

    /* Step 8: s^{B,k+1} <- (y^{B,k+1}, 0). */
    addi t1, a7, SHARE_STR_BYTES
    li   t2, 31
    loopi MLDSA_KBITS_PLUS_1, 1
        bn.sid t2, 0(t1++)

    /* Step 10: u^{B,k+1} <- SecAdd^d_{k+1}(s^{B,k+1}, s'^{B,k}). */
    lw   a0, 0(sp)
    addi a1, a7, 0
    li   a2, MLDSA_KBITS_PLUS_1
    li   a3, SHARE_STR_BYTES
    li   a4, 2
    addi a5, a7, 0
    jal  x1, secadd_bc22

    /* Steps 11-13 (fused): z^{B,k} <- u + BitCopyMask^d_k(u^{B,k+1}[k], p). */
    addi a0, a7, 0
    jal  x1, secadd_constant_bmsk_mldsa

    addi sp, sp, 32
    ret
