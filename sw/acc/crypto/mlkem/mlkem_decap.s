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
#define NSHARESm1 1
#define RP_BYTES 64
#else
#define NSHARES 1
#define NSHARESm1 0
#define RP_BYTES 32
#endif

/* Config to start a SHAKE-256 operation. */
#define SHAKE256_CFG 0xA
/* Config to start a SHA3_512 operation. */
#define SHA3_512_CFG 0x10

/**
 * Decapsulation for the CCA-secure ML-KEM key encapsulation mechanism.
 *
 * Uses the decapsulation key to produce a shared secret key from a ciphertext.
 *
 * Let d = NSHARES.
 *  Step 1: extract keys.
 *      dk_pke = dk[0 : 384 * k * d]                                    // NSHARES shares
 *      ek_pke = dk[384 * k * d : 384 * k * d + 768 * k + 32]           // rho of ek_pke is not masked
 *      h = dk[384 * k * d + 768 * k + 32 : 384 * k * d + 768 * k + 64] // H(ek) is not masked
 *      z = dk[384 * k * d + 768 * k + 64 :
 *             384 * k * d + 768 * k + 64 + 32 * d]                     // NSHARES shares
 *  Step 2: m' = indcpa_dec(c, dk_pke)
 *  Step 3: (K_true, r') <- SHA3-512(m' || h)
 *  Step 4: K_false <- SHAKE256(z || c)
 *  Step 5: w0 <- indcpa_enc_cmp(m', ek_pke, r', c)                     // w0 is the comparison result
 *  Step 6: if cp != c: ss <- K_false; else, ss <- K_true.
 *
 * @param[in]  x10: dmem pointer to the input ciphertext c
 * @param[in]  x11: dmem pointer to the input masked secret key dk
 * @param[out] x12: dmem pointer to the output shared secret ss
 * @param[in]  x13: k, the security level
 * @param[in]  w16 (sw0): sw0.0 = q = 3329 (1st 16-bit lane),
 *                        sw0.2 = -q^-1 mod 2^16 = 3327 (3rd 16-bit lane)
 * @param[in]  w31: all-zero register
 *
 * UNPROTECTED
 * clobbered registers: x2 to x15, x18 to x19, x21 to x28,
 *                      w0 to w15, w17 to w26, mod, acch, acc
 * clobbered flag groups: FG0
 *
 * HARDENED
 * clobbered registers: x2 to x31, w0 to w30, acc, acch, mod
 * clobbered flag groups: FG0
 */

.globl crypto_kem_dec
.type crypto_kem_dec, @function
crypto_kem_dec:
  addi x4, x0, 2
  beq  x13, x4, _save_k2_ptrs
  addi x4, x0, 3
  beq  x13, x4, _save_k3_ptrs
  addi x7, x0, 1568 /* Byte length of the public ciphertext. */
  addi x8, x0, 1536 /* Byte length of one packed polynomial of dk_pke. */
  addi x9, x0, 1568 /* Byte length of the packed public key ek_pke. */
  beq  x0, x0, _continue

_save_k2_ptrs:
  addi x7, x0, 768  /* Byte length of the public ciphertext. */
  addi x8, x0, 768  /* Byte length of one packed polynomial of dk_pke. */
  addi x9, x0, 800  /* Byte length of the packed public key ek_pke. */
  beq  x0, x0, _continue

_save_k3_ptrs:
  addi x7, x0, 1088 /* Byte length of the public ciphertext. */
  addi x8, x0, 1152 /* Byte length of one packed polynomial of dk_pke. */
  addi x9, x0, 1184 /* Byte length of the packed public key ek_pke. */

_continue:
  /*** Step 1: save addresses of secret key's components. ***/
  /* Input public ciphertext. */
  la   x5, dptr_ct
  sw   x10, 0(x5)
  /* Byte length of the public ciphertext. */
  la   x5, ctbytes
  add  x6, x0, x7
  sw   x6, 0(x5)
  /* The public key pk_pke for indcpa_enc_cmp. */
  add  x6, x11, x0
  add  x5, x0, x8
  slli x5, x5, NSHARESm1
  add  x6, x11, x5
  la   x5, dptr_pk
  sw   x6, 0(x5)
  /* H(ek). */
  add  x6, x6, x9
  la   x5, dptr_h
  sw   x6, 0(x5)
  /* The output shared key. */
  la   x5, dptr_ss
  sw   x12, 0(x5)
  /* The security level k. */
  la   x5, k
  sw   x13, 0(x5)

