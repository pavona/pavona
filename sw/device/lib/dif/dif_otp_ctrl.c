// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
#include "sw/device/lib/dif/dif_otp_ctrl.h"

#include <stddef.h>

#include "sw/device/lib/base/bitfield.h"
#include "sw/device/lib/base/macros.h"
#include "sw/device/lib/dif/dif_base.h"

#include "hw/top/otp_ctrl_regs.h"  // Generated.

/**
 * Checks if integrity/consistency-check-related operations are locked.
 *
 * This is a convenience function to avoid superfluous error-checking in all the
 * functions that can be locked out by this register.
 *
 * @param check_config True to check the config regwen. False to check the
 * trigger regwen.
 */
static bool checks_are_locked(const dif_otp_ctrl_t *otp, bool check_config) {
  ptrdiff_t reg_offset = check_config
                             ? OTP_CTRL_CHECK_REGWEN_REG_OFFSET
                             : OTP_CTRL_CHECK_TRIGGER_REGWEN_REG_OFFSET;
  size_t regwen_bit =
      check_config ? OTP_CTRL_CHECK_REGWEN_CHECK_REGWEN_BIT
                   : OTP_CTRL_CHECK_TRIGGER_REGWEN_CHECK_TRIGGER_REGWEN_BIT;
  uint32_t locked = mmio_region_read32(otp->base_addr, reg_offset);
  return !bitfield_bit32_read(locked, regwen_bit);
}

static dif_result_t get_error_code(const dif_otp_ctrl_t *otp,
                                   uint32_t partition_number,
                                   dif_otp_ctrl_error_t *err) {
  bitfield_field32_t field;
  field = (bitfield_field32_t){
      .mask = OTP_CTRL_ERR_CODE_0_ERR_CODE_0_MASK,
      .index = OTP_CTRL_ERR_CODE_0_ERR_CODE_0_OFFSET,
  };

  ptrdiff_t err_code_address =
      OTP_CTRL_ERR_CODE_0_REG_OFFSET +
      (ptrdiff_t)partition_number * (ptrdiff_t)sizeof(uint32_t);
  uint32_t error_code = mmio_region_read32(otp->base_addr, err_code_address);

  switch (bitfield_field32_read(error_code, field)) {
    case OTP_CTRL_ERR_CODE_0_ERR_CODE_0_VALUE_NO_ERROR:
      *err = kDifOtpCtrlErrorOk;
      break;
    case OTP_CTRL_ERR_CODE_0_ERR_CODE_0_VALUE_MACRO_ERROR:
      *err = kDifOtpCtrlErrorMacroUnspecified;
      break;
    case OTP_CTRL_ERR_CODE_0_ERR_CODE_0_VALUE_MACRO_ECC_CORR_ERROR:
      *err = kDifOtpCtrlErrorMacroRecoverableRead;
      break;
    case OTP_CTRL_ERR_CODE_0_ERR_CODE_0_VALUE_MACRO_ECC_UNCORR_ERROR:
      *err = kDifOtpCtrlErrorMacroUnrecoverableRead;
      break;
    case OTP_CTRL_ERR_CODE_0_ERR_CODE_0_VALUE_MACRO_WRITE_BLANK_ERROR:
      *err = kDifOtpCtrlErrorMacroBlankCheckFailed;
      break;
    case OTP_CTRL_ERR_CODE_0_ERR_CODE_0_VALUE_ACCESS_ERROR:
      *err = kDifOtpCtrlErrorLockedAccess;
      break;
    case OTP_CTRL_ERR_CODE_0_ERR_CODE_0_VALUE_CHECK_FAIL_ERROR:
      *err = kDifOtpCtrlErrorBackgroundCheckFailed;
      break;
    case OTP_CTRL_ERR_CODE_0_ERR_CODE_0_VALUE_FSM_STATE_ERROR:
      *err = kDifOtpCtrlErrorFsmBadState;
      break;
    default:
      return kDifError;
  }
  return kDifOk;
}

