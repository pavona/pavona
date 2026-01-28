// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/crypto/impl/aes_kwp/aes_kwp.h"

#include <stddef.h>
#include <stdint.h>

#include "hw/top/dt/dt_aes.h"
#include "sw/device/lib/base/abs_mmio.h"
#include "sw/device/lib/base/hardened.h"
#include "sw/device/lib/base/macros.h"
#include "sw/device/lib/base/math.h"
#include "sw/device/lib/crypto/drivers/aes.h"
#include "sw/device/lib/crypto/impl/status.h"

#include "hw/top/aes_regs.h"  // Generated.

// Module ID for status codes.
#define MODULE_ID MAKE_MODULE_ID('k', 'w', 'p')

enum {
  /** Number of bytes in a semiblock (half an AES block). */
  kSemiblockBytes = kAesBlockNumBytes / 2,
  /** Number of 32-bit words in a semiblock (half an AES block). */
  kSemiblockWords = kSemiblockBytes / sizeof(uint32_t),
};

static const dt_aes_t kAesDt = kDtAes;

static inline uint32_t aes_base(void) {
  return dt_aes_primary_reg_block(kAesDt);
}

/**
 * Spins until the AES hardware reports a specific status bit.
 */
OT_WARN_UNUSED_RESULT
static status_t aes_spin_until(uint32_t bit) {
  while (true) {
    uint32_t reg = abs_mmio_read32(aes_base() + AES_STATUS_REG_OFFSET);
    if (bitfield_bit32_read(reg, AES_STATUS_ALERT_RECOV_CTRL_UPDATE_ERR_BIT) ||
        bitfield_bit32_read(reg, AES_STATUS_ALERT_FATAL_FAULT_BIT)) {
      return OTCRYPTO_RECOV_ERR;
    }
    if (bitfield_bit32_read(reg, bit)) {
      return OTCRYPTO_OK;
    }
  }
}

