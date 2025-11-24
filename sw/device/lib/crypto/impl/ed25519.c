// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/crypto/impl/ecc/ed25519.h"

#include "sw/device/lib/base/math.h"
#include "sw/device/lib/crypto/drivers/entropy.h"
#include "sw/device/lib/crypto/drivers/otbn.h"
#include "sw/device/lib/crypto/impl/integrity.h"
#include "sw/device/lib/crypto/impl/status.h"
#include "sw/device/lib/crypto/include/datatypes.h"
#include "sw/device/lib/crypto/include/ed25519.h"
#include "sw/device/lib/crypto/include/sha2.h"

// Module ID for status codes.
#define MODULE_ID MAKE_MODULE_ID('e', '2', '5')

otcrypto_status_t otcrypto_ed25519_keygen(
    otcrypto_blinded_key_t *private_key, otcrypto_unblinded_key_t *public_key) {
  return OTCRYPTO_NOT_IMPLEMENTED;
}

otcrypto_status_t otcrypto_ed25519_sign(
    const otcrypto_blinded_key_t *private_key,
    otcrypto_const_byte_buf_t input_message, otcrypto_const_byte_buf_t context,
    otcrypto_eddsa_sign_mode_t sign_mode, otcrypto_word32_buf_t signature) {
  HARDENED_TRY(otcrypto_ed25519_sign_async_start(
      private_key, input_message, context, sign_mode, signature));
  OTBN_WIPE_IF_ERROR(otbn_busy_wait_for_done());
  return otcrypto_ed25519_sign_async_finalize(signature);
}

otcrypto_status_t otcrypto_ed25519_verify(
    const otcrypto_unblinded_key_t *public_key,
    otcrypto_const_byte_buf_t input_message, otcrypto_const_byte_buf_t context,
    otcrypto_eddsa_sign_mode_t sign_mode, otcrypto_const_word32_buf_t signature,
    hardened_bool_t *verification_result) {
  HARDENED_TRY(otcrypto_ed25519_verify_async_start(
      public_key, input_message, context, sign_mode, signature));
  OTBN_WIPE_IF_ERROR(otbn_busy_wait_for_done());
  return otcrypto_ed25519_verify_async_finalize(signature, verification_result);
}

otcrypto_status_t otcrypto_ed25519_keygen_async_start(
    const otcrypto_blinded_key_t *private_key) {
  return OTCRYPTO_NOT_IMPLEMENTED;
}

otcrypto_status_t otcrypto_ed25519_keygen_async_finalize(
    otcrypto_blinded_key_t *private_key, otcrypto_unblinded_key_t *public_key) {
  return OTCRYPTO_NOT_IMPLEMENTED;
}

