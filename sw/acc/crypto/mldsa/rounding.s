/* Copyright zeroRISC Inc. */
/* Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192). */
/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

.equ w31, bn0

/**
 * decompose_88 / decompose_32
 *
 * For finite field element a, compute high and low bits a0, a1 such that a
 * mod^+ Q = a1*ALPHA + a0 with -ALPHA/2 < a0 <= ALPHA/2 except if a1 =
 * (Q-1)/ALPHA where we set a1 = 0 and -ALPHA/2 <= a0 = a mod^+ Q - Q < 0.
 * Assumes a to be standard representative.
 *
 * Two variants are provided depending on the GAMMA2 value of the active mode:
 *   decompose_88: GAMMA2 == (Q-1)/88   (mode 2, ML-DSA-44)
 *   decompose_32: GAMMA2 == (Q-1)/32   (modes 3 and 5, ML-DSA-65/87)
 * Callers select the right symbol at compile time via a #define alias.
 *
 * Returns: output element vector "a0" in w1, output element vector "a1" in w2
 *
 * @param[in] w0: input element vector
 * @param[in] w5-w11: constants in the following order: decompose_127_const,
 * decompose_const, reduce32_const, decompose_43_const, gamma2_vec_const,
 * qm1half_const, modulus
 *
 * clobbered registers: w1-w4, w30
 */
.global decompose_88
decompose_88:
    /* "a", "a{0,1}" refer to the variable names from the reference code */

    /* Compute "a1" */
    bn.addv.8S w2, w0, w5         /* "a" + 127 */
    bn.shv.8S  w2, w2 >> 7   /* ("a" + 127) >> 7 */
    bn.mulv.8S.even.lo w2, w2, w6         /* "a1" * 11275 */
    bn.mulv.8S.odd.lo  w2, w2, w6         /* "a1" * 11275 */
    bn.shv.8S  w4, w7 << 23  /* 1 << 23 */
    bn.addv.8S w2, w2, w4         /* ("a1" * 11275) + (1 << 23) */
    bn.shv.8S  w2, w2 >> 24  /* (("a1" * 11275) + (1 << 23)) >> 24 */
    bn.subv.8S w3, w8, w2         /* 43 - "a1" */
    bn.shv.8S w30, w3 >> 31
    bn.subv.8S w30, bn0, w30 /* Build mask from MSBs */
    bn.and w3, w2, w30           /* ((43 - "a1") >> 31) & "a1" */
    bn.xor w2, w2, w3            /* "a1" ^= ((43 - "a1") >> 31) & "a1" */

    /* Compute "a0" */
    bn.mulv.8S.even.lo w4, w2, w9          /* "a1" * GAMMA2 */
    bn.mulv.8S.odd.lo  w4, w4, w9          /* "a1" * GAMMA2 */
    bn.shv.8S  w4, w4 << 1    /* "a1" * GAMMA2 * 2 */
    bn.subv.8S w1, w0, w4          /* a - "a1" * GAMMA2 * 2 */
    bn.subv.8S w4, w10, w1         /* (Q-1)/2 - "a0" */
    bn.shv.8S  w30, w4 >> 31
    bn.subv.8S w30, bn0, w30 /* Build mask from MSBs */
    bn.and     w4, w11, w30        /* (((Q-1)/2 - "a0") >> 31) & Q */
    bn.subv.8S w1, w1, w4          /* a0 -= (((Q-1)/2 - "a0") >> 31) & Q */

    ret

.global decompose_32
decompose_32:
    /* "a", "a{0,1}" refer to the variable names from the reference code */

    /* Compute "a1" */
    bn.addv.8S w2, w0, w5         /* "a" + 127 */
    bn.shv.8S  w2, w2 >> 7   /* ("a" + 127) >> 7 */
    bn.mulv.8S.even.lo w2, w2, w6    /* "a1" * 1025 */
    bn.mulv.8S.odd.lo  w2, w2, w6    /* "a1" * 1025 */
    bn.shv.8S  w4, w7 << 21  /* 1 << 21 */
    bn.addv.8S w2, w2, w4    /* ("a1" * 1025) + (1 << 21) */
    bn.shv.8S  w2, w2 >> 22  /* (("a1" * 1025) + (1 << 21)) >> 22 */
    bn.and     w2, w2, w8    /* & 15 */

    /* Compute "a0" */
    bn.mulv.8S.even.lo w4, w2, w9          /* "a1" * GAMMA2 */
    bn.mulv.8S.odd.lo  w4, w4, w9          /* "a1" * GAMMA2 */
    bn.shv.8S  w4, w4 << 1    /* "a1" * GAMMA2 * 2 */
    bn.subv.8S w1, w0, w4          /* a - "a1" * GAMMA2 * 2 */
    bn.subv.8S w4, w10, w1         /* (Q-1)/2 - "a0" */
    bn.shv.8S  w30, w4 >> 31
    bn.subv.8S w30, bn0, w30 /* Build mask from MSBs */
    bn.and     w4, w11, w30        /* (((Q-1)/2 - "a0") >> 31) & Q */
    bn.subv.8S w1, w1, w4          /* a0 -= (((Q-1)/2 - "a0") >> 31) & Q */

    ret
