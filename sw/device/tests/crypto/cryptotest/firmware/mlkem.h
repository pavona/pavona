// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_FIRMWARE_MLKEM_H_
#define OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_FIRMWARE_MLKEM_H_

#include "sw/device/lib/base/status.h"
#include "sw/device/lib/crypto/include/mlkem.h"
#include "sw/device/lib/ujson/ujson.h"
#include "sw/device/tests/crypto/cryptotest/json/mlkem_commands.h"

// Maximum secret key size in uint32_t words (blinded = 2 shares).
// Oversized vs. kOtcryptoMlkem1024SecretKeyBytes to accommodate
// invalid-length test vectors.
#define MLKEM_MAX_SK_BLOB_WORDS \
  (((MLKEM_CMD_MAX_DK_BYTES + sizeof(uint32_t) - 1) / sizeof(uint32_t)) * 2)

// Scratch memory for ML-KEM tests.
typedef struct mlkem_test_scratch {
  uint32_t pk[((kOtcryptoMlkem1024PublicKeyBytes + sizeof(uint32_t) - 1) /
               sizeof(uint32_t))];
  uint32_t sk[MLKEM_MAX_SK_BLOB_WORDS];
  uint8_t ct[kOtcryptoMlkem1024CiphertextBytes + 32];
  // Crypto work area, dk import scratch, and hash scratch.
  union {
    uint32_t keypair[kOtcryptoMlkem1024WorkBufferKeypairWords];
    uint32_t encaps[kOtcryptoMlkem1024WorkBufferEncapsWords];
    uint32_t decaps[kOtcryptoMlkem1024WorkBufferDecapsWords];
    uint32_t dk_scratch[MLKEM_MAX_SK_BLOB_WORDS];
    uint8_t tmp[kOtcryptoMlkem1024PublicKeyBytes +
                kOtcryptoMlkem1024SecretKeyBytes];
  } work;
} mlkem_test_scratch_t;

status_t handle_mlkem(ujson_t *uj, mlkem_test_scratch_t *s);

#endif  // OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_FIRMWARE_MLKEM_H_
