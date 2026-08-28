/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#define NSHARES 2
#define N_WDR 16
#define NB_POLY 512
#define STACK_SIZE 20000

.section .text.start

main:
  /* All-zero register. */
  bn.xor w31, w31, w31

  /* MOD <= dmem[modulus] = KYBER_Q */
  la      x6, modulus_bn
  bn.lid  x0, 0(x6)
  bn.rshi w0, w31, w0 >> 240
  bn.wsrw 0x0, w0

  /* reta_1_e2 <= recombine(masked_poly_getnoise_eta_1(seed, nonce, eta = 2)) */
  la  x2, stack_end
  la  x10, seed
  la  x11, nonce
  jal x1, masked_poly_getnoise_eta_init
  li  x10, 2
  la  x11, ra
  jal x1, masked_poly_getnoise_eta_1
  la   x2, ra
  la   x3, reta_1_e2
  li   x4, 1
  li   x5, NSHARES
  addi x5, x5, -1
  loopi N_WDR, 7
    addi   x6, x2, NB_POLY
    bn.lid x0, 0(x2++)
    loop x5, 3
      bn.lid       x4, 0(x6)
      bn.addvm.16h w0, w0, w1
      addi         x6, x6, NB_POLY
    endloop
    bn.sid x0, 0(x3++)
  endloop

  /* reta_1_e3 <= recombine(masked_poly_getnoise_eta_1(seed, nonce, eta = 3)) */
  la  x2, stack_end
  la  x10, seed
  la  x11, nonce
  jal x1, masked_poly_getnoise_eta_init
  li  x10, 3
  la  x11, ra
  jal x1, masked_poly_getnoise_eta_1
  la   x2, ra
  la   x3, reta_1_e3
  li   x4, 1
  li   x5, NSHARES
  addi x5, x5, -1
  loopi N_WDR, 7
    addi   x6, x2, NB_POLY
    bn.lid x0, 0(x2++)
    loop x5, 3
      bn.lid       x4, 0(x6)
      bn.addvm.16h w0, w0, w1
      addi         x6, x6, NB_POLY
    endloop
    bn.sid x0, 0(x3++)
  endloop

  /* reta_2 <= recombine(masked_poly_getnoise_eta_2(seed, nonce, eta = 2)) */
  la  x2, stack_end
  la  x10, seed
  la  x11, nonce
  jal x1, masked_poly_getnoise_eta_init
  li  x10, 2
  la  x11, ra
  jal x1, masked_poly_getnoise_eta_2
  la   x2, ra
  la   x3, reta_2
  li   x4, 1
  li   x5, NSHARES
  addi x5, x5, -1
  loopi N_WDR, 7
    addi   x6, x2, NB_POLY
    bn.lid x0, 0(x2++)
    loop x5, 3
      bn.lid       x4, 0(x6)
      bn.addvm.16h w0, w0, w1
      addi         x6, x6, NB_POLY
    endloop
    bn.sid x0, 0(x3++)
  endloop
  ecall

.data
.balign 32
stack:
  .zero STACK_SIZE
stack_end:

reta_1_e2:
  .zero 32 * N_WDR

reta_1_e3:
  .zero 32 * N_WDR

reta_2:
  .zero 32 * N_WDR
