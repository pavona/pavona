// Copyright The mldsa-native project authors
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include <string.h>

#include "sw/device/lib/base/math.h"
#include "sw/device/lib/crypto/include/mldsa.h"
#include "sw/device/lib/crypto/include/sha3.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/profile.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"

OTTF_DEFINE_TEST_CONFIG();

// Benchmarking Approach:
//
// ML-DSA signing performance is probabilistic due to rejection sampling in
// Algorithm 2 (ML-DSA.Sign). The number of iterations varies per signature.
//
// To estimate expected signing time without extensive statistical sampling:
// 1. Measure signing time for messages requiring exactly 1 iteration
// 2. Measure signing time for messages requiring exactly 2 iterations
// 3. Calculate per-iteration cost: time_per_iter = time_2iter - time_1iter
// 4. Extrapolate to FIPS 204 expected iterations via linear interpolation:
//    expected_time = time_1iter + (FIPS204_expected - 1) * time_per_iter
//
// The test messages below were selected to deterministically produce
// 1 or 2 iterations when signing with the fixed test seed and randomness.
//
// The benchmark results are an approximation of the actual expected signing
// time as there are multiple rejection conditions resulting in varying
// iteration timing. We mitigate this by picking the messages resulting in 2
// iteration such that it in the first iteration the siganture is rejected
// due to the z-norm check which accounts for the vast majority of rejections
// (see Section 3.4 of the round-3 Dilithium specification).

// Optimized test messages for each parameter set (1 iteration each)
#define TEST_MSG_44 "Test message 12"
#define TEST_MSG_44_LEN (sizeof(TEST_MSG_44) - 1)
#define TEST_MSG_65 "Test message 5"
#define TEST_MSG_65_LEN (sizeof(TEST_MSG_65) - 1)
#define TEST_MSG_87 "Test message 2"
#define TEST_MSG_87_LEN (sizeof(TEST_MSG_87) - 1)

// Messages that result in 2 iterations (for benchmarking)
#define TEST_MSG_44_2ITER "Test message 3"
#define TEST_MSG_44_2ITER_LEN (sizeof(TEST_MSG_44_2ITER) - 1)
#define TEST_MSG_65_2ITER "Test message 56"
#define TEST_MSG_65_2ITER_LEN (sizeof(TEST_MSG_65_2ITER) - 1)
#define TEST_MSG_87_2ITER "Test message 24"
#define TEST_MSG_87_2ITER_LEN (sizeof(TEST_MSG_87_2ITER) - 1)

// FIPS 204 expected iteration counts for signing (scaled by 100)
// From FIPS 204 Table 1: Expected number of iterations of the
// main loop in Algorithm 2 (ML-DSA.Sign)
#define FIPS204_EXPECTED_ITERS_44 425  // 4.25
#define FIPS204_EXPECTED_ITERS_65 510  // 5.1
#define FIPS204_EXPECTED_ITERS_87 385  // 3.85

#define TEST_MSG_LEN (sizeof(TEST_MSG) - 1)

#define TEST_CTX "test_context_123"
#define TEST_CTX_LEN (sizeof(TEST_CTX) - 1)

static const uint8_t kKeypairSeed[32] = {
    0x93, 0x4d, 0x60, 0xb3, 0x56, 0x24, 0xd7, 0x40, 0xb3, 0x0a, 0x7f,
    0x22, 0x7a, 0xf2, 0xae, 0x7c, 0x67, 0x8e, 0x4e, 0x04, 0xe1, 0x3c,
    0x5f, 0x50, 0x9e, 0xad, 0xe2, 0xb7, 0x9a, 0xea, 0x77, 0xe2};

static const uint8_t kSignRnd[32] = {
    0x3e, 0x2a, 0x2e, 0xa6, 0xc9, 0xc4, 0x76, 0xfc, 0x49, 0x37, 0xb0,
    0x13, 0xc9, 0x93, 0xa7, 0x93, 0xd6, 0xc0, 0xab, 0x99, 0x60, 0x69,
    0x5b, 0xa8, 0x38, 0xf6, 0x49, 0xda, 0x53, 0x9c, 0xa3, 0xd0};

