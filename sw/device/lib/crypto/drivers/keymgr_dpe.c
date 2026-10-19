// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/crypto/drivers/keymgr_dpe.h"

#include "hw/top/dt/keymgr_dpe.h"
#include "sw/device/lib/base/abs_mmio.h"
#include "sw/device/lib/base/bitfield.h"
#include "sw/device/lib/base/hardened_memory.h"
#include "sw/device/lib/base/memory.h"
#include "sw/device/lib/crypto/drivers/entropy.h"
#include "sw/device/lib/crypto/impl/status.h"
#include "sw/device/lib/runtime/hart.h"

#include "hw/top/keymgr_dpe_regs.h"

// Module ID for status codes.
#define MODULE_ID MAKE_MODULE_ID('d', 'k', 'd')

enum {
  // Microseconds to leave the sideload-clear bit set. This value is probably
  // overkill, since theoretically one cycle is enough if entropy is available.
  kSideloadClearWaitMicros = 100,
};

static const dt_keymgr_dpe_t kKeymgrDpeDt = kDtKeymgrDpe;

static inline uint32_t keymgr_dpe_base(void) {
  return dt_keymgr_dpe_primary_reg_block(kKeymgrDpeDt);
}

static_assert(kKeymgrSaltNumWords == KEYMGR_DPE_SALT_MULTIREG_COUNT,
              "Number of salt registers does not match.");
static_assert(kKeymgrOutputShareNumWords ==
                  KEYMGR_DPE_SW_SHARE0_OUTPUT_MULTIREG_COUNT,
              "Number of output share 0 registers does not match.");
static_assert(kKeymgrOutputShareNumWords ==
                  KEYMGR_DPE_SW_SHARE1_OUTPUT_MULTIREG_COUNT,
              "Number of output share 1 registers does not match.");

/**
 * Fails if the keymgr_dpe is not idle.
 *
 * @return OK if the key manager is idle, OTCRYPTO_RECOV_ERR otherwise.
 */
OT_WARN_UNUSED_RESULT
static status_t keymgr_dpe_is_idle(void) {
  uint32_t reg =
      abs_mmio_read32(keymgr_dpe_base() + KEYMGR_DPE_OP_STATUS_REG_OFFSET);
  uint32_t status =
      bitfield_field32_read(reg, KEYMGR_DPE_OP_STATUS_STATUS_FIELD);
  if (launder32(status) == KEYMGR_DPE_OP_STATUS_STATUS_VALUE_IDLE) {
    HARDENED_CHECK_EQ(status, KEYMGR_DPE_OP_STATUS_STATUS_VALUE_IDLE);
    return OTCRYPTO_OK;
  }
  return OTCRYPTO_RECOV_ERR;
}

/**
 * Set diversification input and start the key manager operation.
 *
 * Ensure the key manager is idle before calling this function.
 *
 * @param diversification Diversification input for the key derivation.
 */
static void keymgr_dpe_start(keymgr_diversification_t diversification) {
  const uint32_t kBase = keymgr_dpe_base();
  // Set the version.
  abs_mmio_write32(kBase + KEYMGR_DPE_KEY_VERSION_REG_OFFSET,
                   diversification.version);
  // Set the salt.
  hardened_mmio_write(kBase + KEYMGR_DPE_SALT_0_REG_OFFSET,
                      diversification.salt, kKeymgrSaltNumWords);

  // Issue the start command.
  abs_mmio_write32(kBase + KEYMGR_DPE_START_REG_OFFSET,
                   1 << KEYMGR_DPE_START_EN_BIT);
}

/**
 * Wait for the key manager to finish an operation.
 *
 * Polls the key manager until it is no longer busy. If the operation completed
 * successfully, returns OTCRYPTO_OK. If there was an error during the
 * operation, reads and clears the error code and returns OTCRYPTO_RECOV_ERR;
 * the operation can be retried afterwards.
 *
 * This function assumes an operation has already been started by the caller.
 * The function traps if the keymgr_dpe is already idle.
 *
 * @return OK or error.
 */