dif_result_t dif_otp_ctrl_configure(const dif_otp_ctrl_t *otp,
                                    dif_otp_ctrl_config_t config) {
  if (otp == NULL) {
    return kDifBadArg;
  }
  if (checks_are_locked(otp, /*check_config=*/true)) {
    return kDifLocked;
  }

  mmio_region_write32(otp->base_addr, OTP_CTRL_CHECK_TIMEOUT_REG_OFFSET,
                      config.check_timeout);
  mmio_region_write32(otp->base_addr,
                      OTP_CTRL_INTEGRITY_CHECK_PERIOD_REG_OFFSET,
                      config.integrity_period_mask);
  mmio_region_write32(otp->base_addr,
                      OTP_CTRL_CONSISTENCY_CHECK_PERIOD_REG_OFFSET,
                      config.consistency_period_mask);

  return kDifOk;
}

dif_result_t dif_otp_ctrl_check_integrity(const dif_otp_ctrl_t *otp) {
  if (otp == NULL) {
    return kDifBadArg;
  }
  if (checks_are_locked(otp, /*check_config=*/false)) {
    return kDifLocked;
  }

  uint32_t reg =
      bitfield_bit32_write(0, OTP_CTRL_CHECK_TRIGGER_INTEGRITY_BIT, true);
  mmio_region_write32(otp->base_addr, OTP_CTRL_CHECK_TRIGGER_REG_OFFSET, reg);

  return kDifOk;
}

dif_result_t dif_otp_ctrl_check_consistency(const dif_otp_ctrl_t *otp) {
  if (otp == NULL) {
    return kDifBadArg;
  }
  if (checks_are_locked(otp, /*check_config=*/false)) {
    return kDifLocked;
  }

  uint32_t reg =
      bitfield_bit32_write(0, OTP_CTRL_CHECK_TRIGGER_CONSISTENCY_BIT, true);
  mmio_region_write32(otp->base_addr, OTP_CTRL_CHECK_TRIGGER_REG_OFFSET, reg);

  return kDifOk;
}

dif_result_t dif_otp_ctrl_dai_lock(const dif_otp_ctrl_t *otp) {
  if (otp == NULL) {
    return kDifBadArg;
  }

  uint32_t reg = bitfield_bit32_write(
      0, OTP_CTRL_DIRECT_ACCESS_REGWEN_DIRECT_ACCESS_REGWEN_BIT, false);
  mmio_region_write32(otp->base_addr, OTP_CTRL_DIRECT_ACCESS_REGWEN_REG_OFFSET,
                      reg);

  return kDifOk;
}

dif_result_t dif_otp_ctrl_dai_is_locked(const dif_otp_ctrl_t *otp,
                                        bool *is_locked) {
  if (otp == NULL || is_locked == NULL) {
    return kDifBadArg;
  }

  uint32_t reg = mmio_region_read32(otp->base_addr,
                                    OTP_CTRL_DIRECT_ACCESS_REGWEN_REG_OFFSET);
  *is_locked = !bitfield_bit32_read(
      reg, OTP_CTRL_DIRECT_ACCESS_REGWEN_DIRECT_ACCESS_REGWEN_BIT);

  return kDifOk;
}

dif_result_t dif_otp_ctrl_lock_config(const dif_otp_ctrl_t *otp) {
  if (otp == NULL) {
    return kDifBadArg;
  }

  uint32_t reg =
      bitfield_bit32_write(0, OTP_CTRL_CHECK_REGWEN_CHECK_REGWEN_BIT, false);
  mmio_region_write32(otp->base_addr, OTP_CTRL_CHECK_REGWEN_REG_OFFSET, reg);

  return kDifOk;
}

dif_result_t dif_otp_ctrl_config_is_locked(const dif_otp_ctrl_t *otp,
                                           bool *is_locked) {
  if (otp == NULL || is_locked == NULL) {
    return kDifBadArg;
  }

  *is_locked = checks_are_locked(otp, /*check_config=*/true);
  return kDifOk;
}

dif_result_t dif_otp_ctrl_lock_check_trigger(const dif_otp_ctrl_t *otp) {
  if (otp == NULL) {
    return kDifBadArg;
  }

  uint32_t reg = bitfield_bit32_write(
      0, OTP_CTRL_CHECK_TRIGGER_REGWEN_CHECK_TRIGGER_REGWEN_BIT, false);
  mmio_region_write32(otp->base_addr, OTP_CTRL_CHECK_TRIGGER_REGWEN_REG_OFFSET,
                      reg);

  return kDifOk;
}

dif_result_t dif_otp_ctrl_check_trigger_is_locked(const dif_otp_ctrl_t *otp,
                                                  bool *is_locked) {
  if (otp == NULL || is_locked == NULL) {
    return kDifBadArg;
  }

  *is_locked = checks_are_locked(otp, /*check_config=*/false);
  return kDifOk;
}