// Static work buffer for all ML-DSA operations
// Use the maximum size across all ML-DSA-87 operations
#define MLDSA_MAX(a, b) ((a) > (b) ? (a) : (b))
#define MLDSA_MAX_WORK_BUFFER_WORDS                           \
  MLDSA_MAX(MLDSA_MAX(kOtcryptoMldsa87WorkBufferKeypairWords, \
                      kOtcryptoMldsa87WorkBufferSignWords),   \
            kOtcryptoMldsa87WorkBufferVerifyWords)
static uint32_t mldsa_work_buffer[MLDSA_MAX_WORK_BUFFER_WORDS];

// Static buffers for all ML-DSA test operations (sized for ML-DSA-87)
static uint32_t mldsa_public_key_data[(kOtcryptoMldsa87PublicKeyBytes +
                                       (sizeof(uint32_t) - 1)) /
                                      sizeof(uint32_t)];
static uint32_t mldsa_secret_key_data[2 * ((kOtcryptoMldsa87SecretKeyBytes +
                                            (sizeof(uint32_t) - 1)) /
                                           sizeof(uint32_t))];
static uint32_t
    mldsa_signature[(kOtcryptoMldsa87SignatureBytes + (sizeof(uint32_t) - 1)) /
                    sizeof(uint32_t)];
static uint32_t mldsa_test_msg_buf[(TEST_MSG_87_LEN + (sizeof(uint32_t) - 1)) /
                                   sizeof(uint32_t)];
static uint32_t mldsa_test_ctx_buf[(TEST_CTX_LEN + (sizeof(uint32_t) - 1)) /
                                   sizeof(uint32_t)];

// SHA3-256 hash of expected ML-DSA-44 signature
static const uint8_t kMldsa44ExpectedSignatureHash[32] = {
    0xf5, 0x46, 0x33, 0x14, 0x02, 0xee, 0x16, 0x4b, 0xe1, 0x91, 0x5e,
    0xd5, 0x55, 0x4e, 0xf7, 0x35, 0x24, 0xb6, 0x30, 0x5b, 0xdc, 0x32,
    0xb5, 0x57, 0x15, 0xd1, 0x33, 0x2c, 0xf4, 0xd1, 0x9e, 0x46};

// SHA3-256 hash of expected ML-DSA-65 signature
static const uint8_t kMldsa65ExpectedSignatureHash[32] = {
    0x09, 0xa1, 0xbe, 0xaa, 0x0e, 0x8d, 0xa6, 0xab, 0x94, 0xd5, 0xf0,
    0x1e, 0x3d, 0xae, 0x2e, 0x11, 0x52, 0x86, 0x4c, 0xc4, 0x6a, 0xfd,
    0xea, 0x0f, 0x78, 0xec, 0x6d, 0x62, 0xcf, 0x39, 0xb3, 0x6d};

// SHA3-256 hash of expected ML-DSA-87 signature
static const uint8_t kMldsa87ExpectedSignatureHash[32] = {
    0x06, 0x10, 0x69, 0x43, 0x52, 0xf3, 0xe7, 0x58, 0xae, 0xb4, 0x5e,
    0x97, 0x0a, 0x87, 0x7f, 0x1b, 0x42, 0x7f, 0xc2, 0xcb, 0x0f, 0xbf,
    0x96, 0xa7, 0xeb, 0xd1, 0xed, 0x6d, 0x9c, 0x0a, 0xd6, 0x7c};

/**
 * Verify signature by comparing its SHA3-256 hash with expected hash.
 *
 * @param signature Pointer to signature buffer
 * @param signature_len Length of signature in bytes
 * @param expected_hash Expected SHA3-256 hash (32 bytes)
 */
