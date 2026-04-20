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
.equ x28, t3
.equ x29, t4
.equ x30, t5
.equ x31, t6

#define MLDSA_KBITS         23
#define MLDSA_KBITS_PLUS_1  24
#define SHARE_STR_BYTES     768

/*
 * Name: secleq^d_psi (PINI when output is public, d = 2)
 *
 * Implements Alg.4 SecLeq^d_psi(x^{B,k}) of [ABCH+23] for k = MLDSA_KBITS
 * = 23.  Returns b = 1 iff x <= psi in w0, with 0 <= psi < 2^k - 1.
 *
 *   1: x'^{B,k+1}  <- SecAdd^d_{k+1}(x^{B,k}, 2^{k+1} - psi - 1)
 *   2: b           <- SecUnMask^d_1(x'^{B,k+1}[k])
 *
 * Source: Alg.4 of "Protecting Dilithium against Leakage --
 *         Revisited Sensitivity Analysis and Improved Implementations",
 *         IACR TCHES 2023(4), pp. 58-79.
 *         https://eprint.iacr.org/2022/1406
 *
 * @param[in]       a1: dptr_x, (k+1)*2*32 bytes (top WDR = 0; clobbered).
 * @param[in]       w17: lane-0 holds C = 2^{k+1} - psi - 1.
 * @param[in]  w31: all-zero.
 * @param[out] w0: per-lane b (lane i = 1 iff x_i <= psi).
 *
 * clobbered registers: x5 to x7, x10 to x17, x28 to x31, w0 to w19
 * clobbered flag groups: FG0
 */
.globl secleq
secleq:
    /* Stash x ptr in a7. */
    addi a7, a1, 0

    /* Step 1: x'^{B,k+1} <- SecAdd^d_{k+1}(C, x), in place. */
    addi a0, a1, 0
    addi a5, a1, 0
    li   a2, MLDSA_KBITS_PLUS_1
    li   a3, SHARE_STR_BYTES
    li   a4, 2
    jal  x1, secadd_bc22_immd_d2

    /* Step 2: b <- SecUnMask^d_1(x'^{B,k+1}[k]). */
    addi t1, a7, 736
    addi t6, t1, SHARE_STR_BYTES
    li   t3, 0
    bn.lid t3, 0(t1)
    li   t4, 1
    bn.lid t4, 0(t6)
    bn.wsrr w2, URND
    bn.xor  w0, w0, w2
    bn.xor  w1, w1, w2
    bn.xor  w0, w0, w1
    ret
