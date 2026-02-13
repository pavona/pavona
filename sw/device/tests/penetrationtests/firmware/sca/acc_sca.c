// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/tests/penetrationtests/firmware/sca/acc_sca.h"

#include "ecc256_keygen_sca.h"
#include "sw/device/lib/arch/boot_stage.h"
#include "sw/device/lib/base/memory.h"
#include "sw/device/lib/base/status.h"
#include "sw/device/lib/crypto/drivers/keymgr.h"
#include "sw/device/lib/crypto/impl/keyblob.h"
#include "sw/device/lib/crypto/impl/status.h"
#include "sw/device/lib/dif/dif_acc.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/entropy_testutils.h"
#include "sw/device/lib/testing/keymgr_testutils.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_test_config.h"
#include "sw/device/lib/testing/test_framework/ujson_ottf.h"
#include "sw/device/lib/ujson/ujson.h"
#include "sw/device/sca/lib/prng.h"
#include "sw/device/tests/penetrationtests/firmware/lib/pentest_lib.h"
#include "sw/device/tests/penetrationtests/json/acc_sca_commands.h"

#include "hw/top/acc_regs.h"  // Generated.
#include "hw/top_earlgrey/sw/autogen/top_earlgrey.h"

#define MAX_BATCH_SIZE 256
#define BYTES_IN_WDR 32

static dif_acc_t acc;
static dif_keymgr_t keymgr;
static dif_kmac_t kmac;

enum {
  kKeySideloadNumIt = 16,
  /**
   * Number of bytes for ECDSA P-256 private keys, message digests, and point
   * coordinates.
   */
  kEcc256NumBytes = 256 / 8,
  /**
   * Number of 32b words for ECDSA P-256 private keys, message digests, and
   * point coordinates.
   */
  kEcc256NumWords = kEcc256NumBytes / sizeof(uint32_t),
  /**
   * Max number of traces per batch.
   */
  kNumBatchOpsMax = 256,
};

// Data structs for key sideloading test.
ACC_DECLARE_APP_SYMBOLS(acc_key_sideload_sca);
ACC_DECLARE_SYMBOL_ADDR(acc_key_sideload_sca, k_s0_l);
ACC_DECLARE_SYMBOL_ADDR(acc_key_sideload_sca, k_s0_h);
ACC_DECLARE_SYMBOL_ADDR(acc_key_sideload_sca, k_s1_l);
ACC_DECLARE_SYMBOL_ADDR(acc_key_sideload_sca, k_s1_h);
ACC_DECLARE_SYMBOL_ADDR(acc_key_sideload_sca, k_l);
ACC_DECLARE_SYMBOL_ADDR(acc_key_sideload_sca, k_h);
const acc_app_t kAccAppKeySideloadSca = ACC_APP_T_INIT(acc_key_sideload_sca);
static const acc_addr_t kAccAppKeySideloadks0l =
    ACC_ADDR_T_INIT(acc_key_sideload_sca, k_s0_l);
static const acc_addr_t kAccAppKeySideloadks0h =
    ACC_ADDR_T_INIT(acc_key_sideload_sca, k_s0_h);
static const acc_addr_t kAccAppKeySideloadks1l =
    ACC_ADDR_T_INIT(acc_key_sideload_sca, k_s1_l);
static const acc_addr_t kAccAppKeySideloadks1h =
    ACC_ADDR_T_INIT(acc_key_sideload_sca, k_s1_h);
static const acc_addr_t kAccAppKeySideloadkl =
    ACC_ADDR_T_INIT(acc_key_sideload_sca, k_l);
static const acc_addr_t kAccAppKeySideloadkh =
    ACC_ADDR_T_INIT(acc_key_sideload_sca, k_h);

// RSA ACC App.
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

// p256_ecdsa_sca has randomization removed.
ACC_DECLARE_APP_SYMBOLS(p256_ecdsa_sca);

ACC_DECLARE_SYMBOL_ADDR(p256_ecdsa_sca, mode);
ACC_DECLARE_SYMBOL_ADDR(p256_ecdsa_sca, msg);
ACC_DECLARE_SYMBOL_ADDR(p256_ecdsa_sca, r);
ACC_DECLARE_SYMBOL_ADDR(p256_ecdsa_sca, s);
ACC_DECLARE_SYMBOL_ADDR(p256_ecdsa_sca, x);
ACC_DECLARE_SYMBOL_ADDR(p256_ecdsa_sca, y);
ACC_DECLARE_SYMBOL_ADDR(p256_ecdsa_sca, d0);
ACC_DECLARE_SYMBOL_ADDR(p256_ecdsa_sca, d1);
ACC_DECLARE_SYMBOL_ADDR(p256_ecdsa_sca, k0);
ACC_DECLARE_SYMBOL_ADDR(p256_ecdsa_sca, k1);
ACC_DECLARE_SYMBOL_ADDR(p256_ecdsa_sca, x_r);

static const acc_app_t kAccAppP256Ecdsa = ACC_APP_T_INIT(p256_ecdsa_sca);

