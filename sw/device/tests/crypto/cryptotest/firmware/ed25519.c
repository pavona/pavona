// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "ed25519.h"

#include "sw/device/lib/base/memory.h"
#include "sw/device/lib/base/status.h"
#include "sw/device/lib/crypto/impl/integrity.h"
#include "sw/device/lib/crypto/include/datatypes.h"
#include "sw/device/lib/crypto/include/ed25519.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/test_framework/ujson_ottf.h"
#include "sw/device/lib/ujson/ujson.h"
#include "sw/device/tests/crypto/cryptotest/json/ed25519_commands.h"

#define MODULE_ID MAKE_MODULE_ID('e', 'd', 'v')

enum {
  kEd25519PublicKeyBytes = 32,
  kEd25519PrivateKeyBytes = 32,
  kEd25519SignatureWords = 512 / 32,
};

static const otcrypto_key_config_t kEd25519PrivateKeyConfig = {
    .version = kOtcryptoLibVersion1,
    .key_mode = kOtcryptoKeyModeEd25519,
    .key_length = kEd25519PrivateKeyBytes,
    .hw_backed = kHardenedBoolFalse,
    .security_level = kOtcryptoKeySecurityLevelPassiveRemote,
};

static status_t handle_ed25519_sigver(ujson_t *uj) {
  cryptotest_ed25519_sign_mode_t uj_sign_mode;
  cryptotest_ed25519_message_t uj_message;
  cryptotest_ed25519_signature_t uj_signature;
  cryptotest_ed25519_public_key_t uj_public_key;

  TRY(ujson_deserialize_cryptotest_ed25519_sign_mode_t(uj, &uj_sign_mode));
  TRY(ujson_deserialize_cryptotest_ed25519_message_t(uj, &uj_message));
  TRY(ujson_deserialize_cryptotest_ed25519_signature_t(uj, &uj_signature));
  TRY(ujson_deserialize_cryptotest_ed25519_public_key_t(uj, &uj_public_key));

  // Set up the public key.
  uint32_t pk_data[kEd25519PublicKeyBytes / sizeof(uint32_t)];
  memset(pk_data, 0, sizeof(pk_data));
  memcpy(pk_data, uj_public_key.pk, uj_public_key.pk_len);
  otcrypto_unblinded_key_t public_key = {
      .key_mode = kOtcryptoKeyModeEd25519,
      .key_length = uj_public_key.pk_len,
      .key = pk_data,
  };
  public_key.checksum = integrity_unblinded_checksum(&public_key);

  otcrypto_const_byte_buf_t message = {
      .data = uj_message.input,
      .len = uj_message.input_len,
  };

  otcrypto_const_byte_buf_t context = {
      .data = NULL,
      .len = 0,
  };

  // Set up the signature.
  uint32_t sig_data[kEd25519SignatureWords];
  memset(sig_data, 0, sizeof(sig_data));
  memcpy(sig_data, uj_signature.signature, uj_signature.signature_len);
  otcrypto_const_word32_buf_t signature = {
      .data = sig_data,
      .len = kEd25519SignatureWords,
  };

  // Map the ujson sign mode to the cryptolib enum.
  otcrypto_eddsa_sign_mode_t sign_mode;
  switch (uj_sign_mode) {
    case kCryptotestEd25519SignModeEddsa:
      sign_mode = kOtcryptoEddsaSignModeEddsa;
      break;
    case kCryptotestEd25519SignModeHashEddsa:
      sign_mode = kOtcryptoEddsaSignModeHashEddsa;
      break;
    default:
      return INVALID_ARGUMENT();
  }

  // Verify.
  hardened_bool_t verification_result = kHardenedBoolFalse;
  otcrypto_status_t status =
      otcrypto_ed25519_verify(&public_key, message, context, sign_mode,
                              signature, &verification_result);

  cryptotest_ed25519_verify_output_t uj_output =
      (status_ok(status) && verification_result == kHardenedBoolTrue)
          ? kCryptotestEd25519VerifyOutputSuccess
          : kCryptotestEd25519VerifyOutputFailure;

  RESP_OK(ujson_serialize_cryptotest_ed25519_verify_output_t, uj, &uj_output);
  return OK_STATUS();
}

