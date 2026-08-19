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

#define N_WDR 16

/**
 * Decryption for the CPA-secure public-key encryption scheme underlying
 * ML-KEM.
 *
 * Uses the decryption key to decrypt a ciphertext.
 *
 * Let d = NSHARES and cu = 32 * du, that is 320 bytes for k = 2, 3 and
 * 352 bytes for k = 4.
 *  Step 1: unpack dk_pke[0] and compute the first product.
 *          dk_pke[0] = poly_frombytes(dk_pke[0 : 384 * d]) // d shares
 *          dk_pke[0] = refreshmodq(dk_pke[0])              // only for d > 1
 *          b         = poly_polyvec_decompress(c[0 : cu])
 *          b         = ntt(b)
 *          m         = b * dk_pke[0]                       // d shares
 *  Step 2: accumulate the remaining products, for j = 1..k - 1.
 *          dk_pke[j] = poly_frombytes(dk_pke[384 * j * d : 384 * (j + 1) * d])
 *          dk_pke[j] = refreshmodq(dk_pke[j])              // only for d > 1
 *          b         = poly_polyvec_decompress(c[j * cu : (j + 1) * cu])
 *          b         = ntt(b)
 *          m        += b * dk_pke[j]
 *  Step 3: m = intt(m)
 *  Step 4: v = poly_decompress(c[k * cu :])
 *  Step 5: m = v - m            // poly_sub subtracts from share 0 only, so
 *                               // shares 1..d - 1 are negated afterwards
 *  Step 6: r = poly_tomsg(m)    // masked_poly_tomsg when d > 1, which returns
 *                               // r in Boolean-shared form
 *
 * @param[in]  x10: dmem pointer to the input ciphertext c
 * @param[in]  x11: dmem pointer to the input packed masked secret key dk_pke
 * @param[out] x12: dmem pointer to the output message m
 * @param[in]  x13: k, the security level
 * @param[in]  w31: all-zero register
 *
 * UNPROTECTED
 * clobbered registers: x2 to x5, x8 to x13, x18 to x19, x21 to x25,
 *                      w0 to w26, w30, acc, acch, mod
 * clobbered flag groups: FG0
 *
 * HARDENED
 * clobbered registers: x2 to x19, x21 to x25, x28 to x31, w0 to w26, w28 to w29,
 *                      acc, acch, mod
 * clobbered flag groups: FG0
 */

.globl indcpa_dec
.type indcpa_dec, @function
indcpa_dec:
  addi x2, x2, -32
  sw   x3, 0(x2)
  add  x3, x2, x0

  add x8, x10, x0
  add x9, x11, x0
  add x18, x12, x0
  add x19, x13, x0

  /* Unpack dk_pke and c polynomial by polynomial, multiply them and accumulate
   * the result in m. */
  la x21, mpoly_sk
  la x22, poly_b
  la x23, mpoly_m
  la x24, twiddles_ntt
  la x25, twiddles_basemul

#ifndef HARDENED
  /*** Step 1: unpack dk_pke[0] and compute the first product. ***/
  /* Unpack dk_pke[0]. */
  add x10, x9, x0
  add x11, x21, x0
  jal x1, poly_frombytes
  add x9, x10, x0

  /* Unpack b <- c[0 : cu]. */
  bn.wsrr   w16, mod
  add       x10, x8, x0
  add       x11, x22, x0
  add       x12, x19, x0
  jal       x1, poly_polyvec_decompress
  add       x8, x10, x0

  /* Compute b = ntt(b). */
  bn.shv.16h w0, w16 << 1
  bn.wsrw    mod, w0
  add        x10, x22, x0
  add        x11, x24, x0
  add        x12, x10, x0
  jal        x1, ntt

  /* Compute m = b * dk_pke[0]. */
  add x11, x21, x0
  add x12, x25, x0
  add x13, x23, x0
  add x10, x22, x0
  jal x1, basemul

  /*** Step 2: accumulate the remaining products, for j = 1..k - 1. ***/
  addi x19, x19, -1
  loop x19, 19
    /* Unpack dk_pke[j]. */
    add x10, x9, x0
    add x11, x21, x0
    jal x1, poly_frombytes
    add x9, x10, x0

    /* Unpack b <- c[j * cu : (j + 1) * cu]. */
    add  x10, x8, x0
    add  x11, x22, x0
    addi x12, x19, 1
    jal  x1, poly_polyvec_decompress
    add  x8, x10, x0

    /* Compute b = ntt(b). */
    add x10, x22, x0
    add x11, x24, x0
    add x12, x10, x0
    jal x1, ntt

    /* Compute m += b * dk_pke[j]. */
    add x10, x22, x0
    add x11, x21, x0
    add x12, x25, x0
    add x13, x23, x0
    jal x1, basemul_acc
    nop
  endloop

  /*** Step 3: m = intt(m). ***/
  add    x10, x23, x0
  la     x11, twiddles_intt
  add    x12, x10, x0
  jal    x1, intt
  bn.wsrw mod, w16

  /*** Step 4: v = poly_decompress(c[k * cu :]). ***/
  add x10, x8, x0
  la  x11, poly_v
  add x12, x19, 1
  jal x1, poly_decompress

  /*** Step 5: m = v - m. ***/
  la  x10, poly_v
  la  x11, mpoly_m
  add x12, x11, x0
  jal x1, poly_sub

  /*** Step 6: r = poly_tomsg(m). ***/
  la  x10, mpoly_m
  add x11, x18, x0
  jal x1, poly_tomsg
