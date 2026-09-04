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

/* Config to start a SHA3_512 operation. */
#define SHA3_512_CFG 0x10

/**
 * Key generation for the CPA-secure public-key encryption scheme underlying
 * ML-KEM.
 *
 * Uses randomness to generate an encryption key and a corresponding decryption
 * key.
 *
 * Let d = NSHARES. When d > 1, the noise is sampled with the masked gadgets
 * masked_poly_getnoise_eta_{init,1} and sk is kept in d arithmetic shares.
 *  Step 1: publicseed || noiseseed <- SHA3-512(seed || k)
 *  Step 2: generate dk_pke, for i = 0..k - 1:
 *          sk[i] = poly_getnoise_eta_1(noiseseed, i)  // nonce i, d shares
 *          sk[i] = ntt(sk[i])
 *          dk_pke[384 * i * d : 384 * (i + 1) * d] = poly_tobytes(sk[i])
 *  Step 3: generate ek_pke, for i = 0..k - 1:
 *          a[i][j] = poly_gen_matrix(publicseed, i, j), j = 0..k - 1
 *          pk      = poly_tomont(sum_j a[i][j] * sk[j])
 *          e[i]    = poly_getnoise_eta_1(noiseseed, k + i)
 *          pk     += ntt(e[i])
 *          pk      = sum of the d shares of pk         // only for d > 1
 *          ek_pke[384 * i : 384 * (i + 1)] = poly_tobytes(pk)
 *  Step 4: append publicseed to ek_pke
 *
 * @param[in]  x10: dmem pointer to the input seed
 *                  (KYBER_SYMBYTES = 32 bytes per share, 32 * d in total)
 * @param[out] x11: dmem pointer to the output packed public key ek_pke
 * @param[out] x12: dmem pointer to the output packed secret key dk_pke
 * @param[in]  x13: k, the security level
 * @param[in]  w16 (sw0): sw0.0 = q = 3329 (1st 16-bit lane),
 *                        sw0.2 = -q^-1 mod 2^16 = 3327 (3rd 16-bit lane)
 * @param[in]  w31: all-zero register
 *
 * UNPROTECTED
 * clobbered registers: x4 to x13, x18 to x28,
 *                      w0 to w15, w17 to w26, mod, acch, acc
 * clobbered flag groups: FG0
 *
 * HARDENED
 * clobbered registers: x2, x4 to x31, w0 to w30, mod, acch, acc
 * clobbered flag groups: FG0
 */

.globl indcpa_keypair
.type indcpa_keypair, @function
indcpa_keypair:
#ifndef HARDENED
  add x9, x11, x0
  add x18, x12, x0
  add x19, x13, x0

  addi x4, x0, 2
  beq  x19, x4, _handle_k2_eta_1
  addi x20, x0, 2
  beq  x0, x0, _continue

_handle_k2_eta_1:
  addi x20, x0, 3

