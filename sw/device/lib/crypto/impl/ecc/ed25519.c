// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/crypto/impl/ecc/ed25519.h"

#include "sw/device/lib/base/math.h"
#include "sw/device/lib/crypto/drivers/entropy.h"
#include "sw/device/lib/crypto/drivers/rv_core_ibex.h"
#include "sw/device/lib/crypto/impl/ecc/ed25519_insn_counts.h"
#include "sw/device/lib/crypto/include/datatypes.h"

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
ACC_DECLARE_SYMBOL_ADDR(run_ed25519, ed25519_message_len);    // Message length.
ACC_DECLARE_SYMBOL_ADDR(run_ed25519, ed25519_public_key);     // Public key.
ACC_DECLARE_SYMBOL_ADDR(run_ed25519, ed25519_verify_result);  // Verify result.
ACC_DECLARE_SYMBOL_ADDR(run_ed25519, ed25519_session_token);  // Session token.

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
static const acc_addr_t kAccVarEd25519MessageLen =
    ACC_ADDR_T_INIT(run_ed25519, ed25519_message_len);
static const acc_addr_t kAccVarEd25519PublicKey =
    ACC_ADDR_T_INIT(run_ed25519, ed25519_public_key);
static const acc_addr_t kAccVarEd25519VerifyResult =
    ACC_ADDR_T_INIT(run_ed25519, ed25519_verify_result);
static const acc_addr_t kAccVarEd25519SessionToken =
    ACC_ADDR_T_INIT(run_ed25519, ed25519_session_token);

// Declare mode constants.
ACC_DECLARE_SYMBOL_ADDR(run_ed25519,
                        ED25519_MODE_SIGN_PREHASH);  // HashEd25519 signing.
ACC_DECLARE_SYMBOL_ADDR(run_ed25519,
                        ED25519_MODE_SIGN_PURE_INIT);  // Pure sign: init.
ACC_DECLARE_SYMBOL_ADDR(run_ed25519,
                        ED25519_MODE_SIGN_PURE_UPDATE);  // Pure sign: update.
ACC_DECLARE_SYMBOL_ADDR(run_ed25519,
                        ED25519_MODE_SIGN_PURE_MID);  // Pure sign: mid.
ACC_DECLARE_SYMBOL_ADDR(run_ed25519,
                        ED25519_MODE_SIGN_PURE_FINAL);  // Pure sign: final.
ACC_DECLARE_SYMBOL_ADDR(run_ed25519,
                        ED25519_MODE_VERIFY);  // Ed25519 verification.

static const uint32_t kAccEd25519ModeSignHash =
    ACC_ADDR_T_INIT(run_ed25519, ED25519_MODE_SIGN_PREHASH);
static const uint32_t kAccEd25519ModeSignPureInit =
    ACC_ADDR_T_INIT(run_ed25519, ED25519_MODE_SIGN_PURE_INIT);
static const uint32_t kAccEd25519ModeSignPureUpdate =
    ACC_ADDR_T_INIT(run_ed25519, ED25519_MODE_SIGN_PURE_UPDATE);
static const uint32_t kAccEd25519ModeSignPureMid =
    ACC_ADDR_T_INIT(run_ed25519, ED25519_MODE_SIGN_PURE_MID);
static const uint32_t kAccEd25519ModeSignPureFinal =
    ACC_ADDR_T_INIT(run_ed25519, ED25519_MODE_SIGN_PURE_FINAL);
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
 * @param context_length Length of the provided context in bytes.
 * @return OK or error.
 */
