// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/silicon_creator/lib/drivers/keymgr_dpe.h"

#include <assert.h>

#include "hw/top/dt/keymgr_dpe.h"
#include "sw/device/lib/base/abs_mmio.h"
#include "sw/device/lib/base/macros.h"
#include "sw/device/lib/runtime/hart.h"
#include "sw/device/silicon_creator/lib/base/sec_mmio.h"

#include "hw/top/keymgr_dpe_regs.h"  // Generated.

#define KEYMGR_DPE_ASSERT(a, b) static_assert(a == b, "Bad value for " #a)
KEYMGR_DPE_ASSERT(kScKeymgrDpeStateReset,
                  KEYMGR_DPE_WORKING_STATE_STATE_VALUE_RESET);
KEYMGR_DPE_ASSERT(kScKeymgrDpeStateAvailable,
                  KEYMGR_DPE_WORKING_STATE_STATE_VALUE_AVAILABLE);
KEYMGR_DPE_ASSERT(kScKeymgrDpeStateDisabled,
                  KEYMGR_DPE_WORKING_STATE_STATE_VALUE_DISABLED);
KEYMGR_DPE_ASSERT(kScKeymgrDpeStateInvalid,
                  KEYMGR_DPE_WORKING_STATE_STATE_VALUE_INVALID);

/**
 * Base address of the keymgr_dpe registers.
 */
static inline uint32_t sc_keymgr_dpe_base(void) {
  return dt_keymgr_dpe_reg_block(kDtKeymgrDpe, kDtKeymgrDpeRegBlockCore);
}

/**
 * Checks the key manager `expected_state`.
 *
 * This function reads and clears the status and error code registers.
 *
 * @return `kErrorOk` if the key manager is at the `expected_state` and the
 * status is idle or success.
 */
OT_WARN_UNUSED_RESULT
static rom_error_t expected_state_check(uint32_t expected_state) {
  // Read and clear the status register by writing back the read value,
  // polling until the status is non-WIP.
  uint32_t op_status;
  uint32_t op_status_field;
  do {
    op_status =
        abs_mmio_read32(sc_keymgr_dpe_base() + KEYMGR_DPE_OP_STATUS_REG_OFFSET);
    abs_mmio_write32(sc_keymgr_dpe_base() + KEYMGR_DPE_OP_STATUS_REG_OFFSET,
                     op_status);
    op_status_field =
        bitfield_field32_read(op_status, KEYMGR_DPE_OP_STATUS_STATUS_FIELD);
  } while (op_status_field == KEYMGR_DPE_OP_STATUS_STATUS_VALUE_WIP ||
           op_status_field == KEYMGR_DPE_OP_STATUS_STATUS_VALUE_DONE_SUCCESS);

  // Read and clear the error register by writing back the read value.
  uint32_t error_code =
      abs_mmio_read32(sc_keymgr_dpe_base() + KEYMGR_DPE_ERR_CODE_REG_OFFSET);
  abs_mmio_write32(sc_keymgr_dpe_base() + KEYMGR_DPE_ERR_CODE_REG_OFFSET,
                   error_code);

  uint32_t got_state = sec_mmio_read32(sc_keymgr_dpe_base() +
                                       KEYMGR_DPE_WORKING_STATE_REG_OFFSET);
  if (op_status_field == KEYMGR_DPE_OP_STATUS_STATUS_VALUE_IDLE &&
      error_code == 0u && got_state == expected_state) {
    return kErrorOk;
  }
  return kErrorKeymgrInternal;
}

void sc_keymgr_dpe_entropy_reseed_interval_set(
    uint16_t entropy_reseed_interval) {
  SEC_MMIO_ASSERT_WRITE_INCREMENT(kScKeymgrDpeSecMmioEntropyReseedIntervalSet,
                                  1);
  uint32_t reg =
      bitfield_field32_write(0, KEYMGR_DPE_RESEED_INTERVAL_SHADOWED_VAL_FIELD,
                             entropy_reseed_interval);
  sec_mmio_write32_shadowed(
      sc_keymgr_dpe_base() + KEYMGR_DPE_RESEED_INTERVAL_SHADOWED_REG_OFFSET,
      reg);
}

