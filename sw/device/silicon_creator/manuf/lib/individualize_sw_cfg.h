// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_SILICON_CREATOR_MANUF_LIB_INDIVIDUALIZE_SW_CFG_H_
#define OPENTITAN_SW_DEVICE_SILICON_CREATOR_MANUF_LIB_INDIVIDUALIZE_SW_CFG_H_

#include "sw/device/lib/base/status.h"
#include "sw/device/lib/dif/dif_flash_ctrl.h"
#include "sw/device/lib/dif/dif_otp_ctrl.h"
#include "sw/device/silicon_creator/manuf/lib/otp_img_types.h"

/**
 * OTP Creator Software Configuration Partition.
 */
extern const size_t kOtpKvCreatorSwCfgSize;
extern const otp_kv_t kOtpKvCreatorSwCfg[];
extern const uint32_t kCreatorSwCfgFlashDataDefaultCfgValue;
extern const uint32_t kCreatorSwCfgFlashInfoBootDataCfgValue;
extern const uint32_t kCreatorSwCfgManufStateValue;
extern const uint32_t kCreatorSwCfgImmutableRomExtEnValue;

/**
 * OTP Owner Software Configuration Partition.
 */
extern const size_t kOtpKvOwnerSwCfgSize;
extern const otp_kv_t kOtpKvOwnerSwCfg[];
extern const uint32_t kOwnerSwCfgRomBootstrapDisValue;

/**
 * OTP RoT Owner Auth Slot Partitions.
 */
extern const size_t kOtpKvRotOwnerAuthSlot0Size;
extern const otp_kv_t kOtpKvRotOwnerAuthSlot0[];
extern const size_t kOtpKvRotOwnerAuthSlot1Size;
extern const otp_kv_t kOtpKvRotOwnerAuthSlot1[];
extern const size_t kOtpKvRotOwnerAuthSlot2Size;
extern const otp_kv_t kOtpKvRotOwnerAuthSlot2[];
extern const size_t kOtpKvRotOwnerAuthSlot3Size;
extern const otp_kv_t kOtpKvRotOwnerAuthSlot3[];

/**
 * OTP RoT Owner Auth Slot State Partitions.
 */
extern const size_t kOtpKvRotOwnerAuthSlot0StateSize;
extern const otp_kv_t kOtpKvRotOwnerAuthSlot0State[];
extern const size_t kOtpKvRotOwnerAuthSlot1StateSize;
extern const otp_kv_t kOtpKvRotOwnerAuthSlot1State[];
extern const size_t kOtpKvRotOwnerAuthSlot2StateSize;
extern const otp_kv_t kOtpKvRotOwnerAuthSlot2State[];
extern const size_t kOtpKvRotOwnerAuthSlot3StateSize;
extern const otp_kv_t kOtpKvRotOwnerAuthSlot3State[];

/**
 * Configures the CREATOR_SW_CFG OTP partition.
 *
 * The CREATOR_SW_CFG partition contains various settings for the ROM, e.g.,:
 * - ROM execution enablement
 * - ROM key enable/disable flags
 * - AST and entropy complex configuration
 * - Various ROM feature knobs
 *
 * Note:
 * - The operation will fail if there are any pre-programmed words not equal
 *   to the expected test values.
 * - This operation will explicitly NOT provision the FLASH_DATA_DEFAULT_CFG
 *   and MANUF_STATE fields in the CREATOR_SW_CFG partition. These fields must
 * be explicitly configured after all other provisioning operations are done,
 * but before the partition is locked, and the final transport image is loaded.
 * - This function will NOT lock the partition either. This must be done after
 *   provisioning the final FLASH_DATA_DEFAULT_CFG and MANUF_STATE fields
 * mentioned above.
 * - The partition must be configured and the chip reset, before the ROM can be
 *   booted, thus enabling bootstrap.
 *
 * @param otp_ctrl OTP controller instance.
 * @param flash_state Flash controller instance.
 * @return OK_STATUS if the CREATOR_SW_CFG partition was provisioned.
 */
OT_WARN_UNUSED_RESULT
status_t manuf_individualize_device_creator_sw_cfg(
    const dif_otp_ctrl_t *otp_ctrl, dif_flash_ctrl_state_t *flash_state);

