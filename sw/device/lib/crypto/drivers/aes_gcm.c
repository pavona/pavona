// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/crypto/drivers/aes_gcm.h"

#include "hw/top/dt/aes.h"
#include "sw/device/lib/base/abs_mmio.h"
#include "sw/device/lib/base/bitfield.h"
#include "sw/device/lib/base/hardened.h"
#include "sw/device/lib/base/hardened_memory.h"
#include "sw/device/lib/base/macros.h"
#include "sw/device/lib/base/memory.h"
#include "sw/device/lib/crypto/drivers/aes.h"
#include "sw/device/lib/crypto/drivers/entropy.h"
#include "sw/device/lib/crypto/drivers/rv_core_ibex.h"
#include "sw/device/lib/crypto/impl/status.h"

#include "hw/top/aes_regs.h"  // Generated.

// Module ID for status codes.
#define MODULE_ID MAKE_MODULE_ID('d', 'a', 'g')

static const dt_aes_t kAesDt = kDtAes;

static inline uint32_t aes_base(void) {
  return dt_aes_primary_reg_block(kAesDt);
}

enum {
  kAesKeyWordLen128 = 128 / (sizeof(uint32_t) * 8),
  kAesKeyWordLen192 = 192 / (sizeof(uint32_t) * 8),
  kAesKeyWordLen256 = 256 / (sizeof(uint32_t) * 8),
  kAesKeyWordLenMax = kAesKeyWordLen256,
};

/**
 * Spins until the AES hardware reports a specific status bit.
 */
OT_WARN_UNUSED_RESULT
static status_t spin_until(uint32_t bit) {
  while (true) {
    uint32_t reg = abs_mmio_read32(aes_base() + AES_STATUS_REG_OFFSET);
    if (bitfield_bit32_read(reg, AES_STATUS_ALERT_RECOV_CTRL_UPDATE_ERR_BIT) ||
        bitfield_bit32_read(reg, AES_STATUS_ALERT_FATAL_FAULT_BIT)) {
      return OTCRYPTO_RECOV_ERR;
    }
    if (bitfield_bit32_read(reg, bit)) {
      return OTCRYPTO_OK;
    }
  }
}

/**
 * Write the key to the AES hardware block.
 *
 * If the key is sideloaded, this is a no-op.
 *
 * Consumes randomness; the caller must ensure the entropy complex is up.
 *
 * @param key AES key.
 * @return result, OK or error.
 */
OT_WARN_UNUSED_RESULT
static status_t write_key(const aes_key_t key) {
  if (key.sideload != kHardenedBoolFalse) {
    HARDENED_CHECK_EQ(key.sideload, kHardenedBoolTrue);
    // Nothing to be done; key must be separately loaded from keymgr.
    return OTCRYPTO_OK;
  }
  HARDENED_CHECK_EQ(key.sideload, kHardenedBoolFalse);

  uint32_t share0 = aes_base() + AES_KEY_SHARE0_0_REG_OFFSET;
  uint32_t share1 = aes_base() + AES_KEY_SHARE1_0_REG_OFFSET;

  hardened_mmio_write(share0, key.key_shares[0], key.key_len);
  hardened_mmio_write(share1, key.key_shares[1], key.key_len);

  // Write random words to remaining key registers.
  size_t i = key.key_len;
  for (; i < kAesKeyWordLenMax; i++) {
    abs_mmio_write32(share0 + i * sizeof(uint32_t), ibex_rnd32_read());
    abs_mmio_write32(share1 + i * sizeof(uint32_t), ibex_rnd32_read());
  }
  HARDENED_CHECK_EQ(i, kAesKeyWordLenMax);

  return spin_until(AES_STATUS_IDLE_BIT);
}

/**
 * Compute the ctrl register value for the given parameters.
 *
 * @param key AES key.
 * @param encrypt True for encryption, false for decryption.
 * @param[out] ctrl_reg Computed control register value.
 * @return result, OK or error.
 */
