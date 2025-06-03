/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */


/**
 * Test for key_pair_dilithium
*/

.section .text.start
#define STACK_SIZE 112000

#define SEEDBYTES 32
#define CRHBYTES 64
#define TRBYTES 64
#define RNDBYTES 32
#define N 256
#define Q 8380417
#define D 13
#define ROOT_OF_UNITY 1753

#if DILITHIUM_MODE == 2
#define K 4
#define L 4
#define ETA 2
#define TAU 39
#define BETA 78
#define GAMMA1 131072
#define GAMMA2 95232
#define OMEGA 80
#define CTILDEBYTES 32

#define POLYVECK_BYTES 4096
#define POLYVECL_BYTES 4096

#define CRYPTO_PUBLICKEYBYTES 1312
#define CRYPTO_SECRETKEYBYTES 2560
#define CRYPTO_BYTES 2420

#elif DILITHIUM_MODE == 3
#define K 6
#define L 5
#define ETA 4
#define TAU 49
#define BETA 196
#define GAMMA1 524288
#define GAMMA2 261888
#define OMEGA 55
#define CTILDEBYTES 48

#define POLYVECK_BYTES 6144
#define POLYVECL_BYTES 5120

#define CRYPTO_PUBLICKEYBYTES 1952
#define CRYPTO_SECRETKEYBYTES 4032
#define CRYPTO_BYTES 3309

#elif DILITHIUM_MODE == 5
#define K 8
#define L 7
#define ETA 2
#define TAU 60
#define BETA 120
#define GAMMA1 524288
#define GAMMA2 261888
#define OMEGA 75
#define CTILDEBYTES 64

#define POLYVECK_BYTES 8192
#define POLYVECL_BYTES 7168

#define CRYPTO_PUBLICKEYBYTES 2592
#define CRYPTO_SECRETKEYBYTES 4896
#define CRYPTO_BYTES 4627

#endif

#define POLYT1_PACKEDBYTES  320
#define POLYT0_PACKEDBYTES  416
#define POLYVECH_PACKEDBYTES (OMEGA + K)

#if GAMMA1 == (1 << 17)
#define POLYZ_PACKEDBYTES   576
#elif GAMMA1 == (1 << 19)
#define POLYZ_PACKEDBYTES   640
#endif

#if GAMMA2 == (Q-1)/88
#define POLYW1_PACKEDBYTES  192
#elif GAMMA2 == (Q-1)/32
#define POLYW1_PACKEDBYTES  128
#endif

#if ETA == 2
#define POLYETA_PACKEDBYTES  96
#elif ETA == 4
#define POLYETA_PACKEDBYTES 128
#endif

/* Entry point. */
.globl main
main:
  /* Init all-zero register. */
  bn.xor  w31, w31, w31
  
  /* MOD <= dmem[modulus] = DILITHIUM_Q */
  li      x5, 2
  la      x6, modulus
  bn.lid  x5, 0(x6)

  /* MOD 2nd word <= DILITHIUM_R */
  li      x5, 3
  la      x6, montg_R
  bn.lid  x5, 0(x6)
  bn.rshi w2, w3, w2 >> 224
  /* Write back MOD */
  bn.wsrw 0x0, w2

  /* Loadf stack address */
  la  x2, stack_end
  la  x10, zeta
  la  x11, pk
  la  x12, sk
  jal x1, key_pair_dilithium

  ecall

.data
.balign 32
.global stack
stack:
    .zero STACK_SIZE
stack_end:
.globl pk
pk:
  .zero CRYPTO_PUBLICKEYBYTES
.globl sk
sk:
  .zero CRYPTO_SECRETKEYBYTES

.balign 32
.globl zeta
zeta:
  .word 0xa42b9c7f
  .word 0x7d828fe8
  .word 0x50456061
  .word 0x3e850576
  .word 0x93803bd7
  .word 0x88bceff6
  .word 0xac6e1aeb
  .word 0x26ef66fa

