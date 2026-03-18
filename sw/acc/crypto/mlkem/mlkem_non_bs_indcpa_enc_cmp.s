/* Copyright zeroRISC Inc. */
/* Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192). */
/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors. */
/* Modified by Ruben Niederhagen and Hoang Nguyen Hien Pham - authors of */
/* "Improving ML-KEM & ML-DSA on OpenTitan - Efficient Multiplication Vector Instructions for OTBN" */
/* (https://eprint.iacr.org/2025/2028). */
/* Copyright Ruben Niederhagen and Hoang Nguyen Hien Pham. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

#ifndef NSHARES
	#define NSHARES 2
#endif

/* Register aliases */
#define sp x2
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
 * Name:        indcpa_enc
 *
 * Description: Encryption function of the CPA-secure
 *              public-key encryption scheme underlying Kyber.
 *
 * Arguments:   - uint8_t *c: pointer to output ciphertext
 *                            (of length KYBER_INDCPA_BYTES bytes)
 *              - const uint8_t *m: pointer to input message
 *                                  (of length KYBER_INDCPA_MSGBYTES bytes)
 *              - const uint8_t *pk: pointer to input public key
 *                                   (of length KYBER_INDCPA_PUBLICKEYBYTES)
 *              - const uint8_t *coins: pointer to input random coins used as seed
 *                                      (of length KYBER_SYMBYTES) to deterministically
 *                                      generate all randomness
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10 (a0): dmem pointer to input Boolean-shared message
 * @param[in]  x11 (a1): dmem pointer to input packed pk
 * @param[in]  x12 (a2): dmem pointer to input coins
 * @param[in]  x13 (a3): dmem pointer to input ct
 * @param[in]  x14 (a4): nshares, the number of shares
 * @param[in]  x15 (a5): k, the security level
 *
 * clobbered registers: x4 to x29, w0 to w31, acc, acch, mod
 * clobbered flag groups: FG0
 */
.globl indcpa_enc_cmp
indcpa_enc_cmp:
    /* Save fp to stack */
    addi sp, sp, -32
    sw   fp, 0(sp)
    addi fp, sp, 0

	addi s1, a1, 0
	addi s2, a2, 0
	addi s3, a3, 0
	addi s4, a4, 0
	addi s5, a5, 0

	addi x4, x0, 4
	beq  s5, x4, _compute_k4_consts
_compute_kn4_consts:
	addi s10, x0, 128 /* dv */
	addi s11, x0, 320 /* du */
	addi t0, x0, 4
	sw   t0, 12(fp)
	addi t0, x0, 10
	sw   t0, 16(fp)
	beq  x0, x0, _continue
_compute_k4_consts:
	addi s10, x0, 160 /* dv */
	addi s11, x0, 352 /* du */
	addi t0, x0, 5
	sw   t0, 12(fp)
	addi t0, x0, 11
	sw   t0, 16(fp)
_continue:
	/* Adjust stack for comparison result r. */
	slli t0, s4, 5 /* nshares * 32 */
	sub  sp, sp, t0
	sw   sp, 4(fp) /* txb */
	sub  sp, sp, t0
	sw   sp, 8(fp) /* twb */
	sub  sp, sp, t0 /* ptr_r */

	/* The first share of r is (1 << N) - 1. The other shares are 0. */
	addi    t0, sp, 0 /* r */
	bn.xor  w0, w0, w0
	bn.subi w0, w0, 1
	bn.sid  x0, 0(t0++)
	bn.xor  w0, w0, w0
	addi    t1, s4, -1 /* nshares - 1 */
	loop t1, 1
		bn.sid x0, 0(t0++)

	/* Compute k = onebitdecompress_bgr21(m, nshares). */
	bn.wsrr w16, mod /* mod = R | Q */
	/* a0 is already ptr_m. */
	addi a1, s4, 0 /* nshares */
	la   a2, mpoly_k
	jal  x1, onebitdecompress_bgr21

	/* The following block will:
	 *	(1) unpack pk[i],
	 *	(2) sample sp[i],
	 *	(3) compute sp[i] = ntt(sp[i]),
	 *	(4) compute v += pk[i] * sp[i],
	 *	(5) compute v = intt(v),
	 *	(6) compute v += k
	 *	(7) sample epp
	 *	(8) compute v += epp
	 *	(9) compare v and ct, output to r. */
	/**************************************************************************/
	addi x4, x0, 2
	beq  s5, x4, _handle_k2_eta_1
