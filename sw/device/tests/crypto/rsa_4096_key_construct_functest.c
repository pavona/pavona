// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/base/hardened.h"
#include "sw/device/lib/crypto/drivers/entropy.h"
#include "sw/device/lib/crypto/impl/rsa/rsa_datatypes.h"
#include "sw/device/lib/crypto/include/rsa.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"

// Module for status messages.
#define MODULE_ID MAKE_MODULE_ID('t', 's', 't')

enum {
  kRsa4096CofactorNumWords = kRsa4096NumWords / 2,
};

// Note: The key material for this test was generated out-of-band using the
// PyCryptodome Python library.

// Test RSA-4096 key pair.
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
    0xf3cb8131, 0xcc1dce4d, 0x03a3001e, 0xe1fbe96f, 0x404ad557, 0x1821ebd2,
    0xc067a549, 0x3ac6c40a, 0xdc55cf46, 0x74f68602, 0x2a3bef1e, 0x2012804a,
    0xac0b75bc, 0x688e4385, 0x677bcd5d, 0x9f61a83a, 0x67f25048, 0x8713276a,
    0xdfca979c, 0xe905483b, 0x035c0088, 0x91675ce7, 0xf9479513, 0xd319a129,
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

static uint32_t kTestInvalidPrivateExponentComponentP[kRsa4096NumWords / 2] = {
    0x5b5a4fc9, 0xc59b19b5, 0x2b7b2ff6, 0xafc22452, 0x3aa7b9f2, 0xf58eae14,
    0x953b7e4c, 0x404fb3f8, 0x67335ef4, 0x82a1b5f2, 0x18c34ec2, 0xda3476fd,
    0xf3cb8131, 0xcc1dce4d, 0x03a3001f, 0xe1fbe96f, 0x404ad557, 0x1821ebd2,
    0xc067a549, 0x3ac6c40a, 0xdc55cf46, 0x74f68602, 0x2a3bef1e, 0x2012804a,
    0xac0b75bc, 0x688e4385, 0x677bcd5d, 0x9f61a83a, 0x67f25048, 0x8713276a,
    0xdfca979c, 0xe905483b, 0x035c0088, 0x91675ce7, 0xf9479513, 0xd319a129,
    0xf9eac12a, 0xfedf48c3, 0xa655fc6c, 0x5f009ed0, 0x2620d234, 0x7b818891,
    0x57fac406, 0x2b69700a, 0x998e495f, 0xf6926214, 0x79578463, 0xb42fe656,
    0x4948177f, 0xc7b888ac, 0xb5a7436a, 0xae493b28, 0xbca5cb2a, 0xb6516614,
    0xcb459e67, 0x48dd01f0, 0xff620c66, 0x86c37195, 0x739f09d5, 0x37df79d6,
    0x3efcafc4, 0xd2e1d9f7, 0xcfc2e0e1, 0x524173bc,
};

static uint32_t kTestPublicExponent = 65537;

// Key mode for testing.
static otcrypto_key_mode_t kTestKeyMode = kOtcryptoKeyModeRsaSignPss;

status_t public_key_roundtrip_test(void) {
  // Construct the public key.
  otcrypto_const_word32_buf_t modulus = {
      .data = kTestModulus,
      .len = ARRAYSIZE(kTestModulus),
  };
  uint32_t public_key_data[ceil_div(kOtcryptoRsa4096PublicKeyBytes,
                                    sizeof(uint32_t))];
  otcrypto_unblinded_key_t public_key = {
      .key_mode = kTestKeyMode,
      .key_length = kOtcryptoRsa4096PublicKeyBytes,
      .key = public_key_data,
  };
  otcrypto_rsa_public_key_construct(kOtcryptoRsaSize4096, modulus,
                                    kTestPublicExponent, &public_key);

  // Deconstruct the public key
  uint32_t roundtrip_modulus_data[kRsa4096NumWords] = {0};
  otcrypto_word32_buf_t roundtrip_modulus = {
      .data = roundtrip_modulus_data,
      .len = ARRAYSIZE(roundtrip_modulus_data),
  };
  uint32_t roundtrip_public_exponent = 0;
  otcrypto_rsa_public_key_deconstruct(&public_key, roundtrip_modulus,
                                      &roundtrip_public_exponent);

  // Check that the round trip had the expected results
  TRY_CHECK(roundtrip_public_exponent == kTestPublicExponent);
  TRY_CHECK(roundtrip_modulus.len == ARRAYSIZE(kTestModulus));
  TRY_CHECK_ARRAYS_EQ(roundtrip_modulus.data, kTestModulus,
                      ARRAYSIZE(kTestModulus));

  return OK_STATUS();
}