/**
 * This must be called before both
 * `manuf_individualize_device_creator_sw_cfg_lock()` and
 * `manuf_individualize_device_owner_sw_cfg_lock()` are called. The operation
 * will fail if there are any pre-programmed words not equal to the expected
 * test values.
 *
 */
OT_WARN_UNUSED_RESULT
status_t manuf_individualize_device_field_cfg(const dif_otp_ctrl_t *otp_ctrl,
                                              uint32_t field_offset);

/**
 * Checks the FLASH_DATA_DEFAULT_CFG field in the CREATOR_SW_CFG OTP
 * partition.
 *
 * @param otp_ctrl OTP controller instance.
 * @return OK_STATUS if the FLASH_DATA_DEFAULT_CFG field is provisioned.
 */
OT_WARN_UNUSED_RESULT
status_t manuf_individualize_device_flash_data_default_cfg_check(
    const dif_otp_ctrl_t *otp_ctrl);

/**
 * Checks the FLASH_INFO_BOOT_DATA_CFG field in the CREATOR_SW_CFG OTP
 * partition.
 *
 * @param otp_ctrl OTP controller instance.
 * @return OK_STATUS if the FLASH_INFO_BOOT_DATA_CFG field is provisioned.
 */
OT_WARN_UNUSED_RESULT
status_t manuf_individualize_device_flash_info_boot_data_cfg_check(
    const dif_otp_ctrl_t *otp_ctrl);

/**
 * Locks the CREATOR_SW_CFG OTP partition.
 *
 * This must be called after `manuf_individualize_device_field_cfg()`
 * has been called.
 *
 * @param otp_ctrl OTP controller instance.
 * @return OK_STATUS if the CREATOR_SW_CFG partition was locked.
 */
OT_WARN_UNUSED_RESULT
status_t manuf_individualize_device_creator_sw_cfg_lock(
    const dif_otp_ctrl_t *otp_ctrl);

/**
 * Checks the CREATOR_SW_CFG OTP partition end state.
 *
 * @param otp_ctrl OTP controller interface.
 * @return OK_STATUS if the CREATOR_SW_CFG partition is locked.
 */
status_t manuf_individualize_device_creator_sw_cfg_check(
    const dif_otp_ctrl_t *otp_ctrl);

/**
 * Configures the OWNER_SW_CFG OTP partition.
 *
 * The OWNER_SW_CFG partition contains additional settings for the ROM and
 * ROM_EXT, for example:
 * - Alert handler configuration
 * - ROM_EXT bootstrap enablement
 *
 * Note:
 * - The operation will fail if there are any pre-programmed words not equal to
 *   the expected test values.
 * - This operation will explicitly NOT provision the ROM_BOOTSTRAP_DIS
 *   field in the OWNER_SW_CFG partition. This field must be explicitly
 *   configured after all other provisioning operations are done, but before the
 *   partition is locked, and the final transport image is loaded.
 *
 * @param otp_ctrl OTP controller instance.
 * @return OK_STATUS if the OWNER_SW_CFG partition is locked.
 */
OT_WARN_UNUSED_RESULT
status_t manuf_individualize_device_owner_sw_cfg(
    const dif_otp_ctrl_t *otp_ctrl);

/**
 * Locks the OWNER_SW_CFG OTP partition.
 *
 * This must be called after `manuf_individualize_device_field_cfg()`
 * has been called.
 *
 * @param otp_ctrl OTP controller instance.
 * @return OK_STATUS if the OWNER_SW_CFG partition was locked.
 */
OT_WARN_UNUSED_RESULT
status_t manuf_individualize_device_owner_sw_cfg_lock(
    const dif_otp_ctrl_t *otp_ctrl);

/**
 * Checks the OWNER_SW_CFG OTP partition end state.
 *
 * @param otp_ctrl OTP controller interface.
 * @return OK_STATUS if the OWNER_SW_CFG partition is locked.
 */
status_t manuf_individualize_device_owner_sw_cfg_check(
    const dif_otp_ctrl_t *otp_ctrl);

/**
 * Overwrites unprovisioned fields with their expected final values in a buffer
 * representing the provided partition.
 *
 * @param partition Target OTP partition.
 * @param[out] buffer A buffer containing the entire target OTP partition.
 * @return OK_STATUS if the expected partition values are successfully written
 * to the `buffer`.
 */