#ifdef HARDENED
  /* Refresh z's Boolean shares; clobbers x10/x11, so stash/reload sk/ct. */
  add  x8, x11, x0
  la   x10, dptr_h
  lw   x10, 0(x10)
  addi x10, x10, 32
  addi x11, x0, 1
  addi x12, x0, 32
  add  x14, x10, x0
  jal  x1, refreshios
  la   x5, dptr_ct
  lw   x10, 0(x5)
  add  x11, x8, x0
#endif

  /*** Step 2: m' = indcpa_dec(c, dk_pke). ***/
  /* x10 already points to c. */
  /* x11 already points to dk_pke. */
  la  x12, m
  /* x13 is already the security level k. */
  jal x1, indcpa_dec

  /*** Step 3: (K_true, r') <- SHA3-512(m' || h). ***/
#ifdef HARDENED
  /* Since the output message of indcpa_dec is in a special order due
   * to performance reason for masked_poly_tomsg gagdet, we reorder the
   * message m here before hashing it. Note that the re-ordered message is
   * put elsewhere, not in buffer for m again. Otherwise, the re-encryption
   * will fail since the masked one-bit decompression gadget takes into
   * account the special order of the message m. */
  la   x5, m
  la   x6, mtmp
  addi x4, x0, 1
  loopi 2, 11
    bn.lid x0, 0(x5++)
    loopi 16, 5
      bn.shv.16h w2, w0 >> 15
      loopi 16, 2
        bn.rshi w1, w2, w1 >> 1
        bn.rshi w2, w31, w2 >> 16
      endloop
      bn.shv.16h w0, w0 << 1
    endloop
    bn.sid x4, 0(x6++)
    /* Whitening. */
    bn.xor w0, w31, w31
    bn.xor w1, w31, w31
    bn.xor w2, w31, w31
  endloop

  /* Initialize SHA3-512 operation. */
  addi    x5, x0, 64
  slli    x5, x5, 5
  addi    x5, x5, SHA3_512_CFG
  addi    x6, x0, 1
  slli    x6, x6, 20
  add     x5, x5, x6
  csrrw   x0, kmac_cfg, x5
  /* Send m. */
  la      x5, mtmp
  bn.lid  x0, 0(x5++)
  bn.wsrw kmac_msg, w0  /* m[0] */
  bn.xor  w0, w31, w31  /* Whitening. */
  bn.lid  x0, 0(x5)
  bn.wsrw kmac_msg1, w0 /* m[1] */
  bn.xor  w0, w31, w31  /* Whitening. */
  /* Send h. */
  la      x5, dptr_h
  lw      x5, 0(x5)
  bn.lid  x0, 0(x5)
  bn.wsrw kmac_msg, w0  /* h */
  bn.xor  w0, w31, w31
  bn.wsrw kmac_msg1, w0 /* 0 */
  /* Retrieve K_true. */
  la      x5, kr
  bn.wsrr w0, kmac_digest
  bn.sid  x0, 0(x5++)
  bn.xor  w0, w31, w31  /* Whitening. */
  bn.wsrr w0, kmac_digest1
  bn.sid  x0, 0(x5++)
  bn.xor  w0, w31, w31  /* Whitening. */
  /* Retrieve r'. */
  bn.wsrr w0, kmac_digest
  bn.sid  x0, 0(x5++)
  bn.xor  w0, w31, w31  /* Whitening. */
  bn.wsrr w0, kmac_digest1
  bn.sid  x0, 0(x5++)
  bn.xor  w0, w31, w31  /* Whitening. */

#else
  /* Initialize SHA3-512 operation. */
  addi    x5, x0, 64
  slli    x5, x5, 5
  addi    x5, x5, SHA3_512_CFG
  csrrw   x0, kmac_cfg, x5
  /* Send m. */
  la      x5, m
  bn.lid  x0, 0(x5)
  bn.wsrw kmac_msg, w0
  /* Send h. */
  la      x5, dptr_h
  lw      x5, 0(x5)
  bn.lid  x0, 0(x5)
  bn.wsrw kmac_msg, w0
  /* Retrieve K_true. */
  la      x5, kr
  bn.wsrr w0, kmac_digest
  bn.sid  x0, 0(x5++)
  /* Retrieve r'. */
  bn.wsrr w0, kmac_digest
  bn.sid  x0, 0(x5++)
