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

/**
 * Re-encryption and ciphertext comparison for the decapsulation check.
 *
 * Use the encryption key to encrypt a plaintext message using the randomness r.
 * Compare the re-encrypted ciphertext with the input public ciphertext.
 *
 * Let d = NSHARES, cv = 32 * dv and cu = 32 * du, that is cv = 128 and cu = 320
 * bytes for k = 2, 3 and cv = 160 and cu = 352 bytes for k = 4. The input
 * ciphertext is laid out as c = u || v, with u in c[0 : k * cu] and v in
 * c[k * cu : k * cu + cv].
 *  Step 1: kpoly = poly_frommsg(m)       // masked_poly_frommsg(m) when d > 1
 *  Step 2: recompute v and compare it against c[k * cu : k * cu + cv].
 *          for i = 0..k - 1:
 *            ek_pke[i] = poly_frombytes(ek_pke[384 * i : 384 * (i + 1)])
 *            sp[i]     = poly_getnoise_eta_1(r, i)       // nonce i
 *            v        += ek_pke[i] * ntt(sp[i])
 *          v   = intt(v) + kpoly + epp                   // epp: nonce 2 * k
 *          acc = compare(poly_compress(v), c[k * cu : k * cu + cv])
 *  Step 3: recompute u and compare each row against c[i * cu : (i + 1) * cu].
 *          for i = 0..k - 1:
 *            b    = sum_j at[i][j] * sp[j], j = 0..k - 1  // at[i][j] from rho
 *            b    = intt(b) + ep[i]                       // ep[i]: nonce k + i
 *            acc |= compare(poly_polyvec_compress(b), c[i * cu : (i + 1) * cu])
 *  Step 4: w0 = acc                      // finalize_cmp + unmask when d > 1
 *
 * @param[in]  x10: dmem pointer to the input message m
 * @param[in]  x11: dmem pointer to the input packed public key ek_pke
 * @param[in]  x12: dmem pointer to the input randomness r (32 bytes)
 * @param[in]  x13: dmem pointer to the input ciphertext c to compare against
 * @param[in]  x15: k, the security level
 * @param[out] w0: comparison result; 0 if the ciphertexts match and all-ones
 *                 otherwise for UNPROTECTED, 1 if they match and 0 otherwise
 *                 for HARDENED
 * @param[in]  w16 (sw0): sw0.0 = q = 3329 (1st 16-bit lane),
 *                        sw0.2 = -q^-1 mod 2^16 = 3327 (3rd 16-bit lane)
 * @param[in]  w31: all-zero register
 *
 * UNPROTECTED
 * clobbered registers: x2 to x13, x18 to x19, x21 to x28,
 *                      w0 to w15, w17 to w26, mod, acch, acc
 * clobbered flag groups: FG0
 *
 * HARDENED
 * clobbered registers: x2 to x24, x26 to x31, w0 to w30, acc, mod, acch
 * clobbered flag groups: FG0
 */

.globl indcpa_enc_cmp
.type indcpa_enc_cmp, @function
indcpa_enc_cmp:
  addi x2, x2, -32
  sw   x3, 0(x2)
  add  x3, x2, x0

  add x9, x11, x0
  add x18, x12, x0
  add x19, x13, x0
  add x21, x15, x0

#ifndef HARDENED
  addi x4, x0, 4
  beq  x21, x4, _compute_k4_consts
  addi x26, x0, 128 /* dv * 32 = 4 * 32 */
  addi x27, x0, 320 /* du * 32 = 10 * 32 */
  beq  x0, x0, _continue

_compute_k4_consts:
  addi x26, x0, 160 /* dv * 32 = 5 * 32 */
  addi x27, x0, 352 /* du * 32 = 11 * 32 */

_continue:
  /* Adjust stack for packed re-encrypted ciphertext and comparison result. */
  sub  x2, x2, x27
  add  x25, x2, x0
  addi x2, x2, -32

  /*** Step 1: kpoly = poly_frommsg(m). ***/
  /* x10 already points to m. */
  la  x11, mpoly_k
  jal x1, poly_frommsg

  /*** Step 2: recompute v and compare it against c[k * cu : k * cu + cv]. ***/
  /* The following block will:
   *  (1) unpack ek_pke[i],
   *  (2) sample sp[i],
   *  (3) compute sp[i] = ntt(sp[i]),
   *  (4) compute v += ek_pke[i] * sp[i],
   *  (5) compute v = intt(v),
   *  (6) compute v += kpoly
   *  (7) sample epp
   *  (8) compute v += epp
   *  (9) compare v and c, output to r. */
  /**************************************************************************/
  addi x4, x0, 2
  beq  x21, x4, _handle_k2_eta_1
  addi x22, x0, 2 /* ETA1 */
  beq  x0, x0, _continue_compute_v

_handle_k2_eta_1:
  addi x22, x0, 3 /* ETA1 */

_continue_compute_v:
  /* Prepare for initial `poly_getnoise_eta_1` call: generate sp. */
  add    x10, x18, x0
  la     x11, nonce
  bn.xor w0, w0, w0
  bn.sid x0, 0(x11)
  jal    x1, poly_getnoise_eta_init

  /* Unpack ek_pke[0]. */
  add x10, x9, x0
  la  x11, poly_pk
  jal x1, poly_frombytes
  add x9, x10, x0

  /* Generate sp[0]. */
  add x10, x22, x0
  la  x11, mpolyvec_sp
  jal x1, poly_getnoise_eta_1

  /* Prepare for generating sp[1]. */
  add  x10, x18, x0
  la   x11, nonce
  lw   x5, 0(x11)
  addi x5, x5, 1
  sw   x5, 0(x11)
  jal  x1, poly_getnoise_eta_init

  /* Compute sp[0] = ntt(sp[0]). */
  bn.shv.16h w0, w16 << 1
  bn.wsrw    mod, w0
  la         x10, mpolyvec_sp
  la         x11, twiddles_ntt
  add        x12, x10, x0
  jal        x1, ntt

  /* Compute v = ek_pke[0] * sp[0]. */
  la      x10, poly_pk
  la      x11, mpolyvec_sp
  la      x12, twiddles_basemul
  la      x13, mpoly_v
  jal     x1, basemul
  add     x24, x11, x0
  bn.wsrw mod, w16

  /* At this point:
   *  - x9 points to packed pk.
   *  - x18 points to r (for cbd).
   *  - x19 points to c (for later).
   *  - x20 = nshares.
   *  - x21 is the security level k.
   *  - x22 is ETA1.
   *  - x24 points to sp[1].
   *  - x25 points to the packed re-encrypted ciphertext.
   *  - x26 = cv = 32 * dv and x27 = cu = 32 * du. */

  addi x4, x0, 3
  beq  x21, x4, _handle_k3_compute_v
  addi x4, x0, 2
  beq  x21, x4, _handle_k2_compute_v

