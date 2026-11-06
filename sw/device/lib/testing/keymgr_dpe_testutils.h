// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_LIB_TESTING_KEYMGR_DPE_TESTUTILS_H_
#define OPENTITAN_SW_DEVICE_LIB_TESTING_KEYMGR_DPE_TESTUTILS_H_

#include "sw/device/lib/base/status.h"
#include "sw/device/lib/dif/dif_keymgr_dpe.h"

#include "hw/top/keymgr_dpe_regs.h"  // Generated

/**
 * Software binding value for advancing to creator root key state.
 */
static const dif_keymgr_dpe_advance_params_t kCreatorParams = {
    .binding_value = {0xdc96c23d, 0xaf36e268, 0xcb68ff71, 0xe92f76e2,
                      0xb8a8379d, 0x426dc745, 0x19f5cff7, 0x4ec9c6d6},
    .max_key_version = 0x11,
    .slot_src_sel = 0x0,
    .slot_dst_sel = 0x0,
    .slot_policy = 0b1 << KEYMGR_DPE_SLOT_POLICY_ALLOW_CHILD_BIT,
};

/**
 * Software binding value for advancing to owner intermediate key state.
 */
static const dif_keymgr_dpe_advance_params_t kOwnerIntParams = {
    .binding_value = {0xe4987b39, 0x3f83d390, 0xc2f3bbaf, 0x3195dbfa,
                      0x23fb480c, 0xb012ae5e, 0xf1394d28, 0x1940ceeb},
    .max_key_version = 0xaa,
    .slot_src_sel = 0x0,
    .slot_dst_sel = 0x0,
    .slot_policy = 0b1 << KEYMGR_DPE_SLOT_POLICY_ALLOW_CHILD_BIT,
};

/**
 * Software binding value for advancing to owner root key state.
 *
 * Values were randomly generated.
 */
static const dif_keymgr_dpe_advance_params_t kOwnerRootKeyParams = {
    .binding_value =
        {
            0xd8a812ea,
            0xb6ebe129,
            0x217773d4,
            0x35b37c77,
            0xec8298be,
            0x1f7dec77,
            0x1803199e,
            0xa02ad81d,
        },
    .max_key_version = 0xaa,
    .slot_src_sel = 0x0,
    .slot_dst_sel = 0x0,
    .slot_policy = 0b1 << KEYMGR_DPE_SLOT_POLICY_ALLOW_CHILD_BIT,
};

/**
 * Locks OTP, restarts and initializes keymgr_dpe with UDS (a.k.a. the OTP
 * root key).
 *
 * This procedure essentially gets the keymgr_dpe into the stage where it
 * can be used for tests. An example is given below:
 * ```
 * void test_main(void) {
 *   // The following sets up keymgr_dpe and asks it to latch UDS.
 *   dif_keymgr_dpe_t keymgr_dpe;
 *   keymgr_dpe_testutils_startup(&keymgr_dpe);
 *
 *   // Remainder of test; optionally advance to CreatorRootKey state, generate
 *   // keys and identities.
 *   ...
 * }
 * ```
 *
 * @param[out] keymgr_dpe A key manager handle, may be uninitialized.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
status_t keymgr_dpe_testutils_startup(dif_keymgr_dpe_t *keymgr_dpe,
                                      uint32_t slot_dst_sel);

/**
 * Issues a keymgr_dpe advance operation and wait for it to complete.
 *
 * @param keymgr_dpe A key manager handle.
 * @param params Inputs that are consumed by HW during advance operation.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
status_t keymgr_dpe_testutils_advance_state(
    const dif_keymgr_dpe_t *keymgr_dpe,
    const dif_keymgr_dpe_advance_params_t *params);

/**
 * Issues a keymgr_dpe key generation operation and wait for it to complete.
 *
 * @param keymgr_dpe A key manager handle.
 * @param params Inputs that are consumed by HW during generate operation.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
status_t keymgr_dpe_testutils_generate(
    const dif_keymgr_dpe_t *keymgr_dpe,
    const dif_keymgr_dpe_generate_params_t *params,
    dif_keymgr_dpe_output_t *key);

/**
 * Erase a keymgr_dpe slot.
 *
 * @param keymgr_dpe A key manager handle.
 * @param params A wrapper struct that contains the destination slot to be
 * erased.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
status_t keymgr_dpe_testutils_erase_slot(
    const dif_keymgr_dpe_t *keymgr_dpe,
    const dif_keymgr_dpe_erase_params_t *params);

/**
 * Checks if the current keymgr_dpe state matches the expected state
 *
 * @param keymgr_dpe A key manager handle.
 * @param exp_state The expected key manager state.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
status_t keymgr_dpe_testutils_check_state(
    const dif_keymgr_dpe_t *keymgr_dpe, const dif_keymgr_dpe_state_t exp_state);

/**
 * Polling keymgr_dpe status until it becomes idle.
 * Fail the test if the status code indicates any error.
 *
 * @param keymgr_dpe A key manager handle.
 * @return The result of the operation.
 */
OT_WARN_UNUSED_RESULT
status_t keymgr_dpe_testutils_wait_for_operation_done(
    const dif_keymgr_dpe_t *keymgr_dpe);

#endif  // OPENTITAN_SW_DEVICE_LIB_TESTING_KEYMGR_DPE_TESTUTILS_H_
