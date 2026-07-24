// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/silicon_creator/rom/sigverify_otp_keys.h"

#include "sw/device/silicon_creator/lib/drivers/hmac.h"
#include "sw/device/silicon_creator/lib/drivers/otp.h"
#include "sw/device/silicon_creator/lib/drivers/rnd.h"
#include "sw/device/silicon_creator/lib/error.h"

#include "hw/top/otp_ctrl_regs.h"

/**
 * Determines whether a key is valid in the RMA life cycle state.
 *
 * Only test and production keys that are valid in the RMA life cycle state.
 *
 * @param key_type Type of the key.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
static rom_error_t key_is_valid_in_lc_state_rma(sigverify_key_type_t key_type) {
  switch (launder32(key_type)) {
    case kSigverifyKeyTypeTest:
      HARDENED_CHECK_EQ(key_type, kSigverifyKeyTypeTest);
      return kErrorOk;
    case kSigverifyKeyTypeProd:
      HARDENED_CHECK_EQ(key_type, kSigverifyKeyTypeProd);
      return kErrorOk;
    case kSigverifyKeyTypeDev:
      HARDENED_CHECK_EQ(key_type, kSigverifyKeyTypeDev);
      return kErrorOk;
    default:
      HARDENED_TRAP();
      OT_UNREACHABLE();
  }
}

/**
 * Determines whether a key is valid in the DEV life cycle state.
 *
 * Only production and development keys are valid in the DEV life cycle state.
 *
 * @param key_type Type of the key.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
static rom_error_t key_is_valid_in_lc_state_dev(sigverify_key_type_t key_type) {
  switch (launder32(key_type)) {
    case kSigverifyKeyTypeTest:
      HARDENED_CHECK_EQ(key_type, kSigverifyKeyTypeTest);
      return kErrorSigverifyBadKey;
    case kSigverifyKeyTypeProd:
      HARDENED_CHECK_EQ(key_type, kSigverifyKeyTypeProd);
      return kErrorOk;
    case kSigverifyKeyTypeDev:
      HARDENED_CHECK_EQ(key_type, kSigverifyKeyTypeDev);
      return kErrorOk;
    default:
      HARDENED_TRAP();
      OT_UNREACHABLE();
  }
}

/**
 * Determines whether a key is valid in PROD and PROD_END life cycle states.
 *
 * Only production keys are valid in PROD and PROD_END life cycle states.
 *
 * @param key_type Type of the key.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
static rom_error_t key_is_valid_in_lc_state_prod(
    sigverify_key_type_t key_type) {
  switch (launder32(key_type)) {
    case kSigverifyKeyTypeTest:
      HARDENED_CHECK_EQ(key_type, kSigverifyKeyTypeTest);
      return kErrorSigverifyBadKey;
    case kSigverifyKeyTypeProd:
      HARDENED_CHECK_EQ(key_type, kSigverifyKeyTypeProd);
      return kErrorOk;
    case kSigverifyKeyTypeDev:
      HARDENED_CHECK_EQ(key_type, kSigverifyKeyTypeDev);
      return kErrorSigverifyBadKey;
    default:
      HARDENED_TRAP();
      OT_UNREACHABLE();
  }
}

/**
 * Determines whether a key is valid in TEST_UNLOCKED_* life cycle states.
 *
 * Only test and production keys are valid in TEST_UNLOCKED_* states.
 *
 * @param key_type Type of the key.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
static rom_error_t key_is_valid_in_lc_state_test(
    sigverify_key_type_t key_type) {
  switch (launder32(key_type)) {
    case kSigverifyKeyTypeTest:
      HARDENED_CHECK_EQ(key_type, kSigverifyKeyTypeTest);
      return kErrorOk;
    case kSigverifyKeyTypeProd:
      HARDENED_CHECK_EQ(key_type, kSigverifyKeyTypeProd);
      return kErrorOk;
    case kSigverifyKeyTypeDev:
      HARDENED_CHECK_EQ(key_type, kSigverifyKeyTypeDev);
      return kErrorOk;
    default:
      HARDENED_TRAP();
      OT_UNREACHABLE();
  }
}

/**
 * Determines whether a given key is valid in the given life cycle state.
 *
 * @param key_type Type of the key.
 * @param lc_state Life cycle state of the device.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
static rom_error_t key_is_valid(sigverify_key_type_t key_type,
                                lifecycle_state_t lc_state) {
  switch (launder32(lc_state)) {
    case kLcStateTest:
      HARDENED_CHECK_EQ(lc_state, kLcStateTest);
      return key_is_valid_in_lc_state_test(key_type);
    case kLcStateProd:
      HARDENED_CHECK_EQ(lc_state, kLcStateProd);
      return key_is_valid_in_lc_state_prod(key_type);
    case kLcStateProdEnd:
      HARDENED_CHECK_EQ(lc_state, kLcStateProdEnd);
      return key_is_valid_in_lc_state_prod(key_type);
    case kLcStateDev:
      HARDENED_CHECK_EQ(lc_state, kLcStateDev);
      return key_is_valid_in_lc_state_dev(key_type);
    case kLcStateRma:
      HARDENED_CHECK_EQ(lc_state, kLcStateRma);
      return key_is_valid_in_lc_state_rma(key_type);
    default:
      HARDENED_TRAP();
      OT_UNREACHABLE();
  }
}

/**
 * Read a hybrid key from OTP.
 */
