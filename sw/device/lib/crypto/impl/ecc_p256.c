// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/crypto/include/ecc_p256.h"

#include "sw/device/lib/base/hardened.h"
#include "sw/device/lib/base/hardened_memory.h"
#include "sw/device/lib/crypto/drivers/acc.h"
#include "sw/device/lib/crypto/drivers/entropy.h"
#include "sw/device/lib/crypto/drivers/hmac.h"
#include "sw/device/lib/crypto/impl/ecc/p256.h"
#include "sw/device/lib/crypto/impl/integrity.h"
#include "sw/device/lib/crypto/impl/keyblob.h"
#include "sw/device/lib/crypto/include/datatypes.h"

// Module ID for status codes.
#define MODULE_ID MAKE_MODULE_ID('p', '2', '5')

/**
 * Check if a key mode is intended for ECC P-256 use.
 *
 * @param mode Mode to check.
 * @return OK if the mode is for ECC P-256 use, OTCRYPTO_BAD_ARGS otherwise.
 */
static status_t p256_mode_check(const otcrypto_key_mode_t mode) {
  switch (launder32(mode)) {
    case kOtcryptoKeyModeEcdsaP256:
      HARDENED_CHECK_EQ(mode, kOtcryptoKeyModeEcdsaP256);
      return OTCRYPTO_OK;
    case kOtcryptoKeyModeEcdhP256:
      HARDENED_CHECK_EQ(mode, kOtcryptoKeyModeEcdhP256);
      return OTCRYPTO_OK;
    default:
      return OTCRYPTO_BAD_ARGS;
  }

  // Should be unreachable.
  HARDENED_TRAP();
  return OTCRYPTO_FATAL_ERR;
}

/**
 * Check the lengths of public keys for curve P-256.
 *
 * Checks the length of caller-allocated buffers for a P-256 public key. This
 * function may be used for both ECDSA and ECDH keys, since the key structure
 * is the same.
 *
 * If this check passes, it is safe to interpret public_key->key as a
 * `p256_point_t *`.
 *
 * @param public_key Public key struct to check.
 * @return OK if the lengths are correct or BAD_ARGS otherwise.
 */
OT_WARN_UNUSED_RESULT
static status_t p256_public_key_length_check(
    const otcrypto_unblinded_key_t *public_key) {
  if (launder32(public_key->key_length) != sizeof(p256_point_t)) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(public_key->key_length, sizeof(p256_point_t));
  return OTCRYPTO_OK;
}

/**
 * Check the lengths of private keys for curve P-256.
 *
 * Checks the length of caller-allocated buffers for a P-256 private key. This
 * function may be used for both ECDSA and ECDH keys, since the key structure
 * is the same.
 *
 * If this check passes and `hw_backed` is false, it is safe to interpret
 * `private_key->keyblob` as a `p256_masked_scalar_t *`.
 *
 * @param private_key Private key struct to check.
 * @return OK if the lengths are correct or BAD_ARGS otherwise.
 */
