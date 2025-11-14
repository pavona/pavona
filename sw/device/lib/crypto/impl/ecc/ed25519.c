// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/crypto/impl/ecc/ed25519.h"

#include "sw/device/lib/crypto/impl/ecc/ed25519_insn_counts.h"

// Module ID for status codes.
#define MODULE_ID MAKE_MODULE_ID('e', '2', 'r')

// Declare the OTBN app.
OTBN_DECLARE_APP_SYMBOLS(run_ed25519);  // The OTBN Ed25519 app.
static const otbn_app_t kOtbnAppEd25519 = OTBN_APP_T_INIT(run_ed25519);

// Declare offsets for input and output buffers.
OTBN_DECLARE_SYMBOL_ADDR(run_ed25519, ed25519_mode);     // Mode of operation..
OTBN_DECLARE_SYMBOL_ADDR(run_ed25519, ed25519_message);  // Message.
OTBN_DECLARE_SYMBOL_ADDR(run_ed25519, ed25519_sig_R);    // R signature point.
OTBN_DECLARE_SYMBOL_ADDR(run_ed25519, ed25519_sig_S);    // S signature scalar.
OTBN_DECLARE_SYMBOL_ADDR(run_ed25519, ed25519_hash_h);   // Secret key hash h.
OTBN_DECLARE_SYMBOL_ADDR(run_ed25519, ed25519_hash_k);   // Pre-computed hash k.
OTBN_DECLARE_SYMBOL_ADDR(run_ed25519, ed25519_ctx);      // Context string.
OTBN_DECLARE_SYMBOL_ADDR(run_ed25519, ed25519_ctx_len);  // Context length.
OTBN_DECLARE_SYMBOL_ADDR(run_ed25519, ed25519_public_key);     // Public key.
OTBN_DECLARE_SYMBOL_ADDR(run_ed25519, ed25519_verify_result);  // Verify result.

static const otbn_addr_t kOtbnVarEd25519Mode =
    OTBN_ADDR_T_INIT(run_ed25519, ed25519_mode);
static const otbn_addr_t kOtbnVarEd25519Message =
    OTBN_ADDR_T_INIT(run_ed25519, ed25519_message);
static const otbn_addr_t kOtbnVarEd25519SigR =
    OTBN_ADDR_T_INIT(run_ed25519, ed25519_sig_R);
static const otbn_addr_t kOtbnVarEd25519SigS =
    OTBN_ADDR_T_INIT(run_ed25519, ed25519_sig_S);
static const otbn_addr_t kOtbnVarEd25519HashH =
    OTBN_ADDR_T_INIT(run_ed25519, ed25519_hash_h);
static const otbn_addr_t kOtbnVarEd25519HashK =
    OTBN_ADDR_T_INIT(run_ed25519, ed25519_hash_k);
static const otbn_addr_t kOtbnVarEd25519Ctx =
    OTBN_ADDR_T_INIT(run_ed25519, ed25519_ctx);
static const otbn_addr_t kOtbnVarEd25519CtxLen =
    OTBN_ADDR_T_INIT(run_ed25519, ed25519_ctx_len);
static const otbn_addr_t kOtbnVarEd25519PublicKey =
    OTBN_ADDR_T_INIT(run_ed25519, ed25519_public_key);
static const otbn_addr_t kOtbnVarEd25519VerifyResult =
    OTBN_ADDR_T_INIT(run_ed25519, ed25519_verify_result);

// Declare mode constants.
OTBN_DECLARE_SYMBOL_ADDR(run_ed25519, ED25519_MODE_SIGN);  // Ed25519 signing.
OTBN_DECLARE_SYMBOL_ADDR(run_ed25519,
                         ED25519_MODE_VERIFY);  // Ed25519 verification.

static const uint32_t kOtbnEd25519ModeSign =
    OTBN_ADDR_T_INIT(run_ed25519, ED25519_MODE_SIGN);
static const uint32_t kOtbnEd25519ModeVerify =
    OTBN_ADDR_T_INIT(run_ed25519, ED25519_MODE_VERIFY);

enum {
  /*
   * Mode is represented by a single word.
   */
  kOtbnEd25519ModeWords = 1,
};

/**
 * Set the context for signature generation or verification.
 *
 * @param context Context to set (little-endian).
 * @return OK or error.
 */
static status_t set_context(const uint32_t context[kEd25519ContextWords],
                            const uint32_t context_length) {
  // Ensure that our context length is valid; if not, fail early.
  if (context_length > kEd25519ContextWords) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_LE(context_length, kEd25519ContextWords);

  // Write the full context string.
  HARDENED_TRY(otbn_dmem_write(context_length, context, kOtbnVarEd25519Ctx));

  // Set the context length.
  return otbn_dmem_write(1, &context_length, kOtbnVarEd25519CtxLen);
}