_handle_kn2_eta_1:
	addi s6, x0, 2 /* ETA1 */
	beq  x0, x0, _continue_compute_v
_handle_k2_eta_1:
	addi s6, x0, 3 /* ETA1 */

_continue_compute_v:

	/* Prepare for initial `poly_getnoise_eta_1` call: generate sp. */
	addi   a0, s2, 0 /* coins */
	la     a1, nonce
	bn.xor w0, w0, w0
	bn.sid x0, 0(a1)
	jal    x1, poly_getnoise_eta_init

	/* Unpack pk[0]. */
	addi a0, s1, 0
	la   a1, poly_pk
	jal  x1, poly_frombytes
	addi s1, a0, 0 /* Save address of pk to be unpacked later. */

	/* Generate sp[0]. */
	addi a0, s6, 0 /* eta = ETA1 */
	la   a1, mpolyvec_sp
	jal  x1, masked_poly_getnoise_eta_1

	/* Prepare for generating sp[1]. */
	addi a0, s2, 0 /* coins */
	la   a1, nonce
	lw   t0, 0(a1)
	addi t0, t0, 1
	sw   t0, 0(a1)
	jal  x1, poly_getnoise_eta_init

	/* Compute sp[0] = ntt(sp[0]). */
	bn.wsrr    w16, mod /* w16 = R | Q */
	bn.shv.16h w0, w16 << 1 /* w0 = 2*R | 2*Q */
	bn.wsrw    mod, w0 /* mod = 2*R | 2*Q */
	la         a0, mpolyvec_sp
	la         a1, twiddles_ntt
	add        a2, a0, 0
	loop s4, 2
		jal x1, ntt
		nop

	/* Compute v = pk[0] * sp[0]. */
	la   s0, poly_pk
	la   a1, mpolyvec_sp
	la   a2, twiddles_basemul
	la   a3, mpoly_v
	loop s4, 3
		addi a0, s0, 0
		jal  x1, basemul
		nop
	addi    s8, a1, 0 /* Point to sp[1]. */
	bn.wsrw mod, w16 /* Reset mod = R | Q */

	/* At this point:
	 *	- s1 points to packed pk.
	 * 	- s2 points to coins (for cbd).
	 *	- s3 points to ct (for later).
	 *	- s4 = nshares.
	 *	- s5 is the security level k.
	 * 	- s6 is ETA1.
	 *	- s7 points to poly_pk.
	 *	- s8 points to sp[1]. */

	addi x4, x0, 3
	beq  s5, x4, _handle_k3_compute_v
	addi x4, x0, 2
	beq  s5, x4, _handle_k2_compute_v

_handle_k4_compute_v:
	/* Generate sp[i]. */
	addi a0, s6, 0 /* eta = ETA1 */
	addi a1, s8, 0 /* sp[i] */
	jal  x1, masked_poly_getnoise_eta_1

	/* Prepare for generating sp[i + 1]. */
	addi a0, s2, 0 /* coins */
	la   a1, nonce
	lw   t0, 0(a1)
	addi t0, t0, 1
	sw   t0, 0(a1)
	jal  x1, poly_getnoise_eta_init

	/* Unpack pk[i]. */
	addi a0, s1, 0
	la   a1, poly_pk
	jal  x1, poly_frombytes
	addi s1, a0, 0 /* Save address of pk to be unpacked later. */

	/* Compute sp[i] = ntt(sp[i]). */
	bn.wsrr    w16, mod /* mod = R | Q */
	bn.shv.16h w0, w16 << 1 /* w0 = 2*R | 2*Q */
	bn.wsrw    mod, w0 /* mod = 2*R | 2*Q */
	add        a0, s8, 0 /* sp[i] */
	la         a1, twiddles_ntt
	add        a2, a0, 0
	loop s4, 2
		jal x1, ntt
		nop

	/* Compute v += pk * sp[i]. */
	la   s0, poly_pk
	addi a1, s8, 0 /* sp[i] */
	la   a2, twiddles_basemul
	la   a3, mpoly_v
	loop s4, 3
		addi a0, s0, 0
		jal  x1, basemul_acc
		nop
	addi    s8, a1, 0 /* Point to mpolyvec_sp[i + 1]. */
	bn.wsrw mod, w16 /* mod = R | Q */

