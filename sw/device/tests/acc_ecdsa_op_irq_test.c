// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hw/top/dt/dt_acc.h"      // Generated
#include "hw/top/dt/dt_rv_plic.h"  // Generated
#include "sw/device/lib/dif/dif_acc.h"
#include "sw/device/lib/runtime/ibex.h"
#include "sw/device/lib/runtime/irq.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/acc_testutils.h"
#include "sw/device/lib/testing/entropy_testutils.h"
#include "sw/device/lib/testing/profile.h"
#include "sw/device/lib/testing/rv_plic_testutils.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"

/**
 * ECDSA sign and verify test with the NIST P-256 curve using ACC.
 *
 * IMPORTANT: This test is not a secure, complete, or reusable implementation of
 * a cryptographic algorithm; it is not even close to being production-ready.
 * It is only meant as an end-to-end test for ACC during the bringup phase.
 *
 * The test contains constants and expected output, which can be independently
 * and conveniently verified using a Python script.
 *
 * <code>
 * # Optional: generate a new key
 * $ openssl ecparam -name prime256v1 -genkey -noout -out \
 *     acc_ecdsa_p256_test_private_key.pem
 *
 * # Create all constants/variables
 * $ ./acc_test_params.py ecc acc_ecdsa_p256_test_private_key.pem
 * </code>
 */

ACC_DECLARE_APP_SYMBOLS(run_p256);

ACC_DECLARE_SYMBOL_ADDR(run_p256, mode);
ACC_DECLARE_SYMBOL_ADDR(run_p256, msg);
ACC_DECLARE_SYMBOL_ADDR(run_p256, r);
ACC_DECLARE_SYMBOL_ADDR(run_p256, s);
ACC_DECLARE_SYMBOL_ADDR(run_p256, x);
ACC_DECLARE_SYMBOL_ADDR(run_p256, y);
ACC_DECLARE_SYMBOL_ADDR(run_p256, d0_io);
ACC_DECLARE_SYMBOL_ADDR(run_p256, d1_io);
ACC_DECLARE_SYMBOL_ADDR(run_p256, x_r);

static const acc_app_t kAccAppP256Ecdsa = ACC_APP_T_INIT(run_p256);

static const acc_addr_t kAccVarMode = ACC_ADDR_T_INIT(run_p256, mode);
static const acc_addr_t kAccVarMsg = ACC_ADDR_T_INIT(run_p256, msg);
static const acc_addr_t kAccVarR = ACC_ADDR_T_INIT(run_p256, r);
static const acc_addr_t kAccVarS = ACC_ADDR_T_INIT(run_p256, s);
static const acc_addr_t kAccVarX = ACC_ADDR_T_INIT(run_p256, x);
static const acc_addr_t kAccVarY = ACC_ADDR_T_INIT(run_p256, y);
static const acc_addr_t kAccVarD0 = ACC_ADDR_T_INIT(run_p256, d0_io);
static const acc_addr_t kAccVarD1 = ACC_ADDR_T_INIT(run_p256, d1_io);
static const acc_addr_t kAccVarXR = ACC_ADDR_T_INIT(run_p256, x_r);

// Declare mode constants.
ACC_DECLARE_SYMBOL_ADDR(run_p256, MODE_SIGN);
ACC_DECLARE_SYMBOL_ADDR(run_p256, MODE_VERIFY);
static const uint32_t kModeSign = ACC_ADDR_T_INIT(run_p256, MODE_SIGN);
static const uint32_t kModeVerify = ACC_ADDR_T_INIT(run_p256, MODE_VERIFY);

OTTF_DEFINE_TEST_CONFIG();

static const uint32_t kPlicTarget = 0;

/**
 * The plic dif to access the hardware.
 */
static dif_rv_plic_t plic;

/**
 * The acc context handler.
 */
static dif_acc_t acc;

/**
 * The peripheral which fired the irq to be filled by the irq handler.
 */
static volatile dt_instance_id_t plic_peripheral;

/**
 * The irq id to be filled by the irq handler.
 */
static volatile dif_rv_plic_irq_id_t irq_id;

/**
 * The acc irq to be filled by the irq handler.
 */
