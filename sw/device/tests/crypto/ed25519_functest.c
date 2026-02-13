// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

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

status_t sign_then_verify_test(hardened_bool_t *verification_result) {
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

  // Hash the message.
  otcrypto_const_byte_buf_t msg = {
      .data = (unsigned char *)&kMessage,
      .len = sizeof(kMessage) - 1,
  };
  uint32_t msg_digest_data[512 / 32];
  otcrypto_hash_digest_t msg_digest = {
      .data = msg_digest_data,
      .len = ARRAYSIZE(msg_digest_data),
  };
  TRY(otcrypto_sha2_512(msg, &msg_digest));

  // Convert the hashed message into a const byte buffer.
  otcrypto_const_byte_buf_t msg_digest_buf = {
      .data = (uint8_t *)msg_digest_data,
      .len = sizeof(msg_digest_data),
  };

  // Allocate space for the signature.
  uint32_t sig[kEd25519SignatureWords] = {0};

  // Allocate a zero-size buffer for context
  uint8_t context[0];

  // Generate a signature for the message.
  LOG_INFO("Signing...");
  CHECK_STATUS_OK(otcrypto_ed25519_sign(
      &private_key, msg_digest_buf,
      (otcrypto_const_byte_buf_t){.data = context, .len = 0},
      kOtcryptoEddsaSignModeHashEddsa,
      (otcrypto_word32_buf_t){.data = sig, .len = ARRAYSIZE(sig)}));

  // Verify the signature.
  LOG_INFO("Verifying...");
  CHECK_STATUS_OK(otcrypto_ed25519_verify(
      &public_key, msg_digest_buf,
      (otcrypto_const_byte_buf_t){.data = context, .len = 0},
      kOtcryptoEddsaSignModeHashEddsa,
      (otcrypto_const_word32_buf_t){.data = sig, .len = ARRAYSIZE(sig)},
      verification_result));

  return OTCRYPTO_OK;
}

OTTF_DEFINE_TEST_CONFIG();

bool test_main(void) {
  CHECK_STATUS_OK(entropy_testutils_auto_mode_init());

  hardened_bool_t verificationResult;
  status_t err = sign_then_verify_test(&verificationResult);
  if (!status_ok(err)) {
    // If there was an error, print the ACC error bits and instruction count.
    LOG_INFO("ACC error bits: 0x%08x", acc_err_bits_get());
    LOG_INFO("ACC instruction count: 0x%08x", acc_instruction_count_get());
    // Print the error.
    CHECK_STATUS_OK(err);
    return false;
  }

  // Signature verification is expected to succeed.
  if (verificationResult != kHardenedBoolTrue) {
    LOG_ERROR("Signature failed to pass verification!");
    return false;
  }

  return true;
}
