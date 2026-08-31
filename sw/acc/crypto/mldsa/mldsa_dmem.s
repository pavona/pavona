/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/*
 * ML-DSA DMEM layout for run_mldsa (unprotected) and run_mldsa_hardened
 * (-DHARDENED, masked): I/O buffers, runtime broadcast constants and working
 * buffers, worst-case (ML-DSA-87) sized and overlaid so buffers used by
 * disjoint operations share storage.
 */

#ifdef HARDENED
#define NSHARES 2
#else
#define NSHARES 1
#endif

.bss
#ifdef HARDENED
/* ===================== HARDENED (masked) DMEM layout ===================== */

/* Operation mode (one of MODE_*). */
.globl mode
.balign 4
mode:
  .zero 4

/* Keygen seed: NSHARES boolean shares (2 x 32 B).  Dead during sign/verify,
 * where it hosts the rho'/ctilde scratch. */
.globl zeta_shares
.balign 32
zeta_shares:
  .zero 32 * NSHARES
.globl rhoprime
.globl ctilde
.set rhoprime, zeta_shares
.set ctilde,   zeta_shares

/* Public key (worst-case ML-DSA-87 = 2592 bytes).  Keygen output / verify
 * input; dead during sign, where it hosts the masked-sign scratch. */
.globl pk
.balign 32
pk:
  .zero 2592
.globl sign_y
.globl sign_tmp
.globl sign_w1_repvec
.globl sign_gamma1_buf
.set sign_y,          pk
.set sign_tmp,        pk + 1024
.set sign_w1_repvec,  pk + 2048
.set sign_gamma1_buf, pk + 2304

/* Masked secret key (rho@0, K-slot@32 zeroed, tr@64, packed t0@128); worst
 * case 128 + 8*416 = 3456 (ML-DSA-87).  During keygen the masked ExpandS
 * reuses the not-yet-written t0 region (sk+128) as eta scratch; dead during
 * verify, where it hosts w1_repvec. */
.globl sk
.balign 32
sk:
  .zero 3456
.globl w1_repvec
.set w1_repvec, sk

/* Signature (worst-case ML-DSA-87 = 4627 bytes).  Sign output / verify input;
 * dead during keygen, where it hosts the ExpandS output + matrix nonce + mask
 * stack. */
.globl sig
.balign 32
sig:
  .zero 4627
.globl eta_out
.globl matmul_nonce
.globl keygen_mask_stack
.globl keygen_mask_stack_end
.set eta_out,               sig
.set matmul_nonce,          sig + 2048
.set keygen_mask_stack,     sig + 2080
/* ExpandS call-stack headroom; keygen_tmp starts above it. */
.set keygen_mask_stack_end, sig + 2816

/* Pre-hashed message mu (external-mu sign/verify). */
.globl mu
.balign 32
mu:
  .zero 64

/* Hedge randomness for signing (32 bytes). */
.globl rnd
.balign 32
rnd:
  .zero 32

/* msg/ctx/msglen/ctxlen are unused here: external-mu sign/verify consume only
 * the pre-hashed mu (the driver hashes the message+context in software). */

/* Verify result (0 on success, -1 on failure). */
.globl result
.balign 4
result:
  .zero 4

/* rho_prime_shares is keygen-internal (sign loads s1/s2 from s1s2_shares);
   overlay it onto sign-dead mask_stack. */
.globl rho_prime_shares
.set rho_prime_shares, mask_stack

/* Masked key material: keygen output / sign input. */
.globl K_shares
.balign 32
K_shares:
  .zero 64

/* Expanded sk: s1 then s2 as Boolean bitsliced ExpandS shares (worst case
   ML-DSA-87 = 2 * (7 + 8) * 96). */
.globl s1s2_shares
.balign 32
s1s2_shares:
  .zero 2880

.globl dptr_sig
.balign 4
dptr_sig:
  .zero 4

/* Single-symbol broadcast vectors, populated at runtime by
 * _setup_masked_vectors from mldsa_params. */
.balign 32
.globl eta
eta:
  .zero 32
.balign 32
.globl gamma1_vec_const
gamma1_vec_const:
  .zero 32
.balign 32
.globl gamma2_vec_const
gamma2_vec_const:
  .zero 32
.balign 32
.globl polyz_unpack_mask
polyz_unpack_mask:
  .zero 32
/* poly.s loads the per-K names; in this single-binary build they all resolve to
 * the runtime broadcast vectors above, so no per-K tables are stored. */
.globl gamma1_vec_const_17
.globl gamma1_vec_const_19
.globl gamma2_vec_const_88
.globl gamma2_vec_const_32
.globl polyz_unpack_mask_17
.globl polyz_unpack_mask_19
.set gamma1_vec_const_17, gamma1_vec_const
.set gamma1_vec_const_19, gamma1_vec_const
.set gamma2_vec_const_88, gamma2_vec_const
.set gamma2_vec_const_32, gamma2_vec_const
.set polyz_unpack_mask_17, polyz_unpack_mask
.set polyz_unpack_mask_19, polyz_unpack_mask
.balign 32
.globl lambda0_z_vec
lambda0_z_vec:
  .zero 32
.balign 32
.globl lambda0_r_vec
lambda0_r_vec:
  .zero 32
.balign 32
.globl c_z_const
c_z_const:
  .zero 32
.balign 32
.globl c_r_const
c_r_const:
  .zero 32

/* Masked-sign gadget stack (256B); live throughout sign, so it keeps its own
 * storage. */