OT_WARN_UNUSED_RESULT
static status_t p256_private_key_length_check(
    const otcrypto_blinded_key_t *private_key) {
  if (private_key->keyblob == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }

  if (launder32(private_key->config.hw_backed) == kHardenedBoolTrue) {
    // Skip the length check in this case; if the salt is the wrong length, the
    // keyblob library will catch it before we sideload the key.
    return OTCRYPTO_OK;
  }
  HARDENED_CHECK_NE(private_key->config.hw_backed, kHardenedBoolTrue);

  // Check the unmasked length.
  if (launder32(private_key->config.key_length) != kP256ScalarBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(private_key->config.key_length, kP256ScalarBytes);

  // Check the single-share length.
  if (launder32(keyblob_share_num_words(private_key->config)) !=
      kP256MaskedScalarShareWords) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(keyblob_share_num_words(private_key->config),
                    kP256MaskedScalarShareWords);

  // Check the keyblob length.
  if (launder32(private_key->keyblob_length) != sizeof(p256_masked_scalar_t)) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(private_key->keyblob_length, sizeof(p256_masked_scalar_t));

  return OTCRYPTO_OK;
}

otcrypto_status_t otcrypto_p256_public_key_construct(
    otcrypto_const_word32_buf_t x, otcrypto_const_word32_buf_t y,
    otcrypto_unblinded_key_t *public_key) {
  // Entropy complex must be initialized for `hardened_memcpy`.
  HARDENED_TRY(entropy_complex_check());

  // Check for any NULL pointers.
  if (public_key == NULL || public_key->key == NULL || x.data == NULL ||
      y.data == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Check the key mode.
  HARDENED_TRY(p256_mode_check(public_key->key_mode));

  // Check the key and coordinate lengths.
  HARDENED_TRY(p256_public_key_length_check(public_key));
  if (x.len != kP256CoordWords || y.len != kP256CoordWords) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(x.len, kP256CoordWords);
  HARDENED_CHECK_EQ(y.len, kP256CoordWords);

  // Copy the provided values into the public key.
  p256_point_t *pk = (p256_point_t *)public_key->key;
  hardened_memcpy(pk->x, x.data, kP256CoordWords);
  hardened_memcpy(pk->y, y.data, kP256CoordWords);

  // Set the public key checksum.
  public_key->checksum = integrity_unblinded_checksum(public_key);

  return OTCRYPTO_OK;
}

otcrypto_status_t otcrypto_p256_public_key_construct_and_check(
    otcrypto_const_word32_buf_t x, otcrypto_const_word32_buf_t y,
    otcrypto_unblinded_key_t *public_key, hardened_bool_t *key_valid) {
  otcrypto_session_token_t session_token = 0;
  HARDENED_TRY(otcrypto_p256_public_key_construct_and_check_async_start(
      x, y, public_key, key_valid, &session_token));
  ACC_WIPE_IF_ERROR(acc_busy_wait_for_done());
  return otcrypto_p256_public_key_construct_and_check_async_finalize(
      session_token, key_valid);
  return otcrypto_p256_public_key_construct_and_check_async_finalize(
      session_token, key_valid);
}

otcrypto_status_t otcrypto_p256_public_key_construct_and_check_async_start(
    otcrypto_const_word32_buf_t x, otcrypto_const_word32_buf_t y,
    otcrypto_unblinded_key_t *public_key, hardened_bool_t *key_valid,
    otcrypto_session_token_t *session_token) {
  // Defensively mark the private key as invalid to start.
  *key_valid = kHardenedBoolFalse;

  // Construct a copy of the private key from the provided parameters.
  HARDENED_TRY(otcrypto_p256_public_key_construct(x, y, public_key));

  // Start the public key check.
  p256_point_t *pk = (p256_point_t *)public_key->key;
  return p256_public_key_check_start(pk, session_token);
}

otcrypto_status_t otcrypto_p256_public_key_construct_and_check_async_finalize(
    otcrypto_session_token_t session_token, hardened_bool_t *key_valid) {
  // Finalize the public key check.
  return p256_public_key_check_finalize(session_token, key_valid);
}

otcrypto_status_t otcrypto_p256_public_key_deconstruct(
    const otcrypto_unblinded_key_t *public_key, otcrypto_word32_buf_t x,
    otcrypto_word32_buf_t y) {
  // Entropy complex must be initialized for `hardened_memcpy`.
  HARDENED_TRY(entropy_complex_check());

  // Check for any NULL pointers.
  if (public_key == NULL || public_key->key == NULL || x.data == NULL ||
      y.data == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Check the key mode.
  HARDENED_TRY(p256_mode_check(public_key->key_mode));

  // Check the key and coordinate lengths.
  HARDENED_TRY(p256_public_key_length_check(public_key));
  if (x.len != kP256CoordWords || y.len != kP256CoordWords) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(x.len, kP256CoordWords);
  HARDENED_CHECK_EQ(y.len, kP256CoordWords);

  // Check the integrity of the public key.
  if (launder32(integrity_unblinded_key_check(public_key)) !=
      kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(integrity_unblinded_key_check(public_key),
                    kHardenedBoolTrue);

  // Copy the provided values into the public key.
  p256_point_t *pk = (p256_point_t *)public_key->key;
  hardened_memcpy(x.data, pk->x, kP256CoordWords);
  hardened_memcpy(y.data, pk->y, kP256CoordWords);
  return OTCRYPTO_OK;
}

otcrypto_status_t otcrypto_p256_private_key_construct(
    otcrypto_const_word32_buf_t scalar_share0,
    otcrypto_const_word32_buf_t scalar_share1,
    otcrypto_blinded_key_t *private_key) {
  // Entropy complex must be initialized for `hardened_memcpy`.
  HARDENED_TRY(entropy_complex_check());

  // Check for any NULL pointers.
  if (private_key == NULL || private_key->keyblob == NULL ||
      scalar_share0.data == NULL || scalar_share1.data == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Check the key mode.
  HARDENED_TRY(p256_mode_check(private_key->config.key_mode));

  // Check the key and scalar share lengths.
  HARDENED_TRY(p256_private_key_length_check(private_key));
  if (scalar_share0.len != kP256MaskedScalarShareWords ||
      scalar_share1.len != kP256MaskedScalarShareWords) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(scalar_share0.len, kP256MaskedScalarShareWords);
  HARDENED_CHECK_EQ(scalar_share1.len, kP256MaskedScalarShareWords);

  // Copy the provided values into the private key.
  p256_masked_scalar_t *sk = (p256_masked_scalar_t *)private_key->keyblob;
  hardened_memcpy(sk->share0, scalar_share0.data, kP256MaskedScalarShareWords);
  hardened_memcpy(sk->share1, scalar_share1.data, kP256MaskedScalarShareWords);

  // Set the private key checksum.
  private_key->checksum = integrity_blinded_checksum(private_key);

  return OTCRYPTO_OK;
}

otcrypto_status_t otcrypto_p256_private_key_deconstruct(
    const otcrypto_blinded_key_t *private_key,
    otcrypto_word32_buf_t scalar_share0, otcrypto_word32_buf_t scalar_share1) {
  // Entropy complex must be initialized for `hardened_memcpy`.
  HARDENED_TRY(entropy_complex_check());

  // Check for any NULL pointers.
  if (private_key == NULL || private_key->keyblob == NULL ||
      scalar_share0.data == NULL || scalar_share1.data == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Check the key mode.
  HARDENED_TRY(p256_mode_check(private_key->config.key_mode));

  // Check that the key is exportable.
  if (private_key->config.exportable != kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(private_key->config.exportable, kHardenedBoolTrue);

  // Check the key and scalar share lengths.
  HARDENED_TRY(p256_private_key_length_check(private_key));
  if (scalar_share0.len != kP256MaskedScalarShareWords ||
      scalar_share1.len != kP256MaskedScalarShareWords) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(scalar_share0.len, kP256MaskedScalarShareWords);
  HARDENED_CHECK_EQ(scalar_share1.len, kP256MaskedScalarShareWords);

  // Check the integrity of the private key.
  if (launder32(integrity_blinded_key_check(private_key)) !=
      kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(integrity_blinded_key_check(private_key),
                    kHardenedBoolTrue);

  // Copy the provided values into the private key.
  p256_masked_scalar_t *sk = (p256_masked_scalar_t *)private_key->keyblob;
  hardened_memcpy(scalar_share0.data, sk->share0, kP256MaskedScalarShareWords);
  hardened_memcpy(scalar_share1.data, sk->share1, kP256MaskedScalarShareWords);
  return OTCRYPTO_OK;
}

otcrypto_status_t otcrypto_ecdsa_p256_keygen(
    otcrypto_blinded_key_t *private_key, otcrypto_unblinded_key_t *public_key) {
  otcrypto_session_token_t session_token = 0;
  HARDENED_TRY(
      otcrypto_ecdsa_p256_keygen_async_start(private_key, &session_token));
  ACC_WIPE_IF_ERROR(acc_busy_wait_for_done());
  return otcrypto_ecdsa_p256_keygen_async_finalize(session_token, private_key,
                                                   public_key);
}

otcrypto_status_t otcrypto_ecdsa_p256_sign(
    const otcrypto_blinded_key_t *private_key,
    const otcrypto_hash_digest_t message_digest,
    otcrypto_word32_buf_t signature) {
  otcrypto_session_token_t session_token = 0;
  HARDENED_TRY(otcrypto_ecdsa_p256_sign_async_start(private_key, message_digest,
                                                    &session_token));
  ACC_WIPE_IF_ERROR(acc_busy_wait_for_done());
  return otcrypto_ecdsa_p256_sign_async_finalize(session_token, signature);
}

otcrypto_status_t otcrypto_ecdsa_p256_attestation_endorse(
    const otcrypto_hash_digest_t message_digest,
    otcrypto_word32_buf_t signature) {
  return OTCRYPTO_NOT_IMPLEMENTED;
}

otcrypto_status_t otcrypto_ecdsa_p256_verify(
    const otcrypto_unblinded_key_t *public_key,
    const otcrypto_hash_digest_t message_digest,
    otcrypto_const_word32_buf_t signature,
    hardened_bool_t *verification_result) {
  otcrypto_session_token_t session_token = 0;
  HARDENED_TRY(otcrypto_ecdsa_p256_verify_async_start(

      public_key, message_digest, signature, &session_token));
  ACC_WIPE_IF_ERROR(acc_busy_wait_for_done());
  return otcrypto_ecdsa_p256_verify_async_finalize(signature, session_token,
                                                   verification_result);
}

otcrypto_status_t otcrypto_ecdsa_p256_sign_verify(
    const otcrypto_blinded_key_t *private_key,
    const otcrypto_unblinded_key_t *public_key,
    const otcrypto_hash_digest_t message_digest,
    otcrypto_word32_buf_t signature) {
  // Signature generation.
  HARDENED_TRY(
      otcrypto_ecdsa_p256_sign(private_key, message_digest, signature));

  // Verify signature before releasing it.
  otcrypto_const_word32_buf_t signature_check = {
      .data = signature.data,
      .len = signature.len,
  };
  hardened_bool_t verification_result = kHardenedBoolFalse;
  HARDENED_TRY(otcrypto_ecdsa_p256_verify(
      public_key, message_digest, signature_check, &verification_result));

  // Trap if signature verification failed.
  HARDENED_CHECK_EQ(verification_result, kHardenedBoolTrue);
  return OTCRYPTO_OK;
}

otcrypto_status_t otcrypto_ecdh_p256_keygen(
    otcrypto_blinded_key_t *private_key, otcrypto_unblinded_key_t *public_key) {
  otcrypto_session_token_t session_token = 0;
  HARDENED_TRY(
      otcrypto_ecdh_p256_keygen_async_start(private_key, &session_token));
  ACC_WIPE_IF_ERROR(acc_busy_wait_for_done());
  return otcrypto_ecdh_p256_keygen_async_finalize(session_token, private_key,
                                                  public_key);
}

otcrypto_status_t otcrypto_ecdh_p256(const otcrypto_blinded_key_t *private_key,
                                     const otcrypto_unblinded_key_t *public_key,
                                     otcrypto_blinded_key_t *shared_secret) {
  otcrypto_session_token_t session_token = 0;
  HARDENED_TRY(
      otcrypto_ecdh_p256_async_start(private_key, public_key, &session_token));
  ACC_WIPE_IF_ERROR(acc_busy_wait_for_done());
  return otcrypto_ecdh_p256_async_finalize(private_key, session_token,
                                           shared_secret);
}

/**
 * Calls P-256 key generation.
 *
 * Can be used for both ECDSA and ECDH. If the key is hardware-backed, loads
 * the data from key manager and calls the sideloaded key generation routine.
 *
 * @param private_key Sideloaded key handle.
 * @return OK or error.
 */
OT_WARN_UNUSED_RESULT
static status_t internal_p256_keygen_start(
    otcrypto_session_token_t *session_token,
    const otcrypto_blinded_key_t *private_key) {
  // Ensure the entropy complex is initialized.
  HARDENED_TRY(entropy_complex_check());

  if (launder32(private_key->config.hw_backed) == kHardenedBoolTrue) {
    HARDENED_CHECK_EQ(private_key->config.hw_backed, kHardenedBoolTrue);
    HARDENED_TRY(keyblob_sideload_key_acc(private_key));
    return p256_sideload_keygen_start(session_token);
  } else if (launder32(private_key->config.hw_backed) == kHardenedBoolFalse) {
    HARDENED_CHECK_EQ(private_key->config.hw_backed, kHardenedBoolFalse);
    return p256_keygen_start(session_token);
  } else {
    return OTCRYPTO_BAD_ARGS;
  }
  return OTCRYPTO_OK;
}

otcrypto_status_t otcrypto_ecdsa_p256_keygen_async_start(
    const otcrypto_blinded_key_t *private_key,
    otcrypto_session_token_t *session_token) {
  if (private_key == NULL || private_key->keyblob == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Check the key mode.
  if (launder32(private_key->config.key_mode) != kOtcryptoKeyModeEcdsaP256) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(private_key->config.key_mode, kOtcryptoKeyModeEcdsaP256);

  return internal_p256_keygen_start(session_token, private_key);
}

/**
 * Finalize a keypair generation operation for curve P-256.
 *
 * This function assumes that space is already allocated for all key material
 * and that the length parameters on the structs are set accordingly, in the
 * same way as for `otcrypto_ecdh_p256_keygen_async_finalize` and
 * `otcrypto_ecdsa_p256_keygen_async_finalize`.
 *
 * @param[out] private_key Private key to populate.
 * @param[out] public_key Public key to populate.
 * @return OK or error.
 */
OT_WARN_UNUSED_RESULT
static status_t internal_p256_keygen_finalize(
    otcrypto_session_token_t session_token, otcrypto_blinded_key_t *private_key,
    otcrypto_unblinded_key_t *public_key) {
  // Ensure the entropy complex is initialized.
  HARDENED_TRY(entropy_complex_check());

  // Check the lengths of caller-allocated buffers.
  HARDENED_TRY(p256_private_key_length_check(private_key));
  HARDENED_TRY(p256_public_key_length_check(public_key));
  p256_point_t *pk = (p256_point_t *)public_key->key;

  // Note: The `finalize` operations wipe DMEM after retrieving the keys, so if
  // an error occurs after this point then the keys would be unrecoverable.
  // The `finalize` call should be the last potentially error-causing line
  // before returning to the caller.

  if (launder32(private_key->config.hw_backed) == kHardenedBoolTrue) {
    HARDENED_CHECK_EQ(private_key->config.hw_backed, kHardenedBoolTrue);
    HARDENED_TRY(p256_sideload_keygen_finalize(session_token, pk));
  } else if (launder32(private_key->config.hw_backed) == kHardenedBoolFalse) {
    HARDENED_CHECK_EQ(private_key->config.hw_backed, kHardenedBoolFalse);

    // Randomize the keyblob before writing secret data.
    size_t keyblob_words = 0;
    HARDENED_TRY(keyblob_num_words(private_key->config, &keyblob_words));
    hardened_memshred(private_key->keyblob, keyblob_words);

    p256_masked_scalar_t *sk = (p256_masked_scalar_t *)private_key->keyblob;
    HARDENED_TRY(p256_keygen_finalize(session_token, sk, pk));
  } else {
    return OTCRYPTO_BAD_ARGS;
  }

  // Set the key checksums.
  private_key->checksum = integrity_blinded_checksum(private_key);
  public_key->checksum = integrity_unblinded_checksum(public_key);

  // Clear the ACC sideload slot (in case the seed was sideloaded).
  return keymgr_sideload_clear_acc();
}

otcrypto_status_t otcrypto_ecdsa_p256_keygen_async_finalize(
    otcrypto_session_token_t session_token, otcrypto_blinded_key_t *private_key,
    otcrypto_unblinded_key_t *public_key) {
  // Check for any NULL pointers.
  if (private_key == NULL || public_key == NULL ||
      private_key->keyblob == NULL || public_key->key == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Check the key modes.
  if (launder32(private_key->config.key_mode) != kOtcryptoKeyModeEcdsaP256 ||
      launder32(public_key->key_mode) != kOtcryptoKeyModeEcdsaP256) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(private_key->config.key_mode, kOtcryptoKeyModeEcdsaP256);
  HARDENED_CHECK_EQ(public_key->key_mode, kOtcryptoKeyModeEcdsaP256);

  return internal_p256_keygen_finalize(session_token, private_key, public_key);
}

otcrypto_status_t otcrypto_ecdsa_p256_sign_async_start(
    const otcrypto_blinded_key_t *private_key,
    const otcrypto_hash_digest_t message_digest,
    otcrypto_session_token_t *session_token) {
  if (private_key == NULL || private_key->keyblob == NULL ||
      message_digest.data == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Check that the entropy complex is initialized.
  HARDENED_TRY(entropy_complex_check());

  // Check the integrity of the private key.
  if (launder32(integrity_blinded_key_check(private_key)) !=
      kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(integrity_blinded_key_check(private_key),
                    kHardenedBoolTrue);

  if (launder32(private_key->config.key_mode) != kOtcryptoKeyModeEcdsaP256) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(private_key->config.key_mode, kOtcryptoKeyModeEcdsaP256);

  // Check the digest length.
  if (launder32(message_digest.len) != kP256ScalarWords) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(message_digest.len, kP256ScalarWords);

  // Check the key length.
  HARDENED_TRY(p256_private_key_length_check(private_key));

  if (launder32(private_key->config.hw_backed) == kHardenedBoolFalse) {
    // Start the asynchronous signature-generation routine.
    HARDENED_CHECK_EQ(private_key->config.hw_backed, kHardenedBoolFalse);
    p256_masked_scalar_t *sk = (p256_masked_scalar_t *)private_key->keyblob;
    return p256_ecdsa_sign_start(message_digest.data, sk, session_token);
  } else if (launder32(private_key->config.hw_backed) == kHardenedBoolTrue) {
    // Load the key and start in sideloaded-key mode.
    HARDENED_CHECK_EQ(private_key->config.hw_backed, kHardenedBoolTrue);
    HARDENED_TRY(keyblob_sideload_key_acc(private_key));
    HARDENED_TRY(
        p256_ecdsa_sideload_sign_start(message_digest.data, session_token));
  } else {
    // Invalid value for private_key->hw_backed.
    return OTCRYPTO_BAD_ARGS;
  }

  // To detect forgeries of the pointer to the private key that we have passed
  // to the ECC implementation, check its integrity again. If the pointer would
  // have been tampered with between the first integrity check we did when
  // entering cryptolib and here, we would detect this now.
  HARDENED_CHECK_EQ(integrity_blinded_key_check(private_key),
                    kHardenedBoolTrue);

  return OTCRYPTO_OK;
}

/**
 * Check the length of a signature buffer for ECDSA with P-256.
 *
 * If this check passes on `signature.len`, it is safe to interpret
 * `signature.data` as `p256_ecdsa_signature_t *`.
 *
 * @param len Length to check.
 * @return OK if the lengths are correct or BAD_ARGS otherwise.
 */
OT_WARN_UNUSED_RESULT
static status_t p256_signature_length_check(size_t len) {
  if (launder32(len) > UINT32_MAX / sizeof(uint32_t) ||
      launder32(len) * sizeof(uint32_t) != sizeof(p256_ecdsa_signature_t)) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(len * sizeof(uint32_t), sizeof(p256_ecdsa_signature_t));

  return OTCRYPTO_OK;
}

otcrypto_status_t otcrypto_ecdsa_p256_sign_async_finalize(
    otcrypto_session_token_t session_token, otcrypto_word32_buf_t signature) {
  if (signature.data == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Ensure the entropy complex is initialized.
  HARDENED_TRY(entropy_complex_check());

  HARDENED_TRY(p256_signature_length_check(signature.len));
  p256_ecdsa_signature_t *sig_p256 = (p256_ecdsa_signature_t *)signature.data;
  // Note: This operation wipes DMEM, so if an error occurs after this
  // point then the signature would be unrecoverable. This should be the
  // last potentially error-causing line before returning to the caller.
  HARDENED_TRY(p256_ecdsa_sign_finalize(session_token, sig_p256));

  // Clear the ACC sideload slot (in case the key was sideloaded).
  return keymgr_sideload_clear_acc();
}

otcrypto_status_t otcrypto_ecdsa_p256_attestation_endorse_async_start(
    const otcrypto_hash_digest_t message_digest,
    otcrypto_session_token_t *session_token) {
  return OTCRYPTO_NOT_IMPLEMENTED;
}

otcrypto_status_t otcrypto_ecdsa_p256_attestation_endorse_async_finalize(
    otcrypto_session_token_t session_token, otcrypto_word32_buf_t signature) {
  return OTCRYPTO_NOT_IMPLEMENTED;
}

otcrypto_status_t otcrypto_ecdsa_p256_verify_async_start(
    const otcrypto_unblinded_key_t *public_key,
    const otcrypto_hash_digest_t message_digest,
    otcrypto_const_word32_buf_t signature,
    otcrypto_session_token_t *session_token) {
  if (public_key == NULL || signature.data == NULL ||
      message_digest.data == NULL || public_key->key == NULL) {
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
  if (launder32(public_key->key_mode) != kOtcryptoKeyModeEcdsaP256) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(public_key->key_mode, kOtcryptoKeyModeEcdsaP256);

  // Check the public key size.
  HARDENED_TRY(p256_public_key_length_check(public_key));
  p256_point_t *pk = (p256_point_t *)public_key->key;

  // Check the digest length.
  if (launder32(message_digest.len) != kP256ScalarWords) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(message_digest.len, kP256ScalarWords);

  // Check the signature lengths.
  HARDENED_TRY(p256_signature_length_check(signature.len));
  p256_ecdsa_signature_t *sig = (p256_ecdsa_signature_t *)signature.data;

  // Start the asynchronous signature-verification routine.
  HARDENED_TRY(
      p256_ecdsa_verify_start(sig, message_digest.data, pk, session_token));

  // To detect forgeries of the pointer to the public key that we have passed
  // to the ECC implementation, check its integrity again. If the pointer would
  // have been tampered with between the first integrity check we did when
  // entering cryptolib and here, we would detect this now.
  HARDENED_CHECK_EQ(integrity_unblinded_key_check(public_key),
                    kHardenedBoolTrue);
  return OTCRYPTO_OK;
}

otcrypto_status_t otcrypto_ecdsa_p256_verify_async_finalize(
    otcrypto_const_word32_buf_t signature,
    otcrypto_session_token_t session_token,
    hardened_bool_t *verification_result) {
  if (verification_result == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Ensure the entropy complex is initialized.
  HARDENED_TRY(entropy_complex_check());

  HARDENED_TRY(p256_signature_length_check(signature.len));
  p256_ecdsa_signature_t *sig_p256 = (p256_ecdsa_signature_t *)signature.data;
  return p256_ecdsa_verify_finalize(sig_p256, session_token,
                                    verification_result);
}

otcrypto_status_t otcrypto_ecdh_p256_keygen_async_start(
    const otcrypto_blinded_key_t *private_key,
    otcrypto_session_token_t *session_token) {
  if (private_key == NULL || private_key->keyblob == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }

  if (launder32(private_key->config.key_mode) != kOtcryptoKeyModeEcdhP256) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(private_key->config.key_mode, kOtcryptoKeyModeEcdhP256);
  return internal_p256_keygen_start(session_token, private_key);
}

otcrypto_status_t otcrypto_ecdh_p256_keygen_async_finalize(
    otcrypto_session_token_t session_token, otcrypto_blinded_key_t *private_key,
    otcrypto_unblinded_key_t *public_key) {
  // Check for any NULL pointers.
  if (private_key == NULL || public_key == NULL ||
      private_key->keyblob == NULL || public_key->key == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }

  if (launder32(public_key->key_mode) != kOtcryptoKeyModeEcdhP256 ||
      launder32(private_key->config.key_mode) != kOtcryptoKeyModeEcdhP256) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(public_key->key_mode, kOtcryptoKeyModeEcdhP256);
  HARDENED_CHECK_EQ(private_key->config.key_mode, kOtcryptoKeyModeEcdhP256);
  return internal_p256_keygen_finalize(session_token, private_key, public_key);
}

otcrypto_status_t otcrypto_ecdh_p256_async_start(
    const otcrypto_blinded_key_t *private_key,
    const otcrypto_unblinded_key_t *public_key,
    otcrypto_session_token_t *session_token) {
  if (private_key == NULL || public_key == NULL || public_key->key == NULL ||
      private_key->keyblob == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Ensure the entropy complex is initialized.
  HARDENED_TRY(entropy_complex_check());

  // Check the integrity of the keys.
  if (launder32(integrity_blinded_key_check(private_key)) !=
          kHardenedBoolTrue ||
      launder32(integrity_unblinded_key_check(public_key)) !=
          kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(integrity_blinded_key_check(private_key),
                    kHardenedBoolTrue);
  HARDENED_CHECK_EQ(integrity_unblinded_key_check(public_key),
                    kHardenedBoolTrue);

  // Check the key modes.
  if (launder32(private_key->config.key_mode) != kOtcryptoKeyModeEcdhP256 ||
      launder32(public_key->key_mode) != kOtcryptoKeyModeEcdhP256) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(private_key->config.key_mode, kOtcryptoKeyModeEcdhP256);
  HARDENED_CHECK_EQ(public_key->key_mode, kOtcryptoKeyModeEcdhP256);

  // Check the key lengths.
  HARDENED_TRY(p256_private_key_length_check(private_key));
  HARDENED_TRY(p256_public_key_length_check(public_key));
  p256_point_t *pk = (p256_point_t *)public_key->key;

  if (launder32(private_key->config.hw_backed) == kHardenedBoolTrue) {
    HARDENED_CHECK_EQ(private_key->config.hw_backed, kHardenedBoolTrue);
    HARDENED_TRY(keyblob_sideload_key_acc(private_key));
    HARDENED_TRY(p256_sideload_ecdh_start(pk, session_token));
  } else if (launder32(private_key->config.hw_backed) == kHardenedBoolFalse) {
    HARDENED_CHECK_EQ(private_key->config.hw_backed, kHardenedBoolFalse);
    p256_masked_scalar_t *sk = (p256_masked_scalar_t *)private_key->keyblob;
    HARDENED_TRY(p256_ecdh_start(sk, pk, session_token));
  } else {
    // Invalid value for `hw_backed`.
    return OTCRYPTO_BAD_ARGS;
  }

  // To detect forgeries of the pointer to the public key that we have passed
  // to the ECC implementation, check its integrity again. If the pointer would
  // have been tampered with between the first integrity check we did when
  // entering cryptolib and here, we would detect this now.
  HARDENED_CHECK_EQ(integrity_blinded_key_check(private_key),
                    kHardenedBoolTrue);
  HARDENED_CHECK_EQ(integrity_unblinded_key_check(public_key),
                    kHardenedBoolTrue);

  return OTCRYPTO_OK;
}

otcrypto_status_t otcrypto_ecdh_p256_async_finalize(
    const otcrypto_blinded_key_t *private_key,
    otcrypto_session_token_t session_token,
    otcrypto_blinded_key_t *shared_secret) {
  if (shared_secret == NULL || shared_secret->keyblob == NULL ||
      private_key == NULL || private_key->keyblob == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Ensure the entropy complex is initialized.
  HARDENED_TRY(entropy_complex_check());

  // Shared keys cannot be sideloaded because they are software-generated.
  if (launder32(shared_secret->config.hw_backed) != kHardenedBoolFalse) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(shared_secret->config.hw_backed, kHardenedBoolFalse);

  // Check shared secret length.
  if (launder32(shared_secret->config.key_length) != kP256CoordBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(shared_secret->config.key_length, kP256CoordBytes);
  HARDENED_TRY(check_keyblob_length(shared_secret));

  // Note: This operation wipes DMEM after retrieving the keys, so if an error
  // occurs after this point then the keys would be unrecoverable. This should
  // be the last potentially error-causing line before returning to the caller.
  p256_ecdh_shared_key_t ss;
  hardened_memshred(ss.share0, ARRAYSIZE(ss.share0));
  hardened_memshred(ss.share1, ARRAYSIZE(ss.share1));

  if (launder32(private_key->config.hw_backed) == kHardenedBoolTrue) {
    HARDENED_CHECK_EQ(private_key->config.hw_backed, kHardenedBoolTrue);
    HARDENED_TRY(p256_sideload_ecdh_finalize(session_token, &ss));
  } else if (launder32(private_key->config.hw_backed) == kHardenedBoolFalse) {
    HARDENED_CHECK_EQ(private_key->config.hw_backed, kHardenedBoolFalse);
    HARDENED_TRY(p256_ecdh_finalize(session_token, &ss));
  } else {
    // Invalid value for `hw_backed`.
    return OTCRYPTO_BAD_ARGS;
  }

  HARDENED_TRY(keyblob_from_shares(ss.share0, ss.share1, shared_secret->config,
                                   shared_secret->keyblob));

  // Set the checksum.
  shared_secret->checksum = integrity_blinded_checksum(shared_secret);

  // Clear the ACC sideload slot (in case the seed was sideloaded).
  return keymgr_sideload_clear_acc();
}