void sc_keymgr_dpe_sw_binding_set(
    const keymgr_dpe_binding_value_t *binding_value) {
  SEC_MMIO_ASSERT_WRITE_INCREMENT(kScKeymgrDpeSecMmioSwBindingSet, 9);

  // Write and lock (rw0c) the software binding value. This register is unlocked
  // by hardware upon a successful state transition.
  for (size_t i = 0; i < ARRAYSIZE(binding_value->data); ++i) {
    sec_mmio_write32(sc_keymgr_dpe_base() + KEYMGR_DPE_SW_BINDING_0_REG_OFFSET +
                         i * sizeof(uint32_t),
                     binding_value->data[i]);
  }
  sec_mmio_write32(
      sc_keymgr_dpe_base() + KEYMGR_DPE_SW_BINDING_REGWEN_REG_OFFSET, 0);
}

void sc_keymgr_dpe_sw_binding_unlock_wait(void) {
  while (!abs_mmio_read32(sc_keymgr_dpe_base() +
                          KEYMGR_DPE_SW_BINDING_REGWEN_REG_OFFSET)) {
  }
  // Ignore the return value since this read is performed to check and update
  // the expected value.
  OT_DISCARD(sec_mmio_read32(sc_keymgr_dpe_base() +
                             KEYMGR_DPE_SW_BINDING_REGWEN_REG_OFFSET));
}

void sc_keymgr_dpe_max_ver_set(uint32_t max_key_ver) {
  SEC_MMIO_ASSERT_WRITE_INCREMENT(kScKeymgrDpeSecMmioMaxVerSet, 2);
  // Write and lock (rw0c) the max key version.
  sec_mmio_write32_shadowed(
      sc_keymgr_dpe_base() + KEYMGR_DPE_MAX_KEY_VER_SHADOWED_REG_OFFSET,
      max_key_ver);
  sec_mmio_write32(
      sc_keymgr_dpe_base() + KEYMGR_DPE_MAX_KEY_VER_REGWEN_REG_OFFSET, 0);
}

void sc_keymgr_dpe_max_ver_unlock_wait(void) {
  while (!abs_mmio_read32(sc_keymgr_dpe_base() +
                          KEYMGR_DPE_MAX_KEY_VER_REGWEN_REG_OFFSET)) {
  }
  // Ignore the return value since this read is performed to check and update
  // the expected value.
  OT_DISCARD(sec_mmio_read32(sc_keymgr_dpe_base() +
                             KEYMGR_DPE_MAX_KEY_VER_REGWEN_REG_OFFSET));
}

/**
 * Wait for the key manager to finish an operation.
 *
 * Polls the key manager until it is no longer busy. If the operation completed
 * successfully or the key manager was already idle, returns kErrorOk. If
 * there was an error during the operation, reads and clears the error code
 * and returns kErrorKeymgrInternal.
 *
 * @return OK or error.
 */
