// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/crypto/impl/rsa/rsa_keygen.h"

#include "sw/device/lib/base/hardened.h"
#include "sw/device/lib/base/hardened_memory.h"
#include "sw/device/lib/crypto/drivers/otbn.h"

// Module ID for status codes.
#define MODULE_ID MAKE_MODULE_ID('r', 'k', 'g')

// Declare the OTBN app.
OTBN_DECLARE_APP_SYMBOLS(run_rsa_keygen);
static const otbn_app_t kOtbnAppRsaKeygen = OTBN_APP_T_INIT(run_rsa_keygen);

// Declare offsets for input and output buffers.
OTBN_DECLARE_SYMBOL_ADDR(run_rsa_keygen, mode);   // Application mode.
OTBN_DECLARE_SYMBOL_ADDR(run_rsa_keygen, rsa_n);  // Public exponent n.
OTBN_DECLARE_SYMBOL_ADDR(run_rsa_keygen, rsa_p);  // Cofactor p.
OTBN_DECLARE_SYMBOL_ADDR(run_rsa_keygen, rsa_q);  // Cofactor q.
OTBN_DECLARE_SYMBOL_ADDR(run_rsa_keygen,
                         rsa_d_p);  // Private exponent component d_p.
OTBN_DECLARE_SYMBOL_ADDR(run_rsa_keygen,
                         rsa_d_q);  // Private exponent component d_p.
OTBN_DECLARE_SYMBOL_ADDR(run_rsa_keygen, rsa_i_q);       // CRT coefficient i_p.
OTBN_DECLARE_SYMBOL_ADDR(run_rsa_keygen, rsa_cofactor);  // Cofactor p or q.

static const otbn_addr_t kOtbnVarRsaMode =
    OTBN_ADDR_T_INIT(run_rsa_keygen, mode);
static const otbn_addr_t kOtbnVarRsaN = OTBN_ADDR_T_INIT(run_rsa_keygen, rsa_n);
static const otbn_addr_t kOtbnVarRsaP = OTBN_ADDR_T_INIT(run_rsa_keygen, rsa_p);
static const otbn_addr_t kOtbnVarRsaQ = OTBN_ADDR_T_INIT(run_rsa_keygen, rsa_q);
static const otbn_addr_t kOtbnVarRsaDp =
    OTBN_ADDR_T_INIT(run_rsa_keygen, rsa_d_p);
static const otbn_addr_t kOtbnVarRsaDq =
    OTBN_ADDR_T_INIT(run_rsa_keygen, rsa_d_q);
static const otbn_addr_t kOtbnVarRsaIq =
    OTBN_ADDR_T_INIT(run_rsa_keygen, rsa_i_q);
static const otbn_addr_t kOtbnVarRsaCofactor =
    OTBN_ADDR_T_INIT(run_rsa_keygen, rsa_cofactor);

// Declare mode constants.
OTBN_DECLARE_SYMBOL_ADDR(run_rsa_keygen, MODE_GEN_RSA_2048);
OTBN_DECLARE_SYMBOL_ADDR(run_rsa_keygen, MODE_COFACTOR_RSA_2048);
OTBN_DECLARE_SYMBOL_ADDR(run_rsa_keygen, MODE_GEN_RSA_3072);
OTBN_DECLARE_SYMBOL_ADDR(run_rsa_keygen, MODE_GEN_RSA_4096);
static const uint32_t kOtbnRsaModeGen2048 =
    OTBN_ADDR_T_INIT(run_rsa_keygen, MODE_GEN_RSA_2048);
static const uint32_t kOtbnRsaModeCofactor2048 =
    OTBN_ADDR_T_INIT(run_rsa_keygen, MODE_COFACTOR_RSA_2048);
static const uint32_t kOtbnRsaModeGen3072 =
    OTBN_ADDR_T_INIT(run_rsa_keygen, MODE_GEN_RSA_3072);
static const uint32_t kOtbnRsaModeGen4096 =
    OTBN_ADDR_T_INIT(run_rsa_keygen, MODE_GEN_RSA_4096);

enum {
  /* Fixed public exponent for generated keys. This exponent is 2^16 + 1, also
     known as "F4" because it's the fourth Fermat number. */
  kFixedPublicExponent = 65537,
  /* Number of words used to represent the application mode. */
  kOtbnRsaModeWords = 1,
};

/**
 * Start the OTBN key generation program in random-key mode.
 *
 * Cofactor mode should not use this routine, because it wipes DMEM and
 * cofactor mode requires input data.
 *
 * @param mode Mode parameter for keygen.
 * @return Result of the operation.
 */
static status_t keygen_start(uint32_t mode) {
  // Load the RSA key generation app. Fails if OTBN is non-idle.
  HARDENED_TRY(otbn_load_app(kOtbnAppRsaKeygen));

  // Set mode and start OTBN.
  HARDENED_TRY(otbn_dmem_write(kOtbnRsaModeWords, &mode, kOtbnVarRsaMode));
  return otbn_execute();
}

/**
 * Finalize a key generation operation (for either mode).
 *
 * Checks the application mode against expectations, then reads back the
 * modulus and private exponent.
 *
 * @param exp_mode Application mode to expect.
 * @param num_words Number of words for modulus and private exponent.
 * @param[out] n Buffer for the modulus.
 * @param[out] p Buffer for the first cofactor.
 * @param[out] q Buffer for the second cofactor.
 * @param[out] d_p Buffer for the first private exponent component.
 * @param[out] d_q Buffer for the second private exponent component.
 * @param[out] i_q Buffer for the CRT reconstruction coefficient.
 * @return OK or error.
 */