status_t manuf_individualize_device_partition_expected_read(
    const dif_otp_ctrl_t *otp_ctrl, otp_partition_t partition, uint8_t *buffer);

/**
 * Configures and locks the ROT_OWNER_AUTH_SLOT0 OTP partition.
 *
 * The ROT_OWNER_AUTH_SLOT0 partition contains the first stage
 * (ROM->ROM_EXT) secure boot public keys.
 *
 * @param otp_ctrl OTP controller instance.
 * @return OK_STATUS if the ROT_OWNER_AUTH_SLOT0 partition has been locked.
 */
OT_WARN_UNUSED_RESULT
status_t manuf_individualize_device_rot_owner_auth_slot0(
    const dif_otp_ctrl_t *otp_ctrl);

/**
 * Checks the ROT_OWNER_AUTH_SLOT0 OTP partition end state.
 *
 * @param otp_ctrl OTP controller interface.
 * @return OK_STATUS if the ROT_OWNER_AUTH_SLOT0 partition is locked.
 */
status_t manuf_individualize_device_rot_owner_auth_slot0_check(
    const dif_otp_ctrl_t *otp_ctrl);

/**
 * Configures and locks the ROT_OWNER_AUTH_SLOT1 OTP partition.
 *
 * The ROT_OWNER_AUTH_SLOT1 partition contains the first stage
 * (ROM->ROM_EXT) secure boot public keys.
 *
 * @param otp_ctrl OTP controller instance.
 * @return OK_STATUS if the ROT_OWNER_AUTH_SLOT1 partition has been locked.
 */
OT_WARN_UNUSED_RESULT
status_t manuf_individualize_device_rot_owner_auth_slot1(
    const dif_otp_ctrl_t *otp_ctrl);

/**
 * Checks the ROT_OWNER_AUTH_SLOT1 OTP partition end state.
 *
 * @param otp_ctrl OTP controller interface.
 * @return OK_STATUS if the ROT_OWNER_AUTH_SLOT1 partition is locked.
 */
status_t manuf_individualize_device_rot_owner_auth_slot1_check(
    const dif_otp_ctrl_t *otp_ctrl);

/**
 * Configures and locks the ROT_OWNER_AUTH_SLOT2 OTP partition.
 *
 * The ROT_OWNER_AUTH_SLOT2 partition contains the first stage
 * (ROM->ROM_EXT) secure boot public keys.
 *
 * @param otp_ctrl OTP controller instance.
 * @return OK_STATUS if the ROT_OWNER_AUTH_SLOT2 partition has been locked.
 */
OT_WARN_UNUSED_RESULT
status_t manuf_individualize_device_rot_owner_auth_slot2(
    const dif_otp_ctrl_t *otp_ctrl);

/**
 * Checks the ROT_OWNER_AUTH_SLOT2 OTP partition end state.
 *
 * @param otp_ctrl OTP controller interface.
 * @return OK_STATUS if the ROT_OWNER_AUTH_SLOT2 partition is locked.
 */
status_t manuf_individualize_device_rot_owner_auth_slot2_check(
    const dif_otp_ctrl_t *otp_ctrl);

/**
 * Configures and locks the ROT_OWNER_AUTH_SLOT3 OTP partition.
 *
 * The ROT_OWNER_AUTH_SLOT3 partition contains the first stage
 * (ROM->ROM_EXT) secure boot public keys.
 *
 * @param otp_ctrl OTP controller instance.
 * @return OK_STATUS if the ROT_OWNER_AUTH_SLOT3 partition has been locked.
 */
OT_WARN_UNUSED_RESULT
status_t manuf_individualize_device_rot_owner_auth_slot3(
    const dif_otp_ctrl_t *otp_ctrl);

/**
 * Checks the ROT_OWNER_AUTH_SLOT3 OTP partition end state.
 *
 * @param otp_ctrl OTP controller interface.
 * @return OK_STATUS if the ROT_OWNER_AUTH_SLOT3 partition is locked.
 */
status_t manuf_individualize_device_rot_owner_auth_slot3_check(
    const dif_otp_ctrl_t *otp_ctrl);

