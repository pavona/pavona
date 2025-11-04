/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.section .text.start

/**
 * Standalone RSA 1024 decrypt using CRT
 *
 * Uses OTBN modexp bignum lib to decrypt the message from the .data segment
 * in this file with the private key contained in .data segment of this file.
 *
 * Copies the decrypted message to wide registers for comparison (starting at
 * w0). See comment at the end of the file for expected values.
 */
 run_rsa_1024_dec_crt:
  /* Init all-zero register. */
  bn.xor   w31, w31, w31

  /* Load number of limbs. */
  li       x30, 4

  /* Load pointers to cofactor and Montgomery constant buffers. */
  la       x17, m0inv
  la       x18, RR
  la       x27, modulus_p
  la       x28, modulus_q

  /* Run exponentiation.
       dmem[plaintext] = dmem[ciphertext]^<exp> mod <modulus>
       where
         <exp> mod p = exp_p
         <exp> mod q = exp_q
         <modulus> = modulus_p * modulus_q. */
  la       x2, plaintext
  la       x3, work_exp
  la       x4, work_reduce
  la       x23, ciphertext
  la       x25, exp_p
  la       x26, exp_q
  la       x29, crt_coeff
  jal      x1, modexp_crt

  /* copy all limbs of result to wide reg file */
  la       x21, plaintext
  li       x8, 0
  loop     x30, 2
    bn.lid   x8, 0(x21++)
    addi     x8, x8, 1

  ecall


.data

/* Modulus */
.balign 32
modulus_p:
.word 0x1d2b96a5
.word 0x8fae3d85
.word 0x87e768bf
.word 0xc1ad304b
.word 0x055631e7
.word 0xa87bdc88
.word 0xa2d265dd
.word 0x30883e3e

.word 0x40d967a1
.word 0x32ac3633
.word 0x493a3c62
.word 0xb3f27ac5
.word 0x2aa7eb68
.word 0x27e1f91e
.word 0xf119d455
.word 0xd14d3c63

.balign 32
modulus_q:
.word 0x371d3ef3
.word 0xfd046007
.word 0x365e6ad8
.word 0xcd286b52
.word 0x045fd422
.word 0xc71de767
.word 0x2610045e
.word 0xe9574229

.word 0x8db9802e
.word 0xa7687572
.word 0x7b84221b
.word 0x9807203e
.word 0x459c4d0e
.word 0x809e9704
.word 0x0d16d271
.word 0xb7ad4873

/* encrypted message */
.balign 32
ciphertext:
.word 0xe0e14a9b
.word 0x7ae96741
.word 0x4a430036
.word 0xcda13a47
.word 0x79524410
.word 0x3810cd51
.word 0x3b47425f
.word 0x686f3abe

.word 0x91dff899
.word 0xbfa8b284
.word 0x0539e396
.word 0xa66cf53c
.word 0xbcdc315a
.word 0x0d595811
.word 0x0a522e08
.word 0x5b9dce33

.word 0x6fde2d48
.word 0x587a618e
.word 0x6b4c0c56
.word 0x4affcc62
.word 0x6a88ead2
.word 0x991f39d0
.word 0x39f88b9a
.word 0x3c0d6626

.word 0xa3fe6181
.word 0x82f3f1f6
.word 0x43f4ed0b
.word 0x938bfd7b
.word 0x60de8b63
.word 0x8ade6cc0
.word 0x91f560d7
.word 0x35f506d1


/* private exponent */
.balign 32
exp_p:
.word 0x99392d81
.word 0xe65644a5
.word 0x5ffd2412
.word 0x4cb30aa8
.word 0xfb7d2820
.word 0xd09d1a6f
.word 0x83f59aa5
.word 0xa08f1492

.word 0xd3c5626d
.word 0xa74e86e9
.word 0x9da1b13a
.word 0xc5ac5065
.word 0x0fb5c3ff
.word 0xae0bdaee
.word 0x061b83b2
.word 0x72c44739

.balign 32
exp_q:
.word 0x478211f5
.word 0xff0b3e3f
.word 0xea9450e1
.word 0x04242e27
.word 0x2c52ee41
.word 0x4c074b8e
.word 0x32afd20a
.word 0xc05b80e4

.word 0x97d547f5
.word 0x9227c025
.word 0x5d6336c8
.word 0x17d18878
.word 0xca7edced
.word 0xfd6bddff
.word 0xedeb3ff7
.word 0xac66df9b

.balign 32
crt_coeff:
.word 0x4e67618e
.word 0xccca7663
.word 0x6a6115e8
.word 0x8e1249d3
.word 0x100ca320
.word 0x3240503d
.word 0x18c9d56d
.word 0xfb707055

.word 0x96134bc6
.word 0xcd1fc12d
.word 0x41ccbffb
.word 0x8ce49064
.word 0xce42176e
.word 0x8b1f5c97
.word 0x63ff65d2
.word 0x00dc352f

/* output buffer */
.balign 32
plaintext:
.zero 128

/* buffer for Montgomery constant RR */
.balign 32
RR:
.zero 128

/* buffer for Montgomery constant m0inv */
.balign 32
m0inv:
.zero 32

.balign 32
work_exp:
.zero 128

.balign 32
work_reduce:
.zero 128
