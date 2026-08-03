// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_MLDSA_ACC_MLDSA_ACC_H_
#define OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_MLDSA_ACC_MLDSA_ACC_H_

#include <stdint.h>

#include "sw/device/lib/base/hardened.h"
#include "sw/device/lib/base/macros.h"
#include "sw/device/lib/crypto/impl/status.h"
#include "sw/device/lib/crypto/include/mldsa.h"

#ifdef __cplusplus
extern "C" {
#endif  // __cplusplus

enum {
  kMldsaSeedBytes = 32,
  kMldsaRndBytes = 32,
  kMldsaMaxContextBytes = 255,
  // FIPS 204 message representative (mu) is always 64 bytes.
  kMldsaMuBytes = 64,

  kMldsa44PublicKeyBytes = 1312,
  kMldsa44SecretKeyBytes = 2560,
  kMldsa44SignatureBytes = 2420,

  kMldsa65PublicKeyBytes = 1952,
  kMldsa65SecretKeyBytes = 4032,
  kMldsa65SignatureBytes = 3309,

  kMldsa87PublicKeyBytes = 2592,
  kMldsa87SecretKeyBytes = 4896,
  kMldsa87SignatureBytes = 4627,

  // Masked secret-key blob sizes (ACC layout, see mldsa.h): the three ACC
  // regions concatenated, 128 + K*416 + 2*(L+K)*polyeta + 64 bytes.
  kMldsa44MaskedSecretKeyBytes = 128 + 4 * 416 + 2 * 8 * 96 + 64,
  kMldsa65MaskedSecretKeyBytes = 128 + 6 * 416 + 2 * 11 * 128 + 64,
  kMldsa87MaskedSecretKeyBytes = 128 + 8 * 416 + 2 * 15 * 96 + 64,

  kMldsaSeedWords = (kMldsaSeedBytes + sizeof(uint32_t) - 1) / sizeof(uint32_t),
  kMldsaRndWords = (kMldsaRndBytes + sizeof(uint32_t) - 1) / sizeof(uint32_t),
  kMldsaMuWords = (kMldsaMuBytes + sizeof(uint32_t) - 1) / sizeof(uint32_t),

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

  kMldsa44MaskedSecretKeyWords =
      kMldsa44MaskedSecretKeyBytes / sizeof(uint32_t),
  kMldsa65MaskedSecretKeyWords =
      kMldsa65MaskedSecretKeyBytes / sizeof(uint32_t),
  kMldsa87MaskedSecretKeyWords =
      kMldsa87MaskedSecretKeyBytes / sizeof(uint32_t),
};

/**
 * ACC-backed ML-DSA (synchronous) primitives.
 *
 * Each function loads the run_mldsa ACC binary, writes inputs and the mode
 * code into ACC dmem, executes, waits for idle, and reads outputs back. The
 * shared KL-runtime kernels in `sw/acc/crypto/mldsa` are dispatched based on
 * the chosen parameter set (ML-DSA-44 / 65 / 87).
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

/**
 * Verify the signature. On success the status is OTCRYPTO_OK and
 * `*verification_result` is set to `kHardenedBoolTrue` if the signature is
 * valid or `kHardenedBoolFalse` otherwise.
 */
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

/**
 * ACC-backed ML-DSA external-mu primitives.
 *
 * `mu` is a precomputed message representative (FIPS 204 external-mu
 * variant); the caller has already done the context/message encoding and
 * hashing that the non-mu primitives above do internally.
 */

OT_WARN_UNUSED_RESULT
status_t mldsa_acc_44_sign_mu(const uint32_t sk[kMldsa44SecretKeyWords],
                              const uint32_t mu[kMldsaMuWords],
                              const uint32_t rnd[kMldsaRndWords],
                              uint32_t sig[kMldsa44SignatureWords]);

OT_WARN_UNUSED_RESULT
status_t mldsa_acc_65_sign_mu(const uint32_t sk[kMldsa65SecretKeyWords],
                              const uint32_t mu[kMldsaMuWords],
                              const uint32_t rnd[kMldsaRndWords],
                              uint32_t sig[kMldsa65SignatureWords]);

OT_WARN_UNUSED_RESULT
status_t mldsa_acc_87_sign_mu(const uint32_t sk[kMldsa87SecretKeyWords],
                              const uint32_t mu[kMldsaMuWords],
                              const uint32_t rnd[kMldsaRndWords],
                              uint32_t sig[kMldsa87SignatureWords]);

OT_WARN_UNUSED_RESULT
status_t mldsa_acc_44_verify_mu(const uint32_t pk[kMldsa44PublicKeyWords],
                                const uint32_t mu[kMldsaMuWords],
                                const uint32_t sig[kMldsa44SignatureWords],
                                hardened_bool_t *verification_result);

OT_WARN_UNUSED_RESULT
status_t mldsa_acc_65_verify_mu(const uint32_t pk[kMldsa65PublicKeyWords],
                                const uint32_t mu[kMldsaMuWords],
                                const uint32_t sig[kMldsa65SignatureWords],
                                hardened_bool_t *verification_result);

OT_WARN_UNUSED_RESULT
status_t mldsa_acc_87_verify_mu(const uint32_t pk[kMldsa87PublicKeyWords],
                                const uint32_t mu[kMldsaMuWords],
                                const uint32_t sig[kMldsa87SignatureWords],
                                hardened_bool_t *verification_result);

/**
 * ACC-backed HashML-DSA primitives (FIPS 204 Algorithms 4/5).
 *
 * `ph`/`ph_bytes` is the pre-hashed message (the caller hashes the message
 * with the hash function named by `hash_mode` before calling); `hash_mode`
 * selects the OID folded into the signed message representative.
 */

OT_WARN_UNUSED_RESULT
status_t mldsa_acc_44_sign_pre_hash(const uint32_t sk[kMldsa44SecretKeyWords],
                                    const uint8_t *ph, size_t ph_bytes,
                                    const uint8_t *ctx, size_t ctx_bytes,
                                    otcrypto_mldsa_sign_mode_t hash_mode,
                                    const uint32_t rnd[kMldsaRndWords],
                                    uint32_t sig[kMldsa44SignatureWords]);

OT_WARN_UNUSED_RESULT
status_t mldsa_acc_65_sign_pre_hash(const uint32_t sk[kMldsa65SecretKeyWords],
                                    const uint8_t *ph, size_t ph_bytes,
                                    const uint8_t *ctx, size_t ctx_bytes,
                                    otcrypto_mldsa_sign_mode_t hash_mode,
                                    const uint32_t rnd[kMldsaRndWords],
                                    uint32_t sig[kMldsa65SignatureWords]);

OT_WARN_UNUSED_RESULT
status_t mldsa_acc_87_sign_pre_hash(const uint32_t sk[kMldsa87SecretKeyWords],
                                    const uint8_t *ph, size_t ph_bytes,
                                    const uint8_t *ctx, size_t ctx_bytes,
                                    otcrypto_mldsa_sign_mode_t hash_mode,
                                    const uint32_t rnd[kMldsaRndWords],
                                    uint32_t sig[kMldsa87SignatureWords]);

OT_WARN_UNUSED_RESULT
status_t mldsa_acc_44_verify_pre_hash(
    const uint32_t pk[kMldsa44PublicKeyWords], const uint8_t *ph,
    size_t ph_bytes, const uint8_t *ctx, size_t ctx_bytes,
    otcrypto_mldsa_sign_mode_t hash_mode,
    const uint32_t sig[kMldsa44SignatureWords],
    hardened_bool_t *verification_result);

OT_WARN_UNUSED_RESULT
status_t mldsa_acc_65_verify_pre_hash(
    const uint32_t pk[kMldsa65PublicKeyWords], const uint8_t *ph,
    size_t ph_bytes, const uint8_t *ctx, size_t ctx_bytes,
    otcrypto_mldsa_sign_mode_t hash_mode,
    const uint32_t sig[kMldsa65SignatureWords],
    hardened_bool_t *verification_result);

OT_WARN_UNUSED_RESULT
status_t mldsa_acc_87_verify_pre_hash(
    const uint32_t pk[kMldsa87PublicKeyWords], const uint8_t *ph,
    size_t ph_bytes, const uint8_t *ctx, size_t ctx_bytes,
    otcrypto_mldsa_sign_mode_t hash_mode,
    const uint32_t sig[kMldsa87SignatureWords],
    hardened_bool_t *verification_result);

/**
 * Hardened (masked) ML-DSA keygen and sign: the signing key is the masked
 * component-major keyblob (`kMldsa*MaskedSecretKeyWords`; see mldsa.h).
 */
OT_WARN_UNUSED_RESULT
status_t mldsa_acc_44_keygen_hardened(
    const uint32_t zeta_share0[kMldsaSeedWords],
    const uint32_t zeta_share1[kMldsaSeedWords],
    uint32_t pk[kMldsa44PublicKeyWords],
    uint32_t sk[kMldsa44MaskedSecretKeyWords]);

OT_WARN_UNUSED_RESULT
status_t mldsa_acc_65_keygen_hardened(
    const uint32_t zeta_share0[kMldsaSeedWords],
    const uint32_t zeta_share1[kMldsaSeedWords],
    uint32_t pk[kMldsa65PublicKeyWords],
    uint32_t sk[kMldsa65MaskedSecretKeyWords]);

OT_WARN_UNUSED_RESULT
status_t mldsa_acc_87_keygen_hardened(
    const uint32_t zeta_share0[kMldsaSeedWords],
    const uint32_t zeta_share1[kMldsaSeedWords],
    uint32_t pk[kMldsa87PublicKeyWords],
    uint32_t sk[kMldsa87MaskedSecretKeyWords]);

OT_WARN_UNUSED_RESULT
status_t mldsa_acc_44_sign_hardened(
    const uint32_t sk[kMldsa44MaskedSecretKeyWords], const uint8_t *msg,
    size_t msg_bytes, const uint8_t *ctx, size_t ctx_bytes,
    const uint32_t rnd[kMldsaRndWords], uint32_t sig[kMldsa44SignatureWords]);

OT_WARN_UNUSED_RESULT
status_t mldsa_acc_65_sign_hardened(
    const uint32_t sk[kMldsa65MaskedSecretKeyWords], const uint8_t *msg,
    size_t msg_bytes, const uint8_t *ctx, size_t ctx_bytes,
    const uint32_t rnd[kMldsaRndWords], uint32_t sig[kMldsa65SignatureWords]);

OT_WARN_UNUSED_RESULT
status_t mldsa_acc_87_sign_hardened(
    const uint32_t sk[kMldsa87MaskedSecretKeyWords], const uint8_t *msg,
    size_t msg_bytes, const uint8_t *ctx, size_t ctx_bytes,
    const uint32_t rnd[kMldsaRndWords], uint32_t sig[kMldsa87SignatureWords]);

/**
 * Hardened (masked) ML-DSA external-mu and HashML-DSA sign. See the
 * corresponding non-hardened primitives above for parameter semantics.
 */

OT_WARN_UNUSED_RESULT
status_t mldsa_acc_44_sign_mu_hardened(
    const uint32_t sk[kMldsa44MaskedSecretKeyWords],
    const uint32_t mu[kMldsaMuWords], const uint32_t rnd[kMldsaRndWords],
    uint32_t sig[kMldsa44SignatureWords]);

OT_WARN_UNUSED_RESULT
status_t mldsa_acc_65_sign_mu_hardened(
    const uint32_t sk[kMldsa65MaskedSecretKeyWords],
    const uint32_t mu[kMldsaMuWords], const uint32_t rnd[kMldsaRndWords],
    uint32_t sig[kMldsa65SignatureWords]);

OT_WARN_UNUSED_RESULT
status_t mldsa_acc_87_sign_mu_hardened(
    const uint32_t sk[kMldsa87MaskedSecretKeyWords],
    const uint32_t mu[kMldsaMuWords], const uint32_t rnd[kMldsaRndWords],
    uint32_t sig[kMldsa87SignatureWords]);

OT_WARN_UNUSED_RESULT
status_t mldsa_acc_44_sign_pre_hash_hardened(
    const uint32_t sk[kMldsa44MaskedSecretKeyWords], const uint8_t *ph,
    size_t ph_bytes, const uint8_t *ctx, size_t ctx_bytes,
    otcrypto_mldsa_sign_mode_t hash_mode, const uint32_t rnd[kMldsaRndWords],
    uint32_t sig[kMldsa44SignatureWords]);

OT_WARN_UNUSED_RESULT
status_t mldsa_acc_65_sign_pre_hash_hardened(
    const uint32_t sk[kMldsa65MaskedSecretKeyWords], const uint8_t *ph,
    size_t ph_bytes, const uint8_t *ctx, size_t ctx_bytes,
    otcrypto_mldsa_sign_mode_t hash_mode, const uint32_t rnd[kMldsaRndWords],
    uint32_t sig[kMldsa65SignatureWords]);

OT_WARN_UNUSED_RESULT
status_t mldsa_acc_87_sign_pre_hash_hardened(
    const uint32_t sk[kMldsa87MaskedSecretKeyWords], const uint8_t *ph,
    size_t ph_bytes, const uint8_t *ctx, size_t ctx_bytes,
    otcrypto_mldsa_sign_mode_t hash_mode, const uint32_t rnd[kMldsaRndWords],
    uint32_t sig[kMldsa87SignatureWords]);

#ifdef __cplusplus
}  // extern "C"
#endif  // __cplusplus

#endif  // OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_MLDSA_ACC_MLDSA_ACC_H_
