// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/crypto/impl/rsa/rsa_encryption.h"

#include "sw/device/lib/base/hardened.h"
#include "sw/device/lib/base/hardened_memory.h"
#include "sw/device/lib/base/math.h"
#include "sw/device/lib/base/memory.h"
#include "sw/device/lib/crypto/drivers/entropy.h"
#include "sw/device/lib/crypto/impl/rsa/rsa_modexp.h"
#include "sw/device/lib/crypto/impl/rsa/rsa_padding.h"

// Module ID for status codes.
#define MODULE_ID MAKE_MODULE_ID('r', 'e', 'n')

status_t rsa_encrypt_2048_start(const rsa_2048_public_key_t *public_key,
                                const otcrypto_hash_mode_t hash_mode,
                                const uint8_t *message, size_t message_bytelen,
                                const uint8_t *label, size_t label_bytelen) {
  // Encode the message.
  rsa_2048_int_t encoded_message;
  hardened_memshred(encoded_message.data, ARRAYSIZE(encoded_message.data));
  HARDENED_TRY(rsa_padding_oaep_encode(
      hash_mode, message, message_bytelen, label, label_bytelen,
      ARRAYSIZE(encoded_message.data), encoded_message.data));

  // Start computing (encoded_message ^ e) mod n with a variable-time
  // exponentiation.
  return rsa_modexp_vartime_2048_start(&encoded_message, public_key->e,
                                       &public_key->n);
}

status_t rsa_encrypt_2048_finalize(rsa_2048_int_t *ciphertext) {
  return rsa_modexp_vartime_2048_finalize(ciphertext);
}

/**
 * Ensure that the provided RSA-2048 ciphertext is reduced with respect to the
 * provided RSA-2048 private key's modulus.
 *
 * @param private_key Private key to check against.
 * @param ciphertext Ciphertext to check.
 * @return Result of the operation (OK or BAD_ARGS).
 */
