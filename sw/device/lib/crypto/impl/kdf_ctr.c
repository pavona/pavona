// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/crypto/include/kdf_ctr.h"

#include "sw/device/lib/base/hardened_memory.h"
#include "sw/device/lib/base/macros.h"
#include "sw/device/lib/base/math.h"
#include "sw/device/lib/crypto/drivers/entropy.h"
#include "sw/device/lib/crypto/drivers/hmac.h"
#include "sw/device/lib/crypto/impl/integrity.h"
#include "sw/device/lib/crypto/impl/keyblob.h"
#include "sw/device/lib/crypto/impl/status.h"
#include "sw/device/lib/crypto/include/datatypes.h"
#include "sw/device/lib/crypto/include/hmac.h"

// Module ID for status codes.
#define MODULE_ID MAKE_MODULE_ID('c', 'k', 'd')

// Bounds the number of iterations in `otcrypto_kdf_ctr_hmac`.
OT_ASSERT_MEMBER_SIZE(otcrypto_key_config_t, key_length, 4);

/**
 * Infer the digest length in 32-bit words for the given hash function.
 *
 * @param key_mode HMAC key mode.
 * @param[out] digest_words Number of words in the hash digest.
 * @return OK or error.
 */
OT_WARN_UNUSED_RESULT
static status_t digest_num_words_from_key_mode(otcrypto_key_mode_t key_mode,
                                               size_t *digest_words) {
  *digest_words = 0;
  switch (launder32(key_mode)) {
    case kOtcryptoKeyModeHmacSha256:
      HARDENED_CHECK_EQ(key_mode, kOtcryptoKeyModeHmacSha256);
      *digest_words = 256 / 32;
      break;
    case kOtcryptoKeyModeHmacSha384:
      HARDENED_CHECK_EQ(key_mode, kOtcryptoKeyModeHmacSha384);
      *digest_words = 384 / 32;
      break;
    case kOtcryptoKeyModeHmacSha512:
      HARDENED_CHECK_EQ(key_mode, kOtcryptoKeyModeHmacSha512);
      *digest_words = 512 / 32;
      break;
    default:
      return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_NE(*digest_words, 0);
  return OTCRYPTO_OK;
}

otcrypto_status_t otcrypto_kdf_ctr_hmac(
    const otcrypto_blinded_key_t *key_derivation_key,
    const otcrypto_const_byte_buf_t fixed_data,
    otcrypto_blinded_key_t *output_key_material) {
  // Check NULL pointers.
  if (output_key_material == NULL || output_key_material->keyblob == NULL ||
      key_derivation_key->keyblob == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }

  if (launder32(output_key_material->config.security_level) !=
          kOtcryptoKeySecurityLevelPassiveRemote ||
      launder32(key_derivation_key->config.security_level) !=
          kOtcryptoKeySecurityLevelPassiveRemote) {
    // The underlying HMAC implementation is not currently hardened.
    return OTCRYPTO_NOT_IMPLEMENTED;
  }

  // Check for null fixed data with nonzero length.
  if (fixed_data.data == NULL && fixed_data.len != 0) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Check the private key checksum.
  if (integrity_blinded_key_check(key_derivation_key) != kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Check non-zero length for output_key_material.
  if (output_key_material->config.key_length == 0) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Infer the digest size.
  size_t digest_word_len = 0;
  HARDENED_TRY(digest_num_words_from_key_mode(
      key_derivation_key->config.key_mode, &digest_word_len));

  // Ensure that the derived key is a symmetric key masked with XOR and is not
  // supposed to be hardware-backed.
  HARDENED_TRY(keyblob_ensure_xor_masked(output_key_material->config));

  // Check `output_key_material` key length.
  if (output_key_material->config.hw_backed == kHardenedBoolTrue) {
    // The case where `output_key_material` is hw_backed is addressed by
    // `otcrypto_hw_backed_key` function in `key_transport.h`.
    return OTCRYPTO_BAD_ARGS;
  } else if (output_key_material->config.hw_backed == kHardenedBoolFalse) {
    TRY(check_keyblob_length(output_key_material));
  } else {
    return OTCRYPTO_BAD_ARGS;
  }

  size_t required_byte_len = output_key_material->config.key_length;
  size_t required_word_len = ceil_div(required_byte_len, sizeof(uint32_t));
  size_t num_iterations = ceil_div(required_word_len, digest_word_len);
  // NIST SP 800-108r1, section 4.1, requires `num_iterations` <= 2^32 - 1 for
  // the 32-bit counter `i + 1` below. `key_length` is a `uint32_t`, which
  // bounds `num_iterations` by 2^27.

  // Entropy complex must be initialized for `hardened_memcpy` below.
  HARDENED_TRY(entropy_complex_check());

  // Randomize the keyblob buffer. Since we populate the keyblob in place (in
  // order to avoid allocating a pair of OKM-sized VLAs), we must shred the
  // keyblob buffer now; this matches keyblob_from_key_and_mask.
  size_t num_words = 0;
  HARDENED_TRY(keyblob_num_words(output_key_material->config, &num_words));
  hardened_memshred(output_key_material->keyblob, num_words);

  // Split the OKM into shares.
  uint32_t *okm_share0;
  uint32_t *okm_share1;
  HARDENED_TRY(
      keyblob_to_shares(output_key_material, &okm_share0, &okm_share1));

  // Repeatedly call HMAC to generate the derived key based on input data:
  // [i]_2 || FixedData
  // (see NIST SP 800-108r1, section 4.1)
  // [i]_2 is the binary representation of the counter value
  // The counter value is updated within the loop

  for (uint32_t i = 0; launder32(i) < num_iterations; i++) {
    otcrypto_hmac_context_t ctx;
    HARDENED_TRY(otcrypto_hmac_init(&ctx, key_derivation_key));
    uint32_t counter_be = __builtin_bswap32(i + 1);
    HARDENED_TRY(otcrypto_hmac_update(
        &ctx, (otcrypto_const_byte_buf_t){
                  .data = (const unsigned char *const)&counter_be,
                  .len = sizeof(counter_be)}));
    HARDENED_TRY(otcrypto_hmac_update(&ctx, fixed_data));
    uint32_t *tag_dest = okm_share0 + i * digest_word_len;
    size_t words_left = required_word_len - i * digest_word_len;
    if (words_left < digest_word_len) {
      // Compute the HMAC tag into a separate buffer; we don't want to place the
      // entire tag into the OKM keyblob as there isn't room left for it. The
      // result is moved into the OKM keyblob via a hardened memcpy, to match
      // how keyblob_from_key_and_mask copies key material.
      uint32_t tag_data[kHmacMaxDigestWords];
      otcrypto_word32_buf_t tag_words = {
          .data = tag_data,
          .len = digest_word_len,
      };
      HARDENED_TRY(otcrypto_hmac_final(&ctx, tag_words));
      hardened_memcpy(tag_dest, tag_data, words_left);
    } else {
      // Compute and store the HMAC tag directly in the OKM buffer.
      otcrypto_word32_buf_t tag_words = {
          .data = tag_dest,
          .len = digest_word_len,
      };
      HARDENED_TRY(otcrypto_hmac_final(&ctx, tag_words));
    }
  }

  // Generate a mask (all-zero for now, since HMAC is unhardened anyway).
  memset(okm_share1, 0, output_key_material->config.key_length);

  output_key_material->checksum =
      integrity_blinded_checksum(output_key_material);

  return OTCRYPTO_OK;
}
