/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * Entrypoint for Ed25519 operations.
 *
 * This binary has the following modes of operation:
 * 1. ED25519_MODE_SIGN: generate an Ed25519 signature using caller-provided secret key
 * 2. ED25519_MODE_VERIFY: verify an Ed25519 signature
 */

/**
 * Mode magic values.
 *
 * Encoding generated with:
 * $ ./util/design/sparse-fsm-encode.py -d 6 -m 2 -n 11 \
 *     -s 923549298 --avoid-zero
 *
 * Call the same utility with the same arguments and a higher -m to generate
 * additional value(s) without changing the others or sacrificing mutual HD.
 *
 * TODO(#17727): in some places the OTBN assembler support for .equ directives
 * is lacking, so they cannot be used in bignum instructions or pseudo-ops such
 * as `li`. If support is added, we could use 32-bit values here instead of
 * 11-bit.
 */
.equ ED25519_MODE_SIGN, 0x5be
.equ ED25519_MODE_VERIFY, 0x672

/**
 * Make the mode constants visible to Ibex.
 */
.globl ED25519_MODE_SIGN
.globl ED25519_MODE_VERIFY

.section .text.start
.globl start
start:
  /* Init all-zero register. */
  bn.xor  w31, w31, w31

  /* Read the mode and tail-call the requested operation. */
  la      x2, ed25519_mode
  lw      x2, 0(x2)

  addi    x3, x0, ED25519_MODE_SIGN
  beq     x2, x3, ed25519_sign_top

  addi  x3, x0, ED25519_MODE_VERIFY
  beq   x2, x3, ed25519_verify_top

  /* Invalid mode; fail. */
  unimp
  unimp
  unimp

/**
 * Generate an Ed25519 signature.
 *
 * See documentation for ed25519_sign_prehashed in ed25519.s for details.
 *
 * @param[in]  dmem[ed25519_hash_h]: hash of secret key (512 bits)
 * @param[in]  dmem[ed25519_ctx]: context string (ctx_len bytes)
 * @param[in]  dmem[ed25519_ctx_len]: length of context string in bytes
 * @param[in]  dmem[ed25519_message]: pre-hashed message (512 bits)
 * @param[out] dmem[ed25519_sig_R]: R component of signature (256 bits)
 * @param[out] dmem[ed25519_sig_S]: S component of signature (256 bits)
 */
ed25519_sign_top:
  jal x1, ed25519_sign_prehashed
  ecall

/**
 * Verify an Ed25519 signature.
 *
 * See documentation for ed25519_verify_var in ed25519.s for details, including
 * concrete values for SUCCESS and FAILURE.
 *
 * @param[in]  w31: all-zero
 * @param[in]  dmem[ed25519_hash_k]: precomputed hash k, 512 bits
 * @param[in]  dmem[ed25519_sig_R]: encoded signature point R_, 256 bits
 * @param[in]  dmem[ed25519_sig_S]: signature scalar S, 256 bits
 * @param[in]  dmem[ed25519_public_key]: encoded public key A_, 256 bits
 * @param[out] dmem[ed25519_verify_result]: SUCCESS or FAILURE
 */
ed25519_verify_top:
  jal x1, ed25519_verify_var
  ecall

.bss

/* Operation mode. */
.globl ed25519_mode
.balign 4
ed25519_mode:
  .zero 4

/* Context string length in bytes for pre-hashed EdDSA */
.globl ed25519_ctx_len
.balign 4
ed25519_ctx_len:
  .zero 4

/* Verification result code (32 bits). Output for verify.
   If verification is successful, this will be SUCCESS = 0xf77fe650.
   Otherwise, this will be FAILURE = 0xeda2bfaf. */
.globl ed25519_verify_result
.balign 4
ed25519_verify_result:
  .zero 4

/* Signature point R (256 bits). Input for verify and output for sign. */
.globl ed25519_sig_R
.balign 32
ed25519_sig_R:
  .zero 32

/* Signature scalar S (253 bits). Input for verify and output for sign. */
.globl ed25519_sig_S
.balign 32
ed25519_sig_S:
  .zero 32

/* Encoded public key A_ (256 bits). Input for verify. */
.globl ed25519_public_key
.balign 32
ed25519_public_key:
  .zero 32

/* Hash of the secret key (512 bits). Intermediate value for sign. */
.globl ed25519_hash_h
.balign 32
ed25519_hash_h:
  .zero 64

/* Hash value k (512 bits). Input for verify, intermediate for sign. */
.globl ed25519_hash_k
.balign 32
ed25519_hash_k:
  .zero 64

/* Context string for pre-hashed EdDSA (up to 255 bytes).

   Note: If the context length is not a multiple of 32 bytes, the bytes up to
   the next multiple of 32 should be initialized in order to prevent read
   errors. The value of these bytes is ignored. */
.globl ed25519_ctx
.balign 32
ed25519_ctx:
  .zero 256

/* Message (pre-hashed, 64 bytes). */
.globl ed25519_message
.balign 32
ed25519_message:
  .zero 64
