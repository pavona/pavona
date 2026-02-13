// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/sca/acc_vertical/ecc256_modinv_serial.h"

#include "sw/device/lib/base/abs_mmio.h"
#include "sw/device/lib/base/memory.h"
#include "sw/device/lib/runtime/ibex.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/entropy_testutils.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"
#include "sw/device/lib/testing/test_framework/ottf_test_config.h"
#include "sw/device/sca/lib/prng.h"
#include "sw/device/sca/lib/simple_serial.h"
#include "sw/device/tests/penetrationtests/firmware/lib/pentest_lib.h"

#include "hw/top/acc_regs.h"
#include "hw/top_earlgrey/sw/autogen/top_earlgrey.h"

enum {
  /**
   * Number of cycles that Ibex should sleep to minimize noise during ACC
   * operations. Caution: This number should be chosen to provide enough time
   * to complete the operation. Otherwise, Ibex might wake up while ACC is
   * still busy and disturb the capture.
   */
  kIbexAccSleepCycles = 50000,
  /**
   * Number of bytes for ECDSA P-256 modular inverse input shares (k0,k1).
   */
  kEcc256ModInvInputShareNumBytes = 320 / 8,
  /**
   * Number of words for ECDSA P-256 modular inverse input shares (k0,k1).
   */
  kEcc256ModInvInputShareNumWords =
      kEcc256ModInvInputShareNumBytes / sizeof(uint32_t),
  /**
   * Number of bytes for ECDSA P-256 modular inverse output ((k*alpha)^-1 mod
   * n).
   */
  kEcc256ModInvOutputKAlphaInvNumBytes = 256 / 8,
  /**
   * Number of words for ECDSA P-256 modular inverse output ((k*alpha)^-1 mod
   * n).
   */
  kEcc256ModInvOutputKAlphaInvNumWords =
      kEcc256ModInvOutputKAlphaInvNumBytes / sizeof(uint32_t),
  /**
   * Number of bytes for ECDSA P-256 modular inverse output mask (alpha).
   */
  kEcc256ModInvOutputAlphaNumBytes = 128 / 8,
  /**
   * Number of words for ECDSA P-256 modular inverse output mask (alpha).
   */
  kEcc256ModInvOutputAlphaNumWords =
      kEcc256ModInvOutputAlphaNumBytes / sizeof(uint32_t),
};

/**
 * App configuration for p256_mod_inv_sca
 */
const acc_app_t kAccAppP256ModInv = ACC_APP_T_INIT(p256_mod_inv_sca);

static const acc_addr_t kAccVarModInvK0 =
    ACC_ADDR_T_INIT(p256_mod_inv_sca, k0);
static const acc_addr_t kAccVarModInvK1 =
    ACC_ADDR_T_INIT(p256_mod_inv_sca, k1);
static const acc_addr_t kAccVarModInvKAplhaInv =
    ACC_ADDR_T_INIT(p256_mod_inv_sca, kalpha_inv);
static const acc_addr_t kAccVarModInvAlpha =
    ACC_ADDR_T_INIT(p256_mod_inv_sca, alpha);

/**
 * Callback wrapper for ACC manual trigger function.
 */
static void acc_manual_trigger(void) { SS_CHECK_STATUS_OK(acc_execute()); }

/**
 * Runs the ACC modular inverse program.
 *
 * The input must be `kEcc256ModInvInputShareNumWords` words long.
 *
 * @param[in] input  Iput value for the ACC modular inverse.
 */
static void p256_run_modinv(uint32_t *k0, uint32_t *k1) {
  // Write input.
  SS_CHECK_STATUS_OK(
      acc_dmem_write(kEcc256ModInvInputShareNumWords, k0, kAccVarModInvK0));
  SS_CHECK_STATUS_OK(
      acc_dmem_write(kEcc256ModInvInputShareNumWords, k1, kAccVarModInvK1));

  // Execute program.
  pentest_set_trigger_high();
  pentest_call_and_sleep(acc_manual_trigger, kIbexAccSleepCycles, false,
                         false);
  SS_CHECK_STATUS_OK(acc_busy_wait_for_done());
  pentest_set_trigger_low();
}

void ecc256_modinv(const uint8_t *k0_k1, size_t k0_k1_len) {
  if (k0_k1_len != 2 * kEcc256ModInvInputShareNumBytes) {
    LOG_ERROR("Invalid input length %hu", (uint8_t)k0_k1_len);
    return;
  }

  // Copy input to an aligned buffer.
  uint32_t modinv_k0[kEcc256ModInvInputShareNumWords];
  uint32_t modinv_k1[kEcc256ModInvInputShareNumWords];
  memcpy(modinv_k0, k0_k1, kEcc256ModInvInputShareNumBytes);
  memcpy(modinv_k1, (k0_k1 + kEcc256ModInvInputShareNumBytes),
         kEcc256ModInvInputShareNumBytes);

  // Run the key generation program.
  p256_run_modinv(modinv_k0, modinv_k1);

  // Read result.
  uint32_t modinv_kalpha_inv[kEcc256ModInvOutputKAlphaInvNumWords];
  uint32_t modinv_alpha[kEcc256ModInvOutputAlphaNumWords];
  SS_CHECK_STATUS_OK(acc_dmem_read(kEcc256ModInvOutputKAlphaInvNumWords,
                                    kAccVarModInvKAplhaInv,
                                    modinv_kalpha_inv));
  SS_CHECK_STATUS_OK(acc_dmem_read(kEcc256ModInvOutputAlphaNumWords,
                                    kAccVarModInvAlpha, modinv_alpha));

  simple_serial_send_packet('r', (unsigned char *)modinv_kalpha_inv,
                            kEcc256ModInvOutputKAlphaInvNumBytes);
  simple_serial_send_packet('r', (unsigned char *)modinv_alpha,
                            kEcc256ModInvOutputAlphaNumBytes);
}
