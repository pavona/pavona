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

#ifdef HARDENED
#define NSHARES 2
#else
#define NSHARES 1
#endif

/* Register aliases */
.equ x2, sp
.equ x3, fp
.equ x5, t0
#define t1 x6
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


/* Config to start a SHAKE-256 operation. */
#define SHAKE256_CFG 0xA
/* Config to start a SHA3_512 operation. */
#define SHA3_512_CFG 0x10

/*
 * Name:        crypto_kem_dec
 *
 * Description: Generates shared secret for given
 *              cipher text and private key
 *
 * Flags: -.
 *
 * @param[in]  x10 (a0): dmem pointer to input ct
 * @param[in]  x11 (a1): dmem pointer to input sk
 * @param[out] x12 (a2): dmem pointer to output key_a
 * @param[in]  x13 (a3): k, the security level
 * @param[in]  w31: all-zero register
 *
 * clobbered registers: a0-a4, t0-t5, w8, w16
 */
.globl crypto_kem_dec
.type crypto_kem_dec, @function
crypto_kem_dec:
	addi x4, x0, 2
	beq  a3, x4, _save_k2_ptrs
	addi x4, x0, 3
	beq  a3, x4, _save_k3_ptrs

	/* Save input and output addresses. */
	/* Public ciphertext. */
	la t0, dptr_ct
	sw a0, 0(t0)
	/* Public key for PKE.Enc. */
	addi t1, a1, 0
	loopi NSHARES, 1
		addi t1, t1, 1536
	endloop
	la t0, dptr_pk
	sw t1, 0(t0)
	/* H(pk). */
	addi t1, t1, 1568
	la   t0, dptr_h
	sw   t1, 0(t0)
	/* Shared key. */
	la t0, dptr_ss
	sw a2, 0(t0)
	/* k. */
	la t0, k
	sw a3, 0(t0)
	/* Ciphertext bytes. */
	la   t0, ctbytes
	addi t1, x0, 1568
	sw   t1, 0(t0)

	beq  x0, x0, _continue

_save_k2_ptrs:
	/* Save input and output addresses. */
	/* Public ciphertext. */
	la t0, dptr_ct
	sw a0, 0(t0)
	/* Public key for PKE.Enc. */
	addi t1, a1, 0
	loopi NSHARES, 1
		addi t1, t1, 768
	endloop
	la t0, dptr_pk
	sw t1, 0(t0)
	/* H(pk). */
	addi t1, t1, 800
	la   t0, dptr_h
	sw   t1, 0(t0)
	/* Shared key. */
	la t0, dptr_ss
	sw a2, 0(t0)
	/* k. */
	la t0, k
	sw a3, 0(t0)
	/* Ciphertext bytes. */
	la   t0, ctbytes
	addi t1, x0, 768
	sw   t1, 0(t0)

	beq  x0, x0, _continue

_save_k3_ptrs:
	/* Save input and output addresses. */
	/* Public ciphertext. */
	la t0, dptr_ct
	sw a0, 0(t0)
	/* Public key for PKE.Enc. */
	addi t1, a1, 0
	loopi NSHARES, 1
		addi t1, t1, 1152
	endloop
	la t0, dptr_pk
	sw t1, 0(t0)
	/* H(pk). */
	addi t1, t1, 1184
	la   t0, dptr_h
	sw   t1, 0(t0)
	/* Shared key. */
	la t0, dptr_ss
	sw a2, 0(t0)
	/* k. */
	la t0, k
	sw a3, 0(t0)
	/* Ciphertext bytes. */
	la   t0, ctbytes
	addi t1, x0, 1088
	sw   t1, 0(t0)

_continue:

#ifdef HARDENED
	/* Refresh z's Boolean shares; clobbers a0/a1, so stash/reload sk/ct. */
	addi s0, a1, 0
	la   a0, dptr_h
	lw   a0, 0(a0)
	addi a0, a0, 32
	addi a1, x0, 1
	addi a2, x0, 32
	addi a4, a0, 0
	jal  x1, refreshios
	la   t0, dptr_ct
	lw   a0, 0(t0)
	addi a1, s0, 0
#endif

	/* m = indcpa_dec(ct, sk). */
	la  a2, m
	jal x1, indcpa_dec

#ifdef HARDENED
	/* Since the output message of indcpa_dec is in a special order due
	 * to performance reason for masked_poly_tomsg gagdet, we reorder the
	 * message m here before hashing it. Note that the re-ordered message is
	 * put elsewhere, not in buffer for m again. Otherwise, the re-encryption
	 * will fail since the masked one-bit decompression gadget takes into
	 * account the special order of the message m. */
	la t0, m
	la t1, mtmp
	li x4, 3
	loopi 2, 11
		/* Whitening. */
		bn.xor w0, w0, w0
		bn.xor w1, w1, w1
		bn.xor w3, w3, w3
		bn.lid x0, 0(t0++)
		loopi 16, 5
			bn.shv.16h w1, w0 >> 15
			loopi 16, 2
				bn.rshi w3, w1, w3 >> 1
				bn.rshi w1, w31, w1 >> 16
			endloop
			bn.shv.16h w0, w0 << 1
		endloop
		bn.sid x4, 0(t1++)
	endloop

	/* Compute kr = hash_g(m || h). */
	la      t0, dptr_h
	lw      t0, 0(t0)
	addi    x4, x0, 1
	bn.lid  x4, 0(t0)
	/* Send the message to KMAC. */
	addi    t0, x0, 64
	slli    t0, t0, 5
	addi    t0, t0, SHA3_512_CFG
	addi    t1, x0, 1
	slli    t1, t1, 20
	add     t0, t0, t1
	csrrw   x0, kmac_cfg, t0
	/* Send m. */
	la      t1, mtmp
	bn.xor  w0, w0, w0 /* Whitening. */
	bn.lid  x0, 0(t1++)
	bn.wsrw kmac_msg, w0 /* m[0] */
	bn.xor  w0, w0, w0 /* Whitening. */
	bn.lid  x0, 0(t1)
	bn.wsrw kmac_msg1, w0 /* m[1] */
	/* Send h. */
	bn.wsrw kmac_msg, w1 /* h */
	bn.xor  w1, w1, w1
	bn.wsrw kmac_msg1, w1 /* 0 */
	/* Retrieve output. We keep the ephemeral shared key in masked form. */
	la      t0, kr
	bn.xor  w0, w0, w0 /* Whitening. */
	bn.wsrr w0, kmac_digest
	bn.sid  x0, 0(t0++)
	bn.xor  w0, w0, w0 /* Whitening. */
	bn.wsrr w0, kmac_digest1
	bn.sid  x0, 0(t0++)
	bn.xor  w0, w0, w0 /* Whitening. */
	bn.wsrr w0, kmac_digest
	bn.sid  x0, 0(t0++)
	bn.xor  w0, w0, w0 /* Whitening. */
	bn.wsrr w0, kmac_digest1
	bn.sid  x0, 0(t0++)

