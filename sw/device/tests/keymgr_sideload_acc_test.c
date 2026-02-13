// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include <stdbool.h>
#include <stdint.h>

#include "sw/device/lib/arch/device.h"
#include "sw/device/lib/base/macros.h"
#include "sw/device/lib/dif/dif_keymgr.h"
#include "sw/device/lib/dif/dif_acc.h"
#include "sw/device/lib/runtime/hart.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/runtime/print.h"
#include "sw/device/lib/testing/entropy_testutils.h"
#include "sw/device/lib/testing/keymgr_testutils.h"
#include "sw/device/lib/testing/acc_testutils.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"

#include "hw/top/acc_regs.h"  // Generated.
#include "hw/top_earlgrey/sw/autogen/top_earlgrey.h"

static dif_keymgr_t keymgr;
static dif_kmac_t kmac;
static dif_acc_t acc;

/* Set up pointers to symbols in the ACC application. */
ACC_DECLARE_APP_SYMBOLS(x25519_sideload);
ACC_DECLARE_SYMBOL_ADDR(x25519_sideload, enc_u);
ACC_DECLARE_SYMBOL_ADDR(x25519_sideload, enc_result);
static const acc_app_t kAccAppX25519 = ACC_APP_T_INIT(x25519_sideload);
static const acc_addr_t kAccVarEncU =
    ACC_ADDR_T_INIT(x25519_sideload, enc_u);
static const acc_addr_t kAccVarEncResult =
    ACC_ADDR_T_INIT(x25519_sideload, enc_result);

OTTF_DEFINE_TEST_CONFIG();

/**
 * Initializes all DIF handles for each peripheral used in this test.
 */
static void init_peripheral_handles(void) {
  CHECK_DIF_OK(
      dif_kmac_init(mmio_region_from_addr(TOP_EARLGREY_KMAC_BASE_ADDR), &kmac));
  CHECK_DIF_OK(dif_keymgr_init(
      mmio_region_from_addr(TOP_EARLGREY_KEYMGR_BASE_ADDR), &keymgr));
  CHECK_DIF_OK(
      dif_acc_init(mmio_region_from_addr(TOP_EARLGREY_ACC_BASE_ADDR), &acc));
}

/**
 * Encoded Montgomery u-coordinate for testing.
 *
 * This value (9) is actually the u-coordinate of the Curve25519 base point, so
 * the X25519 function will effectively compute the public key. This is the
 * first step in key exchange (see RFC 7748, section 6.1).
 */
static const uint32_t kEncodedU[8] = {
    0x9, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
};
static const dif_acc_err_bits_t kAccInvalidKeyErr =
    0x1 << ACC_ERR_BITS_KEY_INVALID_BIT;
static const dif_acc_err_bits_t kErrBitsOk = 0x0;

/**
 * Runs the ACC X25519 application.
 *
 * The X25519 app and sideloaded key should already be loaded into ACC before
 * this routine is called. Causes CHECK-fail if the ACC error code is not as
 * expected.
 *
 * @param acc ACC context object
 * @param[out] result Resulting Montgomery u-coordinate.
 * @param expect_err_bits Error code expected from ACC ERR register.
 * an unexpected error.
 */
static void run_x25519_app(dif_acc_t *acc, uint32_t *result,
                           dif_acc_err_bits_t expect_err_bits) {
  CHECK_DIF_OK(dif_acc_set_ctrl_software_errs_fatal(acc, /*enable=*/false));

  // Copy the input argument (Montgomery u-coordinate).
  CHECK_STATUS_OK(acc_testutils_write_data(acc, sizeof(kEncodedU), &kEncodedU,
                                            kAccVarEncU));

  // Run the ACC program and wait for it to complete. Clear software
  // error fatal flag as the test expects an intermediate error state.
  LOG_INFO("Starting ACC program...");
  CHECK_DIF_OK(dif_acc_set_ctrl_software_errs_fatal(acc, false));
  CHECK_STATUS_OK(acc_testutils_execute(acc));
  CHECK_STATUS_OK(acc_testutils_wait_for_done(acc, expect_err_bits));

  // Copy the result (also a 256-bit Montgomery u-coordinate).
  CHECK_STATUS_OK(
      acc_testutils_read_data(acc, 32, kAccVarEncResult, result));
}