sigverify_otp_hybrid_key_t sigverify_otp_read_hybrid_key(
    uint32_t key_type_offset, uint32_t ecdsa_key_offset,
    uint32_t spx_key_offset, uint32_t spx_key_config_offset) {
  sigverify_otp_hybrid_key_t out;

  // Read the key type.
  out.key_type = otp_read32(key_type_offset);
  // Read the ECDSA key.
  for (size_t i = 0; i < kEcdsaP256PublicKeyCoordWords; i++) {
    out.ecdsa_key.x[i] = otp_read32(ecdsa_key_offset + i * sizeof(uint32_t));
  }
  for (size_t j = 0; j < kEcdsaP256PublicKeyCoordWords; j++) {
    out.ecdsa_key.y[j] =
        otp_read32(ecdsa_key_offset +
                   (kEcdsaP256PublicKeyCoordWords + j) * sizeof(uint32_t));
  }
  // Read the SPHINCS+ key.
  for (size_t k = 0; k < kSigverifySpxKeyNumWords; k++) {
    out.spx_key.data[k] = otp_read32(spx_key_offset + k * sizeof(uint32_t));
  }
  // Read the SPHINCS+ config ID.
  out.spx_config_id = otp_read32(spx_key_config_offset);

  return out;
}

/**
 * Read an AUTH_SLOT hybrid key state from OTP.
 */
sigverify_otp_hybrid_key_state_t sigverify_otp_read_hybrid_key_state(
    uint32_t ecdsa_state_offset, uint32_t spx_state_offset) {
  sigverify_otp_hybrid_key_state_t state = {
      .ecdsa_key_state = otp_read32(ecdsa_state_offset),
      .spx_key_state = otp_read32(spx_state_offset),
  };
  return state;
}

/* Check ROT_OWNER key and key type OTP field sizes. */
static_assert(
    sizeof(sigverify_key_type_t) ==
        OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT0_FIRMWARE_CODESIGN_KEY_TYPE_SIZE,
    "Unexpected OTP field size.");
static_assert(
    sizeof(sigverify_key_type_t) ==
        OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT1_FIRMWARE_CODESIGN_KEY_TYPE_SIZE,
    "Unexpected OTP field size.");
static_assert(
    sizeof(sigverify_key_type_t) ==
        OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT2_FIRMWARE_CODESIGN_KEY_TYPE_SIZE,
    "Unexpected OTP field size.");
static_assert(
    sizeof(sigverify_key_type_t) ==
        OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT3_FIRMWARE_CODESIGN_KEY_TYPE_SIZE,
    "Unexpected OTP field size.");
static_assert(
    sizeof(ecdsa_p256_public_key_t) ==
        OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT0_FIRMWARE_CODESIGN_ECDSA_KEY_SIZE,
    "Unexpected OTP field size.");
static_assert(
    sizeof(ecdsa_p256_public_key_t) ==
        OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT1_FIRMWARE_CODESIGN_ECDSA_KEY_SIZE,
    "Unexpected OTP field size.");
static_assert(
    sizeof(ecdsa_p256_public_key_t) ==
        OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT2_FIRMWARE_CODESIGN_ECDSA_KEY_SIZE,
    "Unexpected OTP field size.");
static_assert(
    sizeof(ecdsa_p256_public_key_t) ==
        OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT3_FIRMWARE_CODESIGN_ECDSA_KEY_SIZE,
    "Unexpected OTP field size.");
static_assert(
    sizeof(sigverify_spx_key_t) ==
        OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT0_FIRMWARE_CODESIGN_SPX_KEY_SIZE,
    "Unexpected OTP field size.");
static_assert(
    sizeof(sigverify_spx_key_t) ==
        OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT1_FIRMWARE_CODESIGN_SPX_KEY_SIZE,
    "Unexpected OTP field size.");
static_assert(
    sizeof(sigverify_spx_key_t) ==
        OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT2_FIRMWARE_CODESIGN_SPX_KEY_SIZE,
    "Unexpected OTP field size.");
