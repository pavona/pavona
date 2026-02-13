// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/crypto/impl/rsa/rsa_modexp.h"

#include "sw/device/lib/crypto/drivers/acc.h"
#include "sw/device/lib/crypto/impl/rsa/rsa_modexp_insn_counts.h"

// Module ID for status codes.
#define MODULE_ID MAKE_MODULE_ID('r', 'm', 'e')

// Declare the ACC app.
ACC_DECLARE_APP_SYMBOLS(run_rsa_modexp);
static const acc_app_t kAccAppRsaModexp = ACC_APP_T_INIT(run_rsa_modexp);

// Declare offsets for input and output buffers.
ACC_DECLARE_SYMBOL_ADDR(run_rsa_modexp, mode);   // Application mode.
ACC_DECLARE_SYMBOL_ADDR(run_rsa_modexp, n);      // Public modulus n.
ACC_DECLARE_SYMBOL_ADDR(run_rsa_modexp, p);      // Cofactor p.
ACC_DECLARE_SYMBOL_ADDR(run_rsa_modexp, q);      // Cofactor q.
ACC_DECLARE_SYMBOL_ADDR(run_rsa_modexp, d);      // Private exponent d.
ACC_DECLARE_SYMBOL_ADDR(run_rsa_modexp, d_p);    // CRT component d_p.
ACC_DECLARE_SYMBOL_ADDR(run_rsa_modexp, d_q);    // CRT component d_q.
ACC_DECLARE_SYMBOL_ADDR(run_rsa_modexp, i_q);    // CRT coefficient i_q.
ACC_DECLARE_SYMBOL_ADDR(run_rsa_modexp, inout);  // Input/output buffer.

static const acc_addr_t kAccVarRsaMode = ACC_ADDR_T_INIT(run_rsa_modexp, mode);
static const acc_addr_t kAccVarRsaN = ACC_ADDR_T_INIT(run_rsa_modexp, n);
static const acc_addr_t kAccVarRsaP = ACC_ADDR_T_INIT(run_rsa_modexp, p);
static const acc_addr_t kAccVarRsaQ = ACC_ADDR_T_INIT(run_rsa_modexp, q);
static const acc_addr_t kAccVarRsaD = ACC_ADDR_T_INIT(run_rsa_modexp, d);
static const acc_addr_t kAccVarRsaDp = ACC_ADDR_T_INIT(run_rsa_modexp, d_p);
static const acc_addr_t kAccVarRsaDq = ACC_ADDR_T_INIT(run_rsa_modexp, d_q);
static const acc_addr_t kAccVarRsaIq = ACC_ADDR_T_INIT(run_rsa_modexp, i_q);
static const acc_addr_t kAccVarRsaInOut =
    ACC_ADDR_T_INIT(run_rsa_modexp, inout);

// Declare mode constants.
ACC_DECLARE_SYMBOL_ADDR(run_rsa_modexp, MODE_RSA_2048_MODEXP);
ACC_DECLARE_SYMBOL_ADDR(run_rsa_modexp, MODE_RSA_2048_MODEXP_CRT);
ACC_DECLARE_SYMBOL_ADDR(run_rsa_modexp, MODE_RSA_2048_MODEXP_F4);
ACC_DECLARE_SYMBOL_ADDR(run_rsa_modexp, MODE_RSA_3072_MODEXP);
ACC_DECLARE_SYMBOL_ADDR(run_rsa_modexp, MODE_RSA_3072_MODEXP_CRT);
ACC_DECLARE_SYMBOL_ADDR(run_rsa_modexp, MODE_RSA_3072_MODEXP_F4);
ACC_DECLARE_SYMBOL_ADDR(run_rsa_modexp, MODE_RSA_4096_MODEXP);
ACC_DECLARE_SYMBOL_ADDR(run_rsa_modexp, MODE_RSA_4096_MODEXP_CRT);
ACC_DECLARE_SYMBOL_ADDR(run_rsa_modexp, MODE_RSA_4096_MODEXP_F4);
static const uint32_t kMode2048Modexp =
    ACC_ADDR_T_INIT(run_rsa_modexp, MODE_RSA_2048_MODEXP);
