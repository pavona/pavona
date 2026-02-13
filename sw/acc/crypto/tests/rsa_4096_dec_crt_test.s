/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.section .text.start

/**
 * Standalone RSA-4096 modexp with secret exponent (decryption/signing).
 */
main:
  /* Init all-zero register. */
  bn.xor  w31, w31, w31

  /* Load number of limbs. */
  li    x30, 16

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
  .word 0xfec5dc2d
  .word 0x3a7a8fe5
  .word 0x6c3daadf
  .word 0x3116e661
  .word 0x1fb6d872
  .word 0xd50b544a
  .word 0x8133aec2
  .word 0xfb9b5415
  .word 0x7db2f4cb
  .word 0xe63788ac
  .word 0x8dcc7cf0
  .word 0x0b910894
  .word 0x537a81ae
  .word 0x275ae3ff
  .word 0x4bd9b25c
  .word 0x86a42570
  .word 0xfece96d6
  .word 0x3fdb1334
  .word 0xab8cd66a
  .word 0x277382c6
  .word 0x7da58545
  .word 0xab016340
  .word 0x5ad39a03
  .word 0x9f3ca8e2
  .word 0xcba7ef37
  .word 0x02b1212e
  .word 0x187bbe72
  .word 0xa1fd671c
  .word 0x4a7247d2
  .word 0x37cb9754
  .word 0x439b988c
  .word 0x74f46ad6
  .word 0xaded1926
  .word 0x03612c7c
  .word 0xbee2960c
  .word 0x63deaf6d
  .word 0x797c8a2a
  .word 0x51daf082
  .word 0x371446c2
  .word 0x8b1329fb
  .word 0xd797d718
  .word 0xf4303bbd
  .word 0x40799edd
  .word 0x78cfbb07
  .word 0x5574655d
  .word 0xd80bd17f
  .word 0xb4b59f8a
  .word 0x3dfc9de5
  .word 0xa0911bbe
  .word 0x47064f36
  .word 0xb2559173
  .word 0xe9cdba80
  .word 0xcc87a4b5
  .word 0x738ecaa4
  .word 0xb2c027a2
  .word 0x2c199b85
  .word 0x4f16a517
  .word 0x31762e77
  .word 0x57df7f1c
  .word 0xb6e17379
  .word 0xfac6162e
  .word 0x0860cdc1
  .word 0x091c375d
  .word 0xf89d646e

.balign 32
modulus_q:
  .word 0x5e21ad4b
  .word 0x79e61238
  .word 0x3082c1b1
  .word 0xd8e5685b
  .word 0x157b6069
  .word 0xeb543e45
  .word 0xcb026c71
  .word 0xdf52981f
  .word 0xc303fcc9
  .word 0x648442e5
  .word 0x63c9a278
  .word 0xa6ecad7d
  .word 0x75b6339e
  .word 0xebf32fd9
  .word 0xdfc252f6
  .word 0x3a938e04
  .word 0xcf596e98
  .word 0x24486520
  .word 0x9317e2da
  .word 0xa8a4908a
  .word 0x44e9b287
  .word 0xe13f02cc
  .word 0xa81cfbb9
  .word 0x692e6385
  .word 0x98f840f5
  .word 0x458a2225
  .word 0x005bc81e
  .word 0x01a12638
  .word 0xae960769
  .word 0xee66f159
  .word 0x92a04b83
  .word 0xa30b4d66
  .word 0x1b4aa41b
  .word 0xda9a6767
  .word 0x2709172d
  .word 0xc6909732
  .word 0x5a04fb0c
  .word 0xa87341b8
  .word 0x94a33478
  .word 0x57ee542f
  .word 0xbd116900
  .word 0x361043f2
  .word 0x4c79a269
  .word 0x47e5f9d9
  .word 0x9feadcd3
  .word 0xe2a21f9f
  .word 0x344e3f67
  .word 0xa1ba9352
  .word 0x73c73e51
  .word 0x5d0f1b92
  .word 0x67d7d3e2
  .word 0x060da8dc
  .word 0x7fb2c3c6
  .word 0xe277e595
  .word 0x1f6894ba
  .word 0x678bc544
  .word 0xaf1a3cf3
  .word 0x086f1e3a
  .word 0xbdc21aae
  .word 0x7d16717d
  .word 0x9713cdfd
  .word 0x4e2bf026
  .word 0xe90dc9ed
  .word 0xfad5e5fd

