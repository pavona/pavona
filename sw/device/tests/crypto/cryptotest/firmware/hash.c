// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hash.h"

#include "sw/device/lib/base/macros.h"
#include "sw/device/lib/base/math.h"
#include "sw/device/lib/base/memory.h"
#include "sw/device/lib/base/status.h"
#include "sw/device/lib/crypto/impl/integrity.h"
#include "sw/device/lib/crypto/impl/keyblob.h"
#include "sw/device/lib/crypto/include/datatypes.h"
#include "sw/device/lib/crypto/include/sha2.h"
#include "sw/device/lib/crypto/include/sha3.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/test_framework/ujson_ottf.h"
#include "sw/device/lib/ujson/ujson.h"
#include "sw/device/tests/crypto/cryptotest/json/hash_commands.h"

status_t handle_hash(ujson_t *uj, hash_test_scratch_t *s) {
  // Declare test arguments
  cryptotest_hash_algorithm_t uj_algorithm;
  cryptotest_hash_shake_digest_length_t uj_shake_digest_length;
  cryptotest_hash_message_t *uj_message = &s->message;
  // Deserialize test arguments from UART
  TRY(ujson_deserialize_cryptotest_hash_algorithm_t(uj, &uj_algorithm));
  TRY(ujson_deserialize_cryptotest_hash_shake_digest_length_t(
      uj, &uj_shake_digest_length));
  TRY(ujson_deserialize_cryptotest_hash_message_t(uj, uj_message));

  otcrypto_const_byte_buf_t input_message = {
      .len = uj_message->message_len,
      .data = uj_message->message,
  };
  otcrypto_const_byte_buf_t customization_string = {
      .len = uj_message->customization_string_len,
      .data = uj_message->customization_string,
  };
  // If we are using cSHAKE, the empty function name tells cryptolib not to
  // apply any function on top of cSHAKE.
  otcrypto_const_byte_buf_t cshake_function_name = {
      .len = 0,
  };

  // Handle to correct oneshot hash API for the provided algorithm
  otcrypto_status_t (*hash_oneshot)(otcrypto_const_byte_buf_t,
                                    otcrypto_hash_digest_t *);

  // Digest length in 32-bit words
  size_t digest_len;
  uint8_t test_stepwise = false;
  otcrypto_hash_mode_t mode;
  switch (uj_algorithm) {
    case kCryptotestHashAlgorithmSha256:
      mode = kOtcryptoHashModeSha256;
      digest_len = 256 / 32;
      hash_oneshot = otcrypto_sha2_256;
      test_stepwise = true;
      break;
    case kCryptotestHashAlgorithmSha384:
      mode = kOtcryptoHashModeSha384;
      digest_len = 384 / 32;
      hash_oneshot = otcrypto_sha2_384;
      test_stepwise = true;
      break;
    case kCryptotestHashAlgorithmSha512:
      mode = kOtcryptoHashModeSha512;
      digest_len = 512 / 32;
      hash_oneshot = otcrypto_sha2_512;
      test_stepwise = true;
      break;
    case kCryptotestHashAlgorithmSha3_224:
      mode = kOtcryptoHashModeSha3_224;
      digest_len = 224 / 32;
      hash_oneshot = otcrypto_sha3_224;
      break;
    case kCryptotestHashAlgorithmSha3_256:
      mode = kOtcryptoHashModeSha3_256;
      digest_len = 256 / 32;
      hash_oneshot = otcrypto_sha3_256;
      break;
    case kCryptotestHashAlgorithmSha3_384:
      mode = kOtcryptoHashModeSha3_384;
      digest_len = 384 / 32;
      hash_oneshot = otcrypto_sha3_384;
      break;
    case kCryptotestHashAlgorithmSha3_512:
      mode = kOtcryptoHashModeSha3_512;
      digest_len = 512 / 32;
      hash_oneshot = otcrypto_sha3_512;
      break;
    case kCryptotestHashAlgorithmShake128:
      mode = kOtcryptoHashXofModeShake128;
      digest_len = ceil_div(uj_shake_digest_length.length, sizeof(uint32_t));
      hash_oneshot = otcrypto_shake128;
      break;
    case kCryptotestHashAlgorithmShake256:
      mode = kOtcryptoHashXofModeShake256;
      digest_len = ceil_div(uj_shake_digest_length.length, sizeof(uint32_t));
      hash_oneshot = otcrypto_shake256;
      break;
    case kCryptotestHashAlgorithmCshake128:
      mode = kOtcryptoHashXofModeCshake128;
      digest_len = ceil_div(uj_shake_digest_length.length, sizeof(uint32_t));
      break;
    case kCryptotestHashAlgorithmCshake256:
      mode = kOtcryptoHashXofModeCshake256;
      digest_len = ceil_div(uj_shake_digest_length.length, sizeof(uint32_t));
      break;
    default:
      LOG_ERROR("Unsupported hash algorithm: %d", uj_algorithm);
      return INVALID_ARGUMENT();
  }

  // Create digest skeleton
  if (digest_len > ARRAYSIZE(s->work.digest)) {
    LOG_ERROR("Digest too long");
    return INVALID_ARGUMENT();
  }
  uint32_t *digest_buf = s->work.digest;
  memset(digest_buf, 0, digest_len * sizeof(uint32_t));
  otcrypto_hash_digest_t digest = {
      .data = digest_buf,
      .len = digest_len,
  };
  otcrypto_status_t status;
  // Test oneshot API
  switch (uj_algorithm) {
    case kCryptotestHashAlgorithmCshake128:
      status = otcrypto_cshake128(input_message, cshake_function_name,
                                  customization_string, &digest);
      break;
    case kCryptotestHashAlgorithmCshake256:
      status = otcrypto_cshake256(input_message, cshake_function_name,
                                  customization_string, &digest);
      break;
    default:
      status = hash_oneshot(input_message, &digest);
  }
  if (status.value != kOtcryptoStatusValueOk) {
    LOG_ERROR("Bad status value: 0x%x", status.value);
    return INTERNAL(status.value);
  }
  cryptotest_hash_output_t *uj_output = &s->output;
  memset(uj_output, 0, sizeof(*uj_output));
  uj_output->digest_len = digest_len * sizeof(uint32_t);
  // Copy oneshot digest to uJSON type
  memcpy(uj_output->oneshot_digest, digest_buf, digest_len * sizeof(uint32_t));
  // Zero out digest_buf to mitigate chance of a false positive in the
  // stepwise test
  memset(digest_buf, 0, digest_len * sizeof(uint32_t));
  // Test the stepwise API for algorithms that support it
  if (test_stepwise) {
    otcrypto_sha2_context_t ctx;
    status = otcrypto_sha2_init(mode, &ctx);
    if (status.value != kOtcryptoStatusValueOk) {
      return INTERNAL(status.value);
    }
    // Split up input mesasge into 2 shares for better coverage of stepwise
    // hashing
    otcrypto_const_byte_buf_t input_message_share1 = {
        .len = uj_message->message_len / 2,
        .data = uj_message->message,
    };
    otcrypto_const_byte_buf_t input_message_share2 = {
        .len = ceil_div(uj_message->message_len, 2),
        .data = &uj_message->message[uj_message->message_len / 2],
    };
    status = otcrypto_sha2_update(&ctx, input_message_share1);
    if (status.value != kOtcryptoStatusValueOk) {
      return INTERNAL(status.value);
    }
    status = otcrypto_sha2_update(&ctx, input_message_share2);
    if (status.value != kOtcryptoStatusValueOk) {
      return INTERNAL(status.value);
    }
    status = otcrypto_sha2_final(&ctx, &digest);
    if (status.value != kOtcryptoStatusValueOk) {
      return INTERNAL(status.value);
    }
    // Copy stepwise result to uJSON type
    memcpy(uj_output->stepwise_digest, digest_buf,
           digest_len * sizeof(uint32_t));
  }
  // Send digest to host via UART
  RESP_OK(ujson_serialize_cryptotest_hash_output_t, uj, uj_output);
  return OK_STATUS(0);
}