status_t ed25519_sign_start(
    const uint32_t prehashed_message[kEd25519PreHashWords],
    const uint32_t hash_h[kEd25519HashWords],
    const uint32_t context[kEd25519ContextWords],
    const uint32_t context_length) {
  // Load the Ed25519 app. Fails if OTBN is non-idle.
  HARDENED_TRY(otbn_load_app(kOtbnAppEd25519));

  // Set mode so start() will jump into signing.
  uint32_t mode = kOtbnEd25519ModeSign;
  HARDENED_TRY(
      otbn_dmem_write(kOtbnEd25519ModeWords, &mode, kOtbnVarEd25519Mode));

  // Set the precomputed private key hash h.
  HARDENED_TRY(
      otbn_dmem_write(kEd25519PreHashWords, hash_h, kOtbnVarEd25519HashH));

  // Set the context string.
  HARDENED_TRY(set_context(context, context_length));

  // Set the pre-hashed message.
  HARDENED_TRY(otbn_dmem_write(kEd25519HashWords, prehashed_message,
                               kOtbnVarEd25519Message));

  // Start the OTBN routine.
  return otbn_execute();
}

status_t ed25519_sign_finalize(ed25519_signature_t *result) {
  // Spin here waiting for OTBN to complete.
  HARDENED_TRY(otbn_busy_wait_for_done());

  // Check instruction count.
  OTBN_CHECK_INSN_COUNT(kEd25519SignMinInstructionCount,
                        kEd25519SignMaxInstructionCount);

  // Read signature R out of OTBN dmem.
  HARDENED_TRY(otbn_dmem_read(8, kOtbnVarEd25519SigR, result->r));

  // Read signature S out of OTBN dmem.
  HARDENED_TRY(otbn_dmem_read(8, kOtbnVarEd25519SigS, result->s));

  // Wipe DMEM.
  return otbn_dmem_sec_wipe();
}

status_t ed25519_verify_start(
    const ed25519_signature_t *signature,
    const uint32_t prehashed_message[kEd25519PreHashWords],
    const uint32_t hash_k[kEd25519HashWords], const ed25519_point_t *public_key,
    const uint32_t context[kEd25519ContextWords],
    const uint32_t context_length) {
  // Load the P-256 app and set up data pointers
  HARDENED_TRY(otbn_load_app(kOtbnAppEd25519));

  // Set mode so start() will jump into verifying.
  uint32_t mode = kOtbnEd25519ModeVerify;
  HARDENED_TRY(
      otbn_dmem_write(kOtbnEd25519ModeWords, &mode, kOtbnVarEd25519Mode));

  // Set the pre-hashed message to the provided digest.
  HARDENED_TRY(otbn_dmem_write(kEd25519HashWords, prehashed_message,
                               kOtbnVarEd25519Message));

  // Set the precomputed hash value k.
  HARDENED_TRY(
      otbn_dmem_write(kEd25519HashWords, hash_k, kOtbnVarEd25519HashK));

  // Set the context string.
  HARDENED_TRY(set_context(context, context_length));

  // Set the signature R.
  HARDENED_TRY(
      otbn_dmem_write(kEd25519PointWords, signature->r, kOtbnVarEd25519SigR));

  // Set the signature S.
  HARDENED_TRY(
      otbn_dmem_write(kEd25519ScalarWords, signature->s, kOtbnVarEd25519SigS));

  // Set the public key.
  HARDENED_TRY(otbn_dmem_write(kEd25519PointWords, public_key->data,
                               kOtbnVarEd25519PublicKey));

  // Start the OTBN routine.
  return otbn_execute();
}

status_t ed25519_verify_finalize(const ed25519_signature_t *signature,
                                 hardened_bool_t *result) {
  // Spin here waiting for OTBN to complete.
  HARDENED_TRY(otbn_busy_wait_for_done());

  // Check instruction count.
  OTBN_CHECK_INSN_COUNT(kEd25519VerifyMinInstructionCount,
                        kEd25519VerifyMaxInstructionCount);

  // Read verification result out of OTBN dmem.
  uint32_t verify_result;
  HARDENED_TRY(otbn_dmem_read(1, kOtbnVarEd25519VerifyResult, &verify_result));

  // Wipe DMEM.
  HARDENED_TRY(otbn_dmem_sec_wipe());

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
