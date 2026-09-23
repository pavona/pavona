// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_SILICON_CREATOR_ROM_SIGVERIFY_KEY_TYPES_H_
#define OPENTITAN_SW_DEVICE_SILICON_CREATOR_ROM_SIGVERIFY_KEY_TYPES_H_

#include <stdint.h>

#include "sw/device/silicon_creator/lib/sigverify/ecdsa_p256_key.h"
#include "sw/device/silicon_creator/lib/sigverify/rsa_key.h"
#include "sw/device/silicon_creator/lib/sigverify/spx_key.h"

#ifdef __cplusplus
extern "C" {
#endif  // __cplusplus

/**
 * Key types.
 *
 * The life cycle states in which a key can be used depend on its type.
 *
 * Encoding generated with
 * $ ./util/design/sparse-fsm-encode.py -d 6 -m 3 -n 32 \
 *     -s 1985033815 --language=c
 *
 * Minimum Hamming distance: 15
 * Maximum Hamming distance: 18
 * Minimum Hamming weight: 13
 * Maximum Hamming weight: 16
 */
typedef enum sigverify_key_type {
  /**
   * A key used for manufacturing, testing, and RMA.
   *
   * Keys of this type can be used only in TEST_UNLOCKED* and RMA life cycle
   * states.
   */
  kSigverifyKeyTypeTest = 0x3ff0c819,
  /**
   * A production key.
   *
   * Keys of this type can be used in all operational life cycle states, i.e.
   * states in which CPU execution is enabled.
   */
  kSigverifyKeyTypeProd = 0x43a839ad,
  /**
   * A development key.
   *
   * Keys of this type can be used only in the DEV life cycle state.
   */
  kSigverifyKeyTypeDev = 0x7a01a471,
} sigverify_key_type_t;

/**
 * Key roles values in OTP and ROM.
 *
 * Encoding generated with
 * $ ./util/design/sparse-fsm-encode.py -d 6 -m 7 -n 32 \
 *     -s 47726686 --language=c
 *
 * Minimum Hamming distance: 12
 * Maximum Hamming distance: 24
 * Minimum Hamming weight: 13
 * Maximum Hamming weight: 19
 */
typedef enum sigverify_key_role {
  /**
   * A key used for signing key bundles.
   */
  kSigverifyKeyRoleKeyBundleSigning = 0x2642f8b5,
  /**
   * A key used for signing firmware bundles.
   */
  kSigverifyKeyRoleFirmwareSigning = 0x1da3b74f,
  /**
   * A key used for allowing ownership transfers.
   */
  kSigverifyKeyRoleRelinquishOwnership = 0x427c7871,
  /**
   * A key used for entering platform debug.
   */
  kSigverifyKeyRoleDebugAuthorization = 0x31bf03ba,
  /**
   * A key used for signing second stage ROM patches.
   */
  kSigverifyKeyRoleRomPatchSigning = 0xeee1ee0e,
  /**
   * A key used for signing bootstrap firmwares.
   */
  kSigverifyKeyRoleBootstrapFirmwareSigning = 0x918adc12,
  /**
   * A key used for signing OTP keys.
   */
  kSigverifyKeyRoleOtpKeySigning = 0xbe85349c,
} sigverify_key_role_t;

/**
 * OTP key state encoding values used in the `AUTH_SLOT*_STATE` OTP partitions.
 *
 * The values are derived from the otp_ctrl encoding algorithm to ensure that
 * the following one-directional transitions are possible:
 * - `kSigVerifyKeyAuthStateBlank` -> `kSigVerifyKeyAuthStateProvisioned`
 * - `kSigVerifyKeyAuthStateProvisioned` -> `kSigVerifyKeyAuthStateRevoked`
 *
 * No other state transitions are supported. An attacker who attempts to change
 * the state of the key from `kSigVerifyKeyAuthStateRevoked` to
 * `kSigVerifyKeyAuthStateProvisioned` will trigger an ECC error in the OTP
 * macro
 */
typedef enum sigverify_key_auth_state {
  /**
   * Represents the state of the key as blank.
   */
  kSigVerifyKeyAuthStateBlank = 0,
  /**
   * Represents the state of the key as enabled.
   *
   * The value is derived from the otp_ctrl encoding algorithm to ensure that
   * transitions from this value to `kSigVerifyKeyAuthStateRevoked` are
   * possible (i.e. the value change does not trigger an ECC error in the OTP
   * macro). See https://github.com/lowRISC/opentitan/pull/21270 for more
   * details.
   *
   * parameter logic [15:0] I0 = 16'b0110_0111_1000_0001; // ECC: 6'b000100
   * parameter logic [15:0] I1 = 16'b1110_1000_1010_0001; // ECC: 6'b100110
   * AuthStEnabled  = { I1,  I0},
   */
  kSigVerifyKeyAuthStateProvisioned = 0xe8a16781,
  /**
   * Represents the state of the key as revoked.
   *
   * The value is derived from the otp_ctrl encoding algorithm to ensure that
   * transitions into this value from `kSigVerifyKeyAuthStateProvisioned` are
   * possible (i.e. the value change does not trigger an ECC error in the OTP
   * macro). See https://github.com/lowRISC/opentitan/pull/21270 for more
   * details.
   *
   * parameter logic [15:0] J0 = 16'b0111_1111_1010_0001; // ECC: 6'b101101
   * parameter logic [15:0] J1 = 16'b1110_1001_1111_0101; // ECC: 6'b101111
   * AuthStDisabled = { J1,  J0}
   */
  kSigVerifyKeyAuthStateRevoked = 0xe9f57fa1,
} sigverify_key_auth_state_t;

#ifdef __cplusplus
}  // extern "C"
#endif  // __cplusplus

#endif  // OPENTITAN_SW_DEVICE_SILICON_CREATOR_ROM_SIGVERIFY_KEY_TYPES_H_
