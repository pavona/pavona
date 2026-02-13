// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/testing/acc_testutils_rsa.h"

#include "sw/device/lib/base/status.h"
#include "sw/device/lib/dif/dif_acc.h"
#include "sw/device/lib/testing/acc_testutils.h"

ACC_DECLARE_APP_SYMBOLS(rsa);
ACC_DECLARE_SYMBOL_ADDR(rsa, mode);
ACC_DECLARE_SYMBOL_ADDR(rsa, n_limbs);
ACC_DECLARE_SYMBOL_ADDR(rsa, inout);
ACC_DECLARE_SYMBOL_ADDR(rsa, modulus);
ACC_DECLARE_SYMBOL_ADDR(rsa, exp);

static const acc_app_t kAccAppRsa = ACC_APP_T_INIT(rsa);
static const acc_addr_t kAccVarRsaMode = ACC_ADDR_T_INIT(rsa, mode);
static const acc_addr_t kAccVarRsaNLimbs = ACC_ADDR_T_INIT(rsa, n_limbs);
static const acc_addr_t kAccVarRsaInOut = ACC_ADDR_T_INIT(rsa, inout);
static const acc_addr_t kAccVarRsaModulus = ACC_ADDR_T_INIT(rsa, modulus);
static const acc_addr_t kAccVarRsaExp = ACC_ADDR_T_INIT(rsa, exp);

enum {
  kAccWideWordBytes = 256 / 8,
  kModeEncrypt = 1,
  kModeDecrypt = 2,
};

status_t acc_testutils_rsa_load(dif_acc_t *acc) {
  if (acc == NULL) {
    return INVALID_ARGUMENT();
  }
  return acc_testutils_load_app(acc, kAccAppRsa);
}

status_t acc_testutils_rsa_modexp_f4_start(dif_acc_t *acc,
                                           const uint8_t *modulus,
                                           const uint8_t *in,
                                           size_t size_bytes) {
  if (acc == NULL || size_bytes % kAccWideWordBytes != 0) {
    return INVALID_ARGUMENT();
  }

  uint32_t n_limbs = size_bytes / kAccWideWordBytes;
  if (n_limbs == 0 || n_limbs > 16) {
    return INVALID_ARGUMENT();
  }

  // Write input arguments.
  uint32_t mode = kModeEncrypt;
  TRY(acc_testutils_write_data(acc, sizeof(uint32_t), &mode, kAccVarRsaMode));
  TRY(acc_testutils_write_data(acc, sizeof(uint32_t), &n_limbs,
                               kAccVarRsaNLimbs));
  TRY(acc_testutils_write_data(acc, size_bytes, modulus, kAccVarRsaModulus));
  TRY(acc_testutils_write_data(acc, size_bytes, in, kAccVarRsaInOut));

  // Call ACC to start the operation.
  return acc_testutils_execute(acc);
}

status_t acc_testutils_rsa_modexp_consttime_start(
    dif_acc_t *acc, const uint8_t *modulus, const uint8_t *private_exponent,
    const uint8_t *in, size_t size_bytes) {
  if (acc == NULL || size_bytes % kAccWideWordBytes != 0) {
    return INVALID_ARGUMENT();
  }

  uint32_t n_limbs = size_bytes / kAccWideWordBytes;
  if (n_limbs == 0 || n_limbs > 16) {
    return INVALID_ARGUMENT();
  }

  // Write input arguments.
  uint32_t mode = kModeDecrypt;
  TRY(acc_testutils_write_data(acc, sizeof(mode), &mode, kAccVarRsaMode));
  TRY(acc_testutils_write_data(acc, sizeof(n_limbs), &n_limbs,
                               kAccVarRsaNLimbs));
  TRY(acc_testutils_write_data(acc, size_bytes, modulus, kAccVarRsaModulus));
  TRY(acc_testutils_write_data(acc, size_bytes, private_exponent,
                               kAccVarRsaExp));
  TRY(acc_testutils_write_data(acc, size_bytes, in, kAccVarRsaInOut));

  // Call ACC to start the operation.
  return acc_testutils_execute(acc);
}

static status_t modexp_finalize(dif_acc_t *acc, uint8_t *out,
                                size_t size_bytes) {
  if (acc == NULL || size_bytes % kAccWideWordBytes != 0) {
    return INVALID_ARGUMENT();
  }

  uint32_t n_limbs = size_bytes / kAccWideWordBytes;
  if (n_limbs == 0 || n_limbs > 16) {
    return INVALID_ARGUMENT();
  }

  // Wait for ACC to complete.
  TRY(acc_testutils_wait_for_done(acc, kDifAccErrBitsNoError));

  // Read back results.
  return acc_testutils_read_data(acc, size_bytes, kAccVarRsaInOut, out);
}

status_t acc_testutils_rsa_modexp_f4_finalize(dif_acc_t *acc, uint8_t *out,
                                              size_t size_bytes) {
  return modexp_finalize(acc, out, size_bytes);
}

status_t acc_testutils_rsa_modexp_consttime_finalize(dif_acc_t *acc,
                                                     uint8_t *out,
                                                     size_t size_bytes) {
  return modexp_finalize(acc, out, size_bytes);
}