static const acc_addr_t kAccVarMode = ACC_ADDR_T_INIT(p256_ecdsa_sca, mode);
static const acc_addr_t kAccVarMsg = ACC_ADDR_T_INIT(p256_ecdsa_sca, msg);
static const acc_addr_t kAccVarR = ACC_ADDR_T_INIT(p256_ecdsa_sca, r);
static const acc_addr_t kAccVarS = ACC_ADDR_T_INIT(p256_ecdsa_sca, s);
static const acc_addr_t kAccVarD0 = ACC_ADDR_T_INIT(p256_ecdsa_sca, d0);
static const acc_addr_t kAccVarD1 = ACC_ADDR_T_INIT(p256_ecdsa_sca, d1);
static const acc_addr_t kAccVarK0 = ACC_ADDR_T_INIT(p256_ecdsa_sca, k0);
static const acc_addr_t kAccVarK1 = ACC_ADDR_T_INIT(p256_ecdsa_sca, k1);

/**
 * Clears the ACC DMEM and IMEM.
 *
 * @returns OK or error.
 */
static status_t clear_acc(void) {
  // Clear ACC memory.
  TRY(acc_dmem_sec_wipe());
  TRY(acc_imem_sec_wipe());

  return OK_STATUS();
}

/**
 * Generate masked shared.
 *
 * If mask_en is set, generate a random share.
 * If mask_en is not set, set share to 0.
 *
 * @param dest_array          Destination array.
 * @param mask_en             Masking enabled or disabled.
 * @param len                 Length of the array.
 */
void gen_mask_data(uint32_t *dest_array, bool mask_en, size_t len) {
  if (mask_en) {
    for (size_t j = 0; j < len; ++j) {
      dest_array[j] = prng_rand_uint32();
    }
  } else {
    memset(dest_array, 0, len * sizeof(dest_array[0]));
  }
}

/**
 * Generate a FvsR data set.
 *
 * If fixed is set, copy src_fixed_array into dest_array.
 * If fixed is not set, generate random data.
 *
 * @param dest_array          Destination array.
 * @param fixed               Fixed or random set.
 * @param src_fixed_array     Source fixed array.
 * @param len                 Length of the array.
 */
void gen_fvsr_data(uint32_t *dest_array, bool fixed, uint32_t *src_fixed_array,
                   size_t len) {
  if (fixed) {
    memcpy(dest_array, src_fixed_array, len * sizeof(src_fixed_array[0]));
  } else {
    for (size_t j = 0; j < len; ++j) {
      dest_array[j] = prng_rand_uint32();
    }
  }
}

/**
 * Signs a message with ECDSA using the P-256 curve.
 *
 * R = k*G
 * r = x-coordinate of R
 * s = k^(-1)(msg + r*d)  mod n
 *
 * @param acc_ctx            The ACC context object.
 * @param msg                 The message to sign, msg (32B).
 * @param private_key_d       The private key, d (32B).
 * @param k                   The ephemeral key,  k (random scalar) (32B).
 * @param[out] signature_r    Signature component r (the x-coordinate of R).
 *                            Provide a pre-allocated 32B buffer.
 * @param[out] signature_s    Signature component s (the proof).
 *                            Provide a pre-allocated 32B buffer.
 */
static status_t p256_ecdsa_sign(const uint32_t *msg,
                                const uint32_t *private_key_d,
                                uint32_t *signature_r, uint32_t *signature_s,
                                const uint32_t *k) {
  uint32_t mode = 1;  // mode 1 => sign
  // Send operation mode to ACC
  TRY(acc_dmem_write(/*num_words=*/1, &mode, kAccVarMode));
  // Send Msg to ACC
  TRY(acc_dmem_write(kEcc256NumWords, msg, kAccVarMsg));
  // Send two shares of private_key_d to ACC
  TRY(acc_dmem_write(kEcc256NumWords, private_key_d, kAccVarD0));
  TRY(acc_dmem_write(kEcc256NumWords, private_key_d + kEcc256NumWords,
                     kAccVarD1));
  // Send two shares of secret_k to ACC
  TRY(acc_dmem_write(kEcc256NumWords, k, kAccVarK0));
  TRY(acc_dmem_write(kEcc256NumWords, k + kEcc256NumWords, kAccVarK1));

  // Start ACC execution
  pentest_set_trigger_high();
  // Give the trigger time to rise.
  asm volatile(NOP30);
  TRY(acc_execute());
  TRY(acc_busy_wait_for_done());
  pentest_set_trigger_low();

  // Read the results back (sig_r, sig_s)
  TRY(acc_dmem_read(kEcc256NumWords, kAccVarR, signature_r));
  TRY(acc_dmem_read(kEcc256NumWords, kAccVarS, signature_s));

  return OK_STATUS();
}

