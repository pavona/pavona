// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
#ifndef OPENTITAN_SW_DEVICE_LIB_CRYPTO_DRIVERS_KMAC_H_
#define OPENTITAN_SW_DEVICE_LIB_CRYPTO_DRIVERS_KMAC_H_

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "sw/device/lib/base/macros.h"
#include "sw/device/lib/crypto/impl/status.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * The exposed costants to caller functions.
 */
enum {
  // The total size of prefix registers (in bytes), after removing len encodings
  kKmacPrefixMaxSize = 36,
  // The max size of customization string for KMAC.
  kKmacCustStrMaxSize = 32,
  // The size of the sideload key. This parameter is not exposed by KMAC or
  // Keymgr hjson files from HW, so we need to hardcode it for the moment.
  kKmacSideloadKeyLength = 256,
  // Length of a SHA3-224 digest in bytes.
  kKmacSha3224DigestBytes = 224 / 8,
  // Length of a SHA3-224 digest in 32-bit words.
  kKmacSha3224DigestWords = kKmacSha3224DigestBytes / sizeof(uint32_t),
  // Length of a SHA3_256 digest in bytes.
  kKmacSha3256DigestBytes = 256 / 8,
  // Length of a SHA3_256 digest in 32-bit words.
  kKmacSha3256DigestWords = kKmacSha3256DigestBytes / sizeof(uint32_t),
  // Length of a SHA3_384 digest in bytes.
  kKmacSha3384DigestBytes = 384 / 8,
  // Length of a SHA3_384 digest in 32-bit words.
  kKmacSha3384DigestWords = kKmacSha3384DigestBytes / sizeof(uint32_t),
  // Length of a SHA3_512 digest in bytes.
  kKmacSha3512DigestBytes = 512 / 8,
  // Length of a SHA3_512 digest in 32-bit words.
  kKmacSha3512DigestWords = kKmacSha3512DigestBytes / sizeof(uint32_t),
};

/**
 * Simplified key struct to pass blinded key internally.
 */
typedef struct kmac_blinded_key {
  uint32_t *share0;
  uint32_t *share1;
  // The length of single share (in bytes)
  size_t len;
  // Whether the key should be provided by keymgr through sideload port.
  // If `hw_backed` is true, `share0/1` pointers and `len` are ignored.
  hardened_bool_t hw_backed;
} kmac_blinded_key_t;

/**
 * Set the "global" config of HWIP
 *
 * For the moment, we have a number of configuation options needs to be
 * configured at session level. This functions serves as a temporary
 * solution by setting default values to this configuration.
 * TODO: Define config struct and pass it as argument.
 * TODO: see #14832
 *
 * Warning: This function sets `entropy_ready`, which triggers kmac_entropy's
 * FSM to jump to next step. Therefore, the caller of this function should make
 * sure that entropy is configured properly beforehand.
 *
 * It enforces the following as the default configuration:
 * It touches the following fields of CSRs:
 *   CFG register:
 *     endianness, entropy_mode, fast_process, msg_mask, ent_ready,
 * en_unsup_mode EDN refresh settings: hash threshold refresh
 * counter entropy seed -> ignore? INTR_ENABLE: all disabled
 *
 * @return Error code.
 */
OT_WARN_UNUSED_RESULT
status_t kmac_hwip_default_configure(void);

/**
 * Start a SHA-3-224 operation.
 *
 * Blocks until KMAC is idle.
 *
 * Make sure to call `kmac_process` and `kmac_squeeze_end` at some later point
 * to return the block to an idle state.
 *
 * @return Error code.
 */
OT_WARN_UNUSED_RESULT
status_t kmac_sha3_224_begin(void);

/**
 * Start a SHA-3-245 operation.
 *
 * Blocks until KMAC is idle.
 *
 * Make sure to call `kmac_process` and `kmac_squeeze_end` at some later point
 * to return the block to an idle state.
 *
 * @return Error code.
 */
OT_WARN_UNUSED_RESULT
status_t kmac_sha3_256_begin(void);

