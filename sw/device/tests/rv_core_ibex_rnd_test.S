// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/* These assembly functions are used in the rv_core_ibex_rnd_test chip-level
 * test. Writing these functions in assembly guarantees that the memory reads
 * are a fixed number of instructions apart, independent of how the compiler
 * optimizes code. This is important because the RND status is low for only a
 * small number of cycles (10 cycles in the Verilator simulator). If we do not
 * write these in assembly, changes to the test, implementation or compiler
 * could affect whether the tests pass or not, which is de-risked to a certain
 * extent by using the assembly versions.
 */

#include "hw/top/rv_core_ibex_regs.h"

/**
 * Read RND Data and immediately read RND status afterwards.
 *
 * @return the value of the RND status.
 */
  .globl rv_core_ibex_rnd_read_and_immediately_check_status
  .type rv_core_ibex_rnd_read_and_immediately_check_status, @function
rv_core_ibex_rnd_read_and_immediately_check_status:
  mv t0, a0 // Load ibex base address
  lw t1, RV_CORE_IBEX_RND_DATA_REG_OFFSET(t0) // Read RND data
  lw a0, RV_CORE_IBEX_RND_STATUS_REG_OFFSET(t0) // Get RND status
  ret // Return status

/**
 * Read RND data to invalidate status, read status, then read RND data again.
 * A read taken while the status is invalid must return zero rather than block,
 * which is what this checks.
 *
 * The status is not read a second time. EDN may answer the pending request at
 * any point, so the status can go valid again within an instruction or two of
 * the invalidating read, and requiring it to still read invalid would be
 * asking for something the design does not promise.
 *
 * @return -1 if the status was not invalid before the second read, or if that
 * read did not return zero. Otherwise return zero.
 */
  .globl rv_core_ibex_check_rnd_read_possible_while_status_invalid
  .type rv_core_ibex_check_rnd_read_possible_while_status_invalid, @function
rv_core_ibex_check_rnd_read_possible_while_status_invalid:
  mv t0, a0 // Load ibex base address
  lw t1, RV_CORE_IBEX_RND_DATA_REG_OFFSET(t0) // Read RND to invalidate status
  lw t2, RV_CORE_IBEX_RND_STATUS_REG_OFFSET(t0) // Get RND status
  lw t3, RV_CORE_IBEX_RND_DATA_REG_OFFSET(t0) // Read RND data
  andi t2, t2, 1 // Keep the valid bit of the status taken before the read
  or t2, t2, t3 // Check whether that read returned 0
  bnez t2, error_return // Check whether to return -1
  mv a0, x0 // Return 0
  ret
error_return:
  addi a0, x0, -1 // Put -1 in a0
  ret // Return -1
