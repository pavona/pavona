// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/crypto/impl/ecc/ed25519.h"

#include "sw/device/lib/crypto/impl/ecc/ed25519_insn_counts.h"

// Module ID for status codes.
#define MODULE_ID MAKE_MODULE_ID('e', '2', 'r')

// Declare the ACC app.
ACC_DECLARE_APP_SYMBOLS(run_ed25519);  // The ACC Ed25519 app.
static const acc_app_t kAccAppEd25519 = ACC_APP_T_INIT(run_ed25519);

// Declare offsets for input and output buffers.
ACC_DECLARE_SYMBOL_ADDR(run_ed25519, ed25519_mode);     // Mode of operation..
ACC_DECLARE_SYMBOL_ADDR(run_ed25519, ed25519_message);  // Message.
ACC_DECLARE_SYMBOL_ADDR(run_ed25519, ed25519_sig_R);    // R signature point.
ACC_DECLARE_SYMBOL_ADDR(run_ed25519, ed25519_sig_S);    // S signature scalar.
ACC_DECLARE_SYMBOL_ADDR(run_ed25519, ed25519_hash_h);   // Secret key hash h.
ACC_DECLARE_SYMBOL_ADDR(run_ed25519, ed25519_hash_k);   // Pre-computed hash k.
ACC_DECLARE_SYMBOL_ADDR(run_ed25519, ed25519_ctx);      // Context string.
ACC_DECLARE_SYMBOL_ADDR(run_ed25519, ed25519_ctx_len);  // Context length.
ACC_DECLARE_SYMBOL_ADDR(run_ed25519, ed25519_public_key);     // Public key.
ACC_DECLARE_SYMBOL_ADDR(run_ed25519, ed25519_verify_result);  // Verify result.

static const acc_addr_t kAccVarEd25519Mode =
    ACC_ADDR_T_INIT(run_ed25519, ed25519_mode);
static const acc_addr_t kAccVarEd25519Message =
    ACC_ADDR_T_INIT(run_ed25519, ed25519_message);
static const acc_addr_t kAccVarEd25519SigR =
    ACC_ADDR_T_INIT(run_ed25519, ed25519_sig_R);
static const acc_addr_t kAccVarEd25519SigS =
    ACC_ADDR_T_INIT(run_ed25519, ed25519_sig_S);
static const acc_addr_t kAccVarEd25519HashH =
    ACC_ADDR_T_INIT(run_ed25519, ed25519_hash_h);
static const acc_addr_t kAccVarEd25519HashK =
    ACC_ADDR_T_INIT(run_ed25519, ed25519_hash_k);
static const acc_addr_t kAccVarEd25519Ctx =
    ACC_ADDR_T_INIT(run_ed25519, ed25519_ctx);
static const acc_addr_t kAccVarEd25519CtxLen =
    ACC_ADDR_T_INIT(run_ed25519, ed25519_ctx_len);
static const acc_addr_t kAccVarEd25519PublicKey =
    ACC_ADDR_T_INIT(run_ed25519, ed25519_public_key);
static const acc_addr_t kAccVarEd25519VerifyResult =
    ACC_ADDR_T_INIT(run_ed25519, ed25519_verify_result);

// Declare mode constants.
ACC_DECLARE_SYMBOL_ADDR(run_ed25519, ED25519_MODE_SIGN);  // Ed25519 signing.
ACC_DECLARE_SYMBOL_ADDR(run_ed25519,
                         ED25519_MODE_VERIFY);  // Ed25519 verification.

static const uint32_t kAccEd25519ModeSign =
    ACC_ADDR_T_INIT(run_ed25519, ED25519_MODE_SIGN);
static const uint32_t kAccEd25519ModeVerify =
    ACC_ADDR_T_INIT(run_ed25519, ED25519_MODE_VERIFY);

enum {
  /*
   * Mode is represented by a single word.
   */
  kAccEd25519ModeWords = 1,
};

/**
 * Set the context for signature generation or verification.
 *
 * @param context Context to set (little-endian).
 * @return OK or error.
 */
OT_WARN_UNUSED_RESULT
static status_t set_context(const uint32_t context[kEd25519ContextWords],
                            const uint32_t context_length) {
  // Ensure that our context length is valid; if not, fail early.
  if (context_length > kEd25519ContextWords) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_LE(context_length, kEd25519ContextWords);

  // Write the full context string.
  HARDENED_TRY(acc_dmem_write(context_length, context, kAccVarEd25519Ctx));

  // Set the context length.
  return acc_dmem_write(1, &context_length, kAccVarEd25519CtxLen);
}

