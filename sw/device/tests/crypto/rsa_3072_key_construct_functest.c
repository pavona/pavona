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
  kRsa3072CofactorNumWords = kRsa3072NumWords / 2,
};

// Note: The key material for this test was generated out-of-band using the
// PyCryptodome Python library.

// Test RSA-3072 key pair.
static uint32_t kTestModulus[kRsa3072NumWords] = {
    0x5248e8eb, 0x61422b39, 0xc2242ceb, 0x239b6fe8, 0xddf894ca, 0x5b29ea9c,
    0x30ca1103, 0xb9c19f86, 0x0241a25d, 0x7b1f16bd, 0xee956a86, 0x154da24d,
    0x2318ca24, 0xf941f899, 0x1299c298, 0xbcd26c2b, 0x1e9c1ce3, 0x5fcfd55f,
    0x6258c90c, 0x55bed694, 0xd2412d32, 0x3d9bdfff, 0xdde93cc0, 0xdd1beacf,
    0x54ce8e23, 0x62ec62aa, 0xd95d6ff6, 0xe04eb5af, 0x7b8bc3e8, 0xe300d474,
    0x0d15ec18, 0xedd8bc92, 0xabc571eb, 0x91fcadfe, 0xebf8d88d, 0xe576ea64,
    0x482def92, 0x22df77e1, 0x5c36a62b, 0x53b671a0, 0x434ccc48, 0x5bb1b180,
    0x5dfe37bc, 0xab5c1657, 0x3e1dfa99, 0x64a074ff, 0xde3a683d, 0xddecb80b,
    0xf7e63faf, 0xea044e20, 0xac776aa1, 0x26d660d3, 0x09435541, 0x1988b5df,
    0xb82214b1, 0x1cf0109b, 0x8094aee1, 0x4b2dab39, 0x9d0a8e49, 0x37c377b3,
    0xf9d614e6, 0xd446f2cb, 0x2f8c428b, 0x46b16dd8, 0xabca3029, 0x84807eb9,
    0x3fc8e542, 0x2cd843c3, 0x6b8cfc8e, 0x6398c69c, 0xdcbafdb2, 0x4bed7f9e,
    0xd1a7e998, 0x0b53c50a, 0x7fdec0a9, 0x141f23d0, 0x46dcfa85, 0x53cdc14e,
    0x0922ea46, 0xe82d5c81, 0xcc4ee3b8, 0x5b973b2c, 0x065433ac, 0x075a427b,
    0xa4b442f1, 0x8adb26e8, 0xe827fc8c, 0xc6057b0b, 0x1c9f5a53, 0x833bf326,
    0x7520180f, 0x24ec935f, 0xa90cc23b, 0xafe74287, 0x31261907, 0xa60f30a2,
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
  uint32_t public_key_data[ceil_div(kOtcryptoRsa3072PublicKeyBytes,
                                    sizeof(uint32_t))];
  otcrypto_unblinded_key_t public_key = {
      .key_mode = kTestKeyMode,
      .key_length = kOtcryptoRsa3072PublicKeyBytes,
      .key = public_key_data,
  };
  otcrypto_rsa_public_key_construct(kOtcryptoRsaSize3072, modulus,
                                    kTestPublicExponent, &public_key);

  // Deconstruct the public key
  uint32_t roundtrip_modulus_data[kRsa3072NumWords] = {0};
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