_handle_k4_compute_v:
  /* Generate sp[1]. */
  add x10, x22, x0
  add x11, x24, x0
  jal x1, poly_getnoise_eta_1

  /* Prepare for generating sp[2]. */
  add  x10, x18, x0
  la   x11, nonce
  lw   x5, 0(x11)
  addi x5, x5, 1
  sw   x5, 0(x11)
  jal  x1, poly_getnoise_eta_init

  /* Unpack ek_pke[1]. */
  add x10, x9, x0
  la  x11, poly_pk
  jal x1, poly_frombytes
  add x9, x10, x0

  /* Compute sp[1] = ntt(sp[1]). */
  bn.shv.16h w0, w16 << 1
  bn.wsrw    mod, w0
  add        x10, x24, x0
  la         x11, twiddles_ntt
  add        x12, x10, x0
  jal        x1, ntt

  /* Compute v += ek_pke[1] * sp[1]. */
  la      x10, poly_pk
  add     x11, x24, x0
  la      x12, twiddles_basemul
  la      x13, mpoly_v
  jal     x1, basemul_acc
  add     x24, x11, x0
  bn.wsrw mod, w16

_handle_k3_compute_v:
  /* Generate sp[2]. */
  add x10, x22, x0
  add x11, x24, x0
  jal x1, poly_getnoise_eta_1

  /* Prepare for generating sp[3]. */
  add  x10, x18, x0
  la   x11, nonce
  lw   x5, 0(x11)
  addi x5, x5, 1
  sw   x5, 0(x11)
  jal  x1, poly_getnoise_eta_init

  /* Unpack ek_pke[2]. */
  add x10, x9, x0
  la  x11, poly_pk
  jal x1, poly_frombytes
  add x9, x10, x0

  /* Compute sp[i] = ntt(sp[i]). */
  bn.shv.16h w0, w16 << 1
  bn.wsrw    mod, w0
  add        x10, x24, x0
  la         x11, twiddles_ntt
  add        x12, x10, x0
  jal        x1, ntt

  /* Compute v += ek_pke[2] * sp[2]. */
  la      x10, poly_pk
  add     x11, x24, x0
  la      x12, twiddles_basemul
  la      x13, mpoly_v
  jal     x1, basemul_acc
  add     x24, x11, x0
  bn.wsrw mod, w16

