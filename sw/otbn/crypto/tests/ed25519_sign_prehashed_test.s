/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/* Copyright lowRISC contributors. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.section .text.start

/**
 * Standalone test for pre-hashed Ed25519.
 *
 * Test data from IETF RFC 8032, section 7.3:
 * https://datatracker.ietf.org/doc/html/rfc8032#section-7.3
 *
 * -----TEST abc
 *
 * ALGORITHM:
 * Ed25519ph
 *
 * SECRET KEY:
 * 833fe62409237b9d62ec77587520911e
 * 9a759cec1d19755b7da901b96dca3d42
 *
 * PUBLIC KEY:
 * ec172b93ad5e563bf4932c70e1245034
 * c35467ef2efd4d64ebf819683467e2bf
 *
 * MESSAGE (length 3 bytes):
 * 616263
 *
 * SIGNATURE:
 * 98a70222f0b8121aa9d30f813d683f80
 * 9e462b469c7ff87639499bb94e6dae41
 * 31f85042463c2a355a2003d062adf5aa
 * a10b8c61e636062aaad11c2a26083406
 * -----
 */

main:
  /* Compute signature.
       dmem[ed25519_sig_R] <= R
       dmem[ed25519_sig_S] <= S */
  jal     x1, ed25519_sign_prehashed

  ecall

.data

.balign 4
.globl ed25519_ctx_len
ed25519_ctx_len:
.word 0x00000000

.balign 32
.globl ed25519_d
ed25519_d:
.word 0x24e63f83
.word 0x9d7b2309
.word 0x5877ec62
.word 0x1e912075
.word 0xec9c759a
.word 0x5b75191d
.word 0xb901a97d
.word 0x423dca6d

.balign 32
.globl ed25519_message
ed25519_message:
.word 0xa135afdd
.word 0xba7a6193
.word 0x497341cc
.word 0x314120ae
.word 0x4efae612
.word 0xa27ea989
.word 0xe6ee9e0a
.word 0x9ad3554b
.word 0x2a999221
.word 0xa8c14f27
.word 0x233cba36
.word 0xbdebfea3
.word 0x23444d45
.word 0x0ee83c64
.word 0x4fc99a2a
.word 0x9fa44ca5

.balign 32
.globl ed25519_sig_R
ed25519_sig_R:
.zero 32

.balign 32
.globl ed25519_sig_S
ed25519_sig_S:
.zero 32
