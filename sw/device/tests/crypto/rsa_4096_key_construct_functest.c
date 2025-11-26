// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

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
  otcrypto_rsa_public_key_deconstruct(&public_key, &roundtrip_modulus,
                                      &roundtrip_public_exponent);

  // Check that the round trip had the expected results
  TRY_CHECK(roundtrip_public_exponent == kTestPublicExponent);
  TRY_CHECK(roundtrip_modulus.len == ARRAYSIZE(kTestModulus));
  TRY_CHECK_ARRAYS_EQ(roundtrip_modulus.data, kTestModulus,
                      ARRAYSIZE(kTestModulus));

  return OK_STATUS();
}

OTTF_DEFINE_TEST_CONFIG();

bool test_main(void) {
  status_t test_result = OK_STATUS();
  CHECK_STATUS_OK(entropy_complex_init());
  EXECUTE_TEST(test_result, public_key_roundtrip_test);
  return status_ok(test_result);
}