static const uint32_t kMode2048ModexpCrt =
    ACC_ADDR_T_INIT(run_rsa_modexp, MODE_RSA_2048_MODEXP_CRT);
static const uint32_t kMode2048ModexpF4 =
    ACC_ADDR_T_INIT(run_rsa_modexp, MODE_RSA_2048_MODEXP_F4);
static const uint32_t kMode3072Modexp =
    ACC_ADDR_T_INIT(run_rsa_modexp, MODE_RSA_3072_MODEXP);
static const uint32_t kMode3072ModexpCrt =
    ACC_ADDR_T_INIT(run_rsa_modexp, MODE_RSA_3072_MODEXP_CRT);
static const uint32_t kMode3072ModexpF4 =
    ACC_ADDR_T_INIT(run_rsa_modexp, MODE_RSA_3072_MODEXP_F4);
static const uint32_t kMode4096Modexp =
    ACC_ADDR_T_INIT(run_rsa_modexp, MODE_RSA_4096_MODEXP);
static const uint32_t kMode4096ModexpCrt =
    ACC_ADDR_T_INIT(run_rsa_modexp, MODE_RSA_4096_MODEXP_CRT);
static const uint32_t kMode4096ModexpF4 =
    ACC_ADDR_T_INIT(run_rsa_modexp, MODE_RSA_4096_MODEXP_F4);

enum {
  /**
   * Common RSA exponent with a specialized implementation.
   *
   * This exponent is 2^16 + 1, and called "F4" because it's the fourth Fermat
   * number.
   */
  kExponentF4 = 65537,
};

status_t rsa_modexp_get_result_size(size_t *num_words) {
  // Return `OTCRYTPO_ASYNC_INCOMPLETE` if ACC not done.
  HARDENED_TRY(acc_assert_idle());

  // Read the application mode.
  uint32_t mode;
  HARDENED_TRY(acc_dmem_read(1, kAccVarRsaMode, &mode));

  *num_words = 0;
  if (mode == kMode2048Modexp || mode == kMode2048ModexpCrt ||
      mode == kMode2048ModexpF4) {
    *num_words = kRsa2048NumWords;
  } else if (mode == kMode3072Modexp || mode == kMode3072ModexpCrt ||
             mode == kMode3072ModexpF4) {
    *num_words = kRsa3072NumWords;
  } else if (mode == kMode4096Modexp || mode == kMode4096ModexpCrt ||
             mode == kMode4096ModexpF4) {
    *num_words = kRsa4096NumWords;
  } else {
    // Wipe DMEM.
    acc_dmem_sec_wipe_nofail();
    // Unrecognized mode.
    return OTCRYPTO_FATAL_ERR;
  }

  return OTCRYPTO_OK;
}

/**
 * Finalizes a modular exponentiation of variable size.
 *
 * Blocks until ACC is done, checks for errors. Ensures the mode matches
 * expectations. Reads back the result, and then performs an ACC secure wipe.
 *
 * @param num_words Number of words for the modexp result.
 * @param[out] result Result of the modexp operation.
 * @return Status of the operation (OK or error).
 */
OT_WARN_UNUSED_RESULT
static status_t rsa_modexp_finalize(const size_t num_words,
                                    const uint32_t min_insn_count,
                                    const uint32_t max_insn_count,
                                    uint32_t *result) {
  // Get the result size, failing if the ACC isn't done.
  size_t num_words_inferred;
  ACC_WIPE_IF_ERROR(rsa_modexp_get_result_size(&num_words_inferred));

  // Check that the inferred result size matches expectations.
  if (num_words != num_words_inferred) {
    acc_dmem_sec_wipe_nofail();
    return OTCRYPTO_FATAL_ERR;
  }

  // Check instruction count.
  ACC_CHECK_INSN_COUNT(min_insn_count, max_insn_count);

  // Read the result.
  ACC_WIPE_IF_ERROR(acc_dmem_read(num_words, kAccVarRsaInOut, result));

  // Wipe DMEM.
  return acc_dmem_sec_wipe();
}

