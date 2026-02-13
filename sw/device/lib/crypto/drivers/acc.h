// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_LIB_CRYPTO_DRIVERS_ACC_H_
#define OPENTITAN_SW_DEVICE_LIB_CRYPTO_DRIVERS_ACC_H_

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "sw/device/lib/crypto/impl/status.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Constants related to ACC wide words
 */
enum {
  /* Length of an ACC wide word in bits */
  kAccWideWordNumBits = 256,
  /* Length of an ACC wide word in bytes */
  kAccWideWordNumBytes = kAccWideWordNumBits / 8,
  /* Length of an ACC wide word in words */
  kAccWideWordNumWords = kAccWideWordNumBytes / sizeof(uint32_t),
};

/**
 * The address of an ACC symbol as seen by ACC.
 *
 * Use `ACC_DECLARE_SYMBOL_ADDR()` together with `ACC_ADDR_T_INIT()` to
 * initialize this type.
 */
typedef uint32_t acc_addr_t;

/**
 * Information about an embedded ACC application image.
 *
 * All pointers reference data in the normal CPU address space.
 * uint32_t values are addresses in the ACC address space.
 *
 * Use `ACC_DECLARE_APP_SYMBOLS()` together with `ACC_APP_T_INIT()` to
 * initialize this structure.
 */
typedef struct acc_app {
  /**
   * Start of ACC instruction memory in the embedded program.
   *
   * This pointer references Ibex's memory.
   */
  const uint32_t *imem_start;
  /**
   * The first word after ACC instruction memory in the embedded program.
   *
   * This pointer references Ibex's memory.
   *
   * This address satifies `imem_start < imem_end`.
   */
  const uint32_t *imem_end;
  /**
   * Start of initialized ACC data in the embedded program.
   *
   * This pointer references Ibex's memory.
   *
   * Data in between `dmem_data_start` and `dmem_data_end` will be copied to
   * ACC at app load time.
   */
  const uint32_t *dmem_data_start;
  /**
   * The first word after initialized ACC data in the embedded program.
   *
   * This pointer references Ibex's memory.
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
  const acc_addr_t dmem_data_start_addr;
  /**
   * Application checksum.
   *
   * This value represents a CRC32 checksum over IMEM and the `.data` portion
   * of DMEM.
   */
  const uint32_t checksum;
} acc_app_t;

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
#define ACC_DECLARE_APP_SYMBOLS(app_name)              \
  ACC_DECLARE_SYMBOL_PTR(app_name, _imem_start);       \
  ACC_DECLARE_SYMBOL_PTR(app_name, _imem_end);         \
  ACC_DECLARE_SYMBOL_PTR(app_name, _dmem_data_start);  \
  ACC_DECLARE_SYMBOL_PTR(app_name, _dmem_data_end);    \
  ACC_DECLARE_SYMBOL_ADDR(app_name, _dmem_data_start); \
  ACC_DECLARE_SYMBOL_ADDR(app_name, _checksum)

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
#define ACC_APP_T_INIT(app_name)                                           \
  ((acc_app_t){                                                            \
      .imem_start = ACC_SYMBOL_PTR(app_name, _imem_start),                 \
      .imem_end = ACC_SYMBOL_PTR(app_name, _imem_end),                     \
      .dmem_data_start = ACC_SYMBOL_PTR(app_name, _dmem_data_start),       \
      .dmem_data_end = ACC_SYMBOL_PTR(app_name, _dmem_data_end),           \
      .dmem_data_start_addr = ACC_ADDR_T_INIT(app_name, _dmem_data_start), \
      .checksum = ACC_ADDR_T_INIT(app_name, _checksum),                    \
  })

/**
 * Initializes an `acc_addr_t`.
 */
#define ACC_ADDR_T_INIT(app_name, symbol_name) \
  ((uint32_t)ACC_SYMBOL_ADDR(app_name, symbol_name))

/**
 * Variant of HARDENED_TRY that wipes DMEM before returning.
 *
 * Use this for operations that might fail after secret values were written to
 * DMEM, so that later routines cannot read the data from the cancelled
 * operation.
 *
 * @param expr_ An expression that evaluates to a `status_t`.
 */
