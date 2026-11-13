// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
#ifndef OPENTITAN_SW_DEVICE_LIB_CRYPTO_DRIVERS_AES_GCM_H_
#define OPENTITAN_SW_DEVICE_LIB_CRYPTO_DRIVERS_AES_GCM_H_

#include <stddef.h>
#include <stdint.h>

#include "sw/device/lib/base/hardened.h"
#include "sw/device/lib/base/macros.h"
#include "sw/device/lib/base/status.h"
#include "sw/device/lib/crypto/drivers/aes.h"

#include "hw/top/aes_regs.h"  // Generated.

#ifdef __cplusplus
extern "C" {
#endif

enum {
  /** Number of words in an IV. The hardware only supports 96-bit IVs. */
  kAesGcmHwIvNumWords = 3,
  /** Maximum number of words in a tag. The hardware computes 128-bit tags. */
  kAesGcmHwTagMaxNumWords = kAesBlockNumWords,
};

/**
 * GCM phases of the AES hardware, in the encoding of the
 * CTRL_GCM_SHADOWED.PHASE field.
 */
typedef enum aes_gcm_hw_phase {
  kAesGcmHwPhaseInit = AES_CTRL_GCM_SHADOWED_PHASE_VALUE_GCM_INIT,
  kAesGcmHwPhaseRestore = AES_CTRL_GCM_SHADOWED_PHASE_VALUE_GCM_RESTORE,
  kAesGcmHwPhaseAad = AES_CTRL_GCM_SHADOWED_PHASE_VALUE_GCM_AAD,
  kAesGcmHwPhaseText = AES_CTRL_GCM_SHADOWED_PHASE_VALUE_GCM_TEXT,
  kAesGcmHwPhaseSave = AES_CTRL_GCM_SHADOWED_PHASE_VALUE_GCM_SAVE,
  kAesGcmHwPhaseTag = AES_CTRL_GCM_SHADOWED_PHASE_VALUE_GCM_TAG,
} aes_gcm_hw_phase_t;

/**
 * Checks whether the AES hardware supports GCM.
 *
 * Clears the AES block afterwards via aes_gcm_hw_end.
 *
 * @param[out] available True if GCM is supported, otherwise False.
 * @return result, OK or error.
 */
OT_WARN_UNUSED_RESULT
status_t aes_gcm_hw_available(hardened_bool_t *available);

/**
 * Prepares the AES hardware to perform a GCM encryption operation. Configures
 * the AES block, loads the key and IV and waits for initialization to finish.
 *
 * @param key AES key; `key.mode` must be `kAesCipherModeCtr`.
 * @param iv IV; words 0 to 2 hold the 96-bit IV, word 3 is ignored.
 * @return result, OK or error. `OTCRYPTO_NOT_IMPLEMENTED` if the hardware has
 *         no GCM support.
 */
OT_WARN_UNUSED_RESULT
status_t aes_gcm_hw_encrypt_begin(const aes_key_t key, const aes_block_t *iv);

/**
 * Prepares the AES hardware to perform a GCM decryption operation. Configures
 * the AES block, loads the key and IV and waits for initialization to finish.
 *
 * @param key AES key; `key.mode` must be `kAesCipherModeCtr`.
 * @param iv IV; words 0 to 2 hold the 96-bit IV, word 3 is ignored.
 * @return result, OK or error. `OTCRYPTO_NOT_IMPLEMENTED` if the hardware has
 *         no GCM support.
 */
OT_WARN_UNUSED_RESULT
status_t aes_gcm_hw_decrypt_begin(const aes_key_t key, const aes_block_t *iv);

/**
 * Processes AAD or data in a phase.
 *
 * Enters the phase and sends the input. A phase may be split over several
 * calls, but only the last call may end with a partial block.
 *
 * @param phase `kAesGcmHwPhaseAad` or `kAesGcmHwPhaseText`.
 * @param len Number of bytes to process.
 * @param in Input bytes; may be null if `len` is zero.
 * @param[out] out Output bytes (`len` bytes), or null to not read the output
 *             (for AAD).
 * @return result, OK or error.
 */
OT_WARN_UNUSED_RESULT
status_t aes_gcm_hw_process(aes_gcm_hw_phase_t phase, size_t len,
                            const uint8_t *in, uint8_t *out);

/**
 * Saves the GCM context and clears the AES block.
 *
 * Clears the AES block afterwards via aes_gcm_hw_end.
 * Call `aes_gcm_hw_verify_ctrl()` first; resume with `aes_gcm_hw_restore()`.
 *
 * @param[out] ghash_state The GHASH state.
 * @param[out] iv The IV register (the last word holds the counter).
 * @return result, OK or error.
 */
OT_WARN_UNUSED_RESULT
status_t aes_gcm_hw_save(aes_block_t *ghash_state, aes_block_t *iv);

/**
 * Restores a context saved with `aes_gcm_hw_save()` and continues in `phase`.
 *
 * Starts the AES block like `aes_gcm_hw_encrypt_begin()`: the caller must call
 * `aes_gcm_hw_end()` afterwards, also if this function fails.
 *
 * @param key The same AES key as for the saved operation.
 * @param encrypt The same direction as for the saved operation.
 * @param ghash_state The saved GHASH state.
 * @param iv The saved IV register.
 * @param phase The phase to continue in.
 * @return result, OK or error.
 */
OT_WARN_UNUSED_RESULT
status_t aes_gcm_hw_restore(const aes_key_t key, hardened_bool_t encrypt,
                            const aes_block_t *ghash_state,
                            const aes_block_t *iv, aes_gcm_hw_phase_t phase);

/**
 * Enters the tag phase and reads the tag.
 *
 * Call `aes_gcm_hw_verify_ctrl()` first.
 *
 * @param aad_len Total length of the AAD in bytes.
 * @param data_len Total length of the data in bytes.
 * @param[out] tag The 128-bit tag.
 * @return result, OK or error.
 */
OT_WARN_UNUSED_RESULT
status_t aes_gcm_hw_tag(size_t aad_len, size_t data_len, aes_block_t *tag);

/**
 * Verify the CTRL and CTRL_AUX register values for the given parameters.
 *
 * Like `aes_verify_ctrl_reg()` and `aes_verify_ctrl_aux_reg()`.
 *
 * @param key AES key.
 * @param encrypt True for encryption, false for decryption.
 * @return result, OK or error.
 */
OT_WARN_UNUSED_RESULT
status_t aes_gcm_hw_verify_ctrl(const aes_key_t key, hardened_bool_t encrypt);

/**
 * Ends the operation: clears the control settings, the key, IV and data
 * registers.
 *
 * @return result, OK or error.
 */
OT_WARN_UNUSED_RESULT
status_t aes_gcm_hw_end(void);

/**
 * One-shot AES-GCM encryption with the AES hardware.
 *
 * `key.mode` must be `kAesCipherModeCtr`.
 *
 * @param key AES key.
 * @param iv IV; words 0 to 2 hold the 96-bit IV, word 3 is ignored.
 * @param aad_len Length of the AAD in bytes.
 * @param aad Additional authenticated data.
 * @param data_len Length of the plaintext in bytes.
 * @param plaintext Plaintext.
 * @param[out] ciphertext Ciphertext (`data_len` bytes).
 * @param[out] tag Full 128-bit tag.
 * @return result, OK or error. `OTCRYPTO_NOT_IMPLEMENTED` if the hardware has
 *         no GCM support.
 */
OT_WARN_UNUSED_RESULT
status_t aes_gcm_hw_encrypt(const aes_key_t key, const aes_block_t *iv,
                            size_t aad_len, const uint8_t *aad, size_t data_len,
                            const uint8_t *plaintext, uint8_t *ciphertext,
                            aes_block_t *tag);

/**
 * One-shot AES-GCM decryption with the AES hardware.
 *
 * `key.mode` must be `kAesCipherModeCtr`.
 *
 * The returned tag is the tag computed over the ciphertext; the caller must
 * compare it with the expected tag and discard the plaintext if they differ.
 *
 * @param key AES key.
 * @param iv IV; words 0 to 2 hold the 96-bit IV, word 3 is ignored.
 * @param aad_len Length of the AAD in bytes.
 * @param aad Additional authenticated data.
 * @param data_len Length of the ciphertext in bytes.
 * @param ciphertext Ciphertext.
 * @param[out] plaintext Plaintext (`data_len` bytes).
 * @param[out] tag The 128-bit tag computed over the ciphertext.
 * @return result, OK or error.
 */
OT_WARN_UNUSED_RESULT
status_t aes_gcm_hw_decrypt(const aes_key_t key, const aes_block_t *iv,
                            size_t aad_len, const uint8_t *aad, size_t data_len,
                            const uint8_t *ciphertext, uint8_t *plaintext,
                            aes_block_t *tag);

#ifdef __cplusplus
}
#endif

#endif  // OPENTITAN_SW_DEVICE_LIB_CRYPTO_DRIVERS_AES_GCM_H_
