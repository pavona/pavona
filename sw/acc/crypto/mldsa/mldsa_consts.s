/* Copyright zeroRISC Inc. */
/* Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192). */
/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors. */
/* Modified by Ruben Niederhagen and Hoang Nguyen Hien Pham - authors of */
/* "Improving ML-KEM & ML-DSA on OpenTitan - Efficient Multiplication Vector Instructions for OTBN" */
/* (https://eprint.iacr.org/2025/2028). */
/* Copyright Ruben Niederhagen and Hoang Nguyen Hien Pham. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * Constants used by internal libraries for ML-DSA computations.
 */

#define Q 8380417

.data

/* Modulus for reduction */
.balign 32
.globl modulus
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
.globl montg_R
montg_R:
  .word 0xfc7fdfff
  .word 0xfc7fdfff
  .word 0xfc7fdfff
  .word 0xfc7fdfff
  .word 0xfc7fdfff
  .word 0xfc7fdfff
  .word 0xfc7fdfff
  .word 0xfc7fdfff

/* Hardened builds regenerate the twiddles into scratch at runtime (see
 * gen_twiddles.s), so the 1 KiB table is omitted. */
#ifndef HARDENED
.globl twiddles_fwd
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
#endif

.balign 32
.globl reduce32_const
reduce32_const:
  .word 0x1
  .word 0x1
  .word 0x1
  .word 0x1
  .word 0x1
  .word 0x1
  .word 0x1
  .word 0x1

/* Unused in hardened builds; poly_power2round uses the preprocessed form. */
#ifndef HARDENED
.balign 32
.globl power2round_D
power2round_D:
  .word 0xd
  .word 0xd
  .word 0xd
  .word 0xd
  .word 0xd
  .word 0xd
  .word 0xd
  .word 0xd
#endif

.balign 32
.globl power2round_D_preprocessed
power2round_D_preprocessed:
  .word 0xfff
  .word 0xfff
  .word 0xfff
  .word 0xfff
  .word 0xfff
  .word 0xfff
  .word 0xfff
  .word 0xfff

#ifndef HARDENED
.balign 32
.globl eta_2
eta_2:
  .word 2
  .word 2
  .word 2
  .word 2
  .word 2
  .word 2
  .word 2
  .word 2

.balign 32
.globl eta_4
eta_4:
  .word 4
  .word 4
  .word 4
  .word 4
  .word 4
  .word 4
  .word 4
  .word 4

#endif
.balign 32
.globl polyt0_pack_const
polyt0_pack_const:
  .word 0x1000
  .word 0x1000
  .word 0x1000
  .word 0x1000
  .word 0x1000
  .word 0x1000
  .word 0x1000
  .word 0x1000

.balign 32
.globl decompose_const_88
decompose_const_88:
  .word 0x00002c0b
  .word 0x00002c0b
  .word 0x00002c0b
  .word 0x00002c0b
  .word 0x00002c0b
  .word 0x00002c0b
  .word 0x00002c0b
  .word 0x00002c0b

.balign 32
.globl decompose_const_32
decompose_const_32:
  .word 1025
  .word 1025
  .word 1025
  .word 1025
  .word 1025
  .word 1025
  .word 1025
  .word 1025

/* In hardened builds polyz_pack/poly_use_hint use the runtime-broadcast
 * gamma1_vec_const/gamma2_vec_const; the per-K tables are aliased to those in
 * run_mldsa.s, so the static tables are omitted here. */
#ifndef HARDENED
.balign 32
.globl gamma1_vec_const_17
gamma1_vec_const_17:
  .word 131072
  .word 131072
  .word 131072
  .word 131072
  .word 131072
  .word 131072
  .word 131072
  .word 131072

.balign 32
.globl gamma1_vec_const_19
gamma1_vec_const_19:
  .word 524288
  .word 524288
  .word 524288
  .word 524288
  .word 524288
  .word 524288
  .word 524288
  .word 524288

.balign 32
.globl gamma2_vec_const_88
gamma2_vec_const_88:
  .word 95232
  .word 95232
  .word 95232
  .word 95232
  .word 95232
  .word 95232
  .word 95232
  .word 95232

.balign 32
.globl gamma2_vec_const_32
gamma2_vec_const_32:
  .word 261888
  .word 261888
  .word 261888
  .word 261888
  .word 261888
  .word 261888
  .word 261888
  .word 261888
#endif

