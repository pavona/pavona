/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.section .text.start

/**
 * Standalone RSA 1024 decrypt using CRT, with cofactors q > p
 *
 * Uses ACC modexp bignum lib to decrypt the message from the .data segment
 * in this file with the private key contained in .data segment of this file.
 *
 * Copies the decrypted message to wide registers for comparison (starting at
 * w0). See comment at the end of the file for expected values.
 *
 * The ciphertext is chosen such that C_q > C_p + p, where C_p and C_q are the
 * modular exponentiation results mod p and q.
 */
 run_rsa_1024_dec_crt_q_gt_p:
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

.balign 32
modulus_q:
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

/* encrypted message */
.balign 32
ciphertext:
.word 0x9eba8775
.word 0xab392034
.word 0x87ecbe86
.word 0x32864238
.word 0x5c03151c
.word 0x86b46f01
.word 0x00e6a305
.word 0xadb55556

.word 0x63a029a5
.word 0x9450085b
.word 0x6d05c818
.word 0xf86668c1
.word 0x67be9998
.word 0x5604c3b6
.word 0xdc7a9283
.word 0x9f22ce0a

.word 0x959d133d
.word 0xf977edf4
.word 0xbbdc55a2
.word 0xb312ad6f
.word 0xe5dd6001
.word 0xf7adc0ae
.word 0xbfaf9e2f
.word 0x1157c8b3

.word 0x7e21b8aa
.word 0xfcd58c0f
.word 0xbeeaac97
.word 0x3f64c50c
.word 0xa3ee54d4
.word 0xf78d9952
.word 0xa6142e5b
.word 0x4a77814e


/* private exponent */
.balign 32
exp_p:
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
exp_q:
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
crt_coeff:
.word 0x6f12799e
.word 0xf56bec92
.word 0x123d4cfb
.word 0xe40afa54
.word 0xb617c93f
.word 0x0e070f4c
.word 0x274f523b
.word 0xd18bae50

.word 0x38011b7c
.word 0xe494e846
.word 0x2e89e66f
.word 0x7eec5e47
.word 0x096d54a9
.word 0x789e3bf3
.word 0x205c8d4a
.word 0xb6ec0909

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
