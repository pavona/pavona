/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#ifndef KYBER_K
    #define KYBER_K 3
#endif
#ifndef NSHARES
    #define NSHARES 2
#endif

/* WARNING: This file should not be changed without understanding the code.
 * Otherwise, it will lead to failure of the tests. */

.bss

/* Ciphertext input address. */
.balign 4
.globl dptr_ct
dptr_ct:
	.zero 4

/* Message input address to PKE.Dec. */
/* Coins input address to PKE.Enc. */
.balign 4
.globl dptr_m
.globl dptr_coins
dptr_m:
dptr_coins:
	.zero 4

/* Public key address for PKE.Enc. */
.balign 4
.globl dptr_pk
dptr_pk:
    .zero 4

/* H(pk) address. */
.balign 4
.globl dptr_h
dptr_h:
	.zero 4

/* Number of shares. */
.balign 4
.globl dptr_nshares
dptr_nshares:
	.zero 4

/* Shared key output address. */
.balign 4
.globl dptr_ss
dptr_ss:
	.zero 4

/* Shared key output address. */
.balign 4
.globl dptr_mode
dptr_mode:
	.zero 4

/* Nonce intermediate value (32 bytes). */
.balign 32
.globl nonce
nonce:
    .zero 32

/* Seed intermediate value (32 bytes). */
.balign 32
.globl seed
seed:
    .zero 32

/* Shared buffer for intermediate polynomial. */
/* Vector of KYBER_K polynomial pkpv (KYBER_K * 512 bytes).  */
.balign 32
.globl poly_at
.globl poly_b
.globl poly_v
.globl pkpv
poly_at:
poly_b:
poly_v:
pkpv:
    .zero 512

/* Re-enc: masked polynomial sk intermediate value (512 * NSHARES bytes). */
/* Dec + Re-enc: Masked polynomial v intermediate value (512 * NSHARES bytes). */
.balign 32
.globl masked_poly_sk
.globl masked_poly_v
masked_poly_sk:
masked_poly_v:
    .zero 512 * NSHARES

.balign 32
.globl masked_poly_m
.globl masked_poly_k
.globl masked_poly_epp
.globl masked_polyvec_b
masked_poly_m:
masked_poly_k:
masked_poly_epp:
masked_polyvec_b:
    .zero 512 * NSHARES * KYBER_K

/* Masked polynomial sk.vec[i] intermediate value for i = 0,...,KYBER_K - 1 (512 * NSHARES bytes.) */
.globl masked_poly_ep
.globl masked_polyvec_sp
masked_poly_ep:
masked_polyvec_sp:
    .zero 512 * NSHARES * KYBER_K

/* Message output of indcpa_dec intermediate value (32 * NSHARES bytes). */
.balign 32
.globl m
m:
	.zero 32 * NSHARES

/* Output of SHA3-512 (64 bytes). */
.balign 32
.globl kr
kr:
    #if NSHARES == 2
	.zero 64 * NSHARES
    #else
    .zero 64
    #endif