static volatile dt_acc_irq_t irq;

/**
 * Provides external IRQ handling for acc tests.
 *
 * This function overrides the default OTTF external ISR.
 *
 * It performs the following:
 * 1. Checks if the interrupt is from ACC.
 * 2. Computes the acc irq from the PLIC ID.
 * 3. Sets volatile variables for the waiting function.
 * 4. Clears the IRQ at the peripheral.
 * 5. Returns true to indicate the interrupt was handled.
 */
bool ottf_handle_irq(uint32_t *exc_info, dt_instance_id_t devid,
                     dif_rv_plic_irq_id_t plic_id) {
  // Handle interrupts from ACC
  if (devid != dt_acc_instance_id(kDtAcc)) {
    return false;
  }

  // Store the peripheral and IRQ ID for acc_wait_for_done_irq
  plic_peripheral = devid;
  irq_id = plic_id;
  irq = dt_acc_irq_from_plic_id(kDtAcc, plic_id);

  CHECK_DIF_OK(dif_acc_irq_acknowledge(&acc, irq));
  return true;
}

static void acc_wait_for_done_irq(dif_acc_t *acc) {
  // Clear the acc irq variable: we'll set it in the interrupt handler when
  // we see the Done interrupt fire.
  irq = UINT32_MAX;
  irq_id = UINT32_MAX;
  plic_peripheral = kDtInstanceIdUnknown;
  // Enable Done interrupt.
  CHECK_DIF_OK(dif_acc_irq_set_enabled(acc, kDifAccIrqDone, kDifToggleEnabled));

  // At this point, ACC should be running. Wait for an interrupt that says
  // it's done.
  ATOMIC_WAIT_FOR_INTERRUPT(plic_peripheral != kDtInstanceIdUnknown);

  CHECK(plic_peripheral == dt_acc_instance_id(kDtAcc),
        "Interrupt from incorrect peripheral: (exp: %d, obs: %s)",
        dt_acc_instance_id(kDtAcc), plic_peripheral);

  // Check this is the interrupt we expected.
  CHECK(irq == kDtAccIrqDone);

  // Disable Done interrupt.
  CHECK_DIF_OK(
      dif_acc_irq_set_enabled(acc, kDifAccIrqDone, kDifToggleDisabled));

  // Acknowledge Done interrupt. This clears INTR_STATE.done back to 0.
  CHECK_DIF_OK(dif_acc_irq_acknowledge(acc, kDifAccIrqDone));
}

static void acc_init_irq(void) {
  // Initialize PLIC and configure ACC interrupt.
  CHECK_DIF_OK(dif_rv_plic_init_from_dt(kDtRvPlic, &plic));

  // Set interrupt priority to be positive.
  dif_rv_plic_irq_id_t irq_id = dt_acc_irq_to_plic_id(kDtAcc, kDtAccIrqDone);
  CHECK_DIF_OK(dif_rv_plic_irq_set_priority(&plic, irq_id, 0x1));

  CHECK_DIF_OK(dif_rv_plic_irq_set_enabled(&plic, irq_id, kPlicTarget,
                                           kDifToggleEnabled));

  // Set the threshold for Ibex to 0.
  CHECK_DIF_OK(dif_rv_plic_target_set_threshold(&plic, kPlicTarget, 0x0));

  // Enable the external IRQ (so that we see the interrupt from the PLIC).
  irq_global_ctrl(true);
  irq_external_ctrl(true);
}

/**
 * Securely wipes ACC DMEM and waits for Done interrupt.
 *
 * @param acc The ACC context object.
 */
static void acc_wipe_dmem(dif_acc_t *acc) {
  CHECK_DIF_OK(dif_acc_write_cmd(acc, kDifAccCmdSecWipeDmem));
  acc_wait_for_done_irq(acc);
}

/**
 * CHECK()s that the actual data matches the expected data.
 *
 * @param actual The actual data.
 * @param expected The expected data.
 * @param size_bytes The size of the actual/expected data.
 */
