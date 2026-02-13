/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.section .text.start

/**
 * Standalone RSA-2048 modexp with secret exponent (decryption/signing).
 */
main:
  /* Init all-zero register. */
  bn.xor  w31, w31, w31

  /* Load number of limbs. */
  li    x30, 8

  /* Load pointers to cofactor and Montgomery constant buffers. */
  la    x17, m0inv
  la    x18, RR
  la    x27, modulus_p
  la    x28, modulus_q

  /* Run exponentiation.
       dmem[plaintext] = dmem[ciphertext]^<exp> mod <modulus>
       where
         <exp> mod p = exp_p
         <exp> mod q = exp_q
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
    addi     x8, x8, 1

  ecall


.data

/* Modulus n =

0xb5ed720fe7e1b4a65494e8e9421df94910811d23854cb07b08a34508b682b188b16fa70e4804b4c4f54a54ae2a10848abc9253ac7c6085e5b9abcbcd48515db1626b01df4e7f5f1c85b9ce1b4c8d0f77f3854c8bc4f350ad4d993a6815d0d62ac83b47a257adb40023e1acf003d27953f19c5cbede1af58e42ef12ad9907c20ca428f8b7dbb6f3434936b1108d17ee343d7127f8885ff2513eb834c17bf1c4ddec0d61cc26f5f683c10c0e48676608811e9341f2898f690bc9fafd3b7e46d375e2178a141faf0d637767da550de4c5b9939af133ceba7cd2734df4ad269c166180afd8c35060de8ac302ca911aa3f92d139ed1595523a7f6c201cfafed4c17b5
 */
.balign 32
modulus_p:
  .word 0xa6408193
  .word 0xba2cfd48
  .word 0xc1dc6a22
  .word 0xe7b8a6fd
  .word 0x1a9734c5
  .word 0x8bae4a82
  .word 0xf3bfc268
  .word 0xe735042b
  .word 0x4bc0ac83
  .word 0xfca80d97
  .word 0x9d208fd5
  .word 0x42caeee7
  .word 0x14ab2bd8
  .word 0x28373c20
  .word 0xe0d47260
  .word 0x906aa10b
  .word 0x105b1b33
  .word 0x2ab138d0
  .word 0xe4c1cf3b
  .word 0x53310add
  .word 0xcf585ca9
  .word 0x4fbe02a8
  .word 0x4b0d9ce0
  .word 0xa2710e34
  .word 0xa22e30f3
  .word 0xb97de915
  .word 0xd75f04fa
  .word 0x47285bff
  .word 0x40c10f61
  .word 0x5594f184
  .word 0x283dfe50
  .word 0xef9ed6be

.balign 32
modulus_q:
  .word 0x69b3ee97
  .word 0xe3daa4a2
  .word 0xa1e33da5
  .word 0xe540d9ec
  .word 0x7684fa8d
  .word 0x7c178d4e
  .word 0x1499c190
  .word 0x6b03d0d8
  .word 0x05632c00
  .word 0x8f082731
  .word 0x563f9100
  .word 0x8bf15b58
  .word 0x0e52b0ef
  .word 0x9dc84173
  .word 0xd8fea794
  .word 0x0106ab13
  .word 0x63b01d5b
  .word 0x64eb0549
  .word 0xdda2dd79
  .word 0x8d03e5a5
  .word 0x36c83167
  .word 0x453db5a0
  .word 0x8aa9707a
  .word 0xfb3afd94
  .word 0x65d68789
  .word 0xcfd454ae
  .word 0x581b4a37
  .word 0x013f0fba
  .word 0x33007706
  .word 0x2784a089
  .word 0xb53d9b76
  .word 0xc25d0713

/* Base for exponentiation (corresponds to ciphertext for decryption or
   message for signing).

   Raw hex value =
0x95fb986cd4aeee4b013effc1d183670380a9e2133ecc6a38dbbfff3f8ef20e1923a5e3741eac8772ee80f28994968fcabd6d454b7791263872bc68d97b6f4fbb76cee24f205d812ad36f2fcb6c11145943009a051c39c18c45b53ee19e51df0254b31eb991783718fb35c51dec249956bceb0276eaee88d8ecdeae2c08ac62a0018408af3923206e911a7ecf6ad786255fa69d63d333e6f44ebd3f5e6ebb7c82443c694d913e200492c89f046943f2dc7d8cf9951c6a33fa721558d1956fb552349ded082714be6a8bff775fd05162744d229fc9fac72509476bdc6434e5187bf3a1cc426cc13f0a10dcf0d15f28abcecfe5674782f232464b1a890d42b6fdd0
 */
