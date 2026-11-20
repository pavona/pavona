// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/crypto/drivers/aes_gcm.h"

#include "hw/top/dt/aes.h"
#include "sw/device/lib/base/abs_mmio.h"
#include "sw/device/lib/base/macros.h"
#include "sw/device/lib/base/memory.h"
#include "sw/device/lib/base/status.h"
#include "sw/device/lib/crypto/drivers/aes.h"
#include "sw/device/lib/crypto/drivers/entropy.h"
#include "sw/device/lib/crypto/impl/status.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"
#include "sw/device/tests/crypto/aes_gcm_hw_testvectors.h"

#include "hw/top/aes_regs.h"  // Generated.

/** Whether the AES hardware supports GCM; set by `test_setup()`. */
static hardened_bool_t gcm_available = kHardenedBoolFalse;

/**
 * Split the key of a test vector into two shares.
 *
 * This is a weak share intended to exercise correct configuration of the
 * hardware, as in the AES driver test.
 *
 * @param v Test vector.
 * @param[out] share0 First share; words after the key length are zero.
 * @param[out] share1 Second share; words after the key length are zero.
 * @return The key, made of the two shares.
 */
static aes_key_t make_key(const aes_gcm_hw_test_vector_t *v,
                          uint32_t share0[kAesGcmHwTestMaxKeyWords],
                          uint32_t share1[kAesGcmHwTestMaxKeyWords]) {
  for (size_t i = 0; i < kAesGcmHwTestMaxKeyWords; ++i) {
    share0[i] = i < v->key_len ? ~v->key[i] : 0;
    share1[i] = i < v->key_len ? UINT32_MAX : 0;
  }
  return (aes_key_t){
      .mode = kAesCipherModeCtr,
      .sideload = kHardenedBoolFalse,
      .key_len = v->key_len,
      .key_shares = {share0, share1},
  };
}

/**
 * Return the IV of a test vector as a block; the last word is zero.
 *
 * @param v Test vector.
 * @return The IV block.
 */
static aes_block_t make_iv(const aes_gcm_hw_test_vector_t *v) {
  aes_block_t iv = {.data = {0}};
  memcpy(iv.data, v->iv, sizeof(v->iv));
  return iv;
}

/**
 * Check that the IV registers no longer hold `iv`, then load `iv` again.
 *
 * Clearing writes pseudo-random data, so this checks for a change, not for
 * zero.
 *
 * @param iv IV block; the first `kAesGcmHwIvNumWords` words are compared.
 */
static status_t check_aes_cleared(const aes_block_t *iv) {
  uint32_t iv_reg = dt_aes_primary_reg_block(kDtAes) + AES_IV_0_REG_OFFSET;
  uint32_t iv_regs[kAesGcmHwIvNumWords];
  for (size_t i = 0; i < kAesGcmHwIvNumWords; ++i) {
    iv_regs[i] = abs_mmio_read32(iv_reg + i * sizeof(uint32_t));
  }
  TRY_CHECK(memcmp(iv_regs, iv->data, sizeof(iv_regs)) != 0,
            "IV registers not cleared");
  for (size_t i = 0; i < kAesBlockNumWords; ++i) {
    abs_mmio_write32(iv_reg + i * sizeof(uint32_t), iv->data[i]);
  }
  return OK_STATUS();
}

/**
 * Start the entropy complex and detect whether the AES hardware supports GCM.
 */
static status_t test_setup(void) {
  TRY(entropy_complex_init());
  TRY(aes_gcm_hw_available(&gcm_available));
  LOG_INFO("AES hardware GCM support: %s",
           gcm_available == kHardenedBoolTrue ? "yes" : "no");
  return OK_STATUS();
}

/**
 * Encrypt all test vectors with the one-shot function.
 */
static status_t encrypt_test(void) {
  if (gcm_available != kHardenedBoolTrue) {
    LOG_INFO("Skipped: no GCM support.");
    return OK_STATUS();
  }
  for (size_t i = 0; i < ARRAYSIZE(kAesGcmHwTestVectors); ++i) {
    const aes_gcm_hw_test_vector_t *v = &kAesGcmHwTestVectors[i];
    uint32_t share0[kAesGcmHwTestMaxKeyWords];
    uint32_t share1[kAesGcmHwTestMaxKeyWords];
    aes_key_t key = make_key(v, share0, share1);
    aes_block_t iv = make_iv(v);

    uint8_t ciphertext[kAesGcmHwTestMaxDataBytes];
    aes_block_t tag;
    TRY(aes_gcm_hw_encrypt(key, &iv, v->aad_len, v->aad, v->data_len,
                           v->plaintext, ciphertext, &tag));
    TRY_CHECK_ARRAYS_EQ(ciphertext, v->ciphertext, v->data_len);
    TRY_CHECK_ARRAYS_EQ(tag.data, v->tag, kAesGcmHwTagMaxNumWords);
  }
  return OK_STATUS();
}

