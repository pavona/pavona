// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_FIRMWARE_MLDSA_H_
#define OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_FIRMWARE_MLDSA_H_

#include "sw/device/lib/base/status.h"
#include "sw/device/lib/crypto/include/mldsa.h"
#include "sw/device/lib/ujson/ujson.h"
#include "sw/device/tests/crypto/cryptotest/json/mldsa_commands.h"

// Maximum secret key size in uint32_t words (blinded = 2 shares).
// Oversized vs. kOtcryptoMldsa87SecretKeyBytes to accommodate
// invalid-length test vectors.
#define MLDSA_MAX_SK_BLOB_WORDS \
  (((MLDSA_CMD_MAX_SK_BYTES + sizeof(uint32_t) - 1) / sizeof(uint32_t)) * 2)

// Scratch memory for ML-DSA tests.
typedef struct mldsa_test_scratch {
  uint32_t sk[MLDSA_MAX_SK_BLOB_WORDS];
  uint32_t pk[((kOtcryptoMldsa87PublicKeyBytes + sizeof(uint32_t) - 1) /
               sizeof(uint32_t))];
  uint8_t sig[MLDSA_CMD_MAX_SIG_BYTES];
  union {
    cryptotest_mldsa_keygen_data_t keygen;
    cryptotest_mldsa_keygen_sign_data_t keygen_sign;
    cryptotest_mldsa_siggen_data_t siggen;
    cryptotest_mldsa_sigver_data_t sigver;
  } cmd;
  // Crypto work area, sk import scratch, and hash scratch.
  union {
    uint32_t keypair[kOtcryptoMldsa87WorkBufferKeypairWords];
    uint32_t sign[kOtcryptoMldsa87WorkBufferSignWords];
    uint32_t verify[kOtcryptoMldsa87WorkBufferVerifyWords];
    uint32_t sk_scratch[MLDSA_MAX_SK_BLOB_WORDS];
    uint8_t
        tmp[kOtcryptoMldsa87PublicKeyBytes + kOtcryptoMldsa87SecretKeyBytes];
  } work;
} mldsa_test_scratch_t;

status_t handle_mldsa(ujson_t *uj, mldsa_test_scratch_t *s);

#endif  // OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_FIRMWARE_MLDSA_H_
