// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_LIB_TESTING_ACC_TESTUTILS_H_
#define OPENTITAN_SW_DEVICE_LIB_TESTING_ACC_TESTUTILS_H_

#include "sw/device/lib/base/mmio.h"
#include "sw/device/lib/base/status.h"
#include "sw/device/lib/dif/dif_acc.h"
#include "sw/device/lib/dif/dif_base.h"

/**
 * @file
 * @brief Asymmetric Cryptographic Coprocessor (ACC) driver
 */

/**
 * Information about an embedded ACC application image.
 *
 * All pointers reference data in the normal CPU address space.
 *
 * Use `ACC_DECLARE_APP_SYMBOLS()` together with `ACC_APP_T_INIT()` to
 * initialize this structure.
 */
typedef struct acc_app {
  /**
   * Start of ACC instruction memory.
   */
  const uint8_t *imem_start;
  /**
   * End of ACC instruction memory.
   */
  const uint8_t *imem_end;
  /**
   * Start of initialized ACC data memory.
   *
   * Data in this section is copied into DMEM when the app is loaded.
   */
  const uint8_t *dmem_data_start;
  /**
   * End of initialized ACC data memory.
   */
  const uint8_t *dmem_data_end;
} acc_app_t;

/**
 * The address of an ACC symbol as seen by ACC
 *
 * Use `ACC_DECLARE_SYMBOL_ADDR()` together with `ACC_ADDR_T_INIT()` to
 * initialize this type.
 */
typedef uint32_t acc_addr_t;

/**
 * Generate the prefix to add to an ACC symbol name used on the Ibex side
 *
 * The result is a pointer to Ibex's rodata that should be used to initialise
 * memory for that symbol.
 *
 * This is needed by the ACC driver to support DMEM/IMEM ranges but
 * application code shouldn't need to use this. Use the `acc_addr_t` type and
 * supporting macros instead.
 */
#define ACC_SYMBOL_PTR(app_name, sym) _acc_local_app_##app_name##_##sym

/**
 * Generate the prefix to add to an ACC symbol name used on the ACC side
 *
 * The result is a pointer whose integer value is the address by which the
 * symbol should be accessed in ACC memory.
 *
 * This is an internal macro used in `ACC_DECLARE_SYMBOL_ADDR` and
 * `ACC_ADDR_T_INIT` but application code shouldn't need to use it directly.
 */
#define ACC_SYMBOL_ADDR(app_name, sym) _acc_remote_app_##app_name##_##sym

/**
 * Makes a symbol in the ACC application image available.
 *
 * This is needed by the ACC driver to support DMEM/IMEM ranges but
 * application code shouldn't need to use this. To get access to ACC
 * addresses, use `ACC_DECLARE_SYMBOL_ADDR` instead.
 */
#define ACC_DECLARE_SYMBOL_PTR(app_name, symbol_name) \
  extern const uint8_t ACC_SYMBOL_PTR(app_name, symbol_name)[]

/**
 * Makes the ACC address of a symbol in the ACC application available.
 *
 * Symbols are typically function or data pointers, i.e. labels in assembly
 * code. Unlike ACC_DECLARE_SYMBOL_PTR, this will work for symbols in the .bss
 * section (which exist on the ACC side, even though they don't have backing
 * data on Ibex).
 *
 * Use this macro instead of manually declaring the symbols as symbol names
 * might change.
 *
 * @param app_name    Name of the application the function is contained in.
 * @param symbol_name Name of the symbol (function, label).
 */
#define ACC_DECLARE_SYMBOL_ADDR(app_name, symbol_name) \
  extern const uint8_t ACC_SYMBOL_ADDR(app_name, symbol_name)[]

/**
 * Makes an embedded ACC application image available for use.
 *
 * Make symbols available that indicate the start and the end of instruction
 * and data memory regions, as they are stored in the device memory.
 *
 * Use this macro instead of manually declaring the symbols as symbol names
 * might change.
 *
 * @param app_name Name of the application to load, which is typically the
 *                 name of the main (assembly) source file.
 */