_handle_k3_compute_v:
	/* Generate sp[i]. */
	addi a0, s6, 0 /* eta = ETA1 */
	addi a1, s8, 0 /* sp[i] */
	jal  x1, masked_poly_getnoise_eta_1

	/* Prepare for generating sp[i + 1]. */
	addi a0, s2, 0 /* coins */
	la   a1, nonce
	lw   t0, 0(a1)
	addi t0, t0, 1
	sw   t0, 0(a1)
	jal  x1, poly_getnoise_eta_init

	/* Unpack pk[i]. */
	addi a0, s1, 0
	la   a1, poly_pk
	jal  x1, poly_frombytes
	addi s1, a0, 0 /* Save address of pk to be unpacked later. */

	/* Compute sp[i] = ntt(sp[i]). */
	bn.wsrr    w16, mod /* mod = R | Q */
	bn.shv.16h w0, w16 << 1 /* w0 = 2*R | 2*Q */
	bn.wsrw    mod, w0 /* mod = 2*R | 2*Q */
	add        a0, s8, 0 /* sp[i] */
	la         a1, twiddles_ntt
	add        a2, a0, 0
	loop s4, 2
		jal x1, ntt
		nop

	/* Compute v += pk * sp[i]. */
	la   s0, poly_pk
	addi a1, s8, 0 /* sp[i] */
	la   a2, twiddles_basemul
	la   a3, mpoly_v
	loop s4, 3
		addi a0, s0, 0
		jal  x1, basemul_acc
		nop
	addi    s8, a1, 0 /* Point to mpolyvec_sp[i + 1]. */
	bn.wsrw mod, w16 /* mod = R | Q */

_handle_k2_compute_v:
	/* Generate sp[k - 1]. */
	addi a0, s6, 0 /* eta = ETA1 */
	addi a1, s8, 0 /* sp[k - 1] */
	jal  x1, masked_poly_getnoise_eta_1

	/* Prepare for initial `poly_getnoise_eta_2` call: generate epp. */
	addi a0, s2, 0 /* coins */
	slli t0, s5, 1 /* 2 * k */
	la   a1, nonce
	sw   t0, 0(a1)
	jal  x1, poly_getnoise_eta_init

	/* Compute sp[k - 1] = ntt(sp[k - 1]). */
	bn.wsrr    w16, mod /* mod = R | Q */
	bn.shv.16h w0, w16 << 1 /* w0 = 2*R | 2*Q */
	bn.wsrw    mod, w0 /* mod = 2*R | 2*Q */
	add        a0, s8, 0 /* sp[k - 1] */
	la         a1, twiddles_ntt
	add        a2, a0, 0 /* Output inplace. */
	loop s4, 2
		jal  x1, ntt
		nop

	/* Unpack pk[k - 1]. */
	addi a0, s1, 0
	la   a1, poly_pk
	jal  x1, poly_frombytes
	addi s1, a0, 0 /* seed */

	/* Compute v += pk * sp[k - 1]. */
	la   s0, poly_pk
	addi a1, s8, 0 /* sp[k - 1] */
	la   a2, twiddles_basemul
	la   a3, mpoly_v
	loop s4, 3
		addi a0, s0, 0
		jal  x1, basemul_acc
		nop

	/* Compute v = intt(v). */
	la   a0, mpoly_v
	la   a1, twiddles_intt
	addi a2, a0, 0
	loop s4, 2
		jal x1, intt
		nop
	bn.wsrw mod, w16 /* Restore mod = R | Q */

	/* Compute v += k. */
	la   a0, mpoly_v
	la   a1, mpoly_k
	addi a2, a0, 0
	loop s4, 2
		jal x1, poly_add
		nop

	/* Generate epp. */
	addi a0, x0, 2 /* eta = ETA2 = 2 */
	la   a1, mpoly_epp
	jal  x1, masked_poly_getnoise_eta_2

	/* Prepare for initial `poly_getnoise_eta_2` call: generate ep. */
	addi a0, s2, 0 /* coins */
	la   a1, nonce
	sw   s5, 0(a1)
	jal  x1, poly_getnoise_eta_init

	/* Compute v += epp. */
	la   a0, mpoly_v
	la   a1, mpoly_epp
	addi a2, a0, 0
	loop s4, 2
		jal x1, poly_add
		nop

	/* Generate ep[0]. */
	addi a0, x0, 2 /* eta = ETA2 = 2 */
	la   a1, mpoly_ep
	jal  x1, masked_poly_getnoise_eta_2

	/* Prepare for generating at[0][0]. */
	addi   a0, s1, 0 /* seed */
	la     a1, seed_ij
	bn.xor w0, w0, w0
	bn.sid x0, 0(a1)
	jal    x1, poly_gen_matrix_init

	/* Compare v and ct[k * POLY_POLYVECDECOMPRESSED_BYTES]. Output to r. */
	la   a0, mpoly_v
	addi a1, s3, 0 /* ct */
	loop s5, 1
		add a1, a1, s11
    lw   a2, 12(fp) /* dv */
    addi a3, s4, 0 /* nshares */
    lw   a4, 8(fp) /* r */
	addi a5, s5, 0 /* k */
    jal  x1, poly_compare_bgr21

	/* Compute tb = secand_isw03(twb, txb, nshares, 1, 32). */
	lw   a0, 8(fp) /* ptr_twb */
	lw   a1, 4(fp) /* ptr_txb */
	addi a2, s4, 0 /* nshares */
	addi a3, a0, 0 /* ptr_twb */
	addi a4, x0, 1
	addi a5, x0, 32
	jal  x1, secand_isw03

	/* Compute r = secand_isw03(r, tb, nshares, 1, 32). */
	addi a0, sp, 0 /* ptr_r */
	lw   a1, 8(fp) /* ptr_twb */
	addi a2, s4, 0 /* nshares */
	addi a3, a0, 0 /* ptr_r */
	addi a4, x0, 1
	addi a5, x0, 32
	jal  x1, secand_isw03

	/**************************************************************************/


	/* The following block will:
	 *	(1) sample at.row[i],
	 *	(2) compute b = at.row[i] * sp[i],
	 *	(3) compute b = intt(b),
	 *	(4) sample ep[i]
	 *	(5) compute b += ep[i]
	 *	(6) compare b and ct, output to r. */
	/**************************************************************************/

	/* At this point:
	 * 	- s0 is free.
	 *	- s1 points to seed (for matrix generation).
	 * 	- s2 points to coins (for cbd).
	 *	- s3 points to ct (for unpacking).
	 *	- s4 = nshares.
	 *	- s5 is the security level k.
	 * 	- s6 is free.
	 *	- s7 is free.
	 *	- s8 is free. */

	addi x4, x0, 2
	beq  s5, x4, _handle_k2_compute_b

