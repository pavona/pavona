/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#define STACK_SIZE 20000

.section .text.start

main:
  /* All-zero register. */
  bn.xor w31, w31, w31

  /* mod = q. */
  la      x5, modulus_bn
  bn.lid  x0, 0(x5)
  bn.rshi w0, w31, w0 >> 240
  bn.wsrw mod, w0

  /* ra <- masked_poly_getnoise_eta_1(seed, nonce, eta = 2). */
  la   x2, stack_end
  la   x10, seed
  la   x11, nonce
  jal  x1, masked_poly_getnoise_eta_init

  li   x10, 2
  la   x11, ra
  jal  x1, masked_poly_getnoise_eta_1

  /* reta_1_e2 <- unmask(ra). */
  la     x2, ra
  addi   x3, x2, 512
  la     x5, reta_1_e2
  li     x4, 1
  loopi 16, 4
    bn.lid       x0, 0(x2++)
    bn.lid       x4, 0(x3++)
    bn.addvm.16h w0, w0, w1
    bn.sid       x0, 0(x5++)
  endloop

  /* ra <- masked_poly_getnoise_eta_1(seed, nonce, eta = 3). */
  la  x2, stack_end
  la  x10, seed
  la  x11, nonce
  jal x1, masked_poly_getnoise_eta_init

  li  x10, 3
  la  x11, ra
  jal x1, masked_poly_getnoise_eta_1

  /* reta_1_e3 <- unmask(ra). */
  la     x2, ra
  addi   x3, x2, 512
  la     x5, reta_1_e3
  li     x4, 1
  loopi 16, 4
    bn.lid       x0, 0(x2++)
    bn.lid       x4, 0(x3++)
    bn.addvm.16h w0, w0, w1
    bn.sid       x0, 0(x5++)
  endloop

  /* ra <- masked_poly_getnoise_eta_2(seed, nonce, eta = 2). */
  la  x2, stack_end
  la  x10, seed
  la  x11, nonce
  jal x1, masked_poly_getnoise_eta_init

  li  x10, 2
  la  x11, ra
  jal x1, masked_poly_getnoise_eta_2

  /* reta_2 <- unmask(ra). */
  la     x2, ra
  addi   x3, x2, 512
  la     x5, reta_2
  li     x4, 1
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

reta_1_e2:
  .zero 512

reta_1_e3:
  .zero 512

reta_2:
  .zero 512