/**
 * Decrypt all test vectors in place with the one-shot function.
 */
static status_t decrypt_test(void) {
  if (gcm_available != kHardenedBoolTrue) {
    LOG_INFO("Skipped: no GCM support.");
    return OK_STATUS();
  }
  for (size_t i = 0; i < ARRAYSIZE(kAesGcmHwTestVectors); ++i) {
    const aes_gcm_hw_test_vector_t *v = &kAesGcmHwTestVectors[i];
    uint32_t share0[kAesGcmHwTestMaxKeyWords];
    uint32_t share1[kAesGcmHwTestMaxKeyWords];
    aes_key_t key = make_key(v, share0, share1);
    aes_block_t iv = make_iv(v);

    uint8_t data[kAesGcmHwTestMaxDataBytes];
    memcpy(data, v->ciphertext, v->data_len);
    aes_block_t tag;
    TRY(aes_gcm_hw_decrypt(key, &iv, v->aad_len, v->aad, v->data_len, data,
                           data, &tag));
    TRY_CHECK_ARRAYS_EQ(data, v->plaintext, v->data_len);
    TRY_CHECK_ARRAYS_EQ(tag.data, v->tag, kAesGcmHwTagMaxNumWords);
  }
  return OK_STATUS();
}

/**
 * Encrypt the first test vector (test case 4) step by step, saving and
 * restoring the GCM context after the first AAD block and/or after the first
 * data block.
 * That first test vector must have more than one block of AAD and of data.
 *
 * @param after_aad Whether to save and restore after the first AAD block.
 * @param after_data Whether to save and restore after the first data block.
 */
static status_t save_restore(bool after_aad, bool after_data) {
  if (gcm_available != kHardenedBoolTrue) {
    LOG_INFO("Skipped: no GCM support.");
    return OK_STATUS();
  }
  const aes_gcm_hw_test_vector_t *v = &kAesGcmHwTestVectors[0];
  TRY_CHECK(v->aad_len > kAesBlockNumBytes && v->data_len > kAesBlockNumBytes,
            "Needs more than one block of AAD and data.");
  uint32_t share0[kAesGcmHwTestMaxKeyWords];
  uint32_t share1[kAesGcmHwTestMaxKeyWords];
  aes_key_t key = make_key(v, share0, share1);
  aes_block_t iv = make_iv(v);

  TRY(aes_gcm_hw_encrypt_begin(key, &iv));

  aes_block_t ghash_state;
  aes_block_t iv_reg;

  size_t aad_first = after_aad ? kAesBlockNumBytes : v->aad_len;
  TRY(aes_gcm_hw_process(kAesGcmHwPhaseAad, aad_first, v->aad, NULL));
  if (after_aad) {
    TRY(aes_gcm_hw_save(&ghash_state, &iv_reg));
    TRY(aes_gcm_hw_restore(key, kHardenedBoolTrue, &ghash_state, &iv_reg,
                           kAesGcmHwPhaseAad));
    TRY(aes_gcm_hw_process(kAesGcmHwPhaseAad, v->aad_len - aad_first,
                           v->aad + aad_first, NULL));
  }

  uint8_t ciphertext[kAesGcmHwTestMaxDataBytes];
  size_t data_first = after_data ? kAesBlockNumBytes : v->data_len;
  TRY(aes_gcm_hw_process(kAesGcmHwPhaseText, data_first, v->plaintext,
                         ciphertext));
  if (after_data) {
    TRY(aes_gcm_hw_save(&ghash_state, &iv_reg));
    TRY(aes_gcm_hw_restore(key, kHardenedBoolTrue, &ghash_state, &iv_reg,
                           kAesGcmHwPhaseText));
    TRY(aes_gcm_hw_process(kAesGcmHwPhaseText, v->data_len - data_first,
                           v->plaintext + data_first, ciphertext + data_first));
  }

  aes_block_t tag;
  TRY(aes_gcm_hw_tag(v->aad_len, v->data_len, &tag));
  TRY(aes_gcm_hw_end());

  TRY_CHECK_ARRAYS_EQ(ciphertext, v->ciphertext, v->data_len);
  TRY_CHECK_ARRAYS_EQ(tag.data, v->tag, kAesGcmHwTagMaxNumWords);
  return OK_STATUS();
}