status_t rsa_modexp_consttime_2048_start(const rsa_2048_int_t *base,
                                         const rsa_2048_int_t *exp,
                                         const rsa_2048_int_t *modulus) {
  // Load the ACC app. Fails if ACC is not idle.
  HARDENED_TRY(acc_load_app(kAccAppRsaModexp));

  // Set mode.
  uint32_t mode = kMode2048Modexp;
  HARDENED_TRY(acc_dmem_write(1, &mode, kAccVarRsaMode));

  // Set the base, the modulus n and private exponent d.
  HARDENED_TRY(acc_dmem_write(kRsa2048NumWords, base->data, kAccVarRsaInOut));
  HARDENED_TRY(acc_dmem_write(kRsa2048NumWords, modulus->data, kAccVarRsaN));
  ACC_WIPE_IF_ERROR(acc_dmem_write(kRsa2048NumWords, exp->data, kAccVarRsaD));

  // Start ACC.
  ACC_WIPE_IF_ERROR(acc_execute());
  return OTCRYPTO_OK;
}

status_t rsa_modexp_consttime_2048_finalize(rsa_2048_int_t *result) {
  return rsa_modexp_finalize(kRsa2048NumWords,
                             kRsa2048ModexpMinInstructionCount,
                             kRsa2048ModexpMaxInstructionCount, result->data);
}

status_t rsa_modexp_consttime_crt_2048_start(
    const rsa_2048_int_t *base, const rsa_2048_short_t *exp_p,
    const rsa_2048_short_t *exp_q, const rsa_2048_short_t *crt_coeff,
    const rsa_2048_short_t *modulus_p, const rsa_2048_short_t *modulus_q) {
  // Load the ACC app. Fails if ACC is not idle.
  HARDENED_TRY(acc_load_app(kAccAppRsaModexp));

  // Set mode.
  uint32_t mode = kMode2048ModexpCrt;
  HARDENED_TRY(acc_dmem_write(1, &mode, kAccVarRsaMode));

  // Set the base, the cofactors, the CRT components, and the CRT coefficient.
  HARDENED_TRY(acc_dmem_write(kRsa2048NumWords, base->data, kAccVarRsaInOut));
  ACC_WIPE_IF_ERROR(
      acc_dmem_write(kRsa2048NumWords / 2, modulus_p->data, kAccVarRsaP));
  ACC_WIPE_IF_ERROR(
      acc_dmem_write(kRsa2048NumWords / 2, modulus_q->data, kAccVarRsaQ));
  ACC_WIPE_IF_ERROR(
      acc_dmem_write(kRsa2048NumWords / 2, exp_p->data, kAccVarRsaDp));
  ACC_WIPE_IF_ERROR(
      acc_dmem_write(kRsa2048NumWords / 2, exp_q->data, kAccVarRsaDq));
  ACC_WIPE_IF_ERROR(
      acc_dmem_write(kRsa2048NumWords / 2, crt_coeff->data, kAccVarRsaIq));

  // Start ACC.
  ACC_WIPE_IF_ERROR(acc_execute());
  return OTCRYPTO_OK;
}

status_t rsa_modexp_consttime_crt_2048_finalize(rsa_2048_int_t *result) {
  return rsa_modexp_finalize(
      kRsa2048NumWords, kRsa2048ModexpCrtMinInstructionCount,
      kRsa2048ModexpCrtMaxInstructionCount, result->data);
}