/**
 * Start a SHA-3-384 operation.
 *
 * Blocks until KMAC is idle.
 *
 * Make sure to call `kmac_process` and `kmac_squeeze_end` at some later point
 * to return the block to an idle state.
 *
 * @return Error code.
 */
OT_WARN_UNUSED_RESULT
status_t kmac_sha3_384_begin(void);

/**
 * Start a SHA-3-512 operation.
 *
 * Blocks until KMAC is idle.
 *
 * Make sure to call `kmac_process` and `kmac_squeeze_end` at some later point
 * to return the block to an idle state.
 *
 * @return Error code.
 */
OT_WARN_UNUSED_RESULT
status_t kmac_sha3_512_begin(void);

/**
 * Start a SHAKE-128 operation.
 *
 * Blocks until KMAC is idle.
 *
 * Make sure to call `kmac_process` and `kmac_squeeze_end` at some later point
 * to return the block to an idle state.
 *
 * @return Error code.
 */
OT_WARN_UNUSED_RESULT
status_t kmac_shake128_begin(void);

/**
 * Start a SHAKE-256 operation.
 *
 * Blocks until KMAC is idle.
 *
 * Make sure to call `kmac_process` and `kmac_squeeze_end` at some later point
 * to return the block to an idle state.
 *
 * @return Error code.
 */
OT_WARN_UNUSED_RESULT
status_t kmac_shake256_begin(void);

/**
 * Absorb a message for an ongoing operation.
 *
 * The operation must have been started before calling this. May be called
 * repeatedly.
 *
 * Make sure to call `kmac_process` and `kmac_squeeze_end` at some later point
 * to return the block to an idle state.
 *
 * @param message Message data to absorb.
 * @param message_len Message length in bytes.
 * @return Error code.
 */
OT_WARN_UNUSED_RESULT
status_t kmac_absorb(const uint8_t *message, size_t message_len);

/**
 * Tell KMAC to start processing the message.
 *
 * The operation must have been started before calling this.
 *
 * Make sure to call `kmac_squeeze_end` at some later point to return the block
 * to an idle state.
 */
void kmac_process(void);

/**
 * Read generated output from a SHA-3, SHAKE, cSHAKE, or KMAC operation.
 *
 * This operation expects that the process command has already been sent; call
 * `kmac_process` first.
 *
 * May be called repeatedly; does not return the hardware to its idle state
 * after reading the requested output. Always call `kmac_squeeze_end`
 * afterwards to clean up.
 *
 * The caller must ensure that there is an amount of space matching the Keccak
 * rate times the number of blocks available at `blocks_share0`. If
 * `read_masked` is set, there must also be the same amount of space available
 * at `blocks_share1`; otherwise, `blocks_share1` is ignored and may be NULL.
 *
 * @param nblocks Number of state blocks to read.
 * @param read_masked Whether to return the digest in two shares.
 * @param[out] blocks_share0 Destination for output (share if `read_masked`).
 * @param[out] blocks_share1 Destination for share of output (if `read_masked`).
 * @return Error code.
 */
OT_WARN_UNUSED_RESULT
status_t kmac_squeeze_blocks(size_t nblocks, hardened_bool_t read_masked,
                             uint32_t *blocks_share0, uint32_t *blocks_share1);

/**
 * Finish reading output from a SHA-3, SHAKE, cSHAKE, or KMAC operation.
 *
 * This operation expects that the process command has already been sent; call
 * `kmac_process` first.
 *
 * Unlike `kmac_squeeze_blocks`, returns the hardware to its idle state after
 * reading the requested output.
 *
 * The caller must ensure that there are `digest_wordlen` words available at
 * `digest_share0`. If `digest_wordlen` is 0, then both shares are ignored and
 * may be NULL. If `read_masked` is set, there must also be the same amount of
 * space available at `digest_share1`; otherwise, `digest_share1` is ignored
 * and may be NULL.
 *
 * @param digest_wordlen Requested digest length in 32-bit words.
 * @param read_masked Whether to return the digest in two shares.
 * @param[out] digest_share0 Destination for output (share if `read_masked`).
 * @param[out] digest_share1 Destination for share of output (if `read_masked`).
 * @return Error code.
 */