.balign 32
base:
  .word 0x42b6fdd0
  .word 0x4b1a890d
  .word 0x82f23246
  .word 0xcfe56747
  .word 0x5f28abce
  .word 0x10dcf0d1
  .word 0x6cc13f0a
  .word 0xf3a1cc42
  .word 0x34e5187b
  .word 0x476bdc64
  .word 0xfac72509
  .word 0x4d229fc9
  .word 0xd0516274
  .word 0x8bff775f
  .word 0x2714be6a
  .word 0x349ded08
  .word 0x956fb552
  .word 0x721558d1
  .word 0x1c6a33fa
  .word 0x7d8cf995
  .word 0x6943f2dc
  .word 0x92c89f04
  .word 0x913e2004
  .word 0x443c694d
  .word 0x6ebb7c82
  .word 0x4ebd3f5e
  .word 0xd333e6f4
  .word 0x5fa69d63
  .word 0x6ad78625
  .word 0x911a7ecf
  .word 0x3923206e
  .word 0x018408af
  .word 0x08ac62a0
  .word 0xecdeae2c
  .word 0xeaee88d8
  .word 0xbceb0276
  .word 0xec249956
  .word 0xfb35c51d
  .word 0x91783718
  .word 0x54b31eb9
  .word 0x9e51df02
  .word 0x45b53ee1
  .word 0x1c39c18c
  .word 0x43009a05
  .word 0x6c111459
  .word 0xd36f2fcb
  .word 0x205d812a
  .word 0x76cee24f
  .word 0x7b6f4fbb
  .word 0x72bc68d9
  .word 0x77912638
  .word 0xbd6d454b
  .word 0x94968fca
  .word 0xee80f289
  .word 0x1eac8772
  .word 0x23a5e374
  .word 0x8ef20e19
  .word 0xdbbfff3f
  .word 0x3ecc6a38
  .word 0x80a9e213
  .word 0xd1836703
  .word 0x013effc1
  .word 0xd4aeee4b
  .word 0x95fb986c

/* Private exponent d =
0x51a84a52295a7da34ac3abe746edfd3e7651fdaa3be2b8340124878fe99bafe4130072934e700e537965ebac60e51918cc9b4143627050a95435703cac011974cd200aaf18a4c3242241cbe924eb0bce6357a98bf2d2e39b660128de1f2ca5747e7b5d23d906f68c398ec9f8d13e5f86f623a0dd6b03dec403f71b03207502fbb6c7d812f391e010cbed264655d11ab63c262a803196a128df72ecf1c65ed7f742371e4c4ee355f44cfae81ec0a256da9aa3eb1935fc509d366de08c7edb522411670cd7ee0053bb9395ac4cbe0af6f3cdd1c24e225ee47aa4f381764cfab389db993fed537f397fbff31362a85872993bc467dde42b66894f4cb3ce712b2ee1
 */
.balign 32
exp_p:
  .word 0xa4ee271f
  .word 0x96e84807
  .word 0x0ad53fc0
  .word 0x165b4f60
  .word 0xf38d7124
  .word 0xae7982a2
  .word 0x404b0ade
  .word 0xd75b45e8
  .word 0xed0826b7
  .word 0xf96ce2b4
  .word 0x2f44a897
  .word 0x379d64b9
  .word 0x650e9cde
  .word 0xcf79c5a5
  .word 0x410aadba
  .word 0x1fe31b22
  .word 0x920844bd
  .word 0xb98f1058
  .word 0x47722232
  .word 0x83f67d5d
  .word 0xad453087
  .word 0x6ee272bc
  .word 0x866cc5bd
  .word 0x1d07e63f
  .word 0xf0f4ed23
  .word 0xaa523f03
  .word 0xbfb93916
  .word 0x3b8d5d4c
  .word 0x05aaefed
  .word 0x04ae0150
  .word 0x3257de9c
  .word 0xe5df7455

.balign 32
exp_q:
  .word 0x594f3821
  .word 0xffefeb84
  .word 0x083b9dc0
  .word 0x4aba9949
  .word 0x49354f21
  .word 0xe3c599fc
  .word 0xe09e4274
  .word 0xa08741b6
  .word 0x7303d28c
  .word 0x717642be
  .word 0x743702ce
  .word 0x7d55c573
  .word 0x3f8dd845
  .word 0x29e4dad8
  .word 0xf672152a
  .word 0xcc1792af
  .word 0x8b8d1375
  .word 0x80de6bb7
  .word 0x4c18dffc
  .word 0x7d8bcea0
  .word 0x8e021f12
  .word 0x89fcda23
  .word 0xed6fd1ef
  .word 0xcf69687e
  .word 0xf8a15c2f
  .word 0x23910499
  .word 0x268b5ff1
  .word 0xaeef9a62
  .word 0x4a067ec8
  .word 0x6b5e3201
  .word 0x4e05099e
  .word 0x5cc46a0c

.balign 32
crt_coeff:
  .word 0x68f6da21
  .word 0x207efe53
  .word 0xf67be56d
  .word 0x8e6ba9db
  .word 0x0af2c3c8
  .word 0x5d5226ba
  .word 0x43fde3ad
  .word 0x3ce7ce28
  .word 0x793fe9b5
  .word 0x13e01aee
  .word 0x7e0031df
  .word 0x364131c3
  .word 0xaf00f37c
  .word 0x8d1d77bb
  .word 0xab6b8493
  .word 0x34c2d84f
  .word 0x95a2a1cb
  .word 0x63067538
  .word 0x3566180d
  .word 0x299aafe7
  .word 0x52d16fea
  .word 0x9d894033
  .word 0x485c7dbf
  .word 0xe048ced4
  .word 0xd2b3d4fb
  .word 0x7e470cba
  .word 0x8a643155
  .word 0x9593c7d2
  .word 0xea426c51
  .word 0x5b1d91eb
  .word 0x4c18384b
  .word 0x2227c3a1

/* output buffer */
.balign 32
result:
.zero 256

/* buffer for Montgomery constant RR */
.balign 32
RR:
.zero 256

/* buffer for Montgomery constant m0inv */
.balign 32
m0inv:
.zero 32

.balign 32
work_exp:
.zero 256

.balign 32
work_reduce:
.zero 256
