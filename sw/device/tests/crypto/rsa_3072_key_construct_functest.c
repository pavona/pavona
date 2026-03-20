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

static uint32_t kTestCofactorP[kRsa3072NumWords / 2] = {
    0x2dcdaa29, 0xa5479f83, 0xf0865f20, 0xa00e6b5c, 0xda2f3b0b, 0xe25ee188,
    0xda871b22, 0x7f3c5312, 0x70d3dbb9, 0x18b5d5c4, 0x6aab200b, 0x4e0f3f82,
    0xf8a21a59, 0x50ef0295, 0x46e46aab, 0x7d2400cd, 0x7eba5cd,  0x663c5c3e,
    0x9864429f, 0x43b5f720, 0x44c7bce9, 0xd1b4e7a6, 0x182fad9f, 0xa44f60d1,
    0x9fbaa2fc, 0xaec05186, 0x5a153b8d, 0x260d7233, 0xf1ca731,  0x3a732dc0,
    0xb8569f49, 0xff65af8b, 0xe7e52e22, 0x89488e07, 0x48d1fb75, 0xa25d2fc9,
    0xd7cc292f, 0xb03ed86e, 0xade0e9e8, 0xc2c7d9a6, 0x3669559e, 0x5e42d96e,
    0xe88cc13f, 0x6e0f4140, 0xbb1d7819, 0xa51aeef0, 0xde49201f, 0xcd8321b3,
};

static uint32_t kTestCofactorQ[kRsa3072NumWords / 2] = {
    0x2ea1c4f3, 0xfc66f8f8, 0x14f3a7a1, 0x7bc379a7, 0x4ead8bc9, 0xa6deed,
    0x3ce15fd7, 0x728a5f2,  0x137b7369, 0x5148e796, 0x4b35584,  0xfd3198c0,
    0x27b7bd07, 0xd1f161c2, 0x3fe253b1, 0x776469d8, 0x2ff32c90, 0x60e7e92b,
    0xc4634b76, 0x92ef2f4,  0x6f47669c, 0x646656d3, 0x84ba2a40, 0x644b9d6c,
    0x46aa19de, 0xac1775f8, 0x4544e5b5, 0xc2016a75, 0xe9e0123b, 0x2a68042b,
    0x1e4ae26a, 0xe5694a01, 0xd4f37598, 0x90dbad6f, 0x73c1fcd1, 0xd038763c,
    0xc4a259da, 0xf346012e, 0xcc1ceddb, 0xa58dc466, 0xd98f53bf, 0xc23171b1,
    0x99d751f5, 0xb0cbd5d5, 0x1c51a0a8, 0x3b583faf, 0x94e9ca26, 0xcedad392,
};

static uint32_t kTestPrivateExponentComponentP[kRsa3072NumWords / 2] = {
    0x8d4c3841, 0xb47d2df,  0x78d7e5cd, 0xa813c5d1, 0x88a5ea0e, 0x7e645d47,
    0xa0234973, 0x9e9f6c13, 0x63aaa6bc, 0xe9499bd,  0xc460330c, 0x8c6f1c30,
    0x574669c4, 0x40f08ad8, 0xf7ecd674, 0xe6f44b6,  0x973659ae, 0x8f8a5927,
    0xd3487ce8, 0x60c3d55e, 0xb435892b, 0x5666de34, 0x794e7453, 0x45fd426a,
    0xe44fbfd5, 0x66bc0c93, 0x3aa737d2, 0x90fca9f9, 0x69e76acd, 0x6ba875fa,
    0x55e10f38, 0xf6b12022, 0x1a119c21, 0x58b5c16b, 0x14bf7b98, 0x1c80a387,
    0x280ab1c4, 0x84f513c3, 0xf6a4c8b,  0x687217ba, 0xe087f11d, 0x8d4259bc,
    0x454af9,   0xcff6d9cd, 0xac279129, 0x351b6fb4, 0x85357c74, 0x866381de,
};

static uint32_t kTestPrivateExponentComponentQ[kRsa3072NumWords / 2] = {
    0x4f94d00b, 0xcaacdde0, 0x81aa7fd7, 0xc265ae41, 0x326c9940, 0x8b427abf,
    0x3a8f513a, 0x35580c14, 0xebfa05c1, 0x52b27b33, 0x7619c80c, 0xa5e076dc,
    0xdef8c89c, 0xd42498c4, 0x753d842c, 0x44858361, 0x7e0b2e5f, 0x9da6b987,
    0x9868b4ce, 0xb7ecb1ac, 0x381254c5, 0xa273df4e, 0x29aa3f66, 0xe8fd5603,
    0xd6fe3210, 0x24041fe2, 0xf4c60024, 0x42cb4edf, 0x94713c64, 0xd3f5212c,
    0x10f126,   0xad37458f, 0x820f1d42, 0x5a0b1136, 0xe000246d, 0x77fdaca4,
    0xf244711b, 0xdceeefad, 0xc968d70a, 0xb73ee87d, 0xc0e913b3, 0x70629c,
    0xdbf9ea12, 0xeeb64955, 0x3d24759f, 0x2ec3bd38, 0xd0def2f7, 0x8d57af0b,
};