OT_WARN_UNUSED_RESULT
status_t kmac_squeeze_end(size_t digest_wordlen, hardened_bool_t read_masked,
                          uint32_t *digest_share0, uint32_t *digest_share1);

/**
 * Compute SHA-3-224 in one-shot.
 *
 * The caller must ensure that there is at least 224 bits = 28 bytes of space
 * available at the location pointed to by `digest`.
 *
 * @param message The input message.
 * @param message_len The input message length in bytes.
 * @param[out] digest Output buffer for the result.
 * @return Error status.
 */
OT_WARN_UNUSED_RESULT
status_t kmac_sha3_224(const uint8_t *message, size_t message_len,
                       uint32_t *digest);

/**
 * Compute SHA-3-256 in one-shot.
 *
 * The caller must ensure that there is at least 256 bits = 32 bytes of space
 * available at the location pointed to by `digest`.
 *
 * @param message The input message.
 * @param message_len The input message length in bytes.
 * @param[out] digest Output buffer for the result.
 * @return Error status.
 */
OT_WARN_UNUSED_RESULT
status_t kmac_sha3_256(const uint8_t *message, size_t message_len,
                       uint32_t *digest);

/**
 * Compute SHA-3-384 in one-shot.
 *
 * The caller must ensure that there is at least 384 bits = 48 bytes of space
 * available at the location pointed to by `digest`.
 *
 * @param message The input message.
 * @param message_len The input message length in bytes.
 * @param[out] digest Output buffer for the result.
 * @return Error status.
 */
OT_WARN_UNUSED_RESULT
status_t kmac_sha3_384(const uint8_t *message, size_t message_len,
                       uint32_t *digest);

/**
 * Compute SHA-3-512 in one-shot.
 *
 * The caller must ensure that there is at least 512 bits = 64 bytes of space
 * available at the location pointed to by `digest`.
 *
 * @param message The input message.
 * @param message_len The input message length in bytes.
 * @param[out] digest Output buffer for the result.
 * @return Error status.
 */
OT_WARN_UNUSED_RESULT
status_t kmac_sha3_512(const uint8_t *message, size_t message_len,
                       uint32_t *digest);

/**
 * Compute SHAKE-128 in one-shot.
 *
 * The caller must ensure that `digest_len` words are allocated at the location
 * pointed to by `digest`.
 *
 * @param message The input message.
 * @param message_len The input message length in bytes.
 * @param[out] digest Output buffer for the result.
 * @param digest_len Requested digest length in 32-bit words.
 * @return Error status.
 */
OT_WARN_UNUSED_RESULT
status_t kmac_shake_128(const uint8_t *message, size_t message_len,
                        uint32_t *digest, size_t digest_len);

/**
 * Compute SHAKE-256 in one-shot.
 *
 * The caller must ensure that `digest_len` words are allocated at the location
 * pointed to by `digest`.
 *
 * @param message The input message.
 * @param message_len The input message length in bytes.
 * @param[out] digest Output buffer for the result.
 * @param digest_len Requested digest length in 32-bit words.
 * @return Error status.
 */
OT_WARN_UNUSED_RESULT
status_t kmac_shake_256(const uint8_t *message, size_t message_len,
                        uint32_t *digest, size_t digest_len);

/**
 * Compute CSHAKE-128 in one-shot.
 *
 * The caller must ensure that `digest_len` words are allocated at the location
 * pointed to by `digest`.
 *
 * @param message The input message.
 * @param message_len The input message length in bytes.
 * @param func_name The function name.
 * @param func_name_len The function name length in bytes.
 * @param cust_str The customization string.
 * @param cust_str_len The customization string length in bytes.
 * @param[out] digest Output buffer for the result.
 * @param digest_len Requested digest length in 32-bit words.
 * @return Error status.
 */
OT_WARN_UNUSED_RESULT
status_t kmac_cshake_128(const uint8_t *message, size_t message_len,
                         const unsigned char *func_name, size_t func_name_len,
                         const unsigned char *cust_str, size_t cust_str_len,
                         uint32_t *digest, size_t digest_len);

