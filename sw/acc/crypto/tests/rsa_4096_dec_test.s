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

  /* Load pointers to modulus and Montgomery constant buffers. */
  la    x16, modulus
  la    x17, m0inv
  la    x18, RR

  /* Compute Montgomery constants. */
  jal      x1, modload

  /* Run exponentiation.
       dmem[result] = dmem[base]^dmem[exp] mod dmem[modulus] */
  la       x14, base
  la       x15, exp
  la       x2, result
  jal      x1, modexp

  /* copy all limbs of result to wide reg file */
  la       x21, result
  li       x8, 0
  loop     x30, 2
    bn.lid   x8, 0(x21++)
    addi     x8, x8, 1

  ecall


.data

/* Modulus n =
0xf3996e63652a75f0725b950501740ed9e398870683326aa97e2a2e8d96f0e87a1ba4bf3406ee2cf0cf1360a2ce807db12629aa73810dfb406465915a65e6c5b28009296ff015a29f7144044cb676ba51c3bac7258913065f2febfe8267cdddb392f8f5595d8f771932c596e4a964f55b34d2b3cf68c60addc1dac2639449fa37810cd2d33c6de896ef7d6ecfcd9054e833755aad9c12af60835a87dfecfb0d9f02173be457ca39a1387dc42d8db8fa7a014308286c3fe5be029a746f6aca7dfe26d0e77eeb0f88d1e9e9c3f8f7c4c86dd4f7a6943991baf1215a8cf5ba4fccdee2f01b4ff6b9794c8198526e82aa531a0030d09974276367b7719df23c425511651b9a21a7ef5db5c3e7542ac27dc5f69bc9ddfcb0e83e64711dd948c9f2fef4ff4120370ce9d2eae9d350b4ef80e4cf5aaa8fe3316dd9f7f0c37f4c736f02beced35a01f55fdf0c15929f8f201bbbe5e5f588166e8292a4e4274618722d1b0aecd6e78aa7f1ae5b5126feaa9970f2684db6acab374d598195878b79c1cd7ec281790d213503e3b54f37a366cddcb3258a3b681d76f141b8e64da70d2e68680284201b29b71b327b891598d881421148b982041861fe92e89820247ca5137dbe9c70f2b29f91ba59f3e0cbb35a35dddd9cea58c48465654f6e79929e91cb6e6b0d7a527c33cc2cfcab32e1b18d54af644439614d586aadb9af8a67bf418eea2f
 */
