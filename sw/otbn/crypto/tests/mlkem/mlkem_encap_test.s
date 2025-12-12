/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */
/* Modified by Ruben Niederhagen and Hoang Nguyen Hien Pham - authors of */
/* "Improving ML-KEM & ML-DSA on OpenTitan - Efficient Multiplication Vector Instructions for OTBN" */
/* (https://eprint.iacr.org/2025/2028) */
/* Copyright Ruben Niederhagen and Hoang Nguyen Hien Pham. */

/*
 * Testwrapper for mlkem_encap
*/

.section .text.start

#define STACK_SIZE 20000
#define CRYPTO_BYTES 32

#if KYBER_K == 2
  #define CRYPTO_PUBLICKEYBYTES  800
  #define CRYPTO_SECRETKEYBYTES  1632
  #define CRYPTO_CIPHERTEXTBYTES 768
#elif KYBER_K == 3
  #define CRYPTO_PUBLICKEYBYTES  1184
  #define CRYPTO_SECRETKEYBYTES  2400
  #define CRYPTO_CIPHERTEXTBYTES 1088
#elif KYBER_K == 4
  #define CRYPTO_PUBLICKEYBYTES  1568
  #define CRYPTO_SECRETKEYBYTES  3168
  #define CRYPTO_CIPHERTEXTBYTES 1568
#endif

/* Entry point. */
.globl main
main:
  /* Init all-zero register. */
#ifdef RTL_ISS_TEST
  bn.xor  w0, w0, w0
  bn.xor  w1, w1, w1
  bn.xor  w2, w2, w2
  bn.xor  w3, w3, w3
  bn.xor  w4, w4, w4
  bn.xor  w5, w5, w5
  bn.xor  w6, w6, w6
  bn.xor  w7, w7, w7
  bn.xor  w8, w8, w8
  bn.xor  w9, w9, w9
  bn.xor  w10, w10, w10
  bn.xor  w11, w11, w11
  bn.xor  w12, w12, w12
  bn.xor  w13, w13, w13
  bn.xor  w14, w14, w14
  bn.xor  w15, w15, w15
  bn.xor  w16, w16, w16
  bn.xor  w17, w17, w17
  bn.xor  w18, w18, w18
  bn.xor  w19, w19, w19
  bn.xor  w20, w20, w20
  bn.xor  w21, w21, w21
  bn.xor  w22, w22, w22
  bn.xor  w23, w23, w23
  bn.xor  w24, w24, w24
  bn.xor  w25, w25, w25
  bn.xor  w26, w26, w26
  bn.xor  w27, w27, w27
  bn.xor  w28, w28, w28
  bn.xor  w29, w29, w29
  bn.xor  w30, w30, w30
#endif
  bn.xor  w31, w31, w31

  /* MOD <= dmem[modulus] = KYBER_Q */
  li      x5, 2
  la      x6, modulus
  bn.lid  x5++, 0(x6)
  la      x6, modulus_inv
  bn.lid  x5, 0(x6)
  bn.or   w2, w2, w3 << 32 /* MOD = R | Q */
  bn.wsrw 0x0, w2

  /* Load stack pointer */
  la   x2, stack_end
  la   x10, coins
  la   x11, ct
  la   x12, ss
  la   x13, ek
  jal  x1, crypto_kem_enc

  ecall

.data
.balign 32
.global stack
stack:
  .zero STACK_SIZE
stack_end:
.globl ct
ct:
  .zero CRYPTO_CIPHERTEXTBYTES
.globl ss
ss:
  .zero CRYPTO_BYTES

.balign 32
.globl coins
coins:
  .word 0x87ccb835
  .word 0x62dc233c
  .word 0x1660d2b8
  .word 0x752ffa9a
  .word 0x586a91ab
  .word 0x889174d9
  .word 0x6a5ed235
  .word 0xb2855043