#else
  /*** Step 1: unpack dk_pke[0] and compute the first product. ***/
  /* Unpack dk_pke[0]. */
  add x10, x9, x0
  add x11, x21, x0
  loopi NSHARES, 4
    /* Whitening. */
    bn.xor  w0, w0, w0
    bn.xor  w1, w1, w1
    jal     x1, poly_frombytes
    nop
  endloop
  add x9, x10, x0

  /* Refresh dk_pke[0] arithmetic shares (mod = q here). */
  bn.wsrr w16, mod
  add     x10, x21, x0
  add     x12, x21, x0
  jal     x1, refreshmodq

  /* Unpack b <- c[0 : cu]. */
  add x10, x8, x0
  add x11, x22, x0
  add x12, x19, x0
  jal x1, poly_polyvec_decompress
  add x8, x10, x0

  /* Compute b = ntt(b). */
  bn.shv.16h w0, w16 << 1
  bn.wsrw    mod, w0
  add        x10, x22, x0
  add        x11, x24, x0
  add        x12, x10, x0
  jal        x1, ntt

  /* Compute m = b * dk_pke[0]. */
  add x11, x21, x0
  add x12, x25, x0
  add x13, x23, x0
  loopi NSHARES, 4
    jal x1, whitening
    add x10, x22, x0
    jal x1, basemul
    nop
  endloop

  /*** Step 2: accumulate the remaining products, for j = 1..k - 1. ***/
  addi x19, x19, -1
  loop x19, 32
    /* Unpack dk_pke[j]. */
    add x10, x9, x0
    add x11, x21, x0
    loopi NSHARES, 4
      /* Whitening. */
      bn.xor w0, w0, w0
      bn.xor w1, w1, w1
      jal    x1, poly_frombytes
      nop
    endloop
    add x9, x10, x0

    /* Refresh dk_pke[j] arithmetic shares. */
    bn.wsrw    mod, w16
    add        x10, x21, x0
    add        x12, x21, x0
    jal        x1, refreshmodq
    bn.shv.16h w0, w16 << 1
    bn.wsrw    mod, w0

    /* Unpack b <- c[j * cu : (j + 1) * cu]. */
    add  x10, x8, x0
    add  x11, x22, x0
    addi x12, x19, 1
    jal  x1, poly_polyvec_decompress
    add  x8, x10, x0

    /* Compute b = ntt(b). */
    add x10, x22, x0
    add x11, x24, x0
    add x12, x10, x0
    jal x1, ntt

    /* Compute m += b * dk_pke[j]. */
    add x11, x21, x0
    add x12, x25, x0
    add x13, x23, x0
    loopi NSHARES, 4
      jal x1, whitening
      add x10, x22, x0
      jal x1, basemul_acc
      nop
    endloop
    nop
  endloop

  /*** Step 3: m = intt(m). ***/
  add x10, x23, x0
  la  x11, twiddles_intt
  add x12, x10, x0
  loopi NSHARES, 3
    jal x1, whitening
    jal x1, intt
    nop
  endloop
  bn.wsrw mod, w16

  /*** Step 4: v = poly_decompress(c[k * cu :]). ***/
  add  x10, x8, x0
  la   x11, poly_v
  addi x12, x19, 1
  jal  x1, poly_decompress

  /*** Step 5: m = v - m. ***/
  la  x10, poly_v
  la  x11, mpoly_m
  add x12, x11, x0
  jal x1, poly_sub

  /* poly_sub only subtracted m from share 0 of v, so negate the remaining
   * shares 1..d - 1 to make the shared value equal v - m. */
  addi   x5, x0, NSHARES
  addi   x5, x5, -1
  bn.xor w0, w0, w0
  loop x5, 5
    loopi 16, 3
      bn.lid       x0, 0(x11)
      bn.subvm.16h w0, w31, w0
      bn.sid       x0, 0(x11++)
    endloop
    /* Whitening. */
    bn.xor w0, w0, w0
  endloop

  /*** Step 6: r = masked_poly_tomsg(m). ***/
  la  x10, mpoly_m
  add x12, x18, x0
  jal x1, masked_poly_tomsg
#endif

  add  x2, x3, x0
  lw   x3, 0(x2)
  addi x2, x2, 32
  ret