_handle_kn2_compute_b:

	addi s0, s5, -1 /* k - 1 */
	addi s5, s5, -2 /* k - 2 */
	slli s7, s0, 8 /* (k - 1) * 0x0100 */
	addi s7, s7, -1

	loop s0, 130
		/* Generate at[i][0]. */
		la   a1, poly_at
		jal  x1, poly_gen_matrix

		/* Prepare for generating at[i][1]. */
		addi a0, s1, 0 /* seed */
		la   a1, seed_ij
		lw   x4, 0(a1)
		addi x4, x4, 0x0100
		sw   x4, 0(a1)
		jal  x1, poly_gen_matrix_init

		/* Compute b = at[i][0] * sp[0]. */
		bn.wsrr    w16, mod /* mod = R | Q */
		bn.shv.16h w0, w16 << 1 /* w16 = 2*R | 2*Q */
		bn.wsrw    mod, w0 /* mod = 2*R | 2*Q */
		la         s6, poly_at
		addi       a0, s6, 0
		la         a1, mpolyvec_sp
		la         a2, twiddles_basemul
		la         a3, mpoly_b
		loop s4, 2
			jal  x1, basemul
			addi a0, s6, 0
		addi    s8, a1, 0 /* sp[1] */
		bn.wsrw mod, w16 /* Restore mod = R | Q. */

		loop s5, 26
			/* Generate at[i][1]. */
			la   a1, poly_at
			jal  x1, poly_gen_matrix

			/* Prepare for generating at[i][2]. */
			addi a0, s1, 0 /* seed */
			la   a1, seed_ij
			lw   x4, 0(a1)
			addi x4, x4, 0x0100
			sw   x4, 0(a1)
			jal  x1, poly_gen_matrix_init

			/* Compute b += at[i][1] * sp[1]. */
			bn.wsrr    w16, mod /* mod = R | Q */
			bn.shv.16h w0, w16 << 1 /* w16 = 2*R | 2*Q */
			bn.wsrw    mod, w0 /* mod = 2*R | 2*Q */
			la         s6, poly_at
			addi       a0, s6, 0
			addi       a1, s8, 0 /* sp[j] */
			la         a2, twiddles_basemul
			la         a3, mpoly_b
			loop s4, 2
				jal  x1, basemul_acc
				addi a0, s6, 0 /* poly_at */
			addi    s8, a1, 0 /* sp[j + 1] */
			bn.wsrw mod, w16 /* Restore mod = R | Q. */

		/* Generate at[i][k - 1]. */
		la   a1, poly_at
		jal  x1, poly_gen_matrix

		/* Compute b += at[i][k - 1] * sp[k - 1]. */
		bn.wsrr    w16, mod /* mod = R | Q */
		bn.shv.16h w0, w16 << 1 /* w16 = 2*R | 2*Q */
		bn.wsrw    mod, w0 /* mod = 2*R | 2*Q */
		la         s6, poly_at
		addi       a0, s6, 0
		addi       a1, s8, 0 /* sp[k - 1] */
		la         a2, twiddles_basemul
		la         a3, mpoly_b
		loop s4, 2
			jal  x1, basemul_acc
			addi a0, s6, 0 /* poly_at */

		/* Compute b = intt(b). */
		la   a0, mpoly_b
		la   a1, twiddles_intt
		addi a2, a0, 0
		loop s4, 2
			jal x1, intt
			nop
		bn.wsrw mod, w16 /* Restore mod = R | Q. */

		/* Prepare for generating ep[i + 1]. */
		addi a0, s2, 0 /* coins */
		la   a1, nonce
		lw   t0, 0(a1)
		addi t0, t0, 1
		sw   t0, 0(a1)
		jal  x1, poly_getnoise_eta_init

		/* Compute b += ep. */
		la   a0, mpoly_b
		la   a1, mpoly_ep
		addi a2, a0, 0
		loop s4, 2
			jal x1, poly_add
			nop

		/* Generate ep[i + 1]. */
		addi a0, x0, 2 /* eta = ETA2 = 2 */
		la   a1, mpoly_ep
		jal  x1, masked_poly_getnoise_eta_2

		/* Prepare for generating at[i + 1][0]. */
		addi a0, s1, 0 /* seed */
		la   a1, seed_ij
		lw   t0, 0(a1)
		sub  t0, t0, s7
		sw   t0, 0(a1)
		jal  x1, poly_gen_matrix_init

		/* Compare b and ct[i * POLY_POLYVECDECOMPRESSED_BYTES : (i + 1) * POLY_POLYVECDECOMPRESSED_BYTES].
		 * Accumulate output to r. */
		la   a0, mpoly_b
		addi a1, s3, 0 /* ct */
		lw   a2, 16(fp) /* du */
		addi a3, s4, 0 /* nshares */
		lw   a4, 8(fp) /* twb */
		addi a5, s5, 2 /* k */
		jal  x1, poly_compare_bgr21
		add  s3, s3, s11 /* ct[(i + 1) * POLY_POLYVECDECOMPRESSED_BYTES : (i + 2) * POLY_POLYVECDECOMPRESSED_BYTES]  */

		/* Compute tb = secand_isw03(twb, txb, nshares, 1, 32). */
		lw   a0, 8(fp) /* ptr_twb */
		lw   a1, 4(fp) /* ptr_txb */
		addi a2, s4, 0 /* nshares */
		addi a3, a0, 0 /* ptr_twb */
		addi a4, x0, 1
		addi a5, x0, 32
		jal  x1, secand_isw03

		/* Compute r = secand_isw03(r, tb, nshares, 1, 32). */
		addi a0, sp, 0 /* ptr_r */
		lw   a1, 8(fp) /* ptr_twb */
		addi a2, s4, 0 /* nshares */
		addi a3, a0, 0 /* ptr_r */
		addi a4, x0, 1
		addi a5, x0, 32
		jal  x1, secand_isw03
		nop

    /* Generate at[k - 1][0]. */
	la   a1, poly_at
	jal  x1, poly_gen_matrix

	/* Prepare for generating at[k - 1][1]. */
	addi a0, s1, 0 /* seed */
	la   a1, seed_ij
	lw   x4, 0(a1)
	addi x4, x4, 0x0100
	sw   x4, 0(a1)
	jal  x1, poly_gen_matrix_init

	/* Compute b = at[k - 1][0] * sp[0]. */
	bn.wsrr    w16, mod /* mod = R | Q */
	bn.shv.16h w0, w16 << 1 /* w0 = 2*R | 2*Q */
	bn.wsrw    mod, w0 /* mod = 2*R | 2*Q */
	la         s6, poly_at
	addi       a0, s6, 0
	la         a1, mpolyvec_sp
	la         a2, twiddles_basemul
	la         a3, mpoly_b
	loop s4, 2
		jal  x1, basemul
		addi a0, s6, 0 /* poly_at */
	addi    s8, a1, 0 /* sp[1] */
	bn.wsrw mod, w16 /* Restore mod = R | Q. */

	loop s5, 26
		/* Generate at[i][j]. */
		la   a1, poly_at
		jal  x1, poly_gen_matrix

		/* Prepare for generating at[i][j]. */
		addi a0, s1, 0 /* seed */
		la   a1, seed_ij
		lw   x4, 0(a1)
		addi x4, x4, 0x0100
		sw   x4, 0(a1)
		jal  x1, poly_gen_matrix_init

		/* Compute b += at[i][j] * sp[j]. */
		bn.wsrr    w16, mod /* mod = R | Q */
		bn.shv.16h w0, w16 << 1 /* w0 = 2*R | 2*Q */
		bn.wsrw    mod, w0 /* mod = 2*R | 2*Q */
		la         s6, poly_at
		addi       a0, s6, 0
		addi       a1, s8, 0 /* sp[j] */
		la         a2, twiddles_basemul
		la         a3, mpoly_b
		loop s4, 2
			jal  x1, basemul_acc
			addi a0, s6, 0
		addi    s8, a1, 0 /* sp[j + 1] */
		bn.wsrw mod, w16 /* Restore mod = R | Q. */

	/* Generate at[k - 1][k - 1]. */
	la   a1, poly_at
	jal  x1, poly_gen_matrix

	/* Compute b += at[k - 1][k - 1] * sp[k - 1]. */
	bn.wsrr    w16, mod /* mod = R | Q */
	bn.shv.16h w0, w16 << 1 /* w0 = 2*R | 2*Q */
	bn.wsrw    mod, w0 /* mod = 2*R | 2*Q */
	la         s6, poly_at
	addi       a0, s6, 0 /* poly_at */
	addi       a1, s8, 0 /* sp[k - 1] */
	la         a2, twiddles_basemul
	la         a3, mpoly_b
	loop s4, 2
		jal  x1, basemul_acc
		addi a0, s6, 0 /* poly_at */

	/* Compute b = intt(b). */
	la   a0, mpoly_b
	la   a1, twiddles_intt
	addi a2, a0, 0
	loop s4, 2
		jal x1, intt
		nop
	bn.wsrw mod, w16 /* Restore mod = R | Q. */

	/* Compute b += ep. */
	la   a0, mpoly_b
	la   a1, mpoly_ep
	addi a2, a0, 0
	loop s4, 2
		jal x1, poly_add
		nop

	/* Compare b and ct[i * POLY_POLYVECDECOMPRESSED_BYTES : (i + 1) * POLY_POLYVECDECOMPRESSED_BYTES].
	 * Accumulate output to r. */
	la   a0, mpoly_b
	addi a1, s3, 0 /* ct */
	lw   a2, 16(fp) /* du */
	addi a3, s4, 0 /* nshares */
	lw   a4, 8(fp) /* twb */
	addi a5, s5, 2 /* k */
	jal  x1, poly_compare_bgr21

	/* Compute tb = secand_isw03(twb, txb, nshares, 1, 32). */
	lw   a0, 8(fp) /* ptr_twb */
	lw   a1, 4(fp) /* ptr_txb */
	addi a2, s4, 0 /* nshares */
	addi a3, a0, 0 /* ptr_twb */
	addi a4, x0, 1
	addi a5, x0, 32
	jal  x1, secand_isw03

	/* Compute r = secand_isw03(r, tb, nshares, 1, 32). */
	addi a0, sp, 0 /* ptr_r */
	lw   a1, 8(fp) /* ptr_twb */
	addi a2, s4, 0 /* nshares */
	addi a3, a0, 0 /* ptr_r */
	addi a4, x0, 1
	addi a5, x0, 32
	jal  x1, secand_isw03
	/**************************************************************************/
	beq  x0, x0, _finalize_compare