static uint32_t kTestCrtCoefficient[kRsa3072NumWords / 2] = {
    0x95932eaa, 0x59702111, 0x2ac49f32, 0x294792d7, 0x8ad3e891, 0x5b5a0c15,
    0x2b6e7c2d, 0x56e13332, 0xe2a6188e, 0x4062dc8d, 0xdaa62268, 0xf28f7c86,
    0x959632bd, 0xb85a7f81, 0xa5885ac,  0x44a95688, 0x871011f5, 0xd5fae09d,
    0xd18a788a, 0x17dc874f, 0x1c9367f2, 0x94ba8be8, 0xdcd7ea3c, 0xd872e83e,
    0x58690c6c, 0xf7f17944, 0x5b7a09ef, 0x2c9440e6, 0x98a67461, 0xc0ffe122,
    0x17a3638,  0x733a43ea, 0x78476d0d, 0xaf954cab, 0x687da12f, 0x7480080e,
    0xd573ce7c, 0xdc8e3c64, 0xa740368d, 0x17af4d83, 0xc45af0e2, 0xdd51be35,
    0xfe85d4f0, 0xa0871757, 0xda54186d, 0x9b3ed119, 0xfe9b64d6, 0x66f89262,
};

static uint32_t kTestInvalidPrivateExponentComponentP[kRsa3072NumWords / 2] = {
    0x8d4c3841, 0xb47d2df,  0x78d7e5cd, 0xa813c5d1, 0x88a5ea0e, 0x7e645d47,
    0xa0234973, 0x9e9f6c13, 0x63aaa6bc, 0xe9499bd,  0xc460330c, 0x8c6f1c30,
    0x574669c4, 0x40f08ad8, 0xf7ecd674, 0xe6f44b6,  0x973659ae, 0x8f8a5927,
    0xd3487ce8, 0x60c3d55e, 0xb435892b, 0x5666df34, 0x794e7453, 0x45fd426a,
    0xe44fbfd5, 0x66bc0c93, 0x3aa737d2, 0x90fca9f9, 0x69e76acd, 0x6ba875fa,
    0x55e10f38, 0xf6b12022, 0x1a119c21, 0x58b5c16b, 0x14bf7b98, 0x1c80a387,
    0x280ab1c4, 0x84f513c3, 0xf6a4c8b,  0x687217ba, 0xe087f11d, 0x8d4259bc,
    0x454af9,   0xcff6d9cd, 0xac279129, 0x351b6fb4, 0x85357c74, 0x866381de,
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
  TRY(otcrypto_rsa_public_key_construct(kOtcryptoRsaSize3072, modulus,
                                        kTestPublicExponent, &public_key));

  // Deconstruct the public key
  uint32_t roundtrip_modulus_data[kRsa3072NumWords] = {0};
  otcrypto_word32_buf_t roundtrip_modulus = {
      .data = roundtrip_modulus_data,
      .len = ARRAYSIZE(roundtrip_modulus_data),
  };
  uint32_t roundtrip_public_exponent = 0;
  TRY(otcrypto_rsa_public_key_deconstruct(&public_key, roundtrip_modulus,
                                          &roundtrip_public_exponent));

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
      .key_length = kOtcryptoRsa3072PrivateKeyBytes,
      .hw_backed = kHardenedBoolFalse,
      .security_level = kOtcryptoKeySecurityLevelPassiveRemote,
      .exportable = kHardenedBoolTrue,
  };
  size_t keyblob_words =
      ceil_div(kOtcryptoRsa3072PrivateKeyblobBytes, sizeof(uint32_t));
  uint32_t keyblob[keyblob_words];
  otcrypto_blinded_key_t private_key = {
      .config = private_key_config,
      .keyblob = keyblob,
      .keyblob_length = kOtcryptoRsa3072PrivateKeyblobBytes,
  };
  TRY(otcrypto_rsa_private_key_construct(kOtcryptoRsaSize3072, p, q, d_p, d_q,
                                         i_q, &private_key));

  // Deconstruct the public key
  uint32_t roundtrip_p_data[kRsa3072NumWords / 2] = {0};
  otcrypto_word32_buf_t roundtrip_p = {
      .data = roundtrip_p_data,
      .len = ARRAYSIZE(roundtrip_p_data),
  };
  uint32_t roundtrip_q_data[kRsa3072NumWords / 2] = {0};
  otcrypto_word32_buf_t roundtrip_q = {
      .data = roundtrip_q_data,
      .len = ARRAYSIZE(roundtrip_p_data),
  };
  uint32_t roundtrip_d_p_data[kRsa3072NumWords / 2] = {0};
  otcrypto_word32_buf_t roundtrip_d_p = {
      .data = roundtrip_d_p_data,
      .len = ARRAYSIZE(roundtrip_p_data),
  };
  uint32_t roundtrip_d_q_data[kRsa3072NumWords / 2] = {0};
  otcrypto_word32_buf_t roundtrip_d_q = {
      .data = roundtrip_d_q_data,
      .len = ARRAYSIZE(roundtrip_d_q_data),
  };
  uint32_t roundtrip_i_q_data[kRsa3072NumWords / 2] = {0};
  otcrypto_word32_buf_t roundtrip_i_q = {
      .data = roundtrip_i_q_data,
      .len = ARRAYSIZE(roundtrip_i_q_data),
  };
  TRY(otcrypto_rsa_private_key_deconstruct(&private_key, roundtrip_p,
                                           roundtrip_q, roundtrip_d_p,
                                           roundtrip_d_q, roundtrip_i_q));

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
  uint32_t public_key_data[ceil_div(kOtcryptoRsa3072PublicKeyBytes,
                                    sizeof(uint32_t))];
  otcrypto_unblinded_key_t public_key = {
      .key_mode = kTestKeyMode,
      .key_length = kOtcryptoRsa3072PublicKeyBytes,
      .key = public_key_data,
  };
  TRY(otcrypto_rsa_public_key_construct(kOtcryptoRsaSize3072, modulus,
                                        kTestPublicExponent, &public_key));

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
      .key_length = kOtcryptoRsa3072PrivateKeyBytes,
      .hw_backed = kHardenedBoolFalse,
      .security_level = kOtcryptoKeySecurityLevelPassiveRemote,
      .exportable = kHardenedBoolTrue,
  };
  size_t keyblob_words =
      ceil_div(kOtcryptoRsa3072PrivateKeyblobBytes, sizeof(uint32_t));
  uint32_t keyblob[keyblob_words];
  otcrypto_blinded_key_t private_key = {
      .config = private_key_config,
      .keyblob = keyblob,
      .keyblob_length = kOtcryptoRsa3072PrivateKeyblobBytes,
  };
  hardened_bool_t key_valid = kHardenedBoolFalse;
  TRY(otcrypto_rsa_private_key_construct_and_check(
      p, q, d_p, d_q, i_q, &public_key, kHardenedBoolFalse, &private_key,
      &key_valid));

  TRY_CHECK(key_valid == kHardenedBoolTrue);

  // Deconstruct the public key
  uint32_t roundtrip_p_data[kRsa3072NumWords / 2] = {0};
  otcrypto_word32_buf_t roundtrip_p = {
      .data = roundtrip_p_data,
      .len = ARRAYSIZE(roundtrip_p_data),
  };
  uint32_t roundtrip_q_data[kRsa3072NumWords / 2] = {0};
  otcrypto_word32_buf_t roundtrip_q = {
      .data = roundtrip_q_data,
      .len = ARRAYSIZE(roundtrip_p_data),
  };
  uint32_t roundtrip_d_p_data[kRsa3072NumWords / 2] = {0};
  otcrypto_word32_buf_t roundtrip_d_p = {
      .data = roundtrip_d_p_data,
      .len = ARRAYSIZE(roundtrip_p_data),
  };
  uint32_t roundtrip_d_q_data[kRsa3072NumWords / 2] = {0};
  otcrypto_word32_buf_t roundtrip_d_q = {
      .data = roundtrip_d_q_data,
      .len = ARRAYSIZE(roundtrip_d_q_data),
  };
  uint32_t roundtrip_i_q_data[kRsa3072NumWords / 2] = {0};
  otcrypto_word32_buf_t roundtrip_i_q = {
      .data = roundtrip_i_q_data,
      .len = ARRAYSIZE(roundtrip_i_q_data),
  };
  TRY(otcrypto_rsa_private_key_deconstruct(&private_key, roundtrip_p,
                                           roundtrip_q, roundtrip_d_p,
                                           roundtrip_d_q, roundtrip_i_q));

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
  uint32_t public_key_data[ceil_div(kOtcryptoRsa3072PublicKeyBytes,
                                    sizeof(uint32_t))];
  otcrypto_unblinded_key_t public_key = {
      .key_mode = kTestKeyMode,
      .key_length = kOtcryptoRsa3072PublicKeyBytes,
      .key = public_key_data,
  };
  TRY(otcrypto_rsa_public_key_construct(kOtcryptoRsaSize3072, modulus,
                                        kTestPublicExponent, &public_key));

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
      .key_length = kOtcryptoRsa3072PrivateKeyBytes,
      .hw_backed = kHardenedBoolFalse,
      .security_level = kOtcryptoKeySecurityLevelPassiveRemote,
  };
  size_t keyblob_words =
      ceil_div(kOtcryptoRsa3072PrivateKeyblobBytes, sizeof(uint32_t));
  uint32_t keyblob[keyblob_words];
  otcrypto_blinded_key_t private_key = {
      .config = private_key_config,
      .keyblob = keyblob,
      .keyblob_length = kOtcryptoRsa3072PrivateKeyblobBytes,
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