_handle_k2_compute_v:
  /* Generate sp[3]. */
  add x10, x22, x0
  add x11, x24, x0
  jal x1, poly_getnoise_eta_1

  /* Prepare for initial `poly_getnoise_eta_2` call: generate epp. */
  add  x10, x18, x0
  slli x5, x21, 1
  la   x11, nonce
  sw   x5, 0(x11)
  jal  x1, poly_getnoise_eta_init

  /* Compute sp[3] = ntt(sp[3]). */
  bn.shv.16h w0, w16 << 1
  bn.wsrw    mod, w0
  add        x10, x24, x0
  la         x11, twiddles_ntt
  add        x12, x10, x0
  jal        x1, ntt

  /* Unpack ek_pke[3]. */
  add x10, x9, x0
  la  x11, poly_pk
  jal x1, poly_frombytes
  add x9, x10, x0

  /* Compute v += ek_pke[3] * sp[3]. */
  la  x10, poly_pk
  add x11, x24, x0
  la  x12, twiddles_basemul
  la  x13, mpoly_v
  jal x1, basemul_acc

  /* Compute v = intt(v). */
  la      x10, mpoly_v
  la      x11, twiddles_intt
  add     x12, x10, x0
  jal     x1, intt
  bn.wsrw mod, w16

  /* Compute v += kpoly. */
  la  x10, mpoly_v
  la  x11, mpoly_k
  add x12, x10, x0
  jal x1, poly_add

  /* Generate epp. */
  la  x11, mpoly_epp
  jal x1, poly_getnoise_eta_2

  /* Prepare for initial `poly_getnoise_eta_2` call: generate ep. */
  add x10, x18, x0
  la  x11, nonce
  sw  x21, 0(x11)
  jal x1, poly_getnoise_eta_init

  /* Compute v += epp. */
  la  x10, mpoly_v
  la  x11, mpoly_epp
  add x12, x10, x0
  jal x1, poly_add

  /* Generate ep[0]. */
  la  x11, mpoly_ep
  jal x1, poly_getnoise_eta_2

  /* Prepare for generating at[0][0]. */
  add    x10, x9, x0
  la     x11, seed_ij
  bn.xor w0, w0, w0
  bn.sid x0, 0(x11)
  jal    x1, poly_gen_matrix_init

  /* Compress v. */
  la  x10, mpoly_v
  add x11, x25, x0
  add x12, x21, x0
  jal x1, poly_compress

  /* Compare v and c[k * cu :]. Output to r. */
  add x5, x25, x0
  add x6, x19, x0
  loop x21, 1
    add x6, x6, x27
  endloop
  addi x4, x0, 1
  srli x7, x26, 5

  bn.subi w2, w31, 1
  bn.mov  w4, w31
  loop x7, 5
    bn.lid x0, 0(x5++)
    bn.lid x4, 0(x6++)
    bn.cmp w0, w1
    bn.sel w3, w31, w2, FG0.Z
    bn.or  w4, w4, w3
  endloop
  /* First write to r; the later compares read-modify-write it. */
  addi   x4, x0, 4
  bn.sid x4, 0(x2)
  /**************************************************************************/


  /*** Step 3: recompute u row by row and compare it against c. ***/
  /* The following block will:
   *  (1) sample at.row[i],
   *  (2) compute b = at.row[i] * sp[i],
   *  (3) compute b = intt(b),
   *  (4) sample ep[i]
   *  (5) compute b += ep[i]
   *  (6) compare b and c, output to r. */
  /**************************************************************************/

  /* At this point:
   *  - x8 is free.
   *  - x9 points to seed (for matrix generation).
   *  - x18 points to r (for cbd).
   *  - x19 points to c (for unpacking).
   *  - x20 = nshares.
   *  - x21 is the security level k.
   *  - x22 is free.
   *  - x23 is free.
   *  - x24 is free.
   *  - x25 points to the packed re-encrypted ciphertext.
   *  - x26 = cv = 32 * dv and x27 = cu = 32 * du. */

  addi x4, x0, 2
  beq  x21, x4, _handle_k2_compute_b
  addi x8, x21, -1  /* k - 1 */
  addi x21, x21, -2 /* k - 2 */
  slli x23, x8, 8   /* (k - 1) * 0x0100 */
  addi x23, x23, -1

  /* Loop over i = 1..k - 1. */
  loop x8, 110
    /* Generate at[i][0]. */
    la  x11, poly_at
    jal x1, poly_gen_matrix

    /* Prepare for generating at[i][1]. */
    add  x10, x9, x0
    la   x11, seed_ij
    lw   x4, 0(x11)
    addi x4, x4, 0x0100
    sw   x4, 0(x11)
    jal  x1, poly_gen_matrix_init

    /* Compute b = at[i][0] * sp[0]. */
    bn.shv.16h w0, w16 << 1
    bn.wsrw    mod, w0
    la         x10, poly_at
    la         x11, mpolyvec_sp
    la         x12, twiddles_basemul
    la         x13, mpoly_b
    jal        x1, basemul
    add        x24, x11, x0
    bn.wsrw    mod, w16

    loop x21, 22
      /* Generate at[i][j]. */
      la  x11, poly_at
      jal x1, poly_gen_matrix

      /* Prepare for generating at[i][j + 1]. */
      add  x10, x9, x0
      la   x11, seed_ij
      lw   x4, 0(x11)
      addi x4, x4, 0x0100
      sw   x4, 0(x11)
      jal  x1, poly_gen_matrix_init

      /* Compute b += at[i][j] * sp[j]. */
      bn.shv.16h w0, w16 << 1
      bn.wsrw    mod, w0
      la         x10, poly_at
      add        x11, x24, x0
      la         x12, twiddles_basemul
      la         x13, mpoly_b
      jal        x1, basemul_acc
      add        x24, x11, x0
      bn.wsrw    mod, w16
    endloop

    /* Generate at[i][k - 1]. */
    la  x11, poly_at
    jal x1, poly_gen_matrix

    /* Compute b += at[i][k - 1] * sp[k - 1]. */
    bn.shv.16h w0, w16 << 1
    bn.wsrw    mod, w0
    la         x10, poly_at
    add        x11, x24, x0
    la         x12, twiddles_basemul
    la         x13, mpoly_b
    jal        x1, basemul_acc

    /* Compute b = intt(b). */
    la      x10, mpoly_b
    la      x11, twiddles_intt
    add     x12, x10, x0
    jal     x1, intt
    bn.wsrw mod, w16

    /* Prepare for generating ep[i + 1]. */
    add  x10, x18, x0
    la   x11, nonce
    lw   x5, 0(x11)
    addi x5, x5, 1
    sw   x5, 0(x11)
    jal  x1, poly_getnoise_eta_init

    /* Compute b += ep. */
    la  x10, mpoly_b
    la  x11, mpoly_ep
    add x12, x10, x0
    jal x1, poly_add

    /* Generate ep[i + 1]. */
    la  x11, mpoly_ep
    jal x1, poly_getnoise_eta_2

    /* Prepare for generating at[i + 1][0]. */
    add x10, x9, x0
    la  x11, seed_ij
    lw  x5, 0(x11)
    sub x5, x5, x23
    sw  x5, 0(x11)
    jal x1, poly_gen_matrix_init

    /* Compress b. */
    la   x10, mpoly_b
    add  x11, x25, x0
    addi x12, x21, 2
    jal  x1, poly_polyvec_compress

    /* Compare b and c[i * cu : (i + 1) * cu]. Accumulate output to r. */
    add  x5, x25, x0
    add  x6, x19, x0
    srli x7, x27, 5
    addi x4, x0, 1

    bn.subi w2, w31, 1
    bn.mov  w4, w31
    loop x7, 5
      bn.lid x0, 0(x5++)
      bn.lid x4, 0(x6++)
      bn.cmp w0, w1
      bn.sel w3, w31, w2, FG0.Z
      bn.or  w4, w4, w3
    endloop
    bn.lid x0, 0(x2)
    bn.or  w0, w0, w4
    bn.sid x0, 0(x2)
    add    x19, x19, x27
  endloop

  /* Generate at[k - 1][0]. */
  la  x11, poly_at
  jal x1, poly_gen_matrix

  /* Prepare for generating at[k - 1][1]. */
  add  x10, x9, x0
  la   x11, seed_ij
  lw   x4, 0(x11)
  addi x4, x4, 0x0100
  sw   x4, 0(x11)
  jal  x1, poly_gen_matrix_init

  /* Compute b = at[k - 1][0] * sp[0]. */
  bn.shv.16h w0, w16 << 1
  bn.wsrw    mod, w0
  la         x10, poly_at
  la         x11, mpolyvec_sp
  la         x12, twiddles_basemul
  la         x13, mpoly_b
  jal        x1, basemul
  add        x24, x11, x0
  bn.wsrw    mod, w16

  loop x21, 22
    /* Generate at[k - 1][j]. */
    la  x11, poly_at
    jal x1, poly_gen_matrix

    /* Prepare for generating at[k - 1][j]. */
    add  x10, x9, x0
    la   x11, seed_ij
    lw   x4, 0(x11)
    addi x4, x4, 0x0100
    sw   x4, 0(x11)
    jal  x1, poly_gen_matrix_init

    /* Compute b += at[k - 1][j] * sp[j]. */
    bn.shv.16h w0, w16 << 1
    bn.wsrw    mod, w0
    la         x10, poly_at
    add        x11, x24, x0
    la         x12, twiddles_basemul
    la         x13, mpoly_b
    jal        x1, basemul_acc
    add        x24, x11, x0
    bn.wsrw    mod, w16
  endloop

  /* Generate at[k - 1][k - 1]. */
  la  x11, poly_at
  jal x1, poly_gen_matrix

  /* Compute b += at[k - 1][k - 1] * sp[k - 1]. */
  bn.shv.16h w0, w16 << 1
  bn.wsrw    mod, w0
  la         x10, poly_at
  add        x11, x24, x0
  la         x12, twiddles_basemul
  la         x13, mpoly_b
  jal        x1, basemul_acc

  /* Compute b = intt(b). */
  la      x10, mpoly_b
  la      x11, twiddles_intt
  add     x12, x10, x0
  jal     x1, intt
  bn.wsrw mod, w16

  /* Compute b += ep. */
  la  x10, mpoly_b
  la  x11, mpoly_ep
  add x12, x10, x0
  jal x1, poly_add

  /* Compress b. */
  la   x10, mpoly_b
  add  x11, x25, x0
  addi x12, x21, 2
  jal  x1, poly_polyvec_compress

  /* Compare b and c[i * cu : (i + 1) * cu]. Accumulate output to r. */
  add  x5, x25, x0
  add  x6, x19, x0
  srli x7, x27, 5
  addi x4, x0, 1

  bn.subi w2, w31, 1
  bn.mov  w4, w31
  loop x7, 5
    bn.lid x0, 0(x5++)
    bn.lid x4, 0(x6++)
    bn.cmp w0, w1
    bn.sel w3, w31, w2, FG0.Z
    bn.or  w4, w4, w3
  endloop
  /*** Step 4: w0 = acc. ***/
  bn.lid x0, 0(x2)
  bn.or  w0, w0, w4 /* w0 is the comparison result. */
  /**************************************************************************/
  /* Restore x2 and x3. */
  add  x2, x3, x0
  lw   x3, 0(x2)
  addi x2, x2, 32
  ret

