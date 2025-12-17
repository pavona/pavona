// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/crypto/drivers/entropy.h"
#include "sw/device/lib/crypto/impl/ecc/p384.h"
#include "sw/device/lib/crypto/include/ecc_p384.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"

static uint32_t kTestCoordinateX[kP384CoordWords] = {
    0x39e0fd2a, 0x6365fece, 0x8a4c839b, 0x11c0d814, 0x4e870889, 0xb715f417,
    0x9f78ef78, 0xc05b19c8, 0x23684480, 0x9ec9e11e, 0x62bfee9a, 0x7ae1f3da,
};

static uint32_t kTestCoordinateY[kP384CoordWords] = {
    0x252d467e, 0xc1ff6aa2, 0x8ebbd5cd, 0xd9a6c9c1, 0x773ce5dd, 0xbb7c3f64,
    0xb6185f43, 0x5c4a6886, 0x52d1651d, 0x08cc2fb9, 0x90b32c57, 0xd6537c67,
};

// ECC P-384 key mode for testing.
static const otcrypto_key_mode_t kTestKeyMode = kOtcryptoKeyModeEcdsaP384;

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
  uint32_t public_key_data[ceil_div(sizeof(p384_point_t), sizeof(uint32_t))];
  otcrypto_unblinded_key_t public_key = {
      .key_mode = kTestKeyMode,
      .key_length = sizeof(p384_point_t),
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

OTTF_DEFINE_TEST_CONFIG();

bool test_main(void) {
  status_t test_result = OK_STATUS();
  CHECK_STATUS_OK(entropy_complex_init());
  EXECUTE_TEST(test_result, public_key_roundtrip_test);
  return status_ok(test_result);
}