static status_t keygen_finalize(uint32_t exp_mode, size_t num_words,
                                uint32_t *n, uint32_t *p, uint32_t *q,
                                uint32_t *d_p, uint32_t *d_q, uint32_t *i_q) {
  // Spin here waiting for OTBN to complete.
  OTBN_WIPE_IF_ERROR(otbn_busy_wait_for_done());

  // Read the mode from OTBN dmem and panic if it's not as expected.
  uint32_t act_mode = 0;
  OTBN_WIPE_IF_ERROR(otbn_dmem_read(1, kOtbnVarRsaMode, &act_mode));
  if (act_mode != exp_mode) {
    return OTCRYPTO_FATAL_ERR;
  }

  // Read the public modulus (n) from OTBN dmem.
  OTBN_WIPE_IF_ERROR(otbn_dmem_read(num_words, kOtbnVarRsaN, n));

  // Read the first cofactor (p) from OTBN dmem.
  OTBN_WIPE_IF_ERROR(otbn_dmem_read(num_words / 2, kOtbnVarRsaP, p));

  // Read the first cofactor (q) from OTBN dmem.
  OTBN_WIPE_IF_ERROR(otbn_dmem_read(num_words / 2, kOtbnVarRsaQ, q));

  // Read the first private exponent CRT component (d_p) from OTBN dmem.
  OTBN_WIPE_IF_ERROR(otbn_dmem_read(num_words / 2, kOtbnVarRsaDp, d_p));

  // Read the second private expoent CRT component (d_q) from OTBN dmem.
  OTBN_WIPE_IF_ERROR(otbn_dmem_read(num_words / 2, kOtbnVarRsaDq, d_q));

  // Read the CRT coefficient (i_q) from OTBN dmem.
  OTBN_WIPE_IF_ERROR(otbn_dmem_read(num_words / 2, kOtbnVarRsaIq, i_q));

  // Wipe DMEM.
  return otbn_dmem_sec_wipe();
}

status_t rsa_keygen_2048_start(void) {
  return keygen_start(kOtbnRsaModeGen2048);
}

status_t rsa_keygen_2048_finalize(rsa_2048_public_key_t *public_key,
                                  rsa_2048_private_key_t *private_key) {
  HARDENED_TRY(keygen_finalize(kOtbnRsaModeGen2048, kRsa2048NumWords,
                               public_key->n.data, private_key->p.data,
                               private_key->q.data, private_key->d_p.data,
                               private_key->d_q.data, private_key->i_q.data));

  // Set the public exponent to F4, the only exponent our key generation
  // algorithm supports.
  public_key->e = kFixedPublicExponent;

  return OTCRYPTO_OK;
}

status_t rsa_keygen_3072_start(void) {
  return keygen_start(kOtbnRsaModeGen3072);
}

status_t rsa_keygen_3072_finalize(rsa_3072_public_key_t *public_key,
                                  rsa_3072_private_key_t *private_key) {
  HARDENED_TRY(keygen_finalize(kOtbnRsaModeGen3072, kRsa3072NumWords,
                               public_key->n.data, private_key->p.data,
                               private_key->q.data, private_key->d_p.data,
                               private_key->d_q.data, private_key->i_q.data));

  // Set the public exponent to F4, the only exponent our key generation
  // algorithm supports.
  public_key->e = kFixedPublicExponent;

  return OTCRYPTO_OK;
}

status_t rsa_keygen_4096_start(void) {
  return keygen_start(kOtbnRsaModeGen4096);
}

status_t rsa_keygen_4096_finalize(rsa_4096_public_key_t *public_key,
                                  rsa_4096_private_key_t *private_key) {
  HARDENED_TRY(keygen_finalize(kOtbnRsaModeGen4096, kRsa4096NumWords,
                               public_key->n.data, private_key->p.data,
                               private_key->q.data, private_key->d_p.data,
                               private_key->d_q.data, private_key->i_q.data));

  // Set the public exponent to F4, the only exponent our key generation
  // algorithm supports.
  public_key->e = kFixedPublicExponent;

  return OTCRYPTO_OK;
}

status_t rsa_keygen_from_cofactor_2048_start(
    const rsa_2048_public_key_t *public_key, const rsa_2048_short_t *cofactor) {
  // Only the exponent F4 is supported.
  if (public_key->e != kFixedPublicExponent) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Load the RSA key generation app. Fails if OTBN is non-idle.
  HARDENED_TRY(otbn_load_app(kOtbnAppRsaKeygen));

  // Write the modulus and cofactor into DMEM.
  HARDENED_TRY(otbn_dmem_write(ARRAYSIZE(public_key->n.data),
                               public_key->n.data, kOtbnVarRsaN));
  HARDENED_TRY(otbn_dmem_write(ARRAYSIZE(cofactor->data), cofactor->data,
                               kOtbnVarRsaCofactor));

  // Set mode and start OTBN.
  uint32_t mode = kOtbnRsaModeCofactor2048;
  HARDENED_TRY(otbn_dmem_write(kOtbnRsaModeWords, &mode, kOtbnVarRsaMode));
  return otbn_execute();
}

status_t rsa_keygen_from_cofactor_2048_finalize(
    rsa_2048_public_key_t *public_key, rsa_2048_private_key_t *private_key) {
  HARDENED_TRY(keygen_finalize(kOtbnRsaModeCofactor2048, kRsa2048NumWords,
                               public_key->n.data, private_key->p.data,
                               private_key->q.data, private_key->d_p.data,
                               private_key->d_q.data, private_key->i_q.data));

  // Set the public exponent to F4, the only exponent our key generation
  // algorithm supports.
  public_key->e = kFixedPublicExponent;

  return OTCRYPTO_OK;
}
