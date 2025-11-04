// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/base/memory.h"
#include "sw/device/lib/crypto/drivers/entropy.h"
#include "sw/device/lib/crypto/impl/integrity.h"
#include "sw/device/lib/crypto/include/rsa.h"
#include "sw/device/lib/crypto/include/sha2.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/profile.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"

// Module for status messages.
#define MODULE_ID MAKE_MODULE_ID('t', 's', 't')

enum {
  kSha512DigestWords = 512 / 32,
  kRsa4096NumBytes = 4096 / 8,
  kRsa4096NumWords = kRsa4096NumBytes / sizeof(uint32_t),
};

// Note: The private key and valid signatures for this test were generated
// out-of-band using the PyCryptodome Python library.

// Test RSA-4096 key pair:
// e = 65537
// n =
// 0x923d26b1b8100867c52ceccbb7b12778bb56c41e74a00192f5cff3d6ca455764149f474abdff524f8711d18bca9ec1c8a911acb9f3b55b92c93741ae5096eb55ee537161caa24b43b7975de681890d9794274031f7d34763e616c66878c110562797e007df176908c5c7c09e28f41846a83522b7a080a8dee6f54599c11a46110733ddacda83238c5e2494c3a9db50ec2ac2bfcf456d1b349a20f3667d4b42e4301ba27152b6aeb4910a869848ba51ca6c4bc2bce4605201fb97013876b81c66f41e8e1a164bdfe9cf2c938d741a0a139a16aa5e371e6534f7b2fe46e9366e3fd94c6f9a84137166f9795da6a341b921ae584a1c5d772fa168ae9ea592da78749ead0010678acef1f405ca0387bf02a1d214c97078fc971eb9543c035b26d7fb59c05b949d589400456b541d1f538ee569f8e760ef593e46bf4a036b217125254a690b240d87195eb02f876604c40c5f43957974cc710705f63d8d4495e0d71a0b87bef169c526075428afc5d476a75343a405d3065717ba3cdee7b26398b8b1a272f6768ad109a2ebead54f19567c96caacc7d0f9ae495aff3fed73dea0d12f3a9c60c474fe316c964c7c044ab8c5fcc7b2b40c8dfeae93cf348dfbef92361d4f473ba5f9699bf22ab3eb21f22b2197a970c3dcd33d1707a86ad866b1d4b69cf071b30b17488f537c4ceeb0ea50031cde80fc8b02cdc82c85c4bdcf3114efe5
// d =
// 0x19aacb83965d940818a2c3b616d9ec6663a53d3b66375e475bc721d271829dadd673c558d043c3bfeb225cbfd732a9ab0d47a9a422ab12754f45584d1ede7a54450616c8b5fee9cc6b2911655f977d4ffd442d5f87d2a8bd5739689e1611b6cb145c730916a63e7c787050b5c1d4e3fce4d19cb413a2f960d4333901dd537df847a61a129870bb78cbde4a51145b46d708c35154b1280f061ac64d4a5013f95be138bc787ceeccf7aadc68d6ca2f0fa38282029e524c38a099f6bd535a7d02992c603f8b431e12a130486fe67c3a04ca3f799a71fa652698d71feec2e5f47481d6e334546fb994e620c3e544d5f33769fab68add732733f035d62e48bbdf861417fecf98658a898c297fec029ea004b708edc6ec008462ec7a62418a56bc03a553d53ac463a211a93a019ce8bc4e07269c7269f61b146fdb73fb2898e9371f6d087d75f53409f25ccda8258a7955470feda00eb93130ab1beeb31968ff0f46e59e8950467af1eeb7fb339c321aa75fe8f87aa3ccbd0107506a6ed6f1e3a10c0ef29cbee4e62df4f64eb8bd8aa40c8a129d1bf875ea48ce7801204058cf40085e248f7d36f3c16658252a9da39255f7addb82a4c11707763eccb95bca1fc075d6a6bca8d4db656795f0f0ec3a0a86efb9ed1cf5db010cc1af90a218e04a977ff1e077dea92fcbfb38bdbc9c786b11c61ded4cacbe4c0f18d02109108d2605e651

