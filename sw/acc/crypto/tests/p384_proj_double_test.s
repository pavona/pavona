/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.section .text.start

main:
  /* Initialize all-zero register. */
  bn.xor   w31, w31, w31

  /* Load point. */
  li       x2, 25
  la       x3, p1_x
  bn.lid   x2++,   0(x3)
  bn.lid   x2++,  32(x3)
  bn.lid   x2++,  64(x3)
  bn.lid   x2++,  96(x3)
  bn.lid   x2++, 128(x3)
  bn.lid   x2++, 160(x3)

  /* [w13, w12] = p */
  li       x2, 12
  la       x3, p384_p
  bn.lid   x2++, 0(x3)
  bn.lid   x2++, 32(x3)

  jal      x1, proj_double_p384

  ecall

.section .data

.balign 32
p1_x:
.word 0x1efb65e9
.word 0x644eefe4
.word 0x1b9db1d5
.word 0xb5dbd0ba
.word 0x760dc196
.word 0x15e0be5c
.word 0x6d678c86
.word 0x65ca4081
.word 0xde946124
.word 0x3c315786
.word 0xb0a1d256
.word 0x0c1eea5a
.zero 16

.balign 32
p1_y:
.word 0xa23ae435
.word 0x14ae78e9
.word 0xa74a3d75
.word 0x300654dd
.word 0xeb352d44
.word 0x7035e43c
.word 0xe1e8fb14
.word 0xdd446c11
.word 0xee0e53b9
.word 0x69b4d724
.word 0xa23baf66
.word 0xdb1cc4d8
.zero 16

.balign 32
p1_z:
.word 0x9b2f1d4b
.word 0x9b53163d
.word 0xa26dbeaa
.word 0x4e834230
.word 0x498af72a
.word 0x5cf57ec1
.word 0xe4e29dd9
.word 0xf242436d
.word 0xb18b0f28
.word 0x031262c1
.word 0xee07b92f
.word 0xe514c262
.zero 16
