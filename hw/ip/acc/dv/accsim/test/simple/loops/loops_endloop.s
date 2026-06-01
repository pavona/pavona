/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

  /* Same program as loops.s, but with endloop markers */

  addi    x2, x0, 0
  addi    x3, x0, 3

  loopi  4, 4
   addi   x2, x2, 10
   loop   x3, 1
    addi   x2, x2, 1
   endloop
   nop
  endloop

  ecall