.balign 32
modulus:
  .word 0x418eea2f
  .word 0xaf8a67bf
  .word 0x586aadb9
  .word 0x4439614d
  .word 0x8d54af64
  .word 0xab32e1b1
  .word 0x33cc2cfc
  .word 0x0d7a527c
  .word 0x91cb6e6b
  .word 0x6e79929e
  .word 0x8465654f
  .word 0x9cea58c4
  .word 0x5a35dddd
  .word 0xf3e0cbb3
  .word 0x9f91ba59
  .word 0x9c70f2b2
  .word 0xa5137dbe
  .word 0x9820247c
  .word 0x61fe92e8
  .word 0xb9820418
  .word 0x81421148
  .word 0x891598d8
  .word 0xb71b327b
  .word 0x84201b29
  .word 0x2e686802
  .word 0xe64da70d
  .word 0x76f141b8
  .word 0x8a3b681d
  .word 0xcddcb325
  .word 0x4f37a366
  .word 0x3503e3b5
  .word 0x81790d21
  .word 0xc1cd7ec2
  .word 0x95878b79
  .word 0x374d5981
  .word 0x4db6acab
  .word 0x9970f268
  .word 0x5126feaa
  .word 0xa7f1ae5b
  .word 0xecd6e78a
  .word 0x722d1b0a
  .word 0xe4274618
  .word 0x6e8292a4
  .word 0xe5f58816
  .word 0x201bbbe5
  .word 0x15929f8f
  .word 0xf55fdf0c
  .word 0xced35a01
  .word 0x736f02be
  .word 0xf0c37f4c
  .word 0x316dd9f7
  .word 0x5aaa8fe3
  .word 0xef80e4cf
  .word 0xe9d350b4
  .word 0x0ce9d2ea
  .word 0xff412037
  .word 0xc9f2fef4
  .word 0x711dd948
  .word 0xb0e83e64
  .word 0x9bc9ddfc
  .word 0xc27dc5f6
  .word 0xc3e7542a
  .word 0xa7ef5db5
  .word 0x651b9a21
  .word 0x3c425511
  .word 0xb7719df2
  .word 0x74276367
  .word 0x0030d099
  .word 0x82aa531a
  .word 0x8198526e
  .word 0xf6b9794c
  .word 0xe2f01b4f
  .word 0xba4fccde
  .word 0x215a8cf5
  .word 0x3991baf1
  .word 0xd4f7a694
  .word 0xf7c4c86d
  .word 0xe9e9c3f8
  .word 0xeb0f88d1
  .word 0x26d0e77e
  .word 0x6aca7dfe
  .word 0x029a746f
  .word 0x6c3fe5be
  .word 0x01430828
  .word 0x8db8fa7a
  .word 0x387dc42d
  .word 0x57ca39a1
  .word 0x02173be4
  .word 0xecfb0d9f
  .word 0x835a87df
  .word 0x9c12af60
  .word 0x33755aad
  .word 0xcd9054e8
  .word 0xef7d6ecf
  .word 0x3c6de896
  .word 0x810cd2d3
  .word 0x9449fa37
  .word 0xc1dac263
  .word 0x68c60add
  .word 0x34d2b3cf
  .word 0xa964f55b
  .word 0x32c596e4
  .word 0x5d8f7719
  .word 0x92f8f559
  .word 0x67cdddb3
  .word 0x2febfe82
  .word 0x8913065f
  .word 0xc3bac725
  .word 0xb676ba51
  .word 0x7144044c
  .word 0xf015a29f
  .word 0x8009296f
  .word 0x65e6c5b2
  .word 0x6465915a
  .word 0x810dfb40
  .word 0x2629aa73
  .word 0xce807db1
  .word 0xcf1360a2
  .word 0x06ee2cf0
  .word 0x1ba4bf34
  .word 0x96f0e87a
  .word 0x7e2a2e8d
  .word 0x83326aa9
  .word 0xe3988706
  .word 0x01740ed9
  .word 0x725b9505
  .word 0x652a75f0
  .word 0xf3996e63

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


/* Private exponent d =
0x38da5cdc9ece57a34c155ac4c5cf8fedc38424335d686563747a24ce4fe59ee46cd238fbcc08477dd65e87e5c77b4e9a8b351b3e84e6bdf68bd7f6a219f94fb7b6d12c961efaf5aeefb0f7adedc1ecff4b46aad6f45477debc61004ff029286e92453f81e167abdcba304a64c8b232df5c07370717c56ce0cfaf1e423e683b993ba9c204a1ec66e5df342faa19286fe097adf2816555291045e7d9a165fe3bf219fb51339c57aab6996824e29ada8abef1cf72b678793b45eaf6a069268be6f6eb9943062897420ff7df62a9172e9ab6a3873f1e0607a091497f083a0b873761e7a63141aaec23c6bad2519ed0292f66f8976bfffc8f7ad0488ca057da3f82f9ad45a280ded1169e4df1dff2c7c65fdaacfb60fab1803dc76e4ee8e502de258082a7e177fd47f65b099d2ef1206d4173f8902cac88fdb69af0798a7914b6c59cba5aa09c7360ff76eb7346d10ff05819727da06e495bf919fe5ac180993efe5911f97873f282b4cefde5f064bfd5feee8274d5f89b4048049eee7054d4a522f9b4e427ef7abd83c948b713c3028d255a8043a87e69d3688e74c206fb2840ede309d1ba8573e6a419654a5ee615764972f5898fb3f268b47671d9ad560d3ffc9eeaa3c44233efab15d550f8ceee9cbd188155e46cf7fd9f2b34b9449cf7c967cf1c528f464a2388b7d77304db97a54773c8dfdb16e36dbb7274980db35cda41a5
 */