.balign 32
/* Modulus for reduction */
.global modulus
modulus:
  .word 0x007fe001
  .word 0x007fe001
  .word 0x007fe001
  .word 0x007fe001
  .word 0x007fe001
  .word 0x007fe001
  .word 0x007fe001
  .word 0x007fe001
/* R for Montgomery multiplication */
.global montg_R
montg_R:
  .word 0xfc7fdfff
  .word 0xfc7fdfff
  .word 0xfc7fdfff
  .word 0xfc7fdfff
  .word 0xfc7fdfff
  .word 0xfc7fdfff
  .word 0xfc7fdfff
  .word 0xfc7fdfff
.global twiddles_fwd
twiddles_fwd:
  /* Layers 1-4 */
  .word 0x000064f7
  .word 0x00581103
  .word 0x0077f504
  .word 0x00039e44
  .word 0x00740119
  .word 0x00728129
  .word 0x00071e24
  .word 0x001bde2b
  .word 0x0023e92b
  .word 0x007a64ae
  .word 0x005ff480
  .word 0x002f9a75
  .word 0x0053db0a
  .word 0x002f7a49
  .word 0x0028e527
  /* Padding */
  .word 0x00000000
  /* Layer 5 - 1*/
  .word 0x00299658
  .word 0x000fa070
  .word 0x006f65a5
  .word 0x0036b788
  .word 0x00777d91
  .word 0x006ecaa1
  .word 0x0027f968
  .word 0x005fb37c
  /* Layer 6 - 1 */
  .word 0x00294a67
  .word 0x00017620
  .word 0x002ef4cd
  .word 0x0035dec5
  .word 0x00668504
  .word 0x0049102d
  .word 0x005927d5
  .word 0x003bbeaf
  .word 0x0044f586
  .word 0x00516e7d
  .word 0x00368a96
  .word 0x00541e42
  .word 0x00360400
  .word 0x007b4a4e
  .word 0x0023d69c
  .word 0x0077a55e
  /* Layer 7 - 1 */
  .word 0x0043e6e6
  .word 0x0047c1d0
  .word 0x0069b65e
  .word 0x002135c7
  .word 0x006caf76
  .word 0x00419073
  .word 0x004f3281
  .word 0x004870e1
  .word 0x00688c82
  .word 0x0051781a
  .word 0x003509ee
  .word 0x0067afbc
  .word 0x001d9772
  .word 0x00709cf7
  .word 0x004fb2af
  .word 0x0001efca
  .word 0x003410f2
  .word 0x0020c638
  .word 0x005297a4
  .word 0x00799a6e
  .word 0x0075a283
  .word 0x007f863c
  .word 0x007a0bde
  .word 0x001c4563
  .word 0x0070de86
  .word 0x00296e9f
  .word 0x0047844c
  .word 0x005a140a
  .word 0x006d2114
  .word 0x006be9f8
  .word 0x001495d4
  .word 0x006a0c63
  /* Layer 8 - 1 */
  .word 0x001fea93
  .word 0x004cdf73
  .word 0x000412f5
  .word 0x004a28a1
  .word 0x000dbe5e
  .word 0x00078f83
  .word 0x0075e022
  .word 0x0049997e
  .word 0x0033ff5a
  .word 0x00223dfb
  .word 0x00252587
  .word 0x004682fd
  .word 0x001c5e1a
  .word 0x0067428b
  .word 0x00503af7
  .word 0x0077dcd7
  .word 0x002358d4
  .word 0x005a8ba0
  .word 0x006d04f1
  .word 0x006d9b57
  .word 0x000de0e6
  .word 0x007f3705
  .word 0x001f0084
  .word 0x00742593
  .word 0x003a41f8
  .word 0x00498423
  .word 0x00359b5d
  .word 0x004f25df
  .word 0x000c7f5a
  .word 0x0077e6fd
  .word 0x0030ef86
  .word 0x004901c3
  .word 0x00053919
  .word 0x003472e7
  .word 0x002b5ee5
  .word 0x003de11c
  .word 0x00466519
  .word 0x0052308a
  .word 0x006b88bf
  .word 0x0078fde5
  .word 0x0004610c
  .word 0x004ce03c
  .word 0x00291199
  .word 0x00130984
  .word 0x001314be
  .word 0x001c853f
  .word 0x0012e11b
  .word 0x001406c7
  .word 0x005aad42
  .word 0x001a7cc7
  .word 0x00585a3b
  .word 0x0025f051
  .word 0x00283891
  .word 0x001d0b4b
  .word 0x004d3e3f
  .word 0x00327283
  .word 0x003eb01b
  .word 0x00031924
  .word 0x00134d71
  .word 0x00185a46
  .word 0x0049bb91
  .word 0x006fd6a7
  .word 0x006a0d30
  .word 0x0061ed6f
  /* Layer 5 - 2*/
  .word 0x005f8dd7
  .word 0x0044fae8
  .word 0x006a84f8
  .word 0x004ddc99
  .word 0x001ad035
  .word 0x007f9423
  .word 0x003d3201
  .word 0x000445c5
  /* Layer 6 - 2 */
  .word 0x0065f23e
  .word 0x0066cad7
  .word 0x00357e1e
  .word 0x00458f5a
  .word 0x0035843f
  .word 0x005f3618
  .word 0x0067745d
  .word 0x0038738c
  .word 0x000c63a8
  .word 0x00081b9a
  .word 0x000e8f76
  .word 0x003b3853
  .word 0x003b8534
  .word 0x0058dc31
  .word 0x001f9d54
  .word 0x00552f2e
  /* Layer 7 - 2 */
  .word 0x004cdbea
  .word 0x0007c417
  .word 0x0000ad00
  .word 0x000dcd44
  .word 0x00470bcb
  .word 0x00193948
  .word 0x0024756c
  .word 0x000b98a1
  .word 0x00040af0
  .word 0x002f4588
  .word 0x006f16bf
  .word 0x003c675a
  .word 0x007fbe7f
  .word 0x004e49c1
  .word 0x007ca7e0
  .word 0x006bc809
  .word 0x0002e46c
  .word 0x003036c2
  .word 0x005b1c94
  .word 0x00141305
  .word 0x00139e25
  .word 0x00737945
  .word 0x0051cea3
  .word 0x00488058
  .word 0x0049a809
  .word 0x00639ff7
  .word 0x007d2ae1
  .word 0x00147792
  .word 0x0067b0e1
  .word 0x0069e803
  .word 0x0044a79d
  .word 0x003a97d9
  /* Layer 8 - 2 */
  .word 0x006c5954
  .word 0x0016e405
  .word 0x00779935
  .word 0x0058711c
  .word 0x00612659
  .word 0x001ddd98
  .word 0x004f4cbf
  .word 0x000c5ca5
  .word 0x001d4099
  .word 0x000bdbe7
  .word 0x0054aa0d
  .word 0x00470c13
  .word 0x00251d8b
  .word 0x00336898
  .word 0x00027c1c
  .word 0x0019379a
  .word 0x00590579
  .word 0x00221de8
  .word 0x00665ff9
  .word 0x000910d8
  .word 0x002573b7
  .word 0x0002d4bb
  .word 0x0018aa08
  .word 0x00478168
  .word 0x006ae5ae
  .word 0x0033f8cf
  .word 0x0063b158
  .word 0x00463e20
  .word 0x007d5c90
  .word 0x006d73a8
  .word 0x002dfd71
  .word 0x00646c3e
  .word 0x0051813d
  .word 0x0021c4f7
  .word 0x00795d46
  .word 0x00666e99
  .word 0x00530765
  .word 0x0002cc93
  .word 0x00776a51
  .word 0x003c15ca
  .word 0x0035c539
  .word 0x0070fbf5
  .word 0x001a4cd0
  .word 0x006f0634
  .word 0x005dc1b0
  .word 0x0070f806
  .word 0x003bcf2c
  .word 0x00155e68
  .word 0x003b0115
  .word 0x001a35e7
  .word 0x00645caf
  .word 0x007be5db
  .word 0x007973de
  .word 0x00189c2a
  .word 0x007f234f
  .word 0x0072f6b7
  .word 0x00041dc0
  .word 0x0007340e
  .word 0x001d2668
  .word 0x00455fdc
  .word 0x005cfd0a
  .word 0x0049c5aa
  .word 0x006b16e0
  .word 0x001e29ce

