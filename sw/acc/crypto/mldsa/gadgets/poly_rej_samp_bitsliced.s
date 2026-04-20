/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

.equ x5,  t0
.equ x6,  t1
.equ x10, a0
.equ x11, a1
.equ x14, a4
.equ x30, t5

#ifndef TEST
  #define TEST 0
#endif

#define MLDSA_KBITS 23

/*
 * Name: poly_rej_samp_bitsliced (ML-DSA)
 *
 * Sample 256 coefficients uniform in [0, q), q = 8380417, in bitsliced
 * layout.
 * Source: URND.  Re-draws until all 256 lanes < q check.
 *
 * Per-batch accept probability (Python):
 *     p_batch = (8380417 / 2**23) ** 256  # ~ 0.77873, so ~ 1.28 draws expected
 *
 * @param[in]      a0: ptr_r, dmem output (k * 32 bytes).
 * @param[in]      a1: (TEST=1 only) deterministic random stream pointer.
 * @param[in]  w31: all-zero.
 *
 * clobbered registers: x5 to x6, x14, x30, w0 to w23
 * clobbered flag groups: FG0
 */
.globl poly_rej_samp_bitsliced
poly_rej_samp_bitsliced:
_prs_bs_draw:
#if TEST == 0
    bn.wsrr w0,  URND
    bn.wsrr w1,  URND
    bn.wsrr w2,  URND
    bn.wsrr w3,  URND
    bn.wsrr w4,  URND
    bn.wsrr w5,  URND
    bn.wsrr w6,  URND
    bn.wsrr w7,  URND
    bn.wsrr w8,  URND
    bn.wsrr w9,  URND
    bn.wsrr w10, URND
    bn.wsrr w11, URND
    bn.wsrr w12, URND
    bn.wsrr w13, URND
    bn.wsrr w14, URND
    bn.wsrr w15, URND
    bn.wsrr w16, URND
    bn.wsrr w17, URND
    bn.wsrr w18, URND
    bn.wsrr w19, URND
    bn.wsrr w20, URND
    bn.wsrr w21, URND
    bn.wsrr w22, URND
#else
    /* TEST=1: read k WDRs from a1 in place of URND. */
    li   t0, 0
    li   t1, MLDSA_KBITS
    loop t1, 2
        bn.lid t0, 0(a1++)
        addi   t0, t0, 1
#endif

    /* Per-lane v < q check: bit k of v + (2^k - q) is 0 iff v < q.
     * With (2^k - q) = 0x1FFF (bits 0..12 = 1, bits 13..22 = 0), the
     * carry chain collapses to:
     *   bits 0..12  (const = 1):  c_{b+1} = v_b OR  c_b
     *   bits 13..22 (const = 0):  c_{b+1} = v_b AND c_b
     * Starting c_0 = 0, accept iff the folded c_23 (in w23) is all-zero.
     *
     * Probability that a random draw passes for all lanes is
     *  (8380417 / 2**23) ** 256  = 0.77873, so ~ 1.28 draws expected
     */
    bn.or  w23, w0,  w1
    bn.or  w23, w23, w2
    bn.or  w23, w23, w3
    bn.or  w23, w23, w4
    bn.or  w23, w23, w5
    bn.or  w23, w23, w6
    bn.or  w23, w23, w7
    bn.or  w23, w23, w8
    bn.or  w23, w23, w9
    bn.or  w23, w23, w10
    bn.or  w23, w23, w11
    bn.or  w23, w23, w12

    bn.and w23, w23, w13
    bn.and w23, w23, w14
    bn.and w23, w23, w15
    bn.and w23, w23, w16
    bn.and w23, w23, w17
    bn.and w23, w23, w18
    bn.and w23, w23, w19
    bn.and w23, w23, w20
    bn.and w23, w23, w21
    bn.and w23, w23, w22

    /* Redraw if any lane >= q (w23 != 0). */
    csrrs  a4, 0x7C0, x0
    andi   a4, a4, 8
    beq    a4, x0, _prs_bs_draw

    /* Store w0..w22 to output. */
    addi t5, a0, 0
    li   t0, 0
    li   t1, MLDSA_KBITS
    loop t1, 2
        bn.sid t0, 0(t5++)
        addi   t0, t0, 1

    ret
