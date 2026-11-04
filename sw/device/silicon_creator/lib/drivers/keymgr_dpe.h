// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_SILICON_CREATOR_LIB_DRIVERS_KEYMGR_DPE_H_
#define OPENTITAN_SW_DEVICE_SILICON_CREATOR_LIB_DRIVERS_KEYMGR_DPE_H_

#include <stddef.h>
#include <stdint.h>

#include "sw/device/silicon_creator/lib/error.h"
#include "sw/device/silicon_creator/lib/keymgr_dpe_binding_value.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Key Manager states.
 */
typedef enum sc_keymgr_dpe_state {
  /**
   * Key manager control is still in reset. Please wait for initialization
   * complete before issuing operations.
   */
  kScKeymgrDpeStateReset,
  /**
   * Key manager control has finished latching OTP root key and will now accept
   * software commands.
   */
  kScKeymgrDpeStateAvailable,
  /**
   * Key manager currently disabled. Please reset the key manager. Sideload keys
   * are still valid.
   */
  kScKeymgrDpeStateDisabled,
  /**
   * Key manager currently invalid. Please reset the key manager. Sideload keys
   * are no longer valid.
   */
  kScKeymgrDpeStateInvalid,
  /**
   * This is not a state - it is the total number of states.
   */
  kScKeymgrDpeStateNumStates,
} sc_keymgr_dpe_state_t;

enum {
  /**
   * Number of 32-bit words for the salt.
   */
  kScKeymgrDpeSaltNumWords = 8,
};

/**
 * Data used to differentiate a generated keymgr_dpe key.
 */
typedef struct sc_keymgr_dpe_diversification {
  /**
   * Salt value to use for key generation.
   */
  uint32_t salt[kScKeymgrDpeSaltNumWords];
  /**
   * Version for key generation (anti-rollback protection).
   */
  uint32_t version;
} sc_keymgr_dpe_diversification_t;

/**
 * Destination for key generation.
 */
typedef enum sc_keymgr_dpe_dest {
  kScKeymgrDpeDestNone = 0,
  kScKeymgrDpeDestAes = 1,
  kScKeymgrDpeDestKmac = 2,
  kScKeymgrDpeDestAcc = 3,
} sc_keymgr_dpe_dest_t;

/**
 * Source for key generation and source/destination for advance operations.
 */
typedef enum sc_keymgr_dpe_slot {
  kScKeymgrDpeSlot0 = 0,
  kScKeymgrDpeSlot1 = 1,
  kScKeymgrDpeSlot2 = 2,
  kScKeymgrDpeSlot3 = 3,

  // Slot usage conventions.
  kScKeymgrDpeSlotSealing = kScKeymgrDpeSlot0,
  kScKeymgrDpeSlotAttestation = kScKeymgrDpeSlot1,
  kScKeymgrDpeSlotAttestationSuccessor = kScKeymgrDpeSlot2,
} sc_keymgr_dpe_slot_t;

/**
 * The following constants represent the expected number of sec_mmio register
 * writes performed by functions in provided in this module. See
 * `SEC_MMIO_WRITE_INCREMENT()` for more details.
 *
 * Example:
 * ```
 *  sc_keymgr_dpe_sw_binding_set();
 *  SEC_MMIO_WRITE_INCREMENT(kScKeymgrDpeSecMmioSwBindingSet);
 * ```
 */
enum {
  kScKeymgrDpeSecMmioEntropyReseedIntervalSet = 1,
  kScKeymgrDpeSecMmioSwBindingSet = 9,
  kScKeymgrDpeSecMmioMaxVerSet = 2,
};

/**
 * Sets the key manager software binding inputs.
 *
 * This function also clears and caches the value of the `SW_BINDING_REGWEN`
 * register in the `sec_mmio` expectations table. This register is unlocked
 * after a successful transaction. It is recommended to call
 * `sc_keymgr_dpe_sw_binding_unlock_wait()` after initiating a transition to
 * update its value in the `sec_mmio` expectations table.
 *
 * @param binding_value Software binding value.
 */