.balign 32
exp:
  .word 0x5cda41a5
  .word 0x74980db3
  .word 0xe36dbb72
  .word 0xc8dfdb16
  .word 0x97a54773
  .word 0xd77304db
  .word 0x4a2388b7
  .word 0x1c528f46
  .word 0xf7c967cf
  .word 0x34b9449c
  .word 0xf7fd9f2b
  .word 0x8155e46c
  .word 0xee9cbd18
  .word 0xd550f8ce
  .word 0x33efab15
  .word 0xeaa3c442
  .word 0x0d3ffc9e
  .word 0x71d9ad56
  .word 0xf268b476
  .word 0xf5898fb3
  .word 0x15764972
  .word 0x654a5ee6
  .word 0x73e6a419
  .word 0x09d1ba85
  .word 0x2840ede3
  .word 0x74c206fb
  .word 0x69d3688e
  .word 0x8043a87e
  .word 0x028d255a
  .word 0x48b713c3
  .word 0x7abd83c9
  .word 0xb4e427ef
  .word 0xd4a522f9
  .word 0x9eee7054
  .word 0x9b404804
  .word 0x8274d5f8
  .word 0xbfd5feee
  .word 0xfde5f064
  .word 0xf282b4ce
  .word 0x11f97873
  .word 0x993efe59
  .word 0xfe5ac180
  .word 0x495bf919
  .word 0x727da06e
  .word 0x0ff05819
  .word 0xeb7346d1
  .word 0x7360ff76
  .word 0xba5aa09c
  .word 0x14b6c59c
  .word 0xf0798a79
  .word 0x88fdb69a
  .word 0xf8902cac
  .word 0x206d4173
  .word 0x099d2ef1
  .word 0xfd47f65b
  .word 0x82a7e177
  .word 0x02de2580
  .word 0x6e4ee8e5
  .word 0xb1803dc7
  .word 0xacfb60fa
  .word 0xc7c65fda
  .word 0x4df1dff2
  .word 0xded1169e
  .word 0xad45a280
  .word 0xda3f82f9
  .word 0x488ca057
  .word 0xfc8f7ad0
  .word 0xf8976bff
  .word 0xd0292f66
  .word 0xbad2519e
  .word 0xaaec23c6
  .word 0xe7a63141
  .word 0x0b873761
  .word 0x497f083a
  .word 0x0607a091
  .word 0xa3873f1e
  .word 0x172e9ab6
  .word 0xf7df62a9
  .word 0x2897420f
  .word 0xeb994306
  .word 0x268be6f6
  .word 0xeaf6a069
  .word 0x78793b45
  .word 0xf1cf72b6
  .word 0x9ada8abe
  .word 0x996824e2
  .word 0x9c57aab6
  .word 0x19fb5133
  .word 0x65fe3bf2
  .word 0x45e7d9a1
  .word 0x65552910
  .word 0x97adf281
  .word 0x19286fe0
  .word 0xdf342faa
  .word 0xa1ec66e5
  .word 0x3ba9c204
  .word 0x3e683b99
  .word 0xcfaf1e42
  .word 0x17c56ce0
  .word 0x5c073707
  .word 0xc8b232df
  .word 0xba304a64
  .word 0xe167abdc
  .word 0x92453f81
  .word 0xf029286e
  .word 0xbc61004f
  .word 0xf45477de
  .word 0x4b46aad6
  .word 0xedc1ecff
  .word 0xefb0f7ad
  .word 0x1efaf5ae
  .word 0xb6d12c96
  .word 0x19f94fb7
  .word 0x8bd7f6a2
  .word 0x84e6bdf6
  .word 0x8b351b3e
  .word 0xc77b4e9a
  .word 0xd65e87e5
  .word 0xcc08477d
  .word 0x6cd238fb
  .word 0x4fe59ee4
  .word 0x747a24ce
  .word 0x5d686563
  .word 0xc3842433
  .word 0xc5cf8fed
  .word 0x4c155ac4
  .word 0x9ece57a3
  .word 0x38da5cdc

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