/**
 * Save and restore the GCM context in the AAD phase.
 */
static status_t save_restore_aad_test(void) {
  return save_restore(/*after_aad=*/true, /*after_data=*/false);
}

/**
 * Save and restore the GCM context in the data phase.
 */
static status_t save_restore_data_test(void) {
  return save_restore(/*after_aad=*/false, /*after_data=*/true);
}

/**
 * Save and restore the GCM context in the AAD phase and the data phase.
 */
static status_t save_restore_aad_and_data_test(void) {
  return save_restore(/*after_aad=*/true, /*after_data=*/true);
}

/**
 * Check that the driver rejects keys other than CTR keys.
 */
static status_t bad_key_mode_test(void) {
  const aes_gcm_hw_test_vector_t *v = &kAesGcmHwTestVectors[0];
  uint32_t share0[kAesGcmHwTestMaxKeyWords];
  uint32_t share1[kAesGcmHwTestMaxKeyWords];
  aes_key_t key = make_key(v, share0, share1);
  key.mode = kAesCipherModeEcb;
  aes_block_t iv = make_iv(v);

  uint8_t ciphertext[kAesGcmHwTestMaxDataBytes];
  aes_block_t tag;
  status_t result =
      aes_gcm_hw_encrypt(key, &iv, v->aad_len, v->aad, v->data_len,
                         v->plaintext, ciphertext, &tag);
  TRY_CHECK(result.value == kOtcryptoStatusValueBadArgs);
  return OK_STATUS();
}

/**
 * Check that without GCM support the driver returns `OTCRYPTO_NOT_IMPLEMENTED`
 * and clears the AES block.
 */
static status_t not_implemented_test(void) {
  if (gcm_available != kHardenedBoolFalse) {
    LOG_INFO("Skipped: the hardware supports GCM.");
    return OK_STATUS();
  }
  const aes_gcm_hw_test_vector_t *v = &kAesGcmHwTestVectors[0];
  uint32_t share0[kAesGcmHwTestMaxKeyWords];
  uint32_t share1[kAesGcmHwTestMaxKeyWords];
  aes_key_t key = make_key(v, share0, share1);
  aes_block_t iv = make_iv(v);
  // Load the IV registers; they still hold the data of an earlier clear.
  TRY(check_aes_cleared(&iv));

  uint8_t data[kAesGcmHwTestMaxDataBytes];
  aes_block_t tag;
  status_t result = aes_gcm_hw_encrypt(key, &iv, v->aad_len, v->aad,
                                       v->data_len, v->plaintext, data, &tag);
  TRY_CHECK(result.value == kOtcryptoStatusValueNotImplemented);
  TRY(check_aes_cleared(&iv));
  result = aes_gcm_hw_decrypt(key, &iv, v->aad_len, v->aad, v->data_len,
                              v->ciphertext, data, &tag);
  TRY_CHECK(result.value == kOtcryptoStatusValueNotImplemented);
  TRY(check_aes_cleared(&iv));
  // After a failed begin, the caller ends the operation.
  result = aes_gcm_hw_encrypt_begin(key, &iv);
  TRY_CHECK(result.value == kOtcryptoStatusValueNotImplemented);
  TRY(aes_gcm_hw_end());
  TRY(check_aes_cleared(&iv));
  result = aes_gcm_hw_decrypt_begin(key, &iv);
  TRY_CHECK(result.value == kOtcryptoStatusValueNotImplemented);
  TRY(aes_gcm_hw_end());
  TRY(check_aes_cleared(&iv));
  return OK_STATUS();
}

OTTF_DEFINE_TEST_CONFIG();

bool test_main(void) {
  status_t result = OK_STATUS();

  EXECUTE_TEST(result, test_setup);
  EXECUTE_TEST(result, encrypt_test);
  EXECUTE_TEST(result, decrypt_test);
  EXECUTE_TEST(result, save_restore_aad_test);
  EXECUTE_TEST(result, save_restore_data_test);
  EXECUTE_TEST(result, save_restore_aad_and_data_test);
  EXECUTE_TEST(result, bad_key_mode_test);
  EXECUTE_TEST(result, not_implemented_test);
  return status_ok(result);
}
