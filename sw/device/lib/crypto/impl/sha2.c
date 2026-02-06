// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/crypto/include/sha2.h"

#include <stdbool.h>

#include "sw/device/lib/base/crc32.h"
#include "sw/device/lib/base/hardened_memory.h"
#include "sw/device/lib/crypto/drivers/hmac.h"
#include "sw/device/lib/crypto/impl/status.h"

// Module ID for status codes.
#define MODULE_ID MAKE_MODULE_ID('s', 'h', '2')

// Ensure that the hash context is large enough for HMAC driver struct.
static_assert(
    sizeof(otcrypto_sha2_context_t) >= sizeof(hmac_ctx_t),
    "`otcrypto_sha2_context_t` must be big enough to hold `hmac_ctx_t`.");

/**
 * Compute the checksum of a SHA2 context.
 *
 * Call this routine after creating or modifying the SHA2 context.
 *
 * @param ctx SHA2 context.
 * @returns Checksum value.
 */
static inline uint32_t sha2_context_integrity_checksum(
    const otcrypto_sha2_context_t *ctx) {
  return crc32(ctx->data, sizeof(ctx->data));
}

/**
 * Perform an integrity check on the SHA2 context.
 *
 * Returns `kHardenedBoolTrue` if the check passed and `kHardenedBoolFalse`
 * otherwise.
 *
 * @param ctx SHA2 context.
 * @returns Whether the integrity check passed.
 */
OT_WARN_UNUSED_RESULT
static hardened_bool_t sha2_context_integrity_checksum_check(
    const otcrypto_sha2_context_t *ctx) {
  if (ctx->checksum == launder32(sha2_context_integrity_checksum(ctx))) {
    HARDENED_CHECK_EQ(ctx->checksum, sha2_context_integrity_checksum(ctx));
    return kHardenedBoolTrue;
  }
  return kHardenedBoolFalse;
}

otcrypto_status_t otcrypto_sha2_256(otcrypto_const_byte_buf_t message,
                                    otcrypto_hash_digest_t *digest) {
  if (message.data == NULL && message.len != 0) {
    return OTCRYPTO_BAD_ARGS;
  }

  if (digest->data == NULL ||
      launder32(digest->len) != kHmacSha256DigestWords) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(digest->len, kHmacSha256DigestWords);
  digest->mode = kOtcryptoHashModeSha256;

  return hmac_hash_sha256(message.data, message.len, digest->data);
}

otcrypto_status_t otcrypto_sha2_384(otcrypto_const_byte_buf_t message,
                                    otcrypto_hash_digest_t *digest) {
  if (message.data == NULL && message.len != 0) {
    return OTCRYPTO_BAD_ARGS;
  }

  if (digest->data == NULL ||
      launder32(digest->len) != kHmacSha384DigestWords) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(digest->len, kHmacSha384DigestWords);
  digest->mode = kOtcryptoHashModeSha384;

  return hmac_hash_sha384(message.data, message.len, digest->data);
}

otcrypto_status_t otcrypto_sha2_512(otcrypto_const_byte_buf_t message,
                                    otcrypto_hash_digest_t *digest) {
  if (message.data == NULL && message.len != 0) {
    return OTCRYPTO_BAD_ARGS;
  }

  if (digest->data == NULL ||
      launder32(digest->len) != kHmacSha512DigestWords) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(digest->len, kHmacSha512DigestWords);
  digest->mode = kOtcryptoHashModeSha512;

  return hmac_hash_sha512(message.data, message.len, digest->data);
}

otcrypto_status_t otcrypto_sha2_init(otcrypto_hash_mode_t hash_mode,
                                     otcrypto_sha2_context_t *ctx) {
  if (ctx == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }

  hmac_ctx_t hmac_ctx;
  switch (hash_mode) {
    case kOtcryptoHashModeSha256: {
      hmac_hash_sha256_init(&hmac_ctx);
      break;
    }
    case kOtcryptoHashModeSha384: {
      hmac_hash_sha384_init(&hmac_ctx);
      break;
    }
    case kOtcryptoHashModeSha512: {
      hmac_hash_sha512_init(&hmac_ctx);
      break;
    }
    default:
      // Unrecognized or unsupported hash mode.
      return OTCRYPTO_BAD_ARGS;
  }

  memcpy(ctx->data, &hmac_ctx, sizeof(hmac_ctx));

  // Compute the context integrity checksum.
  ctx->checksum = sha2_context_integrity_checksum(ctx);
  return OTCRYPTO_OK;
}

/**
 * Check that the message and digest sizes in a context are safe.
 *
 * Checking that these values are within maximum bounds protects from
 * out-of-bounds writes in the HMAC driver, in case a caller changes the
 * context in between calls.
 *
 * @param ctx HMAC context object.
 * @return OK or error.
 */
OT_WARN_UNUSED_RESULT
static status_t check_lengths(hmac_ctx_t *hmac_ctx) {
  if (launder32(hmac_ctx->msg_block_wordlen) > kHmacMaxBlockWords ||
      launder32(hmac_ctx->digest_wordlen) > kHmacMaxDigestWords) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_LE(hmac_ctx->msg_block_wordlen, kHmacMaxBlockWords);
  HARDENED_CHECK_LE(hmac_ctx->digest_wordlen, kHmacMaxDigestWords);
  return OTCRYPTO_OK;
}

otcrypto_status_t otcrypto_sha2_update(otcrypto_sha2_context_t *ctx,
                                       otcrypto_const_byte_buf_t message) {
  // Return early if the update size is 0.
  if (message.len == 0) {
    return OTCRYPTO_OK;
  }

  if (ctx == NULL || message.data == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Check the context integrity checksum.
  HARDENED_CHECK_EQ(sha2_context_integrity_checksum_check(ctx),
                    kHardenedBoolTrue);

  hmac_ctx_t *hmac_ctx = (hmac_ctx_t *)ctx->data;
  HARDENED_TRY(check_lengths(hmac_ctx));
  HARDENED_TRY(hmac_update(hmac_ctx, message.data, message.len));

  // Compute the context integrity checksum.
  ctx->checksum = sha2_context_integrity_checksum(ctx);
  return OTCRYPTO_OK;
}

otcrypto_status_t otcrypto_sha2_final(otcrypto_sha2_context_t *ctx,
                                      otcrypto_hash_digest_t *digest) {
  if (ctx == NULL || digest->data == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Check the context integrity checksum.
  HARDENED_CHECK_EQ(sha2_context_integrity_checksum_check(ctx),
                    kHardenedBoolTrue);

  hmac_ctx_t *hmac_ctx = (hmac_ctx_t *)ctx->data;
  HARDENED_TRY(check_lengths(hmac_ctx));

  if (launder32(digest->len) != hmac_ctx->digest_wordlen) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(digest->len, hmac_ctx->digest_wordlen);

  // Infer the mode from the digest length.
  switch (digest->len) {
    case kHmacSha256DigestWords:
      digest->mode = kOtcryptoHashModeSha256;
      break;
    case kHmacSha384DigestWords:
      digest->mode = kOtcryptoHashModeSha384;
      break;
    case kHmacSha512DigestWords:
      digest->mode = kOtcryptoHashModeSha512;
      break;
    default:
      return OTCRYPTO_BAD_ARGS;
  }

  return hmac_final(hmac_ctx, digest->data);
}