#if (KYBER_K == 2)
.globl ek
ek:
  .word 0x6cc69ac2
  .word 0xf1e3be84
  .word 0x2b8c5029
  .word 0x990c798c
  .word 0xe541caa5
  .word 0x8c9b7e70
  .word 0x7e4dc075
  .word 0x9881a4a8
  .word 0x068b350a
  .word 0x287e4a6a
  .word 0x37105dd1
  .word 0x3dc3754f
  .word 0xd49c02a6
  .word 0xb56f7490
  .word 0xb2ea5f5f
  .word 0xec3d82ce
  .word 0xc1c03018
  .word 0xa39bf88e
  .word 0x4dce3bcc
  .word 0xa4072a25
  .word 0x4c1a400d
  .word 0x1836278d
  .word 0x21db95b5
  .word 0x9e954aca
  .word 0x5533d1b4
  .word 0xb7b20168
  .word 0xb5b25482
  .word 0x00045c95
  .word 0x5abb2d96
  .word 0x24aa7a48
  .word 0x14b630a4
  .word 0x3893afe2
  .word 0x33b0d4af
  .word 0xa930d89b
  .word 0xb11d76cb
  .word 0x352032a8
  .word 0xb823d52d
  .word 0x2c0283a5
  .word 0x65243ea1
  .word 0x578c5406
  .word 0xac5038ba
  .word 0x64d8505c
  .word 0x898bd4e2
  .word 0xcc774269
  .word 0xad74817a
  .word 0xeea21b7b
  .word 0xd2571d62
  .word 0x2dc2239b
  .word 0x208731f8
  .word 0x255d1451
  .word 0x25b0db35
  .word 0xa36d9ce2
  .word 0x9575b48c
  .word 0x08882a8e
  .word 0xd5be31a4
  .word 0x1a8286b4
  .word 0x29a71315
  .word 0x6c9b97cd
  .word 0x0325388b
  .word 0x763353cf
  .word 0x9d05e116
  .word 0x729759dc
  .word 0x7bf1d219
  .word 0xbeabac32
  .word 0xc168c486
  .word 0x862b7b26
  .word 0xa765c52a
  .word 0x6c2632e2
  .word 0x0c70fc83
  .word 0x16b619da
  .word 0x42897337
  .word 0x4c61628e
  .word 0x089facd6
  .word 0x18d212fb
  .word 0x24b3fe27
  .word 0x6cc14bb1
  .word 0x0409c2c0
  .word 0x9d3b97b3
  .word 0x57af60fe
  .word 0x9a447677
  .word 0x09b04ec3
  .word 0x76a8e589
  .word 0xb9c93b14
  .word 0xa5c2a330
  .word 0x081286bb
  .word 0x97dd25f2
  .word 0x6bb35b62
  .word 0xd010882d
  .word 0x89452e45
  .word 0x6a0cb968
  .word 0xdfc2976d
  .word 0xd54173ca
  .word 0x601a743c
  .word 0x8513b9e2
  .word 0xb1b36bc8
  .word 0x70105fbe
  .word 0xe66a548c
  .word 0xba098231
  .word 0xb4d28d26
  .word 0x2772e4e3
  .word 0xe21a4961
  .word 0x48026015
  .word 0x601e54e7
  .word 0xf465b880
  .word 0x029c164a
  .word 0xf174b3a5
  .word 0x330255fa
  .word 0x9c975337
  .word 0x5254a79d
  .word 0x8b4a81c4
  .word 0xb882d68f
  .word 0x990637e0
  .word 0xf4c26b29
  .word 0xa2e5382d
  .word 0xf5c592de
  .word 0xb6241ff6
  .word 0x759b1b5e
  .word 0x59879b24
  .word 0x64068770
  .word 0x90b40000
  .word 0xe1837693
  .word 0x9af3bbcc
  .word 0x1ecbae0b
  .word 0x678262dd
  .word 0xcc4b5221
  .word 0x6ff03b4d
  .word 0x68b35a8e
  .word 0xb46e42aa
  .word 0x3918702c
  .word 0x69ccbbe8
  .word 0x75d2ccdb
  .word 0x0ac6847f
  .word 0x29669b40
  .word 0x29c98dd9
  .word 0x527c3647
  .word 0x3c8c69f0
  .word 0x1011c041
  .word 0x06ebfbba
  .word 0x5117cc21
  .word 0x825f3770
  .word 0x24f6c050
  .word 0x102ee306
  .word 0xe3475b72
  .word 0x5a8465c1
  .word 0xb28fda7a
  .word 0xf55555c5
  .word 0x240286cc
  .word 0x876fe06f
  .word 0xc9b56e5a
  .word 0x92d19d45
  .word 0x92844292
  .word 0xb83867a7
  .word 0xc8847e05
  .word 0xc43614e1
  .word 0x498e78eb
  .word 0x6552394e
  .word 0xa231d37e
  .word 0x757da4e4
  .word 0xc4652349
  .word 0x2084f473
  .word 0x8c860205
  .word 0xb2b93b73
  .word 0xf24ae4b3
  .word 0xb9df8ac9
  .word 0x141a4e1a
  .word 0x325aec4e
  .word 0xc7134fd2
  .word 0x06f27587
  .word 0xee4da9d7
  .word 0x777f0012
  .word 0x144a488e
  .word 0xfe6b6630
  .word 0x31bb6dda
  .word 0x2bd757b7
  .word 0x69a4795c
  .word 0x59e62f52
  .word 0xb545bb9a
  .word 0x3c40c62c
  .word 0x56f67049
  .word 0x0c77bb84
  .word 0xba9388a7
  .word 0x01579043
  .word 0x9c305536
  .word 0x4c524cd8
  .word 0xe358a59c
  .word 0xb7412061
  .word 0x216e02b2
  .word 0xfb8a5987
  .word 0xcad4f146
  .word 0xbc6d0985
  .word 0x251ccc9b
  .word 0x60fb9d77
  .word 0x16e15270
  .word 0x5f7fbb49
  .word 0x79f96872
  .word 0x0a14d8c4
  .word 0x38e56cfe
  .word 0x0286f330
  .word 0x14750d29
  .word 0x277bf027