static void check_data(const char *msg, const uint8_t *actual,
                       const uint8_t *expected, size_t size_bytes) {
  for (int i = 0; i < size_bytes; ++i) {
    CHECK(actual[i] == expected[i],
          "%s: mismatch at byte %d: 0x%x (actual) != 0x%x (expected)", msg, i,
          actual[i], expected[i]);
  }
}

/**
 * Signs a message with ECDSA using the P-256 curve.
 *
 * @param acc                The ACC context object.
 * @param msg                 The message to sign (32B).
 * @param private_key_d       The private key (32B).
 * @param[out] signature_r    Signature component r (the x-coordinate of R).
 *                            Provide a pre-allocated 32B buffer.
 * @param[out] signature_s    Signature component s (the proof).
 *                            Provide a pre-allocated 32B buffer.
 */
static void p256_ecdsa_sign(dif_acc_t *acc, const uint8_t *msg,
                            const uint8_t *private_key_d, uint8_t *signature_r,
                            uint8_t *signature_s) {
  CHECK(acc != NULL);

  // Write input arguments.
  uint32_t mode = kModeSign;
  CHECK_STATUS_OK(
      acc_testutils_write_data(acc, sizeof(uint32_t), &mode, kAccVarMode));
  CHECK_STATUS_OK(
      acc_testutils_write_data(acc, /*len_bytes=*/32, msg, kAccVarMsg));
  CHECK_STATUS_OK(acc_testutils_write_data(acc, /*len_bytes=*/32, private_key_d,
                                           kAccVarD0));

  // Write redundant upper bits of d (all-zero for this test).
  uint8_t d0_high[32] = {0};
  CHECK_STATUS_OK(
      acc_testutils_write_data(acc, /*len_bytes=*/32, d0_high, kAccVarD0 + 32));

  // Write second share of d (all-zero for this test).
  uint8_t d1[64] = {0};
  CHECK_STATUS_OK(
      acc_testutils_write_data(acc, /*len_bytes=*/64, d1, kAccVarD1));

  // Call ACC to perform operation, and wait for it to complete.
  CHECK_STATUS_OK(acc_testutils_execute(acc));
  acc_wait_for_done_irq(acc);

  // Read back results.
  CHECK_STATUS_OK(
      acc_testutils_read_data(acc, /*len_bytes=*/32, kAccVarR, signature_r));
  CHECK_STATUS_OK(
      acc_testutils_read_data(acc, /*len_bytes=*/32, kAccVarS, signature_s));
}

/**
 * Verifies a message with ECDSA using the P-256 curve.
 *
 * @param acc                 The ACC context object.
 * @param msg                  The message to verify (32B).
 * @param signature_r          The signature component r (the proof) (32B).
 * @param signature_s          The signature component s (the proof) (32B).
 * @param public_key_x         The public key x-coordinate (32B).
 * @param public_key_y         The public key y-coordinate (32B).
 * @param[out] signature_x_r   Recovered point x_r (== R'.x). Provide a
 *                             pre-allocated 32B buffer.
 */
static void p256_ecdsa_verify(dif_acc_t *acc, const uint8_t *msg,
                              const uint8_t *signature_r,
                              const uint8_t *signature_s,
                              const uint8_t *public_key_x,
                              const uint8_t *public_key_y,
                              uint8_t *signature_x_r) {
  CHECK(acc != NULL);

  // Write input arguments.
  uint32_t mode = kModeVerify;
  CHECK_STATUS_OK(
      acc_testutils_write_data(acc, sizeof(uint32_t), &mode, kAccVarMode));
  CHECK_STATUS_OK(
      acc_testutils_write_data(acc, /*len_bytes=*/32, msg, kAccVarMsg));
  CHECK_STATUS_OK(
      acc_testutils_write_data(acc, /*len_bytes=*/32, signature_r, kAccVarR));
  CHECK_STATUS_OK(
      acc_testutils_write_data(acc, /*len_bytes=*/32, signature_s, kAccVarS));
  CHECK_STATUS_OK(
      acc_testutils_write_data(acc, /*len_bytes=*/32, public_key_x, kAccVarX));
  CHECK_STATUS_OK(
      acc_testutils_write_data(acc, /*len_bytes=*/32, public_key_y, kAccVarY));

  // Call ACC to perform operation, and wait for it to complete.
  CHECK_STATUS_OK(acc_testutils_execute(acc));
  acc_wait_for_done_irq(acc);

  // Read back results.
  CHECK_STATUS_OK(
      acc_testutils_read_data(acc, /*len_bytes=*/32, kAccVarXR, signature_x_r));
}