/* Base for exponentiation (corresponds to ciphertext for decryption or
   message for signing).

   Raw hex value =
0x9d30784f6d19ff12553efa3e7baac375a37e8b2148af01222df209a15ab998928da72ed1779de91cee893c030d6267c96678a829d56cb55b74b62c1dba458d57283390b47e4091d392f3166c6827baaa53518f953b4d3c58abc1e31acd8edef0b3161ef2203a7118bc9ed4f1eea0fac4989a400c9f1ec3bf00895772b4c526f268cd2ee835bc2964b6592bfa4fddc90ccd15237d24a199760a1843c89ebed2959d79b5e7333015099953259d4650f46e79e643e8283810a6df38567e76bd4d7d3a89df631d47fc32a1da22d4074edc4e227059d4d1c39203dfde07827cc4e13b93e41e00f4be2de6055eba062be75268e7b555dc96998b6aa7a0421475d93039d86859b04a4d43560567bb41e45abfe1d8fb1229bd36d5e7ae3a3efaf9903b524808b7c4972e9520a97d5178f7f2062b8d579282cebab07629f633282e6b25649271338332208b46bd72c6d91e2aeaad993aa0a8ed354f31f719058c08187ce49067394d7b74ff7e82799c9fb90e5ad6bfd78d77c9c43798feee23a8abf7017314104d4d981afecace389345cf7c3a4d89643f8c24728f3e145f6d39ba584c2f9f9eaeb86c1be506320d058d30c05198928c2f5e25178fae84dc0369758555f3527f5f6e5319dff9a3e2fd95c9ae8892e5dbd1cda14c7b6ada79b0095fac4a4f8c00ada71220b5dd3b13340f4cad4201496136ee946bea29dca9ab41c3da9ac0
 */
.balign 32
base:
  .word 0xc3da9ac0
  .word 0xdca9ab41
  .word 0x946bea29
  .word 0x496136ee
  .word 0x4cad4201
  .word 0x3b13340f
  .word 0x1220b5dd
  .word 0x8c00ada7
  .word 0x5fac4a4f
  .word 0xda79b009
  .word 0xa14c7b6a
  .word 0xe5dbd1cd
  .word 0xc9ae8892
  .word 0xa3e2fd95
  .word 0x5319dff9
  .word 0x527f5f6e
  .word 0x758555f3
  .word 0x84dc0369
  .word 0x25178fae
  .word 0x928c2f5e
  .word 0x30c05198
  .word 0x320d058d
  .word 0x6c1be506
  .word 0x9f9eaeb8
  .word 0xba584c2f
  .word 0x145f6d39
  .word 0x24728f3e
  .word 0x89643f8c
  .word 0xcf7c3a4d
  .word 0xce389345
  .word 0x981afeca
  .word 0x14104d4d
  .word 0xabf70173
  .word 0xfeee23a8
  .word 0xc9c43798
  .word 0xbfd78d77
  .word 0xb90e5ad6
  .word 0x82799c9f
  .word 0x7b74ff7e
  .word 0x9067394d
  .word 0x08187ce4
  .word 0xf719058c
  .word 0xed354f31
  .word 0x993aa0a8
  .word 0x1e2aeaad
  .word 0xbd72c6d9
  .word 0x32208b46
  .word 0x92713383
  .word 0x2e6b2564
  .word 0x29f63328
  .word 0xcebab076
  .word 0x8d579282
  .word 0xf7f2062b
  .word 0xa97d5178
  .word 0x972e9520
  .word 0x4808b7c4
  .word 0xf9903b52
  .word 0xae3a3efa
  .word 0xbd36d5e7
  .word 0xd8fb1229
  .word 0xe45abfe1
  .word 0x0567bb41
  .word 0x4a4d4356
  .word 0xd86859b0
  .word 0x75d93039
  .word 0xa7a04214
  .word 0x96998b6a
  .word 0xe7b555dc
  .word 0x2be75268
  .word 0x055eba06
  .word 0xf4be2de6
  .word 0x93e41e00
  .word 0x7cc4e13b
  .word 0xdfde0782
  .word 0xd1c39203
  .word 0x227059d4
  .word 0x074edc4e
  .word 0xa1da22d4
  .word 0x1d47fc32
  .word 0x3a89df63
  .word 0x76bd4d7d
  .word 0xdf38567e
  .word 0x283810a6
  .word 0x79e643e8
  .word 0x4650f46e
  .word 0x9953259d
  .word 0x33301509
  .word 0x9d79b5e7
  .word 0x9ebed295
  .word 0x0a1843c8
  .word 0x24a19976
  .word 0xcd15237d
  .word 0x4fddc90c
  .word 0xb6592bfa
  .word 0x35bc2964
  .word 0x68cd2ee8
  .word 0xb4c526f2
  .word 0x00895772
  .word 0x9f1ec3bf
  .word 0x989a400c
  .word 0xeea0fac4
  .word 0xbc9ed4f1
  .word 0x203a7118
  .word 0xb3161ef2
  .word 0xcd8edef0
  .word 0xabc1e31a
  .word 0x3b4d3c58
  .word 0x53518f95
  .word 0x6827baaa
  .word 0x92f3166c
  .word 0x7e4091d3
  .word 0x283390b4
  .word 0xba458d57
  .word 0x74b62c1d
  .word 0xd56cb55b
  .word 0x6678a829
  .word 0x0d6267c9
  .word 0xee893c03
  .word 0x779de91c
  .word 0x8da72ed1
  .word 0x5ab99892
  .word 0x2df209a1
  .word 0x48af0122
  .word 0xa37e8b21
  .word 0x7baac375
  .word 0x553efa3e
  .word 0x6d19ff12
  .word 0x9d30784f