dif_result_t dif_otp_ctrl_lock_reading(const dif_otp_ctrl_t *otp,
                                       otp_partition_t partition) {
  if (otp == NULL) {
    return kDifBadArg;
  }

  dt_otp_partition_info_t partition_info =
      dt_otp_ctrl_partition(otp->dt, partition);
  if (!partition_info.read_lockable) {
    return kDifBadArg;
  }

  uint32_t reg = bitfield_bit32_write(0, partition_info.read_lock_bit, false);
  mmio_region_write32(otp->base_addr, (ptrdiff_t)partition_info.lock_reg_offset,
                      reg);

  return kDifOk;
}

dif_result_t dif_otp_ctrl_reading_is_locked(const dif_otp_ctrl_t *otp,
                                            otp_partition_t partition,
                                            bool *is_locked) {
  if (otp == NULL || is_locked == NULL) {
    return kDifBadArg;
  }

  dt_otp_partition_info_t partition_info =
      dt_otp_ctrl_partition(otp->dt, partition);
  if (!partition_info.read_lockable) {
    return kDifBadArg;
  }

  uint32_t reg = mmio_region_read32(otp->base_addr,
                                    (ptrdiff_t)partition_info.lock_reg_offset);
  *is_locked = !bitfield_bit32_read(reg, partition_info.read_lock_bit);
  return kDifOk;
}

dif_result_t dif_otp_ctrl_get_status(const dif_otp_ctrl_t *otp,
                                     dif_otp_ctrl_status_t *status) {
  if (otp == NULL || status == NULL) {
    return kDifBadArg;
  }

  status->codes = 0;

  // Read main STATUS register
  uint32_t status_code_reg =
      mmio_region_read32(otp->base_addr, OTP_CTRL_STATUS_REG_OFFSET);

  // Only read PARTITION_STATUS_0 register if PARTITION_ERROR bit is set
  if (bitfield_bit32_read(status_code_reg,
                          OTP_CTRL_STATUS_PARTITION_ERROR_BIT)) {
    uint32_t num_part_status_regs = (kOtpPartitionCount + 31) / 32;
    for (int status_reg_num = 0; status_reg_num < num_part_status_regs;
         ++status_reg_num) {
      uint32_t partition_status_reg = mmio_region_read32(
          otp->base_addr,
          (ptrdiff_t)(OTP_CTRL_PARTITION_STATUS_0_REG_OFFSET +
                      (ptrdiff_t)sizeof(uint32_t) * status_reg_num));
      // Process partition status bits
      for (int status_idx = 0; status_idx < 32; ++status_idx) {
        uint32_t partition_number =
            (uint32_t)status_reg_num * 32 + (uint32_t)status_idx;
        if (partition_number > kOtpPartitionCount) {
          break;
        }
        // If the error is not present at all, we clear its cause and bail
        // immediately.
        if (!bitfield_bit32_read(partition_status_reg,
                                 (bitfield_bit32_index_t)status_idx)) {
          status->causes[partition_number] = kDifOtpCtrlErrorOk;
          continue;
        }

        // Set bit for partition error
        status->codes = bitfield_bit32_write(
            status->codes,
            (bitfield_bit32_index_t)OTP_CTRL_STATUS_PARTITION_ERROR_BIT, true);

        // Read and decode err_code register
        dif_otp_ctrl_error_t err;
        if (get_error_code(otp, partition_number, &err) != kDifOk) {
          return kDifError;
        }
        status->causes[partition_number] = err;
      }
    }
  } else {
    // No partition errors, clear all partition error causes
    for (int i = 0; i < kOtpPartitionCount; ++i) {
      status->causes[i] = kDifOtpCtrlErrorOk;
    }
  }

  // Process DAI/LCI status bits from main STATUS register
  for (int i = kDifOtpCtrlStatusCodeDaiError;
       i <= kDifOtpCtrlStatusCodeLciError; ++i) {
    uint32_t err_code_index = kOtpPartitionCount - 1 + (uint32_t)i;
    dif_otp_ctrl_error_t err = kDifOtpCtrlErrorOk;

    if (bitfield_bit32_read(status_code_reg, (bitfield_bit32_index_t)i)) {
      // Set error status code
      status->codes =
          bitfield_bit32_write(status->codes, (bitfield_bit32_index_t)i, true);

      // Get error cause
      if (get_error_code(otp, err_code_index, &err) != kDifOk) {
        return kDifError;
      }
    }

    status->causes[err_code_index] = err;
  }

  // Process other status bits from main STATUS register
  for (int i = kDifOtpCtrlStatusCodeLciError + 1; i < ARRAYSIZE(status->causes);
       ++i) {
    if (!bitfield_bit32_read(status_code_reg, (bitfield_bit32_index_t)i)) {
      continue;
    }
    // Set error status code
    status->codes =
        bitfield_bit32_write(status->codes, (bitfield_bit32_index_t)i, true);
  }

  return kDifOk;
}

