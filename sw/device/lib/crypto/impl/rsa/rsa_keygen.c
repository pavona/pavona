// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/crypto/impl/rsa/rsa_keygen.h"

#include "sw/device/lib/base/hardened.h"
#include "sw/device/lib/base/hardened_memory.h"
#include "sw/device/lib/crypto/drivers/otbn.h"
#include "sw/device/lib/crypto/impl/rsa/rsa_datatypes.h"

// Module ID for status codes.
#define MODULE_ID MAKE_MODULE_ID('r', 'k', 'g')

// Declare the OTBN app.
OTBN_DECLARE_APP_SYMBOLS(run_rsa_keygen);
static const otbn_app_t kOtbnAppRsaKeygen = OTBN_APP_T_INIT(run_rsa_keygen);

// Declare offsets for input and output buffers.
OTBN_DECLARE_SYMBOL_ADDR(run_rsa_keygen, mode);   // Application mode.
OTBN_DECLARE_SYMBOL_ADDR(run_rsa_keygen, rsa_n);  // Modulus n.
OTBN_DECLARE_SYMBOL_ADDR(run_rsa_keygen, rsa_p);  // Cofactor p.
OTBN_DECLARE_SYMBOL_ADDR(run_rsa_keygen, rsa_q);  // Cofactor q.
OTBN_DECLARE_SYMBOL_ADDR(run_rsa_keygen,
                         rsa_d_p);  // Private exponent component d_p.
OTBN_DECLARE_SYMBOL_ADDR(run_rsa_keygen,
                         rsa_d_q);  // Private exponent component d_p.
OTBN_DECLARE_SYMBOL_ADDR(run_rsa_keygen, rsa_i_q);       // CRT coefficient i_p.
OTBN_DECLARE_SYMBOL_ADDR(run_rsa_keygen, rsa_cofactor);  // Cofactor p or q.
OTBN_DECLARE_SYMBOL_ADDR(run_rsa_keygen, rsa_e);         // Public exponent e.

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
static const otbn_addr_t kOtbnVarRsaE = OTBN_ADDR_T_INIT(run_rsa_keygen, rsa_e);

// Declare mode constants.
OTBN_DECLARE_SYMBOL_ADDR(run_rsa_keygen, MODE_GEN_RSA_2048);
OTBN_DECLARE_SYMBOL_ADDR(run_rsa_keygen, MODE_COFACTOR_RSA_2048);
OTBN_DECLARE_SYMBOL_ADDR(run_rsa_keygen, MODE_CHECK_RSA_2048);
OTBN_DECLARE_SYMBOL_ADDR(run_rsa_keygen, MODE_CHECK_WITH_PRIMES_RSA_2048);
OTBN_DECLARE_SYMBOL_ADDR(run_rsa_keygen, MODE_GEN_RSA_3072);
OTBN_DECLARE_SYMBOL_ADDR(run_rsa_keygen, MODE_COFACTOR_RSA_3072);
OTBN_DECLARE_SYMBOL_ADDR(run_rsa_keygen, MODE_CHECK_RSA_3072);
OTBN_DECLARE_SYMBOL_ADDR(run_rsa_keygen, MODE_CHECK_WITH_PRIMES_RSA_3072);
OTBN_DECLARE_SYMBOL_ADDR(run_rsa_keygen, MODE_GEN_RSA_4096);
OTBN_DECLARE_SYMBOL_ADDR(run_rsa_keygen, MODE_COFACTOR_RSA_4096);
OTBN_DECLARE_SYMBOL_ADDR(run_rsa_keygen, MODE_CHECK_RSA_4096);
OTBN_DECLARE_SYMBOL_ADDR(run_rsa_keygen, MODE_CHECK_WITH_PRIMES_RSA_4096);
static const uint32_t kOtbnRsaModeGen2048 =
    OTBN_ADDR_T_INIT(run_rsa_keygen, MODE_GEN_RSA_2048);
static const uint32_t kOtbnRsaModeCofactor2048 =
    OTBN_ADDR_T_INIT(run_rsa_keygen, MODE_COFACTOR_RSA_2048);
static const uint32_t kOtbnRsaModeCheck2048 =
    OTBN_ADDR_T_INIT(run_rsa_keygen, MODE_CHECK_RSA_2048);
static const uint32_t kOtbnRsaModeCheckWithPrimes2048 =
    OTBN_ADDR_T_INIT(run_rsa_keygen, MODE_CHECK_WITH_PRIMES_RSA_2048);
