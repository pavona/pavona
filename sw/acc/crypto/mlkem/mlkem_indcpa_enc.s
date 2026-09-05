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

/**
 * Encryption for the CPA-secure public-key encryption scheme underlying
 * ML-KEM.
 *
 * Uses the encryption key to encrypt a plaintext message with the randomness r.
 *
 * Let cv = 32 * dv and cu = 32 * du, that is cv = 128 and cu = 320 bytes for
 * k = 2, 3 and cv = 160 and cu = 352 bytes for k = 4. The output ciphertext is
 * laid out as c = u || v, with u in c[0 : k * cu] and v in
 * c[k * cu : k * cu + cv].
 *  Step 1: kpoly = poly_frommsg(m)
 *  Step 2: compute v and store it to c[k * cu : k * cu + cv].
 *          for i = 0..k - 1:
 *            ek_pke[i] = poly_frombytes(ek_pke[384 * i : 384 * (i + 1)])
 *            sp[i]     = poly_getnoise_eta_1(r, i)       // nonce i
 *            v        += ek_pke[i] * ntt(sp[i])
 *          v = intt(v) + kpoly + epp                     // epp: nonce 2 * k
 *          c[k * cu : k * cu + cv] = poly_compress(v)
 *  Step 3: compute u row by row, storing each to c[i * cu : (i + 1) * cu].
 *          for i = 0..k - 1:
 *            b = sum_j at[i][j] * sp[j], j = 0..k - 1    // at[i][j] from rho
 *            b = intt(b) + ep[i]                         // ep[i]: nonce k + i
 *            c[i * cu : (i + 1) * cu] = poly_polyvec_compress(b)
 *
 * @param[in]  x10: dmem pointer to the input message m
 * @param[in]  x11: dmem pointer to the input packed public key ek_pke
 * @param[in]  x12: dmem pointer to the input randomness r (32 bytes)
 * @param[out] x13: dmem pointer to the output ciphertext
 * @param[in]  x14: k, the security level
 * @param[in]  w16 (sw0): sw0.0 = q = 3329 (1st 16-bit lane),
 *                        sw0.2 = -q^-1 mod 2^16 = 3327 (3rd 16-bit lane)
 * @param[in]  w31: all-zero register
 *
 * clobbered registers: x4 to x13, x18 to x19, x21 to x24, x26 to x28,
 *                      w0 to w15, w17 to w26, mod, acch, acc
 * clobbered flag groups: FG0
 */

.globl indcpa_enc
.type indcpa_enc, @function
indcpa_enc:
  add x9, x11, x0
  add x18, x12, x0
  add x19, x13, x0
  add x21, x14, x0

  addi x4, x0, 4
  beq  x21, x4, _compute_k4_consts
  addi x26, x0, 128 /* dv * 32 = 4 * 32 */
  addi x27, x0, 320 /* du * 32 = 10 * 32 */
  beq  x0, x0, _continue

_compute_k4_consts:
  addi x26, x0, 160 /* dv * 32 = 5 * 32 */
  addi x27, x0, 352 /* du * 32 = 11 * 32 */

