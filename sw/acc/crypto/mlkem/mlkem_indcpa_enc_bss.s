/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.bss

/* Intermediate buffer to store the 64-byte hash result. */
.balign 32
.globl indcpa_enc_seed
indcpa_enc_seed:
.zero 64

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
.globl poly_pk
.globl poly_at
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
.globl mpolyvec_sp
mpolyvec_sp:
    .zero 512 * NSHARES * KYBER_K
