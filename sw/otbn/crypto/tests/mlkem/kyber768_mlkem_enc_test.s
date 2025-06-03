/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/*
 * Testwrapper for kyber_mlkem_enc
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

/* Modulus: KYBER_Q = 3329 */
.globl modulus
modulus:
  .word 0x00000d01
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000

.globl modulus_inv
modulus_inv:
  .word 0x00000cff
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000

.globl modulus_bn
modulus_bn:
  .word 0x0d010d01
  .word 0x0d010d01
  .word 0x0d010d01
  .word 0x0d010d01
  .word 0x0d010d01
  .word 0x0d010d01
  .word 0x0d010d01
  .word 0x0d010d01

.globl modulus_over_2
modulus_over_2:
  .word 0x06810681
  .word 0x06810681
  .word 0x06810681
  .word 0x06810681
  .word 0x06810681
  .word 0x06810681
  .word 0x06810681
  .word 0x06810681

.globl const_0x0fff
const_0x0fff:
  .word 0x0fff0fff
  .word 0x0fff0fff
  .word 0x0fff0fff
  .word 0x0fff0fff
  .word 0x0fff0fff
  .word 0x0fff0fff
  .word 0x0fff0fff
  .word 0x0fff0fff

.globl const_1290167
const_1290167:
  .word 0x0013afb7
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000

.globl const_8
const_8:
  .word 0x00080008
  .word 0x00080008
  .word 0x00080008
  .word 0x00080008
  .word 0x00080008
  .word 0x00080008
  .word 0x00080008
  .word 0x00080008
  
.globl const_tomont
const_tomont:
  .word 0x05490549 /* 2^32 % KYBER_Q */
  .word 0x05490549
  .word 0x05490549
  .word 0x05490549
  .word 0x05490549
  .word 0x05490549
  .word 0x05490549
  .word 0x05490549
  
.globl twiddles_ntt
twiddles_ntt:
    /* Layer 1--4 */ 
    .half 0x0a0b
    .half 0x0b9a
    .half 0x0714
    .half 0x05d5
    .half 0x058e
    .half 0x011f
    .half 0x00ca
    .half 0x0c56
    .half 0x026e
    .half 0x0629
    .half 0x00b6
    .half 0x03c2
    .half 0x084f
    .half 0x073f
    .half 0x05bc
    /* Padding */
    .half 0x0000
    /* Layer 5 */
    .word 0x023d023d
    .word 0x07d407d4
    .word 0x01080108
    .word 0x017f017f
    .word 0x09c409c4
    .word 0x05b205b2
    .word 0x06bf06bf
    .word 0x0c7f0c7f
    .word 0x0a580a58
    .word 0x03f903f9
    .word 0x02dc02dc
    .word 0x02600260
    .word 0x06fb06fb
    .word 0x019b019b
    .word 0x0c340c34
    .word 0x06de06de
    /* Layer 6 */
    .word 0x04c704c7
    .word 0x0ad90ad9
    .word 0x07f407f4
    .word 0x0be70be7
    .word 0x02040204
    .word 0x0bc10bc1
    .word 0x06af06af
    .word 0x007e007e
    .word 0x028c028c
    .word 0x03f703f7
    .word 0x05d305d3
    .word 0x06f906f9
    .word 0x0cf90cf9
    .word 0x0a670a67
    .word 0x08770877
    .word 0x05bd05bd
    .word 0x09ac09ac
    .word 0x0bf20bf2
    .word 0x006b006b
    .word 0x0c0a0c0a
    .word 0x0b730b73
    .word 0x071d071d
    .word 0x01c001c0
    .word 0x02a502a5
    .word 0x0ca70ca7
    .word 0x033e033e
    .word 0x07740774
    .word 0x094a094a
    .word 0x03c103c1
    .word 0x0a2c0a2c
    .word 0x08d808d8
    .word 0x08060806
    /* Layer 7 */
    .word 0x08b208b2
    .word 0x081e081e
    .word 0x01a601a6
    .word 0x0bde0bde
    .word 0x0c0b0c0b
    .word 0x09f809f8
    .word 0x06cb06cb
    .word 0x01a201a2
    .word 0x01ae01ae
    .word 0x03670367
    .word 0x024b024b
    .word 0x0b350b35
    .word 0x030a030a
    .word 0x05cb05cb
    .word 0x02840284
    .word 0x01490149
    .word 0x022b022b
    .word 0x060e060e
    .word 0x00b100b1
    .word 0x06260626
    .word 0x04870487
    .word 0x0aa70aa7
    .word 0x09990999
    .word 0x0c650c65
    .word 0x034b034b
    .word 0x00690069
    .word 0x0c160c16
    .word 0x06750675
    .word 0x0c6e0c6e
    .word 0x045f045f
    .word 0x015d015d
    .word 0x0cb60cb6
    .word 0x03310331
    .word 0x052a052a
    .word 0x08420842
    .word 0x09970997
    .word 0x08600860
    .word 0x071b071b
    .word 0x0c950c95
    .word 0x03be03be
    .word 0x04490449
    .word 0x07fc07fc
    .word 0x0c790c79
    .word 0x00dc00dc
    .word 0x07070707
    .word 0x09ab09ab
    .word 0x0bcd0bcd
    .word 0x074d074d
    .word 0x025b025b
    .word 0x07480748
    .word 0x04c204c2
    .word 0x085e085e
    .word 0x08030803
    .word 0x099b099b
    .word 0x03e403e4
    .word 0x05f205f2
    .word 0x02620262
    .word 0x01800180
    .word 0x07ca07ca
    .word 0x06860686
    .word 0x031a031a
    .word 0x01de01de
    .word 0x03df03df
    .word 0x065c065c