static_assert(
    sizeof(sigverify_spx_key_t) ==
        OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT3_FIRMWARE_CODESIGN_SPX_KEY_SIZE,
    "Unexpected OTP field size.");
static_assert(
    sizeof(sigverify_spx_config_id_t) ==
        OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT0_FIRMWARE_CODESIGN_SPX_KEY_CONFIG_SIZE,
    "Unexpected OTP field size.");
static_assert(
    sizeof(sigverify_spx_config_id_t) ==
        OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT1_FIRMWARE_CODESIGN_SPX_KEY_CONFIG_SIZE,
    "Unexpected OTP field size.");
static_assert(
    sizeof(sigverify_spx_config_id_t) ==
        OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT2_FIRMWARE_CODESIGN_SPX_KEY_CONFIG_SIZE,
    "Unexpected OTP field size.");
static_assert(
    sizeof(sigverify_spx_config_id_t) ==
        OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT3_FIRMWARE_CODESIGN_SPX_KEY_CONFIG_SIZE,
    "Unexpected OTP field size.");

#ifdef HAS_ROM_CTRL1
static_assert(sizeof(sigverify_key_type_t) ==
                  OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT0_ROM1_PATCH_KEY_TYPE_SIZE,
              "Unexpected OTP field size.");
static_assert(sizeof(sigverify_key_type_t) ==
                  OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT1_ROM1_PATCH_KEY_TYPE_SIZE,
              "Unexpected OTP field size.");
static_assert(sizeof(sigverify_key_type_t) ==
                  OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT2_ROM1_PATCH_KEY_TYPE_SIZE,
              "Unexpected OTP field size.");
static_assert(sizeof(sigverify_key_type_t) ==
                  OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT3_ROM1_PATCH_KEY_TYPE_SIZE,
              "Unexpected OTP field size.");
static_assert(sizeof(ecdsa_p256_public_key_t) ==
                  OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT0_ROM1_PATCH_ECDSA_KEY_SIZE,
              "Unexpected OTP field size.");
static_assert(sizeof(ecdsa_p256_public_key_t) ==
                  OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT1_ROM1_PATCH_ECDSA_KEY_SIZE,
              "Unexpected OTP field size.");
static_assert(sizeof(ecdsa_p256_public_key_t) ==
                  OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT2_ROM1_PATCH_ECDSA_KEY_SIZE,
              "Unexpected OTP field size.");
static_assert(sizeof(ecdsa_p256_public_key_t) ==
                  OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT3_ROM1_PATCH_ECDSA_KEY_SIZE,
              "Unexpected OTP field size.");
static_assert(sizeof(sigverify_spx_key_t) ==
                  OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT0_ROM1_PATCH_SPX_KEY_SIZE,
              "Unexpected OTP field size.");
static_assert(sizeof(sigverify_spx_key_t) ==
                  OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT1_ROM1_PATCH_SPX_KEY_SIZE,
              "Unexpected OTP field size.");
static_assert(sizeof(sigverify_spx_key_t) ==
                  OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT2_ROM1_PATCH_SPX_KEY_SIZE,
              "Unexpected OTP field size.");
static_assert(sizeof(sigverify_spx_key_t) ==
                  OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT3_ROM1_PATCH_SPX_KEY_SIZE,
              "Unexpected OTP field size.");
static_assert(
    sizeof(sigverify_spx_config_id_t) ==
        OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT0_ROM1_PATCH_SPX_KEY_CONFIG_SIZE,
    "Unexpected OTP field size.");
static_assert(
    sizeof(sigverify_spx_config_id_t) ==
        OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT1_ROM1_PATCH_SPX_KEY_CONFIG_SIZE,
    "Unexpected OTP field size.");
static_assert(
    sizeof(sigverify_spx_config_id_t) ==
        OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT2_ROM1_PATCH_SPX_KEY_CONFIG_SIZE,
    "Unexpected OTP field size.");
static_assert(
    sizeof(sigverify_spx_config_id_t) ==
        OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT3_ROM1_PATCH_SPX_KEY_CONFIG_SIZE,
    "Unexpected OTP field size.");
#endif

/**
 * Read the keys from the specified ROT_OWNER_AUTH_SLOT from OTP.
 */
