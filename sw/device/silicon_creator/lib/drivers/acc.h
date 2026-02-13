// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_SILICON_CREATOR_LIB_DRIVERS_ACC_H_
#define OPENTITAN_SW_DEVICE_SILICON_CREATOR_LIB_DRIVERS_ACC_H_

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "sw/device/silicon_creator/lib/error.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Constants related to ACC wide words
 */
enum {
  /* Length of an ACC wide word in bits */
  kScAccWideWordNumBits = 256,
  /* Length of an ACC wide word in words */
  kScAccWideWordNumWords = kScAccWideWordNumBits / (sizeof(uint32_t) * 8),
};

/**
 * The following constants represent the expected number of sec_mmio register
 * writes performed by functions in provided in this module. See
 * `SEC_MMIO_WRITE_INCREMENT()` for more details.
 *
 * Example:
 * ```
 *  sc_acc_execute();
 *  SEC_MMIO_WRITE_INCREMENT(kScAccSecMmioExecute);
 * ```
 */
enum {
  kScAccSecMmioExecute = 1,
};

/**
 * ACC commands
 *
 * TODO(#16754): replace these with constants from acc_regs.h
 */
typedef enum sc_acc_cmd {
  kScAccCmdExecute = 0xd8,
  kScAccCmdSecWipeDmem = 0xc3,
  kScAccCmdSecWipeImem = 0x1e,
} sc_acc_cmd_t;

/**
 * ACC status
 *
 * TODO(#16754): replace these with constants from acc_regs.h
 */
typedef enum sc_acc_status {
  kScAccStatusIdle = 0x00,
  kScAccStatusBusyExecute = 0x01,
  kScAccStatusBusySecWipeDmem = 0x02,
  kScAccStatusBusySecWipeImem = 0x03,
  kScAccStatusBusySecWipeInt = 0x04,
  kScAccStatusLocked = 0xFF,
} sc_acc_status_t;

/**
 * The address of an ACC symbol as seen by ACC
 *
 * Use `ACC_DECLARE_SYMBOL_ADDR()` together with `ACC_ADDR_T_INIT()` to
 * initialize this type.
 */
typedef uint32_t sc_acc_addr_t;

/**
 * Information about an embedded ACC application image.
 *
 * All pointers reference data in the normal CPU address space.
 * uint32_t values are addresses in the ACC address space.
 *
 * Use `ACC_DECLARE_APP_SYMBOLS()` together with `ACC_APP_T_INIT()` to
 * initialize this structure.
 */
typedef struct sc_acc_app {
  /**
   * Start of ACC instruction memory.
   */
  const uint32_t *imem_start;
  /**
   * The first word after ACC instruction memory.
   *
   * This address satifies `imem_len = imem_end - imem_start`.
   */
  const uint32_t *imem_end;
  /**
   * Start of initialized ACC data.
   *
   * Data in between dmem_data_start and dmem_data_end will be copied to ACC
   * at app load time.
   */
  const uint32_t *dmem_data_start;
  /**
   * The first word after initialized ACC data.
   *
   * Should satisfy `dmem_data_start <= dmem_data_end`.
   */
  const uint32_t *dmem_data_end;
  /**
   * Start of initialized data section in ACC's DMEM.
   *
   * This pointer references ACC's memory and is used to copy data at app load
   * time.
   */
  const sc_acc_addr_t dmem_data_start_addr;
} sc_acc_app_t;

/**
 * Generate the prefix to add to an ACC symbol name used on the Ibex side
 *
 * The result is a pointer to Ibex's rodata that should be used to initialise
 * memory for that symbol.
 *
 * This is needed by the ACC driver to support DMEM/IMEM ranges but
 * application code shouldn't need to use this. Use the `sc_acc_addr_t` type
 * and supporting macros instead.
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
  extern const uint32_t ACC_SYMBOL_PTR(app_name, symbol_name)[]

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
  extern const uint32_t ACC_SYMBOL_ADDR(app_name, symbol_name)[]

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
  ACC_DECLARE_SYMBOL_PTR(app_name, _dmem_data_end);   \
  ACC_DECLARE_SYMBOL_ADDR(app_name, _dmem_data_start);

/**
 * Initializes the ACC application information structure.
 *
 * After making all required symbols from the application image available
 * through `ACC_DECLARE_APP_SYMBOLS()`, use this macro to initialize an
 * `sc_acc_app_t` struct with those symbols.
 *
 * @param app_name Name of the application to load.
 * @see ACC_DECLARE_APP_SYMBOLS()
 */
