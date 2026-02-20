// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/base/hardened.h"
#include "sw/device/lib/crypto/drivers/entropy.h"
#include "sw/device/lib/crypto/impl/ecc/p256.h"
#include "sw/device/lib/crypto/impl/keyblob.h"
#include "sw/device/lib/crypto/include/ecc_p256.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"

enum {
  /* Number of 32-bit words in a P-256 public key. */
  kP256PublicKeyWords = 512 / 32,
  /* Number of bytes in a P-256 private key. */
  kP256PrivateKeyBytes = 256 / 8,
};

static uint32_t kTestCoordinateX[kP256CoordWords] = {
    0x1424d885, 0xd6feda39, 0x98b8b7e8, 0x20209c6a,
    0x48d5cb3b, 0xd480a652, 0xd57bf015, 0xbd5cb207,
};

static uint32_t kTestCoordinateY[kP256CoordWords] = {
    0xee9e8557, 0xbbb1d213, 0x0d45e2f0, 0x842dabf7,
    0x9c83325a, 0x637bc906, 0xcb96e9a6, 0x5ad30f11,
};

static uint32_t kTestScalarShare0[kP256MaskedScalarShareWords] = {
    0x44f7d3ee, 0xa8c33b94, 0x62acc41d, 0xcc8981df,
    0x96401c3c, 0x5d8f7960, 0xcae5d68b, 0xe8ae4fa7,
};

static uint32_t kTestScalarShare1[kP256MaskedScalarShareWords] = {
    0x3ea31e9f, 0x88d00929, 0xc0d38cf2, 0x96236b4f,
    0xb1799dd0, 0xde58fd04, 0xda594df1, 0x87a18c1d,
};

static uint32_t kTestInvalidCoordinateY[kP256CoordWords] = {
    0xee9f8557, 0xbbb1d213, 0x0d45e2f0, 0x842dabf7,
    0x9c83325a, 0x637bc906, 0xcb96e9a6, 0x5ad30f11,
};

// ECC P-256 key mode for testing.
static const otcrypto_key_mode_t kTestKeyMode = kOtcryptoKeyModeEcdsaP256;

// ECC private key config for testing.
static const otcrypto_key_config_t kTestKeyConfig = {
    .version = kOtcryptoLibVersion1,
    .key_mode = kTestKeyMode,
    .key_length = kP256PrivateKeyBytes,
    .hw_backed = kHardenedBoolFalse,
    .security_level = kOtcryptoKeySecurityLevelPassiveRemote,
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
  uint32_t public_key_data[kP256PublicKeyWords];
  otcrypto_unblinded_key_t public_key = {
      .key_mode = kTestKeyMode,
      .key_length = sizeof(public_key_data),
      .key = public_key_data,
  };
  otcrypto_p256_public_key_construct(x, y, &public_key);

  // Deconstruct the public key.
  uint32_t roundtrip_x_data[kP256CoordWords] = {0};
  otcrypto_word32_buf_t roundtrip_x = {
      .data = roundtrip_x_data,
      .len = ARRAYSIZE(roundtrip_x_data),
  };
  uint32_t roundtrip_y_data[kP256CoordWords] = {0};
  otcrypto_word32_buf_t roundtrip_y = {
      .data = roundtrip_y_data,
      .len = ARRAYSIZE(roundtrip_y_data),
  };
  otcrypto_p256_public_key_deconstruct(&public_key, roundtrip_x, roundtrip_y);

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
  uint32_t public_key_data[kP256PublicKeyWords];
  otcrypto_unblinded_key_t public_key = {
      .key_mode = kTestKeyMode,
      .key_length = sizeof(public_key_data),
      .key = public_key_data,
  };
  hardened_bool_t key_valid = kHardenedBoolFalse;
  otcrypto_p256_public_key_construct_and_check(x, y, &public_key, &key_valid);

  // Ensure the constructed key is valid.
  TRY_CHECK(key_valid == kHardenedBoolTrue);

  // Deconstruct the public key.
  uint32_t roundtrip_x_data[kP256CoordWords] = {0};
  otcrypto_word32_buf_t roundtrip_x = {
      .data = roundtrip_x_data,
      .len = ARRAYSIZE(roundtrip_x_data),
  };
  uint32_t roundtrip_y_data[kP256CoordWords] = {0};
  otcrypto_word32_buf_t roundtrip_y = {
      .data = roundtrip_y_data,
      .len = ARRAYSIZE(roundtrip_y_data),
  };
  otcrypto_p256_public_key_deconstruct(&public_key, roundtrip_x, roundtrip_y);

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
  uint32_t public_key_data[kP256PublicKeyWords];
  otcrypto_unblinded_key_t public_key = {
      .key_mode = kTestKeyMode,
      .key_length = sizeof(public_key_data),
      .key = public_key_data,
  };
  hardened_bool_t key_valid = kHardenedBoolFalse;
  otcrypto_p256_public_key_construct_and_check(x, y, &public_key, &key_valid);

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
  TRY(otcrypto_p256_private_key_construct(scalar_share0, scalar_share1,
                                          &private_key));

  // Deconstruct the private key.
  uint32_t roundtrip_scalar_share0_data[kP256MaskedScalarShareWords] = {0};
  otcrypto_word32_buf_t roundtrip_scalar_share0 = {
      .data = roundtrip_scalar_share0_data,
      .len = ARRAYSIZE(roundtrip_scalar_share0_data),
  };
  uint32_t roundtrip_scalar_share1_data[kP256MaskedScalarShareWords] = {0};
  otcrypto_word32_buf_t roundtrip_scalar_share1 = {
      .data = roundtrip_scalar_share1_data,
      .len = ARRAYSIZE(roundtrip_scalar_share1_data),
  };
  TRY(otcrypto_p256_private_key_deconstruct(
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