void sigverify_otp_read_rot_owner_auth_slot(
    uint32_t slot, sigverify_otp_rot_owner_auth_slot_t *out) {
  uint32_t firmware_codesign_key_type_offset = 0;
  uint32_t firmware_codesign_ecdsa_key_offset = 0;
  uint32_t firmware_codesign_spx_key_offset = 0;
  uint32_t firmware_codesign_spx_key_config_offset = 0;
#ifdef HAS_ROM_CTRL1
  uint32_t rom1_patch_key_type_offset = 0;
  uint32_t rom1_patch_ecdsa_key_offset = 0;
  uint32_t rom1_patch_spx_key_offset = 0;
  uint32_t rom1_patch_spx_key_config_offset = 0;
#endif
  switch (launder32(slot)) {
    case kSigVerifyOtpKeysRotOwnerSlot0:
      HARDENED_CHECK_EQ(slot, kSigVerifyOtpKeysRotOwnerSlot0);
      firmware_codesign_key_type_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT0_FIRMWARE_CODESIGN_KEY_TYPE_OFFSET;
      firmware_codesign_ecdsa_key_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT0_FIRMWARE_CODESIGN_ECDSA_KEY_OFFSET;
      firmware_codesign_spx_key_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT0_FIRMWARE_CODESIGN_SPX_KEY_OFFSET;
      firmware_codesign_spx_key_config_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT0_FIRMWARE_CODESIGN_SPX_KEY_CONFIG_OFFSET;

#ifdef HAS_ROM_CTRL1
      rom1_patch_key_type_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT0_ROM1_PATCH_KEY_TYPE_OFFSET;
      rom1_patch_ecdsa_key_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT0_ROM1_PATCH_ECDSA_KEY_OFFSET;
      rom1_patch_spx_key_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT0_ROM1_PATCH_SPX_KEY_OFFSET;
      rom1_patch_spx_key_config_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT0_ROM1_PATCH_SPX_KEY_CONFIG_OFFSET;
#endif
      break;
    case kSigVerifyOtpKeysRotOwnerSlot1:
      HARDENED_CHECK_EQ(slot, kSigVerifyOtpKeysRotOwnerSlot1);
      firmware_codesign_key_type_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT1_FIRMWARE_CODESIGN_KEY_TYPE_OFFSET;
      firmware_codesign_ecdsa_key_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT1_FIRMWARE_CODESIGN_ECDSA_KEY_OFFSET;
      firmware_codesign_spx_key_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT1_FIRMWARE_CODESIGN_SPX_KEY_OFFSET;
      firmware_codesign_spx_key_config_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT1_FIRMWARE_CODESIGN_SPX_KEY_CONFIG_OFFSET;

#ifdef HAS_ROM_CTRL1
      rom1_patch_key_type_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT1_ROM1_PATCH_KEY_TYPE_OFFSET;
      rom1_patch_ecdsa_key_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT1_ROM1_PATCH_ECDSA_KEY_OFFSET;
      rom1_patch_spx_key_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT1_ROM1_PATCH_SPX_KEY_OFFSET;
      rom1_patch_spx_key_config_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT1_ROM1_PATCH_SPX_KEY_CONFIG_OFFSET;
#endif
      break;
    case kSigVerifyOtpKeysRotOwnerSlot2:
      HARDENED_CHECK_EQ(slot, kSigVerifyOtpKeysRotOwnerSlot2);
      firmware_codesign_key_type_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT2_FIRMWARE_CODESIGN_KEY_TYPE_OFFSET;
      firmware_codesign_ecdsa_key_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT2_FIRMWARE_CODESIGN_ECDSA_KEY_OFFSET;
      firmware_codesign_spx_key_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT2_FIRMWARE_CODESIGN_SPX_KEY_OFFSET;
      firmware_codesign_spx_key_config_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT2_FIRMWARE_CODESIGN_SPX_KEY_CONFIG_OFFSET;

#ifdef HAS_ROM_CTRL1
      rom1_patch_key_type_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT2_ROM1_PATCH_KEY_TYPE_OFFSET;
      rom1_patch_ecdsa_key_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT2_ROM1_PATCH_ECDSA_KEY_OFFSET;
      rom1_patch_spx_key_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT2_ROM1_PATCH_SPX_KEY_OFFSET;
      rom1_patch_spx_key_config_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT2_ROM1_PATCH_SPX_KEY_CONFIG_OFFSET;
#endif
      break;
    case kSigVerifyOtpKeysRotOwnerSlot3:
      HARDENED_CHECK_EQ(slot, kSigVerifyOtpKeysRotOwnerSlot3);
      firmware_codesign_key_type_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT3_FIRMWARE_CODESIGN_KEY_TYPE_OFFSET;
      firmware_codesign_ecdsa_key_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT3_FIRMWARE_CODESIGN_ECDSA_KEY_OFFSET;
      firmware_codesign_spx_key_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT3_FIRMWARE_CODESIGN_SPX_KEY_OFFSET;
      firmware_codesign_spx_key_config_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT3_FIRMWARE_CODESIGN_SPX_KEY_CONFIG_OFFSET;

#ifdef HAS_ROM_CTRL1
      rom1_patch_key_type_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT3_ROM1_PATCH_KEY_TYPE_OFFSET;
      rom1_patch_ecdsa_key_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT3_ROM1_PATCH_ECDSA_KEY_OFFSET;
      rom1_patch_spx_key_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT3_ROM1_PATCH_SPX_KEY_OFFSET;
      rom1_patch_spx_key_config_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT3_ROM1_PATCH_SPX_KEY_CONFIG_OFFSET;
#endif
      break;
    default:
      HARDENED_TRAP();
      break;
  }

  out->firmware_codesign_keys = sigverify_otp_read_hybrid_key(
      firmware_codesign_key_type_offset, firmware_codesign_ecdsa_key_offset,
      firmware_codesign_spx_key_offset,
      firmware_codesign_spx_key_config_offset);
#ifdef HAS_ROM_CTRL1
  out->rom1_patch_keys = sigverify_otp_read_hybrid_key(
      rom1_patch_key_type_offset, rom1_patch_ecdsa_key_offset,
      rom1_patch_spx_key_offset, rom1_patch_spx_key_config_offset);
#endif
}

