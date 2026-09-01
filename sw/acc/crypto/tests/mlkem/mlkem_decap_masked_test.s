/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/*
 * Masked ML-KEM decap test wrapper. Links the shared mlkem_dmem layout and
 * runs the hardened decap kernel; ct/dk are preloaded by the testcase. The
 * shared secret comes out as two boolean shares, so this XORs them back into
 * ss for the testcase to check.
 */

.section .text.start

#ifndef KYBER_K
  #define KYBER_K 3
#endif

.globl main
main:
  /* All-zero register. */
  bn.xor w31, w31, w31

  /* w16 = mod = mqinv | q. */
  li      x5, 16
  la      x6, const_q
  bn.lid  x5++, 0(x6)
  bn.rshi w16, w31, w16 >> 240
  la      x6, const_mqinv
  bn.lid  x5, 0(x6)
  bn.or   w16, w16, w17 << 32
  bn.wsrw mod, w16

  /* ss <- crypto_kem_dec(ct, dk). */
  la   x2, stack_end
  la   x10, ct
  la   x11, dk
  la   x12, ss
  li   x13, KYBER_K
  jal  x1, crypto_kem_dec

  /* ss <- unmask(ss): ss_0 ^= ss_1. */
  la     x2, ss
  li     x4, 1
  bn.lid x0, 0(x2)
  bn.lid x4, 32(x2)
  bn.xor w0, w0, w1
  bn.sid x0, 0(x2)

  ecall
