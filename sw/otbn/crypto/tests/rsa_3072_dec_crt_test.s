/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.section .text.start

/**
 * Standalone RSA-3072 modexp with secret exponent (decryption/signing).
 */
main:
  /* Init all-zero register. */
  bn.xor  w31, w31, w31

  /* Load number of limbs. */
  li    x30, 12

  /* Load pointers to cofactor and Montgomery constant buffers. */
  la    x17, m0inv
  la    x18, RR
  la    x27, modulus_p
  la    x28, modulus_q

  /* Run exponentiation.
       dmem[plaintext] = dmem[ciphertext]^<exp> mod <modulus>
       where
         <exp> mod (p - 1) = exp_p
         <exp> mod (q - 1) = exp_q
         <modulus> = modulus_p * modulus_q. */
  la       x2, result
  la       x3, work_exp
  la       x4, work_reduce
  la       x23, base
  la       x25, exp_p
  la       x26, exp_q
  la       x29, crt_coeff
  jal      x1, modexp_crt

  /* copy all limbs of result to wide reg file */
  la       x21, result
  li       x8, 0
  loop     x30, 2
    bn.lid   x8, 0(x21++)
    addi     x8, x8, 1  /* Load pointers to modulus and Montgomery constant buffers. */

  ecall


.data

/* Modulus n =
0xb2e73fd1e1dce003def2f2795a1400f2514256a70fe83d64ae8464f114839c94d975c89f97b3598b48de7a560b867b4967ae92d3552f0b204c000b0841f5fac3ef0ba000acfb517a995cf708e46c670a885626d7865ebc5bccc509bc562a4ffc956eb3b859e43bc83debe4888e3e6a55de852c027a874b9c803598a78f4196800db785d91730e8708b8cef986c6d326c9a003201737cb3f5e42cd601c47d74898105671d446b9a5c8a835286f419682fc4b69e79a8d2f9f6aabca5b0c311dabe6fb19d3e03045a729b3107f21370935c6de2316876afae55aeb4da07b8a04aafc1f7717f8d571f47c1a0f395e4ce78ed581db853bda1cb6f224fc4b2c6244611d416b2e729c54ef638d7bd94483b11b56b7b613c06b2564c08de82ef33dff23892e183fd6e96713bfaf76b792c4e8071f3dd5ad695e3748179bebb97140efaabce02687b401b93a513b80b5ec334d38c0b331f90d1454c9b8f3b87017b5174f1d2b75c27fff6e89a3ae099fb0455b5cc9d3bd4840baf510e4d80dbbac4049efb
 */
.balign 32
modulus_p:
  .word 0xf0c591bd
  .word 0x25097f22
  .word 0x169bf55b
  .word 0x71e832bf
  .word 0x3d8b0eeb
  .word 0x9d6aa2c8
  .word 0xf6bb7b74
  .word 0x6c38a957
  .word 0x6da299c0
  .word 0x45a2c443
  .word 0xf72e2e5
  .word 0x19ad1c0e
  .word 0xdcbbd46f
  .word 0xeb404d8e
  .word 0xeba53228
  .word 0xea66a3f4
  .word 0x39ff14a3
  .word 0x4bfd6666
  .word 0x3537922b
  .word 0x9bbb3bfb
  .word 0xf27f5c8
  .word 0xde4e3567
  .word 0x395a65c4
  .word 0x286d72ef
  .word 0x46eae2f7
  .word 0x5922232f
  .word 0xa42b1485
  .word 0x77eca0bb
  .word 0x4527742c
  .word 0x8a178b
  .word 0x5b5b6dd7
  .word 0xee39f76f
  .word 0xe0dec886
  .word 0x3105658b
  .word 0xe981436
  .word 0x889e564c
  .word 0xc027fd21
  .word 0x3cbaacea
  .word 0x80f8ba98
  .word 0xde1925b9
  .word 0x50d748ac
  .word 0xffcab93
  .word 0xe346c78c
  .word 0xec7c4579
  .word 0xf578f1a4
  .word 0x4d90c00d
  .word 0x879063b8
  .word 0xfbb6d8ab