status_t handle_acc_sca_ecdsa_p256_sign(ujson_t *uj) {
  // Get masks off or on.
  penetrationtest_acc_sca_en_masks_t uj_data_masks;
  TRY(ujson_deserialize_penetrationtest_acc_sca_en_masks_t(uj, &uj_data_masks));

  // Get message and key.
  penetrationtest_acc_sca_ecdsa_p256_sign_t uj_data;
  TRY(ujson_deserialize_penetrationtest_acc_sca_ecdsa_p256_sign_t(uj,
                                                                  &uj_data));

  // Set of share d1 for masking.
  uint32_t ecc256_private_key_d1[kEcc256NumWords];
  memset(ecc256_private_key_d1, 0, sizeof(ecc256_private_key_d1));
  // If masking is activated, generate random share d1.
  if (uj_data_masks.en_masks) {
    for (size_t j = 0; j < kEcc256NumWords; j++) {
      ecc256_private_key_d1[j] = prng_rand_uint32();
    }
  }

  // Set of share k1 for masking.
  uint32_t ecc256_secret_k1[kEcc256NumWords];
  memset(ecc256_secret_k1, 0, sizeof(ecc256_secret_k1));
  // If masking is activated, generate random share d1.
  if (uj_data_masks.en_masks) {
    for (size_t j = 0; j < kEcc256NumWords; j++) {
      ecc256_secret_k1[j] = prng_rand_uint32();
    }
  }

  // Combine D0 and D1 into the private key.
  uint32_t ecc256_private_key_d[2 * kEcc256NumWords];
  memset(ecc256_private_key_d, 0, sizeof(ecc256_private_key_d));
  memcpy(ecc256_private_key_d, uj_data.d0, sizeof(uj_data.d0));
  memcpy(ecc256_private_key_d + kEcc256NumWords, ecc256_private_key_d1,
         sizeof(ecc256_private_key_d1));

  // Combine K0 and K1 into the secret key.
  uint32_t ecc256_secret_k[2 * kEcc256NumWords];
  memset(ecc256_secret_k, 0, sizeof(ecc256_secret_k));
  memcpy(ecc256_secret_k, uj_data.k0, sizeof(uj_data.k0));
  memcpy(ecc256_secret_k + kEcc256NumWords, ecc256_secret_k1,
         sizeof(ecc256_secret_k1));

  TRY(acc_load_app(kAccAppP256Ecdsa));

  // Signature output.
  uint32_t ecc256_signature_r[kEcc256NumWords];
  uint32_t ecc256_signature_s[kEcc256NumWords];

  // Start the operation.
  p256_ecdsa_sign(uj_data.msg, ecc256_private_key_d, ecc256_signature_r,
                  ecc256_signature_s, ecc256_secret_k);

  // Send back signature to host.
  penetrationtest_acc_sca_ecdsa_p256_signature_t uj_output;
  memcpy(uj_output.r, ecc256_signature_r, sizeof(ecc256_signature_r));
  memcpy(uj_output.s, ecc256_signature_s, sizeof(ecc256_signature_s));
  RESP_OK(ujson_serialize_penetrationtest_acc_sca_ecdsa_p256_signature_t, uj,
          &uj_output);

  // Clear ACC memory
  TRY(clear_acc());

  return OK_STATUS();
}

status_t handle_acc_sca_ecdsa_p256_sign_batch(ujson_t *uj) {
  // Get number of traces.
  penetrationtest_acc_sca_num_traces_t uj_data_num_traces;
  TRY(ujson_deserialize_penetrationtest_acc_sca_num_traces_t(
      uj, &uj_data_num_traces));

  if (uj_data_num_traces.num_traces > kNumBatchOpsMax) {
    return OUT_OF_RANGE();
  }

  // Get masks off or on.
  penetrationtest_acc_sca_en_masks_t uj_data_masks;
  TRY(ujson_deserialize_penetrationtest_acc_sca_en_masks_t(uj, &uj_data_masks));

  // Create random message, k, and d.
  uint32_t ecc256_message_batch[kNumBatchOpsMax][kEcc256NumWords];

  uint32_t ecc256_private_key_d0_batch[kNumBatchOpsMax][kEcc256NumWords];
  uint32_t ecc256_private_key_d1_batch[kNumBatchOpsMax][kEcc256NumWords];
  uint32_t ecc256_private_key_d_batch[kNumBatchOpsMax][2 * kEcc256NumWords];

  uint32_t ecc256_secret_key_k0_batch[kNumBatchOpsMax][kEcc256NumWords];
  uint32_t ecc256_secret_key_k1_batch[kNumBatchOpsMax][kEcc256NumWords];
  uint32_t ecc256_secret_key_k_batch[kNumBatchOpsMax][2 * kEcc256NumWords];

  // Generate the FvsR data set.
  for (size_t i = 0; i < uj_data_num_traces.num_traces; ++i) {
    // Generate random message.
    gen_fvsr_data(ecc256_message_batch[i], false, NULL, kEcc256NumWords);

    // Set random private key d0.
    gen_fvsr_data(ecc256_private_key_d0_batch[i], false, NULL, kEcc256NumWords);

    // When masks are on, set random private key d1. If masks are off, set to 0.
    gen_mask_data(ecc256_private_key_d1_batch[i], uj_data_masks.en_masks,
                  kEcc256NumWords);

    // Combine both shares d0 and d1 to d.
    memcpy(ecc256_private_key_d_batch[i], ecc256_private_key_d0_batch[i],
           sizeof(ecc256_private_key_d0_batch[i]));
    memcpy(ecc256_private_key_d_batch[i] + kEcc256NumWords,
           ecc256_private_key_d1_batch[i],
           sizeof(ecc256_private_key_d1_batch[i]));

    // Set random secret key k0.
    gen_fvsr_data(ecc256_secret_key_k0_batch[i], false, NULL, kEcc256NumWords);

    // When masks are on, set random secret key k1. If masks are off, set to 0.
    gen_mask_data(ecc256_secret_key_k1_batch[i], uj_data_masks.en_masks,
                  kEcc256NumWords);

    // Combine both shares k0 and k1 to k.
    memcpy(ecc256_secret_key_k_batch[i], ecc256_secret_key_k0_batch[i],
           sizeof(ecc256_secret_key_k0_batch[i]));
    memcpy(ecc256_secret_key_k_batch[i] + kEcc256NumWords,
           ecc256_secret_key_k1_batch[i],
           sizeof(ecc256_secret_key_k1_batch[i]));
  }

  // Last signature output.
  uint32_t ecc256_signature_r[kEcc256NumWords];
  uint32_t ecc256_signature_s[kEcc256NumWords];
  // Run num_traces ECDSA operations.
  for (size_t i = 0; i < uj_data_num_traces.num_traces; ++i) {
    TRY(acc_load_app(kAccAppP256Ecdsa));

    // Start the operation.
    p256_ecdsa_sign(ecc256_message_batch[i], ecc256_private_key_d_batch[i],
                    ecc256_signature_r, ecc256_signature_s,
                    ecc256_secret_key_k_batch[i]);
  }

  // Send back the last signature to host.
  penetrationtest_acc_sca_ecdsa_p256_signature_t uj_output;
  memcpy(uj_output.r, ecc256_signature_r, sizeof(ecc256_signature_r));
  memcpy(uj_output.s, ecc256_signature_s, sizeof(ecc256_signature_s));
  RESP_OK(ujson_serialize_penetrationtest_acc_sca_ecdsa_p256_signature_t, uj,
          &uj_output);

  // Clear ACC memory
  TRY(clear_acc());

  return OK_STATUS();
}