// Modulus (n) in little-endian form.
static uint32_t kTestModulus[kRsa4096NumWords] = {
    0x3114efe5, 0x85c4bdcf, 0x02cdc82c, 0xde80fc8b, 0xea50031c, 0x7c4ceeb0,
    0x17488f53, 0xf071b30b, 0xb1d4b69c, 0xa86ad866, 0xd33d1707, 0xa970c3dc,
    0xf22b2197, 0x2ab3eb21, 0xf9699bf2, 0x4f473ba5, 0xef92361d, 0xcf348dfb,
    0x8dfeae93, 0xc7b2b40c, 0x4ab8c5fc, 0x964c7c04, 0x74fe316c, 0x3a9c60c4,
    0xdea0d12f, 0xff3fed73, 0xf9ae495a, 0xcaacc7d0, 0x19567c96, 0xebead54f,
    0x8ad109a2, 0xa272f676, 0x6398b8b1, 0x3cdee7b2, 0x065717ba, 0x43a405d3,
    0xd476a753, 0x5428afc5, 0x69c52607, 0x0b87bef1, 0x95e0d71a, 0xf63d8d44,
    0xcc710705, 0x43957974, 0x04c40c5f, 0xb02f8766, 0x0d87195e, 0x4a690b24,
    0x21712525, 0xbf4a036b, 0xef593e46, 0x69f8e760, 0x1f538ee5, 0x456b541d,
    0x9d589400, 0x59c05b94, 0x5b26d7fb, 0xb9543c03, 0x78fc971e, 0xd214c970,
    0x87bf02a1, 0xf405ca03, 0x678acef1, 0x9ead0010, 0x92da7874, 0x68ae9ea5,
    0x5d772fa1, 0xae584a1c, 0xa341b921, 0xf9795da6, 0x84137166, 0xd94c6f9a,
    0xe9366e3f, 0xf7b2fe46, 0x371e6534, 0x9a16aa5e, 0x741a0a13, 0xcf2c938d,
    0x164bdfe9, 0xf41e8e1a, 0x76b81c66, 0xfb970138, 0xe4605201, 0x6c4bc2bc,
    0x48ba51ca, 0x910a8698, 0x52b6aeb4, 0x301ba271, 0x7d4b42e4, 0x9a20f366,
    0x456d1b34, 0x2ac2bfcf, 0xa9db50ec, 0x5e2494c3, 0xda83238c, 0x0733ddac,
    0xc11a4611, 0xe6f54599, 0xa080a8de, 0xa83522b7, 0x28f41846, 0xc5c7c09e,
    0xdf176908, 0x2797e007, 0x78c11056, 0xe616c668, 0xf7d34763, 0x94274031,
    0x81890d97, 0xb7975de6, 0xcaa24b43, 0xee537161, 0x5096eb55, 0xc93741ae,
    0xf3b55b92, 0xa911acb9, 0xca9ec1c8, 0x8711d18b, 0xbdff524f, 0x149f474a,
    0xca455764, 0xf5cff3d6, 0x74a00192, 0xbb56c41e, 0xb7b12778, 0xc52ceccb,
    0xb8100867, 0x923d26b1,

};

static uint32_t kTestCofactorP[kRsa4096NumWords / 2] = {
    0xa42b3975, 0x486e66a1, 0x429543c7, 0x640a9f4a, 0x15c68742, 0x6f01f7e4,
    0x2bc6994,  0xe3c6b400, 0x56da58b2, 0x4eef65dd, 0xf5985fae, 0x12a287d1,
    0x33539d02, 0xea714e4f, 0xbc2b044b, 0x59495543, 0x25aaba3,  0xd696b0b2,
    0x9aa7af94, 0x74c1bc0e, 0x3ac3053d, 0x34315540, 0x543108d0, 0xd0aed3b,
    0xb92acad,  0xccf328b1, 0x4b8656ef, 0x50e3b3bb, 0xde9d43b7, 0x36b40e1d,
    0xcdcf3890, 0x602561c0, 0x5f5f2f2a, 0xfab71bc8, 0xc0765982, 0x9f0660f9,
    0x323c984d, 0x66aa54f7, 0x5e520c5a, 0xacc26fa9, 0x9eee8b0c, 0xaaf4f879,
    0x364eb857, 0x893700d5, 0x3fd36893, 0x1e5712e8, 0x560e398b, 0xa0ef8592,
    0xebc145bf, 0x555b5a25, 0x569b23fc, 0x7ac028cc, 0xa3a4c627, 0x285d52e0,
    0xbceae56c, 0xa12e78cb, 0x157dfb6b, 0x7c64e3ca, 0x756b1935, 0xb52ac488,
    0x1534f8e2, 0x8dce8f10, 0x8f47fe7a, 0xbb02e9b1,
};

