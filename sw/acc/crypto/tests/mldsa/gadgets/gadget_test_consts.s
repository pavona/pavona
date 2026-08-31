/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/*
 * Base broadcast constants for gadget unit tests. In the single-binary runtime
 * build these live in run_mldsa.s and are filled at runtime; gadget tests link
 * individual routines from gadgets.s that reference them (e.g. secdecompose
 * reads gamma2_vec_const on the L2 path). Linked as a separate object (a dep) so
 * it is not concatenated into the test's own source. gamma2 = (q-1)/88 = 95232
 * (ML-DSA-44, the L2 SecDecompose parameter set).
 */

.data
.balign 32
.globl gamma2_vec_const
gamma2_vec_const:
  .word 95232, 95232, 95232, 95232
  .word 95232, 95232, 95232, 95232