void sc_keymgr_dpe_sw_binding_set(
    const keymgr_dpe_binding_value_t *binding_value);

/**
 * Blocks until the software binding registers are unlocked.
 *
 * This function can be called after `sc_keymgr_dpe_advance_state()` to wait for
 * the software binding registers to become available for writing and to update
 * the cached value of `SW_BINDING_REGWEN` register in the `sec_mmio`
 * expectations table.
 */
void sc_keymgr_dpe_sw_binding_unlock_wait(void);

/**
 * Sets the max key version.
 *
 * @param max_key_ver Maximum key version associated with the Silicon Owner
 * key manager stage.
 */
void sc_keymgr_dpe_max_ver_set(uint32_t max_key_ver);

/**
 * Blocks until the max key version registers are unlocked.
 *
 * This function can be called after `sc_keymgr_dpe_advance_state()` to wait for
 * the software binding registers to become available for writing and to update
 * the cached value of `MAX_KEY_VER_REGWEN` register in the `sec_mmio`
 * expectations table.
 */
void sc_keymgr_dpe_max_ver_unlock_wait(void);

/**
 * Sets the entropy reseed interval of the key manager.
 *
 * @param entropy_reseed_interval Number of key manager cycles before the
 * entropy is reseeded.
 * @return The result of the operation.
 */
void sc_keymgr_dpe_entropy_reseed_interval_set(
    uint16_t entropy_reseed_interval);

/**
 * Advances the state of the key manager.
 *
 * The `sc_keymgr_dpe_state_check()` function must be called before this
 * function to ensure the key manager is in the expected state and ready to
 * receive op commands.
 *
 * The caller is responsible for calling the `sc_keymgr_dpe_state_check()` at a
 * later time to ensure the advance transition completed without errors.
 *
 * Note: It is recommended to call `sc_keymgr_dpe_sw_binding_unlock_wait()`
 * before the secure mmio `sec_mmio_check_values()` function to make sure the
 * value of the `SW_BINDING_REGWEN` register is updated in the secure mmio
 * expectations table.
 *
 * @param src_slot: The key manager DPE slot to advance from.
 * @param dest_slot: The key manager DPE slot to write the derived secret.
 * @param allow_child: Whether to allow further ADVANCE operations from the
 * derived secret.
 * @param exportable: Whether to allow the derived secret to be exported from
 * the destination slot.
 * @param retain_parent: Whether to allow the derived secret to derive children
 * in other slots without erasing itself.
 * @param sw_binding_only: Whether to use ONLY the software binding value to
 * derive the secret to the destination slot.
 */
rom_error_t sc_keymgr_dpe_advance_state(sc_keymgr_dpe_slot_t src_slot,
                                        sc_keymgr_dpe_slot_t dest_slot,
                                        hardened_bool_t allow_child,
                                        hardened_bool_t exportable,
                                        hardened_bool_t retain_parent,
                                        hardened_bool_t sw_binding_only);

/**
 * Checks the state of the key manager.
 *
 * @param expected_state Expected key manager state.
 * @return `kErrorOk` if the key manager is in `expected_state` and the status
 * is idle or success; otherwise returns `kErrorKeymgrInternal`.
 */
OT_WARN_UNUSED_RESULT
rom_error_t sc_keymgr_dpe_state_check(sc_keymgr_dpe_state_t expected_state);

/**
 * Keymgr ECC key generation descriptor.
 */
typedef struct sc_keymgr_dpe_ecc_key {
  /**
   * Keymgr slot number. By convention, different slots are used for
   * attestation and sealing keys.
   *
   * Attestation keys are derived from keymgr_dpe state that changes when
   * ROM_EXT or Owner firmware is updated, while Sealing keys remain stable as
   * long as a device remains under the same ownership and hardware lifecycle
   * state.
   */
  sc_keymgr_dpe_slot_t slot;
  /**
   * Index into the kFlashCtrlInfoPageAttestationKeySeeds flash info page that
   * holds a seed for generating the ECC key pair.
   */
  uint32_t keygen_seed_idx;
  /**
   * Pointer to the keymgr_dpe diversifier that is used when actuating the
   * keymgr_dpe's "output-generate" function to generate another ECC keygen seed
   * that will be sideloaded to ACC.
   */
  const sc_keymgr_dpe_diversification_t *keymgr_diversifier;
} sc_keymgr_dpe_ecc_key_t;