static uint32_t kTestCofactorQ[kRsa4096NumWords / 2] = {
    0xc74c9eb1, 0xddcba2ef, 0xaa08cb01, 0x12cf797a, 0x6a5b6bfb, 0x6a8a9245,
    0x273fdf28, 0x390d1889, 0xd67ed07a, 0xd6d03b4,  0xde1d046,  0xf24027e4,
    0xb78ae458, 0xc6d64366, 0xc35854d1, 0x58678ba5, 0x570a4b1b, 0xc672fa48,
    0xd47e1386, 0x30ac5c2f, 0xbb099956, 0xda62cbde, 0xead45575, 0xaa73c5e1,
    0x27394296, 0xfc2b2f82, 0x9c229f4a, 0x955d2059, 0x4a39df8a, 0x2cb560e4,
    0xa20ac9c0, 0xc5162ee,  0xd1956baf, 0x10bf68f,  0x13af452,  0xccf7dc9a,
    0x1471570c, 0x4250206d, 0x5db5432c, 0x89f86282, 0xa9e2d8dd, 0x7f347b65,
    0xaa95e9e,  0x415c412b, 0xb0714e9a, 0xfdfce5c,  0x6ef02097, 0xfbb85f61,
    0x9ef30dad, 0x13e6a5c0, 0x17fa02ae, 0xb41c40fb, 0x57f93251, 0xcba454f1,
    0x366f99ba, 0xddc08695, 0x8d9d7550, 0x78189a3f, 0x649807dd, 0x25aa2d48,
    0x6ddccb17, 0xafc6264d, 0xfd2816c8, 0xc82fbdb5,
};

static uint32_t kTestPrivateExponentComponentP[kRsa4096NumWords / 2] = {
    0x5b5a4fc9, 0xc59b19b5, 0x2b7b2ff6, 0xafc22452, 0x3aa7b9f2, 0xf58eae14,
    0x953b7e4c, 0x404fb3f8, 0x67335ef4, 0x82a1b5f2, 0x18c34ec2, 0xda3476fd,
    0xf3cb8131, 0xcc1dce4d, 0x3a3001e,  0xe1fbe96f, 0x404ad557, 0x1821ebd2,
    0xc067a549, 0x3ac6c40a, 0xdc55cf46, 0x74f68602, 0x2a3bef1e, 0x2012804a,
    0xac0b75bc, 0x688e4385, 0x677bcd5d, 0x9f61a83a, 0x67f25048, 0x8713276a,
    0xdfca979c, 0xe905483b, 0x35c0088,  0x91675ce7, 0xf9479513, 0xd319a129,
    0xf9eac12a, 0xfedf48c3, 0xa655fc6c, 0x5f009ed0, 0x2620d234, 0x7b818891,
    0x57fac406, 0x2b69700a, 0x998e495f, 0xf6926214, 0x79578463, 0xb42fe656,
    0x4948177f, 0xc7b888ac, 0xb5a7436a, 0xae493b28, 0xbca5cb2a, 0xb6516614,
    0xcb459e67, 0x48dd01f0, 0xff620c66, 0x86c37195, 0x739f09d5, 0x37df79d6,
    0x3efcafc4, 0xd2e1d9f7, 0xcfc2e0e1, 0x524173bc,
};