static void verify_signature_hash(const uint8_t *signature,
                                  size_t signature_len,
                                  const uint8_t *expected_hash) {
  uint32_t digest[8];
  otcrypto_const_byte_buf_t sig_msg = {.data = signature, .len = signature_len};
  otcrypto_hash_digest_t hash_digest = {
      .data = digest, .len = 8, .mode = kOtcryptoHashModeSha3_256};
  CHECK_STATUS_OK(otcrypto_sha3_256(sig_msg, &hash_digest));
  CHECK_ARRAYS_EQ((uint8_t *)digest, expected_hash, 32);
}

static void test_mldsa44_derand(void) {
  // Set up public key struct
  otcrypto_unblinded_key_t public_key = {
      .key_mode = kOtcryptoKeyModeMldsa44,
      .key_length = kOtcryptoMldsa44PublicKeyBytes,
      .key = mldsa_public_key_data,
      .checksum = 0,
  };

  // Set up secret key struct
  otcrypto_key_config_t secret_key_config = {
      .version = kOtcryptoLibVersion1,
      .key_mode = kOtcryptoKeyModeMldsa44,
      .key_length = kOtcryptoMldsa44SecretKeyBytes,
      .hw_backed = kHardenedBoolFalse,
      .exportable = kHardenedBoolFalse,
      .security_level = kOtcryptoKeySecurityLevelPassiveRemote,
  };
  otcrypto_blinded_key_t secret_key = {
      .config = secret_key_config,
      .keyblob_length =
          2 * ceil_div(kOtcryptoMldsa44SecretKeyBytes, sizeof(uint32_t)) *
          sizeof(uint32_t),
      .keyblob = mldsa_secret_key_data,
      .checksum = 0,
  };

  otcrypto_const_byte_buf_t seed = {.data = kKeypairSeed,
                                    .len = sizeof(kKeypairSeed)};

  LOG_INFO("Generating keypair...");
  uint64_t t0 = profile_start();
  CHECK_STATUS_OK(otcrypto_mldsa44_keypair_derand(
      seed, &public_key, &secret_key, mldsa_work_buffer));
  profile_end_and_print(t0, "otcrypto_mldsa44_keypair_derand");

  LOG_INFO("Signing...");
  memcpy(mldsa_test_msg_buf, TEST_MSG_44, TEST_MSG_44_LEN);
  memcpy(mldsa_test_ctx_buf, TEST_CTX, TEST_CTX_LEN);

  otcrypto_const_byte_buf_t ctx = {.data = (const uint8_t *)mldsa_test_ctx_buf,
                                   .len = TEST_CTX_LEN};
  otcrypto_const_byte_buf_t rnd = {.data = kSignRnd, .len = sizeof(kSignRnd)};
  otcrypto_byte_buf_t sig_buf = {.data = (uint8_t *)mldsa_signature,
                                 .len = sizeof(mldsa_signature)};

#ifdef MLDSA_BENCHMARK_MODE
  // Benchmark 2-iteration message first
  uint64_t time_2iter;
  memcpy(mldsa_test_msg_buf, TEST_MSG_44_2ITER, TEST_MSG_44_2ITER_LEN);
  otcrypto_const_byte_buf_t msg_2iter = {
      .data = (const uint8_t *)mldsa_test_msg_buf,
      .len = TEST_MSG_44_2ITER_LEN};
  time_2iter = profile_start();
  CHECK_STATUS_OK(otcrypto_mldsa44_sign_derand(&secret_key, msg_2iter, ctx,
                                               kOtcryptoMldsaSignModeMldsa, rnd,
                                               sig_buf, mldsa_work_buffer));
  time_2iter = profile_end(time_2iter);
  LOG_INFO("2-iteration message signing time: %u cycles", (uint32_t)time_2iter);
#endif

  // Sign 1-iteration message
  memcpy(mldsa_test_msg_buf, TEST_MSG_44, TEST_MSG_44_LEN);
  otcrypto_const_byte_buf_t msg = {.data = (const uint8_t *)mldsa_test_msg_buf,
                                   .len = TEST_MSG_44_LEN};
  t0 = profile_start();
  CHECK_STATUS_OK(otcrypto_mldsa44_sign_derand(&secret_key, msg, ctx,
                                               kOtcryptoMldsaSignModeMldsa, rnd,
                                               sig_buf, mldsa_work_buffer));
  uint64_t time_1iter = profile_end(t0);

  verify_signature_hash((uint8_t *)mldsa_signature,
                        kOtcryptoMldsa44SignatureBytes,
                        kMldsa44ExpectedSignatureHash);

  LOG_INFO("1-iteration message signing time: %u cycles", (uint32_t)time_1iter);

#ifdef MLDSA_BENCHMARK_MODE
  // Calculate expected runtime for expected iterations (4.25)
  uint32_t time_per_iter = (uint32_t)(time_2iter - time_1iter);
  uint64_t expected_time =
      time_1iter + ((FIPS204_EXPECTED_ITERS_44 - 100) * time_per_iter) / 100;
  LOG_INFO("Expected signing time (4.25 iterations): %u cycles",
           (uint32_t)expected_time);
#endif

  LOG_INFO("Verifying...");
  hardened_bool_t verification_result;
  otcrypto_const_byte_buf_t sig_const = {.data = (uint8_t *)mldsa_signature,
                                         .len = kOtcryptoMldsa44SignatureBytes};
  t0 = profile_start();
  CHECK_STATUS_OK(otcrypto_mldsa44_verify(
      &public_key, msg, ctx, kOtcryptoMldsaSignModeMldsa, sig_const,
      &verification_result, mldsa_work_buffer));
  profile_end_and_print(t0, "otcrypto_mldsa44_verify");
  CHECK(verification_result == kHardenedBoolTrue,
        "Signature verification failed");
}