/* Check ROT_OWNER key and key state OTP sizes. */
static_assert(
    sizeof(uint32_t) ==
        OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT0_STATE_FIRMWARE_CODESIGN_ECDSA_KEY_STATE_SIZE,
    "Unexpected OTP field size.");
static_assert(
    sizeof(uint32_t) ==
        OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT1_STATE_FIRMWARE_CODESIGN_ECDSA_KEY_STATE_SIZE,
    "Unexpected OTP field size.");
static_assert(
    sizeof(uint32_t) ==
        OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT2_STATE_FIRMWARE_CODESIGN_ECDSA_KEY_STATE_SIZE,
    "Unexpected OTP field size.");
static_assert(
    sizeof(uint32_t) ==
        OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT3_STATE_FIRMWARE_CODESIGN_ECDSA_KEY_STATE_SIZE,
    "Unexpected OTP field size.");
static_assert(
    sizeof(uint32_t) ==
        OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT0_STATE_FIRMWARE_CODESIGN_SPX_KEY_STATE_SIZE,
    "Unexpected OTP field size.");
static_assert(
    sizeof(uint32_t) ==
        OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT1_STATE_FIRMWARE_CODESIGN_SPX_KEY_STATE_SIZE,
    "Unexpected OTP field size.");
static_assert(
    sizeof(uint32_t) ==
        OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT2_STATE_FIRMWARE_CODESIGN_SPX_KEY_STATE_SIZE,
    "Unexpected OTP field size.");
static_assert(
    sizeof(uint32_t) ==
        OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT3_STATE_FIRMWARE_CODESIGN_SPX_KEY_STATE_SIZE,
    "Unexpected OTP field size.");

#ifdef HAS_ROM_CTRL1
static_assert(
    sizeof(uint32_t) ==
        OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT0_STATE_ROM1_PATCH_ECDSA_KEY_STATE_SIZE,
    "Unexpected OTP field size.");
static_assert(
    sizeof(uint32_t) ==
        OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT1_STATE_ROM1_PATCH_ECDSA_KEY_STATE_SIZE,
    "Unexpected OTP field size.");
static_assert(
    sizeof(uint32_t) ==
        OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT2_STATE_ROM1_PATCH_ECDSA_KEY_STATE_SIZE,
    "Unexpected OTP field size.");
static_assert(
    sizeof(uint32_t) ==
        OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT3_STATE_ROM1_PATCH_ECDSA_KEY_STATE_SIZE,
    "Unexpected OTP field size.");
static_assert(
    sizeof(uint32_t) ==
        OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT0_STATE_ROM1_PATCH_SPX_KEY_STATE_SIZE,
    "Unexpected OTP field size.");
static_assert(
    sizeof(uint32_t) ==
        OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT1_STATE_ROM1_PATCH_SPX_KEY_STATE_SIZE,
    "Unexpected OTP field size.");
static_assert(
    sizeof(uint32_t) ==
        OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT2_STATE_ROM1_PATCH_SPX_KEY_STATE_SIZE,
    "Unexpected OTP field size.");
static_assert(
    sizeof(uint32_t) ==
        OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT3_STATE_ROM1_PATCH_SPX_KEY_STATE_SIZE,
    "Unexpected OTP field size.");
#endif

/**
 * Read the key states for the specified ROT_OWNER_AUTH_SLOT from OTP.
 */