.balign 32
modulus_q:
  .word 0xb6b99317
  .word 0xa6ac426f
  .word 0x9123b88a
  .word 0x6790aeb4
  .word 0xbe6a062b
  .word 0x2e9b03c9
  .word 0x4cc54507
  .word 0x60607412
  .word 0xe658d84c
  .word 0x9ab2af24
  .word 0xb1dd80f8
  .word 0xd8ccfecd
  .word 0xc4a10f42
  .word 0xd62c5daf
  .word 0x9152615b
  .word 0x6fa58024
  .word 0xbb28ae61
  .word 0xbb47eb42
  .word 0x792dfdd4
  .word 0xe3dc41e
  .word 0x27845749
  .word 0x50afedf
  .word 0x6e8725c0
  .word 0xa2e60d06
  .word 0xbde31238
  .word 0xb153c6da
  .word 0xea55f56d
  .word 0x7e6601f1
  .word 0x543961d4
  .word 0x15118b07
  .word 0x5e7f9a88
  .word 0x2dd4be35
  .word 0xf8c7bb7f
  .word 0xe7cda4c
  .word 0x5df5fae
  .word 0x8a7e1e8e
  .word 0xa030a0
  .word 0x99c1272f
  .word 0x2fce73f1
  .word 0xa69355bd
  .word 0x622f6564
  .word 0x50774f13
  .word 0xdf99bd61
  .word 0x4769d6f4
  .word 0x408a4afa
  .word 0x3609c80d
  .word 0xd05da12f
  .word 0xb5f30a3c

/* Base for exponentiation (corresponds to ciphertext for decryption or
   message for signing).

   Raw hex value =
0x1273e84d4509b08a748a9bf81808f0a2387616159d3b04b32ab172285440f09f69f53e37a7cb6a6fc3fb0626a4dad7b64417570b4e112843bd3c82030fb4a01ba9ba2c194e98d51372b9a63153d7279c62452592d597c85dc493d167735918d89c4aa86d20073a0d6ce2a3bf7dc603d73efb38c5ff6fb191db117f8cf4cb0b46e995bfa0e4cee3a055fc44e496989f7248e95c6e3f4879d2c38118f51a0910d37030ddf0a39a0e6e0e3e4be9b0d12e8d25f337657e7f752fa63defebd91b2c107a00475fde78b38da4ca12c17160a8d68f6eecb60481e6ae3f3a0dc03ebb82f327dfe85f850d05215af5f7c07cd5932aaec3d17339e75b2ec803d231188942231edd8c43a6bd9b7be638da9911604a3308117ad41cf697273550765bac72a499cf21d4c4406668f569e4b002d75de22d3e5e7d5c7b33131389cffad951b362865106352780474b3c79378169c6998388e5d2782557c228f0fcf1e132e0fc2d14fe03cca340568cfb5c07a00b052304fa0923f1dfcf627a58e0ea093a97af836
 */
