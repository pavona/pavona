// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/testing/acc_testutils.h"

#include "sw/device/lib/base/mmio.h"
#include "sw/device/lib/dif/dif_acc.h"
#include "sw/device/lib/dif/dif_base.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/test_framework/check.h"

#define MODULE_ID MAKE_MODULE_ID('o', 'b', 't')

enum {
  /**
   * Data width of big number subset, in bytes.
   */
  kAccWlenBytes = 256 / 8,
};

status_t acc_testutils_wait_for_done(const dif_acc_t *acc,
                                     dif_acc_err_bits_t expected_err_bits) {
  bool busy = true;
  dif_acc_status_t status;
  while (busy) {
    TRY(dif_acc_get_status(acc, &status));
    busy = status != kDifAccStatusIdle && status != kDifAccStatusLocked;
  }

  // Get instruction count so that we can print them to help with debugging.
  uint32_t instruction_count;
  TRY(dif_acc_get_insn_cnt(acc, &instruction_count));

  dif_acc_err_bits_t err_bits;
  TRY(dif_acc_get_err_bits(acc, &err_bits));

  // Error out if ACC is locked.
  TRY_CHECK(status == kDifAccStatusIdle, "ACC is locked. Error bits: 0x%08x",
            err_bits);

  // Error out if error bits do not match expectations.
  TRY_CHECK(
      err_bits == expected_err_bits,
      "ACC error bits: got: 0x%08x, expected: 0x%08x.\nInstruction count: "
      "0x%08x",
      err_bits, expected_err_bits, instruction_count);
  return OK_STATUS();
}

/**
 * Checks if the ACC application's IMEM and DMEM address parameters are valid.
 *
 * IMEM and DMEM ranges must not be "backwards" in memory, with the end address
 * coming before the start address, and the IMEM range must additionally be
 * non-empty. Finally, separate sections in DMEM must not overlap each other
 * when converted to DMEM address space.
 *
 * @param app the ACC application to check
 */
static void check_app_address_ranges(const acc_app_t *app) {
  // IMEM must have a strictly positive range (cannot be backwards or empty)
  CHECK(app->imem_end > app->imem_start);
  // Initialised DMEM section must not be backwards
  CHECK(app->dmem_data_end >= app->dmem_data_start);
}

status_t acc_testutils_load_app(const dif_acc_t *acc, const acc_app_t app) {
  check_app_address_ranges(&app);

  const size_t imem_size = (size_t)(app.imem_end - app.imem_start);
  const size_t data_size = (size_t)(app.dmem_data_end - app.dmem_data_start);

  // Memory images and offsets must be multiples of 32b words.
  TRY_CHECK(imem_size % sizeof(uint32_t) == 0);
  TRY_CHECK(data_size % sizeof(uint32_t) == 0);

  TRY(dif_acc_imem_write(acc, 0, app.imem_start, imem_size));

  // Write initialized data
  if (data_size > 0) {
    TRY(dif_acc_dmem_write(acc, 0, app.dmem_data_start, data_size));
  }
  return OK_STATUS();
}

status_t acc_testutils_execute(const dif_acc_t *acc) {
  TRY(dif_acc_write_cmd(acc, kDifAccCmdExecute));
  return OK_STATUS();
}

status_t acc_testutils_write_data(const dif_acc_t *acc, size_t len_bytes,
                                  const void *src, acc_addr_t dest) {
  TRY(dif_acc_dmem_write(acc, dest, src, len_bytes));
  return OK_STATUS();
}

status_t acc_testutils_read_data(const dif_acc_t *acc, size_t len_bytes,
                                 acc_addr_t src, void *dest) {
  TRY(dif_acc_dmem_read(acc, src, dest, len_bytes));
  return OK_STATUS();
}

status_t acc_dump_dmem(const dif_acc_t *acc, uint32_t max_addr) {
  TRY_CHECK(max_addr % kAccWlenBytes == 0);

  if (max_addr == 0) {
    max_addr = dif_acc_get_dmem_size_bytes(acc);
  }

  TRY_CHECK(max_addr <= UINT32_MAX, "max_addr must fit in uint32_t");
  for (uint32_t i = 0; i < max_addr; i += kAccWlenBytes) {
    uint32_t data[kAccWlenBytes / sizeof(uint32_t)];
    TRY(dif_acc_dmem_read(acc, i, data, kAccWlenBytes));
    LOG_INFO("DMEM @%04d: 0x%08x%08x%08x%08x%08x%08x%08x%08x",
             i / kAccWlenBytes, data[7], data[6], data[5], data[4], data[3],
             data[2], data[1], data[0]);
  }
  return OK_STATUS();
}