_handle_k2_compute_b:
  /* Generate at[0][0]. */
  la  x11, poly_at
  jal x1, poly_gen_matrix

  /* Prepare for generating at[0][1]. */
  add  x10, x9, x0
  la   x11, seed_ij
  lw   x4, 0(x11)
  addi x4, x4, 0x0100
  sw   x4, 0(x11)
  jal  x1, poly_gen_matrix_init

  /* Compute b = at[0][0] * sp[0]. */
  bn.shv.16h w0, w16 << 1
  bn.wsrw    mod, w0
  la         x10, poly_at
  la         x11, mpolyvec_sp
  la         x12, twiddles_basemul
  la         x13, mpoly_b
  jal        x1, basemul
  add        x24, x11, x0
  bn.wsrw    mod, w16

  /* Generate at[0][1]. */
  la  x11, poly_at
  jal x1, poly_gen_matrix

  /* Compute b += at[0][1] * sp[1]. */
  bn.shv.16h w0, w16 << 1
  bn.wsrw    mod, w0
  la         x10, poly_at
  add        x11, x24, x0
  la         x12, twiddles_basemul
  la         x13, mpoly_b
  jal        x1, basemul_acc

  /* Compute b = intt(b). */
  la      x10, mpoly_b
  la      x11, twiddles_intt
  add     x12, x10, x0
  jal     x1, intt
  bn.wsrw mod, w16

  /* Prepare for generating ep[1]. */
  add  x10, x18, x0
  la   x11, nonce
  lw   x5, 0(x11)
  addi x5, x5, 1
  sw   x5, 0(x11)
  jal  x1, poly_getnoise_eta_init

  /* Compute b += ep. */
  la  x10, mpoly_b
  la  x11, mpoly_ep
  add x12, x10, x0
  jal x1, poly_add

  /* Generate ep[1]. */
  la  x11, mpoly_ep
  jal x1, poly_getnoise_eta_2

  /* Prepare for generating at[1][0]. */
  add  x10, x9, x0
  la   x11, seed_ij
  addi x5, x0, 1
  sw   x5, 0(x11)
  jal  x1, poly_gen_matrix_init

  /* Compress b. */
  la  x10, mpoly_b
  add x11, x25, x0
  add x12, x21, x0
  jal x1, poly_polyvec_compress

  /* Compare b and c[i * cu : (i + 1) * cu]. Accumulate output to r. */
  add  x5, x25, x0
  add  x6, x19, x0 /* c[i * cu : (i + 1) * cu] */
  srli x7, x27, 5
  addi x4, x0, 1

  bn.subi w2, w31, 1
  bn.mov  w4, w31
  loop x7, 5
    bn.lid x0, 0(x5++)
    bn.lid x4, 0(x6++)
    bn.cmp w0, w1
    bn.sel w3, w31, w2, FG0.Z
    bn.or  w4, w4, w3
  endloop
  bn.lid x0, 0(x2)
  bn.or  w0, w0, w4
  bn.sid x0, 0(x2)

  /* Generate at[1][0]. */
  la  x11, poly_at
  jal x1, poly_gen_matrix

  /* Prepare for generating at[1][1]. */
  add  x10, x9, x0
  la   x11, seed_ij
  lw   x4, 0(x11)
  addi x4, x4, 0x0100
  sw   x4, 0(x11)
  jal  x1, poly_gen_matrix_init

  /* Compute b = at[1][0] * sp[0]. */
  bn.shv.16h w0, w16 << 1
  bn.wsrw    mod, w0
  la         x10, poly_at
  la         x11, mpolyvec_sp
  la         x12, twiddles_basemul
  la         x13, mpoly_b
  jal        x1, basemul
  add        x24, x11, x0
  bn.wsrw    mod, w16

  /* Generate at[1][1]. */
  la  x11, poly_at
  jal x1, poly_gen_matrix

  /* Compute b += at[1][1] * sp[1]. */
  bn.shv.16h w0, w16 << 1
  bn.wsrw    mod, w0
  la         x10, poly_at
  add        x11, x24, x0
  la         x12, twiddles_basemul
  la         x13, mpoly_b
  jal        x1, basemul_acc

  /* Compute b = intt(b). */
  la      x10, mpoly_b
  la      x11, twiddles_intt
  add     x12, x10, x0
  jal     x1, intt
  bn.wsrw mod, w16

  /* Compute b += ep. */
  la  x10, mpoly_b
  la  x11, mpoly_ep
  add x12, x10, x0
  jal x1, poly_add

  /* Compress b. */
  la  x10, mpoly_b
  add x11, x25, x0
  add x12, x21, x0
  jal x1, poly_polyvec_compress

  /* Compare b and c[i * cu : (i + 1) * cu]. Accumulate output to r. */
  add  x5, x25, x0
  addi x6, x19, 320 /* c[i * cu : (i + 1) * cu] */
  srli x7, x27, 5
  addi x4, x0, 1

  bn.subi w2, w31, 1
  bn.mov  w4, w31
  loop x7, 5
    bn.lid x0, 0(x5++)
    bn.lid x4, 0(x6++)
    bn.cmp w0, w1
    bn.sel w3, w31, w2, FG0.Z
    bn.or  w4, w4, w3
  endloop
  /*** Step 4: w0 = acc. ***/
  bn.lid x0, 0(x2)
  bn.or  w0, w0, w4 /* w0 is the comparison result. */
  /**************************************************************************/
  add  x2, x3, x0
  lw   x3, 0(x2)
  addi x2, x2, 32
  ret