static const uint32_t kOtbnRsaModeGen3072 =
    OTBN_ADDR_T_INIT(run_rsa_keygen, MODE_GEN_RSA_3072);
static const uint32_t kOtbnRsaModeCofactor3072 =
    OTBN_ADDR_T_INIT(run_rsa_keygen, MODE_COFACTOR_RSA_3072);
static const uint32_t kOtbnRsaModeCheck3072 =
    OTBN_ADDR_T_INIT(run_rsa_keygen, MODE_CHECK_RSA_3072);
static const uint32_t kOtbnRsaModeCheckWithPrimes3072 =
    OTBN_ADDR_T_INIT(run_rsa_keygen, MODE_CHECK_WITH_PRIMES_RSA_3072);
static const uint32_t kOtbnRsaModeGen4096 =
    OTBN_ADDR_T_INIT(run_rsa_keygen, MODE_GEN_RSA_4096);
static const uint32_t kOtbnRsaModeCofactor4096 =
    OTBN_ADDR_T_INIT(run_rsa_keygen, MODE_COFACTOR_RSA_4096);
static const uint32_t kOtbnRsaModeCheck4096 =
    OTBN_ADDR_T_INIT(run_rsa_keygen, MODE_CHECK_RSA_4096);
static const uint32_t kOtbnRsaModeCheckWithPrimes4096 =
    OTBN_ADDR_T_INIT(run_rsa_keygen, MODE_CHECK_WITH_PRIMES_RSA_4096);