.balign 32
exp_p:
  .word 0xbd38b4e5
  .word 0x338f3434
  .word 0x4398624c
  .word 0x38b4f616
  .word 0x77e9f4e8
  .word 0x6062d874
  .word 0xc0b0464d
  .word 0xdbd2990b
  .word 0x83326c85
  .word 0x00769d0c
  .word 0xa2f5dd12
  .word 0xc65f5ac9
  .word 0x2d16829b
  .word 0x1641189b
  .word 0xa516cd56
  .word 0x6d6b9dc5
  .word 0xb7af8617
  .word 0xe6331ae9
  .word 0x3a5e8290
  .word 0xd44f8530
  .word 0x8178f89d
  .word 0x7977b417
  .word 0x992d7f89
  .word 0xf84fd5bd
  .word 0xdb6359c3
  .word 0x3d0e3da1
  .word 0x2edb2e70
  .word 0x92fbdd68
  .word 0x71aa33a5
  .word 0x316169e6
  .word 0x43187f12
  .word 0xaa6c983b
  .word 0xaa4198c1
  .word 0x3d944978
  .word 0x00740e91
  .word 0xa886b415
  .word 0xa15cc586
  .word 0xeacd414c
  .word 0x082fddc1
  .word 0x18058c3a
  .word 0x31690047
  .word 0x26c5e1cc
  .word 0x810ded12
  .word 0xf20ded30
  .word 0x1aa7693d
  .word 0x3a3c4114
  .word 0xaed87162
  .word 0x64d322ec
  .word 0x38fb9e18
  .word 0x439672d6
  .word 0xcdbcf565
  .word 0x8aa7e097
  .word 0x3d641f62
  .word 0x9e7a3be1
  .word 0x772945f1
  .word 0xcc7006f5
  .word 0x315594a1
  .word 0x31a52a19
  .word 0x8438f610
  .word 0x312da3a2
  .word 0xd49b9eab
  .word 0x77253d28
  .word 0x87ae129f
  .word 0xc18a6da3

