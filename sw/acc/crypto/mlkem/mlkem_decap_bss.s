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

/* Shared key output address. */
.balign 4
.globl dptr_ss
dptr_ss:
	.zero 4

/* Length of the public ciphertext depending on the security level. */
.balign 4
.globl ctbytes
ctbytes:
	.zero 4

/* The security level KYBER_K. */
.balign 4
.globl k
k:
    .zero 4

/* Nonce intermediate value used for cbd (32 bytes). */
.balign 32
.globl nonce
nonce:
    .zero 32

/* Bytes i || j used in matrix generation (32 bytes). */
.balign 32
.globl seed_ij
seed_ij:
    .zero 32

.balign 32
.globl poly_b
.globl poly_v
.globl poly_pk
.globl poly_at
poly_b:
poly_v:
poly_pk:
poly_at:
    .zero 512

.balign 32
.globl mpoly_m
.globl mpoly_v
.globl mpoly_b
mpoly_m:
mpoly_v:
mpoly_b:
    .zero 512 * NSHARES

.balign 32
.globl mpoly_k
.globl mpoly_epp
.globl mpoly_ep
mpoly_k:
mpoly_ep:
mpoly_epp:
    .zero 512 * NSHARES

.balign 32
.globl mpoly_sk
.globl mpolyvec_sp
mpoly_sk:
mpolyvec_sp:
    .zero 512 * NSHARES * KYBER_K

/* Message output of indcpa_dec intermediate value (32 * NSHARES bytes). */
.balign 32
.globl m
m:
	.zero 32 * NSHARES

.balign 32
.globl mtmp
.globl ss_false
mtmp:
ss_false:
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
