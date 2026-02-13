// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/crypto/drivers/acc.h"

#include "hw/top/dt/dt_acc.h"
#include "sw/device/lib/base/abs_mmio.h"
#include "sw/device/lib/base/bitfield.h"
#include "sw/device/lib/base/crc32.h"
#include "sw/device/lib/base/hardened.h"
#include "sw/device/lib/base/macros.h"
#include "sw/device/lib/base/random_order.h"
#include "sw/device/lib/base/status.h"
#include "sw/device/lib/crypto/impl/status.h"

#include "hw/top/acc_regs.h"  // Generated.

// Module ID for status codes.
#define MODULE_ID MAKE_MODULE_ID('d', 'b', 'n')

static const dt_acc_t kAccDt = kDtAcc;

static inline uint32_t acc_base(void) {
  return dt_acc_primary_reg_block(kAccDt);
}

enum {
  /**
   * DMEM size in bytes.
   */
  kAccDMemSizeBytes = ACC_DMEM_SIZE_BYTES,
  /**
   * IMEM size in bytes.
   */
  kAccIMemSizeBytes = ACC_IMEM_SIZE_BYTES,
  /**
   * ERR_BITS register value in the case of no errors.
   *
   * Although some parts of the ERR_BITS register are marked reserved, the ACC
   * documentation explicitly guarantees that ERR_BITS is zero for a successful
   * execution:
   *   https://opentitan.org/book/hw/ip/acc/doc/theory_of_operation.html#software-execution-design-details
   */
  kAccErrBitsNoError = 0,
};

/**
 * ACC commands
 */
typedef enum acc_cmd {
  kAccCmdExecute = 0xd8,
  kAccCmdSecWipeDmem = 0xc3,
  kAccCmdSecWipeImem = 0x1e,
} acc_cmd_t;

/**
 * ACC status
 */
typedef enum acc_status {
  kAccStatusIdle = 0x00,
  kAccStatusBusyExecute = 0x01,
  kAccStatusBusySecWipeDmem = 0x02,
  kAccStatusBusySecWipeImem = 0x03,
  kAccStatusBusySecWipeInt = 0x04,
  kAccStatusLocked = 0xFF,
} acc_status_t;

/**
 * Ensures that a memory access fits within the given memory size.
 *
 * @param offset_bytes Memory offset at which to start.
 * @param num_words Number of 32b words to access.
 * @param mem_size Size of memory.
 * @return Result of the operation.
 */