enum {
  kHashMctOuterIterations = 100,
  kHashMctInnerIterations = 1000,
  kHashMctMaxDigestWords = 512 / 32,
  // SHA2 hashes the last three digests, SHA3 the last one.
  kHashMctMaxWindow = 3,
};

status_t handle_hash_mct(ujson_t *uj, hash_test_scratch_t *s) {
  cryptotest_hash_algorithm_t uj_algorithm;
  cryptotest_hash_message_t *uj_message = &s->message;
  cryptotest_hash_mct_version_t uj_mct_version;
  TRY(ujson_deserialize_cryptotest_hash_algorithm_t(uj, &uj_algorithm));
  TRY(ujson_deserialize_cryptotest_hash_message_t(uj, uj_message));
  TRY(ujson_deserialize_cryptotest_hash_mct_version_t(uj, &uj_mct_version));
  // ACVP issues the alternate test if the registered message lengths exclude
  // the standard test's messages. It truncates or zero-pads every message to
  // the length of the seed. Our registrations do not need it, but the SHA2-256
  // and SHA2-512 sample vector sets use it.
  bool alternate = uj_mct_version == kCryptotestHashMctVersionAlternate;

  otcrypto_status_t (*hash_oneshot)(otcrypto_const_byte_buf_t,
                                    otcrypto_hash_digest_t *);
  size_t digest_len;
  size_t window;
  switch (uj_algorithm) {
    case kCryptotestHashAlgorithmSha256:
      digest_len = 256 / 32;
      hash_oneshot = otcrypto_sha2_256;
      window = 3;
      break;
    case kCryptotestHashAlgorithmSha384:
      digest_len = 384 / 32;
      hash_oneshot = otcrypto_sha2_384;
      window = 3;
      break;
    case kCryptotestHashAlgorithmSha512:
      digest_len = 512 / 32;
      hash_oneshot = otcrypto_sha2_512;
      window = 3;
      break;
    case kCryptotestHashAlgorithmSha3_224:
      digest_len = 224 / 32;
      hash_oneshot = otcrypto_sha3_224;
      window = 1;
      break;
    case kCryptotestHashAlgorithmSha3_256:
      digest_len = 256 / 32;
      hash_oneshot = otcrypto_sha3_256;
      window = 1;
      break;
    case kCryptotestHashAlgorithmSha3_384:
      digest_len = 384 / 32;
      hash_oneshot = otcrypto_sha3_384;
      window = 1;
      break;
    case kCryptotestHashAlgorithmSha3_512:
      digest_len = 512 / 32;
      hash_oneshot = otcrypto_sha3_512;
      window = 1;
      break;
    default:
      LOG_ERROR("Unsupported hash algorithm for MCT: %d", uj_algorithm);
      return INVALID_ARGUMENT();
  }

  cryptotest_hash_mct_output_t *uj_output = &s->mct_output;
  memset(uj_output, 0, sizeof(*uj_output));
  size_t digest_bytes = digest_len * sizeof(uint32_t);
  size_t seed_len = uj_message->message_len;
  uint8_t *msg = s->work.mct_message;
  // The standard test's seed is a digest.
  if (!alternate && seed_len != digest_bytes) {
    return INVALID_ARGUMENT();
  }
  // The alternate test fits every message to the length of the first seed.
  size_t max_len = alternate ? seed_len : window * digest_bytes;
  if (max_len > sizeof(s->work.mct_message)) {
    return INVALID_ARGUMENT();
  }

  // One buffer beyond the window holds the next digest.
  uint32_t mds[kHashMctMaxWindow + 1][kHashMctMaxDigestWords];
  size_t next = 0;
  const uint8_t *seed = uj_message->message;
  size_t current_seed_len = seed_len;
  for (size_t j = 0; j < kHashMctOuterIterations; j++) {
    const uint8_t *prev[kHashMctMaxWindow];
    size_t prev_len[kHashMctMaxWindow];
    for (size_t k = 0; k < window; k++) {
      prev[k] = seed;
      prev_len[k] = current_seed_len;
    }
    for (size_t i = 0; i < kHashMctInnerIterations; i++) {
      // The message concatenates the last `window` digests, initially the seed.
      size_t len = 0;
      for (size_t k = 0; k < window; k++) {
        size_t n = prev_len[k];
        // The alternate test truncates a message longer than the seed.
        if (n > max_len - len) {
          n = max_len - len;
        }
        memcpy(&msg[len], prev[k], n);
        len += n;
      }
      // The alternate test zero-pads a message shorter than the seed.
      if (alternate) {
        memset(&msg[len], 0, seed_len - len);
        len = seed_len;
      }
      otcrypto_const_byte_buf_t input = {
          .len = len,
          .data = msg,
      };
      otcrypto_hash_digest_t digest = {
          .data = mds[next],
          .len = digest_len,
      };
      otcrypto_status_t status = hash_oneshot(input, &digest);
      if (status.value != kOtcryptoStatusValueOk) {
        LOG_ERROR("Bad status value: 0x%x", status.value);
        return INTERNAL(status.value);
      }
      for (size_t k = 0; k + 1 < window; k++) {
        prev[k] = prev[k + 1];
        prev_len[k] = prev_len[k + 1];
      }
      prev[window - 1] = (const uint8_t *)mds[next];
      prev_len[window - 1] = digest_bytes;
      next = (next + 1) % (window + 1);
    }
    seed = prev[window - 1];
    current_seed_len = digest_bytes;
    memcpy(&uj_output->digests[j * digest_bytes], seed, digest_bytes);
  }

  uj_output->digests_len = kHashMctOuterIterations * digest_bytes;
  uj_output->digest_len = digest_bytes;
  RESP_OK(ujson_serialize_cryptotest_hash_mct_output_t, uj, uj_output);
  return OK_STATUS(0);
}
