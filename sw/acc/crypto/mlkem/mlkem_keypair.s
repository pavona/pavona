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

/* Config to start a SHA3_256 operation. */
#define SHA3_256_CFG 0x8

/**
 * Key generation for the CCA-secure ML-KEM key encapsulation mechanism.
 *
 * Generates an encapsulation key and a corresponding decapsulation key.
 *
 * The seed buffer holds d || z, that is 2 * KYBER_SYMBYTES = 64 bytes. When
 * built with HARDENED, both halves are Boolean-shared into two shares each, so
 * the buffer holds d_0 || d_1 || z_0 || z_1 and is 128 bytes long instead. The
 * packed ek_pke is 384 * k + 32 bytes, that is 800, 1184 and 1568 bytes for
 * k = 2, 3 and 4.
 *  Step 1: ek_pke, dk_pke <- indcpa_keypair(d)
 *  Step 2: ek <- ek_pke; append ek to dk_pke, then append h = SHA3-256(ek)
 *  Step 3: append z, giving dk = dk_pke || ek || h || z
 *
 * @param[in]  x10: dmem pointer to the input randomness coins
 * @param[out] x11: dmem pointer to the output public key ek
 * @param[out] x12: dmem pointer to the output secret key dk
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

.globl crypto_kem_keypair
.type crypto_kem_keypair, @function
crypto_kem_keypair:
  la x5, dptr_coins
  sw x10, 0(x5)
  la x5, dptr_pk
  sw x11, 0(x5)
  la x5, k
  sw x13, 0(x5)

#ifdef HARDENED
  /* Refresh the Boolean shares of seed d (coins + 0, coins + 32). */
  add  x8, x10, x0
  add  x9, x11, x0
  add  x18, x12, x0
  addi x11, x0, 1
  addi x12, x0, 32
  add  x14, x10, x0
  jal  x1, refreshios
  add  x10, x8, x0
  add  x11, x9, x0
  add  x12, x18, x0
#endif

  /*** Step 1: ek_pke, dk_pke = indcpa_keypair(d). ***/
  /* x10 already points to d. */
  jal  x1, indcpa_keypair

  la   x5, k
  lw   x5, 0(x5)
  addi x4, x0, 2
  beq  x5, x4, _pk_len_k2
  addi x4, x0, 3
  beq  x5, x4, _pk_len_k3
  addi x8, x0, 1568 /* Byte length of ek_pke for k = 4. */
  beq  x0, x0, _continue

_pk_len_k3:
  addi x8, x0, 1184 /* Byte length of ek_pke for k = 3. */
  beq  x0, x0, _continue

_pk_len_k2:
  addi x8, x0, 800 /* Byte length of ek_pke for k = 2. */

_continue:
  /*** Step 2: Append ek (i.e, ek_pke) to dk_pke and compute h = SHA3-256(ek). ***/
  /* Initialize SHA3-256 operation. */
  la      x5, dptr_pk
  lw      x10, 0(x5)
  slli    x5, x8, 5
  addi    x5, x5, SHA3_256_CFG
  csrrw   x0, kmac_cfg, x5

  la      x6, dptr_sk
  lw      x6, 0(x6)
  srli    x8, x8, 5
  loop x8, 3
    bn.lid  x0, 0(x10++)
    bn.sid  x0, 0(x6++)  /* Copy ek to dk_pke. */
    bn.wsrw kmac_msg, w0 /* Send ek. */
  endloop
  /* Retrieve h = SHA3-256(ek). */
  bn.wsrr w0, kmac_digest
  bn.sid  x0, 0(x6++)

  /*** Step 3: Append z to (dk_pke || ek || h). ***/
  la     x5, dptr_coins
  lw     x5, 0(x5)
#ifdef HARDENED
  bn.lid x0, 64(x5)
  bn.sid x0, 0(x6)
  bn.xor w0, w0, w0 /* Whitening. */
  bn.lid x0, 96(x5)
  bn.sid x0, 32(x6)
  bn.xor w0, w0, w0 /* Whitening. */
#else
  bn.lid x0, 32(x5)
  bn.sid x0, 0(x6)
#endif
  ret
