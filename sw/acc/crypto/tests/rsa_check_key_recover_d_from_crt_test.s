/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * Ensure that the RSA check key mode can recover d from CRT components.
 */

.section .text.start

main:
  /* Init all-zero register. */
  bn.xor    w31, w31, w31

  /* Load the number of limbs for this test. */
  li        x30, 4
  addi      x31, x30, -1

  /* Load required constants. */
  li        x20, 20
  li        x21, 21

  /* Copy the first cofactor into `rsa_p` */
  la        x2, p
  la        x3, rsa_p
  loop      x30, 2
    bn.lid   x20, 0(x2++)
    bn.sid   x20, 0(x3++)

  /* Copy the second cofactor into `rsa_q` */
  la        x2, q
  la        x3, rsa_q
  loop      x30, 2
    bn.lid   x20, 0(x2++)
    bn.sid   x20, 0(x3++)

  /* Copy the first private exponent component into `rsa_d_p` */
  la        x2, d_p
  la        x3, rsa_d_p
  loop      x30, 2
    bn.lid   x20, 0(x2++)
    bn.sid   x20, 0(x3++)

  /* Copy second private exponent component into `rsa_d_q` */
  la        x2, d_q
  la        x3, rsa_d_q
  loop      x30, 2
    bn.lid   x20, 0(x2++)
    bn.sid   x20, 0(x3++)

  /* Copy public exponent component into `e` */
  la        x2, e
  la        x3, rsa_e
  loop      x30, 2
    bn.lid   x20, 0(x2++)
    bn.sid   x20, 0(x3++)

  /* Recover d. */
  jal      x1, recover_d_from_crt

  ecall

.data

.balign 32
p:
.word 0x69e8cdeb
.word 0x0aab5698
.word 0x2adbf5a2
.word 0xc6f3fed7
.word 0x9b0f148c
.word 0x68a4b636
.word 0xc3c8948c
.word 0x5ee5c048
.word 0xb20f9f30
.word 0xaced9c36
.word 0xe2a0f71f
.word 0xf57f3401
.word 0x8fb749f8
.word 0x24f4b1f2
.word 0x2811dd24
.word 0x0e45d624
.word 0x7e4fac27
.word 0x7049a420
.word 0x4ea4172b
.word 0x1d4f1d2d
.word 0x15c1dd03
.word 0x733ce8c1
.word 0xe5415c61
.word 0xa3680f9a
.word 0xa13ff562
.word 0xd12a0242
.word 0x3ef684a4
.word 0x5241db6e
.word 0x2e68b5f5
.word 0xaa3e5397
.word 0x45e9606a
.word 0xb8505888

.balign 32
q:
.word 0xc69864d3
.word 0x6eca1793
.word 0xd985ff65
.word 0xa888cce8
.word 0xcadcabc5
.word 0x47d31ff8
.word 0x2eae994a
.word 0x0ba8594d
.word 0x956889ed
.word 0x117f0b01
.word 0x30ace812
.word 0x89aa41b9
.word 0x716c8c93
.word 0xb3e54154
.word 0x70020ae3
.word 0x3f3926af
.word 0x91ae5a18
.word 0xa058daef
.word 0xd5a8a0ee
.word 0xff73e9fb
.word 0xda00591c
.word 0x69220aec
.word 0xe9ee684b
.word 0x12f4ea77
.word 0xea538fb5
.word 0x0505826e
.word 0xef416b24
.word 0x5c65d8d6
.word 0xce422bd4
.word 0x3f4f37ed
.word 0xdd6aff12
.word 0xf6c55808

.balign 32
d_p:
.word 0x450b9217
.word 0x4edd47a6
.word 0x65eaa581
.word 0xa489536c
.word 0x46c6416e
.word 0xcdcd3461
.word 0x07ba3fc0
.word 0x95d56f89
.word 0xcf3c23f1
.word 0x3a09db7b
.word 0x841780f5
.word 0x3ee50c5d
.word 0x6858dd49
.word 0xf56e4c70
.word 0x872d1012
.word 0xe23c883f
.word 0x24170efd
.word 0xeb61ae33
.word 0xd05cb6b7
.word 0x81db8c2f
.word 0x1cd58c9b
.word 0xa828fecf
.word 0x09db577e
.word 0xcdc21d77
.word 0x9ebfb60c
.word 0xbacad629
.word 0x98bc44a7
.word 0x8498e6dc
.word 0x399dc28f
.word 0x95d22e4d
.word 0x7b1d095d
.word 0xacc9ede5

.balign 32
d_q:
.word 0x1294bbf7
.word 0x8b2919b9
.word 0x19e6e6bb
.word 0x5bac57cf
.word 0x94878d05
.word 0xdd0297c9
.word 0xc2fa4a31
.word 0x250dbc5d
.word 0xa6e04ae3
.word 0xc4f6deb7
.word 0x5d21fd5f
.word 0x6e02cdea
.word 0xb967b151
.word 0x1324bb70
.word 0xe7c7e19a
.word 0x93faa85b
.word 0xcea179ee
.word 0xda7b268f
.word 0xb4953e88
.word 0x5da887cf
.word 0xf3475b09
.word 0xf0f59bd2
.word 0xd783b40b
.word 0x871df1f6
.word 0x7781156f
.word 0x2d8a9b67
.word 0xf1555281
.word 0xdf14b659
.word 0x85d12616
.word 0x28f80092
.word 0x50663f6f
.word 0xb2191d7f

.balign 32
e:
.word 0x00010001
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000