status_t handle_acc_sca_ecdsa_p256_sign_fvsr_batch(ujson_t *uj) {
  // Get number of traces.
  penetrationtest_acc_sca_num_traces_t uj_data_num_traces;
  TRY(ujson_deserialize_penetrationtest_acc_sca_num_traces_t(
      uj, &uj_data_num_traces));

  if (uj_data_num_traces.num_traces > kNumBatchOpsMax) {
    return OUT_OF_RANGE();
  }

  // Get masks off or on.
  penetrationtest_acc_sca_en_masks_t uj_data_masks;
  TRY(ujson_deserialize_penetrationtest_acc_sca_en_masks_t(uj, &uj_data_masks));

  // Get fixed message and key.
  penetrationtest_acc_sca_ecdsa_p256_sign_t uj_data;
  TRY(ujson_deserialize_penetrationtest_acc_sca_ecdsa_p256_sign_t(uj,
                                                                  &uj_data));

  uint32_t ecc256_message_batch[kNumBatchOpsMax][kEcc256NumWords];

  uint32_t ecc256_private_key_d0_batch[kNumBatchOpsMax][kEcc256NumWords];
  uint32_t ecc256_private_key_d1_batch[kNumBatchOpsMax][kEcc256NumWords];
  uint32_t ecc256_private_key_d_batch[kNumBatchOpsMax][2 * kEcc256NumWords];

  uint32_t ecc256_secret_key_k0_batch[kNumBatchOpsMax][kEcc256NumWords];
  uint32_t ecc256_secret_key_k1_batch[kNumBatchOpsMax][kEcc256NumWords];
  uint32_t ecc256_secret_key_k_batch[kNumBatchOpsMax][2 * kEcc256NumWords];

  // Generate the FvsR data set. For each trace, message, k, and d is either set
  // to fixed received from the host over uJSON or random.
  bool run_fixed = true;
  for (size_t i = 0; i < uj_data_num_traces.num_traces; ++i) {
    // Set message.
    gen_fvsr_data(ecc256_message_batch[i], run_fixed, uj_data.msg,
                  kEcc256NumWords);

    // If the run is fixed, take the private key received over uJSON. Else,
    // generate a random private key.
    gen_fvsr_data(ecc256_private_key_d0_batch[i], run_fixed, uj_data.d0,
                  kEcc256NumWords);

    // When masks are on, set fixed or random private key d1. If masks are off,
    // set to 0.
    gen_mask_data(ecc256_private_key_d1_batch[i], uj_data_masks.en_masks,
                  kEcc256NumWords);

    // Combine both shares
    memcpy(ecc256_private_key_d_batch[i], ecc256_private_key_d0_batch[i],
           sizeof(ecc256_private_key_d0_batch[i]));
    memcpy(ecc256_private_key_d_batch[i] + kEcc256NumWords,
           ecc256_private_key_d1_batch[i],
           sizeof(ecc256_private_key_d1_batch[i]));

    // Set random secret key k0.
    // If the run is fixed, take the private key received over uJSON. Else,
    // generate a random private key.
    gen_fvsr_data(ecc256_secret_key_k0_batch[i], run_fixed, uj_data.k0,
                  kEcc256NumWords);

    // When masks are on, set random secret key k1. If masks are off, set to 0.
    gen_mask_data(ecc256_secret_key_k1_batch[i], uj_data_masks.en_masks,
                  kEcc256NumWords);

    // Combine both shares k0 and k1 to k.
    memcpy(ecc256_secret_key_k_batch[i], ecc256_secret_key_k0_batch[i],
           sizeof(ecc256_secret_key_k0_batch[i]));
    memcpy(ecc256_secret_key_k_batch[i] + kEcc256NumWords,
           ecc256_secret_key_k1_batch[i],
           sizeof(ecc256_secret_key_k1_batch[i]));

    run_fixed = prng_rand_uint32() & 0x1;
  }

  // Last signature output.
  uint32_t ecc256_signature_r[kEcc256NumWords];
  uint32_t ecc256_signature_s[kEcc256NumWords];
  // Run num_traces ECDSA operations.
  for (size_t i = 0; i < uj_data_num_traces.num_traces; ++i) {
    TRY(acc_load_app(kAccAppP256Ecdsa));

    // Start the operation.
    p256_ecdsa_sign(uj_data.msg, ecc256_private_key_d_batch[i],
                    ecc256_signature_r, ecc256_signature_s,
                    ecc256_secret_key_k_batch[i]);
  }

  // Send back the last signature to host.
  penetrationtest_acc_sca_ecdsa_p256_signature_t uj_output;
  memcpy(uj_output.r, ecc256_signature_r, sizeof(ecc256_signature_r));
  memcpy(uj_output.s, ecc256_signature_s, sizeof(ecc256_signature_s));
  RESP_OK(ujson_serialize_penetrationtest_acc_sca_ecdsa_p256_signature_t, uj,
          &uj_output);

  // Clear ACC memory
  TRY(clear_acc());

  return OK_STATUS();
}