dif_result_t dif_otp_ctrl_relative_address(const dif_otp_ctrl_t *otp,
                                           otp_partition_t partition,
                                           uint32_t abs_address,
                                           uint32_t *relative_address) {
  *relative_address = 0;

  if (partition >= kOtpPartitionCount) {
    return kDifBadArg;
  }

  dt_otp_partition_info_t partition_info =
      dt_otp_ctrl_partition(otp->dt, partition);
  if ((abs_address & partition_info.align_mask) != 0) {
    return kDifUnaligned;
  }

  if (abs_address < partition_info.start_addr) {
    return kDifOutOfRange;
  }

  *relative_address = abs_address - partition_info.start_addr;
  // NOTE: `partition_info.size` excludes the digest / zeroization fields.
  size_t partition_end = partition_info.size;
  if (partition_info.sw_digest || partition_info.hw_digest) {
    partition_end += sizeof(uint64_t);
  }
  if (partition_info.zeroizable) {
    partition_end += sizeof(uint64_t);
  }
  if (*relative_address >= partition_end) {
    *relative_address = 0;
    return kDifOutOfRange;
  }

  return kDifOk;
}

dif_result_t dif_otp_ctrl_dai_read_start(const dif_otp_ctrl_t *otp,
                                         otp_partition_t partition,
                                         uint32_t address) {
  if (otp == NULL || partition >= kOtpPartitionCount) {
    return kDifBadArg;
  }

  dt_otp_partition_info_t partition_info =
      dt_otp_ctrl_partition(otp->dt, partition);
  if ((address & partition_info.align_mask) != 0) {
    return kDifUnaligned;
  }

  // NOTE: `partition_info.size` excludes the digest / zeroization fields.
  size_t partition_end = partition_info.size;
  if (partition_info.sw_digest || partition_info.hw_digest) {
    partition_end += sizeof(uint64_t);
  }
  if (partition_info.zeroizable) {
    partition_end += sizeof(uint64_t);
  }
  if (address >= partition_end) {
    return kDifOutOfRange;
  }

  address += partition_info.start_addr;
  mmio_region_write32(otp->base_addr, OTP_CTRL_DIRECT_ACCESS_ADDRESS_REG_OFFSET,
                      address);

  uint32_t cmd =
      bitfield_bit32_write(0, OTP_CTRL_DIRECT_ACCESS_CMD_RD_BIT, true);
  mmio_region_write32(otp->base_addr, OTP_CTRL_DIRECT_ACCESS_CMD_REG_OFFSET,
                      cmd);

  return kDifOk;
}

dif_result_t dif_otp_ctrl_dai_read32_end(const dif_otp_ctrl_t *otp,
                                         uint32_t *value) {
  if (otp == NULL || value == NULL) {
    return kDifBadArg;
  }

  *value = mmio_region_read32(otp->base_addr,
                              OTP_CTRL_DIRECT_ACCESS_RDATA_0_REG_OFFSET);
  return kDifOk;
}

dif_result_t dif_otp_ctrl_dai_read64_end(const dif_otp_ctrl_t *otp,
                                         uint64_t *value) {
  if (otp == NULL || value == NULL) {
    return kDifBadArg;
  }

  *value = mmio_region_read32(otp->base_addr,
                              OTP_CTRL_DIRECT_ACCESS_RDATA_1_REG_OFFSET);
  *value <<= 32;
  *value |= mmio_region_read32(otp->base_addr,
                               OTP_CTRL_DIRECT_ACCESS_RDATA_0_REG_OFFSET);
  return kDifOk;
}