status_t private_key_roundtrip_test(void) {
  // Construct the private key.
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
  otcrypto_key_config_t private_key_config = {
      .version = kOtcryptoLibVersion1,
      .key_mode = kTestKeyMode,
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
  TRY(otcrypto_rsa_private_key_construct(kOtcryptoRsaSize4096, p, q, d_p, d_q,
                                         i_q, &private_key));

  // Deconstruct the public key
  uint32_t roundtrip_p_data[kRsa4096NumWords / 2] = {0};
  otcrypto_word32_buf_t roundtrip_p = {
      .data = roundtrip_p_data,
      .len = ARRAYSIZE(roundtrip_p_data),
  };
  uint32_t roundtrip_q_data[kRsa4096NumWords / 2] = {0};
  otcrypto_word32_buf_t roundtrip_q = {
      .data = roundtrip_q_data,
      .len = ARRAYSIZE(roundtrip_p_data),
  };
  uint32_t roundtrip_d_p_data[kRsa4096NumWords / 2] = {0};
  otcrypto_word32_buf_t roundtrip_d_p = {
      .data = roundtrip_d_p_data,
      .len = ARRAYSIZE(roundtrip_p_data),
  };
  uint32_t roundtrip_d_q_data[kRsa4096NumWords / 2] = {0};
  otcrypto_word32_buf_t roundtrip_d_q = {
      .data = roundtrip_d_q_data,
      .len = ARRAYSIZE(roundtrip_d_q_data),
  };
  uint32_t roundtrip_i_q_data[kRsa4096NumWords / 2] = {0};
  otcrypto_word32_buf_t roundtrip_i_q = {
      .data = roundtrip_i_q_data,
      .len = ARRAYSIZE(roundtrip_i_q_data),
  };
  otcrypto_rsa_private_key_deconstruct(&private_key, roundtrip_p, roundtrip_q,
                                       roundtrip_d_p, roundtrip_d_q,
                                       roundtrip_i_q);

  // Check that the round trip had the expected results
  TRY_CHECK(roundtrip_p.len == ARRAYSIZE(kTestCofactorP));
  TRY_CHECK_ARRAYS_EQ(roundtrip_p.data, kTestCofactorP,
                      ARRAYSIZE(kTestCofactorP));
  TRY_CHECK(roundtrip_q.len == ARRAYSIZE(kTestCofactorQ));
  TRY_CHECK_ARRAYS_EQ(roundtrip_q.data, kTestCofactorQ,
                      ARRAYSIZE(kTestCofactorQ));
  TRY_CHECK(roundtrip_d_p.len == ARRAYSIZE(kTestPrivateExponentComponentP));
  TRY_CHECK_ARRAYS_EQ(roundtrip_d_p.data, kTestPrivateExponentComponentP,
                      ARRAYSIZE(kTestPrivateExponentComponentP));
  TRY_CHECK(roundtrip_d_q.len == ARRAYSIZE(kTestPrivateExponentComponentQ));
  TRY_CHECK_ARRAYS_EQ(roundtrip_d_q.data, kTestPrivateExponentComponentQ,
                      ARRAYSIZE(kTestPrivateExponentComponentQ));
  TRY_CHECK(roundtrip_i_q.len == ARRAYSIZE(kTestCrtCoefficient));
  TRY_CHECK_ARRAYS_EQ(roundtrip_i_q.data, kTestCrtCoefficient,
                      ARRAYSIZE(kTestCrtCoefficient));
  return OK_STATUS();
}

status_t private_key_check_valid_roundtrip_inner(hardened_bool_t check_primes) {
  // Construct the public key.
  otcrypto_const_word32_buf_t modulus = {
      .data = kTestModulus,
      .len = ARRAYSIZE(kTestModulus),
  };
  uint32_t public_key_data[ceil_div(kOtcryptoRsa4096PublicKeyBytes,
                                    sizeof(uint32_t))];
  otcrypto_unblinded_key_t public_key = {
      .key_mode = kTestKeyMode,
      .key_length = kOtcryptoRsa4096PublicKeyBytes,
      .key = public_key_data,
  };
  otcrypto_rsa_public_key_construct(kOtcryptoRsaSize4096, modulus,
                                    kTestPublicExponent, &public_key);

  // Construct the private key.
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
  otcrypto_key_config_t private_key_config = {
      .version = kOtcryptoLibVersion1,
      .key_mode = kTestKeyMode,
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
  hardened_bool_t key_valid = kHardenedBoolFalse;
  TRY(otcrypto_rsa_private_key_construct_and_check(
      p, q, d_p, d_q, i_q, &public_key, kHardenedBoolFalse, &private_key,
      &key_valid));

  TRY_CHECK(key_valid == kHardenedBoolTrue);

  // Deconstruct the public key
  uint32_t roundtrip_p_data[kRsa4096NumWords / 2] = {0};
  otcrypto_word32_buf_t roundtrip_p = {
      .data = roundtrip_p_data,
      .len = ARRAYSIZE(roundtrip_p_data),
  };
  uint32_t roundtrip_q_data[kRsa4096NumWords / 2] = {0};
  otcrypto_word32_buf_t roundtrip_q = {
      .data = roundtrip_q_data,
      .len = ARRAYSIZE(roundtrip_p_data),
  };
  uint32_t roundtrip_d_p_data[kRsa4096NumWords / 2] = {0};
  otcrypto_word32_buf_t roundtrip_d_p = {
      .data = roundtrip_d_p_data,
      .len = ARRAYSIZE(roundtrip_p_data),
  };
  uint32_t roundtrip_d_q_data[kRsa4096NumWords / 2] = {0};
  otcrypto_word32_buf_t roundtrip_d_q = {
      .data = roundtrip_d_q_data,
      .len = ARRAYSIZE(roundtrip_d_q_data),
  };
  uint32_t roundtrip_i_q_data[kRsa4096NumWords / 2] = {0};
  otcrypto_word32_buf_t roundtrip_i_q = {
      .data = roundtrip_i_q_data,
      .len = ARRAYSIZE(roundtrip_i_q_data),
  };
  otcrypto_rsa_private_key_deconstruct(&private_key, roundtrip_p, roundtrip_q,
                                       roundtrip_d_p, roundtrip_d_q,
                                       roundtrip_i_q);

  // Check that the round trip had the expected results
  TRY_CHECK(roundtrip_p.len == ARRAYSIZE(kTestCofactorP));
  TRY_CHECK_ARRAYS_EQ(roundtrip_p.data, kTestCofactorP,
                      ARRAYSIZE(kTestCofactorP));
  TRY_CHECK(roundtrip_q.len == ARRAYSIZE(kTestCofactorQ));
  TRY_CHECK_ARRAYS_EQ(roundtrip_q.data, kTestCofactorQ,
                      ARRAYSIZE(kTestCofactorQ));
  TRY_CHECK(roundtrip_d_p.len == ARRAYSIZE(kTestPrivateExponentComponentP));
  TRY_CHECK_ARRAYS_EQ(roundtrip_d_p.data, kTestPrivateExponentComponentP,
                      ARRAYSIZE(kTestPrivateExponentComponentP));
  TRY_CHECK(roundtrip_d_q.len == ARRAYSIZE(kTestPrivateExponentComponentQ));
  TRY_CHECK_ARRAYS_EQ(roundtrip_d_q.data, kTestPrivateExponentComponentQ,
                      ARRAYSIZE(kTestPrivateExponentComponentQ));
  TRY_CHECK(roundtrip_i_q.len == ARRAYSIZE(kTestCrtCoefficient));
  TRY_CHECK_ARRAYS_EQ(roundtrip_i_q.data, kTestCrtCoefficient,
                      ARRAYSIZE(kTestCrtCoefficient));
  return OK_STATUS();
}

status_t private_key_check_valid_roundtrip_test(void) {
  // Call the internal roundtrip test, with the check_primes flag unset.
  return private_key_check_valid_roundtrip_inner(kHardenedBoolFalse);
}

status_t private_key_check_with_primes_valid_roundtrip_test(void) {
  // Call the internal roundtrip test, with the check_primes flag set.
  return private_key_check_valid_roundtrip_inner(kHardenedBoolTrue);
}

status_t private_key_check_invalid(void) {
  // Construct the public key.
  otcrypto_const_word32_buf_t modulus = {
      .data = kTestModulus,
      .len = ARRAYSIZE(kTestModulus),
  };
  uint32_t public_key_data[ceil_div(kOtcryptoRsa4096PublicKeyBytes,
                                    sizeof(uint32_t))];
  otcrypto_unblinded_key_t public_key = {
      .key_mode = kTestKeyMode,
      .key_length = kOtcryptoRsa4096PublicKeyBytes,
      .key = public_key_data,
  };
  otcrypto_rsa_public_key_construct(kOtcryptoRsaSize4096, modulus,
                                    kTestPublicExponent, &public_key);

  // Attempt to construct the private key, providing an invalid value for d_p
  // with a single bit changed.
  otcrypto_const_word32_buf_t p = {
      .data = kTestCofactorP,
      .len = ARRAYSIZE(kTestCofactorP),
  };
  otcrypto_const_word32_buf_t q = {
      .data = kTestCofactorQ,
      .len = ARRAYSIZE(kTestCofactorQ),
  };
  otcrypto_const_word32_buf_t d_p = {
      .data = kTestInvalidPrivateExponentComponentP,
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
  otcrypto_key_config_t private_key_config = {
      .version = kOtcryptoLibVersion1,
      .key_mode = kTestKeyMode,
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
  hardened_bool_t key_valid = kHardenedBoolFalse;
  TRY(otcrypto_rsa_private_key_construct_and_check(
      p, q, d_p, d_q, i_q, &public_key, kHardenedBoolFalse, &private_key,
      &key_valid));

  // Ensure the private key was marked as invalid
  TRY_CHECK(key_valid == kHardenedBoolFalse);
  return OK_STATUS();
}

OTTF_DEFINE_TEST_CONFIG();

bool test_main(void) {
  status_t test_result = OK_STATUS();
  CHECK_STATUS_OK(entropy_complex_init());
  EXECUTE_TEST(test_result, public_key_roundtrip_test);
  EXECUTE_TEST(test_result, private_key_roundtrip_test);
  EXECUTE_TEST(test_result, private_key_check_valid_roundtrip_test);
  EXECUTE_TEST(test_result, private_key_check_with_primes_valid_roundtrip_test);
  EXECUTE_TEST(test_result, private_key_check_invalid);
  return status_ok(test_result);
}