.balign 32
exp_q:
  .word 0x3c442975
  .word 0xae2609f5
  .word 0x4213cb89
  .word 0xb4b9fd03
  .word 0xa8cbbc49
  .word 0xc41dbbc1
  .word 0x73b8fcab
  .word 0xe9150c2c
  .word 0x8cf18373
  .word 0x8022e3aa
  .word 0x6fe2935a
  .word 0xe9e6e2fe
  .word 0xa0c391f8
  .word 0x6e77203b
  .word 0x29f730df
  .word 0xdd9827a5
  .word 0xc806df1d
  .word 0x551a6115
  .word 0x1c5df6d3
  .word 0xea23a139
  .word 0x2f771df2
  .word 0x4d7fb2a4
  .word 0xc7828224
  .word 0x7ccb151f
  .word 0x040e702b
  .word 0x68092203
  .word 0xb81b4929
  .word 0x99a76adf
  .word 0x1da2db8c
  .word 0x9eae352e
  .word 0x635058fd
  .word 0x3dbd7330
  .word 0x9e8c1a95
  .word 0xbb225c57
  .word 0x72abc25d
  .word 0x737a8ec6
  .word 0x92359aac
  .word 0xe751ba85
  .word 0xc14fb850
  .word 0xb6635b30
  .word 0x2a415627
  .word 0xf89786ae
  .word 0x24b548e5
  .word 0xe5d70b58
  .word 0x4fb0677d
  .word 0x3264620a
  .word 0x79701066
  .word 0xb92497d9
  .word 0xad452c91
  .word 0xd19ba820
  .word 0x763508b0
  .word 0x0812c736
  .word 0x70ea4c53
  .word 0xce45b5ff
  .word 0x95ef8235
  .word 0xd1308f1c
  .word 0xbd33162f
  .word 0xbaae281f
  .word 0x78c63750
  .word 0x6e032ce4
  .word 0xdd0280e6
  .word 0xdd2aa386
  .word 0x504158fe
  .word 0x1e135b9a

.balign 32
crt_coeff:
  .word 0x3e163b3d
  .word 0xdca2d3af
  .word 0x4d60a829
  .word 0xd2484fa0
  .word 0xbaf6c73b
  .word 0xe25b7f9f
  .word 0x140f9b02
  .word 0x46bf7b7d
  .word 0x75b6a478
  .word 0x5825ec51
  .word 0x86092e88
  .word 0x5bab8bb9
  .word 0x7bad32b0
  .word 0xc60f0b9c
  .word 0xfe8e517f
  .word 0xaec5a70e
  .word 0x8e1a6626
  .word 0xbf756065
  .word 0x7814d639
  .word 0x86094a67
  .word 0x13d1da9b
  .word 0x2811e808
  .word 0x4bcb69f0
  .word 0x1958d9ee
  .word 0x673176cc
  .word 0x8fb39cbc
  .word 0x78e95575
  .word 0xa9c34fa6
  .word 0xdd69b073
  .word 0x60647127
  .word 0xda8880b3
  .word 0x78d6c56d
  .word 0xc83607c7
  .word 0xa79cde99
  .word 0xd5de31f6
  .word 0xa07771f3
  .word 0xf0317e0a
  .word 0x7cace44a
  .word 0xfc3bfa5d
  .word 0x1cb2b083
  .word 0xd7fc726c
  .word 0x34eab8d7
  .word 0xb3d13e8c
  .word 0x88b8e8ea
  .word 0xd3e777b6
  .word 0xb7f90b56
  .word 0x9b9e789e
  .word 0x2e0a1054
  .word 0x6f1c04b3
  .word 0x4388d5bd
  .word 0x0ef2e99b
  .word 0x1274d63a
  .word 0xeeff1533
  .word 0xfc1c5508
  .word 0xeca648cf
  .word 0x4c6f4012
  .word 0x4ebc7de2
  .word 0x25775049
  .word 0xabc07652
  .word 0xea0a630e
  .word 0x02329da2
  .word 0x02dbbb45
  .word 0x00975005
  .word 0xe035d013

/* output buffer */
.balign 32
result:
.zero 512

/* buffer for Montgomery constant RR */
.balign 32
RR:
.zero 512

/* buffer for Montgomery constant m0inv */
.balign 32
m0inv:
.zero 32

/* needed to fit test in dmem */
.section .scratchpad

.balign 32
work_exp:
.zero 512

.balign 32
work_reduce:
.zero 512