dif_result_t dif_otp_ctrl_dai_program32(const dif_otp_ctrl_t *otp,
                                        otp_partition_t partition,
                                        uint32_t address, uint32_t value) {
  if (otp == NULL || partition >= kOtpPartitionCount) {
    return kDifBadArg;
  }
  dt_otp_partition_info_t partition_info =
      dt_otp_ctrl_partition(otp->dt, partition);

  // Ensure that we are writing to a 32-bit-access partition by checking that
  // the alignment mask is 0b11.
  //
  // Note furthermore that the LC partition is *not* writeable, so we eject
  // here.
  if (partition_info.align_mask != 0x3 || partition_info.is_lifecycle) {
    return kDifError;
  }

  if ((address & partition_info.align_mask) != 0) {
    return kDifUnaligned;
  }

  // NOTE: `partition_info.size` excludes the digest / zeroization fields.
  size_t partition_end = partition_info.size;
  if (partition_info.sw_digest || partition_info.hw_digest) {
    partition_end += sizeof(uint64_t);
  }
  if (partition_info.zeroizable) {
    partition_end += sizeof(uint64_t);
  }
  if (address >= partition_end) {
    return kDifOutOfRange;
  }

  address += partition_info.start_addr;
  mmio_region_write32(otp->base_addr, OTP_CTRL_DIRECT_ACCESS_ADDRESS_REG_OFFSET,
                      address);

  mmio_region_write32(otp->base_addr, OTP_CTRL_DIRECT_ACCESS_WDATA_0_REG_OFFSET,
                      value);

  uint32_t cmd =
      bitfield_bit32_write(0, OTP_CTRL_DIRECT_ACCESS_CMD_WR_BIT, true);
  mmio_region_write32(otp->base_addr, OTP_CTRL_DIRECT_ACCESS_CMD_REG_OFFSET,
                      cmd);

  return kDifOk;
}

dif_result_t dif_otp_ctrl_dai_program64(const dif_otp_ctrl_t *otp,
                                        otp_partition_t partition,
                                        uint32_t address, uint64_t value) {
  if (otp == NULL || partition >= kOtpPartitionCount) {
    return kDifBadArg;
  }
  dt_otp_partition_info_t partition_info =
      dt_otp_ctrl_partition(otp->dt, partition);

  // Some partitions are not accessible by software.
  if (partition_info.is_lifecycle) {
    return kDifError;
  }
  // Ensure that we are writing to a 64-bit-access partition by checking that
  // the alignment mask is 0b111.
  if (partition_info.align_mask != 0x7) {
    return kDifError;
  }

  if ((address & partition_info.align_mask) != 0) {
    return kDifUnaligned;
  }

  // NOTE: `partition_info.size` excludes the digest / zeroization fields.
  size_t partition_end = partition_info.size;
  if (partition_info.sw_digest || partition_info.hw_digest) {
    partition_end += sizeof(uint64_t);
  }
  if (partition_info.zeroizable) {
    partition_end += sizeof(uint64_t);
  }
  if (address >= partition_end) {
    return kDifOutOfRange;
  }

  address += partition_info.start_addr;
  mmio_region_write32(otp->base_addr, OTP_CTRL_DIRECT_ACCESS_ADDRESS_REG_OFFSET,
                      address);

  mmio_region_write32(otp->base_addr, OTP_CTRL_DIRECT_ACCESS_WDATA_0_REG_OFFSET,
                      value & UINT32_MAX);
  mmio_region_write32(otp->base_addr, OTP_CTRL_DIRECT_ACCESS_WDATA_1_REG_OFFSET,
                      value >> 32);

  uint32_t cmd =
      bitfield_bit32_write(0, OTP_CTRL_DIRECT_ACCESS_CMD_WR_BIT, true);
  mmio_region_write32(otp->base_addr, OTP_CTRL_DIRECT_ACCESS_CMD_REG_OFFSET,
                      cmd);

  return kDifOk;
}