#elif (KYBER_K == 3)
.globl ek
ek:
  .word 0x02322078
  .word 0x448e2330
  .word 0x9ba9cf7a
  .word 0x53b73263
  .word 0x42e57c1c
  .word 0xca931b03
  .word 0x5f8f2514
  .word 0x870cb398
  .word 0xb2016d3f
  .word 0x343f85c5
  .word 0x04186902
  .word 0xa7084780
  .word 0xa55bfaec
  .word 0x88ef0f98
  .word 0xa8f5ce36
  .word 0x7583ac2d
  .word 0xcb3462e0
  .word 0xc54cd6be
  .word 0x06acb2a4
  .word 0xd9b4a084
  .word 0x44663e86
  .word 0x494833a8
  .word 0xfbdbcfc0
  .word 0xb0841b85
  .word 0xb06f8ce4
  .word 0x52d00148
  .word 0x6876d52f
  .word 0x6744169b
  .word 0xdab44a60
  .word 0xcfab342e
  .word 0x4492dc76
  .word 0x574e4c67
  .word 0x7c78f530
  .word 0x42219067
  .word 0x1540134c
  .word 0x3349244d
  .word 0x0e94bc0d
  .word 0x03e17bba
  .word 0x0a94ec99
  .word 0x6040356b
  .word 0x50669914
  .word 0x89a148b1
  .word 0x5e7f4743
  .word 0xa0410f95
  .word 0x8834b61a
  .word 0xf006f2fa
  .word 0x31a725f2
  .word 0x84776709
  .word 0xec6d1b79
  .word 0xeb600e98
  .word 0xbfbb968f
  .word 0xb0222247
  .word 0xf9128a24
  .word 0x7da18861
  .word 0x523eb868
  .word 0xa27b82c9
  .word 0x7582bcc6
  .word 0x46ae310b
  .word 0x287a82b9
  .word 0x38b3fc77
  .word 0xb8683a00
  .word 0x969caac1
  .word 0x03d2556b
  .word 0x57117478
  .word 0xdbf60577
  .word 0xb4f95915
  .word 0x18578a25
  .word 0x835d5020
  .word 0xa29a00c1
  .word 0x75b384b2
  .word 0x6a61aca7
  .word 0xa242291b
  .word 0x3ec494b4
  .word 0xb9c170b3
  .word 0x2b52cd4a
  .word 0xc7178c20
  .word 0x607e0735
  .word 0x0c41412f
  .word 0xa13e1bfb
  .word 0xc3582109
  .word 0xcc43eab6
  .word 0x0903a77a
  .word 0x64a90fa6
  .word 0x2a332147
  .word 0xbd55c40d
  .word 0xe6d563b5
  .word 0x1012e26e
  .word 0x8d592a87
  .word 0x8351a913
  .word 0x7a509a11
  .word 0x453b3476
  .word 0x4b20b34b
  .word 0x9b4683ad
  .word 0xa7522756
  .word 0xe8e5003a
  .word 0x87d9a6c5
  .word 0x7893ca0a
  .word 0x0bc20569
  .word 0x5df40285
  .word 0xd2a81491
  .word 0xe02ebdc7
  .word 0x80b77f08
  .word 0x587850fa
  .word 0x146f028b
  .word 0x68c06c19
  .word 0x7b5ea7f6
  .word 0xea3a444a
  .word 0xaf5c4241
  .word 0xa312a22d
  .word 0x44f6ade6
  .word 0x90c26451
  .word 0x439d408f
  .word 0x0be45e96
  .word 0xc854d689
  .word 0x48973041
  .word 0xe2909b6a
  .word 0x387444b0
  .word 0xb7361891
  .word 0x6be784ca
  .word 0x00e68e7a
  .word 0xa8553ba1
  .word 0xb2a03db8
  .word 0x2b382508
  .word 0x25bec3da
  .word 0xc7246004
  .word 0x53407688
  .word 0xfa2c92f1
  .word 0x16b8a1a2
  .word 0x6da33022
  .word 0x8ecf36bb
  .word 0xb1a1c862
  .word 0x90519d5f
  .word 0xf5b40a07
  .word 0xf8baa370
  .word 0xad047c63
  .word 0xb4a45119
  .word 0x7a5b0b61
  .word 0xc35633b2
  .word 0x12a8369e
  .word 0x59a25885
  .word 0xafa8e114
  .word 0x1277e476
  .word 0xb13854f8
  .word 0xce048d9e
  .word 0xd3203592
  .word 0xe4c40aab
  .word 0x36f25808
  .word 0xb49dd42d
  .word 0xf7edb746
  .word 0x834cdda0
  .word 0xfa7e30aa
  .word 0xb8b37687
  .word 0x1f0aa1c7
  .word 0xda8ee6df
  .word 0x2ad49c1b
  .word 0x76c4cec0
  .word 0x1893250c
  .word 0x41182c08
  .word 0x93c22c5d
  .word 0xee06f667
  .word 0x45011cea
  .word 0x88a29e38
  .word 0x8da683f3
  .word 0x7a1220d6
  .word 0xcb8ba8ac
  .word 0xa645426b
  .word 0xa6054f64
  .word 0x3d16f1b9
  .word 0x577ee138
  .word 0x5ccc27cb
  .word 0xca2c7b46
  .word 0xcf74f994
  .word 0x520d15d8
  .word 0x2052e194
  .word 0xfaba390b
  .word 0xfa9c9b46
  .word 0x7bebacc3
  .word 0x137bb456
  .word 0xea8171f1
  .word 0x10788795
  .word 0x9dae77a7
  .word 0x51ed6015
  .word 0xb709ab19
  .word 0xe320b16a
  .word 0xd56119c6
  .word 0x16933a8c
  .word 0xd25fa069
  .word 0x97512f88
  .word 0x47b0c3b7
  .word 0x82aa97a1
  .word 0x5c8a200c
  .word 0xbe40bcb5
  .word 0xf58825b8
  .word 0x350b0b61
  .word 0x3950b84e
  .word 0xfd1da4b0
  .word 0x168f2439
  .word 0x7a02bb5a
  .word 0xe01768fd
  .word 0xaaad8d0c
  .word 0x25cb29cb
  .word 0x097524e4
  .word 0x7527ae32
  .word 0xb7b7986a
  .word 0x90532849
  .word 0x565aa99c
  .word 0x36132a92
  .word 0xb8026c90
  .word 0x58bb0512
  .word 0xc0e84d69
  .word 0x235c002a
  .word 0x79c80926
  .word 0xb66ab197
  .word 0xd30d79bc
  .word 0xb9033029
  .word 0x2b7b86b4
  .word 0x56c4046e
  .word 0x94355018
  .word 0x9d9c26aa
  .word 0xa19ac34f
  .word 0xbc3f36ec
  .word 0x4102c757
  .word 0x6b1d0b31
  .word 0xa5e89844
  .word 0xb187c456
  .word 0x9baa456e
  .word 0xa9a6b1b9
  .word 0x6f442abb
  .word 0xed09e36e
  .word 0x32551dec
  .word 0x94867a99
  .word 0xe391b9dd
  .word 0x95f877a6
  .word 0x34a95f88
  .word 0x7e21ea81
  .word 0x4b471cba
  .word 0x148881c4
  .word 0x2203dc7f
  .word 0xc3a5cc81
  .word 0x3e1c5b0d
  .word 0xbd3209d9
  .word 0x925548e1
  .word 0x4f225e9f
  .word 0x36753827
  .word 0x7c0c604b
  .word 0x1fd36b91
  .word 0xc4bbd766
  .word 0xe636c570
  .word 0x7fdae800
  .word 0x993bfb31
  .word 0x77e77345
  .word 0x6939c596
  .word 0x305e1a37
  .word 0x32a071c3
  .word 0xc226e450
  .word 0xee9edadb
  .word 0x656b9bd3
  .word 0x66803803
  .word 0x645ed305
  .word 0x91d059d5
  .word 0x51f72e0d
  .word 0x0033a8af
  .word 0xb55d902c
  .word 0x8109e05e
  .word 0x1111f275
  .word 0x9c6a2f82
  .word 0x97cbab1a
  .word 0x3b15cc71
  .word 0xd719b6b4
  .word 0x2382fa35
  .word 0x8b6af0d5
  .word 0xe308792b
  .word 0x827b8f2d
  .word 0xc988ac9d
  .word 0x2a74a4ca
  .word 0x4ba4a212
  .word 0xf72014c6
  .word 0xc3876bd2
  .word 0x6cc533c8
  .word 0x1bcc1ab5
  .word 0x649a8cd4
  .word 0x8e604f8b
  .word 0x8e37eb4f
  .word 0x3cb75465
  .word 0x9d7be3a8
  .word 0x446ba75f
  .word 0xf897031c
  .word 0xb239aac0
  .word 0x3cbc8a34
  .word 0xa6130d6d
  .word 0x2ad691bd
  .word 0x6051c643
  .word 0xbfd5df63
  .word 0x08f1f077
  .word 0x7b432442
  .word 0xa22ba847