OT_WARN_UNUSED_RESULT
static status_t set_context(const uint32_t context[kEd25519ContextWords],
                            const uint32_t context_length) {
  // Ensure that our context length is valid; if not, fail early.
  if (context_length > kEd25519ContextBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_LE(context_length, kEd25519ContextBytes);

  // Write the context string. If the context length is not a multiple of
  // 32 bytes, the bytes up to the next multiple of 32 must be initialized
  // to prevent read errors.
  size_t padded_words =
      ceil_div(context_length, kAccWideWordNumBytes) * kAccWideWordNumWords;
  uint32_t padded_ctx[padded_words];
  memset(padded_ctx, 0, sizeof(padded_ctx));
  memcpy(padded_ctx, context, context_length);
  HARDENED_TRY(acc_dmem_write(padded_words, padded_ctx, kAccVarEd25519Ctx));

  // Set the context length.
  return acc_dmem_write(1, &context_length, kAccVarEd25519CtxLen);
}

status_t ed25519_sign_hash_start(
    const uint32_t prehashed_message[kEd25519PreHashWords],
    const uint32_t hash_h[kEd25519HashWords],
    const uint32_t context[kEd25519ContextWords], const uint32_t context_length,
    uint32_t *session_token) {
  // Load the Ed25519 app. Fails if ACC is non-idle.
  HARDENED_TRY(acc_load_app(kAccAppEd25519));

  // Set mode so start() will jump into HashEd25519 signing.
  uint32_t mode = kAccEd25519ModeSignHash;
  HARDENED_TRY(acc_dmem_write(kAccEd25519ModeWords, &mode, kAccVarEd25519Mode));

  // Set the precomputed private key hash h.
  HARDENED_TRY(
      acc_dmem_write(kEd25519PreHashWords, hash_h, kAccVarEd25519HashH));

  // Set the context string.
  HARDENED_TRY(set_context(context, context_length));

  // Set the pre-hashed message.
  HARDENED_TRY(acc_dmem_write(kEd25519HashWords, prehashed_message,
                              kAccVarEd25519Message));

  // Generate a fresh session token, and store it in DMEM.
  uint32_t token = ibex_rnd32_read();
  HARDENED_TRY(acc_dmem_write(1, &token, kAccVarEd25519SessionToken));
  *session_token = token;

  // Start the ACC routine.
  return acc_execute();
}

enum {
  /**
   * Maximum message chunk size in bytes for incremental pure Ed25519 signing.
   */
  kEd25519MaxChunkBytes = 1280,
};

/**
 * Run one phase of the incremental pure Ed25519 signing on ACC.
 *
 * Sets the mode, executes the ACC, waits for completion, and checks the
 * instruction count against the expected range for the phase.
 */
static status_t ed25519_sign_pure_run_phase(uint32_t mode, uint32_t min_insn,
                                            uint32_t max_insn) {
  HARDENED_TRY(acc_dmem_write(kAccEd25519ModeWords, &mode, kAccVarEd25519Mode));
  HARDENED_TRY(acc_execute());
  ACC_WIPE_IF_ERROR(acc_busy_wait_for_done());
  ACC_CHECK_INSN_COUNT(min_insn, max_insn);
  return OTCRYPTO_OK;
}

/**
 * Write a message chunk to DMEM, padded to a 32-byte boundary.
 */
static status_t ed25519_sign_pure_write_chunk(const uint8_t *chunk,
                                              size_t chunk_len) {
  size_t padded_words =
      ceil_div(chunk_len, kAccWideWordNumBytes) * kAccWideWordNumWords;
  uint32_t padded[padded_words];
  memset(padded, 0, sizeof(padded));
  memcpy(padded, chunk, chunk_len);
  HARDENED_TRY(acc_dmem_write(padded_words, padded, kAccVarEd25519Message));
  uint32_t len_word = (uint32_t)chunk_len;
  return acc_dmem_write(1, &len_word, kAccVarEd25519MessageLen);
}

/**
 * Start an incremental pure Ed25519 signature generation on ACC.
 *
 * The message M may be larger than what can fit in ACC DMEM.
 * Hence, we stream in the message using an incremental API.
 * Because M appears in both the nonce and challenge hash,
 * it needs to be streamed twice.
 *
 * Pure Ed25519 signing (RFC 8032, section 5.1.6) computes:
 *   h = SHA-512(d)                 - secret key hash (done by caller)
 *   prefix = h[32:64]              - upper half of h
 *   s = clamp(h[0:32])             - secret scalar from lower half
 *   r = SHA-512(prefix || M)       - nonce hash
 *   R = [r]B                       - signature point
 *   A = [s]B                       - public key
 *   k = SHA-512(R_ || A_ || M)     - challenge hash
 *   S = (r + k * s) mod L          - signature scalar
 *
 * The signature is (R_, S).
 *
 * ACC offers the following operations:
 * INIT   - start nonce hash: SHA-512(prefix || first_chunk)
 * UPDATE - feed more chunks into the nonce hash
 *          (if M > kEd25519MaxChunkBytes bytes)
 * MID    - finalize nonce hash, compute R and A, start challenge hash.
 * UPDATE - feed more chunks into the challenge hash
 *          (if M > kEd25519MaxChunkBytes bytes)
 * FINAL  - finalize challenge, compute S = (r + k * s) mod L
 *
 * The UPDATE steps are only required if the message is larger
 * than kEd25519MaxChunkBytes.
 * The two UPDATE steps are identical.
 */
status_t ed25519_sign_pure_start(const uint32_t *message, size_t message_len,
                                 const uint32_t hash_h[kEd25519HashWords],
                                 uint32_t *session_token) {
  const uint8_t *msg = (const uint8_t *)message;

  // Load the Ed25519 app. Fails if ACC is non-idle.
  HARDENED_TRY(acc_load_app(kAccAppEd25519));

  // Set the precomputed private key hash h.
  HARDENED_TRY(acc_dmem_write(kEd25519HashWords, hash_h, kAccVarEd25519HashH));

  // Generate a fresh session token, and store it in DMEM.
  uint32_t token = ibex_rnd32_read();
  HARDENED_TRY(acc_dmem_write(1, &token, kAccVarEd25519SessionToken));
  *session_token = token;

  // INIT: begin the nonce hash r = SHA-512(prefix || M) by hashing the key
  // prefix (upper 32 bytes of h) and the first message chunk.
  size_t first_chunk = (message_len < kEd25519MaxChunkBytes)
                           ? message_len
                           : kEd25519MaxChunkBytes;
  HARDENED_TRY(ed25519_sign_pure_write_chunk(msg, first_chunk));
  ACC_WIPE_IF_ERROR(ed25519_sign_pure_run_phase(
      kAccEd25519ModeSignPureInit, kEd25519SignPureInitMinInstructionCount,
      kEd25519SignPureInitMaxInstructionCount));

  // UPDATE: feed remaining message chunks into the nonce hash.
  for (size_t offset = first_chunk; offset < message_len;
       offset += kEd25519MaxChunkBytes) {
    size_t chunk = message_len - offset;
    if (chunk > kEd25519MaxChunkBytes) {
      chunk = kEd25519MaxChunkBytes;
    }
    HARDENED_TRY(ed25519_sign_pure_write_chunk(msg + offset, chunk));
    ACC_WIPE_IF_ERROR(
        ed25519_sign_pure_run_phase(kAccEd25519ModeSignPureUpdate,
                                    kEd25519SignPureUpdateMinInstructionCount,
                                    kEd25519SignPureUpdateMaxInstructionCount));
  }

  // MID: finalize the nonce hash to get r, compute the signature point
  // R_ = encode([r]B) and public key A_ = encode([s]B), then begin the
  // challenge hash k = SHA-512(R_ || A_ || M) with the first message chunk.
  HARDENED_TRY(ed25519_sign_pure_write_chunk(msg, first_chunk));
  ACC_WIPE_IF_ERROR(ed25519_sign_pure_run_phase(
      kAccEd25519ModeSignPureMid, kEd25519SignPureMidMinInstructionCount,
      kEd25519SignPureMidMaxInstructionCount));

  // UPDATE: feed remaining message chunks into the challenge hash.
  for (size_t offset = first_chunk; offset < message_len;
       offset += kEd25519MaxChunkBytes) {
    size_t chunk = message_len - offset;
    if (chunk > kEd25519MaxChunkBytes) {
      chunk = kEd25519MaxChunkBytes;
    }
    HARDENED_TRY(ed25519_sign_pure_write_chunk(msg + offset, chunk));
    ACC_WIPE_IF_ERROR(
        ed25519_sign_pure_run_phase(kAccEd25519ModeSignPureUpdate,
                                    kEd25519SignPureUpdateMinInstructionCount,
                                    kEd25519SignPureUpdateMaxInstructionCount));
  }

  // FINAL: finalize the challenge hash to get k, then compute the signature
  // scalar S = (r + k * s) mod L. The caller reads R_ and S from DMEM.
  uint32_t mode = kAccEd25519ModeSignPureFinal;
  HARDENED_TRY(acc_dmem_write(kAccEd25519ModeWords, &mode, kAccVarEd25519Mode));
  return acc_execute();
}

/**
 * Common finalize logic for Ed25519 signing (both modes).
 */
static status_t ed25519_sign_finalize_inner(uint32_t session_token,
                                            uint32_t min_insn_count,
                                            uint32_t max_insn_count,
                                            ed25519_signature_t *result) {
  // Return `OTCRYTPO_ASYNC_INCOMPLETE` if ACC not done.
  HARDENED_TRY(acc_assert_idle());

  // Check the session token matches the expected one.
  // If this check fails, either the cryptolib client's logic is broken and
  // providing an incorrect value for the token, or another cryptolib client
  // (e.g. in a multitenant OS) has erroneously been allowed to access the ACC
  // before the client which started the operation can clear the results. To
  // maintain security, both of these must be treated as unrecoverable errors.
  uint32_t stored_token = 0;
  HARDENED_TRY(acc_dmem_read(1, kAccVarEd25519SessionToken, &stored_token));
  if (launder32(stored_token) != session_token) {
    return OTCRYPTO_FATAL_ERR;
  }
  HARDENED_CHECK_EQ(stored_token, session_token);

  // Check instruction count.
  ACC_CHECK_INSN_COUNT(min_insn_count, max_insn_count);

  // Read signature R out of ACC dmem.
  HARDENED_TRY(acc_dmem_read(8, kAccVarEd25519SigR, result->r));

  // Read signature S out of ACC dmem.
  HARDENED_TRY(acc_dmem_read(8, kAccVarEd25519SigS, result->s));

  // Wipe DMEM.
  return acc_dmem_sec_wipe();
}

status_t ed25519_sign_hash_finalize(uint32_t session_token,
                                    ed25519_signature_t *result) {
  return ed25519_sign_finalize_inner(
      session_token, kEd25519SignHashMinInstructionCount,
      kEd25519SignHashMaxInstructionCount, result);
}

status_t ed25519_sign_pure_finalize(uint32_t session_token,
                                    ed25519_signature_t *result) {
  return ed25519_sign_finalize_inner(
      session_token, kEd25519SignPureFinalMinInstructionCount,
      kEd25519SignPureFinalMaxInstructionCount, result);
}

status_t ed25519_verify_start(const ed25519_signature_t *signature,
                              const uint32_t hash_k[kEd25519HashWords],
                              const ed25519_point_t *public_key,
                              uint32_t *session_token) {
  // Load the Ed25519 app.
  HARDENED_TRY(acc_load_app(kAccAppEd25519));

  // Set mode so start() will jump into verifying.
  uint32_t mode = kAccEd25519ModeVerify;
  HARDENED_TRY(acc_dmem_write(kAccEd25519ModeWords, &mode, kAccVarEd25519Mode));

  // Set the precomputed hash value k.
  HARDENED_TRY(acc_dmem_write(kEd25519HashWords, hash_k, kAccVarEd25519HashK));

  // Set the signature R.
  HARDENED_TRY(
      acc_dmem_write(kEd25519PointWords, signature->r, kAccVarEd25519SigR));

  // Set the signature S.
  HARDENED_TRY(
      acc_dmem_write(kEd25519ScalarWords, signature->s, kAccVarEd25519SigS));

  // Set the public key.
  HARDENED_TRY(acc_dmem_write(kEd25519PointWords, public_key->data,
                              kAccVarEd25519PublicKey));

  // Generate a fresh session token, and store it in DMEM.
  uint32_t token = ibex_rnd32_read();
  HARDENED_TRY(acc_dmem_write(1, &token, kAccVarEd25519SessionToken));
  *session_token = token;

  // Start the ACC routine.
  return acc_execute();
}

status_t ed25519_verify_finalize(uint32_t session_token,
                                 hardened_bool_t *result) {
  // Return `OTCRYTPO_ASYNC_INCOMPLETE` if ACC not done.
  HARDENED_TRY(acc_assert_idle());

  // Check the session token matches the expected one.
  // If this check fails, either the cryptolib client's logic is broken and
  // providing an incorrect value for the token, or another cryptolib client
  // (e.g. in a multitenant OS) has erroneously been allowed to access the ACC
  // before the client which started the operation can clear the results. To
  // maintain security, both of these must be treated as unrecoverable errors.
  uint32_t stored_token = 0;
  HARDENED_TRY(acc_dmem_read(1, kAccVarEd25519SessionToken, &stored_token));
  if (launder32(stored_token) != session_token) {
    return OTCRYPTO_FATAL_ERR;
  }
  HARDENED_CHECK_EQ(stored_token, session_token);

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