#define ACC_APP_T_INIT(app_name)                                           \
  ((sc_acc_app_t){                                                         \
      .imem_start = ACC_SYMBOL_PTR(app_name, _imem_start),                 \
      .imem_end = ACC_SYMBOL_PTR(app_name, _imem_end),                     \
      .dmem_data_start = ACC_SYMBOL_PTR(app_name, _dmem_data_start),       \
      .dmem_data_end = ACC_SYMBOL_PTR(app_name, _dmem_data_end),           \
      .dmem_data_start_addr = ACC_ADDR_T_INIT(app_name, _dmem_data_start), \
  })

/**
 * Initializes an `sc_acc_addr_t`.
 */
#define ACC_ADDR_T_INIT(app_name, symbol_name) \
  ((uint32_t)ACC_SYMBOL_ADDR(app_name, symbol_name))

/**
 * (Re-)loads an application into ACC.
 *
 * Load the application image with both instruction and data segments into
 * ACC.
 *
 * @param app The application to load into ACC.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
rom_error_t sc_acc_load_app(const sc_acc_app_t app);

/**
 * Copies data from the CPU memory to ACC data memory.
 *
 * @param num_words Number of 32b words to copy.
 * @param dest Address of the destination in ACC's data memory.
 * @param src Source of the data to copy.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
rom_error_t sc_acc_dmem_write(size_t num_words, const uint32_t *src,
                               sc_acc_addr_t dest);

/**
 * Copies data from ACC's data memory to CPU memory.
 *
 * @param num_words The number of 32b words to copy.
 * @param src The address in ACC data memory to copy from.
 * @param[out] dest The destination of the copied data in main memory
 *                  (preallocated).
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
rom_error_t sc_acc_dmem_read(size_t num_words, const sc_acc_addr_t src,
                              uint32_t *dest);

/**
 * Start the execution of the application loaded into ACC.
 *
 * This function blocks until ACC is idle.
 *
 * @return Result of the operation.
 */
OT_WARN_UNUSED_RESULT
rom_error_t sc_acc_execute(void);

/**
 * Blocks until ACC is idle.
 *
 * If ACC is or becomes locked, an error will occur.
 *
 * @return Result of the operation.
 */
OT_WARN_UNUSED_RESULT
rom_error_t sc_acc_busy_wait_for_done(void);

/**
 * Read ACC's instruction count register.
 *
 * ACC automatically calculates how many instructions are executed in a given
 * program and writes the result to this register. Software can read it to
 * verify that instructions were not unexpectedly skipped or added (for
 * instance, due to fault injection attacks).
 *
 * Note that the ACC hardware resets the instruction count register to 0 when
 * the EXECUTE command is issued, so there is no need for software to reset the
 * counter between programs.
 *
 * @return count the value from the instruction count register
 */
OT_WARN_UNUSED_RESULT
uint32_t sc_acc_instruction_count_get(void);

/**
 * Wipe IMEM securely.
 *
 * This function blocks until ACC is idle.
 *
 * @return Result of the operation.
 */
OT_WARN_UNUSED_RESULT
rom_error_t sc_acc_imem_sec_wipe(void);

/**
 * Wipe DMEM securely.
 *
 * This function blocks until ACC is idle.
 *
 * @return Result of the operation.
 */
OT_WARN_UNUSED_RESULT
rom_error_t sc_acc_dmem_sec_wipe(void);

#ifdef __cplusplus
}
#endif

#endif  // OPENTITAN_SW_DEVICE_SILICON_CREATOR_LIB_DRIVERS_ACC_H_