status_t rsa_modexp_vartime_2048_start(const rsa_2048_int_t *base,
                                       const uint32_t exp,
                                       const rsa_2048_int_t *modulus) {
  if (exp != kExponentF4) {
    // TODO for other exponents, we temporarily fall back to the constant-time
    // implementation until a variable-time implementation is supported.
    rsa_2048_int_t exp_rsa;
    memset(exp_rsa.data, 0, kRsa2048NumWords * sizeof(uint32_t));
    exp_rsa.data[0] = exp;
    return rsa_modexp_consttime_2048_start(base, &exp_rsa, modulus);
  }

  // Load the ACC app. Fails if ACC is not idle.
  HARDENED_TRY(acc_load_app(kAccAppRsaModexp));

  // Set mode.
  uint32_t mode = kMode2048ModexpF4;
  HARDENED_TRY(acc_dmem_write(1, &mode, kAccVarRsaMode));

  // Set the base and the modulus n.
  HARDENED_TRY(acc_dmem_write(kRsa2048NumWords, base->data, kAccVarRsaInOut));
  HARDENED_TRY(acc_dmem_write(kRsa2048NumWords, modulus->data, kAccVarRsaN));

  // Start ACC.
  return acc_execute();
}

status_t rsa_modexp_vartime_2048_finalize(const uint32_t exp,
                                          rsa_2048_int_t *result) {
  if (exp != kExponentF4) {
    return rsa_modexp_finalize(kRsa2048NumWords,
                               kRsa2048ModexpMinInstructionCount,
                               kRsa2048ModexpMaxInstructionCount, result->data);
  }

  return rsa_modexp_finalize(kRsa2048NumWords,
                             kRsa2048ModexpF4MinInstructionCount,
                             kRsa2048ModexpF4MaxInstructionCount, result->data);
}

status_t rsa_modexp_consttime_3072_start(const rsa_3072_int_t *base,
                                         const rsa_3072_int_t *exp,
                                         const rsa_3072_int_t *modulus) {
  // Load the ACC app. Fails if ACC is not idle.
  HARDENED_TRY(acc_load_app(kAccAppRsaModexp));

  // Set mode.
  uint32_t mode = kMode3072Modexp;
  HARDENED_TRY(acc_dmem_write(1, &mode, kAccVarRsaMode));

  // Set the base, the modulus n and private exponent d.
  HARDENED_TRY(acc_dmem_write(kRsa3072NumWords, base->data, kAccVarRsaInOut));
  HARDENED_TRY(acc_dmem_write(kRsa3072NumWords, modulus->data, kAccVarRsaN));
  ACC_WIPE_IF_ERROR(acc_dmem_write(kRsa3072NumWords, exp->data, kAccVarRsaD));

  // Start ACC.
  ACC_WIPE_IF_ERROR(acc_execute());
  return OTCRYPTO_OK;
}

status_t rsa_modexp_consttime_3072_finalize(rsa_3072_int_t *result) {
  return rsa_modexp_finalize(kRsa3072NumWords,
                             kRsa3072ModexpMinInstructionCount,
                             kRsa3072ModexpMaxInstructionCount, result->data);
}

status_t rsa_modexp_consttime_crt_3072_start(
    const rsa_3072_int_t *base, const rsa_3072_short_t *exp_p,
    const rsa_3072_short_t *exp_q, const rsa_3072_short_t *crt_coeff,
    const rsa_3072_short_t *modulus_p, const rsa_3072_short_t *modulus_q) {
  // Load the ACC app. Fails if ACC is not idle.
  HARDENED_TRY(acc_load_app(kAccAppRsaModexp));

  // Set mode.
  uint32_t mode = kMode3072ModexpCrt;
  HARDENED_TRY(acc_dmem_write(1, &mode, kAccVarRsaMode));

  // Set the base, the cofactors, the CRT components, and the CRT coefficient.
  HARDENED_TRY(acc_dmem_write(kRsa3072NumWords, base->data, kAccVarRsaInOut));
  ACC_WIPE_IF_ERROR(
      acc_dmem_write(kRsa3072NumWords / 2, modulus_p->data, kAccVarRsaP));
  ACC_WIPE_IF_ERROR(
      acc_dmem_write(kRsa3072NumWords / 2, modulus_q->data, kAccVarRsaQ));
  ACC_WIPE_IF_ERROR(
      acc_dmem_write(kRsa3072NumWords / 2, exp_p->data, kAccVarRsaDp));
  ACC_WIPE_IF_ERROR(
      acc_dmem_write(kRsa3072NumWords / 2, exp_q->data, kAccVarRsaDq));
  ACC_WIPE_IF_ERROR(
      acc_dmem_write(kRsa3072NumWords / 2, crt_coeff->data, kAccVarRsaIq));

  // Start ACC.
  ACC_WIPE_IF_ERROR(acc_execute());
  return OTCRYPTO_OK;
}