/**
 * Generate a key manager key and sideload to the requested block.
 *
 * Calls the key manager to sideload a key into the requested hardware block and
 * waits until the operation is complete before returning. Can sideload an
 * attestation or sealing key based on user input.
 *
 * @param src_slot: The key manager DPE slot to sideload the key from.
 * @param destination: Hardware destination for key material.
 * @param diversification Diversification input for the key derivation.
 * @return OK or error.
 */

OT_WARN_UNUSED_RESULT
rom_error_t sc_keymgr_dpe_generate_key(
    sc_keymgr_dpe_slot_t src_slot, sc_keymgr_dpe_dest_t destination,
    sc_keymgr_dpe_diversification_t diversification);

/**
 * Clear the requested sideloaded key slot.
 *
 * The entropy complex needs to be initialized before calling this function, so
 * that keymgr_dpe can use it to clear the slot.
 *
 * @param destination: Hardware block to clear key material.
 * @return OK or error.
 */
OT_WARN_UNUSED_RESULT
rom_error_t sc_keymgr_dpe_sideload_clear(sc_keymgr_dpe_dest_t destination);

/**
 * Generate a key manager key and sideload to the ACC block.
 *
 * Calls the key manager to sideload a key into the ACC hardware block and
 * waits until the operation is complete before returning. Can sideload an
 * attestation or sealing key based on user input.
 *
 * @param src_slot: The key manager DPE slot to sideload the key from.
 * @param diversification Diversification input for the key derivation.
 * @return OK or error.
 */
OT_WARN_UNUSED_RESULT
inline rom_error_t sc_keymgr_dpe_generate_key_acc(
    sc_keymgr_dpe_slot_t src_slot,
    sc_keymgr_dpe_diversification_t diversification) {
  return sc_keymgr_dpe_generate_key(src_slot, kScKeymgrDpeDestAcc,
                                    diversification);
}

/**
 * Clear ACC's sideloaded key slot.
 *
 * The entropy complex needs to be initialized before calling this function, so
 * that keymgr_dpe can use it to clear the slot.
 *
 * @return OK or error.
 */
OT_WARN_UNUSED_RESULT
inline rom_error_t sc_keymgr_dpe_sideload_clear_acc(void) {
  return sc_keymgr_dpe_sideload_clear(kScKeymgrDpeDestAcc);
}

/**
 * Sets the binding registers and advances the keymgr_dpe.
 *
 * @param src_slot: The key manager DPE slot to advance from.
 * @param dest_slot: The key manager DPE slot to write the derived secret.
 * @param allow_child: Whether to allow further ADVANCE operations from the
 * derived secret.
 * @param exportable: Whether to allow the derived secret to be exported from
 * the destination slot.
 * @param retain_parent: Whether to allow the derived secret to derive children
 * in other slots without erasing itself.
 * @param sw_binding_only: Whether to use ONLY the software binding value to
 * derive the secret to the destination slot.
 * @param binding The software binding value to use.
 * @param max_key_version Maximum key version associated with the target stage.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
rom_error_t sc_keymgr_dpe_advance(
    sc_keymgr_dpe_slot_t src_slot, sc_keymgr_dpe_slot_t dest_slot,
    hardened_bool_t allow_child, hardened_bool_t exportable,
    hardened_bool_t retain_parent, hardened_bool_t sw_binding_only,
    keymgr_dpe_binding_value_t *binding, uint32_t max_key_version);

/**
 * Disable the keymgr_dpe controller.
 */
void sc_keymgr_dpe_disable(void);

#ifdef __cplusplus
}
#endif

#endif  // OPENTITAN_SW_DEVICE_SILICON_CREATOR_LIB_DRIVERS_KEYMGR_DPE_H_