#else
  addi x4, x0, 4
  beq  x21, x4, _compute_k4_consts
  addi x26, x0, 128 /* dv * 32 = 4 * 32 */
  addi x27, x0, 320 /* du * 32 = 10 * 32 */
  beq  x0, x0, _continue

_compute_k4_consts:
  addi x26, x0, 160 /* dv * 32 = 5 * 32 */
  addi x27, x0, 352 /* du * 32 = 11 * 32 */

_continue:
  /* Adjust stack for comparison result r. */
  addi x2, x2, -64

  /* The first share of r is (1 << N) - 1. The other shares are 0. */
  add     x5, x2, x0
  bn.subi w0, w31, 1
  bn.sid  x0, 0(x5++)
  bn.xor  w0, w31, w31
  bn.sid  x0, 0(x5++)

  /*** Step 1: kpoly = masked_poly_frommsg(m). ***/
  /* x10 already points to m. */
  la   x12, mpoly_k
  jal  x1, masked_poly_frommsg

  /*** Step 2: recompute v and compare it against c[k * cu : k * cu + cv]. ***/
  /* The following block will:
   *  (1) unpack ek_pke[i],
   *  (2) sample sp[i],
   *  (3) compute sp[i] = ntt(sp[i]),
   *  (4) compute v += ek_pke[i] * sp[i],
   *  (5) compute v = intt(v),
   *  (6) compute v += kpoly
   *  (7) sample epp
   *  (8) compute v += epp
   *  (9) compare v and c, output to r. */
  /**************************************************************************/
  addi x4, x0, 2
  beq  x21, x4, _handle_k2_eta_1
  addi x22, x0, 2 /* ETA1 */
  beq  x0, x0, _continue_compute_v

_handle_k2_eta_1:
  addi x22, x0, 3 /* ETA1 */

_continue_compute_v:
  /* Prepare for initial `poly_getnoise_eta_1` call: generate sp. */
  add    x10, x18, x0
  la     x11, nonce
  bn.xor w0, w0, w0
  bn.sid x0, 0(x11)
  jal    x1, masked_poly_getnoise_eta_init

  /* Unpack ek_pke[0]. */
  add x10, x9, x0
  la  x11, poly_pk
  jal x1, poly_frombytes
  add x9, x10, x0

  /* Generate sp[0]. */
  add x10, x22, x0
  la  x11, mpolyvec_sp
  jal x1, masked_poly_getnoise_eta_1

  /* Prepare for generating sp[1]. */
  add  x10, x18, x0
  la   x11, nonce
  lw   x5, 0(x11)
  addi x5, x5, 1
  sw   x5, 0(x11)
  jal  x1, masked_poly_getnoise_eta_init

  /* Compute sp[0] = ntt(sp[0]). */
  bn.shv.16h w0, w16 << 1
  bn.wsrw    mod, w0
  la         x10, mpolyvec_sp
  la         x11, twiddles_ntt
  add        x12, x10, x0
  loopi NSHARES, 3
    jal x1, ntt
    jal x1, whitening
    nop
  endloop

  /* Compute v = ek_pke[0] * sp[0]. */
  la  x8, poly_pk
  add x10, x8, x0
  la  x11, mpolyvec_sp
  la  x12, twiddles_basemul
  la  x13, mpoly_v
  loopi NSHARES, 3
    jal x1, basemul
    jal x1, whitening
    add x10, x8, x0
  endloop
  add     x24, x11, x0
  bn.wsrw mod, w16

  /* At this point:
   *  - x8 points to poly_pk.
   *  - x9 points to packed pk.
   *  - x18 points to r (for cbd).
   *  - x19 points to c (for later).
   *  - x21 is the security level k.
   *  - x22 is ETA1.
   *  - x24 points to sp[1].
   *  - x26 = cv = 32 * dv and x27 = cu = 32 * du. */

  addi x4, x0, 3
  beq  x21, x4, _handle_k3_compute_v
  addi x4, x0, 2
  beq  x21, x4, _handle_k2_compute_v

_handle_k4_compute_v:
  /* Generate sp[1]. */
  add x10, x22, x0
  add x11, x24, x0
  jal x1, masked_poly_getnoise_eta_1

  /* Prepare for generating sp[2]. */
  add  x10, x18, x0
  la   x11, nonce
  lw   x5, 0(x11)
  addi x5, x5, 1
  sw   x5, 0(x11)
  jal  x1, masked_poly_getnoise_eta_init

  /* Unpack ek_pke[1]. */
  add x10, x9, x0
  la  x11, poly_pk
  jal x1, poly_frombytes
  add x9, x10, x0

  /* Compute sp[1] = ntt(sp[1]). */
  bn.shv.16h w0, w16 << 1
  bn.wsrw    mod, w0
  add        x10, x24, x0
  la         x11, twiddles_ntt
  add        x12, x10, x0
  loopi NSHARES, 3
    jal x1, ntt
    jal x1, whitening
    nop
  endloop

  /* Compute v += ek_pke[1] * sp[1]. */
  la  x8, poly_pk
  add x10, x8, x0
  add x11, x24, x0
  la  x12, twiddles_basemul
  la  x13, mpoly_v
  loopi NSHARES, 3
    jal x1, basemul_acc
    jal x1, whitening
    add x10, x8, x0
  endloop
  add     x24, x11, x0
  bn.wsrw mod, w16

