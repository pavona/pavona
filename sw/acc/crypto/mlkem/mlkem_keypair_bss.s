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
.balign 4
.globl dptr_pk
dptr_pk:
    .zero 4

.balign 4
.globl dptr_sk
dptr_sk:
    .zero 4

.balign 4
.globl k
k:
    .zero 4

.balign 4
.globl dptr_coins
dptr_coins:
    .zero 4

.balign 32
.globl buf
buf:
    .zero 32 + 32 * NSHARES

.balign 32
.globl nonce
nonce:
    .zero 32

.balign 32
.global seed_ij
seed_ij:
    .zero 32

.balign 32
.globl mpolyvec_sk
mpolyvec_sk:
    .zero 512 * NSHARES * KYBER_K

.balign 32
.globl mpoly_pk
mpoly_pk:
    .zero 512 * NSHARES

.balign 32
.globl poly_at
.globl mpoly_e
poly_at:
mpoly_e:
    .zero 512 * NSHARES
