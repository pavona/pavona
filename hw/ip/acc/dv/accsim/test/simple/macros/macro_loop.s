/* Copyright zeroRISC Inc & MPI-SP. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/*
  loopi's iteration count is itself a custom-encoded, split-across-two-bit-
  ranges immediate. Used as a macro parameter, it needs a body-start label
  (via Transformer._open_loop) so the matching endloop's bodysize check
  still works once invoked.
*/

.macro triple n
    loopi \n, 1
      addi x2, x2, 1
    endloop
.endm

  addi x2, x0, 0
  triple 3
  triple 5

  ecall