_continue:

  /*** Step 1: publicseed || noiseseed <- SHA3-512(seed || k). ***/
  /* Initialize a SHA3-512 operation. */
  addi    x11, x0, 33
  slli    x5, x11, 5
  addi    x5, x5, SHA3_512_CFG
  csrrw   x0, kmac_cfg, x5
  /* Send seed. */
  bn.lid  x0, 0(x10)
  bn.wsrw kmac_msg, w0
  /* Send k. */
  addi    x5, x0, 1
  csrrw   x0, kmac_partial_write, x5
  la      x5, buf
  bn.xor  w0, w0, w0
  bn.sid  x0, 0(x5)
  sw      x13, 0(x5)
  bn.lid  x0, 0(x5)
  bn.wsrw kmac_msg, w0
  /* Retrieve publicseed. */
  bn.wsrr w0, kmac_digest
  bn.sid  x0, 0(x5++)
  /* Retrieve noiseseed. */
  bn.wsrr w0, kmac_digest
  bn.sid  x0, 0(x5)

  /*** Step 2: Generate dk_pke. ***/
  /* The following block will:
   *  (1) sample sk[i],
   *  (2) compute sk[i] = ntt(sk[i]),
   *  (3) pack sk[i] to dk_pke[i]. */
  /**************************************************************************/
  la     x8, buf
  la     x21, nonce
  bn.xor w0, w0, w0
  bn.sid x0, 0(x21)
  /* Prepare for generating sk[0]. */
  addi   x10, x8, 32
  add    x11, x21, x0
  jal    x1, poly_getnoise_eta_init
  la     x22, mpolyvec_sk
  la     x23, twiddles_ntt

  addi x19, x19, -1 /* k - 1 */
  loop x19, 21
    /* Generate sk[i]. */
    add x10, x20, x0
    add x11, x22, x0
    jal x1, poly_getnoise_eta_1

    /* Prepare for generating sk[i + 1]. */
    addi x10, x8, 32
    add  x11, x21, x0
    lw   x5, 0(x11)
    addi x5, x5, 1
    sw   x5, 0(x11)
    jal  x1, poly_getnoise_eta_init

    /* Compute sk[i] = ntt(sk[i]). */
    bn.shv.16h w0, w16 << 1
    bn.wsrw    mod, w0
    add        x10, x22, x0
    add        x11, x23, x0
    add        x12, x10, x0
    jal        x1, ntt
    bn.wsrw    mod, w16

    /* Pack dk_pke[i] <- sk[i]. */
    add x10, x22, x0
    add x11, x18, x0
    jal x1, poly_tobytes
    add x22, x10, x0
    add x18, x11, x0
  endloop

  /* Generate sk[k - 1]. */
  add x10, x20, x0
  add x11, x22, x0
  jal x1, poly_getnoise_eta_1

  /* Compute sk[k - 1] = ntt(sk[k - 1]). */
  bn.shv.16h w0, w16 << 1
  bn.wsrw    mod, w0
  add        x10, x22, x0
  add        x11, x23, x0
  add        x12, x10, x0
  jal        x1, ntt
  bn.wsrw    mod, w16

  /* Prepare for generating a[0][0]. */
  add    x10, x8, x0
  la     x11, seed_ij
  bn.xor w0, w0, w0
  bn.sid x0, 0(x11)
  jal    x1, poly_gen_matrix_init

  /* Pack dk_pke[k - 1] <- sk[k - 1]. */
  add x10, x22, x0
  add x11, x18, x0
  jal x1, poly_tobytes

  /* Save current addresses of sk. */
  la x5, dptr_sk
  sw x11, 0(x5)
  /**************************************************************************/

  /*** Step 3: Generate ek_pke. ***/
  /* The following block will do:
   *  (1) generate a[i][0],
   *  (2) compute pk = a[i][0] * sk[0],
   *  (3) generate a[i][j],
   *  (4) compute pk += a[i][j] * sk[j],
   *  (5) repeat (3) + (4) for j = 1..k - 1.
   *  (6) compute pk = poly_tomont(pk),
   *  (7) generate e[i],
   *  (8) compute e[i] = ntt(e[i]),
   *  (9) compute pk += e[i],
   *  (10) pack pk to ek_pke[i],
   *  (11) repeat (1) to (10) for i = 0..k - 1. */
  /**************************************************************************/

  la   x21, nonce
  la   x22, mpolyvec_sk
  la   x23, twiddles_basemul
  la   x24, seed_ij
  la   x25, poly_at /* also mpoly_e */
  la   x26, mpoly_pk

  addi x18, x19, -1 /* k - 2 (x19 = k - 1) */
  addi x5, x0, 0x0100
  sub  x27, x5, x19 /* 0x0100 - (k - 1) */

  loop x19, 78
    /* Generate a[i][0]. */
    add x11, x25, x0
    jal x1, poly_gen_matrix

    /* Prepare for generating a[i][1]. */
    add  x10, x8, x0
    add  x11, x24, x0
    lw   x5, 0(x11)
    addi x5, x5, 1
    sw   x5, 0(x11)
    jal  x1, poly_gen_matrix_init

    /* Compute pk = a[i][0] * sk[0]. */
    bn.shv.16h w0, w16 << 1
    bn.wsrw    mod, w0
    add        x10, x25, x0
    la         x22, mpolyvec_sk
    add        x11, x22, x0
    add        x12, x23, x0
    add        x13, x26, x0
    jal        x1, basemul
    add        x22, x11, x0

    /* Skip the middle columns when k = 2 (x18 = k - 2 = 0); a hardware
     * loop must have a non-zero iteration count. */
    beq  x18, x0, _skip_inner_cols
    loop x18, 14
      /* Generate a[i][j]. */
      add x11, x25, x0
      jal x1, poly_gen_matrix

      /* Prepare for generating a[i][j + 1]. */
      add  x10, x8, x0
      add  x11, x24, x0
      lw   x5, 0(x11)
      addi x5, x5, 1
      sw   x5, 0(x11)
      jal  x1, poly_gen_matrix_init

      /* Compute pk += a[i][j] * sk[j]. */
      add x10, x25, x0
      add x11, x22, x0
      add x12, x23, x0
      add x13, x26, x0
      jal x1, basemul_acc
      add x22, x11, x0
    endloop
    _skip_inner_cols:

    /* Generate a[i][k - 1]. */
    add x11, x25, x0
    jal x1, poly_gen_matrix

    /* Prepare for generating e[i]. */
    addi x10, x8, 32
    add  x11, x21, x0
    lw   x5, 0(x11)
    addi x5, x5, 1
    sw   x5, 0(x11)
    jal  x1, poly_getnoise_eta_init

    /* Compute pk += a[i][k - 1] * sk[k - 1]. */
    add     x10, x25, x0
    add     x11, x22, x0
    add     x12, x23, x0
    add     x13, x26, x0
    jal     x1, basemul_acc
    bn.wsrw mod, w16

    /* Generate e[i]. */
    add x10, x20, x0
    la  x11, mpoly_e
    jal x1, poly_getnoise_eta_1

    /* Prepare for generating a[i + 1][0]. */
    add  x10, x8, x0
    add  x11, x24, x0
    lw   x5, 0(x11)
    add  x5, x5, x27
    sw   x5, 0(x11)
    jal  x1, poly_gen_matrix_init

    /* Compute pk = tomont(pk). */
    add x10, x26, x0
    jal x1, poly_tomont

    /* Compute e[i] = ntt(e[i]). */
    bn.shv.16h w0, w16 << 1
    bn.wsrw    mod, w0
    la         x10, mpoly_e
    la         x11, twiddles_ntt
    add        x12, x10, x0
    jal        x1, ntt
    bn.wsrw    mod, w16

    /* Compute pk += e[i]. */
    add x10, x26, x0
    la  x11, mpoly_e
    add x12, x26, x0
    jal x1, poly_add

    /* Pack ek_pke[i] <- pk. */
    add x10, x26, x0
    add x11, x9, x0
    jal x1, poly_tobytes
    add x9, x11, x0
  endloop

  /* Generate a[k - 1][0]. */
  add x11, x25, x0
  jal x1, poly_gen_matrix

  /* Prepare for generating a[k - 1][1]. */
  add  x10, x8, x0
  add  x11, x24, x0
  lw   x5, 0(x11)
  addi x5, x5, 1
  sw   x5, 0(x11)
  jal  x1, poly_gen_matrix_init

  /* Compute pk = a[k - 1][0] * sk[0]. */
  bn.shv.16h w0, w16 << 1
  bn.wsrw    mod, w0
  add        x10, x25, x0
  la         x22, mpolyvec_sk
  add        x11, x22, x0
  add        x12, x23, x0
  add        x13, x26, x0
  jal        x1, basemul
  add        x22, x11, x0

  /* Skip the middle columns when k = 2 (x18 = k - 2 = 0); a hardware
   * loop must have a non-zero iteration count. */
  beq  x18, x0, _skip_inner_cols_tail
  loop x18, 14
    /* Generate a[k - 1][j]. */
    add x11, x25, x0
    jal x1, poly_gen_matrix

    /* Prepare for generating a[k - 1][j + 1]. */
    add  x10, x8, x0
    add  x11, x24, x0
    lw   x5, 0(x11)
    addi x5, x5, 1
    sw   x5, 0(x11)
    jal  x1, poly_gen_matrix_init

    /* Compute pk += a[k - 1][j] * sk[j]. */
    add x10, x25, x0
    add x11, x22, x0
    add x12, x23, x0
    add x13, x26, x0
    jal x1, basemul_acc
    add x22, x11, x0
  endloop
  _skip_inner_cols_tail:

  /* Generate a[k - 1][k - 1]. */
  add x11, x25, x0
  jal x1, poly_gen_matrix

  /* Prepare for generating e[k - 1]. */
  addi x10, x8, 32
  add  x11, x21, x0
  lw   x5, 0(x11)
  addi x5, x5, 1
  sw   x5, 0(x11)
  jal  x1, poly_getnoise_eta_init

  /* Compute pk += a[k - 1][k - 1] * sk[k - 1]. */
  add     x10, x25, x0
  add     x11, x22, x0
  add     x12, x23, x0
  add     x13, x26, x0
  jal     x1, basemul_acc
  bn.wsrw mod, w16

  /* Generate e[k - 1]. */
  add x10, x20, x0
  la  x11, mpoly_e
  jal x1, poly_getnoise_eta_1

  /* Compute pk = tomont(pk). */
  add x10, x26, x0
  jal x1, poly_tomont

  /* Compute e[k - 1] = ntt(e[k - 1]). */
  bn.shv.16h w0, w16 << 1
  bn.wsrw    mod, w0
  la         x10, mpoly_e
  la         x11, twiddles_ntt
  add        x12, x10, x0
  jal        x1, ntt
  bn.wsrw    mod, w16

  /* Compute pk += e[k - 1]. */
  add x10, x26, x0
  la  x11, mpoly_e
  add x12, x26, x0
  jal x1, poly_add

  /* Pack ek_pke[k - 1] <- pk. */
  add x10, x26, x0
  add x11, x9, x0
  jal x1, poly_tobytes

