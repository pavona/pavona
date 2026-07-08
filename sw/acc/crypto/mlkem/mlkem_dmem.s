/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/*
 * ML-KEM DMEM layout for run_mlkem (unprotected) and run_mlkem_hardened
 * (-DHARDENED, masked): I/O buffers, the stack, and the union of the
 * per-operation working buffers, worst-case (ML-KEM-1024) sized and overlaid
 * so buffers used by disjoint operations share storage.
 */

#ifdef HARDENED
  #define NSHARES 2
#else
  #define NSHARES 1
#endif

/* Buffers are sized for the worst case (ML-KEM-1024). */
#define KYBER_K_MAX 4

.bss

/* Encapsulation key / public key (worst-case ML-KEM-1024 = 1568 bytes). */
.globl ek
.balign 32
ek:
  .zero 1568

/* Input random coins: d || z (64 bytes, two boolean shares each in the
 * HARDENED build) for keygen, the 32-byte message m for encap. */
.globl coins
.balign 32
coins:
#ifdef HARDENED
  .zero 128
#else
  .zero 64
#endif

.globl stack
.balign 32
stack:
#ifdef HARDENED
  .zero 16000 - 1568 - 128
#else
  .zero 16000 - 1568 - 64
#endif
.globl stack_end
stack_end:

/* Operation mode (one of MODE_*). */
.globl mode
.balign 4
mode:
  .zero 4

/* FIPS 203 Sec. 7.2/7.3 key-validation result for encapsulation/
 * decapsulation (HARDENED_BOOL_TRUE if the key passed check_pk/check_sk,
 * HARDENED_BOOL_FALSE otherwise). Zero (neither hardened-bool value) by
 * default, so a skipped write is treated as failure. Meaningless for
 * keygen. */
.globl key_ok
.balign 4
key_ok:
  .zero 4

/* Decapsulation key / secret key (worst-case ML-KEM-1024: 3168 bytes
 * plain, 4736 bytes masked). Keygen output / decap input. */
.globl dk
.balign 32
dk:
#ifdef HARDENED
  .zero 4736
#else
  .zero 3168
#endif

/* Ciphertext (worst-case ML-KEM-1024 = 1568 bytes). */
.globl ct
.balign 32
ct:
  .zero 1568

/* Shared secret: 32 bytes, or two 32-byte boolean shares for HARDENED
 * decap. */
.globl ss
.balign 32
ss:
#ifdef HARDENED
  .zero 64
#else
  .zero 32
#endif

/*
 * Kernel working buffers. This is the union of the symbols provided by
 * mlkem_keypair_bss.s, mlkem_indcpa_enc_bss.s and mlkem_decap_bss.s (which
 * define overlapping symbols and thus cannot be linked together), with the
 * per-buffer sizes and aliases preserved from those files. Buffers that
 * belong to different operations may share storage: only one operation
 * runs per execution, and DMEM is securely wiped when the app is
 * (re)loaded.
 */

/* Input/output pointers and parameters stored by the kernels. */
.globl dptr_pk
.balign 4
dptr_pk:
  .zero 4

.globl k
.balign 4
k:
  .zero 4

.globl dptr_sk
.balign 4
dptr_sk:
  .zero 4

.globl dptr_coins
.balign 4
dptr_coins:
  .zero 4

.globl dptr_ct
.balign 4
dptr_ct:
  .zero 4

.globl dptr_h
.balign 4
dptr_h:
  .zero 4

.globl dptr_ss
.balign 4
dptr_ss:
  .zero 4

.globl ctbytes
.balign 4
ctbytes:
  .zero 4

/* Nonce intermediate value used for cbd (32 bytes). */
.globl nonce
.balign 32
nonce:
  .zero 32

/* Bytes i || j used in matrix generation (32 bytes). */
.globl seed_ij
.balign 32
seed_ij:
  .zero 32

/* The decap-only buffers m, mtmp/ss_false and kr share storage with the
 * keygen-only hash buffer buf (96 bytes, overlapping m and the first half
 * of mtmp) and the encap-only indcpa_enc_seed (64 bytes, overlapping kr),
 * since they belong to disjoint operations. */

/* Message output of indcpa_dec intermediate value (decap); hash buffer
 * (keygen). */
.globl m
.globl buf
.balign 32
m:
buf:
  .zero 32 * NSHARES

.globl mtmp
.globl ss_false
.balign 32
mtmp:
ss_false:
  .zero 32 * NSHARES

/* Output of SHA3-512 (decap; one copy per share when HARDENED);
 * intermediate buffer for the 64-byte hash result in indcpa_enc (encap). */
.globl kr
.globl indcpa_enc_seed
.balign 32
kr:
indcpa_enc_seed:
  .zero 64 * NSHARES

.globl mpoly_m
.globl mpoly_v
.globl mpoly_b
.balign 32
mpoly_m:
mpoly_v:
mpoly_b:
  .zero 512 * NSHARES

/* mpoly_k/ep/epp (encap/decap) and mpoly_pk (keygen) belong to disjoint
 * operations and share storage. */
.globl mpoly_k
.globl mpoly_ep
.globl mpoly_epp
.globl mpoly_pk
.balign 32
mpoly_k:
mpoly_ep:
mpoly_epp:
mpoly_pk:
  .zero 512 * NSHARES

/* Secret polynomial vector: mpolyvec_sk (keygen), mpoly_sk (decap) and
 * mpolyvec_sp (encap / decap re-encryption) share storage. */
.globl mpolyvec_sk
.globl mpoly_sk
.globl mpolyvec_sp
.balign 32
mpolyvec_sk:
mpoly_sk:
mpolyvec_sp:
  .zero 512 * NSHARES * KYBER_K_MAX

/* Rejection-sampling target polynomial; kept last so that any sampling
 * overshoot lands past the end of the used DMEM region, mirroring the
 * placement in the original bss files. */
.globl poly_b
.globl poly_v
.globl poly_pk
.globl poly_at
.globl mpoly_e
.balign 32
poly_b:
poly_v:
poly_pk:
poly_at:
mpoly_e:
  .zero 512 * NSHARES