OT_WARN_UNUSED_RESULT
static status_t ed25519_private_key_length_check(
    const otcrypto_blinded_key_t *private_key) {
  if (private_key->keyblob == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Ensure the key isn't hardware backed (we don't support these yet).
  if (launder32(private_key->config.hw_backed) != kHardenedBoolFalse) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(private_key->config.hw_backed, kHardenedBoolFalse);

  // Check the (unmasked) length.
  if (launder32(private_key->config.key_length) != kEd25519SecretBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(private_key->config.key_length, kEd25519SecretBytes);

  // Check the keyblob length.
  if (launder32(private_key->keyblob_length) != sizeof(ed25519_secret_t)) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(private_key->keyblob_length, sizeof(ed25519_secret_t));

  return OTCRYPTO_OK;
}

OT_WARN_UNUSED_RESULT
static status_t ed25519_signature_length_check(size_t len) {
  if (launder32(len) > UINT32_MAX / sizeof(uint32_t) ||
      launder32(len) * sizeof(uint32_t) != sizeof(ed25519_signature_t)) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(len * sizeof(uint32_t), sizeof(ed25519_signature_t));

  return OTCRYPTO_OK;
}

OT_WARN_UNUSED_RESULT
static status_t construct_hash_h(uint32_t hash_h[kEd25519HashWords],
                                 const otcrypto_blinded_key_t *private_key) {
  // Copy the private key into a byte buffer.
  uint8_t private_key_data_buf[kEd25519SecretBytes];
  otcrypto_const_byte_buf_t private_key_buf = {
      .data = private_key_data_buf,
      .len = kEd25519SecretBytes,
  };

  // TODO(#17711) Change to `hardened_memcpy`.
  memcpy(private_key_data_buf, private_key->keyblob, kEd25519SecretBytes);

  // Prepare a struct for the hashed private key.
  uint32_t hash_h_buf[kEd25519HashWords];
  otcrypto_hash_digest_t hash_h_digest = {
      .data = hash_h_buf,
      .len = kEd25519HashWords,
  };

  HARDENED_TRY(otcrypto_sha2_512(private_key_buf, &hash_h_digest));

  // Copy the hashed private key into the provided buffer.
  // TODO(#17711) Change to `hardened_memcpy`.
  memcpy(hash_h, hash_h_buf, kEd25519HashBytes);

  return OTCRYPTO_OK;
}

otcrypto_status_t otcrypto_ed25519_sign_async_start(
    const otcrypto_blinded_key_t *private_key,
    otcrypto_const_byte_buf_t input_message, otcrypto_const_byte_buf_t context,
    otcrypto_eddsa_sign_mode_t sign_mode, otcrypto_word32_buf_t signature) {
  if (private_key == NULL || private_key->keyblob == NULL ||
      input_message.data == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Check that the entropy complex is initialized.
  HARDENED_TRY(entropy_complex_check());

  // Check the mode; currently, only HashEd25519 is allowed.
  if (launder32(sign_mode) != kOtcryptoEddsaSignModeHashEddsa) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(sign_mode, kOtcryptoEddsaSignModeHashEddsa);

  // Check the input message size: since only HashEd25519 is allowed presently,
  // this must be the full size of the prehash output.
  if (launder32(input_message.len) != kEd25519PreHashBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(input_message.len, kEd25519PreHashBytes);

  // TODO: how will we check context size? should we?

  // Check the integrity of the private key.
  if (launder32(integrity_blinded_key_check(private_key)) !=
      kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(integrity_blinded_key_check(private_key),
                    kHardenedBoolTrue);

  // Ensure that the key mode is correct.
  if (launder32(private_key->config.key_mode) != kOtcryptoKeyModeEd25519) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(private_key->config.key_mode, kOtcryptoKeyModeEd25519);

  // Check the private key length.
  HARDENED_TRY(ed25519_private_key_length_check(private_key));

  // Hash the private key.
  uint32_t hash_h[kEd25519HashWords];
  HARDENED_TRY(construct_hash_h(hash_h, private_key));

  // Copy the input message into a 32-bit aligned buffer.
  size_t input_message_wordlen = ceil_div(input_message.len, sizeof(uint32_t));
  uint32_t input_message_aligned[input_message_wordlen];
  // TODO(#17711) Change to `hardened_memcpy`.
  memcpy(input_message_aligned, input_message.data, input_message.len);
  memset(input_message_aligned, 0,
         sizeof(input_message_aligned) - input_message.len);

  // Copy the context into a 32-bit aligned buffer.
  size_t context_wordlen = ceil_div(context.len, sizeof(uint32_t));
  uint32_t context_aligned[context_wordlen];
  // TODO(#17711) Change to `hardened_memcpy`.
  memcpy(context_aligned, context.data, context.len);
  memset(context_aligned, 0, sizeof(context_aligned) - context.len);

  // Start the asynchronous signature-generation routine.
  return ed25519_sign_start(input_message_aligned, hash_h, context_aligned,
                            context.len);
}

otcrypto_status_t otcrypto_ed25519_sign_async_finalize(
    otcrypto_word32_buf_t signature) {
  if (signature.data == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Ensure the entropy complex is initialized.
  HARDENED_TRY(entropy_complex_check());

  // Check the signature length.
  HARDENED_TRY(ed25519_signature_length_check(signature.len));
  ed25519_signature_t *sig_ed25519 = (ed25519_signature_t *)signature.data;

  // Note: This operation wipes DMEM, so if an error occurs after this
  // point then the signature would be unrecoverable. This should be the
  // last potentially error-causing line before returning to the caller.
  return ed25519_sign_finalize(sig_ed25519);
}

OT_WARN_UNUSED_RESULT
static status_t ed25519_public_key_length_check(
    const otcrypto_unblinded_key_t *public_key) {
  if (launder32(public_key->key_length) != sizeof(ed25519_point_t)) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(public_key->key_length, sizeof(ed25519_point_t));
  return OTCRYPTO_OK;
}

OT_WARN_UNUSED_RESULT
static status_t construct_hash_k(uint32_t hash_k[kEd25519HashWords],
                                 otcrypto_const_word32_buf_t signature,
                                 otcrypto_const_byte_buf_t context,
                                 const otcrypto_unblinded_key_t *public_key,
                                 otcrypto_const_byte_buf_t input_message) {
  // Initialize the SHA-512 computation.
  otcrypto_sha2_context_t ctx;
  HARDENED_TRY(otcrypto_sha2_init(kOtcryptoHashModeSha512, &ctx));

  // Update with the domain separation string, pre-hash flag, and context
  // length all together.
  uint8_t domain_sep_data[34] = {'S', 'i', 'g', 'E', 'd', '2',  '5', '5', '1',
                                 '9', ' ', 'n', 'o', ' ', 'E',  'd', '2', '5',
                                 '5', '1', '9', ' ', 'c', 'o',  'l', 'l', 'i',
                                 's', 'i', 'o', 'n', 's', 0x01, 0x00};
  domain_sep_data[33] = (uint8_t)context.len;
  otcrypto_const_byte_buf_t domain_sep_buf = {
      .data = domain_sep_data,
      .len = sizeof(domain_sep_data),
  };
  HARDENED_TRY(otcrypto_sha2_update(&ctx, domain_sep_buf));

  // Update with the context.
  HARDENED_TRY(otcrypto_sha2_update(&ctx, context));

  // Update with the first half of the signature, R.
  otcrypto_const_byte_buf_t signature_point_buf = {
      .data = (uint8_t *)signature.data,
      .len = kEd25519PointBytes,
  };
  HARDENED_TRY(otcrypto_sha2_update(&ctx, signature_point_buf));

  // Update with the public key, A.
  otcrypto_const_byte_buf_t public_key_buf = {
      .data = (uint8_t *)public_key->key,
      .len = kEd25519PointBytes,
  };
  HARDENED_TRY(otcrypto_sha2_update(&ctx, public_key_buf));

  // Update with the pre-hashed message, PH(M).
  HARDENED_TRY(otcrypto_sha2_update(&ctx, input_message));

  // Finalize the computed digest.
  otcrypto_hash_digest_t hash_k_digest = {
      .data = hash_k,
      .len = kEd25519HashWords,
  };
  HARDENED_TRY(otcrypto_sha2_final(&ctx, &hash_k_digest));

  return OTCRYPTO_OK;
}

otcrypto_status_t otcrypto_ed25519_verify_async_start(
    const otcrypto_unblinded_key_t *public_key,
    otcrypto_const_byte_buf_t input_message, otcrypto_const_byte_buf_t context,
    otcrypto_eddsa_sign_mode_t sign_mode,
    otcrypto_const_word32_buf_t signature) {
  if (public_key == NULL || signature.data == NULL ||
      input_message.data == NULL || public_key->key == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Ensure the entropy complex is initialized.
  HARDENED_TRY(entropy_complex_check());

  // Check the integrity of the public key.
  if (launder32(integrity_unblinded_key_check(public_key)) !=
      kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(integrity_unblinded_key_check(public_key),
                    kHardenedBoolTrue);

  // Check the public key mode.
  if (launder32(public_key->key_mode) != kOtcryptoKeyModeEd25519) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(public_key->key_mode, kOtcryptoKeyModeEd25519);

  // Check the public key size.
  HARDENED_TRY(ed25519_public_key_length_check(public_key));
  ed25519_point_t *pk = (ed25519_point_t *)public_key->key;

  // Check the digest length.
  if (launder32(input_message.len) != kEd25519PreHashBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(input_message.len, kEd25519PreHashBytes);

  // Check the signature lengths.
  HARDENED_TRY(ed25519_signature_length_check(signature.len));
  ed25519_signature_t *sig = (ed25519_signature_t *)signature.data;

  // Copy the input message into a 32-bit aligned buffer.
  size_t input_message_wordlen = ceil_div(input_message.len, sizeof(uint32_t));
  uint32_t input_message_aligned[input_message_wordlen];
  memset(input_message_aligned, 0, sizeof(input_message_aligned));
  memcpy(input_message_aligned, input_message.data, input_message.len);

  // Compute the pre-computed hash k
  uint32_t hash_k[kEd25519HashWords];
  HARDENED_TRY(
      construct_hash_k(hash_k, signature, context, public_key, input_message));

  size_t context_wordlen = ceil_div(context.len, sizeof(uint32_t));
  uint32_t context_aligned[context_wordlen];
  // TODO(#17711) Change to `hardened_memcpy`.
  memcpy(context_aligned, context.data, context.len);
  memset(context_aligned, 0, sizeof(context_aligned) - context.len);

  // Start the asynchronous signature-verification routine.
  return ed25519_verify_start(sig, input_message_aligned, hash_k, pk,
                              context_aligned, context.len);
}

otcrypto_status_t otcrypto_ed25519_verify_async_finalize(
    otcrypto_const_word32_buf_t signature,
    hardened_bool_t *verification_result) {
  if (verification_result == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Ensure the entropy complex is initialized.
  HARDENED_TRY(entropy_complex_check());

  HARDENED_TRY(ed25519_signature_length_check(signature.len));
  ed25519_signature_t *sig_ed25519 = (ed25519_signature_t *)signature.data;
  return ed25519_verify_finalize(sig_ed25519, verification_result);
}