_handle_k3_compute_v:
  /* Generate sp[2]. */
  add x10, x22, x0
  add x11, x24, x0
  jal x1, masked_poly_getnoise_eta_1

  /* Prepare for generating sp[3]. */
  add  x10, x18, x0
  la   x11, nonce
  lw   x5, 0(x11)
  addi x5, x5, 1
  sw   x5, 0(x11)
  jal  x1, masked_poly_getnoise_eta_init

  /* Unpack ek_pke[2]. */
  add x10, x9, x0
  la  x11, poly_pk
  jal x1, poly_frombytes
  add x9, x10, x0

  /* Compute sp[2] = ntt(sp[2]). */
  bn.shv.16h w0, w16 << 1
  bn.wsrw    mod, w0
  add        x10, x24, x0
  la         x11, twiddles_ntt
  add        x12, x10, x0
  loopi NSHARES, 3
    jal x1, ntt
    jal x1, whitening
    nop
  endloop

  /* Compute v += ek_pke[2] * sp[2]. */
  la  x8, poly_pk
  add x10, x8, x0
  add x11, x24, x0
  la  x12, twiddles_basemul
  la  x13, mpoly_v
  loopi NSHARES, 3
    jal x1, basemul_acc
    jal x1, whitening
    add x10, x8, x0
  endloop
  add     x24, x11, x0
  bn.wsrw mod, w16

