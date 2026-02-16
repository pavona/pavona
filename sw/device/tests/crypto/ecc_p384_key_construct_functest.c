// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/base/hardened.h"
#include "sw/device/lib/crypto/drivers/entropy.h"
#include "sw/device/lib/crypto/impl/ecc/p384.h"
#include "sw/device/lib/crypto/impl/keyblob.h"
#include "sw/device/lib/crypto/include/ecc_p384.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"

enum {
  /* Number of 32-bit words in a P-384 public key. */
  kP384PublicKeyWords = 768 / 32,
  /* Number of bytes in a P-384 private key. */
  kP384PrivateKeyBytes = 384 / 8,
};

static uint32_t kTestCoordinateX[kP384CoordWords] = {
    0x39e0fd2a, 0x6365fece, 0x8a4c839b, 0x11c0d814, 0x4e870889, 0xb715f417,
    0x9f78ef78, 0xc05b19c8, 0x23684480, 0x9ec9e11e, 0x62bfee9a, 0x7ae1f3da,
};

static uint32_t kTestCoordinateY[kP384CoordWords] = {
    0x252d467e, 0xc1ff6aa2, 0x8ebbd5cd, 0xd9a6c9c1, 0x773ce5dd, 0xbb7c3f64,
    0xb6185f43, 0x5c4a6886, 0x52d1651d, 0x08cc2fb9, 0x90b32c57, 0xd6537c67,
};

static uint32_t kTestScalarShare0[kP384MaskedScalarShareWords] = {
    0x7dbec731, 0x47441bf1, 0x05d839cf, 0x0c9aeec0, 0xa38ae6f8, 0x89828101,
    0xb5a6e4b1, 0x04bc8366, 0x06bd132b, 0x9cb36dd0, 0xfa9b3a2d, 0xeaa102af,
};

static uint32_t kTestScalarShare1[kP384MaskedScalarShareWords] = {
    0xb4161db4, 0xd1174025, 0xda1541ad, 0xfd7f5e18, 0xf38bed8a, 0xdaca4c30,
    0x80c495c3, 0x226c98e5, 0x691b28fa, 0xe685ac7b, 0x60022750, 0x1222f28d,
};

static uint32_t kTestInvalidCoordinateY[kP384CoordWords] = {
    0x252d467f, 0xc1ff6aa2, 0x8ebbd5cd, 0xd9a6c9c1, 0x773ce5dd, 0xbb7c3f64,
    0xb6185f43, 0x5c4a6886, 0x52d1651d, 0x08cc2fb9, 0x90b32c57, 0xd6537c67,
};

// ECC P-384 key mode for testing.
static const otcrypto_key_mode_t kTestKeyMode = kOtcryptoKeyModeEcdsaP384;

// ECC private key config for testing.
static const otcrypto_key_config_t kTestKeyConfig = {
    .version = kOtcryptoLibVersion1,
    .key_mode = kTestKeyMode,
    .key_length = kP384PrivateKeyBytes,
    .hw_backed = kHardenedBoolFalse,
    .security_level = kOtcryptoKeySecurityLevelLow,
    .exportable = kHardenedBoolTrue,
};

status_t public_key_roundtrip_test(void) {
  // Construct the public key.
  otcrypto_const_word32_buf_t x = {
      .data = kTestCoordinateX,
      .len = ARRAYSIZE(kTestCoordinateX),
  };
  otcrypto_const_word32_buf_t y = {
      .data = kTestCoordinateY,
      .len = ARRAYSIZE(kTestCoordinateY),
  };
  uint32_t public_key_data[kP384PublicKeyWords];
  otcrypto_unblinded_key_t public_key = {
      .key_mode = kTestKeyMode,
      .key_length = sizeof(public_key_data),
      .key = public_key_data,
  };
  otcrypto_p384_public_key_construct(x, y, &public_key);

  // Deconstruct the public key.
  uint32_t roundtrip_x_data[kP384CoordWords] = {0};
  otcrypto_word32_buf_t roundtrip_x = {
      .data = roundtrip_x_data,
      .len = ARRAYSIZE(roundtrip_x_data),
  };
  uint32_t roundtrip_y_data[kP384CoordWords] = {0};
  otcrypto_word32_buf_t roundtrip_y = {
      .data = roundtrip_y_data,
      .len = ARRAYSIZE(roundtrip_y_data),
  };
  otcrypto_p384_public_key_deconstruct(&public_key, roundtrip_x, roundtrip_y);

  // Check that the round trip had the expected results.
  TRY_CHECK(roundtrip_x.len == ARRAYSIZE(kTestCoordinateX));
  TRY_CHECK_ARRAYS_EQ(roundtrip_x.data, kTestCoordinateX,
                      ARRAYSIZE(kTestCoordinateX));
  TRY_CHECK(roundtrip_y.len == ARRAYSIZE(kTestCoordinateY));
  TRY_CHECK_ARRAYS_EQ(roundtrip_y.data, kTestCoordinateY,
                      ARRAYSIZE(kTestCoordinateY));
  return OK_STATUS();
}

