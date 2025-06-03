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