static uint32_t kTestPrivateExponentComponentQ[kRsa4096NumWords / 2] = {
    0x5810f281, 0xdd044ece, 0x921b9c1c, 0xb0b4f9f3, 0x1cd91924, 0x1af81c8e,
    0xd68d49df, 0x3dedb354, 0xd58402f2, 0x53714747, 0x5e2f11a6, 0xb1b9a30c,
    0x14cd48a8, 0x6d94c42d, 0xd6809126, 0x5dfb7702, 0x18c16eaf, 0xf6295fc6,
    0xf407d458, 0x79324b14, 0x67dfe161, 0x649b91f2, 0x47917651, 0xebbb6cc6,
    0x67809985, 0xbb20ba18, 0x789b8860, 0xe976be9f, 0x5d172695, 0x5e86663,
    0xf142d3af, 0xedf383d0, 0x63f4f32b, 0x285c57a9, 0x566b2441, 0xc642effa,
    0x70952e2a, 0x760614fb, 0xe96375dc, 0x3b842975, 0x1a41a281, 0xa064d0ef,
    0x19045944, 0x743dadf3, 0x70454d0b, 0x2bc1dcd0, 0xdb507ab8, 0xbe7437fd,
    0x70d8e461, 0x75d09c24, 0x32840920, 0xbbf27036, 0x84a8939a, 0x390cd63f,
    0xc6b36b7,  0x2f2f19ab, 0x708b63f8, 0xe3688a08, 0xb101ff93, 0x8b8db1d2,
    0xafc8a9f,  0xc28deac3, 0xc593a10a, 0x21fdb940,
};

static uint32_t kTestCrtCoefficient[kRsa4096NumWords / 2] = {
    0xd2d24361, 0x91dd5ca9, 0x83c0e47b, 0x94ec892b, 0x652a48c3, 0xfaca1c9b,
    0xf4edb448, 0xa67fae42, 0x36f2871c, 0xd10a8426, 0x4155eccf, 0x7238be69,
    0x544410aa, 0x93f34c6e, 0x42c22222, 0xf392befa, 0x63466b4b, 0xea3ad8c0,
    0xa541b3f0, 0xeef32c4d, 0x54662925, 0x56b407e9, 0x320bda91, 0x6f106dc2,
    0xcd8f5e30, 0x96693547, 0xc4133d08, 0xd9adb683, 0x857bc942, 0x42c54d7e,
    0x36f927a4, 0xb3243a6c, 0x614de345, 0x158b2a23, 0xb56229ae, 0x7a3c5311,
    0x16a39fe1, 0x104e3cd3, 0xa264825d, 0xeab97e2b, 0x56ba7f27, 0x76e5e942,
    0xd13146b1, 0x1cc6da68, 0xd2e9a365, 0x1e120c65, 0x3524be6,  0x34394c2,
    0x67a3a94e, 0x2849824e, 0x540c18dd, 0xee4c8498, 0x8bbf5867, 0x68760f54,
    0x107bf54e, 0xc4801efe, 0x500f1e6,  0x2735f8a6, 0xae9e2f6b, 0x367e6f4d,
    0xfdfece3f, 0xd89234df, 0x22642014, 0x72406ade,
};

static uint32_t kTestPublicExponent = 65537;

// Message data for testing.
static const unsigned char kTestMessage[] = "Test message.";
static const size_t kTestMessageLen = sizeof(kTestMessage) - 1;