_handle_k2_compute_v:
  /* Generate sp[3]. */
  add x10, x22, x0
  add x11, x24, x0
  jal x1, masked_poly_getnoise_eta_1

  /* Prepare for initial `poly_getnoise_eta_2` call: generate epp. */
  add  x10, x18, x0
  slli x5, x21, 1
  la   x11, nonce
  sw   x5, 0(x11)
  jal  x1, masked_poly_getnoise_eta_init

  /* Compute sp[3] = ntt(sp[3]). */
  bn.shv.16h w0, w16 << 1
  bn.wsrw    mod, w0
  add        x10, x24, x0
  la         x11, twiddles_ntt
  add        x12, x10, x0
  loopi NSHARES, 3
    jal x1, ntt
    jal x1, whitening
    nop
  endloop

  /* Unpack ek_pke[3]. */
  add x10, x9, x0
  la  x11, poly_pk
  jal x1, poly_frombytes
  add x9, x10, x0

  /* Compute v += ek_pke[3] * sp[3]. */
  la  x8, poly_pk
  add x10, x8, x0
  add x11, x24, x0
  la  x12, twiddles_basemul
  la  x13, mpoly_v
  loopi NSHARES, 3
    jal x1, basemul_acc
    jal x1, whitening
    add x10, x8, x0
  endloop

  /* Compute v = intt(v). */
  la  x10, mpoly_v
  la  x11, twiddles_intt
  add x12, x10, x0
  loopi NSHARES, 3
    jal x1, intt
    jal x1, whitening
    nop
  endloop
  bn.wsrw mod, w16

  /* Compute v += kpoly. */
  la  x10, mpoly_v
  la  x11, mpoly_k
  add x12, x10, x0
  loopi NSHARES, 3
    jal    x1, poly_add
    /* Whitening. */
    bn.xor w0, w0, w0
    bn.xor w1, w1, w1
  endloop

  /* Generate epp. */
  add x10, x0, 2
  la  x11, mpoly_epp
  jal x1, masked_poly_getnoise_eta_2

  /* Prepare for initial `poly_getnoise_eta_2` call: generate ep. */
  add x10, x18, x0
  la  x11, nonce
  sw  x21, 0(x11)
  jal x1, masked_poly_getnoise_eta_init

  /* Compute v += epp. */
  la  x10, mpoly_v
  la  x11, mpoly_epp
  add x12, x10, x0
  loopi NSHARES, 3
    jal    x1, poly_add
    /* Whitening. */
    bn.xor w0, w0, w0
    bn.xor w1, w1, w1
  endloop

  /* Generate ep[0]. */
  addi x10, x0, 2
  la   x11, mpoly_ep
  jal  x1, masked_poly_getnoise_eta_2

  /* Prepare for generating at[0][0]. */
  add    x10, x9, x0
  la     x11, seed_ij
  bn.xor w0, w0, w0
  bn.sid x0, 0(x11)
  jal    x1, poly_gen_matrix_init

  /* Compare v and c[k * cu :]. Output to r. */
  la  x10, mpoly_v
  add x11, x19, x0
  loop x21, 1
    add x11, x11, x27
  endloop
  add x12, x26, x0
  add x14, x2, x0
  add x15, x21, x0
  jal x1, masked_poly_compare_dv
  /**************************************************************************/


  /*** Step 3: recompute u row by row and compare it against c. ***/
  /* The following block will:
   *  (1) sample at.row[i],
   *  (2) compute b = at.row[i] * sp[i],
   *  (3) compute b = intt(b),
   *  (4) sample ep[i]
   *  (5) compute b += ep[i]
   *  (6) compare b and c, output to r. */
  /**************************************************************************/

  /* At this point:
   *  - x8 is free.
   *  - x9 points to seed (for matrix generation).
   *  - x18 points to r (for cbd).
   *  - x19 points to c (for unpacking).
   *  - x21 is the security level k.
   *  - x22 is free.
   *  - x23 is free.
   *  - x24 is free.
   *  - x26 = cv = 32 * dv and x27 = cu = 32 * du. */

  addi x4, x0, 2
  beq  x21, x4, _handle_k2_compute_b
  addi x8, x21, -1  /* k - 1 */
  addi x21, x21, -2 /* k - 2 */
  slli x23, x8, 8   /* (k - 1) * 0x0100 */
  addi x23, x23, -1

  loop x8, 116
    /* Generate at[i][0]. */
    la   x11, poly_at
    jal  x1, poly_gen_matrix

    /* Prepare for generating at[i][1]. */
    add  x10, x9, x0
    la   x11, seed_ij
    lw   x4, 0(x11)
    addi x4, x4, 0x0100
    sw   x4, 0(x11)
    jal  x1, poly_gen_matrix_init

    /* Compute b = at[i][0] * sp[0]. */
    bn.shv.16h w0, w16 << 1
    bn.wsrw    mod, w0
    la         x22, poly_at
    add        x10, x22, x0
    la         x11, mpolyvec_sp
    la         x12, twiddles_basemul
    la         x13, mpoly_b
    loopi NSHARES, 3
      jal x1, basemul
      jal x1, whitening
      add x10, x22, x0
    endloop
    add     x24, x11, x0
    bn.wsrw mod, w16

    loop x21, 26
      /* Generate at[i][1]. */
      la   x11, poly_at
      jal  x1, poly_gen_matrix

      /* Prepare for generating at[i][2]. */
      add  x10, x9, x0
      la   x11, seed_ij
      lw   x4, 0(x11)
      addi x4, x4, 0x0100
      sw   x4, 0(x11)
      jal  x1, poly_gen_matrix_init

      /* Compute b += at[i][1] * sp[1]. */
      bn.shv.16h w0, w16 << 1
      bn.wsrw    mod, w0
      la         x22, poly_at
      add        x10, x22, x0
      add        x11, x24, x0
      la         x12, twiddles_basemul
      la         x13, mpoly_b
      loopi NSHARES, 3
        jal x1, basemul_acc
        jal x1, whitening
        add x10, x22, x0
      endloop
      add     x24, x11, x0
      bn.wsrw mod, w16
    endloop

    /* Generate at[i][k - 1]. */
    la  x11, poly_at
    jal x1, poly_gen_matrix

    /* Compute b += at[i][k - 1] * sp[k - 1]. */
    bn.shv.16h w0, w16 << 1
    bn.wsrw    mod, w0
    la         x22, poly_at
    add        x10, x22, x0
    add        x11, x24, x0
    la         x12, twiddles_basemul
    la         x13, mpoly_b
    loopi NSHARES, 3
      jal x1, basemul_acc
      jal x1, whitening
      add x10, x22, x0
    endloop

    /* Compute b = intt(b). */
    la  x10, mpoly_b
    la  x11, twiddles_intt
    add x12, x10, x0
    loopi NSHARES, 3
      jal x1, intt
      jal x1, whitening
      nop
    endloop
    bn.wsrw mod, w16

    /* Prepare for generating ep[i + 1]. */
    add  x10, x18, x0
    la   x11, nonce
    lw   x5, 0(x11)
    addi x5, x5, 1
    sw   x5, 0(x11)
    jal  x1, masked_poly_getnoise_eta_init

    /* Compute b += ep. */
    la  x10, mpoly_b
    la  x11, mpoly_ep
    add x12, x10, x0
    loopi NSHARES, 3
      jal    x1, poly_add
      /* Whitening. */
      bn.xor w0, w0, w0
      bn.xor w1, w1, w1
    endloop

    /* Generate ep[i + 1]. */
    addi x10, x0, 2
    la   x11, mpoly_ep
    jal  x1, masked_poly_getnoise_eta_2

    /* Prepare for generating at[i + 1][0]. */
    add x10, x9, x0
    la  x11, seed_ij
    lw  x5, 0(x11)
    sub x5, x5, x23
    sw  x5, 0(x11)
    jal x1, poly_gen_matrix_init

    /* Compare b and c[i * cu : (i + 1) * cu]. Accumulate output to r. */
    la   x10, mpoly_b
    add  x11, x19, x0
    add  x12, x27, x0
    add  x14, x2, x0
    addi x15, x21, 2
    jal  x1, masked_poly_compare_du
    add  x19, x19, x27
  endloop

  /* Generate at[k - 1][0]. */
  la  x11, poly_at
  jal x1, poly_gen_matrix

  /* Prepare for generating at[k - 1][1]. */
  add  x10, x9, x0
  la   x11, seed_ij
  lw   x4, 0(x11)
  addi x4, x4, 0x0100
  sw   x4, 0(x11)
  jal  x1, poly_gen_matrix_init

  /* Compute b = at[k - 1][0] * sp[0]. */
  bn.shv.16h w0, w16 << 1
  bn.wsrw    mod, w0
  la         x22, poly_at
  add        x10, x22, x0
  la         x11, mpolyvec_sp
  la         x12, twiddles_basemul
  la         x13, mpoly_b
  loopi NSHARES, 3
    jal x1, basemul
    jal x1, whitening
    add x10, x22, x0
  endloop
  add     x24, x11, x0
  bn.wsrw mod, w16

  loop x21, 26
    /* Generate at[i][j]. */
    la   x11, poly_at
    jal  x1, poly_gen_matrix

    /* Prepare for generating at[i][j]. */
    add  x10, x9, x0
    la   x11, seed_ij
    lw   x4, 0(x11)
    addi x4, x4, 0x0100
    sw   x4, 0(x11)
    jal  x1, poly_gen_matrix_init

    /* Compute b += at[i][j] * sp[j]. */
    bn.shv.16h w0, w16 << 1
    bn.wsrw    mod, w0
    la         x22, poly_at
    add        x10, x22, x0
    add        x11, x24, x0
    la         x12, twiddles_basemul
    la         x13, mpoly_b
    loopi NSHARES, 3
      jal x1, basemul_acc
      jal x1, whitening
      add x10, x22, x0
    endloop
    add     x24, x11, x0
    bn.wsrw mod, w16
  endloop

  /* Generate at[k - 1][k - 1]. */
  la  x11, poly_at
  jal x1, poly_gen_matrix

  /* Compute b += at[k - 1][k - 1] * sp[k - 1]. */
  bn.shv.16h w0, w16 << 1
  bn.wsrw    mod, w0
  la         x22, poly_at
  add        x10, x22, x0
  add        x11, x24, x0
  la         x12, twiddles_basemul
  la         x13, mpoly_b
  loopi NSHARES, 3
    jal x1, basemul_acc
    jal x1, whitening
    add x10, x22, x0
  endloop

  /* Compute b = intt(b). */
  la  x10, mpoly_b
  la  x11, twiddles_intt
  add x12, x10, x0
  loopi NSHARES, 3
    jal x1, intt
    jal x1, whitening
    nop
  endloop
  bn.wsrw mod, w16

  /* Compute b += ep. */
  la  x10, mpoly_b
  la  x11, mpoly_ep
  add x12, x10, x0
  loopi NSHARES, 3
    jal    x1, poly_add
    /* Whitening. */
    bn.xor w0, w0, w0
    bn.xor w1, w1, w1
  endloop

  /* Compare b and c[i * cu : (i + 1) * cu]. Accumulate output to r. */
  la   x10, mpoly_b
  add  x11, x19, x0
  add  x12, x27, x0
  add  x14, x2, x0
  addi x15, x21, 2
  jal  x1, masked_poly_compare_du
  /**************************************************************************/
  beq  x0, x0, _finalize_compare