static void test_mldsa65_derand(void) {
  // Set up public key struct
  otcrypto_unblinded_key_t public_key = {
      .key_mode = kOtcryptoKeyModeMldsa65,
      .key_length = kOtcryptoMldsa65PublicKeyBytes,
      .key = mldsa_public_key_data,
      .checksum = 0,
  };

  // Set up secret key struct
  otcrypto_key_config_t secret_key_config = {
      .version = kOtcryptoLibVersion1,
      .key_mode = kOtcryptoKeyModeMldsa65,
      .key_length = kOtcryptoMldsa65SecretKeyBytes,
      .hw_backed = kHardenedBoolFalse,
      .exportable = kHardenedBoolFalse,
      .security_level = kOtcryptoKeySecurityLevelPassiveRemote,
  };
  otcrypto_blinded_key_t secret_key = {
      .config = secret_key_config,
      .keyblob_length =
          2 * ceil_div(kOtcryptoMldsa65SecretKeyBytes, sizeof(uint32_t)) *
          sizeof(uint32_t),
      .keyblob = mldsa_secret_key_data,
      .checksum = 0,
  };

  otcrypto_const_byte_buf_t seed = {.data = kKeypairSeed,
                                    .len = sizeof(kKeypairSeed)};

  LOG_INFO("Generating keypair...");
  uint64_t t0 = profile_start();
  CHECK_STATUS_OK(otcrypto_mldsa65_keypair_derand(
      seed, &public_key, &secret_key, mldsa_work_buffer));
  profile_end_and_print(t0, "otcrypto_mldsa65_keypair_derand");

  LOG_INFO("Signing...");
  memcpy(mldsa_test_msg_buf, TEST_MSG_65, TEST_MSG_65_LEN);
  memcpy(mldsa_test_ctx_buf, TEST_CTX, TEST_CTX_LEN);

  otcrypto_const_byte_buf_t ctx = {.data = (const uint8_t *)mldsa_test_ctx_buf,
                                   .len = TEST_CTX_LEN};
  otcrypto_const_byte_buf_t rnd = {.data = kSignRnd, .len = sizeof(kSignRnd)};
  otcrypto_byte_buf_t sig_buf = {.data = (uint8_t *)mldsa_signature,
                                 .len = sizeof(mldsa_signature)};

#ifdef MLDSA_BENCHMARK_MODE
  // Benchmark 2-iteration message first
  uint64_t time_2iter;
  memcpy(mldsa_test_msg_buf, TEST_MSG_65_2ITER, TEST_MSG_65_2ITER_LEN);
  otcrypto_const_byte_buf_t msg_2iter = {
      .data = (const uint8_t *)mldsa_test_msg_buf,
      .len = TEST_MSG_65_2ITER_LEN};
  time_2iter = profile_start();
  CHECK_STATUS_OK(otcrypto_mldsa65_sign_derand(&secret_key, msg_2iter, ctx,
                                               kOtcryptoMldsaSignModeMldsa, rnd,
                                               sig_buf, mldsa_work_buffer));
  time_2iter = profile_end(time_2iter);
  LOG_INFO("2-iteration message signing time: %u cycles", (uint32_t)time_2iter);
#endif

  // Sign 1-iteration message
  memcpy(mldsa_test_msg_buf, TEST_MSG_65, TEST_MSG_65_LEN);
  otcrypto_const_byte_buf_t msg = {.data = (const uint8_t *)mldsa_test_msg_buf,
                                   .len = TEST_MSG_65_LEN};
  t0 = profile_start();
  CHECK_STATUS_OK(otcrypto_mldsa65_sign_derand(&secret_key, msg, ctx,
                                               kOtcryptoMldsaSignModeMldsa, rnd,
                                               sig_buf, mldsa_work_buffer));
  uint64_t time_1iter = profile_end(t0);

  verify_signature_hash((uint8_t *)mldsa_signature,
                        kOtcryptoMldsa65SignatureBytes,
                        kMldsa65ExpectedSignatureHash);

  LOG_INFO("1-iteration message signing time: %u cycles", (uint32_t)time_1iter);

#ifdef MLDSA_BENCHMARK_MODE
  // Calculate expected runtime for expected iterations (5.1)
  uint32_t time_per_iter = (uint32_t)(time_2iter - time_1iter);
  uint64_t expected_time =
      time_1iter + ((FIPS204_EXPECTED_ITERS_65 - 100) * time_per_iter) / 100;
  LOG_INFO("Expected signing time (5.1 iterations): %u cycles",
           (uint32_t)expected_time);
#endif

  LOG_INFO("Verifying...");
  hardened_bool_t verification_result;
  otcrypto_const_byte_buf_t sig_const = {.data = (uint8_t *)mldsa_signature,
                                         .len = kOtcryptoMldsa65SignatureBytes};
  t0 = profile_start();
  CHECK_STATUS_OK(otcrypto_mldsa65_verify(
      &public_key, msg, ctx, kOtcryptoMldsaSignModeMldsa, sig_const,
      &verification_result, mldsa_work_buffer));
  profile_end_and_print(t0, "otcrypto_mldsa65_verify");
  CHECK(verification_result == kHardenedBoolTrue,
        "Signature verification failed");
}