// Valid signature of `kTestMessage` from the test private key, using PKCS#1
// v1.5 padding and SHA-512 as the hash function.
static const uint32_t kValidSignaturePkcs1v15[kRsa4096NumWords] = {
    0x431579e6, 0x4a4dc3fd, 0xdd82ee92, 0xee94982b, 0xc005f7e2, 0x85e5b717,
    0x60c59ff2, 0x201ddff2, 0x96f581be, 0x503fe3aa, 0xef0f8180, 0xb47ff82c,
    0xc8a823f8, 0x71738ca0, 0xb83dcf25, 0x17b990c7, 0xd9f1d7fa, 0x80d3ba14,
    0x13ff422f, 0x9d6e56de, 0xb62b47e0, 0xa4f0b9bc, 0x940a9c71, 0x69b2071c,
    0xdbe34edb, 0xfe63d932, 0xccd9c16f, 0x5ef4ed25, 0x1ec79846, 0x07211158,
    0x8cae2c9d, 0x62e2ef5a, 0x252cc4e0, 0xe8baadda, 0xae429633, 0x429f0843,
    0x40dd6200, 0x04c836b0, 0x8c409adf, 0x73b2add1, 0x36aa0a74, 0xfadaef9b,
    0xacee1f74, 0x5b7b180f, 0x8fad3140, 0xcec646a2, 0x408ddf5c, 0x1d38ee7f,
    0xf240d459, 0xfadfc25c, 0x97647ee4, 0x42d965d5, 0xdbf6ee16, 0xc479cf35,
    0x87e33cd3, 0xac88bfce, 0x6f32526e, 0xea801ce0, 0x74feee71, 0x00a6c464,
    0x8eb97ada, 0xb8b03e2e, 0x2743d233, 0x4b013bca, 0x9fe1a670, 0x20a987c8,
    0x0ee01ece, 0xadd617cc, 0xa3fa54ef, 0x52097d80, 0x0a9563a2, 0xb9dbfd84,
    0xf09435ce, 0x98eb3ae0, 0x51bfae20, 0x6a8b4d79, 0x4734e7d8, 0x0ec9625c,
    0x966491e2, 0xb93d5f9d, 0x1ed39811, 0x817e1eff, 0x509fa18f, 0x7662c2f9,
    0x6bc87f86, 0x75790027, 0xa75af1ad, 0x3f7b359e, 0x0e8b0f7a, 0x2812be5d,
    0xcf22b0bf, 0xe8b8a9a1, 0xa4d1270b, 0x990f2b58, 0xd604d2fa, 0x0c0150dd,
    0x98573b4b, 0x26e911fe, 0xc3c16e49, 0x6e32d3b3, 0x74190631, 0x464c406b,
    0x8124ce62, 0x446c3ec5, 0xde5a2c08, 0xd0cf9f9b, 0x1b5b66ca, 0x6e59e9fa,
    0x9b96724a, 0x8ca5eee1, 0xe9a31ba6, 0xd7820685, 0x77f97af5, 0x3f0bb945,
    0xbae35f12, 0xd2cf54e8, 0xe0b58909, 0xa2ae9943, 0x1eb03456, 0x5dcac40b,
    0x05bf5fa0, 0xc745d2c2, 0x624004fb, 0x445c1918, 0x3853399d, 0x738f2ae2,
    0xd31ca0a5, 0x2daf5e53,

};