OT_WARN_UNUSED_RESULT
static status_t compute_ctrl_reg(const aes_key_t key, hardened_bool_t encrypt,
                                 uint32_t *ctrl_reg) {
  *ctrl_reg = AES_CTRL_SHADOWED_REG_RESVAL;

  // Set the operation (encrypt or decrypt).
  hardened_bool_t operation_written = kHardenedBoolFalse;
  switch (launder32(encrypt)) {
    case kHardenedBoolTrue:
      HARDENED_CHECK_EQ(encrypt, kHardenedBoolTrue);
      *ctrl_reg =
          bitfield_field32_write(*ctrl_reg, AES_CTRL_SHADOWED_OPERATION_FIELD,
                                 AES_CTRL_SHADOWED_OPERATION_VALUE_AES_ENC);
      operation_written = launder32(kHardenedBoolTrue);
      break;
    case kHardenedBoolFalse:
      HARDENED_CHECK_EQ(encrypt, kHardenedBoolFalse);
      *ctrl_reg =
          bitfield_field32_write(*ctrl_reg, AES_CTRL_SHADOWED_OPERATION_FIELD,
                                 AES_CTRL_SHADOWED_OPERATION_VALUE_AES_DEC);
      operation_written = launder32(kHardenedBoolTrue);
      break;
    default:
      // Invalid value.
      return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(operation_written, kHardenedBoolTrue);

  // Indicate whether the key will be sideloaded.
  hardened_bool_t sideload_written = kHardenedBoolFalse;
  switch (launder32(key.sideload)) {
    case kHardenedBoolTrue:
      HARDENED_CHECK_EQ(key.sideload, kHardenedBoolTrue);
      *ctrl_reg =
          bitfield_bit32_write(*ctrl_reg, AES_CTRL_SHADOWED_SIDELOAD_BIT, true);
      sideload_written = launder32(kHardenedBoolTrue);
      break;
    case kHardenedBoolFalse:
      HARDENED_CHECK_EQ(key.sideload, kHardenedBoolFalse);
      *ctrl_reg = bitfield_bit32_write(*ctrl_reg,
                                       AES_CTRL_SHADOWED_SIDELOAD_BIT, false);
      sideload_written = launder32(kHardenedBoolTrue);
      break;
    default:
      // Invalid value.
      return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(sideload_written, kHardenedBoolTrue);

  *ctrl_reg = bitfield_field32_write(*ctrl_reg, AES_CTRL_SHADOWED_MODE_FIELD,
                                     AES_CTRL_SHADOWED_MODE_VALUE_AES_GCM);

  // Translate the key length to the hardware-encoding value and write the
  // control reg field.
  hardened_bool_t len_written = kHardenedBoolFalse;
  switch (launder32(key.key_len)) {
    case kAesKeyWordLen128:
      HARDENED_CHECK_EQ(key.key_len, kAesKeyWordLen128);
      *ctrl_reg =
          bitfield_field32_write(*ctrl_reg, AES_CTRL_SHADOWED_KEY_LEN_FIELD,
                                 AES_CTRL_SHADOWED_KEY_LEN_VALUE_AES_128);
      len_written = launder32(kHardenedBoolTrue);
      break;
    case kAesKeyWordLen192:
      HARDENED_CHECK_EQ(key.key_len, kAesKeyWordLen192);
      *ctrl_reg =
          bitfield_field32_write(*ctrl_reg, AES_CTRL_SHADOWED_KEY_LEN_FIELD,
                                 AES_CTRL_SHADOWED_KEY_LEN_VALUE_AES_192);
      len_written = launder32(kHardenedBoolTrue);
      break;
    case kAesKeyWordLen256:
      HARDENED_CHECK_EQ(key.key_len, kAesKeyWordLen256);
      *ctrl_reg =
          bitfield_field32_write(*ctrl_reg, AES_CTRL_SHADOWED_KEY_LEN_FIELD,
                                 AES_CTRL_SHADOWED_KEY_LEN_VALUE_AES_256);
      len_written = launder32(kHardenedBoolTrue);
      break;
    default:
      // Invalid value.
      return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(len_written, kHardenedBoolTrue);

  // Never enable manual operation.
  *ctrl_reg = bitfield_bit32_write(
      *ctrl_reg, AES_CTRL_SHADOWED_MANUAL_OPERATION_BIT, false);

  // Always set the PRNG reseed rate to once per 64 blocks.
  *ctrl_reg = bitfield_field32_write(
      *ctrl_reg, AES_CTRL_SHADOWED_PRNG_RESEED_RATE_FIELD,
      AES_CTRL_SHADOWED_PRNG_RESEED_RATE_VALUE_PER_64);

  return OTCRYPTO_OK;
}

/**
 * Switches to a GCM phase. Waits for the AES block to be idle first.
 *
 * @param phase The phase to enter.
 * @param num_valid_bytes Number of valid bytes (1 to 16) in the next input
 *        block; only the last block of the AAD and data phases may be partial.
 * @return result, OK or error.
 */
OT_WARN_UNUSED_RESULT
static status_t set_phase(aes_gcm_hw_phase_t phase, size_t num_valid_bytes) {
  if (num_valid_bytes == 0 || num_valid_bytes > kAesBlockNumBytes) {
    return OTCRYPTO_BAD_ARGS;
  }

  switch (phase) {
    case kAesGcmHwPhaseInit:
    case kAesGcmHwPhaseRestore:
    case kAesGcmHwPhaseAad:
    case kAesGcmHwPhaseText:
    case kAesGcmHwPhaseSave:
    case kAesGcmHwPhaseTag:
      break;
    default:
      return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_TRY(spin_until(AES_STATUS_IDLE_BIT));

  uint32_t reg = bitfield_field32_write(
      0, AES_CTRL_GCM_SHADOWED_NUM_VALID_BYTES_FIELD, num_valid_bytes);
  reg = bitfield_field32_write(reg, AES_CTRL_GCM_SHADOWED_PHASE_FIELD, phase);
  abs_mmio_write32_shadowed(aes_base() + AES_CTRL_GCM_SHADOWED_REG_OFFSET, reg);

  // The hardware ignores phase transitions it does not allow. Check that the
  // write was accepted.
  uint32_t readback =
      abs_mmio_read32(aes_base() + AES_CTRL_GCM_SHADOWED_REG_OFFSET);
  if (launder32(readback) != reg) {
    return OTCRYPTO_RECOV_ERR;
  }
  HARDENED_CHECK_EQ(
      abs_mmio_read32(aes_base() + AES_CTRL_GCM_SHADOWED_REG_OFFSET), reg);
  return OTCRYPTO_OK;
}

/**
 * Writes one input block (AAD, data, lengths or GHASH state, depending on the
 * phase). Waits until the AES block is ready for input. A partial block must
 * be zero-padded.
 *
 * @param src The input block.
 * @return result, OK or error.
 */
OT_WARN_UNUSED_RESULT
static status_t input_block(const aes_block_t *src) {
  HARDENED_TRY(spin_until(AES_STATUS_INPUT_READY_BIT));
  hardened_mmio_write(aes_base() + AES_DATA_IN_0_REG_OFFSET, src->data,
                      ARRAYSIZE(src->data));
  return OTCRYPTO_OK;
}

/**
 * Reads one output block (data, tag or GHASH state, depending on the phase).
 * Waits until the output is valid.
 *
 * @param[out] dest The output block.
 * @return result, OK or error.
 */
OT_WARN_UNUSED_RESULT
static status_t output_block(aes_block_t *dest) {
  // Randomize the destination buffer before the output lands in it.
  hardened_memshred(dest->data, ARRAYSIZE(dest->data));
  HARDENED_TRY(spin_until(AES_STATUS_OUTPUT_VALID_BIT));
  hardened_mmio_read(dest->data, aes_base() + AES_DATA_OUT_0_REG_OFFSET,
                     ARRAYSIZE(dest->data));
  return OTCRYPTO_OK;
}

status_t aes_gcm_hw_available(hardened_bool_t *available) {
  if (available == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }
  *available = kHardenedBoolFalse;

  // Wait for the AES block to be idle.
  HARDENED_TRY(spin_until(AES_STATUS_IDLE_BIT));

  // Try to select GCM mode. If GCM support is compiled out, the hardware maps
  // the GCM mode value to AES_NONE.
  aes_key_t key = {
      .mode = kAesCipherModeCtr,
      .sideload = kHardenedBoolFalse,
      .key_len = kAesKeyWordLen128,
      .key_shares = {NULL, NULL},
  };
  uint32_t ctrl_reg;
  HARDENED_TRY(compute_ctrl_reg(key, kHardenedBoolTrue, &ctrl_reg));
  abs_mmio_write32_shadowed(aes_base() + AES_CTRL_SHADOWED_REG_OFFSET,
                            ctrl_reg);
  status_t result = spin_until(AES_STATUS_IDLE_BIT);
  if (status_ok(result)) {
    uint32_t readback =
        abs_mmio_read32(aes_base() + AES_CTRL_SHADOWED_REG_OFFSET);
    if (bitfield_field32_read(readback, AES_CTRL_SHADOWED_MODE_FIELD) ==
        AES_CTRL_SHADOWED_MODE_VALUE_AES_GCM) {
      *available = kHardenedBoolTrue;
    }
  }

  // Always clear the AES block, but report the first error.
  status_t end_result = aes_gcm_hw_end();
  HARDENED_TRY(result);
  return end_result;
}

/**
 * Starts a GCM operation; see `aes_gcm_hw_encrypt_begin()`.
 *
 * @param key AES key.
 * @param iv IV; words 0 to 2 hold the 96-bit IV, word 3 is ignored.
 * @param encrypt True for encryption, false for decryption.
 * @return result, OK or error.
 */
OT_WARN_UNUSED_RESULT
static status_t gcm_begin(const aes_key_t key, const aes_block_t *iv,
                          hardened_bool_t encrypt) {
  if (iv == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }

  // GCM keys are CTR keys, as for the software implementation.
  if (launder32(key.mode) != kAesCipherModeCtr) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(key.mode, kAesCipherModeCtr);

  // Ensure the entropy complex is in an appropriate state. The AES block seeds
  // its PRNG from EDN for masking every time a new key is provided.
  HARDENED_TRY(entropy_complex_check());

  // Wait for the AES block to be idle.
  HARDENED_TRY(spin_until(AES_STATUS_IDLE_BIT));

  uint32_t ctrl_reg;
  HARDENED_TRY(compute_ctrl_reg(key, encrypt, &ctrl_reg));
  abs_mmio_write32_shadowed(aes_base() + AES_CTRL_SHADOWED_REG_OFFSET,
                            launder32(ctrl_reg));
  HARDENED_TRY(spin_until(AES_STATUS_IDLE_BIT));

  // Check that GCM mode has been accepted, otherwise the hardware does not
  // support GCM.
  uint32_t readback =
      abs_mmio_read32(aes_base() + AES_CTRL_SHADOWED_REG_OFFSET);
  if (bitfield_field32_read(readback, AES_CTRL_SHADOWED_MODE_FIELD) !=
      AES_CTRL_SHADOWED_MODE_VALUE_AES_GCM) {
    return OTCRYPTO_NOT_IMPLEMENTED;
  }

  // Verify the CTRL and CTRL_AUX registers.
  HARDENED_CHECK_EQ(abs_mmio_read32(aes_base() + AES_CTRL_SHADOWED_REG_OFFSET),
                    launder32(ctrl_reg));
  HARDENED_TRY(aes_verify_ctrl_aux_reg());

  // Start in the initialization phase.
  HARDENED_TRY(set_phase(kAesGcmHwPhaseInit, kAesBlockNumBytes));

  // Write the key (if it is not sideloaded).
  HARDENED_TRY(write_key(key));

  // Write the IV.
  // The last word is the counter, which the hardware derives from the IV.
  uint32_t iv_offset = aes_base() + AES_IV_0_REG_OFFSET;
  for (size_t i = 0; i < kAesGcmHwIvNumWords; ++i) {
    abs_mmio_write32(iv_offset + i * sizeof(uint32_t), iv->data[i]);
  }
  abs_mmio_write32(iv_offset + kAesGcmHwIvNumWords * sizeof(uint32_t), 0);

  // Wait for hardware to derive key and encrypt IV.
  HARDENED_TRY(spin_until(AES_STATUS_IDLE_BIT));

  // Check that AES is ready to receive input data.
  uint32_t status = abs_mmio_read32(aes_base() + AES_STATUS_REG_OFFSET);
  if (!bitfield_bit32_read(launder32(status), AES_STATUS_INPUT_READY_BIT)) {
    return OTCRYPTO_RECOV_ERR;
  }
  HARDENED_CHECK_EQ(
      bitfield_bit32_read(abs_mmio_read32(aes_base() + AES_STATUS_REG_OFFSET),
                          AES_STATUS_INPUT_READY_BIT),
      true);

  return OTCRYPTO_OK;
}

status_t aes_gcm_hw_encrypt_begin(const aes_key_t key, const aes_block_t *iv) {
  return gcm_begin(key, iv, kHardenedBoolTrue);
}

status_t aes_gcm_hw_decrypt_begin(const aes_key_t key, const aes_block_t *iv) {
  return gcm_begin(key, iv, kHardenedBoolFalse);
}

/**
 * Sends one block of input and, if `out` is not null, reads its output.
 *
 * @param in Input bytes.
 * @param len Number of bytes in the block (1 to 16); the rest is zero-padded.
 * @param[out] out Output bytes (`len` bytes), or null.
 * @return result, OK or error.
 */
OT_WARN_UNUSED_RESULT
static status_t process_block(const uint8_t *in, size_t len, uint8_t *out) {
  // local `block` because in/out may be unaligned.
  aes_block_t block = {.data = {0}};
  memcpy(block.data, in, len);
  status_t result = input_block(&block);
  if (status_ok(result) && out != NULL) {
    result = output_block(&block);
    if (status_ok(result)) {
      memcpy(out, block.data, len);
    }
  }

  hardened_memshred(block.data, ARRAYSIZE(block.data));
  HARDENED_TRY(result);
  return OTCRYPTO_OK;
}

status_t aes_gcm_hw_process(aes_gcm_hw_phase_t phase, size_t len,
                            const uint8_t *in, uint8_t *out) {
  if (phase != kAesGcmHwPhaseAad && phase != kAesGcmHwPhaseText) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (len == 0) {
    return OTCRYPTO_OK;
  }
  if (in == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }

  size_t done = 0;
  while (launder32(done) < len) {
    size_t n = len - done > kAesBlockNumBytes ? kAesBlockNumBytes : len - done;
    // Enter the phase before the first block, and before a partial last block
    // to set the correct number of valid bytes.
    if (done == 0 || n < kAesBlockNumBytes) {
      HARDENED_TRY(set_phase(phase, n));
    }
    HARDENED_TRY(process_block(in + done, n, out == NULL ? NULL : out + done));
    done += n;
  }
  HARDENED_CHECK_EQ(done, len);
  return OTCRYPTO_OK;
}

/**
 * Reads the GCM context; see `aes_gcm_hw_save()`. The caller clears the AES
 * block.
 */
OT_WARN_UNUSED_RESULT
static status_t gcm_save(aes_block_t *ghash_state, aes_block_t *iv) {
  HARDENED_TRY(set_phase(kAesGcmHwPhaseSave, kAesBlockNumBytes));
  HARDENED_TRY(output_block(ghash_state));
  HARDENED_TRY(spin_until(AES_STATUS_IDLE_BIT));
  uint32_t iv_offset = aes_base() + AES_IV_0_REG_OFFSET;
  for (size_t i = 0; i < ARRAYSIZE(iv->data); ++i) {
    iv->data[i] = abs_mmio_read32(iv_offset + i * sizeof(uint32_t));
  }
  return OTCRYPTO_OK;
}

status_t aes_gcm_hw_save(aes_block_t *ghash_state, aes_block_t *iv) {
  if (ghash_state == NULL || iv == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }
  status_t result = gcm_save(ghash_state, iv);

  // Always clear the AES block, but report the first error.
  status_t end_result = aes_gcm_hw_end();
  HARDENED_TRY(result);
  return end_result;
}

status_t aes_gcm_hw_restore(const aes_key_t key, hardened_bool_t encrypt,
                            const aes_block_t *ghash_state,
                            const aes_block_t *iv, aes_gcm_hw_phase_t phase) {
  if (ghash_state == NULL || iv == NULL ||
      (phase != kAesGcmHwPhaseAad && phase != kAesGcmHwPhaseText)) {
    return OTCRYPTO_BAD_ARGS;
  }
  // Start over with the original IV, so that the initialization phase derives
  // the hash subkey and the start counter.
  // `gcm_begin` ignores the counter (fourth word of `iv`).
  HARDENED_TRY(gcm_begin(key, iv, encrypt));

  // Load the saved GHASH state.
  HARDENED_TRY(set_phase(kAesGcmHwPhaseRestore, kAesBlockNumBytes));
  HARDENED_TRY(input_block(ghash_state));
  HARDENED_TRY(spin_until(AES_STATUS_IDLE_BIT));
  // Load the IV register, including the counter of the data processed so far.
  uint32_t iv_offset = aes_base() + AES_IV_0_REG_OFFSET;
  for (size_t i = 0; i < ARRAYSIZE(iv->data); ++i) {
    abs_mmio_write32(iv_offset + i * sizeof(uint32_t), iv->data[i]);
  }
  // Switch to `phase`.
  return set_phase(phase, kAesBlockNumBytes);
}

status_t aes_gcm_hw_tag(size_t aad_len, size_t data_len, aes_block_t *tag) {
  if (tag == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_TRY(set_phase(kAesGcmHwPhaseTag, kAesBlockNumBytes));

  // The hardware expects len(aad) || len(data), in bits, big-endian.
  uint64_t aad_bits = (uint64_t)aad_len * 8;
  uint64_t data_bits = (uint64_t)data_len * 8;
  aes_block_t lengths = {.data = {
                             __builtin_bswap32((uint32_t)(aad_bits >> 32)),
                             __builtin_bswap32((uint32_t)aad_bits),
                             __builtin_bswap32((uint32_t)(data_bits >> 32)),
                             __builtin_bswap32((uint32_t)data_bits),
                         }};
  HARDENED_TRY(input_block(&lengths));
  return output_block(tag);
}

status_t aes_gcm_hw_verify_ctrl(const aes_key_t key, hardened_bool_t encrypt) {
  uint32_t ctrl_reg;

  HARDENED_TRY(compute_ctrl_reg(key, encrypt, &ctrl_reg));
  HARDENED_CHECK_EQ(abs_mmio_read32(aes_base() + AES_CTRL_SHADOWED_REG_OFFSET),
                    launder32(ctrl_reg));

  return aes_verify_ctrl_aux_reg();
}

status_t aes_gcm_hw_end(void) {
  // CTRL is only writable while the AES block is idle.
  // A valid ctrl write would clear a recoverable error.
  // Remember idle_result, clear in any case, then return idle_result.
  status_t idle_result = spin_until(AES_STATUS_IDLE_BIT);
  status_t result = aes_end(NULL);
  HARDENED_TRY(idle_result);
  return result;
}

/**
 * Runs the phases of a one-shot operation; the AES block must be started.
 */
OT_WARN_UNUSED_RESULT
static status_t crypt_phases(const aes_key_t key, hardened_bool_t encrypt,
                             size_t aad_len, const uint8_t *aad,
                             size_t data_len, const uint8_t *data_in,
                             uint8_t *data_out, aes_block_t *tag) {
  HARDENED_TRY(aes_gcm_hw_process(kAesGcmHwPhaseAad, aad_len, aad, NULL));
  HARDENED_TRY(
      aes_gcm_hw_process(kAesGcmHwPhaseText, data_len, data_in, data_out));
  HARDENED_TRY(aes_gcm_hw_verify_ctrl(key, encrypt));
  return aes_gcm_hw_tag(aad_len, data_len, tag);
}

/**
 * One-shot AES-GCM encryption or decryption; see `aes_gcm_hw_encrypt()`.
 */
OT_WARN_UNUSED_RESULT
static status_t gcm_crypt(const aes_key_t key, const aes_block_t *iv,
                          hardened_bool_t encrypt, size_t aad_len,
                          const uint8_t *aad, size_t data_len,
                          const uint8_t *data_in, uint8_t *data_out,
                          aes_block_t *tag) {
  if (tag == NULL || (data_len != 0 && data_out == NULL)) {
    return OTCRYPTO_BAD_ARGS;
  }

  status_t result = gcm_begin(key, iv, encrypt);
  if (status_ok(result)) {
    result = crypt_phases(key, encrypt, aad_len, aad, data_len, data_in,
                          data_out, tag);
  }

  // Clear the AES block, but report the first error.
  status_t end_result = aes_gcm_hw_end();
  HARDENED_TRY(result);
  return end_result;
}

status_t aes_gcm_hw_encrypt(const aes_key_t key, const aes_block_t *iv,
                            size_t aad_len, const uint8_t *aad, size_t data_len,
                            const uint8_t *plaintext, uint8_t *ciphertext,
                            aes_block_t *tag) {
  return gcm_crypt(key, iv, kHardenedBoolTrue, aad_len, aad, data_len,
                   plaintext, ciphertext, tag);
}

status_t aes_gcm_hw_decrypt(const aes_key_t key, const aes_block_t *iv,
                            size_t aad_len, const uint8_t *aad, size_t data_len,
                            const uint8_t *ciphertext, uint8_t *plaintext,
                            aes_block_t *tag) {
  return gcm_crypt(key, iv, kHardenedBoolFalse, aad_len, aad, data_len,
                   ciphertext, plaintext, tag);
}
