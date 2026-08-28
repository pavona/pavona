/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#define STACK_SIZE 20000

.section .text.start

main:
  /* All-zero register. */
  bn.xor w31, w31, w31

  /* mod = qinv | q. */
  add     x4, x0, x0
  la      x5, modulus_bn
  bn.lid  x4++, 0(x5)
  bn.rshi w0, w31, w0 >> 240
  la      x5, modulus_inv
  bn.lid  x4, 0(x5)
  bn.or   w0, w0, w1 << 32
  bn.wsrw mod, w0

  /* ra <- onebitdecompress(xb). */
  bn.wsrr w16, mod
  la      x2, stack_end
  la      x10, xb
  la      x12, ra
  jal     x1, onebitdecompress

  /* r <- unmask(ra). */
  la   x2, ra
  addi x3, x2, 512
  la   x5, r
  li   x4, 1
  loopi 16, 4
    bn.lid       x0, 0(x2++)
    bn.lid       x4, 0(x3++)
    bn.addvm.16h w0, w0, w1
    bn.sid       x0, 0(x5++)
  endloop

  ecall

.data
.balign 32
stack:
  .zero STACK_SIZE
stack_end:

r:
  .zero 512