// Valid signature of `kTestMessage` from the test private key, using PSS
// padding and SHA-512 as the hash function.
static const uint32_t kValidSignaturePss[kRsa4096NumWords] = {
    0xac65bc2f, 0x7022bce6, 0x76849939, 0xba21c651, 0xdfb70b15, 0x7ae994ca,
    0x05eae1d1, 0x57ca0aea, 0xfefb90c5, 0x59357a95, 0x9d79703c, 0x352474be,
    0x5e1c6893, 0x126bec01, 0x71f4d89c, 0x757548b4, 0x23390690, 0xf40f4cf7,
    0x4fcd3373, 0xf2172e98, 0xb9922aff, 0x646c3ab4, 0xd2ef343b, 0x9d38c1e6,
    0x3cd37001, 0xd79b26cf, 0x1f568d39, 0x7c6d6355, 0xc4ca637f, 0xaa3a80e6,
    0x9be8c94a, 0x260b53f8, 0xa42683bf, 0xa7b9f22a, 0xb134f326, 0xe9c72416,
    0xd1614a35, 0x937fc772, 0x7f87f200, 0x952b6b29, 0x616f909f, 0x6b527aa8,
    0xdc2d31d3, 0xce14cc6a, 0xb10366b2, 0x76efd23a, 0x39b15683, 0xa6de0de4,
    0x6896b3c1, 0x31cd66b7, 0xab7a2f62, 0xd754cdcd, 0xf40df9c9, 0xf9707edc,
    0xfa91d1bb, 0xccc8a8a5, 0x61003a17, 0xb4fcb461, 0x72a6681c, 0xe35bd382,
    0x2480a6d2, 0x4f4131e5, 0x19738cf0, 0x95485ec8, 0x14ef579f, 0x49d111c5,
    0x975610a1, 0x51ddcf78, 0xe68ab983, 0x10cd6f5f, 0xe0ae465c, 0x56f87907,
    0x3b5c12dc, 0x50e3633c, 0x879ad30b, 0xd76bb6b0, 0xd014e042, 0x96dedd7a,
    0x4e1eea8d, 0xe6079e4e, 0xc6944035, 0xc866e7a3, 0xf3ac825c, 0x43187fba,
    0xb3b1a633, 0x5589f5de, 0x6a29d58e, 0x35c88cba, 0x160094d5, 0xb0d207eb,
    0xfda6ea44, 0x099b3916, 0x7f4a7947, 0xc0353728, 0x5dada9bf, 0xcd329037,
    0xb2b0fad2, 0xbd79e8e9, 0x5eeb9be8, 0x726ffb2f, 0x61048c24, 0x9fd06d5a,
    0xb486cfe3, 0x94373606, 0x4b482744, 0xe068b60b, 0x52e3420d, 0x018ab9c1,
    0x54abfd10, 0x5e9fd4a8, 0x891be3ff, 0x3c4b951e, 0x215d8a09, 0xf7138508,
    0xbe0e8c16, 0x03bc6f4d, 0x4cc8c343, 0xd88f6a5f, 0xa0df643b, 0x8825086b,
    0xd991ae07, 0x7eaeda97, 0x4fd1b8d5, 0xf494fc5d, 0x08474fcd, 0x898e550a,
    0xd6c55513, 0x251abfaa,

};

/**
 * Helper function to run the RSA-4096 signing routine.
 *
 * Packages input into cryptolib-style structs and calls `otcrypto_rsa_sign`
 * using the constant test private key. Always uses SHA-512 as the hash
 * function.
 *
 * @param msg Message to sign.
 * @param msg_len Message length in bytes.
 * @param padding_mode RSA padding mode.
 * @param[out] sig Buffer for the generated RSA signature (4096 bits).
 * @return OK or error.
 */