status_t handle_acc_pentest_init(ujson_t *uj) {
  penetrationtest_cpuctrl_t uj_cpuctrl_data;
  TRY(ujson_deserialize_penetrationtest_cpuctrl_t(uj, &uj_cpuctrl_data));
  penetrationtest_sensor_config_t uj_sensor_data;
  TRY(ujson_deserialize_penetrationtest_sensor_config_t(uj, &uj_sensor_data));

  // Configure the entropy complex for ACC. Set the reseed interval to max
  // to avoid a non-constant trigger window.
  TRY(pentest_configure_entropy_source_max_reseed_interval());

  // Init the ACC core.
  TRY(dif_acc_init(mmio_region_from_addr(TOP_EARLGREY_ACC_BASE_ADDR), &acc));

  // Load p256 keygen from seed app into ACC.
  if (acc_load_app(kAccAppP256KeyFromSeed).value != OTCRYPTO_OK.value) {
    return ABORTED();
  }

  // Configure the CPU for the pentest.
  penetrationtest_device_info_t uj_output;
  TRY(pentest_configure_cpu(
      uj_cpuctrl_data.enable_icache, &uj_output.icache_en,
      uj_cpuctrl_data.enable_dummy_instr, &uj_output.dummy_instr_en,
      uj_cpuctrl_data.dummy_instr_count, uj_cpuctrl_data.enable_jittery_clock,
      uj_cpuctrl_data.enable_sram_readback, &uj_output.clock_jitter_locked,
      &uj_output.clock_jitter_en, &uj_output.sram_main_readback_locked,
      &uj_output.sram_ret_readback_locked, &uj_output.sram_main_readback_en,
      &uj_output.sram_ret_readback_en, uj_cpuctrl_data.enable_data_ind_timing,
      &uj_output.data_ind_timing_en));

  pentest_init(kPentestTriggerSourceAcc,
               kPentestPeripheralEntropy | kPentestPeripheralIoDiv4 |
                   kPentestPeripheralAcc | kPentestPeripheralCsrng |
                   kPentestPeripheralEdn,
               uj_sensor_data.sensor_ctrl_enable,
               uj_sensor_data.sensor_ctrl_en_fatal);

  // Read rom digest.
  TRY(pentest_read_rom_digest(uj_output.rom_digest));

  // Read device ID and return to host.
  TRY(pentest_read_device_id(uj_output.device_id));
  RESP_OK(ujson_serialize_penetrationtest_device_info_t, uj, &uj_output);

  // Read different SKU config fields and return to host.
  TRY(pentest_send_sku_config(uj));

  return OK_STATUS();
}

status_t handle_acc_pentest_init_keymgr(ujson_t *uj) {
  if (kBootStage != kBootStageOwner) {
    TRY(keymgr_testutils_startup(&keymgr, &kmac));
    // Advance to OwnerIntermediateKey state.
    TRY(keymgr_testutils_advance_state(&keymgr, &kOwnerIntParams));
    TRY(keymgr_testutils_check_state(&keymgr,
                                     kDifKeymgrStateOwnerIntermediateKey));
    LOG_INFO("Keymgr entered OwnerIntKey State");
  } else {
    TRY(dif_keymgr_init(mmio_region_from_addr(TOP_EARLGREY_KEYMGR_BASE_ADDR),
                        &keymgr));
    TRY(keymgr_testutils_check_state(&keymgr, kDifKeymgrStateOwnerRootKey));
  }

  dif_acc_t acc;
  TRY(dif_acc_init(mmio_region_from_addr(TOP_EARLGREY_ACC_BASE_ADDR), &acc));

  return OK_STATUS();
}