OT_WARN_UNUSED_RESULT
static rom_error_t keymgr_dpe_wait_until_done(void) {
  // Poll the OP_STATUS register until it is something other than "WIP".
  uint32_t reg;
  uint32_t status;
  do {
    // Read OP_STATUS and then clear by writing back the value we read.
    reg =
        abs_mmio_read32(sc_keymgr_dpe_base() + KEYMGR_DPE_OP_STATUS_REG_OFFSET);
    abs_mmio_write32(sc_keymgr_dpe_base() + KEYMGR_DPE_OP_STATUS_REG_OFFSET,
                     reg);
    status = bitfield_field32_read(reg, KEYMGR_DPE_OP_STATUS_STATUS_FIELD);
  } while (status == KEYMGR_DPE_OP_STATUS_STATUS_VALUE_WIP);

  // Check if the key manager reported errors. If it is already idle or
  // completed an operation successfully, return an OK status. A `WIP` status
  // should not be possible because of the check above.
  switch (launder32(status)) {
    case KEYMGR_DPE_OP_STATUS_STATUS_VALUE_IDLE:
      HARDENED_CHECK_EQ(status, KEYMGR_DPE_OP_STATUS_STATUS_VALUE_IDLE);
      return kErrorOk;
    case KEYMGR_DPE_OP_STATUS_STATUS_VALUE_DONE_SUCCESS:
      HARDENED_CHECK_EQ(status, KEYMGR_DPE_OP_STATUS_STATUS_VALUE_DONE_SUCCESS);
      return kErrorOk;
    case KEYMGR_DPE_OP_STATUS_STATUS_VALUE_DONE_ERROR: {
      // Clear the ERR_CODE register before returning.
      uint32_t err_code = abs_mmio_read32(sc_keymgr_dpe_base() +
                                          KEYMGR_DPE_ERR_CODE_REG_OFFSET);
      abs_mmio_write32(sc_keymgr_dpe_base() + KEYMGR_DPE_ERR_CODE_REG_OFFSET,
                       err_code);
      return kErrorKeymgrInternal;
    }
    default:
      // Should be unreachable.
      HARDENED_TRAP();
      return kErrorKeymgrInternal;
  }
}

rom_error_t sc_keymgr_dpe_advance_state(sc_keymgr_dpe_slot_t src_slot,
                                        sc_keymgr_dpe_slot_t dest_slot,
                                        hardened_bool_t allow_child,
                                        hardened_bool_t exportable,
                                        hardened_bool_t retain_parent,
                                        hardened_bool_t sw_binding_only) {
  // Set `dest` to `NONE` (this is an `advance`, not a `generate` operation).
  uint32_t ctrl =
      bitfield_field32_write(0, KEYMGR_DPE_CONTROL_SHADOWED_DEST_SEL_FIELD,
                             KEYMGR_DPE_CONTROL_SHADOWED_DEST_SEL_VALUE_NONE);
  // Set source slot.
  ctrl = bitfield_field32_write(
      ctrl, KEYMGR_DPE_CONTROL_SHADOWED_SLOT_SRC_SEL_FIELD, src_slot);
  // Set destination slot.
  ctrl = bitfield_field32_write(
      ctrl, KEYMGR_DPE_CONTROL_SHADOWED_SLOT_DST_SEL_FIELD, dest_slot);
  // Set operation to `ADVANCE`.
  ctrl = bitfield_field32_write(
      ctrl, KEYMGR_DPE_CONTROL_SHADOWED_OPERATION_FIELD,
      KEYMGR_DPE_CONTROL_SHADOWED_OPERATION_VALUE_ADVANCE);
  abs_mmio_write32_shadowed(
      sc_keymgr_dpe_base() + KEYMGR_DPE_CONTROL_SHADOWED_REG_OFFSET, ctrl);

  uint32_t slot_policy;
  // Set the `allow_child` slot policy field.
  switch (launder32(allow_child)) {
    case kHardenedBoolFalse:
      slot_policy =
          bitfield_bit32_write(0, KEYMGR_DPE_SLOT_POLICY_ALLOW_CHILD_BIT, 0);
      break;
    case kHardenedBoolTrue:
      slot_policy =
          bitfield_bit32_write(0, KEYMGR_DPE_SLOT_POLICY_ALLOW_CHILD_BIT, 1);
      break;
    default:
      HARDENED_TRAP();
      break;
  }
  // Set the `exportable` slot policy field.
  switch (launder32(exportable)) {
    case kHardenedBoolFalse:
      slot_policy = bitfield_bit32_write(
          slot_policy, KEYMGR_DPE_SLOT_POLICY_EXPORTABLE_BIT, 0);
      break;
    case kHardenedBoolTrue:
      slot_policy = bitfield_bit32_write(
          slot_policy, KEYMGR_DPE_SLOT_POLICY_EXPORTABLE_BIT, 1);
      break;
    default:
      HARDENED_TRAP();
      break;
  }
  // Set the `retain_parent` slot policy field.
  switch (launder32(retain_parent)) {
    case kHardenedBoolFalse:
      slot_policy = bitfield_bit32_write(
          slot_policy, KEYMGR_DPE_SLOT_POLICY_RETAIN_PARENT_BIT, 0);
      break;
    case kHardenedBoolTrue:
      slot_policy = bitfield_bit32_write(
          slot_policy, KEYMGR_DPE_SLOT_POLICY_RETAIN_PARENT_BIT, 1);
      break;
    default:
      HARDENED_TRAP();
      break;
  }
  abs_mmio_write32_shadowed(
      sc_keymgr_dpe_base() + KEYMGR_DPE_SLOT_POLICY_REG_OFFSET, slot_policy);

  // Start the ADVANCE operation.
  abs_mmio_write32(sc_keymgr_dpe_base() + KEYMGR_DPE_START_REG_OFFSET,
                   1 << KEYMGR_DPE_START_EN_BIT);

  // Block until keymgr_dpe is done.
  return keymgr_dpe_wait_until_done();
}