static status_t handle_ed25519_siggen(ujson_t *uj) {
  cryptotest_ed25519_siggen_data_t uj_data;
  TRY(ujson_deserialize_cryptotest_ed25519_siggen_data_t(uj, &uj_data));

  // Set up the private key.
  uint32_t sk_data[kEd25519PrivateKeyBytes / sizeof(uint32_t)];
  memset(sk_data, 0, sizeof(sk_data));
  memcpy(sk_data, uj_data.sk, uj_data.sk_len);
  otcrypto_blinded_key_t private_key = {
      .config = kEd25519PrivateKeyConfig,
      .keyblob_length = sizeof(sk_data),
      .keyblob = sk_data,
  };
  private_key.checksum = integrity_blinded_checksum(&private_key);

  // Set up the pre-hashed message.
  otcrypto_const_byte_buf_t message = {
      .data = uj_data.message,
      .len = uj_data.message_len,
  };

  // Set up the context.
  otcrypto_const_byte_buf_t context = {
      .data = uj_data.context,
      .len = uj_data.context_len,
  };

  // Allocate space for the signature.
  uint32_t sig[kEd25519SignatureWords] = {0};
  otcrypto_word32_buf_t sig_buf = {
      .data = sig,
      .len = kEd25519SignatureWords,
  };

  // Sign.
  otcrypto_status_t status = otcrypto_ed25519_sign(
      &private_key, message, context, kOtcryptoEddsaSignModeHashEddsa, sig_buf);

  // Verify the signature we just produced.
  if (status_ok(status)) {
    uint32_t pk_data[kEd25519PublicKeyBytes / sizeof(uint32_t)];
    memset(pk_data, 0, sizeof(pk_data));
    memcpy(pk_data, uj_data.pk, uj_data.pk_len);
    otcrypto_unblinded_key_t public_key = {
        .key_mode = kOtcryptoKeyModeEd25519,
        .key_length = uj_data.pk_len,
        .key = pk_data,
    };
    public_key.checksum = integrity_unblinded_checksum(&public_key);

    hardened_bool_t verification_result = kHardenedBoolFalse;
    otcrypto_const_word32_buf_t sig_const = {.data = sig,
                                             .len = ARRAYSIZE(sig)};
    TRY(otcrypto_ed25519_verify(&public_key, message, context,
                                kOtcryptoEddsaSignModeHashEddsa, sig_const,
                                &verification_result));
    if (verification_result != kHardenedBoolTrue) {
      LOG_ERROR("Ed25519 signature verification failed after signing");
      return INTERNAL();
    }
  }

  cryptotest_ed25519_siggen_output_t uj_output;
  memset(&uj_output, 0, sizeof(uj_output));
  uj_output.success = status_ok(status);
  if (uj_output.success) {
    memcpy(uj_output.signature, sig, sizeof(sig));
  }
  uj_output.signature_len = sizeof(sig);
  RESP_OK(ujson_serialize_cryptotest_ed25519_siggen_output_t, uj, &uj_output);
  return OK_STATUS();
}

status_t handle_ed25519(ujson_t *uj) {
  ed25519_subcommand_t subcmd;
  TRY(ujson_deserialize_ed25519_subcommand_t(uj, &subcmd));

  switch (subcmd) {
    case kEd25519SubcommandEd25519Sigver:
      return handle_ed25519_sigver(uj);
    case kEd25519SubcommandEd25519Siggen:
      return handle_ed25519_siggen(uj);
    default:
      LOG_ERROR("Unrecognized Ed25519 subcommand: %d", subcmd);
      return INVALID_ARGUMENT();
  }
}