/**
 * Configures and locks the ROT_OWNER_AUTH_SLOT0_STATE OTP partition.
 *
 * The ROT_OWNER_AUTH_SLOT0_STATE partition contains the first stage
 * (ROM->ROM_EXT) secure boot public key validity states.
 *
 * @param otp_ctrl OTP controller instance.
 * @return OK_STATUS if the ROT_OWNER_AUTH_SLOT0_STATE partition has been
 * locked.
 */
OT_WARN_UNUSED_RESULT
status_t manuf_individualize_device_rot_owner_auth_slot0_state(
    const dif_otp_ctrl_t *otp_ctrl);

/**
 * Checks the ROT_OWNER_AUTH_SLOT0_STATE OTP partition end state.
 *
 * @param otp_ctrl OTP controller interface.
 * @return OK_STATUS if the ROT_OWNER_AUTH_SLOT0_STATE partition is locked.
 */
status_t manuf_individualize_device_rot_owner_auth_slot0_state_check(
    const dif_otp_ctrl_t *otp_ctrl);

/**
 * Configures and locks the ROT_OWNER_AUTH_SLOT1_STATE OTP partition.
 *
 * The ROT_OWNER_AUTH_SLOT1_STATE partition contains the first stage
 * (ROM->ROM_EXT) secure boot public key validity states.
 *
 * @param otp_ctrl OTP controller instance.
 * @return OK_STATUS if the ROT_OWNER_AUTH_SLOT1_STATE partition has been
 * locked.
 */
OT_WARN_UNUSED_RESULT
status_t manuf_individualize_device_rot_owner_auth_slot1_state(
    const dif_otp_ctrl_t *otp_ctrl);

/**
 * Checks the ROT_OWNER_AUTH_SLOT1_STATE OTP partition end state.
 *
 * @param otp_ctrl OTP controller interface.
 * @return OK_STATUS if the ROT_OWNER_AUTH_SLOT1_STATE partition is locked.
 */
status_t manuf_individualize_device_rot_owner_auth_slot1_state_check(
    const dif_otp_ctrl_t *otp_ctrl);

/**
 * Configures and locks the ROT_OWNER_AUTH_SLOT2_STATE OTP partition.
 *
 * The ROT_OWNER_AUTH_SLOT2_STATE partition contains the first stage
 * (ROM->ROM_EXT) secure boot public key validity states.
 *
 * @param otp_ctrl OTP controller instance.
 * @return OK_STATUS if the ROT_OWNER_AUTH_SLOT2_STATE partition has been
 * locked.
 */
OT_WARN_UNUSED_RESULT
status_t manuf_individualize_device_rot_owner_auth_slot2_state(
    const dif_otp_ctrl_t *otp_ctrl);

/**
 * Checks the ROT_OWNER_AUTH_SLOT2_STATE OTP partition end state.
 *
 * @param otp_ctrl OTP controller interface.
 * @return OK_STATUS if the ROT_OWNER_AUTH_SLOT2_STATE partition is locked.
 */
status_t manuf_individualize_device_rot_owner_auth_slot2_state_check(
    const dif_otp_ctrl_t *otp_ctrl);

/**
 * Configures and locks the ROT_OWNER_AUTH_SLOT3_STATE OTP partition.
 *
 * The ROT_OWNER_AUTH_SLOT3_STATE partition contains the first stage
 * (ROM->ROM_EXT) secure boot public key validity states.
 *
 * @param otp_ctrl OTP controller instance.
 * @return OK_STATUS if the ROT_OWNER_AUTH_SLOT3_STATE partition has been
 * locked.
 */
OT_WARN_UNUSED_RESULT
status_t manuf_individualize_device_rot_owner_auth_slot3_state(
    const dif_otp_ctrl_t *otp_ctrl);

/**
 * Checks the ROT_OWNER_AUTH_SLOT3_STATE OTP partition end state.
 *
 * @param otp_ctrl OTP controller interface.
 * @return OK_STATUS if the ROT_OWNER_AUTH_SLOT3_STATE partition is locked.
 */
status_t manuf_individualize_device_rot_owner_auth_slot3_state_check(
    const dif_otp_ctrl_t *otp_ctrl);

#endif  // OPENTITAN_SW_DEVICE_SILICON_CREATOR_MANUF_LIB_INDIVIDUALIZE_SW_CFG_H_
