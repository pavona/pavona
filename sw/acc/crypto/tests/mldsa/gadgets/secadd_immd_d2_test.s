/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#define STACK_SIZE 1024

.section .text.start

main:
  /* All-zero register. */
  bn.xor w31, w31, w31

  /* Load stack pointer. */
  la  x2, stack_end

  /* Config 0: k = 24, c = 0x800000 (= 1 << 23). */
  bn.xor w17, w17, w17
  bn.addi w17, w17, 1
  bn.shv.8s w17, w17 << 23
  la  x10, xb0
  li  x12, 24
  li  x13, 768
  la  x15, zb0
  jal x1, secadd_immd_d2

  /* Config 1: k = 8, c = 212. */
  bn.xor w17, w17, w17
  bn.addi w17, w17, 212
  la  x10, xb1
  li  x12, 8
  li  x13, 256
  la  x15, zb1
  jal x1, secadd_immd_d2

  /* Config 2: k = 5, c = 27. */
  bn.xor w17, w17, w17
  bn.addi w17, w17, 27
  la  x10, xb2
  li  x12, 5
  li  x13, 160
  la  x15, zb2
  jal x1, secadd_immd_d2

  /* Config 3: k = 5, c = 22. */
  bn.xor w17, w17, w17
  bn.addi w17, w17, 22
  la  x10, xb3
  li  x12, 5
  li  x13, 160
  la  x15, zb3
  jal x1, secadd_immd_d2

  /* Recombine each output: z[i] = zb[i] ^ zb[i + k]. */
  li     x4, 1

  la     x2, zb0
  la     x3, z0
  li     x6, 24
  loop x6, 5
    addi   x7, x2, 768
    bn.lid x0, 0(x2++)
    bn.lid x4, 0(x7)
    bn.xor w0, w0, w1
    bn.sid x0, 0(x3++)
  endloop

  la     x2, zb1
  la     x3, z1
  li     x6, 8
  loop x6, 5
    addi   x7, x2, 256
    bn.lid x0, 0(x2++)
    bn.lid x4, 0(x7)
    bn.xor w0, w0, w1
    bn.sid x0, 0(x3++)
  endloop

  la     x2, zb2
  la     x3, z2
  li     x6, 5
  loop x6, 5
    addi   x7, x2, 160
    bn.lid x0, 0(x2++)
    bn.lid x4, 0(x7)
    bn.xor w0, w0, w1
    bn.sid x0, 0(x3++)
  endloop

  la     x2, zb3
  la     x3, z3
  li     x6, 5
  loop x6, 5
    addi   x7, x2, 160
    bn.lid x0, 0(x2++)
    bn.lid x4, 0(x7)
    bn.xor w0, w0, w1
    bn.sid x0, 0(x3++)
  endloop

  ecall

.data
.balign 32
stack:
  .zero STACK_SIZE
stack_end:
z0:
  .zero 768
z1:
  .zero 256
z2:
  .zero 160
z3:
  .zero 160