#elif (KYBER_K == 4)
.globl ek
ek:
  .word 0x55748628
  .word 0xeab67484
  .word 0x17d1b33b
  .word 0xd112a702
  .word 0xf640649b
  .word 0x5c77668c
  .word 0x6568a161
  .word 0x34f29b66
  .word 0x8cf1a90e
  .word 0xe4b3b240
  .word 0x7cf48d98
  .word 0x3fb07c31
  .word 0x2caf6a73
  .word 0x23d45a1a
  .word 0xc18b2f45
  .word 0x95741ab8
  .word 0x1161b83c
  .word 0x7cf67d38
  .word 0x2690c747
  .word 0xd22a6e38
  .word 0x2533e0c5
  .word 0xd074616f
  .word 0x6bc885d7
  .word 0x71255e71
  .word 0xae24ab56
  .word 0xb5aa2068
  .word 0x5d3cb4a0
  .word 0xe225ab15
  .word 0x95185179
  .word 0x0b36d01d
  .word 0xca3cd147
  .word 0x6a01bd45
  .word 0x7fc9b40c
  .word 0xfcb1663f
  .word 0x41972e61
  .word 0x8f9bb34d
  .word 0xc04b2ad8
  .word 0xf3927d9a
  .word 0xa7e94282
  .word 0xa83f5319
  .word 0x17b96b40
  .word 0x8615fc84
  .word 0x9f6952cf
  .word 0x03532dd9
  .word 0x0dc5fa09
  .word 0x5cc4fce1
  .word 0xdba09a1c
  .word 0x0438cc9b
  .word 0x9c6e0934
  .word 0xd0ca1792
  .word 0x73349336
  .word 0x473d832f
  .word 0xbc162198
  .word 0x3d1c1a95
  .word 0x4a88d035
  .word 0xf5744261
  .word 0x7fa670c8
  .word 0x2526f505
  .word 0xd0c971e7
  .word 0xa4715d86
  .word 0x0ba379a5
  .word 0x22ad0f1c
  .word 0x8cfb6283
  .word 0xfdcab10e
  .word 0xb8b281c5
  .word 0xb2d6b17a
  .word 0x559247c6
  .word 0x23cfa798
  .word 0x6ae5749d
  .word 0x2500b64a
  .word 0x4caf7e59
  .word 0x417ae532
  .word 0x579db425
  .word 0x82232d31
  .word 0x29c1325a
  .word 0xc5409b28
  .word 0x7a8a68eb
  .word 0x5b67bfaf
  .word 0xb4a6469e
  .word 0xe3682066
  .word 0x2e5a1475
  .word 0x5d5067b9
  .word 0x1957ca33
  .word 0x00f003bd
  .word 0x70cf584b
  .word 0xeb4f0af1
  .word 0x9ca9f859
  .word 0x491c7125
  .word 0x86ef0c43
  .word 0xb71ca453
  .word 0x000e1036
  .word 0x3274b134
  .word 0x57237546
  .word 0xdc286080
  .word 0xcc2b53f8
  .word 0x01915acf
  .word 0xe8a6129a
  .word 0x8a917f69
  .word 0x48502b7f
  .word 0xa15a264f
  .word 0xe2977639
  .word 0x4767d85e
  .word 0x4e8a3823
  .word 0x35fb9651
  .word 0x776cf595
  .word 0x34703adc
  .word 0x2c825324
  .word 0xb987dc7a
  .word 0x3d37b3d1
  .word 0x457042ba
  .word 0xb3c4e45b
  .word 0x6a47e6b3
  .word 0xe2f4a208
  .word 0x5ab881cb
  .word 0xcc3e95d1
  .word 0xf5a07bb6
  .word 0xbb0c111d
  .word 0x80c4833c
  .word 0xdb108d91
  .word 0x5659b90d
  .word 0x5a11092a
  .word 0x8ba5be29
  .word 0xb345e631
  .word 0xe4967413
  .word 0xd2b6c49b
  .word 0xbb2c3d2b
  .word 0x5266d87c
  .word 0xf5d909ab
  .word 0x46394d22
  .word 0x8e3a4af5
  .word 0x04f206e3
  .word 0x7f547789
  .word 0xf9a5a4af
  .word 0x82d16009
  .word 0x9cc5cec1
  .word 0x4564e6b5
  .word 0x97389dcc
  .word 0x74d029bc
  .word 0x51cc4a00
  .word 0xfa06b3f3
  .word 0x4a03fb5a
  .word 0x3daa50a6
  .word 0xbc2529cc
  .word 0xba35da0c
  .word 0xdb43359d
  .word 0xf474a327
  .word 0x5bc2103d
  .word 0x683606bd
  .word 0x752030d1
  .word 0x6ea25acc
  .word 0x6fa0c219
  .word 0x8b25c7db
  .word 0xb487c653
  .word 0xe3c77172
  .word 0x4450a2e8
  .word 0x2f63ca2b
  .word 0xdf7b5885
  .word 0xea83a902
  .word 0x08142b7d
  .word 0xa776e05a
  .word 0xc641b8a9
  .word 0x69d10f8e
  .word 0x088fa422
  .word 0xa814c829
  .word 0x85e2d817
  .word 0x8c7508ef
  .word 0xd899c544
  .word 0xb07c2a30
  .word 0xcf27c90f
  .word 0x88059f49
  .word 0x8df27c44
  .word 0x038d774e
  .word 0xc56f3e9c
  .word 0x1cf12a19
  .word 0xb88afb1d
  .word 0xa4f5065a
  .word 0x744392aa
  .word 0x18b9e979
  .word 0x9a68ccc6
  .word 0xa9e8c745
  .word 0x5e079748
  .word 0xb18274fb
  .word 0x95331744
  .word 0xa92d4ab0
  .word 0xf811c888
  .word 0x65b5e978
  .word 0xf233cabe
  .word 0xd06a3c64
  .word 0x31f2cab2
  .word 0xd3cbb05b
  .word 0x98cd84f1
  .word 0x7143bd7f
  .word 0x3e181978
  .word 0x5769a605
  .word 0xaa891c77
  .word 0xc6609983
  .word 0x005659a8
  .word 0x5523adcc
  .word 0x2f2c5796
  .word 0x3a0b0652
  .word 0xc875080b
  .word 0x0b9e024a
  .word 0x7484283a
  .word 0x3ee5ee35
  .word 0x0688a972
  .word 0xa10037c3
  .word 0x0b19e83e
  .word 0xc62d72c3
  .word 0x85ea6634
  .word 0x8e7ade97
  .word 0x992e9751
  .word 0x60831f44
  .word 0x56f988ce
  .word 0x9d524497
  .word 0xf7a783e0
  .word 0xa34204c5
  .word 0x53c4f5d7
  .word 0x95b86169
  .word 0x29e290ae
  .word 0xb3990b1e
  .word 0xa801cce1
  .word 0xba5aa4a3
  .word 0xba06c472
  .word 0xf3d50ea3
  .word 0xb7008681
  .word 0x5d5a867f
  .word 0x23e86e79
  .word 0x0ad68dc9
  .word 0xe2615b28
  .word 0x2c849ee7
  .word 0x1e623ec6
  .word 0x1415363b
  .word 0x4176b844
  .word 0xc3648c65
  .word 0x3ea71b71
  .word 0x31aa970a
  .word 0xc9c90730
  .word 0x1677bcc9
  .word 0xc28f71f7
  .word 0xa032bf7c
  .word 0xd700fc5b
  .word 0x39439a19
  .word 0x79309a45
  .word 0x4f5f3a93
  .word 0xe1153bc8
  .word 0x1a953d10
  .word 0x981a0568
  .word 0xb9e33ee7
  .word 0x074ac590
  .word 0x5d24929d
  .word 0xd4ac8f8c
  .word 0x89129ba0
  .word 0x228e6ce4
  .word 0x412e1154
  .word 0xb954b47d
  .word 0xae452cf3
  .word 0x26e0ad69
  .word 0x0a936902
  .word 0xae15d840
  .word 0x1b75c460
  .word 0x1cc27506
  .word 0x00705b22
  .word 0x6b259f97
  .word 0x2b45f4bd
  .word 0xd0ab8ca9
  .word 0xc3d530b3
  .word 0x99582e59
  .word 0xbd9fe042
  .word 0xc1b48987
  .word 0x42842917
  .word 0x96cbe229
  .word 0xe5cbb17c
  .word 0x8be0e9c8
  .word 0x52b494f6
  .word 0x9c976cbc
  .word 0x45170110
  .word 0xf53ee6b0
  .word 0x0a914eaa
  .word 0xcda53c29
  .word 0x092cb11d
  .word 0x79fc5a1a
  .word 0x4322184e
  .word 0x8b756b87
  .word 0xcab60e1b
  .word 0xb782b33d
  .word 0x0fc451c6
  .word 0xe26c2f53
  .word 0xa59c8bc1
  .word 0x1f7eb56b
  .word 0xba65a59a
  .word 0x993668c4
  .word 0x7a633879
  .word 0xaa0fb792
  .word 0x26d243ae
  .word 0x3f5d72e8
  .word 0x5bbd35c7
  .word 0xbb323f25
  .word 0xe00ca834
  .word 0x637a231a
  .word 0xc2794d5a
  .word 0xef88b922
  .word 0x234d7550
  .word 0xc3b94540
  .word 0xc7a561f3
  .word 0x57d55bc1
  .word 0xb7b7e1ab
  .word 0x950cdce0
  .word 0x13648a6b
  .word 0xb2dbdc8e
  .word 0x4c2c4c68
  .word 0x06f74b69
  .word 0x06017e24
  .word 0x39a63538
  .word 0xe3e108d2
  .word 0x11e9b911
  .word 0x90128463
  .word 0x85c2c053
  .word 0x87256c43
  .word 0xc41b3c05
  .word 0xdad8a083
  .word 0xbf4b7d38
  .word 0xea12e5ea
  .word 0x07cfc231
  .word 0x1d77dd03
  .word 0x677e064a
  .word 0x80799b18
  .word 0xccbb98ca
  .word 0x964c38da
  .word 0x0c2e27e8
  .word 0x44585970
  .word 0x7f4965a4
  .word 0xa7583aac
  .word 0x9f86f24f
  .word 0x537e53b2
  .word 0x58db53b6
  .word 0x674881a4
  .word 0xcb6b0ad3
  .word 0x46801f5a
  .word 0x0bc23ace
  .word 0x87843311
  .word 0x8ca987ca
  .word 0x7713b3af
  .word 0x7125813e
  .word 0x4cdb1872
  .word 0x095c8e23
  .word 0x1aa02cfd
  .word 0xe5b79cf4
  .word 0xab207681
  .word 0x4d576a46
  .word 0x53bdaa1a
  .word 0x30d6d0b7
  .word 0x9b17fc91
  .word 0xdc419f54
  .word 0x8fb88f04
  .word 0xb06748a5
  .word 0xdbb15663
  .word 0x0641c48a
  .word 0xe14fd847
  .word 0x8344bfb7
  .word 0x65639e89
  .word 0xe8bdf55e
  .word 0x95bf24e8
  .word 0x29828566
  .word 0x095850a6
  .word 0x4a6737e3
  .word 0x0c27c01f
  .word 0xbc2a9ca6
  .word 0x4c05cab3
  .word 0x0f70552b
  .word 0x0269b1de
  .word 0xe3377e2c
  .word 0xb3fcd262
  .word 0xb876a271
  .word 0x23eb9054
  .word 0x1142d655
  .word 0x16bc5287
  .word 0xe94f74f4
  .word 0x49125711
  .word 0xa4621108
  .word 0x19f78411
  .word 0x2930e1a1
  .word 0x9b9653c9
  .word 0x55fd59c1
  .word 0x7a5a151b
  .word 0x36820a68
  .word 0x1e9adde7
  .word 0xb9dd5265
  .word 0x19c8e553
  .word 0xcc38c34c
  .word 0xdad48bb8
  .word 0xe84c1a4c
  .word 0x3959e1aa
#endif