.globl twiddles_intt
twiddles_intt:
  /* Layer 7 */
  .word 0x06a506a5
  .word 0x09220922
  .word 0x0b230b23
  .word 0x09e709e7
  .word 0x067b067b
  .word 0x05370537
  .word 0x0b810b81
  .word 0x0a9f0a9f
  .word 0x070f070f
  .word 0x091d091d
  .word 0x03660366
  .word 0x04fe04fe
  .word 0x04a304a3
  .word 0x083f083f
  .word 0x05b905b9
  .word 0x0aa60aa6
  .word 0x05b405b4
  .word 0x01340134
  .word 0x03560356
  .word 0x05fa05fa
  .word 0x0c250c25
  .word 0x00880088
  .word 0x05050505
  .word 0x08b808b8
  .word 0x09430943
  .word 0x006c006c
  .word 0x05e605e6
  .word 0x04a104a1
  .word 0x036a036a
  .word 0x04bf04bf
  .word 0x07d707d7
  .word 0x09d009d0
  .word 0x004b004b
  .word 0x0ba40ba4
  .word 0x08a208a2
  .word 0x00930093
  .word 0x068c068c
  .word 0x00eb00eb
  .word 0x0c980c98
  .word 0x09b609b6
  .word 0x009c009c
  .word 0x03680368
  .word 0x025a025a
  .word 0x087a087a
  .word 0x06db06db
  .word 0x0c500c50
  .word 0x06f306f3
  .word 0x0ad60ad6
  .word 0x0bb80bb8
  .word 0x0a7d0a7d
  .word 0x07360736
  .word 0x09f709f7
  .word 0x01cc01cc
  .word 0x0ab60ab6
  .word 0x099a099a
  .word 0x0b530b53
  .word 0x0b5f0b5f
  .word 0x06360636
  .word 0x03090309
  .word 0x00f600f6
  .word 0x01230123
  .word 0x0b5b0b5b
  .word 0x04e304e3
  .word 0x044f044f
  /* Layer 6 */
  .word 0x04fb04fb
  .word 0x04290429
  .word 0x02d502d5
  .word 0x09400940
  .word 0x03b703b7
  .word 0x058d058d
  .word 0x09c309c3
  .word 0x005a005a
  .word 0x0a5c0a5c
  .word 0x0b410b41
  .word 0x05e405e4
  .word 0x018e018e
  .word 0x00f700f7
  .word 0x0c960c96
  .word 0x010f010f
  .word 0x03550355
  .word 0x07440744
  .word 0x048a048a
  .word 0x029a029a
  .word 0x00080008
  .word 0x06080608
  .word 0x072e072e
  .word 0x090a090a
  .word 0x0a750a75
  .word 0x0c830c83
  .word 0x06520652
  .word 0x01400140
  .word 0x0afd0afd
  .word 0x011a011a
  .word 0x050d050d
  .word 0x02280228
  .word 0x083a083a
  /* Layer 5 */
  .word 0x06230623
  .word 0x00cd00cd
  .word 0x0b660b66
  .word 0x06060606
  .word 0x0aa10aa1
  .word 0x0a250a25
  .word 0x09080908
  .word 0x02a902a9
  .word 0x00820082
  .word 0x06420642
  .word 0x074f074f
  .word 0x033d033d
  .word 0x0b820b82
  .word 0x0bf90bf9
  .word 0x052d052d
  .word 0x0ac40ac4
  /* Layer 4--2 */
  .half 0x0745
  .half 0x05c2
  .half 0x04b2
  .half 0x093f
  .half 0x0c4b
  .half 0x06d8
  .half 0x0a93
  .half 0x00ab
  .half 0x0c37
  .half 0x0be2
  .half 0x0773
  .half 0x072c
  .half 0x05ed
  .half 0x0167
  /* Layer 1 */
  .half 0x078c /* ((758*2^16) mod KYBER_Q)*(1/128) mod KYBER_Q */
  /* [(2^32 mod KYBER_Q)*(1/128)] mod KYBER_Q */
  .half 0x05a1