static status_t run_rsa_4096_sign(const uint8_t *msg, size_t msg_len,
                                  otcrypto_rsa_padding_t padding_mode,
                                  uint32_t *sig) {
  otcrypto_key_mode_t key_mode;
  switch (padding_mode) {
    case kOtcryptoRsaPaddingPkcs:
      key_mode = kOtcryptoKeyModeRsaSignPkcs;
      break;
    case kOtcryptoRsaPaddingPss:
      key_mode = kOtcryptoKeyModeRsaSignPss;
      break;
    default:
      return INVALID_ARGUMENT();
  };

  // Create two shares for the private exponent (second share is all-zero).
  otcrypto_const_word32_buf_t p = {
      .data = kTestCofactorP,
      .len = ARRAYSIZE(kTestCofactorP),
  };
  otcrypto_const_word32_buf_t q = {
      .data = kTestCofactorQ,
      .len = ARRAYSIZE(kTestCofactorQ),
  };
  otcrypto_const_word32_buf_t d_p = {
      .data = kTestPrivateExponentComponentP,
      .len = ARRAYSIZE(kTestPrivateExponentComponentP),
  };
  otcrypto_const_word32_buf_t d_q = {
      .data = kTestPrivateExponentComponentQ,
      .len = ARRAYSIZE(kTestPrivateExponentComponentQ),
  };
  otcrypto_const_word32_buf_t i_q = {
      .data = kTestCrtCoefficient,
      .len = ARRAYSIZE(kTestCrtCoefficient),
  };

  // Construct the private key.
  otcrypto_key_config_t private_key_config = {
      .version = kOtcryptoLibVersion1,
      .key_mode = key_mode,
      .key_length = kOtcryptoRsa4096PrivateKeyBytes,
      .hw_backed = kHardenedBoolFalse,
      .security_level = kOtcryptoKeySecurityLevelLow,
  };
  size_t keyblob_words =
      ceil_div(kOtcryptoRsa4096PrivateKeyblobBytes, sizeof(uint32_t));
  uint32_t keyblob[keyblob_words];
  otcrypto_blinded_key_t private_key = {
      .config = private_key_config,
      .keyblob = keyblob,
      .keyblob_length = kOtcryptoRsa4096PrivateKeyblobBytes,
  };
  otcrypto_const_word32_buf_t modulus = {
      .data = kTestModulus,
      .len = ARRAYSIZE(kTestModulus),
  };
  TRY(otcrypto_rsa_private_key_from_exponents(kOtcryptoRsaSize4096, modulus, p,
                                              q, kTestPublicExponent, d_p, d_q,
                                              i_q, &private_key));

  // Hash the message.
  otcrypto_const_byte_buf_t msg_buf = {.data = msg, .len = msg_len};
  uint32_t msg_digest_data[kSha512DigestWords];
  otcrypto_hash_digest_t msg_digest = {
      .data = msg_digest_data,
      .len = ARRAYSIZE(msg_digest_data),
  };
  TRY(otcrypto_sha2_512(msg_buf, &msg_digest));

  otcrypto_word32_buf_t sig_buf = {
      .data = sig,
      .len = kRsa4096NumWords,
  };

  uint64_t t_start = profile_start();
  TRY(otcrypto_rsa_sign(&private_key, msg_digest, padding_mode, sig_buf));
  profile_end_and_print(t_start, "RSA signature generation");

  return OK_STATUS();
}

/**
 * Helper function to run the RSA-4096 verification routine.
 *
 * Packages input into cryptolib-style structs and calls `otcrypto_rsa_verify`
 * using the constant test public key. Always uses SHA-512 as the hash
 * function.
 *
 * @param msg Message to verify.
 * @param msg_len Message length in bytes.
 * @param sig Signature to verify
 * @param padding_mode RSA padding mode.
 * @param[out] verification_result Whether the signature passed verification.
 * @return OK or error.
 */
static status_t run_rsa_4096_verify(const uint8_t *msg, size_t msg_len,
                                    const uint32_t *sig,
                                    const otcrypto_rsa_padding_t padding_mode,
                                    hardened_bool_t *verification_result) {
  otcrypto_key_mode_t key_mode;
  switch (padding_mode) {
    case kOtcryptoRsaPaddingPkcs:
      key_mode = kOtcryptoKeyModeRsaSignPkcs;
      break;
    case kOtcryptoRsaPaddingPss:
      key_mode = kOtcryptoKeyModeRsaSignPss;
      break;
    default:
      return INVALID_ARGUMENT();
  };

  // Construct the public key.
  otcrypto_const_word32_buf_t modulus = {
      .data = kTestModulus,
      .len = ARRAYSIZE(kTestModulus),
  };
  uint32_t public_key_data[ceil_div(kOtcryptoRsa4096PublicKeyBytes,
                                    sizeof(uint32_t))];
  otcrypto_unblinded_key_t public_key = {
      .key_mode = key_mode,
      .key_length = kOtcryptoRsa4096PublicKeyBytes,
      .key = public_key_data,
  };
  TRY(otcrypto_rsa_public_key_construct(kOtcryptoRsaSize4096, modulus,
                                        kTestPublicExponent, &public_key));

  // Hash the message.
  otcrypto_const_byte_buf_t msg_buf = {.data = msg, .len = msg_len};
  uint32_t msg_digest_data[kSha512DigestWords];
  otcrypto_hash_digest_t msg_digest = {
      .data = msg_digest_data,
      .len = ARRAYSIZE(msg_digest_data),
  };
  TRY(otcrypto_sha2_512(msg_buf, &msg_digest));

  otcrypto_const_word32_buf_t sig_buf = {
      .data = sig,
      .len = kRsa4096NumWords,
  };

  uint64_t t_start = profile_start();
  TRY(otcrypto_rsa_verify(&public_key, msg_digest, padding_mode, sig_buf,
                          verification_result));
  profile_end_and_print(t_start, "RSA verify");

  return OK_STATUS();
}