.global twiddles_inv
twiddles_inv:
 /* Layer 8 - 1 */
    .word 0x0061b633
    .word 0x0014c921
    .word 0x00361a57
    .word 0x0022e2f7
    .word 0x003a8025
    .word 0x0062b999
    .word 0x0078abf3
    .word 0x007bc241
    .word 0x000ce94a
    .word 0x0000bcb2
    .word 0x006743d7
    .word 0x00066c23
    .word 0x0003fa26
    .word 0x001b8352
    .word 0x0065aa1a
    .word 0x0044deec
    .word 0x006a8199
    .word 0x004410d5
    .word 0x000ee7fb
    .word 0x00221e51
    .word 0x0010d9cd
    .word 0x00659331
    .word 0x000ee40c
    .word 0x004a1ac8
    .word 0x0043ca37
    .word 0x000875b0
    .word 0x007d136e
    .word 0x002cd89c
    .word 0x00197168
    .word 0x000682bb
    .word 0x005e1b0a
    .word 0x002e5ec4
    .word 0x001b73c3
    .word 0x0051e290
    .word 0x00126c59
    .word 0x00028371
    .word 0x0039a1e1
    .word 0x001c2ea9
    .word 0x004be732
    .word 0x0014fa53
    .word 0x00385e99
    .word 0x006735f9
    .word 0x007d0b46
    .word 0x005a6c4a
    .word 0x0076cf29
    .word 0x00198008
    .word 0x005dc219
    .word 0x0026da88
    .word 0x0066a867
    .word 0x007d63e5
    .word 0x004c7769
    .word 0x005ac276
    .word 0x0038d3ee
    .word 0x002b35f4
    .word 0x0074041a
    .word 0x00629f68
    .word 0x0073835c
    .word 0x00309342
    .word 0x00620269
    .word 0x001eb9a8
    .word 0x00276ee5
    .word 0x000846cc
    .word 0x0068fbfc
    .word 0x001386ad
    /* Layer 7 - 1 */
    .word 0x00454828
    .word 0x003b3864
    .word 0x0015f7fe
    .word 0x00182f20
    .word 0x006b686f
    .word 0x0002b520
    .word 0x001c400a
    .word 0x003637f8
    .word 0x00375fa9
    .word 0x002e115e
    .word 0x000c66bc
    .word 0x006c41dc
    .word 0x006bccfc
    .word 0x0024c36d
    .word 0x004fa93f
    .word 0x007cfb95
    .word 0x001417f8
    .word 0x00033821
    .word 0x00319640
    .word 0x00002182
    .word 0x004378a7
    .word 0x0010c942
    .word 0x00509a79
    .word 0x007bd511
    .word 0x00744760
    .word 0x005b6a95
    .word 0x0066a6b9
    .word 0x0038d436
    .word 0x007212bd
    .word 0x007f3301
    .word 0x00781bea
    .word 0x00330417
    /* Layer 6 - 1 */
    .word 0x002ab0d3
    .word 0x006042ad
    .word 0x002703d0
    .word 0x00445acd
    .word 0x0044a7ae
    .word 0x0071508b
    .word 0x0077c467
    .word 0x00737c59
    .word 0x00476c75
    .word 0x00186ba4
    .word 0x0020a9e9
    .word 0x004a5bc2
    .word 0x003a50a7
    .word 0x004a61e3
    .word 0x0019152a
    .word 0x0019edc3
    /* Layer 5 - 1 */
    .word 0x007b9a3c
    .word 0x0042ae00
    .word 0x00004bde
    .word 0x00650fcc
    .word 0x00320368
    .word 0x00155b09
    .word 0x003ae519
    .word 0x0020522a
    /* Layer 8 - 2 */
    .word 0x001df292
    .word 0x0015d2d1
    .word 0x0010095a
    .word 0x00362470
    .word 0x006785bb
    .word 0x006c9290
    .word 0x007cc6dd
    .word 0x00412fe6
    .word 0x004d6d7e
    .word 0x0032a1c2
    .word 0x0062d4b6
    .word 0x0057a770
    .word 0x0059efb0
    .word 0x002785c6
    .word 0x0065633a
    .word 0x002532bf
    .word 0x006bd93a
    .word 0x006cfee6
    .word 0x00635ac2
    .word 0x006ccb43
    .word 0x006cd67d
    .word 0x0056ce68
    .word 0x0032ffc5
    .word 0x007b7ef5
    .word 0x0006e21c
    .word 0x00145742
    .word 0x002daf77
    .word 0x00397ae8
    .word 0x0041fee5
    .word 0x0054811c
    .word 0x004b6d1a
    .word 0x007aa6e8
    .word 0x0036de3e
    .word 0x004ef07b
    .word 0x0007f904
    .word 0x007360a7
    .word 0x0030ba22
    .word 0x004a44a4
    .word 0x00365bde
    .word 0x00459e09
    .word 0x000bba6e
    .word 0x0060df7d
    .word 0x0000a8fc
    .word 0x0071ff1b
    .word 0x001244aa
    .word 0x0012db10
    .word 0x00255461
    .word 0x005c872d
    .word 0x0008032a
    .word 0x002fa50a
    .word 0x00189d76
    .word 0x006381e7
    .word 0x00395d04
    .word 0x005aba7a
    .word 0x005da206
    .word 0x004be0a7
    .word 0x00364683
    .word 0x0009ffdf
    .word 0x0078507e
    .word 0x007221a3
    .word 0x0035b760
    .word 0x007bcd0c
    .word 0x0033008e
    .word 0x005ff56e
    /* Layer 7 - 2 */
    .word 0x0015d39e
    .word 0x006b4a2d
    .word 0x0013f609
    .word 0x0012beed
    .word 0x0025cbf7
    .word 0x00385bb5
    .word 0x00567162
    .word 0x000f017b
    .word 0x00639a9e
    .word 0x0005d423
    .word 0x000059c5
    .word 0x000a3d7e
    .word 0x00064593
    .word 0x002d485d
    .word 0x005f19c9
    .word 0x004bcf0f
    .word 0x007df037
    .word 0x00302d52
    .word 0x000f430a
    .word 0x0062488f
    .word 0x00183045
    .word 0x004ad613
    .word 0x002e67e7
    .word 0x0017537f
    .word 0x00376f20
    .word 0x0030ad80
    .word 0x003e4f8e
    .word 0x0013308b
    .word 0x005eaa3a
    .word 0x001629a3
    .word 0x00381e31
    .word 0x003bf91b
    /* Layer 6 - 2 */
    .word 0x00083aa3
    .word 0x005c0965
    .word 0x000495b3
    .word 0x0049dc01
    .word 0x002bc1bf
    .word 0x0049556b
    .word 0x002e7184
    .word 0x003aea7b
    .word 0x00442152
    .word 0x0026b82c
    .word 0x0036cfd4
    .word 0x00195afd
    .word 0x004a013c
    .word 0x0050eb34
    .word 0x007e69e1
    .word 0x0056959a
    /* Layer 5 - 2 */
    .word 0x00202c85
    .word 0x0057e699
    .word 0x00111560
    .word 0x00086270
    .word 0x00492879
    .word 0x00107a5c
    .word 0x00703f91
    .word 0x005649a9
    /* Layer 1--4 */
    .word 0x0056fada
    .word 0x005065b8
    .word 0x002c04f7
    .word 0x0050458c
    .word 0x001feb81
    .word 0x00057b53
    .word 0x005bf6d6
    .word 0x006401d6
    .word 0x0078c1dd
    .word 0x000d5ed8
    .word 0x000bdee8
    .word 0x007c41bd
    .word 0x0007eafd
    .word 0x0027cefe
    /* including ninv */
    .word 0x003caa21
    /* ninv */
    .word 0x0000a3fa