.balign 32
base:
  .word 0xa97af836
  .word 0x8e0ea093
  .word 0xfcf627a5
  .word 0xa0923f1d
  .word 0xb052304f
  .word 0xb5c07a00
  .word 0x340568cf
  .word 0x4fe03cca
  .word 0x2e0fc2d1
  .word 0x0fcf1e13
  .word 0x557c228f
  .word 0x8e5d2782
  .word 0x9c699838
  .word 0xc7937816
  .word 0x780474b3
  .word 0x65106352
  .word 0x951b3628
  .word 0x389cffad
  .word 0xc7b33131
  .word 0xd3e5e7d5
  .word 0x2d75de22
  .word 0x569e4b00
  .word 0x4406668f
  .word 0x9cf21d4c
  .word 0xbac72a49
  .word 0x73550765
  .word 0x41cf6972
  .word 0x308117ad
  .word 0x911604a3
  .word 0xbe638da9
  .word 0x3a6bd9b7
  .word 0x31edd8c4
  .word 0x11889422
  .word 0xec803d23
  .word 0x339e75b2
  .word 0xaaec3d17
  .word 0x07cd5932
  .word 0x15af5f7c
  .word 0xf850d052
  .word 0x327dfe85
  .word 0x03ebb82f
  .word 0xe3f3a0dc
  .word 0x60481e6a
  .word 0x68f6eecb
  .word 0x17160a8d
  .word 0xda4ca12c
  .word 0xfde78b38
  .word 0x07a00475
  .word 0xbd91b2c1
  .word 0xfa63defe
  .word 0x57e7f752
  .word 0xd25f3376
  .word 0x9b0d12e8
  .word 0xe0e3e4be
  .word 0x0a39a0e6
  .word 0x37030ddf
  .word 0x51a0910d
  .word 0x2c38118f
  .word 0xe3f4879d
  .word 0x248e95c6
  .word 0x496989f7
  .word 0x055fc44e
  .word 0x0e4cee3a
  .word 0x6e995bfa
  .word 0xcf4cb0b4
  .word 0x1db117f8
  .word 0x5ff6fb19
  .word 0x73efb38c
  .word 0xf7dc603d
  .word 0xd6ce2a3b
  .word 0xd20073a0
  .word 0x89c4aa86
  .word 0x7735918d
  .word 0xdc493d16
  .word 0x2d597c85
  .word 0xc6245259
  .word 0x153d7279
  .word 0x372b9a63
  .word 0x94e98d51
  .word 0xba9ba2c1
  .word 0x30fb4a01
  .word 0x3bd3c820
  .word 0xb4e11284
  .word 0x64417570
  .word 0x6a4dad7b
  .word 0xfc3fb062
  .word 0x7a7cb6a6
  .word 0xf69f53e3
  .word 0x85440f09
  .word 0x32ab1722
  .word 0x59d3b04b
  .word 0x23876161
  .word 0x81808f0a
  .word 0xa748a9bf
  .word 0xd4509b08
  .word 0x01273e84

/* Private exponent d =
0x1bf6782bb27d670843db3e5a0861d30a0cf86cf9dccb24796daba4e96796f0acf5566b1ec2c3d62da69c9b8b826ea92b7e88b34b53e7affa02d708e26808ee029d04f8a3d265cfc4f55eaa001a4ff54518ad3a91fa5f295ac1e55451bb380edb8071d6a66c6a778ba35e1110e506cd711180483234fb9bae60fdbf980514afd4e10ffbdc443b314192165bc6bbbfcf9f58ecc9e41f2c7126705d2fb00409c5e2ce274d882e0f1188006069504dac00f4626f56d2d637efb905d3c9a418c15c2a9f1b2f1d3fca1461d2b483d3ce354e56f24ebbea9197c2359af199d89cdaf737668626719923e8718ee4f5085ecb1b09aed5f539795ef462f173451e18d04939b2b090fdc6e75bd438be26cc7b0b8244810176d366e6f1b38144510d956f5ed8f5f3f51e50092b54945cf6ecc0a6f317cc44e487dd38f8b3e0f42841ff538d87b75d592fdca3ee5f1eedc81f0d9b2652b5058a3e50b9ab7d266eb0c681f6f829daec744b0cbf7d22d099e96cd3d1e29cb675ecaef5a7d99d35b84ca4d35c6b8d
 */
.balign 32
exp_p:
  .word 0xe2526e49
  .word 0x24768d9b
  .word 0x459c9a7c
  .word 0x9eca2b81
  .word 0xa4e5ff9d
  .word 0x75ea041d
  .word 0xe587706f
  .word 0xe6a1f729
  .word 0xac67fa9e
  .word 0x8ea77d5
  .word 0xd518c409
  .word 0x8c2cea33
  .word 0x890c7544
  .word 0x3508da34
  .word 0x4008e2f6
  .word 0x16df2f35
  .word 0x77027f28
  .word 0x10ec7ed5
  .word 0x49a1d24f
  .word 0xe7ade5c4
  .word 0x94f8e0e0
  .word 0xa3da63a0
  .word 0xe17c69b6
  .word 0x268c1233
  .word 0xd000bdb5
  .word 0xc29e6a49
  .word 0xfd00d58a
  .word 0x7365ae45
  .word 0x3bc41070
  .word 0x34c76127
  .word 0xf4ff6e9a
  .word 0xc0be8577
  .word 0x28ef0c12
  .word 0x8e65db9a
  .word 0x9e2aeec4
  .word 0x2c0d7b53
  .word 0xd007d580
  .word 0xb10149b7
  .word 0x970b4d32
  .word 0x876c5d12
  .word 0xab18f2c8
  .word 0x3c17e0ee
  .word 0xeb402f38
  .word 0x18d23bd9
  .word 0x41984e3d
  .word 0x620a6fc3
  .word 0x38ebafc3
  .word 0x3992d2f0