/**
 * Performs a ECDSA roundtrip test using the NIST P-256 curve.
 *
 * A roundtrip consists of three steps: Initialize ACC, sign, and verify.
 */
static void test_ecdsa_p256_roundtrip(void) {
  // Message
  static const uint8_t kIn[32] = {"Hello ACC."};

  // Public key x-coordinate (Q.x)
  static const uint8_t kPublicKeyQx[32] = {
      0x4e, 0xb2, 0x8b, 0x55, 0xeb, 0x88, 0x62, 0x24, 0xf2, 0xbf, 0x1b,
      0x9e, 0xd8, 0x4a, 0x09, 0xa7, 0x86, 0x67, 0x92, 0xcd, 0xca, 0x07,
      0x5d, 0x07, 0x82, 0xe7, 0x2d, 0xac, 0x31, 0x14, 0x79, 0x1f};

  // Public key y-coordinate (Q.y)
  static const uint8_t kPublicKeyQy[32] = {
      0x27, 0x9c, 0xe4, 0x23, 0x24, 0x10, 0xa2, 0xfa, 0xbd, 0x53, 0x73,
      0xf1, 0xa5, 0x08, 0xf0, 0x40, 0x9e, 0xc0, 0x55, 0x21, 0xa4, 0xf0,
      0x54, 0x59, 0x00, 0x3e, 0x5f, 0x15, 0x3c, 0xc6, 0x4b, 0x87};

  // Private key (d)
  static const uint8_t kPrivateKeyD[32] = {
      0xcd, 0xb4, 0x57, 0xaf, 0x1c, 0x9f, 0x4c, 0x74, 0x02, 0x0c, 0x7e,
      0x8b, 0xe9, 0x93, 0x3e, 0x28, 0x0c, 0xf0, 0x18, 0x0d, 0xf4, 0x6c,
      0x0b, 0xda, 0x7a, 0xbb, 0xe6, 0x8f, 0xb7, 0xa0, 0x45, 0x55};

  // Initialize
  uint64_t t_start_init = profile_start();
  CHECK_DIF_OK(dif_acc_init_from_dt(kDtAcc, &acc));
  acc_init_irq();
  CHECK_STATUS_OK(acc_testutils_load_app(&acc, kAccAppP256Ecdsa));
  profile_end_and_print(t_start_init, "Initialization");

  // Sign
  uint8_t signature_r[32] = {0};
  uint8_t signature_s[32] = {0};

  LOG_INFO("Signing");
  uint64_t t_start_sign = profile_start();
  p256_ecdsa_sign(&acc, kIn, kPrivateKeyD, signature_r, signature_s);
  profile_end_and_print(t_start_sign, "Sign");

  // Securely wipe ACC data memory and reload app
  LOG_INFO("Wiping ACC DMEM and reloading app");
  acc_wipe_dmem(&acc);
  CHECK_STATUS_OK(acc_testutils_load_app(&acc, kAccAppP256Ecdsa));

  // Verify
  uint8_t signature_x_r[32] = {0};

  LOG_INFO("Verifying");
  uint64_t t_start_verify = profile_start();
  p256_ecdsa_verify(&acc, kIn, signature_r, signature_s, kPublicKeyQx,
                    kPublicKeyQy, signature_x_r);

  // Include the r =? x_r comparison in the profiling as this is something
  // either ACC or the host CPU needs to do as part of the signature
  // verification.
  check_data("signature_x_r", signature_r, signature_x_r, 32);
  profile_end_and_print(t_start_verify, "Verify");

  // Securely wipe ACC data memory
  LOG_INFO("Wiping ACC DMEM");
  acc_wipe_dmem(&acc);
}

bool test_main(void) {
  CHECK_STATUS_OK(entropy_testutils_auto_mode_init());

  test_ecdsa_p256_roundtrip();

  return true;
}
