// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/base/status.h"
#include "sw/device/lib/crypto/drivers/entropy.h"
#include "sw/device/lib/crypto/include/drbg.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/randomness_quality.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"

#include "hw/top_egret/sw/autogen/top_egret.h"

#define MODULE_ID MAKE_MODULE_ID('t', 's', 't')

OTTF_DEFINE_TEST_CONFIG();

static const uint32_t kTestSeed[12] = {
    0xfa735ddf, 0x9e6468a4, 0x5c3ba3dd, 0xb0b079ca, 0x9c410056, 0x9d877acb,
    0xb39decdf, 0xe594e42e, 0xde511b53, 0x760fa316, 0x4c476292, 0x10c0be73,
};
static const uint32_t kExpOutput[16] = {
    0xd97cc0d1, 0xf1a7f85a, 0x4cc81210, 0xcbb88be4, 0x999e1887, 0xb1cc0fd4,
    0x9b611c77, 0x22ab82df, 0x2fdcb180, 0x91f38125, 0x0cacf764, 0xb3940451,
    0xb7413ca4, 0x4c5117db, 0xae07b187, 0xc5013e79,
};
static const uint32_t kExpOutputWithPerso[16] = {
    0x6798bd12, 0x7a39f3c9, 0x082b990e, 0x5d31d9d3, 0x0d897097, 0xc291b0db,
    0xa3527fd2, 0xb3a2c4b7, 0xbeefbfae, 0x57323e94, 0x6b5d44c3, 0x54c1ed89,
    0x2622114f, 0xee187c45, 0xb24c2fce, 0xa9e9b088,
};
static const uint32_t kExpOutputWithShortAddl[16] = {
    0xa2bd5a18, 0xbf18a5d9, 0xcef2fc18, 0x363c98a2, 0x88f278c3, 0xf8195979,
    0x0928e8d6, 0xbc84fd2a, 0x26dc531e, 0xef4cfa83, 0x1c992828, 0x9db8f9f6,
    0x6b24cbdc, 0x85d4aed7, 0xbc54474a, 0x3b0bb22e,
};
static const otcrypto_const_byte_buf_t kEmptyBuffer = {
    .data = NULL,
    .len = 0,
};
static const uint8_t kPersoString[34] = "This is a personalization string.";
static const otcrypto_const_byte_buf_t kPersoStringBuffer = {
    .data = kPersoString,
    .len = sizeof(kPersoString),
};
static const uint8_t kShortAddl[4] = {0x01, 0x02, 0x03, 0x04};
static const otcrypto_const_byte_buf_t kShortAddlBuffer = {
    .data = kShortAddl,
    .len = sizeof(kShortAddl),
};

static status_t kat_test(void) {
  otcrypto_const_byte_buf_t entropy = {
      .data = (const unsigned char *)kTestSeed,
      .len = sizeof(kTestSeed),
  };

  // Instantiate DRBG.
  TRY(otcrypto_drbg_manual_instantiate(entropy, /*perso_string=*/kEmptyBuffer));

  uint32_t actual_output_words[ARRAYSIZE(kExpOutput)];
  otcrypto_word32_buf_t actual_output = {
      .data = actual_output_words,
      .len = ARRAYSIZE(actual_output_words),
  };

  // Generate output twice.
  LOG_INFO("Generating...");
  TRY(otcrypto_drbg_manual_generate(/*additional_input=*/kEmptyBuffer,
                                    actual_output));
  LOG_INFO("Generating again...");
  TRY(otcrypto_drbg_manual_generate(/*additional_input=*/kEmptyBuffer,
                                    actual_output));

  // Compare second result to expected output.
  TRY_CHECK_ARRAYS_EQ(kExpOutput, actual_output_words, ARRAYSIZE(kExpOutput));

  // Run uninstantiate to allow subsequent tests to instantiate the DRBG.
  return otcrypto_drbg_uninstantiate();
}