OT_WARN_UNUSED_RESULT
static status_t rsa_ciphertext_reduced_check_2048(
    const rsa_2048_private_key_t *private_key,
    const rsa_2048_int_t *ciphertext) {
  // Reconstruct n from the private key
  uint32_t n[kRsa2048NumWords];
  memset(n, 0, kRsa2048NumBytes);
  size_t i = 0;
  for (; launder32(i) < kRsa2048NumWords / 2; i++) {
    uint32_t carry = 0;
    size_t j = 0;
    for (; launder32(j) < kRsa2048NumWords / 2; j++) {
      uint64_t inner_prod =
          (uint64_t)private_key->p.data[j] * (uint64_t)private_key->q.data[i] +
          n[i + j] + carry;
      n[i + j] = inner_prod & 0xFFFFFFFF;
      carry = inner_prod >> 32;
    }
    HARDENED_CHECK_EQ(j, kRsa2048NumWords / 2);
    n[i + (kRsa2048NumWords / 2)] = carry;
  }
  HARDENED_CHECK_EQ(i, kRsa2048NumWords / 2);

  // Verify that the provided signature is less than n
  hardened_bool_t borrow = kHardenedBoolTrue;
  i = 0;
  for (; launder32(i) < kRsa2048NumWords; i++) {
    uint32_t n_limb = n[i];
    uint32_t ct_limb = ciphertext->data[i];
    if (launder32(borrow) == kHardenedBoolTrue) {
      HARDENED_CHECK_EQ(borrow, kHardenedBoolTrue);
      borrow = (n_limb <= ct_limb) ? kHardenedBoolTrue : kHardenedBoolFalse;
    } else {
      HARDENED_CHECK_EQ(borrow, kHardenedBoolFalse);
      borrow = (n_limb < ct_limb) ? kHardenedBoolTrue : kHardenedBoolFalse;
    }
  }
  HARDENED_CHECK_EQ(i, kRsa2048NumWords);

  if (launder32(borrow) == kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(borrow, kHardenedBoolFalse);
  return OTCRYPTO_OK;
}

status_t rsa_decrypt_2048_start(const rsa_2048_private_key_t *private_key,
                                const rsa_2048_int_t *ciphertext) {
  // Verify that the ciphertext is reduced
  HARDENED_TRY(rsa_ciphertext_reduced_check_2048(private_key, ciphertext));

  // Start computing (ciphertext ^ d) mod n.
  return rsa_modexp_consttime_crt_2048_start(
      ciphertext, &private_key->d_p, &private_key->d_q, &private_key->i_q,
      &private_key->p, &private_key->q);
}

status_t rsa_decrypt_finalize(const otcrypto_hash_mode_t hash_mode,
                              const uint8_t *label, size_t label_bytelen,
                              size_t plaintext_max_bytelen, uint8_t *plaintext,
                              size_t *plaintext_len) {
  // Wait for OTBN to complete and get the size for the last RSA operation.
  size_t num_words;
  HARDENED_TRY(rsa_modexp_wait(&num_words));

  // Check that enough space has been allocated for the plaintext.
  size_t max_plaintext_bytelen = 0;
  HARDENED_TRY(rsa_padding_oaep_max_message_bytelen(hash_mode, num_words,
                                                    &max_plaintext_bytelen));
  if (plaintext_max_bytelen < max_plaintext_bytelen) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_GE(plaintext_max_bytelen, max_plaintext_bytelen);

  // Randomize the plaintext destination buffer as best we can, considering its
  // alignment.
  ptrdiff_t misalignment = misalignment32_of((uintptr_t)plaintext);
  size_t aligned_offset =
      (sizeof(uint32_t) - (size_t)misalignment) % sizeof(uint32_t);
  size_t num_aligned_full_words =
      (plaintext_max_bytelen - aligned_offset) / sizeof(uint32_t);
  hardened_memshred((uint32_t *)((uintptr_t)plaintext + aligned_offset),
                    num_aligned_full_words);

  // Call the appropriate `finalize()` operation to get the recovered encoded
  // message.
  switch (num_words) {
    case kRsa2048NumWords: {
      rsa_2048_int_t recovered_message;
      HARDENED_TRY(rsa_modexp_consttime_2048_finalize(&recovered_message));
      return rsa_padding_oaep_decode(
          hash_mode, label, label_bytelen, recovered_message.data,
          ARRAYSIZE(recovered_message.data), plaintext, plaintext_len);
    }
    case kRsa3072NumWords: {
      rsa_3072_int_t recovered_message;
      HARDENED_TRY(rsa_modexp_consttime_3072_finalize(&recovered_message));
      return rsa_padding_oaep_decode(
          hash_mode, label, label_bytelen, recovered_message.data,
          ARRAYSIZE(recovered_message.data), plaintext, plaintext_len);
    }
    case kRsa4096NumWords: {
      rsa_4096_int_t recovered_message;
      HARDENED_TRY(rsa_modexp_consttime_4096_finalize(&recovered_message));
      return rsa_padding_oaep_decode(
          hash_mode, label, label_bytelen, recovered_message.data,
          ARRAYSIZE(recovered_message.data), plaintext, plaintext_len);
    }
    default:
      // Unexpected number of words; should never get here.
      return OTCRYPTO_FATAL_ERR;
  }

  // Should be unreachable.
  HARDENED_TRAP();
  return OTCRYPTO_FATAL_ERR;
}

status_t rsa_encrypt_3072_start(const rsa_3072_public_key_t *public_key,
                                const otcrypto_hash_mode_t hash_mode,
                                const uint8_t *message, size_t message_bytelen,
                                const uint8_t *label, size_t label_bytelen) {
  // Encode the message.
  rsa_3072_int_t encoded_message;
  hardened_memshred(encoded_message.data, ARRAYSIZE(encoded_message.data));
  HARDENED_TRY(rsa_padding_oaep_encode(
      hash_mode, message, message_bytelen, label, label_bytelen,
      ARRAYSIZE(encoded_message.data), encoded_message.data));

  // Start computing (encoded_message ^ e) mod n with a variable-time
  // exponentiation.
  return rsa_modexp_vartime_3072_start(&encoded_message, public_key->e,
                                       &public_key->n);
}

status_t rsa_encrypt_3072_finalize(rsa_3072_int_t *ciphertext) {
  return rsa_modexp_vartime_3072_finalize(ciphertext);
}

/**
 * Ensure that the provided RSA-3072 ciphertext is reduced with respect to the
 * provided RSA-3072 private key's modulus.
 *
 * @param private_key Private key to check against.
 * @param ciphertext Ciphertext to check.
 * @return Result of the operation (OK or BAD_ARGS).
 */
OT_WARN_UNUSED_RESULT
static status_t rsa_ciphertext_reduced_check_3072(
    const rsa_3072_private_key_t *private_key,
    const rsa_3072_int_t *ciphertext) {
  // Reconstruct n from the private key
  uint32_t n[kRsa3072NumWords];
  memset(n, 0, kRsa3072NumBytes);
  size_t i = 0;
  for (; launder32(i) < kRsa3072NumWords / 2; i++) {
    uint32_t carry = 0;
    size_t j = 0;
    for (; launder32(j) < kRsa3072NumWords / 2; j++) {
      uint64_t inner_prod =
          (uint64_t)private_key->p.data[j] * (uint64_t)private_key->q.data[i] +
          n[i + j] + carry;
      n[i + j] = inner_prod & 0xFFFFFFFF;
      carry = inner_prod >> 32;
    }
    HARDENED_CHECK_EQ(j, kRsa3072NumWords / 2);
    n[i + (kRsa3072NumWords / 2)] = carry;
  }
  HARDENED_CHECK_EQ(i, kRsa3072NumWords / 2);

  // Verify that the provided signature is less than n
  hardened_bool_t borrow = kHardenedBoolTrue;
  i = 0;
  for (; launder32(i) < kRsa3072NumWords; i++) {
    uint32_t n_limb = n[i];
    uint32_t ct_limb = ciphertext->data[i];
    if (launder32(borrow) == kHardenedBoolTrue) {
      HARDENED_CHECK_EQ(borrow, kHardenedBoolTrue);
      borrow = (n_limb <= ct_limb) ? kHardenedBoolTrue : kHardenedBoolFalse;
    } else {
      HARDENED_CHECK_EQ(borrow, kHardenedBoolFalse);
      borrow = (n_limb < ct_limb) ? kHardenedBoolTrue : kHardenedBoolFalse;
    }
  }
  HARDENED_CHECK_EQ(i, kRsa3072NumWords);

  if (launder32(borrow) == kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(borrow, kHardenedBoolFalse);
  return OTCRYPTO_OK;
}

status_t rsa_decrypt_3072_start(const rsa_3072_private_key_t *private_key,
                                const rsa_3072_int_t *ciphertext) {
  // Verify that the ciphertext is reduced
  HARDENED_TRY(rsa_ciphertext_reduced_check_3072(private_key, ciphertext));

  // Start computing (ciphertext ^ d) mod n.
  return rsa_modexp_consttime_crt_3072_start(
      ciphertext, &private_key->d_p, &private_key->d_q, &private_key->i_q,
      &private_key->p, &private_key->q);
}

status_t rsa_encrypt_4096_start(const rsa_4096_public_key_t *public_key,
                                const otcrypto_hash_mode_t hash_mode,
                                const uint8_t *message, size_t message_bytelen,
                                const uint8_t *label, size_t label_bytelen) {
  // Encode the message.
  rsa_4096_int_t encoded_message;
  hardened_memshred(encoded_message.data, ARRAYSIZE(encoded_message.data));
  HARDENED_TRY(rsa_padding_oaep_encode(
      hash_mode, message, message_bytelen, label, label_bytelen,
      ARRAYSIZE(encoded_message.data), encoded_message.data));

  // Start computing (encoded_message ^ e) mod n with a variable-time
  // exponentiation.
  return rsa_modexp_vartime_4096_start(&encoded_message, public_key->e,
                                       &public_key->n);
}

status_t rsa_encrypt_4096_finalize(rsa_4096_int_t *ciphertext) {
  return rsa_modexp_vartime_4096_finalize(ciphertext);
}

/**
 * Ensure that the provided RSA-4096 ciphertext is reduced with respect to the
 * provided RSA-4096 private key's modulus.
 *
 * @param private_key Private key to check against.
 * @param ciphertext Ciphertext to check.
 * @return Result of the operation (OK or BAD_ARGS).
 */
OT_WARN_UNUSED_RESULT
static status_t rsa_ciphertext_reduced_check_4096(
    const rsa_4096_private_key_t *private_key,
    const rsa_4096_int_t *ciphertext) {
  // Reconstruct n from the private key
  uint32_t n[kRsa4096NumWords];
  memset(n, 0, kRsa4096NumBytes);
  size_t i = 0;
  for (; launder32(i) < kRsa4096NumWords / 2; i++) {
    uint32_t carry = 0;
    size_t j = 0;
    for (; launder32(j) < kRsa4096NumWords / 2; j++) {
      uint64_t inner_prod =
          (uint64_t)private_key->p.data[j] * (uint64_t)private_key->q.data[i] +
          n[i + j] + carry;
      n[i + j] = inner_prod & 0xFFFFFFFF;
      carry = inner_prod >> 32;
    }
    HARDENED_CHECK_EQ(j, kRsa4096NumWords / 2);
    n[i + (kRsa4096NumWords / 2)] = carry;
  }
  HARDENED_CHECK_EQ(i, kRsa4096NumWords / 2);

  // Verify that the provided signature is less than n
  hardened_bool_t borrow = kHardenedBoolTrue;
  i = 0;
  for (; launder32(i) < kRsa4096NumWords; i++) {
    uint32_t n_limb = n[i];
    uint32_t ct_limb = ciphertext->data[i];
    if (launder32(borrow) == kHardenedBoolTrue) {
      HARDENED_CHECK_EQ(borrow, kHardenedBoolTrue);
      borrow = (n_limb <= ct_limb) ? kHardenedBoolTrue : kHardenedBoolFalse;
    } else {
      HARDENED_CHECK_EQ(borrow, kHardenedBoolFalse);
      borrow = (n_limb < ct_limb) ? kHardenedBoolTrue : kHardenedBoolFalse;
    }
  }
  HARDENED_CHECK_EQ(i, kRsa4096NumWords);

  if (launder32(borrow) == kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(borrow, kHardenedBoolFalse);
  return OTCRYPTO_OK;
}

status_t rsa_decrypt_4096_start(const rsa_4096_private_key_t *private_key,
                                const rsa_4096_int_t *ciphertext) {
  // Verify that the ciphertext is reduced
  HARDENED_TRY(rsa_ciphertext_reduced_check_4096(private_key, ciphertext));

  // Start computing (ciphertext ^ d) mod n.
  return rsa_modexp_consttime_crt_4096_start(
      ciphertext, &private_key->d_p, &private_key->d_q, &private_key->i_q,
      &private_key->p, &private_key->q);
}