status_t public_key_check_valid_roundtrip_test(void) {
  // Construct the public key.
  otcrypto_const_word32_buf_t x = {
      .data = kTestCoordinateX,
      .len = ARRAYSIZE(kTestCoordinateX),
  };
  otcrypto_const_word32_buf_t y = {
      .data = kTestCoordinateY,
      .len = ARRAYSIZE(kTestCoordinateY),
  };
  uint32_t public_key_data[kP384PublicKeyWords];
  otcrypto_unblinded_key_t public_key = {
      .key_mode = kTestKeyMode,
      .key_length = sizeof(public_key_data),
      .key = public_key_data,
  };
  hardened_bool_t key_valid = kHardenedBoolFalse;
  otcrypto_p384_public_key_construct_and_check(x, y, &public_key, &key_valid);

  // Ensure the constructed key is valid.
  TRY_CHECK(key_valid == kHardenedBoolTrue);

  // Deconstruct the public key.
  uint32_t roundtrip_x_data[kP384CoordWords] = {0};
  otcrypto_word32_buf_t roundtrip_x = {
      .data = roundtrip_x_data,
      .len = ARRAYSIZE(roundtrip_x_data),
  };
  uint32_t roundtrip_y_data[kP384CoordWords] = {0};
  otcrypto_word32_buf_t roundtrip_y = {
      .data = roundtrip_y_data,
      .len = ARRAYSIZE(roundtrip_y_data),
  };
  otcrypto_p384_public_key_deconstruct(&public_key, roundtrip_x, roundtrip_y);

  // Check that the round trip had the expected results.
  TRY_CHECK(roundtrip_x.len == ARRAYSIZE(kTestCoordinateX));
  TRY_CHECK_ARRAYS_EQ(roundtrip_x.data, kTestCoordinateX,
                      ARRAYSIZE(kTestCoordinateX));
  TRY_CHECK(roundtrip_y.len == ARRAYSIZE(kTestCoordinateY));
  TRY_CHECK_ARRAYS_EQ(roundtrip_y.data, kTestCoordinateY,
                      ARRAYSIZE(kTestCoordinateY));
  return OK_STATUS();
}

status_t public_key_check_invalid(void) {
  // Construct the public key.
  otcrypto_const_word32_buf_t x = {
      .data = kTestCoordinateX,
      .len = ARRAYSIZE(kTestCoordinateX),
  };
  otcrypto_const_word32_buf_t y = {
      .data = kTestInvalidCoordinateY,
      .len = ARRAYSIZE(kTestInvalidCoordinateY),
  };
  uint32_t public_key_data[kP384PublicKeyWords];
  otcrypto_unblinded_key_t public_key = {
      .key_mode = kTestKeyMode,
      .key_length = sizeof(public_key_data),
      .key = public_key_data,
  };
  hardened_bool_t key_valid = kHardenedBoolFalse;
  otcrypto_p384_public_key_construct_and_check(x, y, &public_key, &key_valid);

  // Ensure the constructed key is invalid.
  TRY_CHECK(key_valid == kHardenedBoolFalse);
  return OK_STATUS();
}

status_t private_key_roundtrip_test(void) {
  // Construct the public key.
  otcrypto_const_word32_buf_t scalar_share0 = {
      .data = kTestScalarShare0,
      .len = ARRAYSIZE(kTestScalarShare0),
  };
  otcrypto_const_word32_buf_t scalar_share1 = {
      .data = kTestScalarShare1,
      .len = ARRAYSIZE(kTestScalarShare1),
  };
  size_t keyblob_words = 0;
  keyblob_num_words(kTestKeyConfig, &keyblob_words);
  uint32_t private_key_data[keyblob_words];
  otcrypto_blinded_key_t private_key = {
      .config = kTestKeyConfig,
      .keyblob_length = sizeof(private_key_data),
      .keyblob = private_key_data,
  };
  TRY(otcrypto_p384_private_key_construct(scalar_share0, scalar_share1,
                                          &private_key));

  // Deconstruct the private key.
  uint32_t roundtrip_scalar_share0_data[kP384MaskedScalarShareWords] = {0};
  otcrypto_word32_buf_t roundtrip_scalar_share0 = {
      .data = roundtrip_scalar_share0_data,
      .len = ARRAYSIZE(roundtrip_scalar_share0_data),
  };
  uint32_t roundtrip_scalar_share1_data[kP384MaskedScalarShareWords] = {0};
  otcrypto_word32_buf_t roundtrip_scalar_share1 = {
      .data = roundtrip_scalar_share1_data,
      .len = ARRAYSIZE(roundtrip_scalar_share1_data),
  };
  TRY(otcrypto_p384_private_key_deconstruct(
      &private_key, roundtrip_scalar_share0, roundtrip_scalar_share1));

  // Check that the round trip had the expected results.
  TRY_CHECK(roundtrip_scalar_share0.len == ARRAYSIZE(kTestScalarShare0));
  TRY_CHECK_ARRAYS_EQ(roundtrip_scalar_share0.data, kTestScalarShare0,
                      ARRAYSIZE(kTestScalarShare0));
  TRY_CHECK(roundtrip_scalar_share1.len == ARRAYSIZE(kTestScalarShare1));
  TRY_CHECK_ARRAYS_EQ(roundtrip_scalar_share1.data, kTestScalarShare1,
                      ARRAYSIZE(kTestScalarShare1));
  return OK_STATUS();
}
OTTF_DEFINE_TEST_CONFIG();

bool test_main(void) {
  status_t test_result = OK_STATUS();
  CHECK_STATUS_OK(entropy_complex_init());
  EXECUTE_TEST(test_result, public_key_roundtrip_test);
  EXECUTE_TEST(test_result, public_key_check_valid_roundtrip_test);
  EXECUTE_TEST(test_result, public_key_check_invalid);
  EXECUTE_TEST(test_result, private_key_roundtrip_test);
  return status_ok(test_result);
}