_handle_k2_compute_b:
  /* Generate at[0][0]. */
  la  x11, poly_at
  jal x1, poly_gen_matrix

  /* Prepare for generating at[0][1]. */
  add  x10, x9, x0
  la   x11, seed_ij
  lw   x4, 0(x11)
  addi x4, x4, 0x0100
  sw   x4, 0(x11)
  jal  x1, poly_gen_matrix_init

  /* Compute b = at[0][0] * sp[0]. */
  bn.shv.16h w0, w16 << 1
  bn.wsrw    mod, w0
  la         x22, poly_at
  add        x10, x22, x0
  la         x11, mpolyvec_sp
  la         x12, twiddles_basemul
  la         x13, mpoly_b
  loopi NSHARES, 3
    jal x1, basemul
    jal x1, whitening
    add x10, x22, x0
  endloop
  add     x24, x11, x0
  bn.wsrw mod, w16

  /* Generate at[0][1]. */
  la  x11, poly_at
  jal x1, poly_gen_matrix

  /* Compute b += at[0][1] * sp[1]. */
  bn.shv.16h w0, w16 << 1
  bn.wsrw    mod, w0
  la         x22, poly_at
  add        x10, x22, x0
  add        x11, x24, x0
  la         x12, twiddles_basemul
  la         x13, mpoly_b
  loopi NSHARES, 3
    jal x1, basemul_acc
    jal x1, whitening
    add x10, x22, x0
  endloop

  /* Compute b = intt(b). */
  la  x10, mpoly_b
  la  x11, twiddles_intt
  add x12, x10, x0
  loopi NSHARES, 3
    jal x1, intt
    jal x1, whitening
    nop
  endloop
  bn.wsrw mod, w16

  /* Prepare for generating ep[1]. */
  add  x10, x18, x0
  la   x11, nonce
  lw   x5, 0(x11)
  addi x5, x5, 1
  sw   x5, 0(x11)
  jal  x1, masked_poly_getnoise_eta_init

  /* Compute b += ep. */
  la   x10, mpoly_b
  la   x11, mpoly_ep
  addi x12, x10, 0
  loopi NSHARES, 3
    jal    x1, poly_add
    /* Whitening. */
    bn.xor w0, w0, w0
    bn.xor w1, w1, w1
  endloop

  /* Generate ep[1]. */
  addi x10, x0, 2 /* eta = ETA2 = 2 */
  la   x11, mpoly_ep
  jal  x1, masked_poly_getnoise_eta_2

  /* Prepare for generating at[1][0]. */
  addi x10, x9, 0 /* seed */
  la   x11, seed_ij
  addi x5, x0, 1
  sw   x5, 0(x11)
  jal  x1, poly_gen_matrix_init

  /* Compare b and c[i * cu : (i + 1) * cu]. Accumulate output to r. */
  la   x10, mpoly_b
  add  x11, x19, x0
  addi x12, x0, 320
  add  x14, x2, x0
  add  x15, x21, x0
  jal  x1, masked_poly_compare_du

  /* Generate at[1][0]. */
  la  x11, poly_at
  jal x1, poly_gen_matrix

  /* Prepare for generating at[1][1]. */
  add  x10, x9, x0
  la   x11, seed_ij
  lw   x4, 0(x11)
  addi x4, x4, 0x0100
  sw   x4, 0(x11)
  jal  x1, poly_gen_matrix_init

  /* Compute b = at[1][0] * sp[0]. */
  bn.shv.16h w0, w16 << 1
  bn.wsrw    mod, w0
  la         x22, poly_at
  add        x10, x22, x0
  la         x11, mpolyvec_sp
  la         x12, twiddles_basemul
  la         x13, mpoly_b
  loopi NSHARES, 3
    jal x1, basemul
    jal x1, whitening
    add x10, x22, x0
  endloop
  add     x24, x11, x0
  bn.wsrw mod, w16

  /* Generate at[1][1]. */
  la  x11, poly_at
  jal x1, poly_gen_matrix

  /* Compute b += at[1][1] * sp[1]. */
  bn.shv.16h w0, w16 << 1
  bn.wsrw    mod, w0
  la         x22, poly_at
  add        x10, x22, x0
  add        x11, x24, x0
  la         x12, twiddles_basemul
  la         x13, mpoly_b
  loopi NSHARES, 3
    jal x1, basemul_acc
    jal x1, whitening
    add x10, x22, x0
  endloop

  /* Compute b = intt(b). */
  la  x10, mpoly_b
  la  x11, twiddles_intt
  add x12, x10, x0
  loopi NSHARES, 3
    jal x1, intt
    jal x1, whitening
    nop
  endloop
  bn.wsrw mod, w16

  /* Compute b += ep. */
  la  x10, mpoly_b
  la  x11, mpoly_ep
  add x12, x10, x0
  loopi NSHARES, 3
    jal    x1, poly_add
    /* Whitening. */
    bn.xor w0, w0, w0
    bn.xor w1, w1, w1
  endloop

  /* Compare b and c[i * cu : (i + 1) * cu]. Accumulate output to r. */
  la   x10, mpoly_b
  addi x11, x19, 320
  addi x12, x0, 320
  add  x14, x2, x0
  add  x15, x21, x0
  jal  x1, masked_poly_compare_du
  /**************************************************************************/

  /*** Step 4: w0 = acc, reduced by finalize_cmp and unmasked. ***/
_finalize_compare:
  add x10, x2, x0
  add x11, x0, NSHARES
  jal x1, finalize_cmp

  /* Unmask comparison result. */
  add    x10, x2, x0
  bn.lid x0, 0(x10++)
  addi   x4, x0, 1
  bn.lid x4, 0(x10++)
  bn.xor w0, w0, w1

  add  x2, x3, x0
  lw   x3, 0(x2)
  addi x2, x2, 32
  ret
#endif