.global reduce32_const
reduce32_const:
    .word 0x1
    .word 0x1
    .word 0x1
    .word 0x1
    .word 0x1
    .word 0x1
    .word 0x1
    .word 0x1

.global power2round_D
power2round_D:
    .word 0xd
    .word 0xd
    .word 0xd
    .word 0xd
    .word 0xd
    .word 0xd
    .word 0xd
    .word 0xd
.global power2round_D_preprocessed
power2round_D_preprocessed:
    .word 0xfff
    .word 0xfff
    .word 0xfff
    .word 0xfff
    .word 0xfff
    .word 0xfff
    .word 0xfff
    .word 0xfff
.global eta
eta:
    .word ETA
    .word ETA
    .word ETA
    .word ETA
    .word ETA
    .word ETA
    .word ETA
    .word ETA
.global polyt0_pack_const
polyt0_pack_const:
    .word 0x1000
    .word 0x1000
    .word 0x1000
    .word 0x1000
    .word 0x1000
    .word 0x1000
    .word 0x1000
    .word 0x1000
.global decompose_const
decompose_const:
    .word 0x00002c0b
    .word 0x00002c0b
    .word 0x00002c0b
    .word 0x00002c0b
    .word 0x00002c0b
    .word 0x00002c0b
    .word 0x00002c0b
    .word 0x00002c0b