status_t rsa_modexp_consttime_crt_3072_finalize(rsa_3072_int_t *result) {
  return rsa_modexp_finalize(
      kRsa3072NumWords, kRsa3072ModexpCrtMinInstructionCount,
      kRsa3072ModexpCrtMaxInstructionCount, result->data);
}

status_t rsa_modexp_vartime_3072_start(const rsa_3072_int_t *base,
                                       const uint32_t exp,
                                       const rsa_3072_int_t *modulus) {
  if (exp != kExponentF4) {
    // TODO for other exponents, we temporarily fall back to the constant-time
    // implementation until a variable-time implementation is supported.
    rsa_3072_int_t exp_rsa;
    memset(exp_rsa.data, 0, kRsa3072NumWords * sizeof(uint32_t));
    exp_rsa.data[0] = exp;
    return rsa_modexp_consttime_3072_start(base, &exp_rsa, modulus);
  }

  // Load the ACC app. Fails if ACC is not idle.
  HARDENED_TRY(acc_load_app(kAccAppRsaModexp));

  // Set mode.
  uint32_t mode = kMode3072ModexpF4;
  HARDENED_TRY(acc_dmem_write(1, &mode, kAccVarRsaMode));

  // Set the base and the modulus n.
  HARDENED_TRY(acc_dmem_write(kRsa3072NumWords, base->data, kAccVarRsaInOut));
  HARDENED_TRY(acc_dmem_write(kRsa3072NumWords, modulus->data, kAccVarRsaN));

  // Start ACC.
  return acc_execute();
}

status_t rsa_modexp_vartime_3072_finalize(const uint32_t exp,
                                          rsa_3072_int_t *result) {
  if (exp != kExponentF4) {
    return rsa_modexp_finalize(kRsa3072NumWords,
                               kRsa3072ModexpMinInstructionCount,
                               kRsa3072ModexpMaxInstructionCount, result->data);
  }

  return rsa_modexp_finalize(kRsa3072NumWords,
                             kRsa3072ModexpF4MinInstructionCount,
                             kRsa3072ModexpF4MaxInstructionCount, result->data);
}

status_t rsa_modexp_consttime_4096_start(const rsa_4096_int_t *base,
                                         const rsa_4096_int_t *exp,
                                         const rsa_4096_int_t *modulus) {
  // Load the ACC app. Fails if ACC is not idle.
  HARDENED_TRY(acc_load_app(kAccAppRsaModexp));

  // Set mode.
  uint32_t mode = kMode4096Modexp;
  HARDENED_TRY(acc_dmem_write(1, &mode, kAccVarRsaMode));

  // Set the base, the modulus n and private exponent d.
  HARDENED_TRY(acc_dmem_write(kRsa4096NumWords, base->data, kAccVarRsaInOut));
  HARDENED_TRY(acc_dmem_write(kRsa4096NumWords, modulus->data, kAccVarRsaN));
  ACC_WIPE_IF_ERROR(acc_dmem_write(kRsa4096NumWords, exp->data, kAccVarRsaD));

  // Start ACC.
  ACC_WIPE_IF_ERROR(acc_execute());
  return OTCRYPTO_OK;
}

status_t rsa_modexp_consttime_4096_finalize(rsa_4096_int_t *result) {
  return rsa_modexp_finalize(kRsa4096NumWords,
                             kRsa4096ModexpMinInstructionCount,
                             kRsa4096ModexpMaxInstructionCount, result->data);
}