enum {
  /* Fixed public exponent for generated keys. This exponent is 2^16 + 1, also
     known as "F4" because it's the fourth Fermat number. */
  kFixedPublicExponent = 65537,
  /* Number of words used to represent the application mode. */
  kOtbnRsaModeWords = 1,
  /* Number of bits for the private exponent (d) check value for key import. */
  kPrivateExponentCheckBits = 256,
  /* Number of bytes for the private exponent (d) check value for key import. */
  kPrivateExponentCheckBytes = kPrivateExponentCheckBits / 8,
  /* Number of words for the private exponent (d) check value for key import. */
  kPrivateExponentCheckWords = kPrivateExponentCheckBytes / sizeof(uint32_t),
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
  // Return `OTCRYTPO_ASYNC_INCOMPLETE` if OTBN not done.
  HARDENED_TRY(otbn_assert_idle());

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

status_t rsa_keygen_from_cofactor_3072_start(
    const rsa_3072_public_key_t *public_key, const rsa_3072_short_t *cofactor) {
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
  uint32_t mode = kOtbnRsaModeCofactor3072;
  HARDENED_TRY(otbn_dmem_write(kOtbnRsaModeWords, &mode, kOtbnVarRsaMode));
  return otbn_execute();
}

status_t rsa_keygen_from_cofactor_3072_finalize(
    rsa_3072_public_key_t *public_key, rsa_3072_private_key_t *private_key) {
  HARDENED_TRY(keygen_finalize(kOtbnRsaModeCofactor3072, kRsa3072NumWords,
                               public_key->n.data, private_key->p.data,
                               private_key->q.data, private_key->d_p.data,
                               private_key->d_q.data, private_key->i_q.data));

  // Set the public exponent to F4, the only exponent our key generation
  // algorithm supports.
  public_key->e = kFixedPublicExponent;

  return OTCRYPTO_OK;
}

status_t rsa_keygen_from_cofactor_4096_start(
    const rsa_4096_public_key_t *public_key, const rsa_4096_short_t *cofactor) {
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
  uint32_t mode = kOtbnRsaModeCofactor4096;
  HARDENED_TRY(otbn_dmem_write(kOtbnRsaModeWords, &mode, kOtbnVarRsaMode));
  return otbn_execute();
}

status_t rsa_keygen_from_cofactor_4096_finalize(
    rsa_4096_public_key_t *public_key, rsa_4096_private_key_t *private_key) {
  HARDENED_TRY(keygen_finalize(kOtbnRsaModeCofactor4096, kRsa4096NumWords,
                               public_key->n.data, private_key->p.data,
                               private_key->q.data, private_key->d_p.data,
                               private_key->d_q.data, private_key->i_q.data));

  // Set the public exponent to F4, the only exponent our key generation
  // algorithm supports.
  public_key->e = kFixedPublicExponent;

  return OTCRYPTO_OK;
}

status_t rsa_key_check_2048_start(const rsa_2048_public_key_t *public_key,
                                  const rsa_2048_private_key_t *private_key,
                                  hardened_bool_t check_primes) {
  // Load the RSA key generation app. Fails if OTBN is non-idle.
  HARDENED_TRY(otbn_load_app(kOtbnAppRsaKeygen));

  // Write the public exponent into DMEM, zero-extended to a full processor
  // word.
  HARDENED_TRY(otbn_dmem_write(1, &public_key->e, kOtbnVarRsaE));

  // Write the primes, CRT components of the private exponent, and CRT
  // coefficient into DMEM.
  HARDENED_TRY(otbn_dmem_write(ARRAYSIZE(private_key->p.data),
                               private_key->p.data, kOtbnVarRsaP));
  HARDENED_TRY(otbn_dmem_write(ARRAYSIZE(private_key->q.data),
                               private_key->q.data, kOtbnVarRsaQ));
  HARDENED_TRY(otbn_dmem_write(ARRAYSIZE(private_key->d_p.data),
                               private_key->d_p.data, kOtbnVarRsaDp));
  HARDENED_TRY(otbn_dmem_write(ARRAYSIZE(private_key->d_q.data),
                               private_key->d_q.data, kOtbnVarRsaDq));
  HARDENED_TRY(otbn_dmem_write(ARRAYSIZE(private_key->i_q.data),
                               private_key->i_q.data, kOtbnVarRsaIq));

  // Select mode based on whether we should perform primality checks.
  uint32_t mode;
  if (launder32(check_primes) == kHardenedBoolTrue) {
    HARDENED_CHECK_EQ(check_primes, kHardenedBoolTrue);
    mode = kOtbnRsaModeCheckWithPrimes2048;
  } else {
    HARDENED_CHECK_EQ(check_primes, kHardenedBoolFalse);
    mode = kOtbnRsaModeCheck2048;
  }

  // Set mode and start OTBN.
  HARDENED_TRY(otbn_dmem_write(kOtbnRsaModeWords, &mode, kOtbnVarRsaMode));
  return otbn_execute();
}

status_t rsa_key_check_2048_finalize(const rsa_2048_public_key_t *public_key,
                                     const rsa_2048_private_key_t *private_key,
                                     hardened_bool_t check_primes,
                                     hardened_bool_t *key_valid) {
  // Spin here waiting for OTBN to complete.
  OTBN_WIPE_IF_ERROR(otbn_busy_wait_for_done());

  // Read the mode from OTBN dmem and panic if it's not as expected.
  uint32_t act_mode = 0;
  OTBN_WIPE_IF_ERROR(otbn_dmem_read(1, kOtbnVarRsaMode, &act_mode));

  // Get the expected mode from provided arguments.
  uint32_t exp_mode = 0;
  if (launder32(check_primes) == kHardenedBoolTrue) {
    HARDENED_CHECK_EQ(check_primes, kHardenedBoolTrue);
    exp_mode = kOtbnRsaModeCheckWithPrimes2048;
  } else {
    HARDENED_CHECK_EQ(check_primes, kHardenedBoolFalse);
    exp_mode = kOtbnRsaModeCheck2048;
  }

  // Ensure that the actual mode is the same as the expected mode.
  if (launder32(act_mode) != exp_mode) {
    return OTCRYPTO_FATAL_ERR;
  }
  HARDENED_CHECK_EQ(act_mode, exp_mode);

  // Prepare a multi-limb constant of 1 for comparing to in validity checks.
  uint32_t one[kRsa2048NumWords / 2];
  memset(&one, 0, sizeof(one));
  one[0] = 1;

  // Read the value of the first CRT component (d_p) validity check value from
  // OTBN dmem.
  uint32_t dp_check[kRsa2048NumWords / 2];
  OTBN_WIPE_IF_ERROR(
      otbn_dmem_read(kRsa2048NumWords / 2, kOtbnVarRsaDp, dp_check));

  // Check that this matches the expected value of 1, and update the validity.
  hardened_bool_t dp_valid = hardened_memeq(one, dp_check, ARRAYSIZE(dp_check));

  // Read the value of the second CRT component (d_q) validity check value
  // from OTBN dmem.
  uint32_t dq_check[kRsa2048NumWords / 2];
  OTBN_WIPE_IF_ERROR(
      otbn_dmem_read(kRsa2048NumWords / 2, kOtbnVarRsaDq, dq_check));

  // Check that this matches the expected value of 1, and update the validity.
  hardened_bool_t dq_valid = hardened_memeq(one, dq_check, ARRAYSIZE(dq_check));

  // Read the value of the CRT coefficient (i_q) validity check value
  // from OTBN dmem.
  uint32_t iq_check[kRsa2048NumWords / 2];
  OTBN_WIPE_IF_ERROR(
      otbn_dmem_read(kRsa2048NumWords / 2, kOtbnVarRsaIq, iq_check));

  // Check that this matches the expected value of 1, and update the validity.
  hardened_bool_t iq_valid = hardened_memeq(one, iq_check, ARRAYSIZE(iq_check));

  // Read the recovered public modulus (n) from OTBN dmem.
  uint32_t recovered_n[kRsa2048NumWords];
  OTBN_WIPE_IF_ERROR(
      otbn_dmem_read(kRsa2048NumWords, kOtbnVarRsaN, recovered_n));

  // Check that this matches the public key modulus, and update the validity.
  hardened_bool_t n_valid =
      hardened_memeq(public_key->n.data, recovered_n, ARRAYSIZE(recovered_n));

  // Read the private exponent (d) check value
  uint32_t d_check[kPrivateExponentCheckWords];
  OTBN_WIPE_IF_ERROR(
      otbn_dmem_read(kPrivateExponentCheckWords, kOtbnVarRsaE, d_check));

  // Prepare a multi-limb all ones constant for comparing to in validity checks.
  uint32_t all_ones[kPrivateExponentCheckWords];
  memset(&all_ones, 0xFF, sizeof(all_ones));

  // Check whether the private exponent check value this is all ones.
  hardened_bool_t d_valid =
      hardened_memeq(all_ones, d_check, ARRAYSIZE(d_check));

  if (launder32(check_primes) == kHardenedBoolTrue) {
    // Read the first prime (p) check value
    uint32_t p_check[kRsa2048NumWords / 2];
    OTBN_WIPE_IF_ERROR(
        otbn_dmem_read(kRsa2048NumWords / 2, kOtbnVarRsaE, p_check));

    // Check whether the first prime check value is all ones.
    hardened_bool_t p_valid =
        hardened_memeq(all_ones, p_check, ARRAYSIZE(p_check));

    // Read the second prime (q) check value
    uint32_t q_check[kRsa2048NumWords / 2];
    OTBN_WIPE_IF_ERROR(
        otbn_dmem_read(kRsa2048NumWords / 2, kOtbnVarRsaE, q_check));

    // Check whether the first prime check value is all ones.
    hardened_bool_t q_valid =
        hardened_memeq(all_ones, p_check, ARRAYSIZE(q_check));

    // Check if all tests passed, and write the output accordingly.
    if ((dp_valid & dq_valid & iq_valid & n_valid & d_valid & p_valid &
         q_valid) == kHardenedBoolTrue) {
      HARDENED_CHECK_EQ(dp_valid, kHardenedBoolTrue);
      HARDENED_CHECK_EQ(dq_valid, kHardenedBoolTrue);
      HARDENED_CHECK_EQ(iq_valid, kHardenedBoolTrue);
      HARDENED_CHECK_EQ(n_valid, kHardenedBoolTrue);
      HARDENED_CHECK_EQ(d_valid, kHardenedBoolTrue);
      HARDENED_CHECK_EQ(p_valid, kHardenedBoolTrue);
      HARDENED_CHECK_EQ(q_valid, kHardenedBoolTrue);
      *key_valid = kHardenedBoolTrue;
    } else {
      *key_valid = kHardenedBoolFalse;
    }
  } else {
    // Ensure that the check primes flag wasn't set.
    HARDENED_CHECK_EQ(check_primes, kHardenedBoolFalse);

    // Check if all tests passed, and write the output accordingly.
    if ((dp_valid & dq_valid & iq_valid & n_valid & d_valid) ==
        kHardenedBoolTrue) {
      HARDENED_CHECK_EQ(dp_valid, kHardenedBoolTrue);
      HARDENED_CHECK_EQ(dq_valid, kHardenedBoolTrue);
      HARDENED_CHECK_EQ(iq_valid, kHardenedBoolTrue);
      HARDENED_CHECK_EQ(n_valid, kHardenedBoolTrue);
      HARDENED_CHECK_EQ(d_valid, kHardenedBoolTrue);
      *key_valid = kHardenedBoolTrue;
    } else {
      *key_valid = kHardenedBoolFalse;
    }
  }

  // Wipe DMEM.
  return otbn_dmem_sec_wipe();
}

status_t rsa_key_check_3072_start(const rsa_3072_public_key_t *public_key,
                                  const rsa_3072_private_key_t *private_key,
                                  hardened_bool_t check_primes) {
  // Load the RSA key generation app. Fails if OTBN is non-idle.
  HARDENED_TRY(otbn_load_app(kOtbnAppRsaKeygen));

  // Write the public exponent into DMEM, zero-extended to a full processor
  // word.
  HARDENED_TRY(otbn_dmem_write(1, &public_key->e, kOtbnVarRsaE));

  // Write the primes, CRT components of the private exponent, and CRT
  // coefficient into DMEM.
  HARDENED_TRY(otbn_dmem_write(ARRAYSIZE(private_key->p.data),
                               private_key->p.data, kOtbnVarRsaP));
  HARDENED_TRY(otbn_dmem_write(ARRAYSIZE(private_key->q.data),
                               private_key->q.data, kOtbnVarRsaQ));
  HARDENED_TRY(otbn_dmem_write(ARRAYSIZE(private_key->d_p.data),
                               private_key->d_p.data, kOtbnVarRsaDp));
  HARDENED_TRY(otbn_dmem_write(ARRAYSIZE(private_key->d_q.data),
                               private_key->d_q.data, kOtbnVarRsaDq));
  HARDENED_TRY(otbn_dmem_write(ARRAYSIZE(private_key->i_q.data),
                               private_key->i_q.data, kOtbnVarRsaIq));

  // Select mode based on whether we should perform primality checks.
  uint32_t mode;
  if (launder32(check_primes) == kHardenedBoolTrue) {
    HARDENED_CHECK_EQ(check_primes, kHardenedBoolTrue);
    mode = kOtbnRsaModeCheckWithPrimes3072;
  } else {
    HARDENED_CHECK_EQ(check_primes, kHardenedBoolFalse);
    mode = kOtbnRsaModeCheck3072;
  }

  // Set mode and start OTBN.
  HARDENED_TRY(otbn_dmem_write(kOtbnRsaModeWords, &mode, kOtbnVarRsaMode));
  return otbn_execute();
}

status_t rsa_key_check_3072_finalize(const rsa_3072_public_key_t *public_key,
                                     const rsa_3072_private_key_t *private_key,
                                     hardened_bool_t check_primes,
                                     hardened_bool_t *key_valid) {
  // Spin here waiting for OTBN to complete.
  OTBN_WIPE_IF_ERROR(otbn_busy_wait_for_done());

  // Read the mode from OTBN dmem and panic if it's not as expected.
  uint32_t act_mode = 0;
  OTBN_WIPE_IF_ERROR(otbn_dmem_read(1, kOtbnVarRsaMode, &act_mode));

  // Get the expected mode from provided arguments.
  uint32_t exp_mode = 0;
  if (launder32(check_primes) == kHardenedBoolTrue) {
    HARDENED_CHECK_EQ(check_primes, kHardenedBoolTrue);
    exp_mode = kOtbnRsaModeCheckWithPrimes3072;
  } else {
    HARDENED_CHECK_EQ(check_primes, kHardenedBoolFalse);
    exp_mode = kOtbnRsaModeCheck3072;
  }

  // Ensure that the actual mode is the same as the expected mode.
  if (launder32(act_mode) != exp_mode) {
    return OTCRYPTO_FATAL_ERR;
  }
  HARDENED_CHECK_EQ(act_mode, exp_mode);

  // Prepare a multi-limb constant of 1 for comparing to in validity checks.
  uint32_t one[kRsa3072NumWords / 2];
  memset(&one, 0, sizeof(one));
  one[0] = 1;

  // Read the value of the first CRT component (d_p) validity check value from
  // OTBN dmem.
  uint32_t dp_check[kRsa3072NumWords / 2];
  OTBN_WIPE_IF_ERROR(
      otbn_dmem_read(kRsa3072NumWords / 2, kOtbnVarRsaDp, dp_check));

  // Check that this matches the expected value of 1, and update the validity.
  hardened_bool_t dp_valid = hardened_memeq(one, dp_check, ARRAYSIZE(dp_check));

  // Read the value of the second CRT component (d_q) validity check value
  // from OTBN dmem.
  uint32_t dq_check[kRsa3072NumWords / 2];
  OTBN_WIPE_IF_ERROR(
      otbn_dmem_read(kRsa3072NumWords / 2, kOtbnVarRsaDq, dq_check));

  // Check that this matches the expected value of 1, and update the validity.
  hardened_bool_t dq_valid = hardened_memeq(one, dq_check, ARRAYSIZE(dq_check));

  // Read the value of the CRT coefficient (i_q) validity check value
  // from OTBN dmem.
  uint32_t iq_check[kRsa3072NumWords / 2];
  OTBN_WIPE_IF_ERROR(
      otbn_dmem_read(kRsa3072NumWords / 2, kOtbnVarRsaIq, iq_check));

  // Check that this matches the expected value of 1, and update the validity.
  hardened_bool_t iq_valid = hardened_memeq(one, iq_check, ARRAYSIZE(iq_check));

  // Read the recovered public modulus (n) from OTBN dmem.
  uint32_t recovered_n[kRsa3072NumWords];
  OTBN_WIPE_IF_ERROR(
      otbn_dmem_read(kRsa3072NumWords, kOtbnVarRsaN, recovered_n));

  // Check that this matches the public key modulus, and update the validity.
  hardened_bool_t n_valid =
      hardened_memeq(public_key->n.data, recovered_n, ARRAYSIZE(recovered_n));

  // Read the private exponent (d) check value
  uint32_t d_check[kPrivateExponentCheckWords];
  OTBN_WIPE_IF_ERROR(
      otbn_dmem_read(kPrivateExponentCheckWords, kOtbnVarRsaE, d_check));

  // Prepare a multi-limb all ones constant for comparing to in validity checks.
  uint32_t all_ones[kPrivateExponentCheckWords];
  memset(&all_ones, 0xFF, sizeof(all_ones));

  // Check whether the private exponent check value this is all ones.
  hardened_bool_t d_valid =
      hardened_memeq(all_ones, d_check, ARRAYSIZE(d_check));

  if (launder32(check_primes) == kHardenedBoolTrue) {
    // Read the first prime (p) check value
    uint32_t p_check[kRsa3072NumWords / 2];
    OTBN_WIPE_IF_ERROR(
        otbn_dmem_read(kRsa3072NumWords / 2, kOtbnVarRsaE, p_check));

    // Check whether the first prime check value is all ones.
    hardened_bool_t p_valid =
        hardened_memeq(all_ones, p_check, ARRAYSIZE(p_check));

    // Read the second prime (q) check value
    uint32_t q_check[kRsa3072NumWords / 2];
    OTBN_WIPE_IF_ERROR(
        otbn_dmem_read(kRsa3072NumWords / 2, kOtbnVarRsaE, q_check));

    // Check whether the first prime check value is all ones.
    hardened_bool_t q_valid =
        hardened_memeq(all_ones, p_check, ARRAYSIZE(q_check));

    // Check if all tests passed, and write the output accordingly.
    if ((dp_valid & dq_valid & iq_valid & n_valid & d_valid & p_valid &
         q_valid) == kHardenedBoolTrue) {
      HARDENED_CHECK_EQ(dp_valid, kHardenedBoolTrue);
      HARDENED_CHECK_EQ(dq_valid, kHardenedBoolTrue);
      HARDENED_CHECK_EQ(iq_valid, kHardenedBoolTrue);
      HARDENED_CHECK_EQ(n_valid, kHardenedBoolTrue);
      HARDENED_CHECK_EQ(d_valid, kHardenedBoolTrue);
      HARDENED_CHECK_EQ(p_valid, kHardenedBoolTrue);
      HARDENED_CHECK_EQ(q_valid, kHardenedBoolTrue);
      *key_valid = kHardenedBoolTrue;
    } else {
      *key_valid = kHardenedBoolFalse;
    }
  } else {
    // Ensure that the check primes flag wasn't set.
    HARDENED_CHECK_EQ(check_primes, kHardenedBoolFalse);

    // Check if all tests passed, and write the output accordingly.
    if ((dp_valid & dq_valid & iq_valid & n_valid & d_valid) ==
        kHardenedBoolTrue) {
      HARDENED_CHECK_EQ(dp_valid, kHardenedBoolTrue);
      HARDENED_CHECK_EQ(dq_valid, kHardenedBoolTrue);
      HARDENED_CHECK_EQ(iq_valid, kHardenedBoolTrue);
      HARDENED_CHECK_EQ(n_valid, kHardenedBoolTrue);
      HARDENED_CHECK_EQ(d_valid, kHardenedBoolTrue);
      *key_valid = kHardenedBoolTrue;
    } else {
      *key_valid = kHardenedBoolFalse;
    }
  }

  // Wipe DMEM.
  return otbn_dmem_sec_wipe();
}

status_t rsa_key_check_4096_start(const rsa_4096_public_key_t *public_key,
                                  const rsa_4096_private_key_t *private_key,
                                  hardened_bool_t check_primes) {
  // Load the RSA key generation app. Fails if OTBN is non-idle.
  HARDENED_TRY(otbn_load_app(kOtbnAppRsaKeygen));

  // Write the public exponent into DMEM, zero-extended to a full processor
  // word.
  HARDENED_TRY(otbn_dmem_write(1, &public_key->e, kOtbnVarRsaE));

  // Write the primes, CRT components of the private exponent, and CRT
  // coefficient into DMEM.
  HARDENED_TRY(otbn_dmem_write(ARRAYSIZE(private_key->p.data),
                               private_key->p.data, kOtbnVarRsaP));
  HARDENED_TRY(otbn_dmem_write(ARRAYSIZE(private_key->q.data),
                               private_key->q.data, kOtbnVarRsaQ));
  HARDENED_TRY(otbn_dmem_write(ARRAYSIZE(private_key->d_p.data),
                               private_key->d_p.data, kOtbnVarRsaDp));
  HARDENED_TRY(otbn_dmem_write(ARRAYSIZE(private_key->d_q.data),
                               private_key->d_q.data, kOtbnVarRsaDq));
  HARDENED_TRY(otbn_dmem_write(ARRAYSIZE(private_key->i_q.data),
                               private_key->i_q.data, kOtbnVarRsaIq));

  // Select mode based on whether we should perform primality checks.
  uint32_t mode;
  if (launder32(check_primes) == kHardenedBoolTrue) {
    HARDENED_CHECK_EQ(check_primes, kHardenedBoolTrue);
    mode = kOtbnRsaModeCheckWithPrimes4096;
  } else {
    HARDENED_CHECK_EQ(check_primes, kHardenedBoolFalse);
    mode = kOtbnRsaModeCheck4096;
  }

  // Set mode and start OTBN.
  HARDENED_TRY(otbn_dmem_write(kOtbnRsaModeWords, &mode, kOtbnVarRsaMode));
  return otbn_execute();
}

status_t rsa_key_check_4096_finalize(const rsa_4096_public_key_t *public_key,
                                     const rsa_4096_private_key_t *private_key,
                                     hardened_bool_t check_primes,
                                     hardened_bool_t *key_valid) {
  // Spin here waiting for OTBN to complete.
  OTBN_WIPE_IF_ERROR(otbn_busy_wait_for_done());

  // Read the mode from OTBN dmem and panic if it's not as expected.
  uint32_t act_mode = 0;
  OTBN_WIPE_IF_ERROR(otbn_dmem_read(1, kOtbnVarRsaMode, &act_mode));

  // Get the expected mode from provided arguments.
  uint32_t exp_mode = 0;
  if (launder32(check_primes) == kHardenedBoolTrue) {
    HARDENED_CHECK_EQ(check_primes, kHardenedBoolTrue);
    exp_mode = kOtbnRsaModeCheckWithPrimes4096;
  } else {
    HARDENED_CHECK_EQ(check_primes, kHardenedBoolFalse);
    exp_mode = kOtbnRsaModeCheck4096;
  }

  // Ensure that the actual mode is the same as the expected mode.
  if (launder32(act_mode) != exp_mode) {
    return OTCRYPTO_FATAL_ERR;
  }
  HARDENED_CHECK_EQ(act_mode, exp_mode);

  // Prepare a multi-limb constant of 1 for comparing to in validity checks.
  uint32_t one[kRsa4096NumWords / 2];
  memset(&one, 0, sizeof(one));
  one[0] = 1;

  // Read the value of the first CRT component (d_p) validity check value from
  // OTBN dmem.
  uint32_t dp_check[kRsa4096NumWords / 2];
  OTBN_WIPE_IF_ERROR(
      otbn_dmem_read(kRsa4096NumWords / 2, kOtbnVarRsaDp, dp_check));

  // Check that this matches the expected value of 1, and update the validity.
  hardened_bool_t dp_valid = hardened_memeq(one, dp_check, ARRAYSIZE(dp_check));

  // Read the value of the second CRT component (d_q) validity check value
  // from OTBN dmem.
  uint32_t dq_check[kRsa4096NumWords / 2];
  OTBN_WIPE_IF_ERROR(
      otbn_dmem_read(kRsa4096NumWords / 2, kOtbnVarRsaDq, dq_check));

  // Check that this matches the expected value of 1, and update the validity.
  hardened_bool_t dq_valid = hardened_memeq(one, dq_check, ARRAYSIZE(dq_check));

  // Read the value of the CRT coefficient (i_q) validity check value
  // from OTBN dmem.
  uint32_t iq_check[kRsa4096NumWords / 2];
  OTBN_WIPE_IF_ERROR(
      otbn_dmem_read(kRsa4096NumWords / 2, kOtbnVarRsaIq, iq_check));

  // Check that this matches the expected value of 1, and update the validity.
  hardened_bool_t iq_valid = hardened_memeq(one, iq_check, ARRAYSIZE(iq_check));

  // Read the recovered public modulus (n) from OTBN dmem.
  uint32_t recovered_n[kRsa4096NumWords];
  OTBN_WIPE_IF_ERROR(
      otbn_dmem_read(kRsa4096NumWords, kOtbnVarRsaN, recovered_n));

  // Check that this matches the public key modulus, and update the validity.
  hardened_bool_t n_valid =
      hardened_memeq(public_key->n.data, recovered_n, ARRAYSIZE(recovered_n));

  // Read the private exponent (d) check value
  uint32_t d_check[kPrivateExponentCheckWords];
  OTBN_WIPE_IF_ERROR(
      otbn_dmem_read(kPrivateExponentCheckWords, kOtbnVarRsaE, d_check));

  // Prepare a multi-limb all ones constant for comparing to in validity checks.
  uint32_t all_ones[kPrivateExponentCheckWords];
  memset(&all_ones, 0xFF, sizeof(all_ones));

  // Check whether the private exponent check value this is all ones.
  hardened_bool_t d_valid =
      hardened_memeq(all_ones, d_check, ARRAYSIZE(d_check));

  if (launder32(check_primes) == kHardenedBoolTrue) {
    // Read the first prime (p) check value
    uint32_t p_check[kRsa4096NumWords / 2];
    OTBN_WIPE_IF_ERROR(
        otbn_dmem_read(kRsa4096NumWords / 2, kOtbnVarRsaE, p_check));

    // Check whether the first prime check value is all ones.
    hardened_bool_t p_valid =
        hardened_memeq(all_ones, p_check, ARRAYSIZE(p_check));

    // Read the second prime (q) check value
    uint32_t q_check[kRsa4096NumWords / 2];
    OTBN_WIPE_IF_ERROR(
        otbn_dmem_read(kRsa4096NumWords / 2, kOtbnVarRsaE, q_check));

    // Check whether the first prime check value is all ones.
    hardened_bool_t q_valid =
        hardened_memeq(all_ones, p_check, ARRAYSIZE(q_check));

    // Check if all tests passed, and write the output accordingly.
    if ((dp_valid & dq_valid & iq_valid & n_valid & d_valid & p_valid &
         q_valid) == kHardenedBoolTrue) {
      HARDENED_CHECK_EQ(dp_valid, kHardenedBoolTrue);
      HARDENED_CHECK_EQ(dq_valid, kHardenedBoolTrue);
      HARDENED_CHECK_EQ(iq_valid, kHardenedBoolTrue);
      HARDENED_CHECK_EQ(n_valid, kHardenedBoolTrue);
      HARDENED_CHECK_EQ(d_valid, kHardenedBoolTrue);
      HARDENED_CHECK_EQ(p_valid, kHardenedBoolTrue);
      HARDENED_CHECK_EQ(q_valid, kHardenedBoolTrue);
      *key_valid = kHardenedBoolTrue;
    } else {
      *key_valid = kHardenedBoolFalse;
    }
  } else {
    // Ensure that the check primes flag wasn't set.
    HARDENED_CHECK_EQ(check_primes, kHardenedBoolFalse);

    // Check if all tests passed, and write the output accordingly.
    if ((dp_valid & dq_valid & iq_valid & n_valid & d_valid) ==
        kHardenedBoolTrue) {
      HARDENED_CHECK_EQ(dp_valid, kHardenedBoolTrue);
      HARDENED_CHECK_EQ(dq_valid, kHardenedBoolTrue);
      HARDENED_CHECK_EQ(iq_valid, kHardenedBoolTrue);
      HARDENED_CHECK_EQ(n_valid, kHardenedBoolTrue);
      HARDENED_CHECK_EQ(d_valid, kHardenedBoolTrue);
      *key_valid = kHardenedBoolTrue;
    } else {
      *key_valid = kHardenedBoolFalse;
    }
  }

  // Wipe DMEM.
  return otbn_dmem_sec_wipe();
}