_continue:
  /*** Step 1: kpoly = poly_frommsg(m). ***/
  /* x10 already points to m. */
  la   x11, mpoly_k
  jal  x1, poly_frommsg

  /*** Step 2: compute v and store it to c. ***/
  /* The following block will:
   *  (1) unpack ek_pke[i],
   *  (2) sample sp[i],
   *  (3) compute sp[i] = ntt(sp[i]),
   *  (4) compute v += ek_pke[i] * sp[i],
   *  (5) compute v = intt(v),
   *  (6) compute v += kpoly
   *  (7) sample epp
   *  (8) compute v += epp,
   *  (9) compress v into c[k * cu : k * cu + cv]. */
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
  la         x11, const_tw_ntt
  add        x12, x10, x0
  jal        x1, ntt

  /* Compute v = ek_pke[0] * sp[0]. */
  la      x10, poly_pk
  la      x11, mpolyvec_sp
  la      x12, const_tw_basemul
  la      x13, mpoly_v
  jal     x1, basemul
  add     x24, x11, x0
  bn.wsrw mod, w16

  /* At this point:
   *  - x9 points to packed pk.
   *  - x18 points to r (for cbd).
   *  - x19 points to c (the output ciphertext).
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
  la         x11, const_tw_ntt
  add        x12, x10, x0
  jal        x1, ntt

  /* Compute v += ek_pke[1] * sp[1]. */
  la      x10, poly_pk
  add     x11, x24, x0
  la      x12, const_tw_basemul
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
  la         x11, const_tw_ntt
  add        x12, x10, x0
  jal       x1, ntt

  /* Compute v += ek_pke[2] * sp[2]. */
  la      x10, poly_pk
  add     x11, x24, x0
  la      x12, const_tw_basemul
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
  la         x11, const_tw_ntt
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
  la  x12, const_tw_basemul
  la  x13, mpoly_v
  jal x1, basemul_acc

  /* Compute v = intt(v). */
  la      x10, mpoly_v
  la      x11, const_tw_intt
  add     x12, x10, x0
  jal     x1, intt
  bn.wsrw mod, w16

  /* Compute v += kpoly. */
  la  x10, mpoly_v
  la  x11, mpoly_k
  add x12, x10, x0
  jal x1, poly_add

  /* Generate epp. */
  la   x11, mpoly_epp
  jal  x1, poly_getnoise_eta_2

  /* Prepare for initial `poly_getnoise_eta_2` call: generate ep. */
  add x10, x18, x0
  la  x11, nonce
  sw  x21, 0(x11)
  jal x1, poly_getnoise_eta_init

  /* Compute v += epp. */
  la   x10, mpoly_v
  la   x11, mpoly_epp
  addi x12, x10, 0
  jal  x1, poly_add

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
  add x11, x19, x0
  loop x21, 1
      add x11, x11, x27
  endloop
  add x12, x21, x0
  jal x1, poly_compress

  /**************************************************************************/


  /*** Step 3: compute u row by row and store it to c. ***/
  /* The following block will:
   *  (1) sample at.row[i],
   *  (2) compute b = at.row[i] * sp[i],
   *  (3) compute b = intt(b),
   *  (4) sample ep[i]
   *  (5) compute b += ep[i],
   *  (6) compress b into c[i * cu : (i + 1) * cu]. */
  /**************************************************************************/

  /* At this point:
   *  - x8 is free.
   *  - x9 points to seed (for matrix generation).
   *  - x18 points to r (for cbd).
   *  - x19 points to c (the output ciphertext).
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

  /* Loop over i = 1..k - 1. */
  loop x8, 95
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
    la         x12, const_tw_basemul
    la         x13, mpoly_b
    jal        x1, basemul
    add        x24, x11, x0
    bn.wsrw    mod, w16

    loop x21, 22
      /* Generate at[i][j]. */
      la   x11, poly_at
      jal  x1, poly_gen_matrix

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
      la         x12, const_tw_basemul
      la         x13, mpoly_b
      jal        x1, basemul_acc
      add        x24, x11, x0
      bn.wsrw    mod, w16
    endloop

    /* Generate at[i][k - 1]. */
    la   x11, poly_at
    jal  x1, poly_gen_matrix

    /* Compute b += at[i][k - 1] * sp[k - 1]. */
    bn.shv.16h w0, w16 << 1
    bn.wsrw    mod, w0
    la         x10, poly_at
    add        x11, x24, x0
    la         x12, const_tw_basemul
    la         x13, mpoly_b
    jal        x1, basemul_acc

    /* Compute b = intt(b). */
    la      x10, mpoly_b
    la      x11, const_tw_intt
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
    add  x11, x19, x0
    addi x12, x21, 2
    jal  x1, poly_polyvec_compress
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
  la         x10, poly_at
  la         x11, mpolyvec_sp
  la         x12, const_tw_basemul
  la         x13, mpoly_b
  jal        x1, basemul
  add        x24, x11, x0
  bn.wsrw    mod, w16

  loop x21, 22
    /* Generate at[k - 1][j]. */
    la  x11, poly_at
    jal x1, poly_gen_matrix

    /* Prepare for generating at[k - 1][j + 1]. */
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
    la         x12, const_tw_basemul
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
  la         x12, const_tw_basemul
  la         x13, mpoly_b
  jal        x1, basemul_acc

  /* Compute b = intt(b). */
  la      x10, mpoly_b
  la      x11, const_tw_intt
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
  add  x11, x19, x0
  addi x12, x21, 2
  jal  x1, poly_polyvec_compress
  /**************************************************************************/
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
  la         x12, const_tw_basemul
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
  la         x12, const_tw_basemul
  la         x13, mpoly_b
  jal        x1, basemul_acc

  /* Compute b = intt(b). */
  la      x10, mpoly_b
  la      x11, const_tw_intt
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
  la   x11, mpoly_ep
  jal  x1, poly_getnoise_eta_2

  /* Prepare for generating at[1][0]. */
  add  x10, x9, x0
  la   x11, seed_ij
  addi x5, x0, 1
  sw   x5, 0(x11)
  jal  x1, poly_gen_matrix_init

  /* Compress b. */
  la  x10, mpoly_b
  add x11, x19, x0
  add x12, x21, x0
  jal x1, poly_polyvec_compress

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
  la         x12, const_tw_basemul
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
  la         x12, const_tw_basemul
  la         x13, mpoly_b
  jal        x1, basemul_acc

  /* Compute b = intt(b). */
  la      x10, mpoly_b
  la      x11, const_tw_intt
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
  addi x11, x19, 320
  add  x12, x21, x0
  jal  x1, poly_polyvec_compress
  /**************************************************************************/
  ret