#define ACC_DECLARE_APP_SYMBOLS(app_name)             \
  ACC_DECLARE_SYMBOL_PTR(app_name, _imem_start);      \
  ACC_DECLARE_SYMBOL_PTR(app_name, _imem_end);        \
  ACC_DECLARE_SYMBOL_PTR(app_name, _dmem_data_start); \
  ACC_DECLARE_SYMBOL_PTR(app_name, _dmem_data_end)

/**
 * Initializes the ACC application information structure.
 *
 * After making all required symbols from the application image available
 * through `ACC_DECLARE_APP_SYMBOLS()`, use this macro to initialize an
 * `acc_app_t` struct with those symbols.
 *
 * @param app_name Name of the application to load.
 * @see ACC_DECLARE_APP_SYMBOLS()
 */
#define ACC_APP_T_INIT(app_name)                                     \
  ((acc_app_t){                                                      \
      .imem_start = ACC_SYMBOL_PTR(app_name, _imem_start),           \
      .imem_end = ACC_SYMBOL_PTR(app_name, _imem_end),               \
      .dmem_data_start = ACC_SYMBOL_PTR(app_name, _dmem_data_start), \
      .dmem_data_end = ACC_SYMBOL_PTR(app_name, _dmem_data_end),     \
  })

/**
 * Initializes an `acc_addr_t`.
 */
#define ACC_ADDR_T_INIT(app_name, symbol_name) \
  ((uint32_t)ACC_SYMBOL_ADDR(app_name, symbol_name))

/**
 * (Re-)loads the application into ACC.
 *
 * Load the application image with both instruction and data segments into ACC.
 *
 * @param acc The context object.
 * @param app The application to load into ACC.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
status_t acc_testutils_load_app(const dif_acc_t *acc, const acc_app_t app);

/**
 * Starts the ACC execute operation.
 *
 * Use `acc_testutils_wait_for_done()` to wait for execution to complete.
 *
 * @param acc The context object.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
status_t acc_testutils_execute(const dif_acc_t *acc);

/**
 * Waits for ACC to be done with the current operation.
 *
 * Polls the status register until ACC is idle. Produces a CHECK-fail if ACC
 * is or becomes locked. Checks that the final error bits match expectations.
 *
 * @param acc The context object.
 * @param expected_err_bits Expected error bits.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
status_t acc_testutils_wait_for_done(const dif_acc_t *acc,
                                     dif_acc_err_bits_t expected_err_bits);

/**
 * Copies data from the CPU memory to ACC data memory.
 *
 * @param acc The context object.
 * @param len_bytes Number of bytes to copy.
 * @param dest Address of the destination in ACC's data memory.
 * @param src Source of the data to copy.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
status_t acc_testutils_write_data(const dif_acc_t *acc, size_t len_bytes,
                                  const void *src, acc_addr_t dest);

/**
 * Copies data from ACC's data memory to CPU memory.
 *
 * @param acc The context object.
 * @param len_bytes The number of bytes to copy.
 * @param src The address in ACC data memory to copy from.
 * @param[out] dest The destination of the copied data in main memory
 *                  (preallocated).
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
status_t acc_testutils_read_data(const dif_acc_t *acc, size_t len_bytes,
                                 acc_addr_t src, void *dest);

/**
 * Writes a LOG_INFO message with the contents of each 256b DMEM word.
 *
 * @param acc The context object.
 * @param max_addr The highest address to dump. Set to 0 to output the whole
 *                 DMEM. Must be a multiple of WLEN.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
status_t acc_testutils_dump_dmem(const dif_acc_t *acc, uint32_t max_addr);

#endif  // OPENTITAN_SW_DEVICE_LIB_TESTING_ACC_TESTUTILS_H_