rom_error_t sc_keymgr_dpe_state_check(sc_keymgr_dpe_state_t expected_state) {
  return expected_state_check(expected_state);
}

/**
 * Fails if the keymgr_dpe is not idle.
 *
 * @return OK if the key manager is idle, kErrorKeymgrInternal otherwise.
 */
OT_WARN_UNUSED_RESULT
static rom_error_t keymgr_dpe_is_idle(void) {
  uint32_t reg =
      abs_mmio_read32(sc_keymgr_dpe_base() + KEYMGR_DPE_OP_STATUS_REG_OFFSET);
  uint32_t status =
      bitfield_field32_read(reg, KEYMGR_DPE_OP_STATUS_STATUS_FIELD);
  if (launder32(status) == KEYMGR_DPE_OP_STATUS_STATUS_VALUE_IDLE) {
    HARDENED_CHECK_EQ(status, KEYMGR_DPE_OP_STATUS_STATUS_VALUE_IDLE);
    return kErrorOk;
  }
  return kErrorKeymgrInternal;
}

rom_error_t sc_keymgr_dpe_generate_key(
    sc_keymgr_dpe_slot_t src_slot, sc_keymgr_dpe_dest_t destination,
    sc_keymgr_dpe_diversification_t diversification) {
  HARDENED_RETURN_IF_ERROR(keymgr_dpe_is_idle());

  // Set the source slot.
  uint32_t ctrl = bitfield_field32_write(
      0, KEYMGR_DPE_CONTROL_SHADOWED_SLOT_SRC_SEL_FIELD, src_slot);
  // Set the destination.
  ctrl = bitfield_field32_write(0, KEYMGR_DPE_CONTROL_SHADOWED_DEST_SEL_FIELD,
                                destination);

  // Select the GENERATE operation.
  ctrl = bitfield_field32_write(
      ctrl, KEYMGR_DPE_CONTROL_SHADOWED_OPERATION_FIELD,
      KEYMGR_DPE_CONTROL_SHADOWED_OPERATION_VALUE_GENERATE_HW_OUTPUT);

  // Write the control register.
  abs_mmio_write32_shadowed(
      sc_keymgr_dpe_base() + KEYMGR_DPE_CONTROL_SHADOWED_REG_OFFSET, ctrl);

  // Set the version.
  abs_mmio_write32(sc_keymgr_dpe_base() + KEYMGR_DPE_KEY_VERSION_REG_OFFSET,
                   diversification.version);
  // Set the salt.
  for (size_t i = 0; i < kScKeymgrDpeSaltNumWords; i++) {
    abs_mmio_write32(sc_keymgr_dpe_base() + KEYMGR_DPE_SALT_0_REG_OFFSET +
                         (i * sizeof(uint32_t)),
                     diversification.salt[i]);
  }

  // Issue the start command.
  abs_mmio_write32(sc_keymgr_dpe_base() + KEYMGR_DPE_START_REG_OFFSET,
                   1 << KEYMGR_DPE_START_EN_BIT);

  // Block until keymgr_dpe is done.
  return keymgr_dpe_wait_until_done();
}

