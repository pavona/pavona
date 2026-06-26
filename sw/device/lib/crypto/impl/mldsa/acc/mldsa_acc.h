// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_MLDSA_ACC_MLDSA_ACC_H_
#define OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_MLDSA_ACC_MLDSA_ACC_H_

#include <stdint.h>

#include "sw/device/lib/base/hardened.h"
#include "sw/device/lib/base/macros.h"
#include "sw/device/lib/crypto/impl/status.h"

#ifdef __cplusplus
extern "C" {
#endif  // __cplusplus

enum {
  kMldsaSeedBytes = 32,
  kMldsaRndBytes = 32,
  kMldsaMaxContextBytes = 255,

  kMldsa44PublicKeyBytes = 1312,
  kMldsa44SecretKeyBytes = 2560,
  kMldsa44SignatureBytes = 2420,

  kMldsa65PublicKeyBytes = 1952,
  kMldsa65SecretKeyBytes = 4032,
  kMldsa65SignatureBytes = 3309,

  kMldsa87PublicKeyBytes = 2592,
  kMldsa87SecretKeyBytes = 4896,
  kMldsa87SignatureBytes = 4627,

  // Buffer sizes in 32-bit words (ACC dmem is word-addressed).
  kMldsaSeedWords = (kMldsaSeedBytes + sizeof(uint32_t) - 1) / sizeof(uint32_t),
  kMldsaRndWords = (kMldsaRndBytes + sizeof(uint32_t) - 1) / sizeof(uint32_t),

  kMldsa44PublicKeyWords =
      (kMldsa44PublicKeyBytes + sizeof(uint32_t) - 1) / sizeof(uint32_t),
  kMldsa44SecretKeyWords =
      (kMldsa44SecretKeyBytes + sizeof(uint32_t) - 1) / sizeof(uint32_t),
  kMldsa44SignatureWords =
      (kMldsa44SignatureBytes + sizeof(uint32_t) - 1) / sizeof(uint32_t),

  kMldsa65PublicKeyWords =
      (kMldsa65PublicKeyBytes + sizeof(uint32_t) - 1) / sizeof(uint32_t),
  kMldsa65SecretKeyWords =
      (kMldsa65SecretKeyBytes + sizeof(uint32_t) - 1) / sizeof(uint32_t),
  kMldsa65SignatureWords =
      (kMldsa65SignatureBytes + sizeof(uint32_t) - 1) / sizeof(uint32_t),

  kMldsa87PublicKeyWords =
      (kMldsa87PublicKeyBytes + sizeof(uint32_t) - 1) / sizeof(uint32_t),
  kMldsa87SecretKeyWords =
      (kMldsa87SecretKeyBytes + sizeof(uint32_t) - 1) / sizeof(uint32_t),
  kMldsa87SignatureWords =
      (kMldsa87SignatureBytes + sizeof(uint32_t) - 1) / sizeof(uint32_t),
};

/**
 * ACC-backed ML-DSA primitives.
 */

OT_WARN_UNUSED_RESULT
status_t mldsa_acc_44_keygen(const uint32_t zeta[kMldsaSeedWords],
                             uint32_t pk[kMldsa44PublicKeyWords],
                             uint32_t sk[kMldsa44SecretKeyWords]);

OT_WARN_UNUSED_RESULT
status_t mldsa_acc_65_keygen(const uint32_t zeta[kMldsaSeedWords],
                             uint32_t pk[kMldsa65PublicKeyWords],
                             uint32_t sk[kMldsa65SecretKeyWords]);

OT_WARN_UNUSED_RESULT
status_t mldsa_acc_87_keygen(const uint32_t zeta[kMldsaSeedWords],
                             uint32_t pk[kMldsa87PublicKeyWords],
                             uint32_t sk[kMldsa87SecretKeyWords]);

OT_WARN_UNUSED_RESULT
status_t mldsa_acc_44_sign(const uint32_t sk[kMldsa44SecretKeyWords],
                           const uint8_t *msg, size_t msg_bytes,
                           const uint8_t *ctx, size_t ctx_bytes,
                           const uint32_t rnd[kMldsaRndWords],
                           uint32_t sig[kMldsa44SignatureWords]);

OT_WARN_UNUSED_RESULT
status_t mldsa_acc_65_sign(const uint32_t sk[kMldsa65SecretKeyWords],
                           const uint8_t *msg, size_t msg_bytes,
                           const uint8_t *ctx, size_t ctx_bytes,
                           const uint32_t rnd[kMldsaRndWords],
                           uint32_t sig[kMldsa65SignatureWords]);

OT_WARN_UNUSED_RESULT
status_t mldsa_acc_87_sign(const uint32_t sk[kMldsa87SecretKeyWords],
                           const uint8_t *msg, size_t msg_bytes,
                           const uint8_t *ctx, size_t ctx_bytes,
                           const uint32_t rnd[kMldsaRndWords],
                           uint32_t sig[kMldsa87SignatureWords]);

OT_WARN_UNUSED_RESULT
status_t mldsa_acc_44_verify(const uint32_t pk[kMldsa44PublicKeyWords],
                             const uint8_t *msg, size_t msg_bytes,
                             const uint8_t *ctx, size_t ctx_bytes,
                             const uint32_t sig[kMldsa44SignatureWords],
                             hardened_bool_t *verification_result);

OT_WARN_UNUSED_RESULT
status_t mldsa_acc_65_verify(const uint32_t pk[kMldsa65PublicKeyWords],
                             const uint8_t *msg, size_t msg_bytes,
                             const uint8_t *ctx, size_t ctx_bytes,
                             const uint32_t sig[kMldsa65SignatureWords],
                             hardened_bool_t *verification_result);

OT_WARN_UNUSED_RESULT
status_t mldsa_acc_87_verify(const uint32_t pk[kMldsa87PublicKeyWords],
                             const uint8_t *msg, size_t msg_bytes,
                             const uint8_t *ctx, size_t ctx_bytes,
                             const uint32_t sig[kMldsa87SignatureWords],
                             hardened_bool_t *verification_result);

#ifdef __cplusplus
}  // extern "C"
#endif  // __cplusplus

#endif  // OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_MLDSA_ACC_MLDSA_ACC_H_