.balign 32
exp_q:
  .word 0xff7a7017
  .word 0x2a941e72
  .word 0xfd87c634
  .word 0x6a595f55
  .word 0x2beef93a
  .word 0x7463e304
  .word 0x72c0ad72
  .word 0xd7ee1ef3
  .word 0x78d264e8
  .word 0x3d8203d
  .word 0x3e9c7f18
  .word 0xabd7b1bb
  .word 0x1b4a7e1b
  .word 0x42bf8655
  .word 0xb4416734
  .word 0x74d30228
  .word 0x883568df
  .word 0x7ef26bbc
  .word 0xb23836a4
  .word 0xfe5c9481
  .word 0xd1763912
  .word 0x78f1b9e9
  .word 0xb616cfde
  .word 0xa0bcbf12
  .word 0x5305d86e
  .word 0xc271522c
  .word 0xccb75432
  .word 0xcd82a711
  .word 0x80d2718
  .word 0xc66176a3
  .word 0x63ea7cf2
  .word 0x222cc531
  .word 0xf18259a9
  .word 0x3b2ea9e7
  .word 0xd6315e4c
  .word 0x991f8ced
  .word 0x32891ba0
  .word 0x6b870187
  .word 0xcdec494f
  .word 0x32ccf25a
  .word 0x567fd5c6
  .word 0x8a483eb7
  .word 0xf2a8cf79
  .word 0x6f5da21d
  .word 0x5f17e1fd
  .word 0xb16475a9
  .word 0x92a81d1d
  .word 0x6e856825

.balign 32
crt_coeff:
  .word 0xcc1b2c88
  .word 0xa7772839
  .word 0xb4a2442
  .word 0x2e2f6fb7
  .word 0xa6d2c031
  .word 0x547af08a
  .word 0x69066cd0
  .word 0x436a9b93
  .word 0x65d3668c
  .word 0xe9c405b1
  .word 0xe8ee0abc
  .word 0xbf715d4b
  .word 0xdfb5f23b
  .word 0xb6bdeb65
  .word 0x6234294b
  .word 0xf28670b8
  .word 0xa4df54f8
  .word 0xae63829
  .word 0x5b172e39
  .word 0x8b96f150
  .word 0x18326fd9
  .word 0x1275fa93
  .word 0x5158bc90
  .word 0xc0f5e45b
  .word 0x751794a2
  .word 0x1f69a125
  .word 0xc7a60873
  .word 0xded93e83
  .word 0xf65d6651
  .word 0x624c00e2
  .word 0xec74c5c4
  .word 0x87ef82ec
  .word 0xff6aee6e
  .word 0x71caf66
  .word 0xd92b69a8
  .word 0x7fea66e0
  .word 0xb2ab6935
  .word 0xe95e28c
  .word 0x4c8341b3
  .word 0x634afa8c
  .word 0xf12328de
  .word 0x722b5c40
  .word 0x6f122800
  .word 0x11323fd9
  .word 0xe1e2e655
  .word 0xf94cb8e9
  .word 0x75fe8173
  .word 0x29a2662a


/* output buffer */
.balign 32
result:
.zero 384

/* buffer for Montgomery constant RR */
.balign 32
RR:
.zero 384

/* buffer for Montgomery constant m0inv */
.balign 32
m0inv:
.zero 32

.balign 32
work_exp:
.zero 384

.balign 32
work_reduce:
.zero 384