void sigverify_otp_read_rot_owner_auth_slot_state(
    uint32_t slot, sigverify_otp_rot_owner_auth_slot_state_t *out) {
  uint32_t firmware_codesign_ecdsa_key_state_offset = 0;
  uint32_t firmware_codesign_spx_key_state_offset = 0;
#ifdef HAS_ROM_CTRL1
  uint32_t rom1_patch_ecdsa_key_state_offset = 0;
  uint32_t rom1_patch_spx_key_state_offset = 0;
#endif

  switch (launder32(slot)) {
    case kSigVerifyOtpKeysRotOwnerSlot0:
      HARDENED_CHECK_EQ(slot, kSigVerifyOtpKeysRotOwnerSlot0);
      firmware_codesign_ecdsa_key_state_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT0_STATE_FIRMWARE_CODESIGN_ECDSA_KEY_STATE_OFFSET;
      firmware_codesign_spx_key_state_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT0_STATE_FIRMWARE_CODESIGN_SPX_KEY_STATE_OFFSET;
#ifdef HAS_ROM_CTRL1
      rom1_patch_ecdsa_key_state_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT0_STATE_ROM1_PATCH_ECDSA_KEY_STATE_OFFSET;
      rom1_patch_spx_key_state_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT0_STATE_ROM1_PATCH_SPX_KEY_STATE_OFFSET;
#endif
      break;
    case kSigVerifyOtpKeysRotOwnerSlot1:
      HARDENED_CHECK_EQ(slot, kSigVerifyOtpKeysRotOwnerSlot1);
      firmware_codesign_ecdsa_key_state_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT1_STATE_FIRMWARE_CODESIGN_ECDSA_KEY_STATE_OFFSET;
      firmware_codesign_spx_key_state_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT1_STATE_FIRMWARE_CODESIGN_SPX_KEY_STATE_OFFSET;
#ifdef HAS_ROM_CTRL1
      rom1_patch_ecdsa_key_state_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT1_STATE_ROM1_PATCH_ECDSA_KEY_STATE_OFFSET;
      rom1_patch_spx_key_state_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT1_STATE_ROM1_PATCH_SPX_KEY_STATE_OFFSET;
#endif
      break;
    case kSigVerifyOtpKeysRotOwnerSlot2:
      HARDENED_CHECK_EQ(slot, kSigVerifyOtpKeysRotOwnerSlot2);
      firmware_codesign_ecdsa_key_state_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT2_STATE_FIRMWARE_CODESIGN_ECDSA_KEY_STATE_OFFSET;
      firmware_codesign_spx_key_state_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT2_STATE_FIRMWARE_CODESIGN_SPX_KEY_STATE_OFFSET;
#ifdef HAS_ROM_CTRL1
      rom1_patch_ecdsa_key_state_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT2_STATE_ROM1_PATCH_ECDSA_KEY_STATE_OFFSET;
      rom1_patch_spx_key_state_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT2_STATE_ROM1_PATCH_SPX_KEY_STATE_OFFSET;
#endif
      break;
    case kSigVerifyOtpKeysRotOwnerSlot3:
      HARDENED_CHECK_EQ(slot, kSigVerifyOtpKeysRotOwnerSlot3);
      firmware_codesign_ecdsa_key_state_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT3_STATE_FIRMWARE_CODESIGN_ECDSA_KEY_STATE_OFFSET;
      firmware_codesign_spx_key_state_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT3_STATE_FIRMWARE_CODESIGN_SPX_KEY_STATE_OFFSET;
#ifdef HAS_ROM_CTRL1
      rom1_patch_ecdsa_key_state_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT3_STATE_ROM1_PATCH_ECDSA_KEY_STATE_OFFSET;
      rom1_patch_spx_key_state_offset =
          OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT3_STATE_ROM1_PATCH_SPX_KEY_STATE_OFFSET;
#endif
      break;
    default:
      HARDENED_TRAP();
      break;
  }

  out->firmware_codesign_key_state = sigverify_otp_read_hybrid_key_state(
      firmware_codesign_ecdsa_key_state_offset,
      firmware_codesign_spx_key_state_offset);
#ifdef HAS_ROM_CTRL1
  out->rom1_patch_key_state = sigverify_otp_read_hybrid_key_state(
      rom1_patch_ecdsa_key_state_offset, rom1_patch_spx_key_state_offset);
#endif
}

rom_error_t sigverify_otp_keys_init(sigverify_otp_key_ctx_t *ctx) {
  // Read ROT_OWNER AUTH_SLOTs.
  for (size_t i = 0; i < kSigVerifyOtpKeysRotOwnerAuthSlotCount; i++) {
    sigverify_otp_read_rot_owner_auth_slot(i, &ctx->rot_owner.slots[i]);
    sigverify_otp_read_rot_owner_auth_slot_state(
        i, &ctx->rot_owner.slot_states[i]);
  }
  return kErrorOk;
}