/**
 * Compute CSHAKE-256 in one-shot.
 *
 * The caller must ensure that `digest_len` words are allocated at the location
 * pointed to by `digest`.
 *
 * @param message The input message.
 * @param message_len The input message length in bytes.
 * @param func_name The function name.
 * @param func_name_len The function name length in bytes.
 * @param cust_str The customization string.
 * @param cust_str_len The customization string length in bytes.
 * @param[out] digest Output buffer for the result.
 * @param digest_len Requested digest length in 32-bit words.
 * @return Error status.
 */
OT_WARN_UNUSED_RESULT
status_t kmac_cshake_256(const uint8_t *message, size_t message_len,
                         const unsigned char *func_name, size_t func_name_len,
                         const unsigned char *cust_str, size_t cust_str_len,
                         uint32_t *digest, size_t digest_len);

/**
 * Compute KMAC-128 in one-shot.
 *
 * This function also supports sideloading the key from the Keymgr through a
 * peripheral port inaccessible to SW. In order to sideload the key, the caller
 * needs to set `key->hw_backed` to `kHardenedBoolTrue`. When sideloading,
 * `key->length` must correspond to the sideload key size
 * `kKmacSideloadKeyLength / 8` and `share` pointers must be set to NULL.
 *
 * With SW-provided keys, `key->hw_backed` must be `kHardenedBoolFalse`, `share`
 * pointers must be correctly configured and `len` must match the key length.
 *
 * The caller must ensure that `digest_len` words are allocated at the location
 * pointed to by `digest`. `cust_str_len` must not exceed
 * `kKmacCustStrMaxSize`. If `masked_digest` is true, the `digest` buffer must
 * have enough space for 2x `digest_len` words.
 *
 * @param key The KMAC key.
 * @param masked_digest Whether to return the digest in concatenated shares.
 * @param message The input message.
 * @param message_len The input message length in bytes.
 * @param cust_str The customization string.
 * @param cust_str_len The customization string length in bytes.
 * @param[out] digest Output buffer for the result.
 * @param digest_len Requested digest length in 32-bit words.
 * @return Error status.
 */
OT_WARN_UNUSED_RESULT
status_t kmac_kmac_128(kmac_blinded_key_t *key, hardened_bool_t masked_digest,
                       const uint8_t *message, size_t message_len,
                       const unsigned char *cust_str, size_t cust_str_len,
                       uint32_t *digest, size_t digest_len);

/**
 * Compute KMAC-256 in one-shot.
 *
 * This function also supports sideloading the key from the Keymgr through a
 * peripheral port inaccessible to SW. In order to sideload the key, the caller
 * needs to set `key->hw_backed` to `kHardenedBoolTrue`. When sideloading,
 * `key->length` must correspond to the sideload key size
 * `kKmacSideloadKeyLength / 8` and `share` pointers must be set to NULL.
 *
 * With SW-provided keys, `key->hw_backed` must be `kHardenedBoolFalse`, `share`
 * pointers must be correctly configured and `len` must match the key length.
 *
 * The caller must ensure that `digest_len` words are allocated at the location
 * pointed to by `digest`. `cust_str_len` must not exceed
 * `kKmacCustStrMaxSize`. If `masked_digest` is true, the `digest` buffer must
 * have enough space for 2x `digest_len` words.
 *
 * @param key The KMAC key.
 * @param masked_digest Whether to return the digest in concatenated shares.
 * @param message The input message.
 * @param message_len The input message length in bytes.
 * @param cust_str The customization string.
 * @param cust_str_len The customization string length in bytes.
 * @param[out] digest Output buffer for the result.
 * @param digest_len Requested digest length in 32-bit words.
 * @return Error status.
 */
OT_WARN_UNUSED_RESULT
status_t kmac_kmac_256(kmac_blinded_key_t *key, hardened_bool_t masked_digest,
                       const uint8_t *message, size_t message_len,
                       const unsigned char *cust_str, size_t cust_str_len,
                       uint32_t *digest, size_t digest_len);

#ifdef __cplusplus
}
#endif

#endif  // OPENTITAN_SW_DEVICE_LIB_CRYPTO_DRIVERS_KMAC_H_