status_t handle_acc_sca_insn_carry_flag(ujson_t *uj) {
  // Get big number (256 bit).
  penetrationtest_acc_sca_big_num_t uj_data;
  TRY(ujson_deserialize_penetrationtest_acc_sca_big_num_t(uj, &uj_data));

  // INSN Carry Flag ACC App.
  ACC_DECLARE_APP_SYMBOLS(acc_insn_carry_flag);
  ACC_DECLARE_SYMBOL_ADDR(acc_insn_carry_flag, big_num);
  ACC_DECLARE_SYMBOL_ADDR(acc_insn_carry_flag, big_num_out);

  static const acc_app_t kAccAppInsnCarryFlag =
      ACC_APP_T_INIT(acc_insn_carry_flag);
  static const acc_addr_t kAccVarInsnCarryFlagBigNum =
      ACC_ADDR_T_INIT(acc_insn_carry_flag, big_num);
  static const acc_addr_t kAccVarInsnCarryFlagBigNumOut =
      ACC_ADDR_T_INIT(acc_insn_carry_flag, big_num_out);

  // Load app and write received big_num into DMEM.
  TRY(acc_load_app(kAccAppInsnCarryFlag));
  TRY(dif_acc_dmem_write(&acc, kAccVarInsnCarryFlagBigNum, uj_data.big_num,
                         sizeof(uj_data.big_num)));

  pentest_set_trigger_high();
  TRY(acc_execute());
  TRY(acc_busy_wait_for_done());
  pentest_set_trigger_low();

  penetrationtest_acc_sca_big_num_t uj_output;
  memset(uj_output.big_num, 0, sizeof(uj_output.big_num));
  TRY(dif_acc_dmem_read(&acc, kAccVarInsnCarryFlagBigNumOut, uj_output.big_num,
                        sizeof(uj_output.big_num)));

  RESP_OK(ujson_serialize_penetrationtest_acc_sca_big_num_t, uj, &uj_output);

  return OK_STATUS();
}

status_t trigger_acc_sca_combi_operations(
    uint32_t value1, uint32_t value2, uint32_t result1[8], uint32_t result2[8],
    uint32_t result3[8], uint32_t result4[8], uint32_t result5[8],
    uint32_t result6[8], uint32_t result7[8], uint32_t *result8,
    uint32_t trigger) {
  // INSN Combi Ops ACC App.
  ACC_DECLARE_APP_SYMBOLS(acc_insn_combi_ops);
  ACC_DECLARE_SYMBOL_ADDR(acc_insn_combi_ops, big_input_1);
  ACC_DECLARE_SYMBOL_ADDR(acc_insn_combi_ops, big_input_2);
  ACC_DECLARE_SYMBOL_ADDR(acc_insn_combi_ops, result_1);
  ACC_DECLARE_SYMBOL_ADDR(acc_insn_combi_ops, result_2);
  ACC_DECLARE_SYMBOL_ADDR(acc_insn_combi_ops, result_3);
  ACC_DECLARE_SYMBOL_ADDR(acc_insn_combi_ops, result_4);
  ACC_DECLARE_SYMBOL_ADDR(acc_insn_combi_ops, result_5);
  ACC_DECLARE_SYMBOL_ADDR(acc_insn_combi_ops, result_6);
  ACC_DECLARE_SYMBOL_ADDR(acc_insn_combi_ops, result_7);
  ACC_DECLARE_SYMBOL_ADDR(acc_insn_combi_ops, result_8);

  static const acc_app_t kAccAppInsnCombiOps =
      ACC_APP_T_INIT(acc_insn_combi_ops);
  static const acc_addr_t kAccVarInsnCombiOpsValue1 =
      ACC_ADDR_T_INIT(acc_insn_combi_ops, big_input_1);
  static const acc_addr_t kAccVarInsnCombiOpsValue2 =
      ACC_ADDR_T_INIT(acc_insn_combi_ops, big_input_2);
  static const acc_addr_t kAccVarInsnCombiOpsResult1 =
      ACC_ADDR_T_INIT(acc_insn_combi_ops, result_1);
  static const acc_addr_t kAccVarInsnCombiOpsResult2 =
      ACC_ADDR_T_INIT(acc_insn_combi_ops, result_2);
  static const acc_addr_t kAccVarInsnCombiOpsResult3 =
      ACC_ADDR_T_INIT(acc_insn_combi_ops, result_3);
  static const acc_addr_t kAccVarInsnCombiOpsResult4 =
      ACC_ADDR_T_INIT(acc_insn_combi_ops, result_4);
  static const acc_addr_t kAccVarInsnCombiOpsResult5 =
      ACC_ADDR_T_INIT(acc_insn_combi_ops, result_5);
  static const acc_addr_t kAccVarInsnCombiOpsResult6 =
      ACC_ADDR_T_INIT(acc_insn_combi_ops, result_6);
  static const acc_addr_t kAccVarInsnCombiOpsResult7 =
      ACC_ADDR_T_INIT(acc_insn_combi_ops, result_7);
  static const acc_addr_t kAccVarInsnCombiOpsResult8 =
      ACC_ADDR_T_INIT(acc_insn_combi_ops, result_8);

  // Load app and write received big_num into DMEM.
  TRY(acc_load_app(kAccAppInsnCombiOps));
  TRY(dif_acc_dmem_write(&acc, kAccVarInsnCombiOpsValue1, &value1,
                         sizeof(value1)));
  TRY(dif_acc_dmem_write(&acc, kAccVarInsnCombiOpsValue2, &value2,
                         sizeof(value2)));

  if (trigger & 0x1)
    pentest_set_trigger_high();
  TRY(acc_execute());
  TRY(acc_busy_wait_for_done());
  if (trigger & 0x1)
    pentest_set_trigger_low();

  TRY(dif_acc_dmem_read(&acc, kAccVarInsnCombiOpsResult1, &result1[0],
                        BYTES_IN_WDR));
  TRY(dif_acc_dmem_read(&acc, kAccVarInsnCombiOpsResult2, &result2[0],
                        BYTES_IN_WDR));
  TRY(dif_acc_dmem_read(&acc, kAccVarInsnCombiOpsResult3, &result3[0],
                        BYTES_IN_WDR));
  TRY(dif_acc_dmem_read(&acc, kAccVarInsnCombiOpsResult4, &result4[0],
                        BYTES_IN_WDR));
  TRY(dif_acc_dmem_read(&acc, kAccVarInsnCombiOpsResult5, &result5[0],
                        BYTES_IN_WDR));
  TRY(dif_acc_dmem_read(&acc, kAccVarInsnCombiOpsResult6, &result6[0],
                        BYTES_IN_WDR));
  TRY(dif_acc_dmem_read(&acc, kAccVarInsnCombiOpsResult7, &result7[0],
                        BYTES_IN_WDR));
  TRY(dif_acc_dmem_read(&acc, kAccVarInsnCombiOpsResult8, &result8[0],
                        sizeof(*result8)));

  if (trigger & 0x2)
    pentest_set_trigger_high();
  TRY(acc_dmem_sec_wipe());
  if (trigger & 0x2)
    pentest_set_trigger_low();

  return OK_STATUS();
}

