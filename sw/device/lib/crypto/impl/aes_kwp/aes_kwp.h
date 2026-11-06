// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_AES_KWP_AES_KWP_H_
#define OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_AES_KWP_AES_KWP_H_

#include <stddef.h>
#include <stdint.h>

#include "sw/device/lib/base/hardened.h"
#include "sw/device/lib/base/macros.h"
#include "sw/device/lib/crypto/drivers/aes.h"

#ifdef __cplusplus
extern "C" {
#endif  // __cplusplus

/**
 * AES Key Wrapping with Padding (KWP) authenticated encryption.
 *
 * As defined by NIST SP800-38F (section 6.3, algorithm 5).
 *
 * The cipher block mode for the AES key should be ECB, since AES-KWP does not
 * use an IV.
 *
 * The key material must be aligned to 32-bit word boundaries for hardening
 * purposes. The length is still given in bytes. Bytes higher than the length
 * will be zeroed. The plaintext must be at least 16 bytes long, and must be
 * shorter than 2^32 bytes.
 *
 * The plaintext is wrapped in place. The buffer must be long enough to hold
 * the ciphertext, which is the plaintext length rounded up to the next
 * multiple of 64 bits, plus 64 bits.
 *
 * @param kek Key encryption key, AES key to encrypt with.
 * @param[in,out] buf Plaintext to wrap; overwritten by the ciphertext.
 * @param plaintext_len Plaintext length in bytes.
 * @return Error status; OK if no errors
 */
OT_WARN_UNUSED_RESULT
status_t aes_kwp_wrap(const aes_key_t kek, uint32_t *buf,
                      const size_t plaintext_len);

/**
 * AES Key Wrapping with Padding (KWP) authenticated decryption.
 *
 * As defined by NIST SP800-38F (section 6.3, algorithm 6).
 *
 * The cipher block mode for the AES key should be ECB, since AES-KWP does not
 * use an IV.
 *
 * The key material must be aligned to 32-bit word boundaries for hardening
 * purposes. The length is still given in bytes and bytes higher than the given
 * length are ignored (although they may be copied, so they should not be
 * uninitialized). The ciphertext must be at least 24 bytes long, and must be
 * shorter than 2^32 bytes.
 *
 * The ciphertext is unwrapped in place. On return, the plaintext starts at the
 * beginning of the buffer.
 *
 * An OK status from this routine does NOT mean that the unwrapping succeeded,
 * only that there were no errors during execution. The caller must check both
 * the returned status and the `success` parameter before reading the
 * plaintext.
 *
 * @param kek Key encryption key, AES key to decrypt with.
 * @param[in,out] buf Ciphertext to unwrap; overwritten by the plaintext.
 * @param ciphertext_len Ciphertext length in bytes.
 * @param[out] success Whether the ciphertext was valid.
 * @param[out] plaintext_len Plaintext length in bytes.
 * @return Error status; OK if no errors
 */
OT_WARN_UNUSED_RESULT
status_t aes_kwp_unwrap(const aes_key_t kek, uint32_t *buf,
                        const size_t ciphertext_len, hardened_bool_t *success,
                        size_t *plaintext_len);

#ifdef __cplusplus
}  // extern "C"
#endif  // __cplusplus

#endif  // OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_AES_KWP_AES_KWP_H_