.globl twiddles_basemul
twiddles_basemul:
    .word 0x081e08b2
    .word 0x04e3044f
    .word 0x036701ae
    .word 0x099a0b53
    .word 0x060e022b
    .word 0x06f30ad6
    .word 0x0069034b
    .word 0x0c9809b6

    .word 0x0bde01a6
    .word 0x01230b5b
    .word 0x0b35024b
    .word 0x01cc0ab6
    .word 0x062600b1
    .word 0x06db0c50
    .word 0x06750c16
    .word 0x068c00eb

    .word 0x09f80c0b
    .word 0x030900f6
    .word 0x05cb030a
    .word 0x073609f7
    .word 0x0aa70487
    .word 0x025a087a
    .word 0x045f0c6e
    .word 0x08a20093

    .word 0x01a206cb
    .word 0x0b5f0636
    .word 0x01490284
    .word 0x0bb80a7d
    .word 0x0c650999
    .word 0x009c0368
    .word 0x0cb6015d
    .word 0x004b0ba4

    .word 0x052a0331
    .word 0x07d709d0
    .word 0x07fc0449
    .word 0x050508b8
    .word 0x0748025b
    .word 0x05b90aa6
    .word 0x01800262
    .word 0x0b810a9f

    .word 0x09970842
    .word 0x036a04bf
    .word 0x00dc0c79
    .word 0x0c250088
    .word 0x085e04c2
    .word 0x04a3083f
    .word 0x068607ca
    .word 0x067b0537

    .word 0x071b0860
    .word 0x05e604a1
    .word 0x09ab0707
    .word 0x035605fa
    .word 0x099b0803
    .word 0x036604fe
    .word 0x01de031a
    .word 0x0b2309e7

    .word 0x03be0c95
    .word 0x0943006c
    .word 0x074d0bcd
    .word 0x05b40134
    .word 0x05f203e4
    .word 0x070f091d
    .word 0x065c03df
    .word 0x06a50922