.balign 32
.globl mask_stack
mask_stack:
  .zero 256
.globl mask_stack_end
mask_stack_end:

/* Scratch polys overlaid onto dead I/O (disjoint ops): verify scratch (tmp_poly)
 * reuses verify-dead sk past w1_repvec; keygen t0 staging (keygen_tmp) reuses
 * keygen-dead sig past the ExpandS output/nonce/stack. */
.globl tmp_poly
.set tmp_poly,   sk + 256
.globl keygen_tmp
.set keygen_tmp, sig + 2816

/* Big polyvec buffer (BIG_BUF) shared by disjoint ops: keygen t (2*K*1024),
 * masked sign w0_polyvec_shares (matrix-mult accumulator + packed b' +
 * overlays), verify w1_polyvec. Worst case 2*8*1024 = 16384. */
.balign 32
.globl t_polyvec
.globl w0_polyvec_shares
.globl w1_polyvec
t_polyvec:
w0_polyvec_shares:
w1_polyvec:
  .zero 16384
/* Verify packs the z shares into the BIG_BUF tail: w1_polyvec uses [0:8192],
 * z_polyvec uses [8192:15360] (L*1024 = 7168 worst case). */
.globl z_polyvec
.set z_polyvec, w1_polyvec + 8192
/* NTT(c) challenge buffer (masked sign + verify) reuses the BIG_BUF tail: verify
 * leaves [15360:16384] free after w1[0:8192]+z[8192:15360], and masked sign's
 * dead region past the packed-b'/sign_c_poly_shares rows covers the same top
 * slot. */
.globl c_poly
.globl y_poly
.globl s1_poly
.set c_poly,  w0_polyvec_shares + 15360
.set y_poly,  w0_polyvec_shares + 15360
.set s1_poly, w0_polyvec_shares + 15360

/* Masked-sign overlays into w0_polyvec_shares (W0_POLYS=8, W0_SHARE_STRIDE=
 * 8192, NSHARES=2 fixed). sign_w0_l2_* hardcode the K=4 offset since the L2
 * decompose path only runs for ML-DSA-44 (c_poly is a standalone buffer above
 * to avoid the unprotected verify's c_poly colliding with
 * sign_c_poly_shares). */
.globl sign_hint_b2a
.set sign_hint_b2a,      w0_polyvec_shares + 8 * 608
.globl sign_c_poly_shares
.set sign_c_poly_shares, w0_polyvec_shares + 8192 + 8 * 608
.globl sign_w0_l2_seccompress_scratch
.set sign_w0_l2_seccompress_scratch, w0_polyvec_shares + 4096
.globl sign_w0_l2_b
.set sign_w0_l2_b,                   w0_polyvec_shares + 8192 + 4096
.globl sign_w0_l2_t_packed
.set sign_w0_l2_t_packed,            sign_w0_l2_b + 2048
#else

/* ==================== UNPROTECTED DMEM layout ==================== */

/* Operation mode (one of MODE_*). */
.globl mode
.balign 4
mode:
  .zero 4

/* Keygen seed (32 bytes). */
.globl zeta
.balign 32
zeta:
  .zero 32

/* Public key (worst-case ML-DSA-87 = 2592 bytes). */
.globl pk
.balign 32
pk:
  .zero 2592

/* Secret key (sk) for keypair/sign and the packed z polyvec (z_polyvec)
 * for verify share storage: sk is unused during verify and z_polyvec is
 * unused during keypair/sign. Sized for the larger consumer (z_polyvec =
 * L*1024 = 7168 bytes for ML-DSA-87); sk uses only the first 4896 bytes. */
.globl sk
.globl z_polyvec
.balign 32
sk:
z_polyvec:
  .zero 7168

/* Signature (worst-case ML-DSA-87 = 4627 bytes). */
.globl sig
.balign 32
sig:
  .zero 4627

.globl msg
.balign 32
msg:
  .zero 2048

/* Message length (4 bytes). */
.globl msglen
.balign 4
msglen:
  .zero 4

/* Context (up to 255 bytes per ML-DSA spec). */
.globl ctx
.balign 32
ctx:
  .zero 256

/* Context length (4 bytes). */
.globl ctxlen
.balign 4
ctxlen:
  .zero 4

/* Hedge randomness for signing (32 bytes). */
.globl rnd
.balign 32
rnd:
  .zero 32

/* Verify result (0 on success, -1 on failure). */
.globl result
.balign 4
result:
  .zero 4

/* Shared kernel scratch. Buffers that are only live within a single
 * operation are overlaid by aliasing label names to the same storage. */

.balign 32
.globl tmp_poly
tmp_poly:
  .zero 1024

.balign 32
.globl c_poly
.globl y_poly
.globl s1_poly
c_poly:
y_poly:
s1_poly:
  .zero 1024

.balign 32
.globl mu
mu:
  .zero 64

.balign 32
.globl rhoprime
.globl ctilde
rhoprime:
ctilde:
  .zero 64

.balign 4
.globl dptr_sig
dptr_sig:
  .zero 4

.balign 32
.globl w1_repvec
w1_repvec:
  .zero 256

/* keypair: t_polyvec; sign: w0_polyvec; verify: w1_polyvec. */
.balign 32
.globl t_polyvec
.globl w0_polyvec
.globl w1_polyvec
t_polyvec:
w0_polyvec:
w1_polyvec:
  .zero 8192
#endif
