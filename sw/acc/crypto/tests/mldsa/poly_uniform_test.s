/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * Test for the poly_uniform subroutine of ML-DSA.
 */

.section .text.start

main:
  /* Prepare all-zero register. */
  bn.xor w31, w31, w31

  /* Set up the SHAKE128 configuration for poly_uniform. */
  addi  x2, zero, 34
  slli  x2, x2, 5
  addi  x2, x2, 0x2 /* SHAKE128 */
  csrrw x0, kmac_cfg, x2

  /* Send the input (34 zero bytes) */
  bn.wsrw   kmac_msg, w31
  bn.wsrw   kmac_msg, w31

  /* Call poly_uniform. */
  la  x11, result
  jal x1, poly_uniform

  ecall

.data

rho:
.zero 32

result:
.zero 1024