rom_error_t check_ecdsa_key(const ecdsa_p256_public_key_t *a,
                            const ecdsa_p256_public_key_t *b) {
  uint32_t i, j;
  for (i = 0; i < kEcdsaP256PublicKeyCoordWords; i++) {
    uint32_t expected = a->x[i];
    uint32_t actual = b->x[i];
    if (launder32(expected) != launder32(actual)) {
      break;
    }
    HARDENED_CHECK_EQ(expected, actual);
  }
  for (j = 0; j < kEcdsaP256PublicKeyCoordWords; j++) {
    uint32_t expected = a->y[j];
    uint32_t actual = b->y[j];
    if (launder32(expected) != launder32(actual)) {
      break;
    }
    HARDENED_CHECK_EQ(expected, actual);
  }
  // If we reached the end of both loops without hitting a `break`, both
  // the `x` and `y` coordinates match.
  if (launder32(i) == kEcdsaP256PublicKeyCoordWords &&
      launder32(j) == kEcdsaP256PublicKeyCoordWords) {
    HARDENED_CHECK_EQ(kEcdsaP256PublicKeyCoordWords, i);
    HARDENED_CHECK_EQ(kEcdsaP256PublicKeyCoordWords, j);
    return kErrorOk;
  }
  return kErrorSigverifyBadEcdsaKey;
}

rom_error_t check_spx_key(const sigverify_spx_key_t *a,
                          const sigverify_spx_key_t *b) {
  for (uint32_t i = 0; i < kSigverifySpxKeyNumWords; i++) {
    uint32_t expected = a->data[i];
    uint32_t actual = b->data[i];
    if (launder32(expected) != launder32(actual)) {
      return kErrorSigverifyBadSpxKey;
    }
    HARDENED_CHECK_EQ(expected, actual);
  }
  return kErrorOk;
}

static_assert(kSigVerifyOtpKeysRotOwnerAuthSlotCount <= 4,
              "Unexpected OTP key slot count.");

