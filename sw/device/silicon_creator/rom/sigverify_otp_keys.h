// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_SILICON_CREATOR_ROM_SIGVERIFY_OTP_KEYS_H_
#define OPENTITAN_SW_DEVICE_SILICON_CREATOR_ROM_SIGVERIFY_OTP_KEYS_H_

#include <stdint.h>

#include "sw/device/lib/base/macros.h"
#include "sw/device/silicon_creator/lib/drivers/hmac.h"
#include "sw/device/silicon_creator/lib/drivers/lifecycle.h"
#include "sw/device/silicon_creator/lib/error.h"
#include "sw/device/silicon_creator/rom/sigverify_key_types.h"

#ifdef __cplusplus
extern "C" {
#endif  // __cplusplus

enum {
  /** Number of ROT_OWNER authentication key slots in OTP. */
  kSigVerifyOtpKeysRotOwnerAuthSlotCount = 4,

  /** Identifier for ROT_OWNER key slot 0. */
  kSigVerifyOtpKeysRotOwnerSlot0 = 0,
  /** Identifier for ROT_OWNER key slot 1. */
  kSigVerifyOtpKeysRotOwnerSlot1 = 1,
  /** Identifier for ROT_OWNER key slot 2. */
  kSigVerifyOtpKeysRotOwnerSlot2 = 2,
  /** Identifier for ROT_OWNER key slot 3. */
  kSigVerifyOtpKeysRotOwnerSlot3 = 3,

  /** Identifier for ROT_OWNER FIRMWARE_CODESIGN key spec. */
  kSigVerifyOtpKeysKeySpecRotOwnerFirmwareCodesign = 0,
  /** Identifier for ROT_OWNER ROM1_PATCH key spec. */
  kSigVerifyOtpKeysKeySpecRotOwnerRom1Patch = 1,

  /** Identifier for ECDSA key. */
  kSigVerifyOtpKeysAlgorithmEcdsa = 0,
  /** Identifier for SPHINCS+ key. */
  kSigVerifyOtpKeysAlgorithmSpx = 1,
};

/**
 * A hybrid ECDSA-P256 and SPHINCS+ public key stored in an AUTH_SLOT in OTP.
 */
typedef struct sigverify_otp_hybrid_key {
  /**
   * Key type annotation of the key.
   *
   * Permitted values:
   * - kSigverifyKeyTypeTest for manufacturing, testing and RMA keys.
   *   Keys of this type can be used only in TEST_UNLOCKED* and RMA life
   *   cycle states.
   * - kSigverifyKeyTypeProd for production keys.
   *   Keys of this type can be used in all operational life cycle states, i.e.
   *   states in which CPU execution is enabled.
   * - kSigverifyKeyTypeDev for development keys.
   *   Keys of this type can be used only in the DEV life cycle state.
   */
  uint32_t key_type;
  /**
   * ECDSA-P256 public key.
   */
  ecdsa_p256_public_key_t ecdsa_key;
  /**
   * SPHINCS+ public key.
   */
  sigverify_spx_key_t spx_key;
  /**
   * Parameter configuration ID for the SPX key:
   * - kSigverifySpxConfigIdSha2128s: SPHINCS+-SHA2-128s without pre-hashing.
   * - kSigverifySpxConfigIdSha2128sQ20: SPHINCS+-SHA2-128s-q20 without
   * pre-hashing
   * - kSigverifySpxConfigIdSha2128sPrehash: SPHINCS+-SHA2-128s with SHA256
   * pre-hashing.
   * - kSigverifySpxConfigIdSha2128sQ20Prehash: SPHINCS+-SHA2-128s-q20 with
   * SHA256 pre-hashing.
   */
  sigverify_spx_config_id_t spx_config_id;
} sigverify_otp_hybrid_key_t;

/**
 * A value binding an AUTH_SLOT to a SKU.
 */
typedef struct sigverify_otp_key_binding {
  /**
   * The binding value.
   */
  uint32_t binding[16];
} sigverify_otp_key_binding_t;

/**
 * ECDSA signature over an AUTH_SLOT by the manufacturer.
 */
typedef struct sigverify_otp_signature {
  /**
   * The signature.
   */
  uint32_t signature[16];
} sigverify_otp_signature_t;

/**
 * A hybrid ECDSA-P256 and SPHINCS+ public key stored in an AUTH_SLOT in OTP.
 */
typedef struct sigverify_otp_hybrid_key_state {
  /**
   * State of the ECDSA key (BLANK, ENABLED, DISABLED).
   */
  uint32_t ecdsa_key_state;
  /**
   * State of the SPHINCS+ key (BLANK, ENABLED, DISABLED).
   */
  uint32_t spx_key_state;

} sigverify_otp_hybrid_key_state_t;

/**
 * SRAM representation of an OTP ROT_OWNER_AUTH_SLOT partition.
 */
typedef struct sigverify_otp_rot_owner_auth_slot {
  /**
   * Verification keys for firmware.
   */
  sigverify_otp_hybrid_key_t firmware_codesign_keys;
#ifdef HAS_ROM_CTRL1
  /**
   * Verification keys for second ROM patch(es).
   */
  sigverify_otp_hybrid_key_t rom1_patch_keys;
#endif
  /**
   * Key binding value used to bind the AUTH_SLOT to a SKU.
   */
  sigverify_otp_key_binding_t key_binding;
  /**
   * ECDSA P-256 signature of the AUTH_SLOT by the manufacturer. This is not
   * verified at boot-time but can be used to establish a chain-of-trust to the
   * manufacturer post-boot.
   */
  sigverify_otp_signature_t signature;
} sigverify_otp_rot_owner_auth_slot_t;

/**
 * SRAM representation of an OTP ROT_OWNER_AUTH_SLOT_STATE partition.
 */
typedef struct sigverify_otp_rot_owner_auth_slot_state {
  /**
   * Verification key state for firmware.
   */
  sigverify_otp_hybrid_key_state_t firmware_codesign_key_state;
#ifdef HAS_ROM_CTRL1
  /**
   * Verification key state for second ROM patch(es).
   */
  sigverify_otp_hybrid_key_state_t rom1_patch_key_state;
#endif
} sigverify_otp_rot_owner_auth_slot_state_t;

/**
 * Context for OTP ROT_OWNER keys loaded into SRAM.
 */
typedef struct sigverify_otp_rot_owner_key_ctx {
  /**
   * Hybrid keys.
   */
  sigverify_otp_rot_owner_auth_slot_t
      slots[kSigVerifyOtpKeysRotOwnerAuthSlotCount];
  /**
   * Hybrid key states.
   */
  sigverify_otp_rot_owner_auth_slot_state_t
      slot_states[kSigVerifyOtpKeysRotOwnerAuthSlotCount];
} sigverify_otp_rot_owner_key_ctx_t;

/**
 * Context for all OTP keys loaded into SRAM.
 */
typedef struct sigverify_otp_key_ctx {
  /**
   * ROT_OWNER key context.
   */
  sigverify_otp_rot_owner_key_ctx_t rot_owner;
} sigverify_otp_key_ctx_t;

/**
 * Initializes the OTP keys context.
 *
 * @param ctx Context for OTP keys loaded into SRAM.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
rom_error_t sigverify_otp_keys_init(sigverify_otp_key_ctx_t *ctx);

/**
 * Look up an ECDSA P-256 or SPHINCS+ public key to ensure it is provisioned in
 * OTP and is valid for the provide lifecycle state.
 *
 * @param ctx Context for OTP keys loaded into SRAM.
 * @param key_spec The chip role and key type to look up, e.g.
 *        kSigVerifyOtpKeysKeySpecRotOwnerFirmwareCodesign.
 * @param algorithm The key algorithm to look up
 *        (kSigVerifyOtpKeysAlgorithmEcdsa or kSigVerifyOtpKeysAlgorithmSpx).
 * @param ecdsa_key Pointer to the ECDSA key to look up. May be NULL if
 *       `algorithm = kSigVerifyOtpKeysAlgorithmSpx`.
 * @param spx_key Pointer to the SPHINCS+ key to look up. May be NULL if
 *       `algorithm = kSigVerifyOtpKeysAlgorithmEcdsa`.
 * @param lc_state Lifecycle state to check that the key is valid for.
 * @param[out] spx_config If `algorithm = kSigVerifyOtpKeysAlgorithmSpx`, the
 *             SPHINCS+ config ID is written here
 *
 * @return An error if the key is not provisioned in OTP or is invalid for
 * `lc_state`.
 */
rom_error_t sigverify_otp_key_lookup(sigverify_otp_key_ctx_t *ctx,
                                     const uint32_t key_spec,
                                     const uint32_t algorithm,
                                     const ecdsa_p256_public_key_t *ecdsa_key,
                                     const sigverify_spx_key_t *spx_key,
                                     const lifecycle_state_t lc_state,
                                     sigverify_spx_config_id_t *spx_config);

#ifdef __cplusplus
}  // extern "C"
#endif  // __cplusplus

#endif  // OPENTITAN_SW_DEVICE_SILICON_CREATOR_ROM_SIGVERIFY_OTP_KEYS_H_
