// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/crypto/include/drbg.h"

#include "sw/device/lib/base/hardened_memory.h"
#include "sw/device/lib/base/math.h"
#include "sw/device/lib/crypto/drivers/entropy.h"
#include "sw/device/lib/crypto/impl/status.h"
#include "sw/device/lib/crypto/include/datatypes.h"

// Module ID for status codes.
#define MODULE_ID MAKE_MODULE_ID('r', 'b', 'g')

/**
 * Construct seed material for the CSRNG.
 *
 * Returns `OTCRYPTO_BAD_ARGS` if the provided value is longer than the entropy
 * complex can absorb. If the value is shorter, it will be padded with zeroes.
 *
 * This operation is not constant-time relative to `value.len`.
 *
 * @param value Seed data.
 * @param[out] seed_material Resulting entropy complex seed.
 * @return OK or error.
 */
OT_WARN_UNUSED_RESULT
static status_t seed_material_construct(
    otcrypto_const_byte_buf_t value, entropy_seed_material_t *seed_material) {
  if (value.len > kEntropySeedBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  seed_material->len = value.len > 0 ? kEntropySeedWords : 0;

  // Copy all complete words of the value into the seed. Note that because
  // `seed_material` is stored in reverse byte order from the byte array of the
  // same name in SP 800-90Ar1 (to allow for direct use by the CSRNG without
  // byte reordering), this copy needs to happen from the tail of the array
  // backward.
  size_t full_words = value.len / sizeof(uint32_t);
  for (size_t i = 0; i < full_words; i++) {
    uint32_t value_word;
    memcpy(&value_word, value.data + i * sizeof(uint32_t), sizeof(uint32_t));
    seed_material->data[(kEntropySeedWords - 1) - i] =
        __builtin_bswap32(value_word);
  }

  // Copy the remaining bytes of the value, if any, into the seed.
  size_t bytes_left = value.len % sizeof(uint32_t);
  if (bytes_left != 0) {
    uint32_t value_word = 0;
    memcpy(&value_word, value.data + full_words * sizeof(uint32_t), bytes_left);
    seed_material->data[(kEntropySeedWords - 1) - full_words] =
        __builtin_bswap32(value_word);
  }

  // Set any unset bytes to zero.
  memset(seed_material->data, 0, kEntropySeedBytes - value.len);

  return OTCRYPTO_OK;
}

/**
 * XOR the entropy seed with another value.
 *
 * Returns `OTCRYPTO_BAD_ARGS` if the provided value is longer than the seed.
 * If the value is shorter, only the tail of `seed_material` (corresponding
 * to the first bytes of the byte array of the same name in SP 800-90Ar1) will
 * be XORed.
 *
 * This operation is not constant-time relative to `value.len`.
 *
 * @param value Value to XOR with seed data.
 * @param seed_material Entropy complex seed, modified in-place.
 * @return OK or error.
 */
OT_WARN_UNUSED_RESULT
static otcrypto_status_t seed_material_xor(
    otcrypto_const_byte_buf_t value, entropy_seed_material_t *seed_material) {
  if (value.len > kEntropySeedBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (value.len == 0) {
    return OTCRYPTO_OK;
  }

  // XOR in all complete words of the value into the seed. Note that because
  // `seed_material` is stored in reverse byte order from the byte array of the
  // same name in SP 800-90Ar1 (to allow for direct use by the CSRNG without
  // byte reordering), this XOR needs to happen from the tail of the array
  // backward.
  size_t full_words = value.len / sizeof(uint32_t);
  for (size_t i = 0; i < full_words; i++) {
    uint32_t value_word;
    memcpy(&value_word, value.data + i * sizeof(uint32_t), sizeof(uint32_t));
    seed_material->data[(kEntropySeedWords - 1) - i] ^=
        __builtin_bswap32(value_word);
  }

  // XOR the remaining bytes of the value, if any, into the seed.
  size_t bytes_left = value.len % sizeof(uint32_t);
  if (bytes_left != 0) {
    uint32_t value_word = 0;
    memcpy(&value_word, value.data + full_words * sizeof(uint32_t), bytes_left);
    seed_material->data[(kEntropySeedWords - 1) - full_words] ^=
        __builtin_bswap32(value_word);
  }

  return OTCRYPTO_OK;
}

otcrypto_status_t otcrypto_drbg_instantiate(
    otcrypto_const_byte_buf_t perso_string) {
  // Check for NULL pointers or bad length.
  if (perso_string.len != 0 && perso_string.data == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Ensure the entropy complex is initialized.
  HARDENED_TRY(entropy_complex_check());

  entropy_seed_material_t seed_material;
  hardened_memshred(seed_material.data, ARRAYSIZE(seed_material.data));
  HARDENED_TRY(seed_material_construct(perso_string, &seed_material));

  HARDENED_TRY(entropy_csrng_uninstantiate());
  return entropy_csrng_instantiate(/*disable_trng_input=*/kHardenedBoolFalse,
                                   &seed_material);
}

otcrypto_status_t otcrypto_drbg_reseed(
    otcrypto_const_byte_buf_t additional_input) {
  // Check for NULL pointers or bad length.
  if (additional_input.len != 0 && additional_input.data == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Ensure the entropy complex is initialized.
  HARDENED_TRY(entropy_complex_check());

  entropy_seed_material_t seed_material;
  hardened_memshred(seed_material.data, ARRAYSIZE(seed_material.data));
  HARDENED_TRY(seed_material_construct(additional_input, &seed_material));

  return entropy_csrng_reseed(/*disable_trng_input=*/kHardenedBoolFalse,
                              &seed_material);
}

otcrypto_status_t otcrypto_drbg_manual_instantiate(
    otcrypto_const_byte_buf_t entropy, otcrypto_const_byte_buf_t perso_string) {
  // Check for NULL pointers or bad length.
  if (perso_string.len != 0 && perso_string.data == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (entropy.data == NULL || entropy.len != kEntropySeedBytes) {
    return OTCRYPTO_BAD_ARGS;
  }

  entropy_seed_material_t seed_material;
  HARDENED_TRY(seed_material_construct(entropy, &seed_material));
  HARDENED_TRY(seed_material_xor(perso_string, &seed_material));

  HARDENED_CHECK_EQ(seed_material.len, kEntropySeedWords);

  return entropy_csrng_instantiate(/*disable_trng_input=*/kHardenedBoolTrue,
                                   &seed_material);
}

otcrypto_status_t otcrypto_drbg_manual_reseed(
    otcrypto_const_byte_buf_t entropy,
    otcrypto_const_byte_buf_t additional_input) {
  // Check for NULL pointers or bad length.
  if (additional_input.len != 0 && additional_input.data == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }
  if (entropy.data == NULL || entropy.len != kEntropySeedBytes) {
    return OTCRYPTO_BAD_ARGS;
  }

  entropy_seed_material_t seed_material;
  HARDENED_TRY(seed_material_construct(entropy, &seed_material));
  HARDENED_TRY(seed_material_xor(additional_input, &seed_material));

  HARDENED_CHECK_EQ(seed_material.len, kEntropySeedWords);

  return entropy_csrng_reseed(/*disable_trng_input=*/kHardenedBoolTrue,
                              &seed_material);
}

/**
 * Common function for random-bit generation.
 *
 * Used for both `otcrypto_drbg_generate` and `otcrypto_drbg_manual_generate`,
 * which have the same implementation except for one flag that determines
 * whether we check that the flag for FIPS compatibility is true.
 *
 * @param additional_input Additional input to DRBG
 * @param fips_check Whether to check FIPS hardware flags
 * @param[out] drbg_output Buffer for output
 * @return Result status; OK or error
 */
OT_WARN_UNUSED_RESULT
static otcrypto_status_t generate(hardened_bool_t fips_check,
                                  otcrypto_const_byte_buf_t additional_input,
                                  otcrypto_word32_buf_t drbg_output) {
  if (drbg_output.len == 0) {
    // Nothing to do.
    return OTCRYPTO_OK;
  }
  if ((additional_input.len != 0 && additional_input.data == NULL) ||
      drbg_output.data == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }

  entropy_seed_material_t seed_material;
  HARDENED_TRY(seed_material_construct(additional_input, &seed_material));
  HARDENED_TRY(entropy_csrng_generate(&seed_material, drbg_output.data,
                                      drbg_output.len, fips_check));
  // Byte swap each word of the generated value. Note that because `drbg_output`
  // is returned in big-endian words (as the CSRNG hardware outputs results in
  // reverse byte order), a byte swap is required in order to provide the output
  // in little-endian.
  for (size_t i = 0; i < drbg_output.len; i++) {
    drbg_output.data[i] = __builtin_bswap32(drbg_output.data[i]);
  }

  return OTCRYPTO_OK;
}

otcrypto_status_t otcrypto_drbg_generate(
    otcrypto_const_byte_buf_t additional_input,
    otcrypto_word32_buf_t drbg_output) {
  // Ensure the entropy complex is initialized.
  HARDENED_TRY(entropy_complex_check());

  // Randomize destination buffer.
  hardened_memshred(drbg_output.data, drbg_output.len);

  return generate(/*fips_check=*/kHardenedBoolTrue, additional_input,
                  drbg_output);
}

otcrypto_status_t otcrypto_drbg_manual_generate(
    otcrypto_const_byte_buf_t additional_input,
    otcrypto_word32_buf_t drbg_output) {
  return generate(/*fips_check=*/kHardenedBoolFalse, additional_input,
                  drbg_output);
}

otcrypto_status_t otcrypto_drbg_uninstantiate(void) {
  return entropy_csrng_uninstantiate();
}