#else
	/* Compute kr = hash_g(m || h). */
	/* Send the message to KMAC. */
	addi    t0, x0, 64
	slli    t0, t0, 5
	addi    t0, t0, SHA3_512_CFG
	csrrw   x0, kmac_cfg, t0
	la      t0, m
	bn.lid  x0, 0(t0)
	bn.wsrw kmac_msg, w0 /* m */
	la      t0, dptr_h
	lw      t0, 0(t0)
	bn.lid  x0, 0(t0)
	bn.wsrw kmac_msg, w0 /* h */

	la      t0, kr
	bn.wsrr w0, kmac_digest
	bn.sid  x0, 0(t0++)
	bn.wsrr w0, kmac_digest
	bn.sid  x0, 0(t0++)
#endif

	/*** shake256(z||c,32) ***/
	addi    a1, x0, 32
	la      t0, ctbytes
	lw      t0, 0(t0)
	add     a1, a1, t0
	slli    t0, a1, 5
	addi    t0, t0, SHAKE256_CFG
#ifdef HARDENED
	addi    t1, x0, 1
	slli    t1, t1, 20
	add     t0, t0, t1
#endif
	csrrw   x0, kmac_cfg, t0
	/* z */
	la      t0, dptr_h
	lw      t0, 0(t0)
	bn.lid  x0, 32(t0)
	bn.wsrw kmac_msg, w0
#ifdef HARDENED
	bn.xor  w0, w0, w0 /* Whitening. */
	bn.lid  x0, 64(t0)
	bn.wsrw kmac_msg1, w0
#endif

	/* c */
	la   t0, dptr_ct
	lw   a0, 0(t0)
	la   t0, ctbytes
	lw   t0, 0(t0)
	add  a1, x0, t0
#ifdef HARDENED
	srli t0, a1, 5
	loop t0, 3
		bn.lid  x0, 0(a0++)
		bn.wsrw kmac_msg, w0
		bn.wsrw kmac_msg1, w31
	endloop
	la      t0, ss_false
	bn.xor  w0, w0, w0 /* Whitening. */
	bn.wsrr w0, kmac_digest
	bn.sid  x0, 0(t0++)
	bn.xor  w0, w0, w0 /* Whitening. */
	bn.wsrr w0, kmac_digest1
	bn.sid  x0, 0(t0)
#else
	jal  x1, keccak_send_message
	/* output buffer */
	la      t0, ss_false
	bn.wsrr w0, kmac_digest
	bn.sid  x0, 0(t0)
#endif

	/* Compute re-encryption and compare the re-encrypted ciphertext with the
	 * public ciphertext. w0 contains the comparison result. */
	la   a0, m
	la   t0, dptr_pk
	lw   a1, 0(t0)
	la   a2, kr /* coins */
#ifdef HARDENED
	addi a2, a2, 64
#else
	addi a2, a2, 32
#endif
	la   t0, dptr_ct
	lw   a3, 0(t0)
	addi a4, x0, NSHARES
	la   t0, k
	lw   a5, 0(t0)
	jal  x1, indcpa_enc_cmp

#ifndef HARDENED
	/*** cmov ***/
	la      t0, kr
	addi    x4, x0, 1
	bn.lid  x4++, 0(t0) /* load true key */
	la      t0, ss_false
	bn.lid  x4, 0(t0) /* load false key */
	bn.xor  w3, w1, w2
	bn.and  w3, w3, w0 /* w0 is the comparison result: 0 if equal, all ones otherwise. */
	bn.xor  w0, w1, w3
	la      t0, dptr_ss
	lw      t0, 0(t0)
	bn.sid  x0, 0(t0)
	ret
#else
	/*** cmov ***/
	la      t0, kr
	la      t1, dptr_ss
	lw      t1, 0(t1)
	la      t2, ss_false
	addi    x4, x0, 1
	bn.xor  w1, w1, w1
	bn.addi w1, w1, 1
	bn.cmp  w0, w1
	csrrw   t3, fg0, x0
	srli    t3, t3, 3 /* extract z flag */
	beq     t3, x0, _fail
	bn.lid  x0, 0(t0)
	bn.lid  x4, 32(t0)
	beq     x0, x0, _end
_fail:
	bn.lid  x0, 0(t2)
	bn.lid  x4, 32(t2)
	beq     x0, x0, _end
_end:
	bn.sid  x0, 0(t1)
	bn.sid  x4, 32(t1)
	ret

#endif