_handle_k2_compute_b:
	/* Generate at[0][0]. */
	la  a1, poly_at
	jal x1, poly_gen_matrix

	/* Prepare for generating at[0][1]. */
	addi a0, s1, 0 /* seed */
	la   a1, seed_ij
	lw   x4, 0(a1)
	addi x4, x4, 0x0100
	sw   x4, 0(a1)
	jal  x1, poly_gen_matrix_init

	/* Compute b = at[0][0] * sp[0]. */
	bn.wsrr    w16, mod /* mod = R | Q */
	bn.shv.16h w0, w16 << 1 /* w0 = 2*R | 2*Q */
	bn.wsrw    mod, w0 /* mod = 2*R | 2*Q */
	la         s6, poly_at
	la         a1, mpolyvec_sp
	la         a2, twiddles_basemul
	la         a3, mpoly_b
	loop s4, 3
		addi a0, s6, 0 /* poly_at */
		jal  x1, basemul
		nop
	addi    s8, a1, 0 /* sp[1] */
	bn.wsrw mod, w16 /* Restore mod = R | Q. */

	/* Generate at[0][1]. */
	la  a1, poly_at
	jal x1, poly_gen_matrix

	/* Compute b += at[0][1] * sp[1]. */
	bn.wsrr    w16, mod /* mod = R | Q */
	bn.shv.16h w0, w16 << 1 /* w0 = 2*R | 2*Q */
	bn.wsrw    mod, w0 /* mod = 2*R | 2*Q */
	la         s6, poly_at
	addi       a1, s8, 0 /* sp[1] */
	la         a2, twiddles_basemul
	la         a3, mpoly_b
	loop s4, 3
		addi a0, s6, 0
		jal  x1, basemul_acc
		nop

	/* Compute b = intt(b). */
	la   a0, mpoly_b
	la   a1, twiddles_intt
	addi a2, a0, 0
	loop s4, 2
		jal x1, intt
		nop
	bn.wsrw mod, w16 /* Restore mod = R | Q. */

	/* Prepare for generating ep[1]. */
	addi a0, s2, 0 /* coins */
	la   a1, nonce
	lw   t0, 0(a1)
	addi t0, t0, 1
	sw   t0, 0(a1)
	jal  x1, poly_getnoise_eta_init

	/* Compute b += ep. */
	la   a0, mpoly_b
	la   a1, mpoly_ep
	addi a2, a0, 0
	loop s4, 2
		jal x1, poly_add
		nop

	/* Generate ep[1]. */
	addi a0, x0, 2 /* eta = ETA2 = 2 */
	la   a1, mpoly_ep
	jal  x1, masked_poly_getnoise_eta_2

	/* Prepare for generating at[1][0]. */
	addi a0, s1, 0 /* seed */
	la   a1, seed_ij
	addi t0, x0, 1
	sw   t0, 0(a1)
	jal  x1, poly_gen_matrix_init

	/* Compare b and ct[i * POLY_POLYVECDECOMPRESSED_BYTES : (i + 1) * POLY_POLYVECDECOMPRESSED_BYTES].
	* Accumulate output to r. */
	la   a0, mpoly_b
	addi a1, s3, 0 /* ct */
	lw   a2, 16(fp) /* du */
	addi a3, s4, 0 /* nshares */
	lw   a4, 8(fp) /* twb */
	addi a5, s5, 0 /* k */
	jal  x1, poly_compare_bgr21

	/* Compute tb = secand_isw03(twb, txb, nshares, 1, 32). */
	lw   a0, 8(fp) /* ptr_twb */
	lw   a1, 4(fp) /* ptr_txb */
	addi a2, s4, 0 /* nshares */
	addi a3, a0, 0 /* ptr_twb */
	addi a4, x0, 1
	addi a5, x0, 32
	jal  x1, secand_isw03

	/* Compute r = secand_isw03(r, tb, nshares, 1, 32). */
	addi a0, sp, 0 /* ptr_r */
	lw   a1, 8(fp) /* ptr_twb */
	addi a2, s4, 0 /* nshares */
	addi a3, a0, 0 /* ptr_r */
	addi a4, x0, 1
	addi a5, x0, 32
	jal  x1, secand_isw03

    /* Generate at[1][0]. */
	la  a1, poly_at
	jal x1, poly_gen_matrix

	/* Prepare for generating at[1][1]. */
	addi a0, s1, 0 /* seed */
	la   a1, seed_ij
	lw   x4, 0(a1)
	addi x4, x4, 0x0100
	sw   x4, 0(a1)
	jal  x1, poly_gen_matrix_init

	/* Compute b = at[1][0] * sp[0]. */
	bn.wsrr    w16, mod /* mod = R | Q */
	bn.shv.16h w0, w16 << 1 /* w0 = 2*R | 2*Q */
	bn.wsrw    mod, w0 /* mod = 2*R | 2*Q */
	la         s6, poly_at
	la         a1, mpolyvec_sp
	la         a2, twiddles_basemul
	la         a3, mpoly_b
	loop s4, 3
		addi a0, s6, 0
		jal  x1, basemul
		nop
	addi    s8, a1, 0 /* sp[1] */
	bn.wsrw mod, w16 /* Restore mod = R | Q. */

	/* Generate at[1][1]. */
	la  a1, poly_at
	jal x1, poly_gen_matrix

	/* Compute b += at[1][1] * sp[1]. */
	bn.wsrr    w16, mod /* mod = R | Q */
	bn.shv.16h w0, w16 << 1 /* w0 = 2*R | 2*Q */
	bn.wsrw    mod, w0 /* mod = 2*R | 2*Q */
	la         s6, poly_at
	addi       a1, s8, 0 /* sp[1] */
	la         a2, twiddles_basemul
	la         a3, mpoly_b
	loop s4, 3
		addi a0, s6, 0
		jal  x1, basemul_acc
		nop

	/* Compute b = intt(b). */
	la   a0, mpoly_b
	la   a1, twiddles_intt
	addi a2, a0, 0
	loop s4, 2
		jal x1, intt
		nop
	bn.wsrw mod, w16 /* Restore mod = R | Q. */

	/* Compute b += ep. */
	la   a0, mpoly_b
	la   a1, mpoly_ep
	addi a2, a0, 0
	loop s4, 2
		jal x1, poly_add
		nop

	/* Compare b and ct[i * POLY_POLYVECDECOMPRESSED_BYTES : (i + 1) * POLY_POLYVECDECOMPRESSED_BYTES].
	* Accumulate output to r. */
	la   a0, mpoly_b
	addi a1, s3, 320 /* ct */
	lw   a2, 16(fp) /* du */
	addi a3, s4, 0 /* nshares */
	lw   a4, 8(fp) /* twb */
	addi a5, s5, 0 /* k */
	jal  x1, poly_compare_bgr21

	/* Compute tb = secand_isw03(twb, txb, nshares, 1, 32). */
	lw   a0, 8(fp) /* ptr_twb */
	lw   a1, 4(fp) /* ptr_txb */
	addi a2, s4, 0 /* nshares */
	addi a3, a0, 0 /* ptr_twb */
	addi a4, x0, 1
	addi a5, x0, 32
	jal  x1, secand_isw03

	/* Compute r = secand_isw03(r, tb, nshares, 1, 32). */
	addi a0, sp, 0 /* ptr_r */
	lw   a1, 8(fp) /* ptr_twb */
	addi a2, s4, 0 /* nshares */
	addi a3, a0, 0 /* ptr_r */
	addi a4, x0, 1
	addi a5, x0, 32
	jal  x1, secand_isw03
	/**************************************************************************/

_finalize_compare:

	/* Finalize the comparison result. */
    addi a0, sp, 0 /* r */
    addi a1, s4, 0 /* nshares */
    jal  x1, finalize_cmp_bc22

    /* Unmask comparison result. */
    addi   a0, sp, 0 /* r */
    bn.lid x0, 0(a0++)
    addi   t0, s4, -1 /* nshares - 1 */
    addi   x4, x0, 1
    loop t0, 2
        bn.lid x4, 0(a0++)
        bn.xor w0, w0, w1

    /* Restore sp and fp. */
    addi sp, fp, 0
    lw   fp, 0(sp)
    addi sp, sp, 32
  	ret