static status_t perso_string_test(void) {
  otcrypto_const_byte_buf_t entropy = {
      .data = (const unsigned char *)kTestSeed,
      .len = sizeof(kTestSeed),
  };

  // Instantiate DRBG.
  TRY(otcrypto_drbg_manual_instantiate(entropy, kPersoStringBuffer));

  uint32_t actual_output_words[ARRAYSIZE(kExpOutput)];
  otcrypto_word32_buf_t actual_output = {
      .data = actual_output_words,
      .len = ARRAYSIZE(actual_output_words),
  };

  // Generate output twice.
  LOG_INFO("Generating...");
  TRY(otcrypto_drbg_manual_generate(/*additional_input=*/kEmptyBuffer,
                                    actual_output));
  LOG_INFO("Generating again...");
  TRY(otcrypto_drbg_manual_generate(/*additional_input=*/kEmptyBuffer,
                                    actual_output));

  // Compare second result to expected output.
  TRY_CHECK_ARRAYS_EQ(kExpOutputWithPerso, actual_output_words,
                      ARRAYSIZE(kExpOutputWithPerso));

  // Run uninstantiate to allow subsequent tests to instantiate the DRBG.
  return otcrypto_drbg_uninstantiate();
}

static status_t short_addl_test(void) {
  otcrypto_const_byte_buf_t entropy = {
      .data = (const unsigned char *)kTestSeed,
      .len = sizeof(kTestSeed),
  };

  // Instantiate DRBG.
  TRY(otcrypto_drbg_manual_instantiate(entropy, /*perso_string=*/kEmptyBuffer));

  uint32_t actual_output_words[ARRAYSIZE(kExpOutputWithShortAddl)];
  otcrypto_word32_buf_t actual_output = {
      .data = actual_output_words,
      .len = ARRAYSIZE(actual_output_words),
  };

  // Generate output twice.
  LOG_INFO("Generating...");
  TRY(otcrypto_drbg_manual_generate(kShortAddlBuffer, actual_output));
  LOG_INFO("Generating again...");
  TRY(otcrypto_drbg_manual_generate(kShortAddlBuffer, actual_output));

  // Compare second result to expected output.
  TRY_CHECK_ARRAYS_EQ(kExpOutputWithShortAddl, actual_output_words,
                      ARRAYSIZE(kExpOutputWithShortAddl));

  // Run uninstantiate to allow subsequent tests to instantiate the DRBG.
  return otcrypto_drbg_uninstantiate();
}

static status_t short_output_test(void) {
  otcrypto_const_byte_buf_t entropy = {
      .data = (const unsigned char *)kTestSeed,
      .len = sizeof(kTestSeed),
  };

  // Instantiate DRBG.
  TRY(otcrypto_drbg_manual_instantiate(entropy, /*perso_string=*/kEmptyBuffer));

  uint32_t actual_output_words[ARRAYSIZE(kExpOutput) - 3];
  otcrypto_word32_buf_t actual_output = {
      .data = actual_output_words,
      .len = ARRAYSIZE(actual_output_words),
  };

  // Generate output twice.
  LOG_INFO("Generating...");
  TRY(otcrypto_drbg_manual_generate(/*additional_input=*/kEmptyBuffer,
                                    actual_output));
  LOG_INFO("Generating again...");
  TRY(otcrypto_drbg_manual_generate(/*additional_input=*/kEmptyBuffer,
                                    actual_output));

  // Compare second result to expected output.
  TRY_CHECK_ARRAYS_EQ(kExpOutput, actual_output_words,
                      ARRAYSIZE(actual_output_words));

  // Run uninstantiate to allow subsequent tests to instantiate the DRBG.
  return otcrypto_drbg_uninstantiate();
}

static status_t random_test(void) {
  // Instantiate DRBG.
  TRY(otcrypto_drbg_instantiate(/*perso_string=*/kEmptyBuffer));

  // Generate a relatively large amount of output data.
  uint32_t output_data[1024];
  otcrypto_word32_buf_t output = {
      .data = output_data,
      .len = ARRAYSIZE(output_data),
  };
  TRY(otcrypto_drbg_generate(/*additional_input=*/kEmptyBuffer, output));

  // Run a basic randomness-quality check on the output.
  TRY(randomness_quality_monobit_test(
      (unsigned char *)output_data, sizeof(output_data),
      kRandomnessQualitySignificanceOnePercent));

  // Run uninstantiate to allow subsequent tests to instantiate the DRBG.
  return otcrypto_drbg_uninstantiate();
}

bool test_main(void) {
  status_t result = OK_STATUS();

  // Initialize the entropy complex.
  CHECK_STATUS_OK(entropy_complex_init());
  CHECK_STATUS_OK(entropy_complex_check());

  EXECUTE_TEST(result, kat_test);
  EXECUTE_TEST(result, perso_string_test);
  EXECUTE_TEST(result, short_addl_test);
  EXECUTE_TEST(result, short_output_test);
  EXECUTE_TEST(result, random_test);
  return status_ok(result);
}