#ifndef OT_DISABLE_HARDENING
#define ACC_WIPE_IF_ERROR(expr_)                                        \
  do {                                                                  \
    status_t status_ = expr_;                                           \
    if (launder32(OT_UNSIGNED(status_.value)) != kHardenedBoolTrue) {   \
      acc_dmem_sec_wipe_nofail();                                       \
      return (status_t){                                                \
          .value = (int32_t)(OT_UNSIGNED(status_.value) | 0x80000000)}; \
    }                                                                   \
    HARDENED_CHECK_EQ(status_.value, kHardenedBoolTrue);                \
  } while (false)
#else  // OT_DISABLE_HARDENING
#define ACC_WIPE_IF_ERROR(expr_)                                        \
  do {                                                                  \
    status_t status_ = expr_;                                           \
    if (status_.value != kHardenedBoolTrue) {                           \
      acc_dmem_sec_wipe_nofail();                                       \
      return (status_t){                                                \
          .value = (int32_t)(OT_UNSIGNED(status_.value) | 0x80000000)}; \
    }                                                                   \
  } while (false)
#endif  // OT_DISABLE_HARDENING

/**
 * Checks that a provided operation completed with a valid instuction count.
 *
 * @param operation_ The operation performed, used to reference autogenerated
 *        constants created by `autogen_acc_insn_count_header`.
 */
#ifndef OT_DISABLE_HARDENING
#define ACC_CHECK_INSN_COUNT(min_count_, max_count_)          \
  do {                                                        \
    uint32_t insn_count = acc_instruction_count_get();        \
    if (insn_count < min_count_ || insn_count > max_count_) { \
      acc_dmem_sec_wipe_nofail();                             \
      return OTCRYPTO_FATAL_ERR;                              \
    }                                                         \
    HARDENED_CHECK_GE(insn_count, min_count_);                \
    HARDENED_CHECK_LE(insn_count, max_count_);                \
  } while (false)
#else  // OT_DISABLE_HARDENING
#define ACC_CHECK_INSN_COUNT(min_count_, max_count_)          \
  do {                                                        \
    uint32_t insn_count = acc_instruction_count_get();        \
    if (insn_count < min_count_ || insn_count > max_count_) { \
      acc_dmem_sec_wipe_nofail();                             \
      return OTCRYPTO_FATAL_ERR;                              \
    }                                                         \
  } while (false)
#endif  // OT_DISABLE_HARDENING

/**
 * Write to ACC's data memory (DMEM)
 *
 * Only 32b-aligned 32b word accesses are allowed. If `dest` is not
 * word-aligned or if the length and offset exceed the DMEM size, this function
 * will return an error.
 *
 * Automatically checks that ACC's LOAD_CHECKSUM register updates as expected
 * for consistency.
 *
 * The caller must ensure ACC is idle before calling this function.
 *
 * @param num_words Length of the data in 32-bit words.
 * @param src The main memory location to copy from.
 * @param dest The DMEM location to copy to.
 * @return Result of the operation.
 */
OT_WARN_UNUSED_RESULT
status_t acc_dmem_write(size_t num_words, const uint32_t *src, acc_addr_t dest);

/**
 * Set a range of ACC's data memory (DMEM) to a particular value.
 *
 * Only 32b-aligned 32b word accesses are allowed. If `dest` is not
 * word-aligned or if the length and offset exceed the DMEM size, this function
 * will return an error.
 *
 * The caller must ensure ACC is idle before calling this function.
 *
 * @param num_words Length of the range to set in 32-bit words.
 * @param src The value to set each word in DMEM to.
 * @param dest The DMEM location to set.
 * @return Result of the operation.
 */
OT_WARN_UNUSED_RESULT
status_t acc_dmem_set(size_t num_words, const uint32_t src, acc_addr_t dest);

/**
 * Read from ACC's data memory (DMEM)
 *
 * Only 32b-aligned 32b word accesses are allowed. If `src` is not word-aligned
 * or if the length and offset exceed the DMEM size, this function will return
 * an error.
 *
 * The caller must ensure ACC is idle before calling this function.
 *
 * @param num_words Length of the data in 32-bit words.
 * @param src The DMEM location to copy from.
 * @param[out] dest The main memory location to copy to.
 * @return Result of the operation.
 */