static void test_mldsa87_derand(void) {
  // Set up public key struct
  otcrypto_unblinded_key_t public_key = {
      .key_mode = kOtcryptoKeyModeMldsa87,
      .key_length = kOtcryptoMldsa87PublicKeyBytes,
      .key = mldsa_public_key_data,
      .checksum = 0,
  };

  // Set up secret key struct
  otcrypto_key_config_t secret_key_config = {
      .version = kOtcryptoLibVersion1,
      .key_mode = kOtcryptoKeyModeMldsa87,
      .key_length = kOtcryptoMldsa87SecretKeyBytes,
      .hw_backed = kHardenedBoolFalse,
      .exportable = kHardenedBoolFalse,
      .security_level = kOtcryptoKeySecurityLevelPassiveRemote,
  };
  otcrypto_blinded_key_t secret_key = {
      .config = secret_key_config,
      .keyblob_length =
          2 * ceil_div(kOtcryptoMldsa87SecretKeyBytes, sizeof(uint32_t)) *
          sizeof(uint32_t),
      .keyblob = mldsa_secret_key_data,
      .checksum = 0,
  };

  otcrypto_const_byte_buf_t seed = {.data = kKeypairSeed,
                                    .len = sizeof(kKeypairSeed)};

  LOG_INFO("Generating keypair...");
  uint64_t t0 = profile_start();
  CHECK_STATUS_OK(otcrypto_mldsa87_keypair_derand(
      seed, &public_key, &secret_key, mldsa_work_buffer));
  profile_end_and_print(t0, "otcrypto_mldsa87_keypair_derand");

  LOG_INFO("Signing...");
  memcpy(mldsa_test_msg_buf, TEST_MSG_87, TEST_MSG_87_LEN);
  memcpy(mldsa_test_ctx_buf, TEST_CTX, TEST_CTX_LEN);

  otcrypto_const_byte_buf_t ctx = {.data = (const uint8_t *)mldsa_test_ctx_buf,
                                   .len = TEST_CTX_LEN};
  otcrypto_const_byte_buf_t rnd = {.data = kSignRnd, .len = sizeof(kSignRnd)};
  otcrypto_byte_buf_t sig_buf = {.data = (uint8_t *)mldsa_signature,
                                 .len = sizeof(mldsa_signature)};

#ifdef MLDSA_BENCHMARK_MODE
  // Benchmark 2-iteration message first
  uint64_t time_2iter;
  memcpy(mldsa_test_msg_buf, TEST_MSG_87_2ITER, TEST_MSG_87_2ITER_LEN);
  otcrypto_const_byte_buf_t msg_2iter = {
      .data = (const uint8_t *)mldsa_test_msg_buf,
      .len = TEST_MSG_87_2ITER_LEN};
  time_2iter = profile_start();
  CHECK_STATUS_OK(otcrypto_mldsa87_sign_derand(&secret_key, msg_2iter, ctx,
                                               kOtcryptoMldsaSignModeMldsa, rnd,
                                               sig_buf, mldsa_work_buffer));
  time_2iter = profile_end(time_2iter);
  LOG_INFO("2-iteration message signing time: %u cycles", (uint32_t)time_2iter);
#endif

  // Sign 1-iteration message
  memcpy(mldsa_test_msg_buf, TEST_MSG_87, TEST_MSG_87_LEN);
  otcrypto_const_byte_buf_t msg = {.data = (const uint8_t *)mldsa_test_msg_buf,
                                   .len = TEST_MSG_87_LEN};
  t0 = profile_start();
  CHECK_STATUS_OK(otcrypto_mldsa87_sign_derand(&secret_key, msg, ctx,
                                               kOtcryptoMldsaSignModeMldsa, rnd,
                                               sig_buf, mldsa_work_buffer));
  uint64_t time_1iter = profile_end(t0);

  verify_signature_hash((uint8_t *)mldsa_signature,
                        kOtcryptoMldsa87SignatureBytes,
                        kMldsa87ExpectedSignatureHash);

  LOG_INFO("1-iteration message signing time: %u cycles", (uint32_t)time_1iter);

#ifdef MLDSA_BENCHMARK_MODE
  // Calculate expected runtime for expected iterations (3.85)
  uint32_t time_per_iter = (uint32_t)(time_2iter - time_1iter);
  uint64_t expected_time =
      time_1iter + ((FIPS204_EXPECTED_ITERS_87 - 100) * time_per_iter) / 100;
  LOG_INFO("Expected signing time (3.85 iterations): %u cycles",
           (uint32_t)expected_time);
#endif

  LOG_INFO("Verifying...");
  hardened_bool_t verification_result;
  otcrypto_const_byte_buf_t sig_const = {.data = (uint8_t *)mldsa_signature,
                                         .len = kOtcryptoMldsa87SignatureBytes};
  t0 = profile_start();
  CHECK_STATUS_OK(otcrypto_mldsa87_verify(
      &public_key, msg, ctx, kOtcryptoMldsaSignModeMldsa, sig_const,
      &verification_result, mldsa_work_buffer));
  profile_end_and_print(t0, "otcrypto_mldsa87_verify");
  CHECK(verification_result == kHardenedBoolTrue,
        "Signature verification failed");
}

bool test_main(void) {
  test_mldsa44_derand();
  test_mldsa65_derand();
  test_mldsa87_derand();
  return true;
}