status_t aes_kwp_wrap(const aes_key_t kek, uint32_t *plaintext,
                      const size_t plaintext_len, uint32_t *ciphertext) {
  // The plaintext length is expected to be at most 2^32 bytes.
  if (plaintext_len > UINT32_MAX || plaintext_len == 0) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Calculate the number of semiblocks needed for the plaintext (round up to
  // the next semiblock).
  size_t plaintext_semiblocks = ceil_div(plaintext_len, kSemiblockBytes);
  size_t pad_len = kSemiblockBytes * plaintext_semiblocks - plaintext_len;

  if (plaintext_semiblocks < 2) {
    // Plaintext is too short.
    return OTCRYPTO_BAD_ARGS;
  }

  // Load the AES block with the encryption key.
  HARDENED_TRY(aes_encrypt_begin(kek, /*iv=*/NULL));

  // Set the padding bytes for the plaintext if needed.
  unsigned char *pad_start = ((unsigned char *)plaintext) + plaintext_len;
  memset(pad_start, 0, pad_len);

  // This implementation follows the "indexing" method for the wrapping
  // function, as described in RFC 3394, section 2.2.1:
  //   https://datatracker.ietf.org/doc/html/rfc3394#section-2.2.1
  //
  // To avoid unnecessary copies while handling data that is naturally
  // expressed in semiblocks instead of blocks, some functionality from
  // aes_update() in the AES driver is inlined and modified here.

  // Construct the first semiblock (A): a fixed 32-bit prefix followed by the
  // byte-length encoded as a big-endian 32-bit integer.
  uint32_t *A = ciphertext;
  A[0] = 0xa65959a6;
  A[1] = __builtin_bswap32(plaintext_len);

  uint64_t t = 1;
  for (size_t j = 0; j < 6; j++) {
    uint32_t *Ri = ciphertext + kSemiblockWords;
    for (size_t i = 0; i < plaintext_semiblocks; i++) {
      HARDENED_TRY(aes_spin_until(AES_STATUS_INPUT_READY_BIT));

      // Send A || R[i] to the AES block.
      abs_mmio_write32(aes_base() + AES_DATA_IN_0_REG_OFFSET, A[0]);
      abs_mmio_write32(aes_base() + AES_DATA_IN_1_REG_OFFSET, A[1]);
      if (j == 0) {
        // For the first iteration of the outer loop, we fetch R[i] from the
        // plaintext.
        abs_mmio_write32(aes_base() + AES_DATA_IN_2_REG_OFFSET,
                         plaintext[i * kSemiblockWords]);
        abs_mmio_write32(aes_base() + AES_DATA_IN_3_REG_OFFSET,
                         plaintext[i * kSemiblockWords + 1]);
      } else {
        abs_mmio_write32(aes_base() + AES_DATA_IN_2_REG_OFFSET, Ri[0]);
        abs_mmio_write32(aes_base() + AES_DATA_IN_3_REG_OFFSET, Ri[1]);
      }

      HARDENED_TRY(aes_spin_until(AES_STATUS_OUTPUT_VALID_BIT));

      // Read the first half of the output into A.
      A[0] = abs_mmio_read32(aes_base() + AES_DATA_OUT_0_REG_OFFSET);
      A[1] = abs_mmio_read32(aes_base() + AES_DATA_OUT_1_REG_OFFSET);

      // Read the second half of the output into the ciphertext (R[i] for the
      // next j).
      Ri[0] = abs_mmio_read32(aes_base() + AES_DATA_OUT_2_REG_OFFSET);
      Ri[1] = abs_mmio_read32(aes_base() + AES_DATA_OUT_3_REG_OFFSET);

      // Encode the index and XOR it with A.
      A[0] ^= __builtin_bswap32((uint32_t)(t >> 32));
      A[1] ^= __builtin_bswap32((uint32_t)(t & UINT32_MAX));

      // Increment the index t and Ri.
      t++;
      Ri += kSemiblockWords;
    }
  }

  return OTCRYPTO_OK;
}

status_t aes_kwp_unwrap(const aes_key_t kek, const uint32_t *ciphertext,
                        const size_t ciphertext_len, hardened_bool_t *success,
                        uint32_t *plaintext) {
  // The ciphertext length is expected to be nonempty, at most 2^32 bytes, and
  // a multiple of the semiblock size.
  if (ciphertext_len > UINT32_MAX || ciphertext_len == 0 ||
      ciphertext_len % kSemiblockBytes != 0) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Calculate the number of semiblocks.
  size_t ciphertext_semiblocks = ciphertext_len / kSemiblockBytes;

  if (ciphertext_semiblocks < 3) {
    // Ciphertext is too short.
    return OTCRYPTO_BAD_ARGS;
  }

  // Load the AES block with the decryption key.
  HARDENED_TRY(aes_decrypt_begin(kek, /*iv=*/NULL));

  // This implementation follows the "indexing" method for the wrapping
  // function, as described in RFC 3394, section 2.2.2:
  //   https://datatracker.ietf.org/doc/html/rfc3394#section-2.2.2
  //
  // To avoid unnecessary copies while handling data that is naturally
  // expressed in semiblocks instead of blocks, some functionality from
  // aes_update() in the AES driver is inlined and modified here.

  // Construct A from the first semiblock of ciphertext.
  uint32_t A[kSemiblockWords];
  memcpy(A, ciphertext, sizeof(A));

  uint64_t t = 6 * ((uint64_t)ciphertext_semiblocks - 1);
  for (size_t j = 0; j < 6; j++) {
    uint32_t *Ri = plaintext + (ciphertext_semiblocks - 1) * kSemiblockWords;
    for (size_t i = ciphertext_semiblocks - 1; 1 <= i; i--) {
      // Encode the index and XOR it with the first semiblock (A ^ t).
      A[0] ^= __builtin_bswap32((uint32_t)(t >> 32));
      A[1] ^= __builtin_bswap32((uint32_t)(t & UINT32_MAX));
      t--;
      Ri -= kSemiblockWords;

      HARDENED_TRY(aes_spin_until(AES_STATUS_INPUT_READY_BIT));

      // Write A || R[i] into the AES block.
      abs_mmio_write32(aes_base() + AES_DATA_IN_0_REG_OFFSET, A[0]);
      abs_mmio_write32(aes_base() + AES_DATA_IN_1_REG_OFFSET, A[1]);
      if (j == 0) {
        // For the first iteration, we fetch Ri from the ciphertext.
        abs_mmio_write32(aes_base() + AES_DATA_IN_2_REG_OFFSET,
                         ciphertext[i * kSemiblockWords]);
        abs_mmio_write32(aes_base() + AES_DATA_IN_3_REG_OFFSET,
                         ciphertext[i * kSemiblockWords + 1]);
      } else {
        abs_mmio_write32(aes_base() + AES_DATA_IN_2_REG_OFFSET, Ri[0]);
        abs_mmio_write32(aes_base() + AES_DATA_IN_3_REG_OFFSET, Ri[1]);
      }

      HARDENED_TRY(aes_spin_until(AES_STATUS_OUTPUT_VALID_BIT));

      // Read the first half of the output into A.
      A[0] = abs_mmio_read32(aes_base() + AES_DATA_OUT_0_REG_OFFSET);
      A[1] = abs_mmio_read32(aes_base() + AES_DATA_OUT_1_REG_OFFSET);

      // Read the second half of the output into the ciphertext (R[i] for the
      // next j).
      Ri[0] = abs_mmio_read32(aes_base() + AES_DATA_OUT_2_REG_OFFSET);
      Ri[1] = abs_mmio_read32(aes_base() + AES_DATA_OUT_3_REG_OFFSET);
    }
  }

  // Decode bits 32-64 of A as the plaintext length.
  size_t plaintext_len = __builtin_bswap32(A[1]);
  size_t pad_len =
      kSemiblockBytes * (ciphertext_semiblocks - 1) - plaintext_len;

  // Check that the first 32 bits of A match the AES-KWP fixed prefix and that
  // the padding length is valid.
  if (launder32(A[0]) != 0xa65959a6 || pad_len >= kSemiblockBytes) {
    *success = kHardenedBoolFalse;
    memset(plaintext, 0, ciphertext_len);
    return OTCRYPTO_OK;
  }
  HARDENED_CHECK_EQ(A[0], 0xa65959a6);

  // Check that the padding bytes are zero. Note: this should happen only after
  // the prefix check. Otherwise it could expose a padding oracle, because
  // memcmp is not constant-time.
  if (pad_len != 0) {
    uint8_t exp_pad[pad_len];
    memset(exp_pad, 0, pad_len);
    unsigned char *pad_start = ((unsigned char *)plaintext) + plaintext_len;
    if (memcmp(pad_start, exp_pad, pad_len) != 0) {
      *success = kHardenedBoolFalse;
      memset(plaintext, 0, ciphertext_len);
      return OTCRYPTO_OK;
    }
  }

  // Return success.
  *success = kHardenedBoolTrue;
  return OTCRYPTO_OK;
}