rom_error_t sc_keymgr_dpe_sideload_clear(sc_keymgr_dpe_dest_t destination) {
  HARDENED_RETURN_IF_ERROR(keymgr_dpe_is_idle());

  // Set SIDELOAD_CLEAR to begin continuously clearing the requested slot.
  abs_mmio_write32(sc_keymgr_dpe_base() + KEYMGR_DPE_SIDELOAD_CLEAR_REG_OFFSET,
                   bitfield_field32_write(
                       0, KEYMGR_DPE_SIDELOAD_CLEAR_VAL_FIELD, destination));

  // Read back the value (hardening measure).
  uint32_t sideload_clear = abs_mmio_read32(
      sc_keymgr_dpe_base() + KEYMGR_DPE_SIDELOAD_CLEAR_REG_OFFSET);
  if (bitfield_field32_read(
          sideload_clear, KEYMGR_DPE_SIDELOAD_CLEAR_VAL_FIELD) != destination) {
    return kErrorKeymgrInternal;
  }

  // Spin for 100 microseconds.
  // TODO(https://github.com/lowRISC/opentitan/issues/20024): this value seems
  // to work for tests, but it would be good to run a more principled analysis.
  busy_spin_micros(100);

  // Stop continuous clearing.
  abs_mmio_write32(
      sc_keymgr_dpe_base() + KEYMGR_DPE_SIDELOAD_CLEAR_REG_OFFSET,
      bitfield_field32_write(0, KEYMGR_DPE_SIDELOAD_CLEAR_VAL_FIELD,
                             KEYMGR_DPE_SIDELOAD_CLEAR_VAL_VALUE_NONE));

  return kErrorOk;
}

rom_error_t sc_keymgr_dpe_advance(
    sc_keymgr_dpe_slot_t src_slot, sc_keymgr_dpe_slot_t dest_slot,
    hardened_bool_t allow_child, hardened_bool_t exportable,
    hardened_bool_t retain_parent, hardened_bool_t sw_binding_only,
    keymgr_dpe_binding_value_t *binding, uint32_t max_key_version) {
  HARDENED_RETURN_IF_ERROR(sc_keymgr_dpe_state_check(kScKeymgrDpeStateReset));
  sc_keymgr_dpe_sw_binding_set(binding);
  sc_keymgr_dpe_max_ver_set(max_key_version);
  sc_keymgr_dpe_advance_state(src_slot, dest_slot, allow_child, exportable,
                              retain_parent, sw_binding_only);
  HARDENED_RETURN_IF_ERROR(
      sc_keymgr_dpe_state_check(kScKeymgrDpeStateAvailable));
  return kErrorOk;
}

void sc_keymgr_dpe_disable(void) {
  uint32_t reg =
      bitfield_field32_write(0, KEYMGR_DPE_CONTROL_SHADOWED_DEST_SEL_FIELD,
                             KEYMGR_DPE_CONTROL_SHADOWED_DEST_SEL_VALUE_NONE);
  reg = bitfield_field32_write(
      reg, KEYMGR_DPE_CONTROL_SHADOWED_OPERATION_FIELD,
      KEYMGR_DPE_CONTROL_SHADOWED_OPERATION_VALUE_DISABLE);
  abs_mmio_write32_shadowed(
      sc_keymgr_dpe_base() + KEYMGR_DPE_CONTROL_SHADOWED_REG_OFFSET, reg);

  abs_mmio_write32(sc_keymgr_dpe_base() + KEYMGR_DPE_START_REG_OFFSET, 1);
  abs_mmio_write32(sc_keymgr_dpe_base() + KEYMGR_DPE_SIDELOAD_CLEAR_REG_OFFSET,
                   1);
}

extern rom_error_t sc_keymgr_dpe_generate_key_acc(
    sc_keymgr_dpe_slot_t src_slot,
    sc_keymgr_dpe_diversification_t diversification);
extern rom_error_t sc_keymgr_dpe_sideload_clear_acc(void);
