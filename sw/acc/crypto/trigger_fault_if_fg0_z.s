/* Copyright lowRISC contributors (OpenTitan project). */
/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * Trigger a fault if the FG0.Z flag is 1.
 *
 * If the flag is 1, then this routine will trigger an `ILLEGAL_INSN` error and
 * abort the ACC program. If the flag is 0, the routine will essentially do
 * nothing.
 *
 * NOTE: Be careful when calling this routine that the FG0.Z flag is not
 * sensitive; since aborting the program will be quicker than completing it,
 * the flag's value is likely clearly visible to an attacker through timing.
 *
 * @param[in]  FG0.Z: boolean indicating fault condition
 *
 * clobbered registers: x2
 * clobbered flag groups: none
 */
.globl trigger_fault_if_fg0_z
trigger_fault_if_fg0_z:
  /* Read the FG0.Z flag (position 3).
       x2 <= FG0.Z << 3 */
  csrrw     x2, FG0, x0
  andi      x2, x2, 8

  /* Causes an ILLEGAL_INSN error if x2 != 0; otherwise just does a no-op move
     from w0 to w0. */
  slli      x2, x2, 5
  bn.movr   x2, x2
  ret
