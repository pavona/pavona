// Copyright The mldsa-native project authors
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_MLDSA_FIPS202_GLUE_H_
#define OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_MLDSA_FIPS202_GLUE_H_
#include <stdint.h>

#include "mldsa/src/common.h"
#include "sw/device/lib/base/macros.h"
#include "sw/device/lib/crypto/drivers/kmac.h"
#include "sw/device/lib/crypto/include/sha3.h"

#define SHAKE128_RATE 168
#define SHAKE256_RATE 136

typedef struct {
} MLD_ALIGN mld_shake128ctx;

typedef struct {
} MLD_ALIGN mld_shake256ctx;

static MLD_INLINE void mld_shake128_absorb_once(mld_shake128ctx *state,
                                                const uint8_t *input,
                                                size_t inlen) {
  (void)state;
  kmac_shake128_begin();
  kmac_absorb(input, inlen);
  kmac_process();
}

static MLD_INLINE void mld_shake128_squeezeblocks(uint8_t *output,
                                                  size_t nblocks,
                                                  mld_shake128ctx *state) {
  (void)state;
  kmac_squeeze_blocks(nblocks, kHardenedBoolFalse, (uint32_t *)output, NULL);
}

static MLD_INLINE void mld_shake128_init(mld_shake128ctx *state) {
  (void)state;
  kmac_shake128_begin();
}

static MLD_INLINE void mld_shake128_absorb(mld_shake128ctx *state,
                                           const uint8_t *input, size_t inlen) {
  (void)state;
  kmac_absorb(input, inlen);
}

static MLD_INLINE void mld_shake128_finalize(mld_shake128ctx *state) {
  (void)state;
  kmac_process();
}

static MLD_INLINE void mld_shake128_squeeze(uint8_t *output, size_t outlen,
                                            mld_shake128ctx *state) {
  (void)state;
  size_t nblocks = outlen / SHAKE128_RATE;
  size_t remainder = outlen % SHAKE128_RATE;

  if (nblocks > 0) {
    kmac_squeeze_blocks(nblocks, kHardenedBoolFalse, (uint32_t *)output, NULL);
  }

  if (remainder > 0) {
    uint8_t block[SHAKE128_RATE];
    kmac_squeeze_blocks(1, kHardenedBoolFalse, (uint32_t *)block, NULL);
    for (size_t i = 0; i < remainder; i++) {
      output[nblocks * SHAKE128_RATE + i] = block[i];
    }
  }
}

static MLD_INLINE void mld_shake128_release(mld_shake128ctx *state) {
  (void)state;
  kmac_squeeze_end(0, kHardenedBoolFalse, NULL, NULL);
}

static MLD_INLINE void mld_shake256_absorb_once(mld_shake256ctx *state,
                                                const uint8_t *input,
                                                size_t inlen) {
  (void)state;
  kmac_shake256_begin();
  kmac_absorb(input, inlen);
  kmac_process();
}

static MLD_INLINE void mld_shake256_squeezeblocks(uint8_t *output,
                                                  size_t nblocks,
                                                  mld_shake256ctx *state) {
  (void)state;
  kmac_squeeze_blocks(nblocks, kHardenedBoolFalse, (uint32_t *)output, NULL);
}

static MLD_INLINE void mld_shake256_init(mld_shake256ctx *state) {
  (void)state;
  kmac_shake256_begin();
}

static MLD_INLINE void mld_shake256_absorb(mld_shake256ctx *state,
                                           const uint8_t *input, size_t inlen) {
  (void)state;
  kmac_absorb(input, inlen);
}

static MLD_INLINE void mld_shake256_finalize(mld_shake256ctx *state) {
  (void)state;
  kmac_process();
}

static MLD_INLINE void mld_shake256_squeeze(uint8_t *output, size_t outlen,
                                            mld_shake256ctx *state) {
  (void)state;
  size_t nblocks = outlen / SHAKE256_RATE;
  size_t remainder = outlen % SHAKE256_RATE;

  if (nblocks > 0) {
    kmac_squeeze_blocks(nblocks, kHardenedBoolFalse, (uint32_t *)output, NULL);
  }

  if (remainder > 0) {
    uint8_t block[SHAKE256_RATE];
    kmac_squeeze_blocks(1, kHardenedBoolFalse, (uint32_t *)block, NULL);
    for (size_t i = 0; i < remainder; i++) {
      output[nblocks * SHAKE256_RATE + i] = block[i];
    }
  }
}

static MLD_INLINE void mld_shake256_release(mld_shake256ctx *state) {
  (void)state;
  kmac_squeeze_end(0, kHardenedBoolFalse, NULL, NULL);
}

static MLD_INLINE void mld_shake256(uint8_t *output, size_t outlen,
                                    const uint8_t *input, size_t inlen) {
  otcrypto_hash_digest_t md = {.data = (uint32_t *)output,
                               .len = outlen / sizeof(uint32_t),
                               .mode = kOtcryptoHashXofModeShake256};

  otcrypto_const_byte_buf_t d = {.data = input, .len = inlen};

  otcrypto_shake256(d, &md);
}

static MLD_INLINE void mld_sha3_256(uint8_t *output, const uint8_t *input,
                                    size_t inlen) {
  otcrypto_hash_digest_t md = {.data = (uint32_t *)output,
                               .len = 32 / sizeof(uint32_t),
                               .mode = kOtcryptoHashModeSha3_256};

  otcrypto_const_byte_buf_t d = {.data = input, .len = inlen};

  otcrypto_sha3_256(d, &md);
}

static MLD_INLINE void mld_sha3_512(uint8_t *output, const uint8_t *input,
                                    size_t inlen) {
  otcrypto_hash_digest_t md = {.data = (uint32_t *)output,
                               .len = 64 / sizeof(uint32_t),
                               .mode = kOtcryptoHashModeSha3_512};

  otcrypto_const_byte_buf_t d = {.data = input, .len = inlen};

  otcrypto_sha3_512(d, &md);
}

#endif  // OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_MLDSA_FIPS202_GLUE_H_
