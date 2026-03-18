/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

#ifndef TEST
	#define TEST 0
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
 * Name: poly_rej_samp
 *
 * Return a polynomial of wrandom coefficients mod q, obtained by running
 * rejection sampling on uniform wrandom bytes from URND.
 * TODO: Is RND good enough?
 *
 * @param[in]  w16: sw0, R | Q
 * @param[out] a0: ptr_r, dmem pointer to output polynomial
 *
 * clobbered registers: TODO
 * clobbered flag groups: TODO
 */

.globl poly_rej_samp
poly_rej_samp:
	/* All-x0 register. */
	bn.xor bn0, bn0, bn0

	/* Load 19*Q. */
	#define wmod_times_19 w1
	addi      t0, x0, 1
	la        t1, modulus_times_19
	bn.lid    t0++, 0(t1)
	bn.shv.8s wmod_times_19, wmod_times_19 >> 16

	/* Load mont = 2**16 % Q. */
	#define wmont w2
	la     t1, mont
	bn.lid t0, 0(t1)

	/* t0 = 508, a0 + 508 is the last valid address */
	addi t0, a0, 512

	#define wrandom w3
	#define wcmp w4
	#define wtmp w5
	#define accumulator w0

#if TEST == 1
	#define wrandom_idx t5
	addi t5, x0, 3
#endif

	/* Loop until 256 coefficients have been written to the output */
_rej_sample_loop:
	/* Get 16 randoms. */
#if TEST == 0
	bn.wsrr     wrandom, urnd
#else
	bn.lid      wrandom_idx, 0(a1++)
#endif
	bn.trn1.16h wcmp, wrandom, bn0
	bn.subv.8s  wcmp, wmod_times_19, wcmp
	bn.shv.8s   wcmp, wcmp >> 31
	bn.trn2.16h wtmp, wrandom, bn0
	bn.subv.8s  wtmp, wmod_times_19, wtmp
	bn.shv.8s   wtmp, wtmp >> 31
	bn.trn1.16h wcmp, wcmp, wtmp
	bn.xor      wcmp, wcmp, bn0, FG0
	csrrs       t1, fg0, x0 /* Read flag fg0. */
	srli        t1, t1, 3 /* Extract FG0.z */

	/* If FG0.z == 0, there is at least one bad coeff, and we're sure that
	 * accumulator_count is less than 16. */
	beq t1, x0, _rej_sample_loop

	/* Once the whole vector is accepted, reduce the accepted candidates mod Q
	 * using Montgomery. */
	bn.mulv.16H.acc.z.lo accumulator, wrandom, wmont
	bn.mulv.l.16H.lo     accumulator, accumulator, sw0.2
	bn.mulv.l.16H.acc.hi accumulator, accumulator, sw0.0
	bn.addvm.16H         accumulator, accumulator, bn0
	bn.sid               x0, 0(a0++)

	/* If a0 == t0, we've filled up a polynomial. Otherwise, continue to sample. */
	beq a0, t0, _end_rej_sample_loop
	beq x0, x0, _rej_sample_loop

_end_rej_sample_loop:
	ret