/**
 * Run an ACC program using a sideloaded key.
 * This routine does not check the correctness of results, merely sideloads the
 * key from keymgr to ACC and then runs the X25519 program.
 */
static void test_acc_with_sideloaded_key(dif_keymgr_t *keymgr,
                                          dif_acc_t *acc) {
  // Generate the sideloaded key.
  // TODO(weicai): also check in SV sequence that the key is correct.
  dif_keymgr_versioned_key_params_t sideload_params = kKeyVersionedParams;
  sideload_params.dest = kDifKeymgrVersionedKeyDestAcc;

  // Get the maximum key version supported by the keymgr in its current state.
  uint32_t max_key_version;
  CHECK_STATUS_OK(
      keymgr_testutils_max_key_version_get(keymgr, &max_key_version));

  if (sideload_params.version > max_key_version) {
    LOG_INFO("Key version %d is greater than the maximum key version %d",
             sideload_params.version, max_key_version);
    LOG_INFO("Setting key version to the maximum key version %d",
             max_key_version);
    sideload_params.version = max_key_version;
  }

  CHECK_STATUS_OK(
      keymgr_testutils_generate_versioned_key(keymgr, sideload_params));
  LOG_INFO("Keymgr generated HW output for ACC.");

  // Load the X25519 application.
  CHECK_STATUS_OK(acc_testutils_load_app(acc, kAccAppX25519));
  // Run the ACC app and retrieve the result.
  uint32_t result[8];
  run_x25519_app(acc, result, kErrBitsOk);

#ifdef TEST_SIMPLE_CASE_ONLY
  return;
#endif

  // Clear the sideload key and check that ACC errors with the correct error
  // code (`KEY_INVALID` bit 5 = 1).
  CHECK_DIF_OK(
      dif_keymgr_sideload_clear_set_enabled(keymgr, kDifToggleEnabled));
  LOG_INFO("Clearing the Keymgr generated sideload keys.");
  uint32_t at_clear_salt_result[8];
  run_x25519_app(acc, at_clear_salt_result, kAccInvalidKeyErr);

  // Disable sideload key clearing.
  CHECK_DIF_OK(
      dif_keymgr_sideload_clear_set_enabled(keymgr, kDifToggleDisabled));
  LOG_INFO("Disable clearing the Keymgr generated sideload keys.");

  // Clear the ERR bits register
  mmio_region_write32(acc->base_addr, ACC_ERR_BITS_REG_OFFSET, 0x0);

  CHECK_STATUS_OK(keymgr_testutils_generate_versioned_key(
      keymgr, sideload_params));  // Regenerate the sideload key.
  LOG_INFO("Keymgr generated HW output for ACC.");
  uint32_t post_clear_salt_result[8];
  run_x25519_app(acc, post_clear_salt_result, kErrBitsOk);
  CHECK_ARRAYS_EQ(result, post_clear_salt_result, ARRAYSIZE(result));

  // Change the salt to generate a different key.
  sideload_params.salt[0] = ~sideload_params.salt[0];
  CHECK_STATUS_OK(
      keymgr_testutils_generate_versioned_key(keymgr, sideload_params));
  LOG_INFO("Keymgr generated HW output for ACC.");

  uint32_t modified_salt_result[8];
  run_x25519_app(acc, modified_salt_result, kErrBitsOk);

  // Check that the result with the new key is different from the first
  // result.
  CHECK_ARRAYS_NE(result, modified_salt_result, ARRAYSIZE(result));

  // Change the salt back to generate the first key again.
  sideload_params.salt[0] = ~sideload_params.salt[0];
  CHECK_STATUS_OK(
      keymgr_testutils_generate_versioned_key(keymgr, sideload_params));
  LOG_INFO("Keymgr generated HW output for ACC.");

  uint32_t same_key_result[8];
  run_x25519_app(acc, same_key_result, kErrBitsOk);

  // Check that the result generated using the same key matches the first
  // result.
  CHECK_ARRAYS_EQ(result, same_key_result, ARRAYSIZE(result));
}

bool test_main(void) {
  init_peripheral_handles();
  CHECK_STATUS_OK(keymgr_testutils_initialize(&keymgr, &kmac));

  // Test ACC sideloading.
  test_acc_with_sideloaded_key(&keymgr, &acc);

  return true;
}