status_t pkcs1v15_sign_test(void) {
  // Generate a signature using PKCS#1 v1.5 padding and SHA-512 as the hash
  // function.
  uint32_t sig[kRsa4096NumWords];
  TRY(run_rsa_4096_sign(kTestMessage, kTestMessageLen, kOtcryptoRsaPaddingPkcs,
                        sig));

  // Compare to the expected signature.
  TRY_CHECK_ARRAYS_EQ(sig, kValidSignaturePkcs1v15,
                      ARRAYSIZE(kValidSignaturePkcs1v15));
  return OK_STATUS();
}

status_t pkcs1v15_verify_valid_test(void) {
  // Try to verify a valid signature.
  hardened_bool_t verification_result;
  TRY(run_rsa_4096_verify(kTestMessage, kTestMessageLen,
                          kValidSignaturePkcs1v15, kOtcryptoRsaPaddingPkcs,
                          &verification_result));

  // Expect the signature to pass verification.
  TRY_CHECK(verification_result == kHardenedBoolTrue);
  return OK_STATUS();
}

status_t pkcs1v15_verify_invalid_test(void) {
  // Try to verify an invalid signature (wrong padding mode).
  hardened_bool_t verification_result;
  TRY(run_rsa_4096_verify(kTestMessage, kTestMessageLen, kValidSignaturePss,
                          kOtcryptoRsaPaddingPkcs, &verification_result));

  // Expect the signature to fail verification.
  TRY_CHECK(verification_result == kHardenedBoolFalse);
  return OK_STATUS();
}

status_t pss_sign_test(void) {
  // PSS signatures are not deterministic, so we need to sign-then-verify.
  uint32_t sig[kRsa4096NumWords];
  TRY(run_rsa_4096_sign(kTestMessage, kTestMessageLen, kOtcryptoRsaPaddingPss,
                        sig));

  // Try to verify the signature.
  hardened_bool_t verification_result;
  TRY(run_rsa_4096_verify(kTestMessage, kTestMessageLen, sig,
                          kOtcryptoRsaPaddingPss, &verification_result));

  // Expect the signature to pass verification.
  TRY_CHECK(verification_result == kHardenedBoolTrue);
  return OK_STATUS();
}

status_t pss_verify_valid_test(void) {
  // Try to verify a valid signature.
  hardened_bool_t verification_result;
  TRY(run_rsa_4096_verify(kTestMessage, kTestMessageLen, kValidSignaturePss,
                          kOtcryptoRsaPaddingPss, &verification_result));

  // Expect the signature to pass verification.
  TRY_CHECK(verification_result == kHardenedBoolTrue);
  return OK_STATUS();
}

status_t pss_verify_invalid_test(void) {
  // Try to verify an invalid signature (wrong padding mode).
  hardened_bool_t verification_result;
  TRY(run_rsa_4096_verify(kTestMessage, kTestMessageLen,
                          kValidSignaturePkcs1v15, kOtcryptoRsaPaddingPss,
                          &verification_result));

  // Expect the signature to fail verification.
  TRY_CHECK(verification_result == kHardenedBoolFalse);
  return OK_STATUS();
}

OTTF_DEFINE_TEST_CONFIG();

bool test_main(void) {
  status_t test_result = OK_STATUS();
  CHECK_STATUS_OK(entropy_complex_init());
  EXECUTE_TEST(test_result, pkcs1v15_sign_test);
  EXECUTE_TEST(test_result, pkcs1v15_verify_valid_test);
  EXECUTE_TEST(test_result, pkcs1v15_verify_invalid_test);
  EXECUTE_TEST(test_result, pss_sign_test);
  EXECUTE_TEST(test_result, pss_verify_valid_test);
  EXECUTE_TEST(test_result, pss_verify_invalid_test);
  return status_ok(test_result);
}
