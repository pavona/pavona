/* Copyright zeroRISC Inc & MPI-SP. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/*
  A macro whose body is plain RV32I (as in sw/acc/crypto/mldsa/poly.s's
  push/pop) still passes straight through unchanged.
*/

.macro push reg
    addi sp, sp, -4
    sw \reg, 0(sp)
.endm

.macro pop reg
    lw \reg, 0(sp)
    addi sp, sp, 4
.endm

  addi sp, x0, 0x100
  addi t0, x0, 0x11
  addi a1, x0, 0x22

  push t0
  push a1

  addi t0, x0, 0
  addi a1, x0, 0

  pop a1
  pop t0

  ecall
