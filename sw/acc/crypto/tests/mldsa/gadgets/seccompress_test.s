/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#ifndef NSHARES
  #define NSHARES 2
#endif

/* ML-DSA-44 SecCompress + cap output: w1 in ceil(log2(44)) = 6 bit-stripes. */
#define C_BITS 6

.section .text.start

/* Compute  zb = seccompress(xa, NSHARES); then XOR-collapse the d
 * Boolean shares per stripe into a single 256-bit word per stripe:
 *   r[b] = XOR over s in [0, NSHARES) of zb[b][s].
 * Expected: r[b] = bit-b of V' = (round(x*44/q) + j*44) mod 2^c across
 *           all 256 lanes, where j is the per-lane wrap count produced
 *           by the testgen's share split. */
main:
  la     x2, stack_end
  bn.xor w31, w31, w31
  la     x10, zb
  la     x11, xa
  la     x12, seccompress_scratch
  la     x13, seccompress_b
  jal    x1, seccompress

  /* XOR-collapse share-major layout: V' = bottom 6 stripes of seccompress
   * output Z's top-8 region.  V' share 0 at zb + 768; share 1 at zb + 1792. */
  la   x2, zb
  addi x2, x2, 768
  la   x3, r
  li   x4, 1
  li   x5, 0
  loopi C_BITS, 5
    bn.lid x5, 0(x2)
    bn.lid x4, 1024(x2)
    bn.xor w0, w0, w1
    bn.sid x5, 0(x3++)
    addi   x2, x2, 32
  endloop

  ecall

.data
.balign 32
stack:
  .zero 2048
stack_end:
r:
  .zero C_BITS * 32

.balign 32
seccompress_scratch:
  .zero 4096

.balign 32
seccompress_b:
  .zero 2048