OT_WARN_UNUSED_RESULT
static status_t keymgr_dpe_wait_until_done(void) {
  // Poll the OP_STATUS register until it is something other than "WIP".
  uint32_t reg;
  uint32_t status;
  do {
    reg = abs_mmio_read32(keymgr_dpe_base() + KEYMGR_DPE_OP_STATUS_REG_OFFSET);
    status = bitfield_field32_read(reg, KEYMGR_DPE_OP_STATUS_STATUS_FIELD);
  } while (status == KEYMGR_DPE_OP_STATUS_STATUS_VALUE_WIP);

  // Clear OP_STATUS by writing back the value we read.
  abs_mmio_write32(keymgr_dpe_base() + KEYMGR_DPE_OP_STATUS_REG_OFFSET, reg);

  // Check that the value was cleared (doubles as a read-back check).
  HARDENED_CHECK_EQ(
      abs_mmio_read32(keymgr_dpe_base() + KEYMGR_DPE_OP_STATUS_REG_OFFSET), 0);

  // Check if the key manager reported errors. If it completed an operation
  // successfully, return an OK status. No other statuses (e.g. WIP) should
  // be possible.
  // The `IDLE` status is left unhandled because the keymgr_dpe should never be
  // idle after an operation has been started by the caller.
  switch (status) {
    case KEYMGR_DPE_OP_STATUS_STATUS_VALUE_DONE_SUCCESS:
      HARDENED_CHECK_EQ(status, KEYMGR_DPE_OP_STATUS_STATUS_VALUE_DONE_SUCCESS);
      return OTCRYPTO_OK;
    case KEYMGR_DPE_OP_STATUS_STATUS_VALUE_DONE_ERROR: {
      // Clear the ERR_CODE register before returning.
      uint32_t err_code =
          abs_mmio_read32(keymgr_dpe_base() + KEYMGR_DPE_ERR_CODE_REG_OFFSET);
      abs_mmio_write32(keymgr_dpe_base() + KEYMGR_DPE_ERR_CODE_REG_OFFSET,
                       err_code);
      return OTCRYPTO_RECOV_ERR;
    }
    default: {
      // Should be unreachable.
      HARDENED_TRAP();
      return OTCRYPTO_FATAL_ERR;
    }
  }
}

/**
 * Set the control register of the key manager.
 *
 * @param dest (NONE, AES, ACC, or KMAC)
 * @param operation (GENERATE_SW or GENERATE_HW)
 * @param slot Key Manager DPE slot to source the key material from.
 */
