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

/* Config to start a SHA3_256 operation. */
#define SHA3_256_CFG 0x8
/* Config to start a SHA3_512 operation. */
#define SHA3_512_CFG 0x10

/**
 * Encapsulation for the CCA-secure ML-KEM key encapsulation mechanism.
 *
 * Uses the encapsulation key to generate a shared secret key and an
 * associated ciphertext.
 *
 * The packed ek is 384 * k + 32 bytes, that is 800, 1184 and 1568 bytes for
 * k = 2, 3 and 4.
 *  Step 1: h = SHA3-256(ek)
 *  Step 2: (ss, r) = SHA3-512(m || h)
 *  Step 3: c = indcpa_enc(m, ek_pke, r) // ek_pke <- ek
 *
 * @param[in]  x10: dmem pointer to the input message m (32 bytes)
 * @param[in]  x11: dmem pointer to the input packed public key ek
 * @param[out] x12: dmem pointer to the output ciphertext c
 * @param[out] x13: dmem pointer to the output shared secret ss
 * @param[in]  x14: k, the security level
 * @param[in]  w16 (sw0): sw0.0 = q = 3329 (1st 16-bit lane),
 *                        sw0.2 = -q^-1 mod 2^16 = 3327 (3rd 16-bit lane)
 * @param[in]  w31: all-zero register
 *
 * clobbered registers: x4 to x14, x18 to x19, x21 to x24, x26 to x28,
 *                      w0 to w15, w17 to w26, mod, acch, acc
 * clobbered flag groups: FG0
 */

.globl crypto_kem_enc
.type crypto_kem_enc, @function
crypto_kem_enc:
  addi x4, x0, 2
  beq  x14, x4, _pk_len_k2
  addi x4, x0, 3
  beq  x14, x4, _pk_len_k3
  addi x5, x0, 1568 /* Byte length of ek_pke for k = 4. */
  beq  x0, x0, _continue

_pk_len_k3:
  addi x5, x0, 1184 /* Byte length of ek_pke for k = 3. */
  beq  x0, x0, _continue

_pk_len_k2:
  addi x5, x0, 800  /* Byte length of ek_pke for k = 2. */

_continue:
  add x8, x10, x0
  add x9, x11, x0

  /*** Step 1: Compute h = SHA3-256(ek). ***/
  /* Initialize SHA3-256 operation. */
  slli    x6, x5, 5
  addi    x6, x6, SHA3_256_CFG
  csrrw   x0, kmac_cfg, x6
  srli    x5, x5, 5
  /* Send ek_pke. */
  loop x5, 2
    bn.lid  x0, 0(x11++)
    bn.wsrw kmac_msg, w0
  endloop
  /* Retrieve h. */
  bn.wsrr w1, kmac_digest

  /*** Step 2: Compute (ss, r) = SHA3-512(m || h). ***/
  /* Initialize SHA3-512 operation. */
  addi  x5, x0, 64
  slli  x5, x5, 5
  addi  x5, x5, SHA3_512_CFG
  csrrw x0, kmac_cfg, x5
  /* Send m. */
  bn.lid  x0, 0(x8)
  bn.wsrw kmac_msg, w0
  /* Send h. */
  bn.wsrw kmac_msg, w1
  /* Retrieve ss. */
  bn.wsrr w0, kmac_digest
  bn.sid  x0, 0(x13)
  /* Retrieve r. */
  la      x5, indcpa_enc_seed
  bn.wsrr w0, kmac_digest
  bn.sid  x0, 0(x5)

  /*** Step 3: c = indcpa_enc(m, ek_pke, r). ***/
  add  x10, x8, x0
  add  x11, x9, x0
  add  x13, x12, x0
  la   x12, indcpa_enc_seed
  /* x14 is still k. */
  jal  x1, indcpa_enc

  ret
