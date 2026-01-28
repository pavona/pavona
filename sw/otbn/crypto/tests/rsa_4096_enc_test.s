/* Copyright lowRISC contributors (OpenTitan project). */
/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */


.section .text.start

/**
 * Standalone RSA-4096 modexp with e=65537 (encryption/verification).
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
  la       x2, result
  jal      x1, modexp_65537

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

/* Base for exponentiation (corresponds to plaintext for encryption or
   signature for verification).

   Raw hex value (randomly generated) =
0x9e67bf21cfb170bd70edb7b9ffb99fbfe6a681f9e17bc8a966bf55d54794b95f9c4ff3657f3eef86433035ec3cc1fd4c092498a59f3fb5ac0b29c1a7a429130509229a001a86f72182354886779211a3f38ae8b864d094f875cc30bfce8df4a999cd6e43ab25c786ebb4d78bd6f439b278937d6d092be28d986564faab071878f0b4982b70af87c2261a0fc4d58b4c5d227cd880b40af25828988a730746b711cd6aaeec67f07b40df881cc8b784f944f4dc9fccac096631baf8ec17201fbacab0f09cbd2e816495820f6a5d7263ab5dd72cee1c1145327e2696066b6103304206c29ace7f13d92b3a7edf3cb9dc3fe5d2da7c22d16319f2fcdf44a9cf14de57cc75f9395b0d1ebd90c107b74ca88d8c99be1e5a4a41d1fa2285ccd8580f4a6206fb4d0cae5945bcd33b5f1308025f660bf96e3e448216b02da98b86d8e9d633e311b2f19fce4dbaa6317d04aaf360ea9245bd0bb70811e64d87accf8ab6339b063ba26b085c85e369f37c2c62a485fab7f2b22edd5f4f6365c3e47fae372ea3e530796473835384e77187ac856b9ebbc3c10f1a0394e9a9c25a8e635a55ac907a011119aa5d00edc26f0b64e9972391ba545a03e003624e0624f824c22710237e8f97a07ffcff0106684f0c17b8df6f975bdd5f286a95f7635416b3e9129aa81e4cee9932dfe177f7f33897412fdde0e8b87f6cc0c54ab2c8f022dcb7fef768
 */
.balign 32
base:
  .word 0xb7fef768
  .word 0xc8f022dc
  .word 0xc0c54ab2
  .word 0xe8b87f6c
  .word 0x412fdde0
  .word 0xf7f33897
  .word 0x32dfe177
  .word 0x1e4cee99
  .word 0xe9129aa8
  .word 0x635416b3
  .word 0x286a95f7
  .word 0x975bdd5f
  .word 0x17b8df6f
  .word 0x06684f0c
  .word 0x7ffcff01
  .word 0x7e8f97a0
  .word 0xc2271023
  .word 0x0624f824
  .word 0xe003624e
  .word 0xba545a03
  .word 0xe9972391
  .word 0xc26f0b64
  .word 0xaa5d00ed
  .word 0x7a011119
  .word 0x5a55ac90
  .word 0xc25a8e63
  .word 0x0394e9a9
  .word 0xc3c10f1a
  .word 0x856b9ebb
  .word 0xe77187ac
  .word 0x73835384
  .word 0xe5307964
  .word 0xae372ea3
  .word 0x65c3e47f
  .word 0xdd5f4f63
  .word 0xb7f2b22e
  .word 0x62a485fa
  .word 0x69f37c2c
  .word 0x085c85e3
  .word 0x063ba26b
  .word 0x8ab6339b
  .word 0x4d87accf
  .word 0xb70811e6
  .word 0x9245bd0b
  .word 0xaaf360ea
  .word 0xa6317d04
  .word 0x9fce4dba
  .word 0xe311b2f1
  .word 0xd8e9d633
  .word 0x2da98b86
  .word 0x448216b0
  .word 0x0bf96e3e
  .word 0x08025f66
  .word 0xd33b5f13
  .word 0xae5945bc
  .word 0x06fb4d0c
  .word 0x580f4a62
  .word 0x2285ccd8
  .word 0x4a41d1fa
  .word 0x99be1e5a
  .word 0x4ca88d8c
  .word 0x90c107b7
  .word 0x5b0d1ebd
  .word 0xcc75f939
  .word 0xcf14de57
  .word 0xfcdf44a9
  .word 0xd16319f2
  .word 0xd2da7c22
  .word 0xb9dc3fe5
  .word 0x3a7edf3c
  .word 0x7f13d92b
  .word 0x06c29ace
  .word 0x61033042
  .word 0x2696066b
  .word 0x1145327e
  .word 0xd72cee1c
  .word 0x7263ab5d
  .word 0x820f6a5d
  .word 0x2e816495
  .word 0xb0f09cbd
  .word 0x201fbaca
  .word 0xbaf8ec17
  .word 0xac096631
  .word 0xf4dc9fcc
  .word 0xb784f944
  .word 0xdf881cc8
  .word 0x67f07b40
  .word 0xcd6aaeec
  .word 0x0746b711
  .word 0x28988a73
  .word 0xb40af258
  .word 0x227cd880
  .word 0xd58b4c5d
  .word 0x261a0fc4
  .word 0x70af87c2
  .word 0xf0b4982b
  .word 0xab071878
  .word 0x986564fa
  .word 0x092be28d
  .word 0x78937d6d
  .word 0xd6f439b2
  .word 0xebb4d78b
  .word 0xab25c786
  .word 0x99cd6e43
  .word 0xce8df4a9
  .word 0x75cc30bf
  .word 0x64d094f8
  .word 0xf38ae8b8
  .word 0x779211a3
  .word 0x82354886
  .word 0x1a86f721
  .word 0x09229a00
  .word 0xa4291305
  .word 0x0b29c1a7
  .word 0x9f3fb5ac
  .word 0x092498a5
  .word 0x3cc1fd4c
  .word 0x433035ec
  .word 0x7f3eef86
  .word 0x9c4ff365
  .word 0x4794b95f
  .word 0x66bf55d5
  .word 0xe17bc8a9
  .word 0xe6a681f9
  .word 0xffb99fbf
  .word 0x70edb7b9
  .word 0xcfb170bd
  .word 0x9e67bf21


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