.balign 32
.globl qm1half_const
qm1half_const:
  .word 0x003ff000
  .word 0x003ff000
  .word 0x003ff000
  .word 0x003ff000
  .word 0x003ff000
  .word 0x003ff000
  .word 0x003ff000
  .word 0x003ff000

.balign 32
.globl decompose_127_const
decompose_127_const:
  .word 0x0000007f
  .word 0x0000007f
  .word 0x0000007f
  .word 0x0000007f
  .word 0x0000007f
  .word 0x0000007f
  .word 0x0000007f
  .word 0x0000007f

.balign 32
.globl decompose_43_const_88
decompose_43_const_88:
  .word 0x0000002b
  .word 0x0000002b
  .word 0x0000002b
  .word 0x0000002b
  .word 0x0000002b
  .word 0x0000002b
  .word 0x0000002b
  .word 0x0000002b

.balign 32
.globl decompose_43_const_32
decompose_43_const_32:
  .word 0x000000f
  .word 0x000000f
  .word 0x000000f
  .word 0x000000f
  .word 0x000000f
  .word 0x000000f
  .word 0x000000f
  .word 0x000000f

#ifndef HARDENED
.balign 32
.globl polyeta_unpack_mask_eta_2
polyeta_unpack_mask_eta_2:
  .word 0x07
  .word 0x07
  .word 0x07
  .word 0x07
  .word 0x07
  .word 0x07
  .word 0x07
  .word 0x07

.balign 32
.globl polyeta_unpack_mask_eta_4
polyeta_unpack_mask_eta_4:
  .word 0x0f
  .word 0x0f
  .word 0x0f
  .word 0x0f
  .word 0x0f
  .word 0x0f
  .word 0x0f
  .word 0x0f

#endif
.balign 32
.globl polyt1_unpack_mask
polyt1_unpack_mask:
  .word 0x3ff
  .word 0x3ff
  .word 0x3ff
  .word 0x3ff
  .word 0x3ff
  .word 0x3ff
  .word 0x3ff
  .word 0x3ff

.balign 32
.globl polyt0_unpack_mask
polyt0_unpack_mask:
  .word 0x1fff
  .word 0x1fff
  .word 0x1fff
  .word 0x1fff
  .word 0x1fff
  .word 0x1fff
  .word 0x1fff
  .word 0x1fff

/* Aliased to polyz_unpack_mask in run_mldsa.s for hardened builds. */
#ifndef HARDENED
.balign 32
.globl polyz_unpack_mask_17
polyz_unpack_mask_17:
  .word 0x3ffff
  .word 0x3ffff
  .word 0x3ffff
  .word 0x3ffff
  .word 0x3ffff
  .word 0x3ffff
  .word 0x3ffff
  .word 0x3ffff

.balign 32
.globl polyz_unpack_mask_19
polyz_unpack_mask_19:
  .word 0xfffff
  .word 0xfffff
  .word 0xfffff
  .word 0xfffff
  .word 0xfffff
  .word 0xfffff
  .word 0xfffff
  .word 0xfffff
#endif

#ifndef HARDENED
.balign 32
.globl poly_uniform_eta_205
poly_uniform_eta_205:
  .word 205
  .word 205
  .word 205
  .word 205
  .word 205
  .word 205
  .word 205
  .word 205

.balign 32
.globl poly_uniform_eta_2
poly_uniform_eta_2:
  .word 2
  .word 2
  .word 2
  .word 2
  .word 2
  .word 2
  .word 2
  .word 2

.balign 32
.globl poly_uniform_eta_5
poly_uniform_eta_5:
  .word 5
  .word 5
  .word 5
  .word 5
  .word 5
  .word 5
  .word 5
  .word 5

#endif
.globl poly_wdr2gpr
poly_wdr2gpr:
  .zero 32

/* Mode-derived parameters. Caller (test harness or driver) writes the
   active mode's values here before calling any mldsa entry point.
   Layout (word offsets):
     0  K
     4  L
     8  TAU
    12  OMEGA
    16  GAMMA1 - BETA
    20  POLYW1_PACKEDBYTES
    24  CRYPTO_PUBLICKEYBYTES
    28  GAMMA2
    32  GAMMA2 - BETA
    36  SK_S2_OFFSET            (128 + L*POLYETA_PACKEDBYTES)
    40  SK_T0_OFFSET            (128 + (L+K)*POLYETA_PACKEDBYTES)
    44  CRYPTO_BYTES */
.balign 32
.globl mldsa_params
mldsa_params:
  .zero 64
