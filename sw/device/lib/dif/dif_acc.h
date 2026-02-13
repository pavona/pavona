// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_LIB_DIF_DIF_ACC_H_
#define OPENTITAN_SW_DEVICE_LIB_DIF_DIF_ACC_H_

/**
 * @file
 * @brief <a href="/book/hw/ip/acc/">ACC</a> Device Interface Functions.
 */

#include <stddef.h>
#include <stdint.h>

#include "sw/device/lib/base/mmio.h"
#include "sw/device/lib/dif/dif_base.h"

#include "sw/device/lib/dif/autogen/dif_acc_autogen.h"

#ifdef __cplusplus
extern "C" {
#endif  // __cplusplus

/**
 * ACC commands.
 */
typedef enum dif_acc_cmd {
  kDifAccCmdExecute = 0xd8,
  kDifAccCmdSecWipeDmem = 0xc3,
  kDifAccCmdSecWipeImem = 0x1e,
} dif_acc_cmd_t;

/**
 * ACC status.
 */
typedef enum dif_acc_status {
  kDifAccStatusIdle = 0x00,
  kDifAccStatusBusyExecute = 0x01,
  kDifAccStatusBusySecWipeDmem = 0x02,
  kDifAccStatusBusySecWipeImem = 0x03,
  kDifAccStatusBusySecWipeInt = 0x04,
  kDifAccStatusLocked = 0xFF,
} dif_acc_status_t;

/**
 * ACC Errors.
 *
 * ACC uses a bitfield to indicate which errors have been seen. Multiple errors
 * can be seen at the same time. This enum gives the individual bits that may be
 * set for different errors.
 */
typedef enum dif_acc_err_bits {
  kDifAccErrBitsNoError = 0,
  /** A BAD_DATA_ADDR error was observed. */
  kDifAccErrBitsBadDataAddr = (1 << 0),
  /** A BAD_INSN_ADDR error was observed. */
  kDifAccErrBitsBadInsnAddr = (1 << 1),
  /** A CALL_STACK error was observed. */
  kDifAccErrBitsCallStack = (1 << 2),
  /** An ILLEGAL_INSN error was observed. */
  kDifAccErrBitsIllegalInsn = (1 << 3),
  /** A LOOP error was observed. */
  kDifAccErrBitsLoop = (1 << 4),
  /** A RND_FIPS_CHECK_FAIL error was observed. */
  kDifAccErrBitsRndFipsChkFail = (1 << 7),
  /** A IMEM_INTG_VIOLATION error was observed. */
  kDifAccErrBitsImemIntgViolation = (1 << 16),
  /** A DMEM_INTG_VIOLATION error was observed. */
  kDifAccErrBitsDmemIntgViolation = (1 << 17),
  /** A REG_INTG_VIOLATION error was observed. */
  kDifAccErrBitsRegIntgViolation = (1 << 18),
  /** A BUS_INTG_VIOLATION error was observed. */
  kDifAccErrBitsBusIntgViolation = (1 << 19),
  /** A BAD_INTERNAL_STATE error was observed. */
  kDifAccErrBitsBadInternalState = (1 << 20),
  /** An ILLEGAL_BUS_ACCESS error was observed. */
  kDifAccErrBitsIllegalBusAccess = (1 << 21),
  /** A LIFECYCLE_ESCALATION error was observed. */
  kDifAccErrBitsLifecycleEscalation = (1 << 22),
  /** A FATAL_SOFTWARE error was observed. */
  kDifAccErrBitsFatalSoftware = (1 << 23),
} dif_acc_err_bits_t;

/**
 * Reset ACC device.
 *
 * Resets the given ACC device by setting its configuration registers to
 * reset values. Disables interrupts, output, and input filter.
 *
 * @param acc ACC instance.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
dif_result_t dif_acc_reset(const dif_acc_t *acc);

/**
 * Start an operation by issuing a command.
 *
 * @param acc ACC instance.
 * @param cmd The command.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
dif_result_t dif_acc_write_cmd(const dif_acc_t *acc, dif_acc_cmd_t cmd);

/**
 * Gets the current status of ACC.
 *
 * @param acc ACC instance.
 * @param[out] status ACC status.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
dif_result_t dif_acc_get_status(const dif_acc_t *acc, dif_acc_status_t *status);

/**
 * Get the error bits set by the device if the operation failed.
 *
 * @param acc ACC instance.
 * @param[out] err_bits The error bits returned by the hardware.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
dif_result_t dif_acc_get_err_bits(const dif_acc_t *acc,
                                  dif_acc_err_bits_t *err_bits);

/**
 * Gets the number of executed ACC instructions.
 *
 * Gets the number of instructions executed so far in the current ACC run if
 * there is one. Otherwise, gets the number executed in total in the previous
 * ACC run.
 *
 * @param acc ACC instance.
 * @param[out] insn_cnt The number of instructions executed by ACC.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
dif_result_t dif_acc_get_insn_cnt(const dif_acc_t *acc, uint32_t *insn_cnt);

/**
 * Gets the content of the load checksum register.
 *
 * Gets the 32-bit CRC checksum of data written to memory.
 *
 * @param acc ACC instance.
 * @param[out] insn_cnt The number of instructions executed by ACC.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
dif_result_t dif_acc_get_load_checksum(const dif_acc_t *acc,
                                       uint32_t *insn_cnt);

/**
 * Clears the load checksum register.
 *
 * Writes 0 to the load checksum register to clear it.
 *
 * @param acc ACC instance.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
dif_result_t dif_acc_clear_load_checksum(const dif_acc_t *acc);

/**
 * Write an ACC application into its instruction memory (IMEM).
 *
 * Only 32b-aligned 32b word accesses are allowed.
 *
 * @param acc ACC instance.
 * @param offset_bytes the byte offset in IMEM the first word is written to.
 * @param src the main memory location to start reading from.
 * @param len_bytes number of bytes to copy.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
dif_result_t dif_acc_imem_write(const dif_acc_t *acc, uint32_t offset_bytes,
                                const void *src, size_t len_bytes);

/**
 * Read from ACC's instruction memory (IMEM).
 *
 * Only 32b-aligned 32b word accesses are allowed.
 *
 * @param acc ACC instance
 * @param offset_bytes the byte offset in IMEM the first word is read from.
 * @param[out] dest the main memory location to copy the data to (preallocated).
 * @param len_bytes number of bytes to copy.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
dif_result_t dif_acc_imem_read(const dif_acc_t *acc, uint32_t offset_bytes,
                               void *dest, size_t len_bytes);

/**
 * Write to ACC's data memory (DMEM).
 *
 * Only 32b-aligned 32b word accesses are allowed.
 *
 * @param acc ACC instance.
 * @param offset_bytes the byte offset in DMEM the first word is written to.
 * @param src the main memory location to start reading from.
 * @param len_bytes number of bytes to copy.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
dif_result_t dif_acc_dmem_write(const dif_acc_t *acc, uint32_t offset_bytes,
                                const void *src, size_t len_bytes);

/**
 * Read from ACC's data memory (DMEM).
 *
 * Only 32b-aligned 32b word accesses are allowed.
 *
 * @param acc ACC instance
 * @param offset_bytes the byte offset in DMEM the first word is read from.
 * @param[out] dest the main memory location to copy the data to (preallocated).
 * @param len_bytes number of bytes to copy.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
dif_result_t dif_acc_dmem_read(const dif_acc_t *acc, uint32_t offset_bytes,
                               void *dest, size_t len_bytes);

/**
 * Sets the software errors are fatal bit in the control register.
 *
 * When set any software error becomes a fatal error. The bit can only be
 * changed when the ACC status is IDLE.
 *
 * @param acc ACC instance.
 * @param enable Enable or disable whether software errors are fatal.
 * @return The result of the operation, `kDifUnavailable` is returned when the
 * requested change cannot be made.
 */
OT_WARN_UNUSED_RESULT
dif_result_t dif_acc_set_ctrl_software_errs_fatal(const dif_acc_t *acc,
                                                  bool enable);

/**
 * Get the size of ACC's data memory in bytes.
 *
 * @param acc ACC instance.
 * @return data memory size in bytes.
 */
size_t dif_acc_get_dmem_size_bytes(const dif_acc_t *acc);

/**
 * Get the size of ACC's instruction memory in bytes.
 *
 * @param acc ACC instance.
 * @return instruction memory size in bytes.
 */
size_t dif_acc_get_imem_size_bytes(const dif_acc_t *acc);

#ifdef __cplusplus
}  // extern "C"
#endif  // __cplusplus

#endif  // OPENTITAN_SW_DEVICE_LIB_DIF_DIF_ACC_H_
