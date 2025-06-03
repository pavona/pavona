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