#endif

  /*** Step 4: K_false <- SHAKE256(z || c). ***/
  /* Initialize SHA3-512 operation. */
  addi    x11, x0, 32
  la      x5, ctbytes
  lw      x5, 0(x5)
  add     x11, x11, x5
  slli    x5, x11, 5
  addi    x5, x5, SHAKE256_CFG
#ifdef HARDENED
  addi    x6, x0, 1
  slli    x6, x6, 20
  add     x5, x5, x6
#endif
  csrrw   x0, kmac_cfg, x5
  /* Send z. */
  la      x5, dptr_h
  lw      x5, 0(x5)
  bn.lid  x0, 32(x5)
  bn.wsrw kmac_msg, w0
#ifdef HARDENED
  bn.xor  w0, w31, w31 /* Whitening. */
  bn.lid  x0, 64(x5)
  bn.wsrw kmac_msg1, w0
  bn.xor  w0, w31, w31 /* Whitening. */
#endif

  /* Send c. */
  la   x5, dptr_ct
  lw   x10, 0(x5)
  la   x5, ctbytes
  lw   x5, 0(x5)
  srli x5, x5, 5
#ifdef HARDENED
  loop x5, 3
    bn.lid  x0, 0(x10++)
    bn.wsrw kmac_msg, w0
    bn.wsrw kmac_msg1, w31
  endloop
  /* Retrieve K_false. */
  la      x5, ss_false
  bn.wsrr w0, kmac_digest
  bn.sid  x0, 0(x5++)
  bn.xor  w0, w31, w31 /* Whitening. */
  bn.wsrr w0, kmac_digest1
  bn.sid  x0, 0(x5)
  bn.xor  w0, w31, w31 /* Whitening. */
#else
  loop x5, 2
    bn.lid  x0, 0(x10++)
    bn.wsrw kmac_msg, w0
  endloop
  /* Retrieve K_false. */
  la      x5, ss_false
  bn.wsrr w0, kmac_digest
  bn.sid  x0, 0(x5)
#endif

  /*** Step 5: w0 <- indcpa_enc_cmp(m', ek_pke, r', c). ***/
  /* Compute re-encryption and compare the re-encrypted ciphertext with the
   * public ciphertext. w0 contains the comparison result. */
  la   x10, m
  la   x5, dptr_pk
  lw   x11, 0(x5)
  la   x12, kr
  addi x12, x12, RP_BYTES
  la   x5, dptr_ct
  lw   x13, 0(x5)
  addi x14, x0, NSHARES
  la   x5, k
  lw   x15, 0(x5)
  jal  x1, indcpa_enc_cmp

  /*** Step 6: if cp != c: K_true <- K_false. Return K_true. ***/
#ifndef HARDENED
  la      x5, kr
  addi    x4, x0, 1
  bn.lid  x4++, 0(x5) /* Load true key. */
  la      x5, ss_false
  bn.lid  x4, 0(x5)   /* Load false key. */
  bn.xor  w3, w1, w2
  /* w0 is the comparison result: 0 if equal, all ones otherwise. */
  bn.and  w3, w3, w0
  bn.xor  w0, w1, w3
  la      x5, dptr_ss
  lw      x5, 0(x5)
  bn.sid  x0, 0(x5)
  ret
#else
  la      x5, kr
  la      x6, dptr_ss
  lw      x6, 0(x6)
  la      x7, ss_false
  addi    x4, x0, 1
  bn.xor  w1, w1, w1
  bn.addi w1, w1, 1
  bn.cmp  w0, w1
  csrrw   x28, fg0, x0
  srli    x28, x28, 3 /* Extract z flag. */
  beq     x28, x0, _fail
  bn.lid  x0, 0(x5)
  bn.lid  x4, 32(x5)
  beq     x0, x0, _end
_fail:
  bn.lid  x0, 0(x7)
  bn.lid  x4, 32(x7)
  beq     x0, x0, _end
_end:
  bn.sid  x0, 0(x6)
  bn.sid  x4, 32(x6)
  ret
#endif