.global gamma1_vec_const
gamma1_vec_const:
    .word 0x00020000
    .word 0x00020000
    .word 0x00020000
    .word 0x00020000
    .word 0x00020000
    .word 0x00020000
    .word 0x00020000
    .word 0x00020000
.global gamma2_vec_const
gamma2_vec_const:
    .word 0x00017400
    .word 0x00017400
    .word 0x00017400
    .word 0x00017400
    .word 0x00017400
    .word 0x00017400
    .word 0x00017400
    .word 0x00017400
.global qm1half_const
qm1half_const:
    .word 0x003ff000
    .word 0x003ff000
    .word 0x003ff000
    .word 0x003ff000
    .word 0x003ff000
    .word 0x003ff000
    .word 0x003ff000
    .word 0x003ff000
.global decompose_127_const
decompose_127_const:
    .word 0x0000007f
    .word 0x0000007f
    .word 0x0000007f
    .word 0x0000007f
    .word 0x0000007f
    .word 0x0000007f
    .word 0x0000007f
    .word 0x0000007f
.global decompose_43_const
decompose_43_const:
    .word 0x0000002b
    .word 0x0000002b
    .word 0x0000002b
    .word 0x0000002b
    .word 0x0000002b
    .word 0x0000002b
    .word 0x0000002b
    .word 0x0000002b
