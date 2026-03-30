// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/base/memory.h"
#include "sw/device/lib/crypto/drivers/acc.h"
#include "sw/device/lib/crypto/drivers/entropy.h"
#include "sw/device/lib/crypto/impl/integrity.h"
#include "sw/device/lib/crypto/impl/status.h"
#include "sw/device/lib/crypto/include/datatypes.h"
#include "sw/device/lib/crypto/include/ed25519.h"
#include "sw/device/lib/crypto/include/sha2.h"
#include "sw/device/lib/testing/entropy_testutils.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"

// Module for status messages.
#define MODULE_ID MAKE_MODULE_ID('t', 's', 't')

enum {
  /* Number of 32-bit words in a Ed25519 public key. */
  kEd25519PublicKeyWords = 256 / 32,
  /* Number of 32-bit words in a Ed25519 signtaure. */
  kEd25519SignatureWords = 512 / 32,
  /* Number of 32-bit words in a Ed25519 private key. */
  kEd25519PrivateKeyWords = 256 / 32,
  /* Number of bytes in a Ed25519 private key. */
  kEd25519PrivateKeyBytes = 256 / 8,
};

// Message
static const char kMessage[] = "abc";

// Public key
static uint32_t public_key_fixed[kEd25519PublicKeyWords] = {
    0x932b17ec, 0x3b565ead, 0x702c93f4, 0x345024e1,
    0xef6754c3, 0x644dfd2e, 0x6819f8eb, 0xbfe26734,
};

// Private key
static uint32_t private_key_fixed[kEd25519PrivateKeyWords] = {
    0x24e63f83, 0x9d7b2309, 0x5877ec62, 0x1e912075,
    0xec9c759a, 0x5b75191d, 0xb901a97d, 0x423dca6d,
};

static const otcrypto_key_config_t kPrivateKeyConfig = {
    .version = kOtcryptoLibVersion1,
    .key_mode = kOtcryptoKeyModeEd25519,
    .key_length = kEd25519PrivateKeyBytes,
    .hw_backed = kHardenedBoolFalse,
    .security_level = kOtcryptoKeySecurityLevelPassiveRemote,
};

status_t sign_then_verify_test(hardened_bool_t *verification_result,
                               otcrypto_eddsa_sign_mode_t sign_mode,
                               const uint8_t *msg, size_t msg_len,
                               const uint8_t *ctx, size_t ctx_len) {
  // Set up private key.
  otcrypto_blinded_key_t private_key = {
      .config = kPrivateKeyConfig,
      .keyblob_length = sizeof(private_key_fixed),
      .keyblob = private_key_fixed,
  };

  // Set up public key.
  otcrypto_unblinded_key_t public_key = {
      .key_mode = kOtcryptoKeyModeEd25519,
      .key_length = sizeof(public_key_fixed),
      .key = public_key_fixed,
  };

  // Compute the checksums for each.
  private_key.checksum = integrity_blinded_checksum(&private_key);
  public_key.checksum = integrity_unblinded_checksum(&public_key);

  uint32_t msg_digest_data[512 / 32];
  if (sign_mode == kOtcryptoEddsaSignModeHashEddsa) {
    // Hash the message for HashEd25519.
    otcrypto_const_byte_buf_t raw_msg = {
        .data = msg,
        .len = msg_len,
    };
    otcrypto_hash_digest_t msg_digest = {
        .data = msg_digest_data,
        .len = ARRAYSIZE(msg_digest_data),
    };
    TRY(otcrypto_sha2_512(raw_msg, &msg_digest));
  }
  otcrypto_const_byte_buf_t message =
      (sign_mode == kOtcryptoEddsaSignModeHashEddsa)
          ? (otcrypto_const_byte_buf_t){.data = (uint8_t *)msg_digest_data,
                                        .len = sizeof(msg_digest_data)}
          : (otcrypto_const_byte_buf_t){.data = msg, .len = msg_len};

  // Allocate space for the signature.
  uint32_t sig[kEd25519SignatureWords] = {0};

  otcrypto_const_byte_buf_t context = {.data = ctx, .len = ctx_len};

  // Generate a signature for the message.
  LOG_INFO("Signing (mode=%d, msg_len=%d, ctx_len=%d)...", sign_mode,
           message.len, ctx_len);
  CHECK_STATUS_OK(otcrypto_ed25519_sign(
      &private_key, message, context, sign_mode,
      (otcrypto_word32_buf_t){.data = sig, .len = ARRAYSIZE(sig)}));

  // Verify the signature.
  LOG_INFO("Verifying...");
  CHECK_STATUS_OK(otcrypto_ed25519_verify(
      &public_key, message, context, sign_mode,
      (otcrypto_const_word32_buf_t){.data = sig, .len = ARRAYSIZE(sig)},
      verification_result));

  return OTCRYPTO_OK;
}

OTTF_DEFINE_TEST_CONFIG();

bool test_main(void) {
  CHECK_STATUS_OK(entropy_testutils_auto_mode_init());

  // Test HashEd25519 with various context lengths.
  uint8_t ctx_buf[255];
  memset(ctx_buf, 0x42, sizeof(ctx_buf));
  size_t ctx_lens[] = {0, 1, 8, 31, 32, 33, 96, 160, 8, 255};

  for (size_t i = 0; i < ARRAYSIZE(ctx_lens); i++) {
    hardened_bool_t result;
    status_t err = sign_then_verify_test(
        &result, kOtcryptoEddsaSignModeHashEddsa, (const uint8_t *)kMessage,
        sizeof(kMessage) - 1, ctx_buf, ctx_lens[i]);
    if (!status_ok(err)) {
      LOG_INFO("ACC error bits: 0x%08x", acc_err_bits_get());
      LOG_INFO("ACC instruction count: 0x%08x", acc_instruction_count_get());
      CHECK_STATUS_OK(err);
      return false;
    }
    if (result != kHardenedBoolTrue) {
      LOG_ERROR("HashEd25519 verification failed (ctx_len=%d)!", ctx_lens[i]);
      return false;
    }
  }

  // Test pure Ed25519 with various message lengths.
  {
    static uint8_t msg_buf[4097];
    memset(msg_buf, 0xA5, sizeof(msg_buf));
    size_t msg_lens[] = {0,   1,   3,    31,   32,   33,   64,  127,
                         128, 129, 1279, 1280, 1281, 2560, 4097};

    for (size_t i = 0; i < ARRAYSIZE(msg_lens); i++) {
      hardened_bool_t result;
      status_t err = sign_then_verify_test(&result, kOtcryptoEddsaSignModeEddsa,
                                           msg_buf, msg_lens[i], NULL, 0);
      if (!status_ok(err)) {
        LOG_INFO("ACC error bits: 0x%08x", acc_err_bits_get());
        LOG_INFO("ACC instruction count: 0x%08x", acc_instruction_count_get());
        CHECK_STATUS_OK(err);
        return false;
      }
      if (result != kHardenedBoolTrue) {
        LOG_ERROR("Pure Ed25519 verification failed (msg_len=%d)!",
                  msg_lens[i]);
        return false;
      }
    }
  }

  return true;
}