OT_WARN_UNUSED_RESULT
status_t acc_dmem_read(size_t num_words, acc_addr_t src, uint32_t *dest);

/**
 * Ensures ACC is idle.
 *
 * If ACC is busy or locked, this function will return
 * `OTCRYPTO_ASYNC_INCOMPLETE`; otherwise it will return `OTCRYPTO_OK`.
 *
 * @return Result of the operation.
 */
status_t acc_assert_idle(void);

/**
 * Start the execution of the application loaded into ACC.
 *
 * This function returns an error if called when ACC is not idle.
 *
 * The caller is responsible for initializing the entropy complex before
 * calling this function, even if the RND register is not being used. ACC
 * still consumes randomness for the secure wipe of its internal state before
 * exiting the program, and will lock if entropy is unavailable.
 *
 * @return Result of the operation.
 */
OT_WARN_UNUSED_RESULT
status_t acc_execute(void);

/**
 * Blocks until ACC is idle.
 *
 * If ACC is or becomes locked, an error will occur.
 *
 * @return Result of the operation.
 */
OT_WARN_UNUSED_RESULT
status_t acc_busy_wait_for_done(void);

/**
 * Get the error bits set by the device if the operation failed.
 *
 * @return The contents of ACC's ERR_BITS register.
 */
uint32_t acc_err_bits_get(void);

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
uint32_t acc_instruction_count_get(void);

/**
 * Get the checksum value of loaded data from ACC.
 *
 * @return The contents of ACC's LOAD_CHECKSUM register.
 */
uint32_t acc_load_checksum_get(void);

/**
 * Reset the value of ACC's LOAD_CHECKSUM register.
 *
 * Sets the checksum value to all-zero.
 */
void acc_load_checksum_reset(void);

/**
 * Wipe IMEM securely.
 *
 * This function returns an error if called when ACC is not idle, and blocks
 * until the secure wipe is complete.
 *
 * The caller is responsible for initializing the entropy complex before
 * calling this function, since it consumes randomness. If entropy is not
 * available, ACC will lock itself.
 *
 * @return Result of the operation.
 */
OT_WARN_UNUSED_RESULT
status_t acc_imem_sec_wipe(void);

/**
 * Wipe DMEM securely.
 *
 * This function returns an error if called when ACC is not idle, and blocks
 * until the secure wipe is complete.
 *
 * The caller is responsible for initializing the entropy complex before
 * calling this function, since it consumes randomness. If entropy is not
 * available, ACC will lock itself.
 *
 * @return Result of the operation.
 */
OT_WARN_UNUSED_RESULT
status_t acc_dmem_sec_wipe(void);

/**
 * Variant of acc_dmem_sec_wipe that does not error or block.
 *
 * Intended for cases where another operation has failed and we want to wipe
 * DMEM before returning the error code up the stack.
 */
void acc_dmem_sec_wipe_nofail(void);

/**
 * Sets the software errors are fatal bit in the control register.
 *
 * When set any software error becomes a fatal error. The bit can only be
 * changed when the ACC status is IDLE.
 *
 * This function returns an error if called when ACC is not idle.
 *
 * @param enable Enable or disable whether software errors are fatal.
 * @return Result of the operation.
 */
OT_WARN_UNUSED_RESULT
status_t acc_set_ctrl_software_errs_fatal(bool enable);

/**
 * (Re-)loads the provided application into ACC.
 *
 * Load the application image with both instruction and data segments into
 * ACC.
 *
 * This function will return an error if called when ACC is not idle.
 *
 * Because this function uses the ACC secure wipe functionality before
 * loading, it will lock ACC if the entropy complex is not initialized.
 *
 * @param ctx The context object.
 * @param app The application to load into ACC.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
status_t acc_load_app(const acc_app_t app);

#ifdef __cplusplus
}
#endif

#endif  // OPENTITAN_SW_DEVICE_LIB_CRYPTO_DRIVERS_ACC_H_