status_t ed25519_sign_start(
    const uint32_t prehashed_message[kEd25519PreHashWords],
    const uint32_t hash_h[kEd25519HashWords],
    const uint32_t context[kEd25519ContextWords],
    const uint32_t context_length) {
  // Load the Ed25519 app. Fails if ACC is non-idle.
  HARDENED_TRY(acc_load_app(kAccAppEd25519));

  // Set mode so start() will jump into signing.
  uint32_t mode = kAccEd25519ModeSign;
  HARDENED_TRY(
      acc_dmem_write(kAccEd25519ModeWords, &mode, kAccVarEd25519Mode));

  // Set the precomputed private key hash h.
  HARDENED_TRY(
      acc_dmem_write(kEd25519PreHashWords, hash_h, kAccVarEd25519HashH));

  // Set the context string.
  HARDENED_TRY(set_context(context, context_length));

  // Set the pre-hashed message.
  HARDENED_TRY(acc_dmem_write(kEd25519HashWords, prehashed_message,
                               kAccVarEd25519Message));

  // Start the ACC routine.
  return acc_execute();
}

status_t ed25519_sign_finalize(ed25519_signature_t *result) {
  // Return `OTCRYTPO_ASYNC_INCOMPLETE` if ACC not done.
  HARDENED_TRY(acc_assert_idle());

  // Check instruction count.
  ACC_CHECK_INSN_COUNT(kEd25519SignMinInstructionCount,
                        kEd25519SignMaxInstructionCount);

  // Read signature R out of ACC dmem.
  HARDENED_TRY(acc_dmem_read(8, kAccVarEd25519SigR, result->r));

  // Read signature S out of ACC dmem.
  HARDENED_TRY(acc_dmem_read(8, kAccVarEd25519SigS, result->s));

  // Wipe DMEM.
  return acc_dmem_sec_wipe();
}

status_t ed25519_verify_start(
    const ed25519_signature_t *signature,
    const uint32_t prehashed_message[kEd25519PreHashWords],
    const uint32_t hash_k[kEd25519HashWords], const ed25519_point_t *public_key,
    const uint32_t context[kEd25519ContextWords],
    const uint32_t context_length) {
  // Load the P-256 app and set up data pointers
  HARDENED_TRY(acc_load_app(kAccAppEd25519));

  // Set mode so start() will jump into verifying.
  uint32_t mode = kAccEd25519ModeVerify;
  HARDENED_TRY(
      acc_dmem_write(kAccEd25519ModeWords, &mode, kAccVarEd25519Mode));

  // Set the pre-hashed message to the provided digest.
  HARDENED_TRY(acc_dmem_write(kEd25519HashWords, prehashed_message,
                               kAccVarEd25519Message));

  // Set the precomputed hash value k.
  HARDENED_TRY(
      acc_dmem_write(kEd25519HashWords, hash_k, kAccVarEd25519HashK));

  // Set the context string.
  HARDENED_TRY(set_context(context, context_length));

  // Set the signature R.
  HARDENED_TRY(
      acc_dmem_write(kEd25519PointWords, signature->r, kAccVarEd25519SigR));

  // Set the signature S.
  HARDENED_TRY(
      acc_dmem_write(kEd25519ScalarWords, signature->s, kAccVarEd25519SigS));

  // Set the public key.
  HARDENED_TRY(acc_dmem_write(kEd25519PointWords, public_key->data,
                               kAccVarEd25519PublicKey));

  // Start the ACC routine.
  return acc_execute();
}

status_t ed25519_verify_finalize(const ed25519_signature_t *signature,
                                 hardened_bool_t *result) {
  // Return `OTCRYTPO_ASYNC_INCOMPLETE` if ACC not done.
  HARDENED_TRY(acc_assert_idle());

  // Check instruction count.
  ACC_CHECK_INSN_COUNT(kEd25519VerifyMinInstructionCount,
                        kEd25519VerifyMaxInstructionCount);

  // Read verification result out of ACC dmem.
  uint32_t verify_result;
  HARDENED_TRY(acc_dmem_read(1, kAccVarEd25519VerifyResult, &verify_result));

  // Wipe DMEM.
  HARDENED_TRY(acc_dmem_sec_wipe());

  // Return a result based on the read value.
  *result = kHardenedBoolFalse;
  if (launder32(verify_result) == kEd25519VerifySuccess) {
    HARDENED_CHECK_EQ(verify_result, kEd25519VerifySuccess);
    *result = kHardenedBoolTrue;
  } else if (launder32(verify_result) == kEd25519VerifyFailure) {
    HARDENED_CHECK_EQ(verify_result, kEd25519VerifyFailure);
  } else {
    // If we're here, we've read an invalid result.
    return OTCRYPTO_FATAL_ERR;
  }

  return OTCRYPTO_OK;
}
