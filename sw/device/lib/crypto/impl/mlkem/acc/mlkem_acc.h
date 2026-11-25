// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_MLKEM_ACC_MLKEM_ACC_H_
#define OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_MLKEM_ACC_MLKEM_ACC_H_

#include <stdint.h>

#include "sw/device/lib/base/macros.h"
#include "sw/device/lib/crypto/impl/status.h"

#ifdef __cplusplus
extern "C" {
#endif  // __cplusplus

enum {
  kMlkemSharedSecretBytes = 32,
  kMlkemKeygenSeedBytes = 64,
  kMlkemEncapSeedBytes = 32,

  kMlkem512PublicKeyBytes = 800,
  kMlkem512SecretKeyBytes = 1632,
  kMlkem512CiphertextBytes = 768,

  kMlkem768PublicKeyBytes = 1184,
  kMlkem768SecretKeyBytes = 2400,
  kMlkem768CiphertextBytes = 1088,

  kMlkem1024PublicKeyBytes = 1568,
  kMlkem1024SecretKeyBytes = 3168,
  kMlkem1024CiphertextBytes = 1568,

  /* Masked dk size, 1152 * K + 128 bytes. */
  kMlkem512MaskedSecretKeyBytes = 1152 * 2 + 128,
  kMlkem768MaskedSecretKeyBytes = 1152 * 3 + 128,
  kMlkem1024MaskedSecretKeyBytes = 1152 * 4 + 128,

  // Buffer sizes in 32-bit words (ACC dmem is word-addressed).
  kMlkemSharedSecretWords = kMlkemSharedSecretBytes / sizeof(uint32_t),
  kMlkemKeygenSeedWords = kMlkemKeygenSeedBytes / sizeof(uint32_t),
  kMlkemEncapSeedWords = kMlkemEncapSeedBytes / sizeof(uint32_t),

  kMlkem512PublicKeyWords = kMlkem512PublicKeyBytes / sizeof(uint32_t),
  kMlkem512SecretKeyWords = kMlkem512SecretKeyBytes / sizeof(uint32_t),
  kMlkem512CiphertextWords = kMlkem512CiphertextBytes / sizeof(uint32_t),

  kMlkem768PublicKeyWords = kMlkem768PublicKeyBytes / sizeof(uint32_t),
  kMlkem768SecretKeyWords = kMlkem768SecretKeyBytes / sizeof(uint32_t),
  kMlkem768CiphertextWords = kMlkem768CiphertextBytes / sizeof(uint32_t),

  kMlkem1024PublicKeyWords = kMlkem1024PublicKeyBytes / sizeof(uint32_t),
  kMlkem1024SecretKeyWords = kMlkem1024SecretKeyBytes / sizeof(uint32_t),
  kMlkem1024CiphertextWords = kMlkem1024CiphertextBytes / sizeof(uint32_t),

  kMlkem512MaskedSecretKeyWords = kMlkem512MaskedSecretKeyBytes /
      sizeof(uint32_t),
  kMlkem768MaskedSecretKeyWords = kMlkem768MaskedSecretKeyBytes /
      sizeof(uint32_t),
  kMlkem1024MaskedSecretKeyWords = kMlkem1024MaskedSecretKeyBytes /
      sizeof(uint32_t),
};

/**
 * Generates an ML-KEM-512 key pair on ACC.
 *
 * @param coins Key generation seed d || z.
 * @param[out] pk Encapsulation key.
 * @param[out] sk Decapsulation key.
 * @return Result of the operation.
 */
OT_WARN_UNUSED_RESULT
status_t mlkem_acc_512_keygen(const uint32_t coins[kMlkemKeygenSeedWords],
                              uint32_t pk[kMlkem512PublicKeyWords],
                              uint32_t sk[kMlkem512SecretKeyWords]);

/**
 * Generates an ML-KEM-768 key pair on ACC.
 *
 * @param coins Key generation seed d || z.
 * @param[out] pk Encapsulation key.
 * @param[out] sk Decapsulation key.
 * @return Result of the operation.
 */
OT_WARN_UNUSED_RESULT
status_t mlkem_acc_768_keygen(const uint32_t coins[kMlkemKeygenSeedWords],
                              uint32_t pk[kMlkem768PublicKeyWords],
                              uint32_t sk[kMlkem768SecretKeyWords]);

/**
 * Generates an ML-KEM-1024 key pair on ACC.
 *
 * @param coins Key generation seed d || z.
 * @param[out] pk Encapsulation key.
 * @param[out] sk Decapsulation key.
 * @return Result of the operation.
 */
OT_WARN_UNUSED_RESULT
status_t mlkem_acc_1024_keygen(const uint32_t coins[kMlkemKeygenSeedWords],
                               uint32_t pk[kMlkem1024PublicKeyWords],
                               uint32_t sk[kMlkem1024SecretKeyWords]);

/**
 * Encapsulates a shared secret to an ML-KEM-512 encapsulation key on ACC.
 *
 * @param coins Encapsulation randomness m.
 * @param pk Encapsulation key.
 * @param[out] ct Ciphertext.
 * @param[out] ss Shared secret.
 * @return Result of the operation.
 */
OT_WARN_UNUSED_RESULT
status_t mlkem_acc_512_encap(const uint32_t coins[kMlkemEncapSeedWords],
                             const uint32_t pk[kMlkem512PublicKeyWords],
                             uint32_t ct[kMlkem512CiphertextWords],
                             uint32_t ss[kMlkemSharedSecretWords]);

/**
 * Encapsulates a shared secret to an ML-KEM-768 encapsulation key on ACC.
 *
 * @param coins Encapsulation randomness m.
 * @param pk Encapsulation key.
 * @param[out] ct Ciphertext.
 * @param[out] ss Shared secret.
 * @return Result of the operation.
 */
OT_WARN_UNUSED_RESULT
status_t mlkem_acc_768_encap(const uint32_t coins[kMlkemEncapSeedWords],
                             const uint32_t pk[kMlkem768PublicKeyWords],
                             uint32_t ct[kMlkem768CiphertextWords],
                             uint32_t ss[kMlkemSharedSecretWords]);

/**
 * Encapsulates a shared secret to an ML-KEM-1024 encapsulation key on ACC.
 *
 * @param coins Encapsulation randomness m.
 * @param pk Encapsulation key.
 * @param[out] ct Ciphertext.
 * @param[out] ss Shared secret.
 * @return Result of the operation.
 */
OT_WARN_UNUSED_RESULT
status_t mlkem_acc_1024_encap(const uint32_t coins[kMlkemEncapSeedWords],
                              const uint32_t pk[kMlkem1024PublicKeyWords],
                              uint32_t ct[kMlkem1024CiphertextWords],
                              uint32_t ss[kMlkemSharedSecretWords]);

/**
 * Decapsulates an ML-KEM-512 ciphertext on ACC.
 *
 * @param ct Ciphertext.
 * @param sk Decapsulation key.
 * @param[out] ss Shared secret.
 * @return Result of the operation.
 */
OT_WARN_UNUSED_RESULT
status_t mlkem_acc_512_decap(const uint32_t ct[kMlkem512CiphertextWords],
                             const uint32_t sk[kMlkem512SecretKeyWords],
                             uint32_t ss[kMlkemSharedSecretWords]);

/**
 * Decapsulates an ML-KEM-768 ciphertext on ACC.
 *
 * @param ct Ciphertext.
 * @param sk Decapsulation key.
 * @param[out] ss Shared secret.
 * @return Result of the operation.
 */
OT_WARN_UNUSED_RESULT
status_t mlkem_acc_768_decap(const uint32_t ct[kMlkem768CiphertextWords],
                             const uint32_t sk[kMlkem768SecretKeyWords],
                             uint32_t ss[kMlkemSharedSecretWords]);

/**
 * Decapsulates an ML-KEM-1024 ciphertext on ACC.
 *
 * @param ct Ciphertext.
 * @param sk Decapsulation key.
 * @param[out] ss Shared secret.
 * @return Result of the operation.
 */
OT_WARN_UNUSED_RESULT
status_t mlkem_acc_1024_decap(const uint32_t ct[kMlkem1024CiphertextWords],
                              const uint32_t sk[kMlkem1024SecretKeyWords],
                              uint32_t ss[kMlkemSharedSecretWords]);

/**
 * Generates an ML-KEM-512 key pair on ACC with a masked decapsulation key.
 *
 * @param coins_share0 First Boolean share of the key generation seed d || z.
 * @param coins_share1 Second Boolean share of the key generation seed d || z.
 * @param[out] pk Encapsulation key.
 * @param[out] sk Masked decapsulation key.
 * @return Result of the operation.
 */
OT_WARN_UNUSED_RESULT
status_t mlkem_acc_512_keygen_hardened(
    const uint32_t coins_share0[kMlkemKeygenSeedWords],
    const uint32_t coins_share1[kMlkemKeygenSeedWords],
    uint32_t pk[kMlkem512PublicKeyWords],
    uint32_t sk[kMlkem512MaskedSecretKeyWords]);

/**
 * Generates an ML-KEM-768 key pair on ACC with a masked decapsulation key.
 *
 * @param coins_share0 First Boolean share of the key generation seed d || z.
 * @param coins_share1 Second Boolean share of the key generation seed d || z.
 * @param[out] pk Encapsulation key.
 * @param[out] sk Masked decapsulation key.
 * @return Result of the operation.
 */
OT_WARN_UNUSED_RESULT
status_t mlkem_acc_768_keygen_hardened(
    const uint32_t coins_share0[kMlkemKeygenSeedWords],
    const uint32_t coins_share1[kMlkemKeygenSeedWords],
    uint32_t pk[kMlkem768PublicKeyWords],
    uint32_t sk[kMlkem768MaskedSecretKeyWords]);

/**
 * Generates an ML-KEM-1024 key pair on ACC with a masked decapsulation key.
 *
 * @param coins_share0 First Boolean share of the key generation seed d || z.
 * @param coins_share1 Second Boolean share of the key generation seed d || z.
 * @param[out] pk Encapsulation key.
 * @param[out] sk Masked decapsulation key.
 * @return Result of the operation.
 */
OT_WARN_UNUSED_RESULT
status_t mlkem_acc_1024_keygen_hardened(
    const uint32_t coins_share0[kMlkemKeygenSeedWords],
    const uint32_t coins_share1[kMlkemKeygenSeedWords],
    uint32_t pk[kMlkem1024PublicKeyWords],
    uint32_t sk[kMlkem1024MaskedSecretKeyWords]);

/**
 * Decapsulates an ML-KEM-512 ciphertext on ACC with a masked decapsulation
 * key.
 *
 * @param ct Ciphertext.
 * @param sk Masked decapsulation key.
 * @param[out] ss_share0 First Boolean share of the shared secret.
 * @param[out] ss_share1 Second Boolean share of the shared secret.
 * @return Result of the operation.
 */
OT_WARN_UNUSED_RESULT
status_t mlkem_acc_512_decap_hardened(
    const uint32_t ct[kMlkem512CiphertextWords],
    const uint32_t sk[kMlkem512MaskedSecretKeyWords],
    uint32_t ss_share0[kMlkemSharedSecretWords],
    uint32_t ss_share1[kMlkemSharedSecretWords]);

/**
 * Decapsulates an ML-KEM-768 ciphertext on ACC with a masked decapsulation
 * key.
 *
 * @param ct Ciphertext.
 * @param sk Masked decapsulation key.
 * @param[out] ss_share0 First Boolean share of the shared secret.
 * @param[out] ss_share1 Second Boolean share of the shared secret.
 * @return Result of the operation.
 */
OT_WARN_UNUSED_RESULT
status_t mlkem_acc_768_decap_hardened(
    const uint32_t ct[kMlkem768CiphertextWords],
    const uint32_t sk[kMlkem768MaskedSecretKeyWords],
    uint32_t ss_share0[kMlkemSharedSecretWords],
    uint32_t ss_share1[kMlkemSharedSecretWords]);

/**
 * Decapsulates an ML-KEM-1024 ciphertext on ACC with a masked decapsulation
 * key.
 *
 * @param ct Ciphertext.
 * @param sk Masked decapsulation key.
 * @param[out] ss_share0 First Boolean share of the shared secret.
 * @param[out] ss_share1 Second Boolean share of the shared secret.
 * @return Result of the operation.
 */
OT_WARN_UNUSED_RESULT
status_t mlkem_acc_1024_decap_hardened(
    const uint32_t ct[kMlkem1024CiphertextWords],
    const uint32_t sk[kMlkem1024MaskedSecretKeyWords],
    uint32_t ss_share0[kMlkemSharedSecretWords],
    uint32_t ss_share1[kMlkemSharedSecretWords]);

#ifdef __cplusplus
}  // extern "C"
#endif  // __cplusplus

#endif  // OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_MLKEM_ACC_MLKEM_ACC_H_
