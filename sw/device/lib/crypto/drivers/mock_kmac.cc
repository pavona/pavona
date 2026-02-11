// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/base/hardened.h"
#include "sw/device/lib/crypto/drivers/kmac.h"
#include "sw/device/lib/crypto/impl/status.h"

/**
 * Basic mock of the KMAC driver.
 *
 * Enables on-host unit tests of code that use the KMAC driver.
 */

namespace test {
extern "C" {

// Array used for mock digest outputs.
static uint32_t digest[] = {
    0xa5a5a5a5, 0xa5a5a5a5, 0xa5a5a5a5, 0xa5a5a5a5, 0xa5a5a5a5, 0xa5a5a5a5,
    0xa5a5a5a5, 0xa5a5a5a5, 0xa5a5a5a5, 0xa5a5a5a5, 0xa5a5a5a5, 0xa5a5a5a5,
    0xa5a5a5a5, 0xa5a5a5a5, 0xa5a5a5a5, 0xa5a5a5a5,
};

// Byte index into digest array to include input from successive absorbs.
static size_t digest_idx = 0;

status_t kmac_hwip_default_configure(void) { return OTCRYPTO_OK; }

status_t kmac_sha3_224_begin(void) { return OTCRYPTO_OK; }

status_t kmac_sha3_256_begin(void) { return OTCRYPTO_OK; }

status_t kmac_sha3_384_begin(void) { return OTCRYPTO_OK; }

status_t kmac_sha3_512_begin(void) { return OTCRYPTO_OK; }

status_t kmac_shake128_begin(void) { return OTCRYPTO_OK; }

status_t kmac_shake256_begin(void) { return OTCRYPTO_OK; }

status_t kmac_absorb(const uint8_t *message, size_t message_len) {
  // We simply copy as much of the message to the digest as we can, wrapping
  // around as needd. This ensures that at least messages with different tails
  // result in different digests.
  uint8_t *digest_bytes = (uint8_t *)digest;
  for (size_t i = 0; i < message_len; i++) {
    digest_bytes[digest_idx] = message[i];
    digest_idx = (digest_idx + 1) % sizeof(digest);
  }
  return OTCRYPTO_OK;
}

void kmac_process(void) {}

status_t kmac_squeeze_blocks(size_t nblocks, hardened_bool_t read_masked,
                             uint32_t *blocks_share0, uint32_t *blocks_share1) {
  // Not implemented for simplicity, existing unit tests don't currently use
  // this function.
  return OTCRYPTO_NOT_IMPLEMENTED;
}

status_t kmac_squeeze_end(size_t digest_wordlen, hardened_bool_t read_masked,
                          uint32_t *digest_share0, uint32_t *digest_share1) {
  // Copy the digest out.
  size_t digest_bytelen = digest_wordlen * sizeof(uint32_t);
  memcpy(digest_share0, digest, digest_bytelen);
  if (read_masked == kHardenedBoolTrue) {
    memset(digest_share1, 0, digest_bytelen);
  }

  // Reset the digest state.
  memset(digest, 0xa5, sizeof(digest));
  digest_idx = 0;

  return OTCRYPTO_OK;
}

status_t kmac_sha3_224(const uint8_t *message, size_t message_len,
                       uint32_t *digest) {
  return OTCRYPTO_OK;
}

status_t kmac_sha3_256(const uint8_t *message, size_t message_len,
                       uint32_t *digest) {
  return OTCRYPTO_OK;
}

status_t kmac_sha3_384(const uint8_t *message, size_t message_len,
                       uint32_t *digest) {
  return OTCRYPTO_OK;
}

status_t kmac_sha3_512(const uint8_t *message, size_t message_len,
                       uint32_t *digest) {
  return OTCRYPTO_OK;
}

status_t kmac_shake_128(const uint8_t *message, size_t message_len,
                        uint32_t *digest, size_t digest_len) {
  return OTCRYPTO_OK;
}

status_t kmac_shake_256(const uint8_t *message, size_t message_len,
                        uint32_t *digest, size_t digest_len) {
  return OTCRYPTO_OK;
}

status_t kmac_cshake_128(const uint8_t *message, size_t message_len,
                         const unsigned char *func_name, size_t func_name_len,
                         const unsigned char *cust_str, size_t cust_str_len,
                         uint32_t *digest, size_t digest_len) {
  return OTCRYPTO_OK;
}

status_t kmac_cshake_256(const uint8_t *message, size_t message_len,
                         const unsigned char *func_name, size_t func_name_len,
                         const unsigned char *cust_str, size_t cust_str_len,
                         uint32_t *digest, size_t digest_len) {
  return OTCRYPTO_OK;
}

status_t kmac_kmac_128(kmac_blinded_key_t *key, hardened_bool_t masked_digest,
                       const uint8_t *message, size_t message_len,
                       const unsigned char *cust_str, size_t cust_str_len,
                       uint32_t *digest, size_t digest_len) {
  return OTCRYPTO_OK;
}

status_t kmac_kmac_256(kmac_blinded_key_t *key, hardened_bool_t masked_digest,
                       const uint8_t *message, size_t message_len,
                       const unsigned char *cust_str, size_t cust_str_len,
                       uint32_t *digest, size_t digest_len) {
  return OTCRYPTO_OK;
}
}
}  // namespace test