status_t handle_acc_sca_combi_operations_batch(ujson_t *uj) {
  // Get number of iterations and fixed data.
  acc_sca_test_batch_ops_t uj_data;
  TRY(ujson_deserialize_acc_sca_test_batch_ops_t(uj, &uj_data));
  TRY_CHECK(uj_data.num_iterations < MAX_BATCH_SIZE);

  acc_sca_ops_result_t uj_output;

  // SCA code target.
  for (size_t it = 0; it < uj_data.num_iterations; it++) {
    // Clear the results buffer.
    memset(uj_output.result1, 0, sizeof(uj_output.result1));
    memset(uj_output.result2, 0, sizeof(uj_output.result2));
    memset(uj_output.result3, 0, sizeof(uj_output.result3));
    memset(uj_output.result4, 0, sizeof(uj_output.result4));
    memset(uj_output.result5, 0, sizeof(uj_output.result5));
    memset(uj_output.result6, 0, sizeof(uj_output.result6));
    memset(uj_output.result7, 0, sizeof(uj_output.result7));
    uj_output.result8 = 0;
    // Call the target code sequence.
    TRY(trigger_acc_sca_combi_operations(
        uj_data.fixed_data1, uj_data.fixed_data2, uj_output.result1,
        uj_output.result2, uj_output.result3, uj_output.result4,
        uj_output.result5, uj_output.result6, uj_output.result7,
        &uj_output.result8, uj_data.trigger));
  }

  // Write back last values to validate generated data if asked for.
  if (uj_data.print_flag) {
    RESP_OK(ujson_serialize_acc_sca_ops_result_t, uj, &uj_output);
  } else {
    acc_sca_empty_t uj_empty;
    uj_empty.success = true;
    RESP_OK(ujson_serialize_acc_sca_empty_t, uj, &uj_empty);
  }
  return OK_STATUS();
}

status_t handle_acc_sca_key_sideload_fvsr(ujson_t *uj) {
  // Get fixed seed.
  penetrationtest_acc_sca_fixed_seed_t uj_data;
  TRY(ujson_deserialize_penetrationtest_acc_sca_fixed_seed_t(uj, &uj_data));

  // Key generation parameters.
  dif_keymgr_versioned_key_params_t sideload_params[kKeySideloadNumIt];

  // Generate FvsR values.
  bool sample_fixed = true;
  for (size_t it = 0; it < kKeySideloadNumIt; it++) {
    sideload_params[it].version = 0x0;
    sideload_params[it].dest = kDifKeymgrVersionedKeyDestAcc;
    memset(sideload_params[it].salt, 0, sizeof(sideload_params[it].salt));
    if (sample_fixed) {
      sideload_params[it].salt[0] = uj_data.fixed_seed;
    } else {
      sideload_params[it].salt[0] = prng_rand_uint32();
    }
    sample_fixed = prng_rand_uint32() & 0x1;
  }

  TRY(acc_load_app(kAccAppKeySideloadSca));

  uint32_t key_share_0_l[kKeySideloadNumIt], key_share_0_h[kKeySideloadNumIt];
  uint32_t key_share_1_l[16], key_share_1_h[kKeySideloadNumIt];
  uint32_t key_l[kKeySideloadNumIt], key_h[kKeySideloadNumIt];

  // SCA code target.
  for (size_t it = 0; it < kKeySideloadNumIt; it++) {
    TRY(keymgr_testutils_generate_versioned_key(&keymgr, sideload_params[it]));

    TRY(dif_acc_set_ctrl_software_errs_fatal(&acc, /*enable=*/false));

    pentest_set_trigger_high();
    // Give the trigger time to rise.
    asm volatile(NOP30);
    TRY(acc_execute());
    TRY(acc_busy_wait_for_done());
    pentest_set_trigger_low();
    asm volatile(NOP30);

    TRY(acc_dmem_read(1, kAccAppKeySideloadks0l, &key_share_0_l[it]));
    TRY(acc_dmem_read(1, kAccAppKeySideloadks0h, &key_share_0_h[it]));
    TRY(acc_dmem_read(1, kAccAppKeySideloadks1l, &key_share_1_l[it]));
    TRY(acc_dmem_read(1, kAccAppKeySideloadks1h, &key_share_1_h[it]));
    TRY(acc_dmem_read(1, kAccAppKeySideloadkl, &key_l[it]));
    TRY(acc_dmem_read(1, kAccAppKeySideloadkh, &key_h[it]));
  }

  // Write back shares and keys to host.
  penetrationtest_acc_sca_key_t uj_output;
  for (size_t it = 0; it < kKeySideloadNumIt; it++) {
    uj_output.shares[0] = key_share_0_l[it];
    uj_output.shares[1] = key_share_0_h[it];
    uj_output.shares[2] = key_share_1_l[it];
    uj_output.shares[3] = key_share_1_h[it];
    uj_output.keys[0] = key_l[it];
    uj_output.keys[1] = key_h[it];
    RESP_OK(ujson_serialize_penetrationtest_acc_sca_key_t, uj, &uj_output);
  }

  return OK_STATUS();
}

