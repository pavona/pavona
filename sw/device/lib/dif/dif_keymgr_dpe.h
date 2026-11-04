// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_LIB_DIF_DIF_KEYMGR_DPE_H_
#define OPENTITAN_SW_DEVICE_LIB_DIF_DIF_KEYMGR_DPE_H_

/**
 * @file
 * @brief <a href="/book/hw/ip/keymgr_dpe/">Key Manager DPE</a> Device Interface
 * Functions
 */

#include <stdint.h>

#include "sw/device/lib/base/macros.h"
#include "sw/device/lib/base/mmio.h"
#include "sw/device/lib/dif/dif_base.h"

#include "sw/device/lib/dif/autogen/dif_keymgr_dpe_autogen.h"

#ifdef __cplusplus
extern "C" {
#endif  // __cplusplus

/**
 * A typical usage of this library during different secure boot
 * stages is as follows:
 *
 * - In ROM:
 *   - Create a new handle: `dif_keymgr_dpe_init()`.
 *   - Initialize state: `dif_keymgr_dpe_initialize()`,
 *   `dif_keymgr_dpe_get_status_codes()`, `dif_keymgr_dpe_get_state()`.
 *   - Advance state: `dif_keymgr_dpe_advance_state()`,
 *     `dif_keymgr_dpe_get_status_codes()`, `dif_keymgr_dpe_get_state()`.
 * - In subsequent boot stages, i.e. ROM_EXT, BL0, kernel:
 *   - Create a new handle: `dif_keymgr_dpe_init()`.
 *   - Generate keys and/or identity seeds:
 *     `dif_keymgr_dpe_generate()`,
 *     dif_keymgr_dpe_get_status_codes()`.
 *   - Read output (if applicable): `dif_keymgr_dpe_read_output()`.
 *   - Advance state: `dif_keymgr_dpe_advance_state()`,
 *     `dif_keymgr_dpe_get_status_codes()`, `dif_keymgr_dpe_get_state()`.
 */

/**
 * Enumeration for side load slot clearing.
 */
typedef enum dif_keymgr_sideload_clr {
  kDifKeymgrDpeSideLoadClearNone = 0,
  kDifKeymgrDpeSideLoadClearAes = 1,
  kDifKeymgrDpeSideLoadClearKmac = 2,
  kDifKeymgrDpeSideLoadClearAcc = 3,
  // Using different value than those enumerated above should clear all slots,
  // so we can use the mask value of this field to denote ALL case. This was
  // we can statically assert this value on the .c side of this DIF.
  kDifKeymgrDpeSideLoadClearAll = 7,
} dif_keymgr_sideload_clr_t;

/**
 * SW-visible key manager DPE states.
 *
 * Key manager RTL has more than 4 finite state machine (FSM) states, but it
 * simply truncates the reported state into four states given below. The reason
 * behind this truncation is that FSM lingers on some states temporarily (i.e.
 * few clock cycles) and the transition into the next state does not require
 * further invocation.
 *
 * From SW point of view, key manager FSM transitions follow a sequence
 * sequential manner and these transitions are irreversible until a power cycle.
 */
typedef enum dif_keymgr_dpe_state {
  kDifKeymgrDpeStateReset = 0,
  kDifKeymgrDpeStateAvailable = 1,
  kDifKeymgrDpeStateDisabled = 2,
  kDifKeymgrDpeStateInvalid = 3
} dif_keymgr_dpe_state_t;

/**
 * Source for key generation and source/destination for advance operations.
 */
enum {
  kDifKeymgrDpeSlot0 = 0,
  kDifKeymgrDpeSlot1 = 1,
  kDifKeymgrDpeSlot2 = 2,
  kDifKeymgrDpeSlot3 = 3,

  // Slot usage conventions.
  kDifKeymgrDpeSlotSealing = kDifKeymgrDpeSlot0,
  kDifKeymgrDpeSlotAttestation = kDifKeymgrDpeSlot1,
  kDifKeymgrDpeSlotAttestationSuccessor = kDifKeymgrDpeSlot2,
};

/**
 * Input parameters for advancing a DPE context/slot.
 */
typedef struct dif_keymgr_dpe_advance_params {
  /**
   * This value is used by key manager as input to DICE computation and can be
   * either a value that represents the measurement of a boot stage or simply a
   * tag from a manifest.
   */
  uint32_t binding_value[8];

  /**
   * Maximum allowed version for keys to be generated at a state. This value is
   * stored inside keymgr slot so that it can later be compared against the
   * `key_version` input provided along with generation request.
   */
  uint32_t max_key_version;

  /**
   * The source slot to be used as parent DPE context.
   */
  uint32_t slot_src_sel;

  /**
   * The destination slot which recieves the derived child DPE context.
   */
  uint32_t slot_dst_sel;

  /**
   * The slot policy bits for the derived child DPE context.
   */
  uint32_t slot_policy;
} dif_keymgr_dpe_advance_params_t;

/**
 * Key destination of a versioned key generation operation.
 *
 * Regardless of whether the generated key is SW or sideload key, HW uses a
 * unique diversification constant for each cryptographic use case. In the case
 * of sideload key, this enum value is also used to determine the target
 * peripheral port to which the generated key is loaded.
 */
typedef enum dif_keymgr_dpe_key_dest {
  /**
   * Diversify the generated key for no HW IP (and don't sideload it).
   */
  kDifKeymgrDpeKeyDestNone = 0,
  /**
   * Diversify the generated key for AES (and load it to AES peripheral port if
   * sideload key).
   */
  kDifKeymgrDpeKeyDestAes = 1,
  /**
   * Diversify the generated key for KMAC (and load it to KMAC peripheral port
   * if sideload key).
   */
  kDifKeymgrDpeKeyDestKmac = 2,
  /**
   * Diversify the generated key for ACC (and load it to ACC peripheral port
   * if sideload key).
   */
  kDifKeymgrDpeKeyDestAcc = 3,
} dif_keymgr_dpe_key_dest_t;

/**
 * Input parameters for advancing a DPE context/slot.
 */
typedef struct dif_keymgr_dpe_generate_params {
  /**
   * Destination for {AES, KMAC, ACC}, which is used for diversification.
   */
  dif_keymgr_dpe_key_dest_t key_dest;

  /**
   * Set to true, if this is a sideload key, otherwise set to false.
   */
  bool sideload_key;

  /**
   * Salt value used as input for key generation (i.e. becomes part of the
   * message payload sent to KMAC during computation).
   */
  uint32_t salt[8];

  /**
   * The key version used for generating versioned key. This value should not be
   * greater than the `max_key_version` value stored inside the source slot that
   * is used to generate the key.
   */
  uint32_t version;

  /**
   * The source slot from which the key is derived.
   */
  uint32_t slot_src_sel;
} dif_keymgr_dpe_generate_params_t;

/**
 * Input parameters for erasing a DPE context/slot.
 */
typedef struct dif_keymgr_dpe_erase_params {
  /**
   * Index for the slot to be erased.
   */
  uint32_t slot_dst_sel;
} dif_keymgr_dpe_erase_params_t;

/**
 * Useed to represent the output of SW generated key.
 */
typedef struct dif_keymgr_dpe_output {
  uint32_t value[2][8];
} dif_keymgr_dpe_output_t;

/**
 * Status code bit flags.
 *
 * See also: `dif_keymgr_dpe_status_codes_t`.
 */
typedef enum dif_keymgr_dpe_status_code {
  /**
   * Key manager is idle.
   */
  kDifKeymgrDpeStatusCodeIdle = 1 << 0,
  /**
   * Software invoked an invalid operation.
   */
  kDifKeymgrDpeStatusCodeInvalidOperation = 1 << 1,
  /**
   * Key manager issued invalid data to KMAC interface.
   */
  kDifKeymgrDpeStatusCodeInvalidKmacInput = 1 << 2,
  /**
   * Key manager encountered invalid state.
   */
  kDifKeymgrDpeStatusCodeInvalidState = 1 << 3,

} dif_keymgr_dpe_status_code_t;

/**
 * Define mask for error fields of `dif_keymgr_dpe_status_code_t`.
 */
static const bitfield_field32_t kIdleBitfield = (bitfield_field32_t){
    .mask = 0x1,
    .index = 0,
};

/**
 * Define mask for idle field of `dif_keymgr_dpe_status_code_t`.
 */
static const bitfield_field32_t kErrorBitfield = (bitfield_field32_t){
    .mask = 0x7,
    .index = 1,
};

/**
 * A bit vector of status codes.
 *
 * The following snippet can be used to check if key manager is idle:
 *
 *   `bool is_idle = (status_codes & kDifKeymgrDpeStatusCodeIdle);`
 *
 * The following snippet can be used to check if key manager is idle and
 * error-free:
 *
 *   `bool is_idle_and_ok = (status_codes == kDifKeymgrDpeStatusCodeIdle);`
 *
 * See also: `dif_keymgr_dpe_status_code_t`.
 */
typedef uint8_t dif_keymgr_dpe_status_codes_t;

/**
 * Initializes the keymgr_dpe block by performing an advance operation.
 *
 * The hardware does not have an explicit initialize command. Initialization is
 * simple the first advance call without software binding, max version or
 * policy registers set. Use this call before calling
 * `dif_keymgr_dpe_advance_state()`.
 *
 * @param keymgr_dpe A key manager handle.
 * @param slot_dst_sel Target slot used to latch the UDS key.
 * @return The result of the operation.
 */
dif_result_t dif_keymgr_dpe_initialize(const dif_keymgr_dpe_t *keymgr_dpe,
                                       uint32_t slot_dst_sel);

/**
 * Configure the entropy reseed interval (in cycles) for the key manager.
 *
 * @param keymgr_dpe A key manager handle.
 * @param interval The interval to set.
 * @return The result of the operation.
 */
dif_result_t dif_keymgr_dpe_set_entropy_reseed_interval(
    const dif_keymgr_dpe_t *keymgr_dpe, uint32_t interval);

/**
 * Advances a keymgr_dpe slot with given parameters.
 *
 * @param keymgr_dpe A key manager handle.
 * @param params Struct to pass inputs consumed by HW during advance.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
dif_result_t dif_keymgr_dpe_advance_state(
    const dif_keymgr_dpe_t *keymgr_dpe,
    const dif_keymgr_dpe_advance_params_t *params);

/**
 * Advances key manager state without setting any of the required inputs.
 *
 * This function instructs key manager to transition to the next stage, i.e.
 * Reset -> OtpRootKey -> CreatorRootKey -> OwnerIntermediateKey ->
 * OwnerRootKey -> Disabled. Once a state transition starts, key manager locks
 * the control register until the transition is complete. State transitions are
 * irreversible until a power cycle.
 *
 * This function does not have a `dif_keymgr_dpe_state_params_t` parameter since
 * these inputs are expected to be set before this function is called, e.g. when
 * the chip is using `rom` as opposed to `test_rom`. See
 * `dif_keymgr_dpe_advance_state()` if you need to set the binding value and max
 * key version before advancing the state.
 *
 * The entropy source must be initialized before this function is called. After
 * PoR, key manager is in Reset state with a non-deterministic secret value. The
 * first call to this function after PoR causes key manager to initialize its
 * secret value using the random values generated by the entropy source and
 * transition to Initialized state.
 *
 * This is an asynchronous function because key manager state transitions
 * involve KMAC operations that can take some time to complete. Clients must
 * check the status of key manager using `dif_keymgr_dpe_get_status_codes()`
 * before calling other functions in this library.
 *
 * @param keymgr A key manager handle.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
dif_result_t dif_keymgr_dpe_advance_state_raw(
    const dif_keymgr_dpe_t *keymgr_dpe);

/**
 * Erases a given keymgr_dpe slot.
 *
 * @param keymgr_dpe A key manager handle.
 * @param params A struct that selects the slot to be erased.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
dif_result_t dif_keymgr_dpe_erase_slot(
    const dif_keymgr_dpe_t *keymgr_dpe,
    const dif_keymgr_dpe_erase_params_t *params);

/**
 * Generate a SW/HW key from a chosen keymgr_dpe slot.
 *
 * @param keymgr_dpe A key manager handle.
 * @param params Struct to pass inputs consumed by HW generate operation.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
dif_result_t dif_keymgr_dpe_generate(
    const dif_keymgr_dpe_t *keymgr_dpe,
    const dif_keymgr_dpe_generate_params_t *params);

/**
 * Gets the operational status of keymgr_dpe.
 *
 * This function also clears OP_STATUS and ERR_CODE registers after reading
 * them.
 *
 * @param keymgr_dpe A key manager handle.
 * @param[out] status_codes Out-param for key manager status codes.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
dif_result_t dif_keymgr_dpe_get_status_codes(
    const dif_keymgr_dpe_t *keymgr_dpe,
    dif_keymgr_dpe_status_codes_t *status_codes);

/**
 * Gets the current state of key manager.
 *
 * @param keymgr_dpe A key manager handle.
 * @param[out] state Out-param for current key manager state.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
dif_result_t dif_keymgr_dpe_get_state(const dif_keymgr_dpe_t *keymgr_dpe,
                                      uint32_t *state);

/**
 * Starts or stops clearing of sideload keys.
 *
 * When a key is generated to be sideloaded to a hardware peripheral, key
 * manager stores it in a set of storage registers. Calling this function with
 * `state` set to `kDifKeymgrDpeToggleEnabled` causes key manager to clear
 * sideload keys continously using random values from the entropty source.
 * Callers must disable clearing of sideload keys to resume normal sideload
 * operation.
 *
 * @param keymgr A key manager handle.
 * @param state The new toggle state for sideload clear.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
dif_result_t dif_keymgr_dpe_sideload_clear_set_enabled(
    const dif_keymgr_dpe_t *keymgr_dpe, dif_toggle_t state);

/**
 * Checks whether clearing of sideload keys is enabled or not.
 *
 * @param keymgr A key manager handle.
 * @param[out] Out-param for the current toggle state of sideload clear.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
dif_result_t dif_keymgr_dpe_sideload_clear_get_enabled(
    const dif_keymgr_dpe_t *keymgr_dpe, dif_toggle_t *state);

/**
 * Read the value of SW generated key from its related CSR. It is the
 * responsibility of the caller to check that key generation has completed.
 *
 * @param keymgr_dpe A key manager handle.
 * @param[out] output The key value in two shares.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
dif_result_t dif_keymgr_dpe_read_output(const dif_keymgr_dpe_t *keymgr_dpe,
                                        dif_keymgr_dpe_output_t *output);

/**
 * Software binding value.
 */
typedef struct dif_keymgr_dpe_binding_value {
  uint32_t binding[8];
} dif_keymgr_dpe_binding_value_t;

/**
 * Reads the software binding value.
 *
 * @param keymgr A key manager handle.
 * @param[out] output Value read.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
dif_result_t dif_keymgr_dpe_read_binding(
    const dif_keymgr_dpe_t *keymgr_dpe, dif_keymgr_dpe_binding_value_t *output);

/**
 * Reads the max key version.
 *
 * @param keymgr A key manager handle.
 * @param[out] version The max key version.
 * @return dif_result_t
 */
OT_WARN_UNUSED_RESULT
dif_result_t dif_keymgr_dpe_read_max_key_version(
    const dif_keymgr_dpe_t *keymgr_dpe, uint32_t *version);

#ifdef __cplusplus
}  // extern "C"
#endif  // __cplusplus

#endif  // OPENTITAN_SW_DEVICE_LIB_DIF_DIF_KEYMGR_DPE_H_
