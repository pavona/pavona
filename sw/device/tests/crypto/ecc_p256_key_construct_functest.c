// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/crypto/drivers/entropy.h"
#include "sw/device/lib/crypto/impl/ecc/p256.h"
#include "sw/device/lib/crypto/include/ecc_p256.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"

static uint32_t kTestCoordinateX[kP256CoordWords] = {
    0x1424d885, 0xd6feda39, 0x98b8b7e8, 0x20209c6a,
    0x48d5cb3b, 0xd480a652, 0xd57bf015, 0xbd5cb207,
};

static uint32_t kTestCoordinateY[kP256CoordWords] = {
    0xee9e8557, 0xbbb1d213, 0x0d45e2f0, 0x842dabf7,
    0x9c83325a, 0x637bc906, 0xcb96e9a6, 0x5ad30f11,
};

// ECC P-256 key mode for testing.
static const otcrypto_key_mode_t kTestKeyMode = kOtcryptoKeyModeEcdsaP256;

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
  uint32_t public_key_data[ceil_div(sizeof(p256_point_t), sizeof(uint32_t))];
  otcrypto_unblinded_key_t public_key = {
      .key_mode = kTestKeyMode,
      .key_length = sizeof(p256_point_t),
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

OTTF_DEFINE_TEST_CONFIG();

bool test_main(void) {
  status_t test_result = OK_STATUS();
  CHECK_STATUS_OK(entropy_complex_init());
  EXECUTE_TEST(test_result, public_key_roundtrip_test);
  return status_ok(test_result);
}
