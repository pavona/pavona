/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#define NSHARES 2

.section .text.start

main:
  la  x2, stack_end
  bn.xor w31, w31, w31

  /* MOD <= R | Q for bn.subvm.8s / bn.addvm.8s inside the gadget. */
  li      x5, 2
  la      x6, modulus
  bn.lid  x5, 0(x6)
  li      x5, 3
  la      x6, montg_R
  bn.lid  x5, 0(x6)
  bn.rshi w2, w3, w2 >> 224
  bn.wsrw 0x0, w2
  bn.wsrr w16, 0x0

  /* ===== ML-DSA-44 (L2, a2 = 2): arithmetic w0 left in place. ===== */
  la  x10, w1_out_l2
  la  x11, w_in_l2
  li  x12, 2
  la  x13, scratch
  li  x14, 1024
  la  x15, seccompress_b
  la  x16, t_packed
  jal x1, secdecompose

  /* w0_unmasked[i] = w_in_l2_s0[i] + w_in_l2_s1[i] mod q. */
  la   x10, w_in_l2
  addi x11, x10, 1024
  la   x12, w0_unmasked
  li   x4, 1
  li   x5, 2
  loopi 32, 4
    bn.lid x4, 0(x10++)
    bn.lid x5, 0(x11++)
    bn.addvm.8s w1, w1, w2
    bn.sid x4, 0(x12++)
  endloop

  /* ===== ML-DSA-65/87 (L35, a2 = 3): Boolean shares of U = gamma2 - w0. ===== */
  la  x10, w1_out_l35
  la  x11, w_in_l35
  li  x12, 3
  la  x13, scratch
  li  x14, 1024
  la  x15, w0_packed_share0
  la  x16, w0_packed_share1
  la  x17, seca2b_scratch
  jal x1, secdecompose

  /* Zero-pad 19-stripe packed shares to 24-stripe Boolean for b2a. */
  li   x7, 0
  li   x28, 31
  la   x5, b2a_in
  la   x6, w0_packed_share0
  loopi 19, 2
    bn.lid x7, 0(x6++)
    bn.sid x7, 0(x5++)
  endloop
  loopi 5, 1
    bn.sid x28, 0(x5++)
  endloop
  bn.xor w0, w0, w0
  la   x6, w0_packed_share1
  loopi 19, 2
    bn.lid x7, 0(x6++)
    bn.sid x7, 0(x5++)
  endloop
  loopi 5, 1
    bn.sid x28, 0(x5++)
  endloop

  /* b2a -> bitsliced arithmetic shares of U; unbitslice each share. */
  la  x10, b2a_out
  la  x11, b2a_in
  la  x13, seca2b_scratch
  jal x1, secb2amodq

  la   x10, u_share0
  la   x11, b2a_out
  jal  x1, unbitslice

  la   x10, u_share1
  la   x11, b2a_out
  addi x11, x11, 768
  jal  x1, unbitslice

  /* u_unmasked[i] = u_share0[i] + u_share1[i] mod q. */
  la   x10, u_share0
  la   x11, u_share1
  la   x12, u_unmasked
  li   x4, 1
  li   x5, 2
  loopi 32, 4
    bn.lid x4, 0(x10++)
    bn.lid x5, 0(x11++)
    bn.addvm.8s w1, w1, w2
    bn.sid x4, 0(x12++)
  endloop

  ecall

.data
.balign 32
stack:
  .zero 2048
stack_end:

.balign 32
.globl w0_unmasked
w0_unmasked:
  .zero 1024

.balign 32
.globl u_unmasked
u_unmasked:
  .zero 1024

/* a3 scratch: seccompress (L2, 4096 B) / secdecompose (L35, 3296 B). */
.balign 32
scratch:
  .zero 4096

/* ML-DSA-44 (L2) scratch. */
.balign 32
t_packed:
  .zero 2048
.balign 32
seccompress_b:
  .zero 2048

/* ML-DSA-65/87 (L35) scratch. */
.balign 32
w0_packed_share0:
  .zero 608
.balign 32
w0_packed_share1:
  .zero 608
.balign 32
b2a_in:
  .zero NSHARES * 768
.balign 32
b2a_out:
  .zero NSHARES * 768
.balign 32
u_share0:
  .zero 1024
.balign 32
u_share1:
  .zero 1024
.balign 32
seca2b_scratch:
  .zero 1536