#define WRITE_CTRL(dest, operation, slot)                                  \
  do {                                                                     \
    uint32_t ctrl = bitfield_field32_write(                                \
        0, KEYMGR_DPE_CONTROL_SHADOWED_DEST_SEL_FIELD,                     \
        KEYMGR_DPE_CONTROL_SHADOWED_DEST_SEL_VALUE_##dest);                \
    ctrl = bitfield_field32_write(                                         \
        ctrl, KEYMGR_DPE_CONTROL_SHADOWED_SLOT_SRC_SEL_FIELD, (slot));     \
    ctrl = bitfield_field32_write(                                         \
        ctrl, KEYMGR_DPE_CONTROL_SHADOWED_OPERATION_FIELD,                 \
        KEYMGR_DPE_CONTROL_SHADOWED_OPERATION_VALUE_##operation##_OUTPUT); \
    abs_mmio_write32_shadowed(                                             \
        keymgr_dpe_base() + KEYMGR_DPE_CONTROL_SHADOWED_REG_OFFSET, ctrl); \
  } while (false);

/**
 * Verify the control register of the key manager.
 *
 * @param dest (NONE, AES, ACC, or KMAC)
 * @param operation (GENERATE_SW or GENERATE_HW)
 * @param slot Key Manager DPE slot to source the key material from.
 */
#define VERIFY_CTRL(dest, operation, slot)                                     \
  do {                                                                         \
    uint32_t ctrl = bitfield_field32_write(                                    \
        0, KEYMGR_DPE_CONTROL_SHADOWED_DEST_SEL_FIELD,                         \
        KEYMGR_DPE_CONTROL_SHADOWED_DEST_SEL_VALUE_##dest);                    \
    ctrl = bitfield_field32_write(                                             \
        ctrl, KEYMGR_DPE_CONTROL_SHADOWED_SLOT_SRC_SEL_FIELD, (slot));         \
    ctrl = bitfield_field32_write(                                             \
        ctrl, KEYMGR_DPE_CONTROL_SHADOWED_OPERATION_FIELD,                     \
        KEYMGR_DPE_CONTROL_SHADOWED_OPERATION_VALUE_##operation##_OUTPUT);     \
    HARDENED_CHECK_EQ(abs_mmio_read32(keymgr_dpe_base() +                      \
                                      KEYMGR_DPE_CONTROL_SHADOWED_REG_OFFSET), \
                      ctrl);                                                   \
  } while (false);

status_t keymgr_generate_key_sw(keymgr_diversification_t diversification,
                                keymgr_slot_t slot, keymgr_output_t *key) {
  // Ensure that the entropy complex has been initialized and keymgr_dpe is
  // idle.
  HARDENED_TRY(entropy_complex_check());
  HARDENED_TRY(keymgr_dpe_is_idle());

  // Set the control register to generate a software-visible key.
  WRITE_CTRL(NONE, GENERATE_SW, slot);

  // Start the operation and wait for it to complete.
  keymgr_dpe_start(diversification);
  HARDENED_TRY(keymgr_dpe_wait_until_done());

  // Check the control register.
  VERIFY_CTRL(NONE, GENERATE_SW, slot);

  // Randomize the destination buffer.
  hardened_memshred(key->share0, kKeymgrOutputShareNumWords);
  hardened_memshred(key->share1, kKeymgrOutputShareNumWords);

  // Collect output.
  hardened_mmio_read(
      key->share0, keymgr_dpe_base() + KEYMGR_DPE_SW_SHARE0_OUTPUT_0_REG_OFFSET,
      kKeymgrOutputShareNumWords);
  hardened_mmio_read(
      key->share1, keymgr_dpe_base() + KEYMGR_DPE_SW_SHARE1_OUTPUT_0_REG_OFFSET,
      kKeymgrOutputShareNumWords);

  return OTCRYPTO_OK;
}

status_t keymgr_generate_key_aes(keymgr_diversification_t diversification,
                                 keymgr_slot_t slot) {
  // Ensure that the entropy complex has been initialized and keymgr_dpe is
  // idle.
  HARDENED_TRY(entropy_complex_check());
  HARDENED_TRY(keymgr_dpe_is_idle());

  // Set the control register to generate an AES key.
  WRITE_CTRL(AES, GENERATE_HW, slot);

  // Start the operation and wait for it to complete.
  keymgr_dpe_start(diversification);
  HARDENED_TRY(keymgr_dpe_wait_until_done());
  // Check the control register.
  VERIFY_CTRL(AES, GENERATE_HW, slot);

  return OTCRYPTO_OK;
}

status_t keymgr_generate_key_kmac(keymgr_diversification_t diversification,
                                  keymgr_slot_t slot) {
  // Ensure that the entropy complex has been initialized and keymgr_dpe is
  // idle.
  HARDENED_TRY(entropy_complex_check());
  HARDENED_TRY(keymgr_dpe_is_idle());

  // Set the control register to generate a KMAC key.
  WRITE_CTRL(KMAC, GENERATE_HW, slot);

  // Start the operation and wait for it to complete.
  keymgr_dpe_start(diversification);
  HARDENED_TRY(keymgr_dpe_wait_until_done());
  // Check the control register.
  VERIFY_CTRL(KMAC, GENERATE_HW, slot);
  return OTCRYPTO_OK;
}

status_t keymgr_generate_key_acc(keymgr_diversification_t diversification,
                                 keymgr_slot_t slot) {
  // Ensure that the entropy complex has been initialized and keymgr_dpe is
  // idle.
  HARDENED_TRY(entropy_complex_check());
  HARDENED_TRY(keymgr_dpe_is_idle());

  // Set the control register to generate an ACC key.
  WRITE_CTRL(ACC, GENERATE_HW, slot);

  // Start the operation and wait for it to complete.
  keymgr_dpe_start(diversification);
  HARDENED_TRY(keymgr_dpe_wait_until_done());
  // Check the control register.
  VERIFY_CTRL(ACC, GENERATE_HW, slot);
  return OTCRYPTO_OK;
}

/**
 * Clear the requested sideload slot.
 *
 * The `slot` parameter should be one of:
 *   - KEYMGR_DPE_SIDELOAD_CLEAR_VAL_VALUE_AES
 *   - KEYMGR_DPE_SIDELOAD_CLEAR_VAL_VALUE_KMAC
 *   - KEYMGR_DPE_SIDELOAD_CLEAR_VAL_VALUE_ACC
 *
 * @param slot Value to write to the SIDELOAD_CLEAR register.
 */
OT_WARN_UNUSED_RESULT
static status_t keymgr_dpe_sideload_clear(uint32_t slot) {
  // Ensure that the entropy complex has been initialized and keymgr_dpe is
  // idle.
  HARDENED_TRY(entropy_complex_check());
  HARDENED_TRY(keymgr_dpe_is_idle());

  // Set SIDELOAD_CLEAR to begin continuously clearing the requested slot.
  abs_mmio_write32(
      keymgr_dpe_base() + KEYMGR_DPE_SIDELOAD_CLEAR_REG_OFFSET,
      bitfield_field32_write(0, KEYMGR_DPE_SIDELOAD_CLEAR_VAL_FIELD, slot));

  // Read back the value (FI hardening measure).
  uint32_t sideload_clear =
      abs_mmio_read32(keymgr_dpe_base() + KEYMGR_DPE_SIDELOAD_CLEAR_REG_OFFSET);
  HARDENED_CHECK_EQ(bitfield_field32_read(sideload_clear,
                                          KEYMGR_DPE_SIDELOAD_CLEAR_VAL_FIELD),
                    slot);

  // Wait for a bit to ensure the slot has time to clear.
  busy_spin_micros(kSideloadClearWaitMicros);

  // Stop continuous clearing.
  abs_mmio_write32(
      keymgr_dpe_base() + KEYMGR_DPE_SIDELOAD_CLEAR_REG_OFFSET,
      bitfield_field32_write(0, KEYMGR_DPE_SIDELOAD_CLEAR_VAL_FIELD,
                             KEYMGR_DPE_SIDELOAD_CLEAR_VAL_VALUE_NONE));

  return OTCRYPTO_OK;
}

status_t keymgr_sideload_clear_aes(void) {
  return keymgr_dpe_sideload_clear(KEYMGR_DPE_SIDELOAD_CLEAR_VAL_VALUE_AES);
}

status_t keymgr_sideload_clear_kmac(void) {
  return keymgr_dpe_sideload_clear(KEYMGR_DPE_SIDELOAD_CLEAR_VAL_VALUE_KMAC);
}

status_t keymgr_sideload_clear_acc(void) {
  return keymgr_dpe_sideload_clear(KEYMGR_DPE_SIDELOAD_CLEAR_VAL_VALUE_ACC);
}