status_t handle_acc_sca_rsa512_decrypt(ujson_t *uj) {
  // Get RSA256 parameters.
  penetrationtest_acc_sca_rsa512_dec_t uj_data;
  TRY(ujson_deserialize_penetrationtest_acc_sca_rsa512_dec_t(uj, &uj_data));
  TRY(acc_load_app(kAccAppRsa));

  uint32_t mode = 2;  // Decrypt.
  // RSA512 configuration.
  uint32_t n_limbs = 2;

  // Write data into ACC DMEM.
  TRY(dif_acc_dmem_write(&acc, kAccVarRsaMode, &mode, sizeof(mode)));
  TRY(dif_acc_dmem_write(&acc, kAccVarRsaNLimbs, &n_limbs, sizeof(n_limbs)));
  TRY(dif_acc_dmem_write(&acc, kAccVarRsaModulus, uj_data.modu,
                         sizeof(uj_data.modu)));
  TRY(dif_acc_dmem_write(&acc, kAccVarRsaExp, uj_data.exp,
                         sizeof(uj_data.exp)));
  TRY(dif_acc_dmem_write(&acc, kAccVarRsaInOut, uj_data.msg,
                         sizeof(uj_data.msg)));

  pentest_set_trigger_high();
  // Give the trigger time to rise.
  asm volatile(NOP30);
  TRY(acc_execute());
  TRY(acc_busy_wait_for_done());
  pentest_set_trigger_low();

  // Send back decryption result to host.
  penetrationtest_acc_sca_rsa512_dec_out_t uj_output;
  TRY(dif_acc_dmem_read(&acc, kAccVarRsaInOut, uj_output.out,
                        sizeof(uj_output.out)));
  RESP_OK(ujson_serialize_penetrationtest_acc_sca_rsa512_dec_out_t, uj,
          &uj_output);
  return OK_STATUS();
}

status_t handle_acc_sca(ujson_t *uj) {
  acc_sca_subcommand_t cmd;
  TRY(ujson_deserialize_acc_sca_subcommand_t(uj, &cmd));
  switch (cmd) {
    case kAccScaSubcommandEcc256EcdsaKeygenFvsrKeyBatch:
      return handle_acc_sca_ecc256_ecdsa_keygen_fvsr_key_batch(uj);
    case kAccScaSubcommandEcc256EcdsaKeygenFvsrSeedBatch:
      return handle_acc_sca_ecc256_ecdsa_keygen_fvsr_seed_batch(uj);
    case kAccScaSubcommandEcc256EnMasks:
      return handle_acc_sca_ecc256_en_masks(uj);
    case kAccScaSubcommandEcc256SetC:
      return handle_acc_sca_ecc256_set_c(uj);
    case kAccScaSubcommandEcc256SetSeed:
      return handle_acc_sca_ecc256_set_seed(uj);
    case kAccScaSubcommandEcdsaP256Sign:
      return handle_acc_sca_ecdsa_p256_sign(uj);
    case kAccScaSubcommandEcdsaP256SignBatch:
      return handle_acc_sca_ecdsa_p256_sign_batch(uj);
    case kAccScaSubcommandEcdsaP256SignFvsrBatch:
      return handle_acc_sca_ecdsa_p256_sign_fvsr_batch(uj);
    case kAccScaSubcommandInit:
      return handle_acc_pentest_init(uj);
    case kAccScaSubcommandInitKeyMgr:
      return handle_acc_pentest_init_keymgr(uj);
    case kAccScaSubcommandInsnCarryFlag:
      return handle_acc_sca_insn_carry_flag(uj);
    case kAccScaSubcommandCombiOps:
      return handle_acc_sca_combi_operations_batch(uj);
    case kAccScaSubcommandKeySideloadFvsr:
      return handle_acc_sca_key_sideload_fvsr(uj);
    case kAccScaSubcommandRsa512Decrypt:
      return handle_acc_sca_rsa512_decrypt(uj);
    default:
      LOG_ERROR("Unrecognized ACC SCA subcommand: %d", cmd);
      return INVALID_ARGUMENT();
  }
  return OK_STATUS();
}