_handle_common:
  /*** Step 4: append publicseed to ek_pke. ***/
  la     x5, buf
  bn.lid x0, 0(x5)
  bn.sid x0, 0(x11)
  ret

#else
  add x9, x11, x0
  add x18, x12, x0
  add x19, x13, x0

  addi x4, x0, 2
  beq  x19, x4, _handle_k2_eta_1
  addi x20, x0, 2
  beq  x0, x0, _continue

_handle_k2_eta_1:
  addi x20, x0, 3

_continue:
  /*** Step 1: publicseed || noiseseed <- SHA3-512(seed || k). ***/
  /* Initialize a SHA3-512 operation. */
  addi    x11, x0, 33
  slli    x5, x11, 5
  addi    x5, x5, SHA3_512_CFG
  addi    x6, x0, 1
  slli    x6, x6, 20
  add     x5, x5, x6
  csrrw   x0, kmac_cfg, x5
  /* Send seed. */
  bn.lid  x0, 0(x10++)
  bn.wsrw kmac_msg, w0
  bn.xor  w0, w31, w31 /* Whitening. */
  bn.lid  x0, 0(x10)
  bn.wsrw kmac_msg1, w0
  bn.xor  w0, w31, w31 /* Whitening. */
  /* Send k. */
  addi    x5, x0, 1
  csrrw   x0, kmac_partial_write, x5
  la      x5, buf
  bn.xor  w0, w31, w31
  bn.sid  x0, 0(x5)
  sw      x13, 0(x5)
  bn.lid  x0, 0(x5)
  bn.wsrw kmac_msg, w0
  bn.xor  w0, w31, w31
  bn.wsrw kmac_msg1, w0
  /* Retrieve publicseed. */
  bn.wsrr w0, kmac_digest
  bn.wsrr w1, kmac_digest1
  bn.xor  w0, w0, w1
  bn.sid  x0, 0(x5++)
  /* Retrieve noiseseed. */
  bn.wsrr w0, kmac_digest
  bn.sid  x0, 0(x5++)
  bn.xor  w0, w31, w31 /* Whitening. */
  bn.wsrr w0, kmac_digest1
  bn.sid  x0, 0(x5++)
  bn.xor  w0, w31, w31 /* Whitening. */

  /*** Step 2: Generate dk_pke. ***/
  /* The following block will:
   *  (1) sample sk[i],
   *  (2) compute sk[i] = ntt(sk[i]),
   *  (3) pack sk[i] to dk_pke[i]. */
  /**************************************************************************/
  la     x8, buf
  la     x21, nonce
  bn.xor w0, w31, w31
  bn.sid x0, 0(x21)
  /* Prepare for generating sk[0]. */
  addi   x10, x8, 32
  add    x11, x21, x0
  jal    x1, masked_poly_getnoise_eta_init
  la     x22, mpolyvec_sk
  la     x23, twiddles_ntt

  addi x19, x19, -1 /* k - 1 */
  loop x19, 27
    /* Generate sk[i]. */
    add x10, x20, x0
    add x11, x22, x0
    jal x1, masked_poly_getnoise_eta_1

    /* Prepare for generating sk[i + 1]. */
    addi x10, x8, 32
    add  x11, x21, x0
    lw   x5, 0(x11)
    addi x5, x5, 1
    sw   x5, 0(x11)
    jal  x1, masked_poly_getnoise_eta_init

    /* Compute sk[i] = ntt(sk[i]). */
    bn.shv.16h w0, w16 << 1
    bn.wsrw    mod, w0
    add        x10, x22, x0
    add        x11, x23, x0
    add        x12, x10, x0
    loopi NSHARES, 3
      jal x1, ntt
      jal x1, whitening
      nop
    endloop
    bn.wsrw mod, w16

    /* Pack dk_pke[i] <- sk[i]. */
    add x10, x22, x0
    add x11, x18, x0
    loopi NSHARES, 3
      jal x1, poly_tobytes
      /* Whitening. */
      bn.xor w0, w31, w31
      bn.xor w1, w31, w31
    endloop
    add x22, x10, x0
    add x18, x11, x0
  endloop

  /* Generate sk[k - 1]. */
  add x10, x20, x0
  add x11, x22, x0
  jal x1, masked_poly_getnoise_eta_1

  /* Compute sk[k - 1] = ntt(sk[k - 1]). */
  bn.shv.16h w0, w16 << 1
  bn.wsrw    mod, w0

  add x10, x22, x0
  add x11, x23, x0
  add x12, x10, x0
  loopi NSHARES, 3
    jal x1, ntt
    jal x1, whitening
    nop
  endloop
  bn.wsrw mod, w16

  /* Prepare for generating a[0][0]. */
  add    x10, x8, x0
  la     x11, seed_ij
  bn.xor w0, w31, w31
  bn.sid x0, 0(x11)
  jal    x1, poly_gen_matrix_init

  /* Pack dk_pke[k - 1] <- sk[k - 1]. */
  add x10, x22, x0
  add x11, x18, x0
  loopi NSHARES, 3
    jal    x1, poly_tobytes
    /* Whitening. */
    bn.xor w0, w31, w31
    bn.xor w1, w31, w31
  endloop

  /* Save current addresses of sk. */
  la x5, dptr_sk
  sw x11, 0(x5)
  /**************************************************************************/

  /*** Step 3: Generate ek_pke. ***/
  /* The following block will do:
   *  (1) generate a[i][0],
   *  (2) compute pk = a[i][0] * sk[0],
   *  (3) generate a[i][j],
   *  (4) compute pk += a[i][j] * sk[j],
   *  (5) repeat (3) + (4) for j = 1..k - 1.
   *  (6) compute pk = poly_tomont(pk),
   *  (7) generate e[i],
   *  (8) compute e[i] = ntt(e[i]),
   *  (9) compute pk += e[i],
   *  (10) pack pk to ek_pke[i],
   *  (11) repeat (1) to (10) for i = 0..k - 1. */
  /**************************************************************************/
  la   x21, nonce
  la   x22, mpolyvec_sk
  la   x23, twiddles_basemul
  la   x24, seed_ij
  la   x25, poly_at /* also mpoly_e */
  la   x26, mpoly_pk

  addi x18, x19, -1 /* k - 2 (x19 = k - 1) */
  addi x5, x0, 0x0100
  sub  x27, x5, x19 /* 0x0100 - (k - 1) */

  loop x19, 103
    /* Generate a[i][0]. */
    add x11, x25, x0
    jal x1, poly_gen_matrix

    /* Prepare for generating a[i][1]. */
    add  x10, x8, x0
    add  x11, x24, x0
    lw   x5, 0(x11)
    addi x5, x5, 1
    sw   x5, 0(x11)
    jal  x1, poly_gen_matrix_init

    /* Compute pk = a[i][0] * sk[0]. */
    bn.shv.16h w0, w16 << 1
    bn.wsrw    mod, w0

    add x10, x25, x0
    la  x11, mpolyvec_sk
    add x12, x23, x0
    add x13, x26, x0
    loopi NSHARES, 3
      jal x1, basemul
      jal x1, whitening
      add x10, x25, x0
    endloop
    add x22, x11, x0

    /* Skip the middle columns when k = 2 (x18 = k - 2 = 0); a hardware
     * loop must have a non-zero iteration count. */
    beq  x18, x0, _skip_inner_cols
    loop x18, 17
      /* Generate a[i][j]. */
      add x11, x25, x0
      jal x1, poly_gen_matrix

      /* Prepare for generating a[i][j + 1]. */
      add  x10, x8, x0
      add  x11, x24, x0
      lw   x5, 0(x11)
      addi x5, x5, 1
      sw   x5, 0(x11)
      jal  x1, poly_gen_matrix_init

      /* Compute pk += a[i][j] * sk[j]. */
      add x10, x25, x0
      add x11, x22, x0
      add x12, x23, x0
      add x13, x26, x0
      loopi NSHARES, 3
        jal x1, basemul_acc
        jal x1, whitening
        add x10, x25, x0
      endloop
      add x22, x11, x0
    endloop
    _skip_inner_cols:

    /* Generate a[i][k - 1]. */
    add x11, x25, x0
    jal x1, poly_gen_matrix

    /* Prepare for generating e[i]. */
    addi x10, x8, 32
    add  x11, x21, x0
    lw   x5, 0(x11)
    addi x5, x5, 1
    sw   x5, 0(x11)
    jal  x1, masked_poly_getnoise_eta_init

    /* Compute pk += a[i][k - 1] * sk[k - 1]. */
    add x10, x25, x0
    add x11, x22, x0
    add x12, x23, x0
    add x13, x26, x0
    loopi NSHARES, 3
      jal x1, basemul_acc
      jal x1, whitening
      add x10, x25, x0
    endloop
    bn.wsrw mod, w16

    /* Generate e[i]. */
    add x10, x20, x0
    la  x11, mpoly_e
    jal x1, masked_poly_getnoise_eta_1

    /* Prepare for generating a[i + 1][0]. */
    add x10, x8, x0
    add x11, x24, x0
    lw  x5, 0(x11)
    add x5, x5, x27
    sw  x5, 0(x11)
    jal x1, poly_gen_matrix_init

    /* Compute pk = tomont(pk). */
    add x10, x26, x0
    loopi NSHARES, 3
      jal    x1, poly_tomont
      /* Whitening. */
      bn.xor w0, w31, w31
      bn.xor w1, w31, w31
    endloop

    /* Compute e[i] = ntt(e[i]). */
    bn.shv.16h w0, w16 << 1
    bn.wsrw    mod, w0

    la  x10, mpoly_e
    la  x11, twiddles_ntt
    add x12, x10, x0
    loopi NSHARES, 3
      jal x1, ntt
      jal x1, whitening
      nop
    endloop

    /* Compute pk += e[i]. */
    add x10, x26, x0
    la  x11, mpoly_e
    add x12, x26, x0
    loopi NSHARES, 3
      jal    x1, poly_add
      /* Whitening. */
      bn.xor w0, w31, w31
      bn.xor w1, w31, w31
    endloop

    /* Unmask pk. */
    addi x4, x0, 1
    add  x5, x26, x0
    addi x6, x5, 512
    loopi 16, 4
      bn.lid       x0, 0(x5)
      bn.lid       x4, 0(x6++)
      bn.addvm.16h w0, w0, w1
      bn.sid       x0, 0(x5++)
    endloop

    bn.wsrw mod, w16

    /* Pack ek_pke[i] <- pk. */
    add x10, x26, x0
    add x11, x9, x0
    jal x1, poly_tobytes
    add x9, x11, x0
  endloop

  /* Generate a[k - 1][0]. */
  add x11, x25, x0
  jal x1, poly_gen_matrix

  /* Prepare for generating a[k - 1][1]. */
  add  x10, x8, x0
  add  x11, x24, x0
  lw   x5, 0(x11)
  addi x5, x5, 1
  sw   x5, 0(x11)
  jal  x1, poly_gen_matrix_init

  /* Compute pk = a[k - 1][0] * sk[0]. */
  bn.shv.16h w0, w16 << 1
  bn.wsrw    mod, w0

  add x10, x25, x0
  la  x11, mpolyvec_sk
  add x12, x23, x0
  add x13, x26, x0
  loopi NSHARES, 3
    jal x1, basemul
    jal x1, whitening
    add x10, x25, x0
  endloop
  add x22, x11, x0

  /* Skip the middle columns when k = 2 (x18 = k - 2 = 0); a hardware
   * loop must have a non-zero iteration count. */
  beq  x18, x0, _skip_inner_cols_tail
  loop x18, 17
    /* Generate a[k - 1][j]. */
    add x11, x25, x0
    jal x1, poly_gen_matrix

    /* Prepare for generating a[k - 1][j + 1]. */
    add  x10, x8, x0
    add  x11, x24, x0
    lw   x5, 0(x11)
    addi x5, x5, 1
    sw   x5, 0(x11)
    jal  x1, poly_gen_matrix_init

    /* Compute pk += a[k - 1][j] * sk[j]. */
    add x10, x25, x0
    add x11, x22, x0
    add x12, x23, x0
    add x13, x26, x0
    loopi NSHARES, 3
      jal x1, basemul_acc
      jal x1, whitening
      add x10, x25, x0
    endloop
    add x22, x11, x0
  endloop
  _skip_inner_cols_tail:

  /* Generate a[k - 1][k - 1]. */
  add x11, x25, x0
  jal x1, poly_gen_matrix

  /* Prepare for generating e[k - 1]. */
  addi x10, x8, 32
  add  x11, x21, x0
  lw   x5, 0(x11)
  addi x5, x5, 1
  sw   x5, 0(x11)
  jal  x1, masked_poly_getnoise_eta_init

  /* Compute pk += a[k - 1][k - 1] * sk[k - 1]. */
  add x10, x25, x0
  add x11, x22, x0
  add x12, x23, x0
  add x13, x26, x0
  loopi NSHARES, 3
    jal x1, basemul_acc
    jal x1, whitening
    add x10, x25, x0
  endloop
  bn.wsrw mod, w16

  /* Generate e[k - 1]. */
  add x10, x20, x0
  la  x11, mpoly_e
  jal x1, masked_poly_getnoise_eta_1

  /* Compute pk = tomont(pk). */
  add x10, x26, x0
  loopi NSHARES, 3
    jal    x1, poly_tomont
    /* Whitening. */
    bn.xor w0, w31, w31
    bn.xor w1, w31, w31
  endloop

  /* Compute e[k - 1] = ntt(e[k - 1]). */
  bn.shv.16h w0, w16 << 1
  bn.wsrw    mod, w0

  la  x10, mpoly_e
  la  x11, twiddles_ntt
  add x12, x10, x0
  loopi NSHARES, 3
    jal x1, ntt
    jal x1, whitening
    nop
  endloop

  /* Compute pk += e[k - 1]. */
  add x10, x26, x0
  la  x11, mpoly_e
  add x12, x26, x0
  loopi NSHARES, 3
    jal    x1, poly_add
    /* Whitening. */
    bn.xor w0, w31, w31
    bn.xor w1, w31, w31
  endloop

  /* Unmask pk. */
  addi x4, x0, 1
  add  x5, x26, x0
  addi x6, x5, 512
  loopi 16, 4
    bn.lid       x0, 0(x5)
    bn.lid       x4, 0(x6++)
    bn.addvm.16h w0, w0, w1
    bn.sid       x0, 0(x5++)
  endloop

  bn.wsrw mod, w16

  /* Pack ek_pke[k - 1] <- pk. */
  add x10, x26, x0
  add x11, x9, x0
  jal x1, poly_tobytes
  /**************************************************************************/

_handle_common:
  /*** Step 4: append publicseed to ek_pke. ***/
  la     x5, buf
  bn.lid x0, 0(x5)
  bn.sid x0, 0(x11)
  ret
#endif