OT_WARN_UNUSED_RESULT
static status_t check_offset_len(uint32_t offset_bytes, size_t num_words,
                                 size_t mem_size) {
  if (num_words > UINT32_MAX / sizeof(uint32_t)) {
    return OTCRYPTO_BAD_ARGS;
  }
  uint32_t num_bytes = num_words * sizeof(uint32_t);

  if (offset_bytes > UINT32_MAX - num_bytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  uint32_t adjusted_offset_bytes = offset_bytes + num_bytes;

  if (adjusted_offset_bytes > mem_size) {
    return OTCRYPTO_BAD_ARGS;
  }

  return OTCRYPTO_OK;
}

/**
 * Update a checksum value with a given DMEM write.
 *
 * Calculates the checksum stream according to:
 * https://opentitan.org/book/hw/ip/acc/doc/theory_of_operation.html#memory-load-integrity
 *
 * This means each write is a 48b value, where the most significant two bytes
 * indicate the location and the least significant four bytes are the 32-bit
 * value that was written. Byte-writes or unaligned writes are not included in
 * the checksum.
 *
 * The location bytes are formatted as follows (described from MSB->LSB):
 * - The first bit (MSB) is 1 for IMEM, 0 for DMEM
 * - The next 5b are zero
 * - The next 10b are the word-index of the address in memory
 *
 * The 48b value is read by ACC in little-endian order, so we accumulate it to
 * the checksum with least significant bytes first.
 *
 * @param checksum Checksum value (updated in-place).
 * @param addr Address of the write.
 * @param value Value to be written.
 */
static void update_checksum_for_write(uint32_t *checksum, uint32_t addr,
                                      uint32_t value) {
  // Calculate prefix: addr[11:2]
  uint16_t prefix = (addr & 0xfff) >> 2;
  unsigned char *prefix_bytes = (unsigned char *)&prefix;

  // The value and prefix are reversed here because of the little-endian
  // ordering.
  crc32_add32(checksum, value);
  crc32_add8(checksum, prefix_bytes[0]);
  crc32_add8(checksum, prefix_bytes[1]);
}

status_t acc_dmem_write(size_t num_words, const uint32_t *src,
                         acc_addr_t dest) {
  // Check that the write fits in DMEM.
  HARDENED_TRY(check_offset_len(dest, num_words, kAccDMemSizeBytes));

  // Calculate the base offset for DMEM.
  uint32_t dmem_addr = acc_base() + ACC_DMEM_REG_OFFSET;

  // Read the initial checksum value from ACC.
  uint32_t checksum = launder32(acc_load_checksum_get());
  HARDENED_CHECK_EQ(checksum, acc_load_checksum_get());

  // Invert the checksum to match the internal representation.
  checksum ^= UINT32_MAX;

  // Set up the iteration.
  random_order_t iter;
  random_order_init(&iter, num_words);

  // Create a copy of the iterator to use for the checksum.
  random_order_t iter_copy;
  memcpy(&iter_copy, &iter, sizeof(iter));

  // Calculate the expected checksum.
  for (size_t i = 0; i < random_order_len(&iter_copy); i++) {
    size_t idx = random_order_advance(&iter_copy);
    if (idx < num_words) {
      uint32_t addr = dest + idx * sizeof(uint32_t);
      uint32_t value = src[idx];
      update_checksum_for_write(&checksum, addr, value);
    }
  }
  RANDOM_ORDER_HARDENED_CHECK_DONE(iter_copy);
  checksum = crc32_finish(&checksum);

  // Perform the write.
  for (size_t i = 0; i < random_order_len(&iter); i++) {
    size_t idx = random_order_advance(&iter);
    size_t offset = idx * sizeof(uint32_t);

    // Prevent the compiler from re-ordering the loop.
    barrierw(offset);

    if (launder32(idx) < num_words) {
      HARDENED_CHECK_LT(idx, num_words);
      uint32_t addr = dest + offset;
      uint32_t value = src[idx];
      abs_mmio_write32(dmem_addr + addr, value);
    }
  }
  RANDOM_ORDER_HARDENED_CHECK_DONE(iter);

  // Ensure the checksum updated the same way here and on ACC.
  if (launder32(checksum) != acc_load_checksum_get()) {
    return OTCRYPTO_FATAL_ERR;
  }
  HARDENED_CHECK_EQ(checksum, acc_load_checksum_get());

  return OTCRYPTO_OK;
}

status_t acc_dmem_set(size_t num_words, const uint32_t src, acc_addr_t dest) {
  HARDENED_TRY(check_offset_len(dest, num_words, kAccDMemSizeBytes));

  // No need to randomize here, since all the values are the same.
  size_t i = 0;
  const uint32_t kBase = acc_base();
  for (; launder32(i) < num_words; ++i) {
    abs_mmio_write32(kBase + ACC_DMEM_REG_OFFSET + dest + i * sizeof(uint32_t),
                     src);
    HARDENED_CHECK_LT(i, num_words);
  }
  HARDENED_CHECK_EQ(i, num_words);
  return OTCRYPTO_OK;
}

status_t acc_dmem_read(size_t num_words, acc_addr_t src, uint32_t *dest) {
  HARDENED_TRY(check_offset_len(src, num_words, kAccDMemSizeBytes));

  size_t i = 0;
  const uint32_t kBase = acc_base();
  for (; launder32(i) < num_words; ++i) {
    dest[i] = abs_mmio_read32(kBase + ACC_DMEM_REG_OFFSET + src +
                              i * sizeof(uint32_t));
  }
  HARDENED_CHECK_EQ(i, num_words);

  return OTCRYPTO_OK;
}

status_t acc_assert_idle(void) {
  uint32_t status = launder32(~(uint32_t)kAccStatusIdle);
  status_t res = (status_t){
      .value = (int32_t)launder32((uint32_t)OTCRYPTO_OK.value ^ status)};
  status = abs_mmio_read32(acc_base() + ACC_STATUS_REG_OFFSET);
  res.value ^= ~status;
  if (launder32(OT_UNSIGNED(res.value)) == kHardenedBoolTrue) {
    HARDENED_CHECK_EQ(res.value, kHardenedBoolTrue);
    HARDENED_CHECK_EQ(abs_mmio_read32(acc_base() + ACC_STATUS_REG_OFFSET),
                      kAccStatusIdle);
    return res;
  }
  return OTCRYPTO_ASYNC_INCOMPLETE;
}

status_t acc_execute(void) {
  // Ensure ACC is idle before attempting to run a command.
  HARDENED_TRY(acc_assert_idle());

  abs_mmio_write32(acc_base() + ACC_CMD_REG_OFFSET, kAccCmdExecute);
  return OTCRYPTO_OK;
}

status_t acc_busy_wait_for_done(void) {
  uint32_t status = launder32(UINT32_MAX);
  const uint32_t kBase = acc_base();
  status_t res = (status_t){
      .value = (int32_t)launder32((uint32_t)kHardenedBoolTrue ^ status)};
  do {
    status = abs_mmio_read32(kBase + ACC_STATUS_REG_OFFSET);
  } while (launder32(status) != kAccStatusIdle &&
           launder32(status) != kAccStatusLocked);
  res.value ^= ~status;

  uint32_t err_bits = acc_err_bits_get();

  if (launder32(OT_UNSIGNED(res.value)) == kHardenedBoolTrue &&
      launder32(err_bits) == kAccErrBitsNoError) {
    HARDENED_CHECK_EQ(res.value, kHardenedBoolTrue);
    err_bits = acc_err_bits_get();
    HARDENED_CHECK_EQ(err_bits, kAccErrBitsNoError);
    HARDENED_CHECK_EQ(abs_mmio_read32(kBase + ACC_STATUS_REG_OFFSET),
                      kAccStatusIdle);
    return res;
  }

  // If ACC is idle (not locked), then return a recoverable error.
  if (launder32(status) == kAccStatusIdle) {
    HARDENED_CHECK_EQ(status, kAccStatusIdle);
    return OTCRYPTO_RECOV_ERR;
  }

  // ACC is locked; return a fatal error.
  HARDENED_CHECK_EQ(status, kAccStatusLocked);
  return OTCRYPTO_FATAL_ERR;
}

uint32_t acc_err_bits_get(void) {
  return abs_mmio_read32(acc_base() + ACC_ERR_BITS_REG_OFFSET);
}

uint32_t acc_load_checksum_get(void) {
  return abs_mmio_read32(acc_base() + ACC_LOAD_CHECKSUM_REG_OFFSET);
}

void acc_load_checksum_reset(void) {
  abs_mmio_write32(acc_base() + ACC_LOAD_CHECKSUM_REG_OFFSET, 0);
}

uint32_t acc_instruction_count_get(void) {
  return abs_mmio_read32(acc_base() + ACC_INSN_CNT_REG_OFFSET);
}

status_t acc_imem_sec_wipe(void) {
  HARDENED_TRY(acc_assert_idle());
  abs_mmio_write32(acc_base() + ACC_CMD_REG_OFFSET, kAccCmdSecWipeImem);
  HARDENED_TRY(acc_busy_wait_for_done());
  return OTCRYPTO_OK;
}

status_t acc_dmem_sec_wipe(void) {
  HARDENED_TRY(acc_assert_idle());
  abs_mmio_write32(acc_base() + ACC_CMD_REG_OFFSET, kAccCmdSecWipeDmem);
  HARDENED_TRY(acc_busy_wait_for_done());
  return OTCRYPTO_OK;
}

void acc_dmem_sec_wipe_nofail(void) {
  abs_mmio_write32(acc_base() + ACC_CMD_REG_OFFSET, kAccCmdSecWipeDmem);
}

status_t acc_set_ctrl_software_errs_fatal(bool enable) {
  // Ensure ACC is idle (otherwise CTRL writes will be ignored).
  HARDENED_TRY(acc_assert_idle());

  // Only one bit in the CTRL register so no need to read current value.
  uint32_t new_ctrl;

  if (enable) {
    new_ctrl = 1;
  } else {
    new_ctrl = 0;
  }

  abs_mmio_write32(acc_base() + ACC_CTRL_REG_OFFSET, new_ctrl);

  return OTCRYPTO_OK;
}

/**
 * Checks if the ACC application's IMEM and DMEM address parameters are valid.
 *
 * This function checks the following properties:
 * - IMEM and DMEM ranges must not be "backwards" in memory, with the end
 * address coming before the start address.
 * - The IMEM range must be non-empty.
 *
 * @param app the ACC application to check
 * @return `OTCRYPTO_OK` if checks pass, otherwise `OTCRYPTO_BAD_ARGS`.
 */
OT_WARN_UNUSED_RESULT
static status_t check_app_address_ranges(const acc_app_t *app) {
  // IMEM must not be backwards or empty.
  if (app->imem_end <= app->imem_start) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_LT(app->imem_start, app->imem_end);

  // DMEM data section must not be backwards.
  if (app->dmem_data_end < app->dmem_data_start) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_LE(app->dmem_data_start, app->dmem_data_end);

  return OTCRYPTO_OK;
}

status_t acc_load_app(const acc_app_t app) {
  HARDENED_TRY(check_app_address_ranges(&app));

  // Ensure ACC is idle.
  HARDENED_TRY(acc_assert_idle());

  const size_t imem_num_words = (size_t)(app.imem_end - app.imem_start);
  const size_t data_num_words =
      (size_t)(app.dmem_data_end - app.dmem_data_start);

  // Wipe the memories and reset the checksum register.
  HARDENED_TRY(acc_imem_sec_wipe());
  HARDENED_TRY(acc_dmem_sec_wipe());
  acc_load_checksum_reset();

  // Reset the LOAD_CHECKSUM register.
  abs_mmio_write32(acc_base() + ACC_LOAD_CHECKSUM_REG_OFFSET, 0);

  // Ensure that the IMEM section fits in IMEM and the data section fits in
  // DMEM.
  HARDENED_TRY(check_offset_len(app.dmem_data_start_addr, data_num_words,
                                kAccDMemSizeBytes));

  // Write to IMEM. Always starts at zero on the ACC side.
  acc_addr_t imem_offset = 0;
  HARDENED_TRY(
      check_offset_len(imem_offset, imem_num_words, kAccIMemSizeBytes));
  uint32_t imem_start_addr = acc_base() + ACC_IMEM_REG_OFFSET + imem_offset;
  uint32_t i = 0;
  for (; launder32(i) < imem_num_words; i++) {
    HARDENED_CHECK_LT(i, imem_num_words);
    abs_mmio_write32(imem_start_addr + i * sizeof(uint32_t), app.imem_start[i]);
  }
  HARDENED_CHECK_EQ(i, imem_num_words);

  // Write the data portion to DMEM.
  acc_addr_t data_offset = app.dmem_data_start_addr;
  HARDENED_TRY(
      check_offset_len(data_offset, data_num_words, kAccDMemSizeBytes));
  uint32_t data_start_addr = acc_base() + ACC_DMEM_REG_OFFSET + data_offset;
  i = 0;
  for (; launder32(i) < data_num_words; i++) {
    HARDENED_CHECK_LT(i, data_num_words);
    abs_mmio_write32(data_start_addr + i * sizeof(uint32_t),
                     app.dmem_data_start[i]);
  }
  HARDENED_CHECK_EQ(i, data_num_words);

  // Ensure that the checksum matches expectations.
  uint32_t checksum =
      abs_mmio_read32(acc_base() + ACC_LOAD_CHECKSUM_REG_OFFSET);
  if (launder32(checksum) != app.checksum) {
    return OTCRYPTO_FATAL_ERR;
  }
  HARDENED_CHECK_EQ(checksum, app.checksum);

  return OTCRYPTO_OK;
}