status_t rsa_modexp_consttime_crt_4096_start(
    const rsa_4096_int_t *base, const rsa_4096_short_t *exp_p,
    const rsa_4096_short_t *exp_q, const rsa_4096_short_t *crt_coeff,
    const rsa_4096_short_t *modulus_p, const rsa_4096_short_t *modulus_q) {
  // Load the ACC app. Fails if ACC is not idle.
  HARDENED_TRY(acc_load_app(kAccAppRsaModexp));

  // Set mode.
  uint32_t mode = kMode4096ModexpCrt;
  HARDENED_TRY(acc_dmem_write(1, &mode, kAccVarRsaMode));

  // Set the base, the cofactors, the CRT components, and the CRT coefficient.
  HARDENED_TRY(acc_dmem_write(kRsa4096NumWords, base->data, kAccVarRsaInOut));
  ACC_WIPE_IF_ERROR(
      acc_dmem_write(kRsa4096NumWords / 2, modulus_p->data, kAccVarRsaP));
  ACC_WIPE_IF_ERROR(
      acc_dmem_write(kRsa4096NumWords / 2, modulus_q->data, kAccVarRsaQ));
  ACC_WIPE_IF_ERROR(
      acc_dmem_write(kRsa4096NumWords / 2, exp_p->data, kAccVarRsaDp));
  ACC_WIPE_IF_ERROR(
      acc_dmem_write(kRsa4096NumWords / 2, exp_q->data, kAccVarRsaDq));
  ACC_WIPE_IF_ERROR(
      acc_dmem_write(kRsa4096NumWords / 2, crt_coeff->data, kAccVarRsaIq));

  // Start ACC.
  ACC_WIPE_IF_ERROR(acc_execute());
  return OTCRYPTO_OK;
}

status_t rsa_modexp_consttime_crt_4096_finalize(rsa_4096_int_t *result) {
  return rsa_modexp_finalize(
      kRsa4096NumWords, kRsa4096ModexpCrtMinInstructionCount,
      kRsa4096ModexpCrtMaxInstructionCount, result->data);
}

status_t rsa_modexp_vartime_4096_start(const rsa_4096_int_t *base,
                                       const uint32_t exp,
                                       const rsa_4096_int_t *modulus) {
  if (exp != kExponentF4) {
    // TODO for other exponents, we temporarily fall back to the constant-time
    // implementation until a variable-time implementation is supported.
    rsa_4096_int_t exp_rsa;
    memset(exp_rsa.data, 0, kRsa4096NumWords * sizeof(uint32_t));
    exp_rsa.data[0] = exp;
    return rsa_modexp_consttime_4096_start(base, &exp_rsa, modulus);
  }

  // Load the ACC app. Fails if ACC is not idle.
  HARDENED_TRY(acc_load_app(kAccAppRsaModexp));

  // Set mode.
  uint32_t mode = kMode4096ModexpF4;
  HARDENED_TRY(acc_dmem_write(1, &mode, kAccVarRsaMode));

  // Set the base and the modulus n.
  HARDENED_TRY(acc_dmem_write(kRsa4096NumWords, base->data, kAccVarRsaInOut));
  HARDENED_TRY(acc_dmem_write(kRsa4096NumWords, modulus->data, kAccVarRsaN));

  // Start ACC.
  return acc_execute();
}

status_t rsa_modexp_vartime_4096_finalize(const uint32_t exp,
                                          rsa_4096_int_t *result) {
  if (exp != kExponentF4) {
    return rsa_modexp_finalize(kRsa4096NumWords,
                               kRsa4096ModexpMinInstructionCount,
                               kRsa4096ModexpMaxInstructionCount, result->data);
  }

  return rsa_modexp_finalize(kRsa4096NumWords,
                             kRsa4096ModexpF4MinInstructionCount,
                             kRsa4096ModexpF4MaxInstructionCount, result->data);
}
