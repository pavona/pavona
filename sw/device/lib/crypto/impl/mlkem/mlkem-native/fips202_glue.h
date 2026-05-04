// Copyright The mlkem-native project authors
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_MLKEM_MLKEM_NATIVE_FIPS202_GLUE_H_
#define OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_MLKEM_MLKEM_NATIVE_FIPS202_GLUE_H_
#include <stdint.h>

#include "mlkem/src/common.h"
#include "sw/device/lib/crypto/drivers/kmac.h"
#include "sw/device/lib/crypto/include/sha3.h"

#define SHAKE128_RATE 168

typedef struct {
} MLK_ALIGN mlk_shake128ctx;

static MLK_INLINE void mlk_shake128_absorb_once(mlk_shake128ctx *state,
                                                const uint8_t *input,
                                                size_t inlen) {
  (void)state;
  kmac_shake128_begin();
  kmac_absorb(input, inlen);
  kmac_process();
}

static MLK_INLINE void mlk_shake128_squeezeblocks(uint8_t *output,
                                                  size_t nblocks,
                                                  mlk_shake128ctx *state) {
  (void)state;
  kmac_squeeze_blocks(nblocks, kHardenedBoolFalse, (uint32_t *)output, NULL);
}

static MLK_INLINE void mlk_shake128_init(mlk_shake128ctx *state) {
  (void)state;
}

static MLK_INLINE void mlk_shake128_release(mlk_shake128ctx *state) {
  (void)state;
  kmac_squeeze_end(0, kHardenedBoolFalse, NULL, NULL);
}

static MLK_INLINE void mlk_shake256(uint8_t *output, size_t outlen,
                                    const uint8_t *input, size_t inlen) {
  otcrypto_hash_digest_t md = {.data = (uint32_t *)output,
                               .len = outlen / 4,
                               .mode = kOtcryptoHashXofModeShake256};

  otcrypto_const_byte_buf_t d = {.data = input, .len = inlen};

  otcrypto_shake256(d, &md);
}

static MLK_INLINE void mlk_sha3_256(uint8_t *output, const uint8_t *input,
                                    size_t inlen) {
  otcrypto_hash_digest_t md = {.data = (uint32_t *)output,
                               .len = 32 / 4,
                               .mode = kOtcryptoHashModeSha3_256};

  otcrypto_const_byte_buf_t d = {.data = input, .len = inlen};

  otcrypto_sha3_256(d, &md);
}

static MLK_INLINE void mlk_sha3_512(uint8_t *output, const uint8_t *input,
                                    size_t inlen) {
  otcrypto_hash_digest_t md = {.data = (uint32_t *)output,
                               .len = 64 / 4,
                               .mode = kOtcryptoHashModeSha3_512};

  otcrypto_const_byte_buf_t d = {.data = input, .len = inlen};

  otcrypto_sha3_512(d, &md);
}

#endif  // OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_MLKEM_MLKEM_NATIVE_FIPS202_GLUE_H_