.global polyeta_unpack_mask
polyeta_unpack_mask:
    .word 0x07
    .word 0x07
    .word 0x07
    .word 0x07
    .word 0x07
    .word 0x07
    .word 0x07
    .word 0x07
.global polyt1_unpack_dilithium_mask
polyt1_unpack_dilithium_mask:
    .word 0x3ff
    .word 0x3ff
    .word 0x3ff
    .word 0x3ff
    .word 0x3ff
    .word 0x3ff
    .word 0x3ff
    .word 0x3ff
.global polyt0_unpack_dilithium_mask
polyt0_unpack_dilithium_mask:
    .word 0x1fff
    .word 0x1fff
    .word 0x1fff
    .word 0x1fff
    .word 0x1fff
    .word 0x1fff
    .word 0x1fff
    .word 0x1fff
.global polyz_unpack_dilithium_mask
polyz_unpack_dilithium_mask:
    .word 0x3ffff
    .word 0x3ffff
    .word 0x3ffff
    .word 0x3ffff
    .word 0x3ffff
    .word 0x3ffff
    .word 0x3ffff
    .word 0x3ffff
.global poly_uniform_eta_205
poly_uniform_eta_205:
    .word 205
    .word 205
    .word 205
    .word 205
    .word 205
    .word 205
    .word 205
    .word 205
.global poly_uniform_eta_5
poly_uniform_eta_5:
    .word 5
    .word 5
    .word 5
    .word 5
    .word 5
    .word 5
    .word 5
    .word 5