dif_result_t dif_otp_ctrl_dai_digest(const dif_otp_ctrl_t *otp,
                                     otp_partition_t partition,
                                     uint64_t digest) {
  if (otp == NULL || partition >= kOtpPartitionCount) {
    return kDifBadArg;
  }
  dt_otp_partition_info_t partition_info =
      dt_otp_ctrl_partition(otp->dt, partition);

  // Not all partitions have a digest.
  if (!partition_info.sw_digest && !partition_info.hw_digest) {
    return kDifBadArg;
  }

  // For software partitions, the digest must be nonzero; for all other
  // partitions it must be zero.
  bool is_sw = partition_info.sw_digest;
  if (is_sw == (digest == 0)) {
    return kDifBadArg;
  }

  uint32_t address = partition_info.start_addr;
  if (is_sw) {
    // NOTE: `partition_info.size` excludes the digest / zeroization fields.
    address += partition_info.size;
  }
  mmio_region_write32(otp->base_addr, OTP_CTRL_DIRECT_ACCESS_ADDRESS_REG_OFFSET,
                      address);

  if (digest != 0) {
    mmio_region_write32(otp->base_addr,
                        OTP_CTRL_DIRECT_ACCESS_WDATA_0_REG_OFFSET,
                        digest & 0xffffffff);
    mmio_region_write32(otp->base_addr,
                        OTP_CTRL_DIRECT_ACCESS_WDATA_1_REG_OFFSET,
                        digest >> 32);
  }

  bitfield_bit32_index_t cmd_bit = is_sw
                                       ? OTP_CTRL_DIRECT_ACCESS_CMD_WR_BIT
                                       : OTP_CTRL_DIRECT_ACCESS_CMD_DIGEST_BIT;
  uint32_t cmd = bitfield_bit32_write(0, cmd_bit, true);
  mmio_region_write32(otp->base_addr, OTP_CTRL_DIRECT_ACCESS_CMD_REG_OFFSET,
                      cmd);

  return kDifOk;
}

dif_result_t dif_otp_ctrl_is_digest_computed(const dif_otp_ctrl_t *otp,
                                             otp_partition_t partition,
                                             bool *is_computed) {
  if (otp == NULL || is_computed == NULL) {
    return kDifBadArg;
  }
  dt_otp_partition_info_t partition_info =
      dt_otp_ctrl_partition(otp->dt, partition);

  // Not all partitions have a digest.
  if (!partition_info.sw_digest && !partition_info.hw_digest) {
    return kDifBadArg;
  }

  uint64_t value = mmio_region_read32(
      otp->base_addr,
      (ptrdiff_t)(partition_info.digest_reg_offset + sizeof(uint32_t)));
  value <<= 32;
  value |= mmio_region_read32(otp->base_addr,
                              (ptrdiff_t)partition_info.digest_reg_offset);

  *is_computed = value != 0;

  return kDifOk;
}

dif_result_t dif_otp_ctrl_get_digest(const dif_otp_ctrl_t *otp,
                                     otp_partition_t partition,
                                     uint64_t *digest) {
  if (otp == NULL || digest == NULL) {
    return kDifBadArg;
  }
  dt_otp_partition_info_t partition_info =
      dt_otp_ctrl_partition(otp->dt, partition);

  // Not all partitions have a digest.
  if (!partition_info.sw_digest && !partition_info.hw_digest) {
    return kDifBadArg;
  }

  uint64_t value = mmio_region_read32(
      otp->base_addr,
      (ptrdiff_t)(partition_info.digest_reg_offset + sizeof(uint32_t)));
  value <<= 32;
  value |= mmio_region_read32(otp->base_addr,
                              (ptrdiff_t)partition_info.digest_reg_offset);

  if (value == 0) {
    return kDifError;
  }
  *digest = value;

  return kDifOk;
}

dif_result_t dif_otp_ctrl_read_blocking(const dif_otp_ctrl_t *otp,
                                        otp_partition_t partition,
                                        uint32_t address, uint32_t *buf,
                                        size_t len) {
  if (otp == NULL || partition >= kOtpPartitionCount || buf == NULL) {
    return kDifBadArg;
  }
  dt_otp_partition_info_t partition_info =
      dt_otp_ctrl_partition(otp->dt, partition);

  if (!partition_info.sw_digest) {
    return kDifError;
  }

  if ((address & partition_info.align_mask) != 0) {
    return kDifUnaligned;
  }

  if (address + len >= partition_info.size) {
    return kDifOutOfRange;
  }

  uint32_t reg_offset =
      OTP_CTRL_SW_CFG_WINDOW_REG_OFFSET + partition_info.start_addr + address;
  mmio_region_memcpy_from_mmio32(otp->base_addr, reg_offset, buf,
                                 len * sizeof(uint32_t));
  return kDifOk;
}