rom_error_t sigverify_otp_key_lookup(sigverify_otp_key_ctx_t *ctx,
                                     const uint32_t key_spec,
                                     const uint32_t algorithm,
                                     const ecdsa_p256_public_key_t *ecdsa_key,
                                     const sigverify_spx_key_t *spx_key,
                                     const lifecycle_state_t lc_state,
                                     sigverify_spx_config_id_t *spx_config) {
  uint32_t n_slots = 0;
  sigverify_otp_hybrid_key_t *keys[4];
  sigverify_otp_hybrid_key_state_t *key_states[4];
  switch (launder32(key_spec)) {
    case kSigVerifyOtpKeysKeySpecRotOwnerFirmwareCodesign:
      HARDENED_CHECK_EQ(key_spec,
                        kSigVerifyOtpKeysKeySpecRotOwnerFirmwareCodesign);
      n_slots = 4;
      keys[0] = &ctx->rot_owner.slots[0].firmware_codesign_keys;
      keys[1] = &ctx->rot_owner.slots[1].firmware_codesign_keys;
      keys[2] = &ctx->rot_owner.slots[2].firmware_codesign_keys;
      keys[3] = &ctx->rot_owner.slots[3].firmware_codesign_keys;
      key_states[0] =
          &ctx->rot_owner.slot_states[0].firmware_codesign_key_state;
      key_states[1] =
          &ctx->rot_owner.slot_states[1].firmware_codesign_key_state;
      key_states[2] =
          &ctx->rot_owner.slot_states[2].firmware_codesign_key_state;
      key_states[3] =
          &ctx->rot_owner.slot_states[3].firmware_codesign_key_state;
      break;
#ifdef HAS_ROM_CTRL1
    case kSigVerifyOtpKeysKeySpecRotOwnerRom1Patch:
      HARDENED_CHECK_EQ(key_spec, kSigVerifyOtpKeysKeySpecRotOwnerRom1Patch);
      n_slots = 4;
      keys[0] = &ctx->rot_owner.slots[0].rom1_patch_keys;
      keys[1] = &ctx->rot_owner.slots[1].rom1_patch_keys;
      keys[2] = &ctx->rot_owner.slots[2].rom1_patch_keys;
      keys[3] = &ctx->rot_owner.slots[3].rom1_patch_keys;
      key_states[0] = &ctx->rot_owner.slot_states[0].rom1_patch_key_state;
      key_states[1] = &ctx->rot_owner.slot_states[1].rom1_patch_key_state;
      key_states[2] = &ctx->rot_owner.slot_states[2].rom1_patch_key_state;
      key_states[3] = &ctx->rot_owner.slot_states[3].rom1_patch_key_state;
      break;
#endif
    default:
      HARDENED_TRAP();
      break;
  }

  size_t cand_key_index = UINT32_MAX;
  // Randomize the start index to avoid always picking the first key.
  // A potential attacker will have a hardtime predicting the timing in
  // which the key will be selected.
  size_t i = ((uint64_t)rnd_uint32() * (uint64_t)n_slots) >> 32;

  // Use forward and backwards iteration counters to ensure that the loop was
  // executed exactly `n_slots` times. This is to prevent faults causing
  // the loop to skip inner iterations.
  size_t iter_cnt = 0, r_iter_cnt = n_slots - 1;
  for (; launder32(iter_cnt) < n_slots && launder32(r_iter_cnt) < n_slots;
       ++iter_cnt, --r_iter_cnt) {
    // Check if the key is compatible with the current lifecycle state.
    rom_error_t error = key_is_valid(keys[i]->key_type, lc_state);
    if (launder32(error) == kErrorOk) {
      HARDENED_CHECK_EQ(kErrorOk, error);
      // Check that the key slot is provisioned.
      //
      // If it is, check if the key in slot `i` is equal to `public_key` for the
      // requested algorithm.
      switch (launder32(algorithm)) {
        case kSigVerifyOtpKeysAlgorithmEcdsa:
          HARDENED_CHECK_EQ(algorithm, kSigVerifyOtpKeysAlgorithmEcdsa);
          if (ecdsa_key == NULL) {
            return kErrorSigverifyBadKey;
          }
          HARDENED_CHECK_NE(ecdsa_key, NULL);
          if (key_states[i]->ecdsa_key_state !=
              kSigVerifyKeyAuthStateProvisioned) {
            error = kErrorSigverifyBadKey;
          } else {
            HARDENED_CHECK_EQ(key_states[i]->ecdsa_key_state,
                              kSigVerifyKeyAuthStateProvisioned);
            error = check_ecdsa_key(&keys[i]->ecdsa_key, ecdsa_key);
          }
          break;
        case kSigVerifyOtpKeysAlgorithmSpx:
          HARDENED_CHECK_EQ(algorithm, kSigVerifyOtpKeysAlgorithmSpx);
          if (key_states[i]->spx_key_state !=
              kSigVerifyKeyAuthStateProvisioned) {
            error = kErrorSigverifyBadKey;
          } else {
            HARDENED_CHECK_EQ(key_states[i]->spx_key_state,
                              kSigVerifyKeyAuthStateProvisioned);
            error = check_spx_key(&keys[i]->spx_key, spx_key);
          }
          break;
        default:
          HARDENED_TRAP();
          break;
      }
      if (launder32(error) == kErrorOk) {
        HARDENED_CHECK_EQ(kErrorOk, error);
        cand_key_index = i;
      }
    }
    i++;
    if (launder32(i) >= n_slots) {
      i -= n_slots;
    }
    HARDENED_CHECK_LT(i, n_slots);
  }
  // Ensure that the loop was executed exactly `n_slots` times.
  HARDENED_CHECK_EQ(iter_cnt, n_slots);
  HARDENED_CHECK_EQ(r_iter_cnt, SIZE_MAX);
  // For SPX keys, set the config value.
  switch (launder32(algorithm)) {
    case kSigVerifyOtpKeysAlgorithmEcdsa:
      break;
    case kSigVerifyOtpKeysAlgorithmSpx:
      *spx_config = keys[cand_key_index]->spx_config_id;
      break;
    default:
      HARDENED_TRAP();
      break;
  }
  // Verify the key a second time and only kErrorOk it if it passes all checks.
  // The hardened check macros create barriers in the code, causing the binary
  // to perform the checks as written in the code (i.e. the checks, or their
  // order, cannot be optimized out by the compiler). This is a security measure
  // to ensure that the checks are performed as intended.
  if (launder32(cand_key_index) < n_slots) {
    HARDENED_CHECK_LT(cand_key_index, n_slots);
    switch (launder32(algorithm)) {
      case kSigVerifyOtpKeysAlgorithmEcdsa:
        HARDENED_CHECK_EQ(algorithm, kSigVerifyOtpKeysAlgorithmEcdsa);
        HARDENED_CHECK_EQ(
            launder32(key_states[cand_key_index]->ecdsa_key_state),
            kSigVerifyKeyAuthStateProvisioned);
        break;
      case kSigVerifyOtpKeysAlgorithmSpx:
        HARDENED_CHECK_EQ(algorithm, kSigVerifyOtpKeysAlgorithmSpx);
        HARDENED_CHECK_EQ(launder32(key_states[cand_key_index]->spx_key_state),
                          kSigVerifyKeyAuthStateProvisioned);
        break;
      default:
        HARDENED_TRAP();
        break;
    }
    rom_error_t error = key_is_valid(keys[cand_key_index]->key_type, lc_state);
    HARDENED_CHECK_EQ(launder32(error), kErrorOk);
    return error;
  }
  return kErrorSigverifyBadKey;
}
