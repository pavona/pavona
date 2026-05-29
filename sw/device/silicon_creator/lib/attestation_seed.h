// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_SILICON_CREATOR_LIB_ATTESTATION_SEED_H_
#define OPENTITAN_SW_DEVICE_SILICON_CREATOR_LIB_ATTESTATION_SEED_H_

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif  // __cplusplus
/**
 * Retrieve an additional attestation key generation seed.
 *
 * This function retrieves an optional, secondary key seed to be loaded it into
 * the ACC data memory (DMEM). This seed complements the primary seed
 * side-loaded from the `keymgr` used by ACC for generating the attestation
 * key.
 *
 * This implementation is **top-specific** because the seed's origin, storage
 * location and availability vary across OpenTitan hardware configurations.
 *
 * Tops that do not require or provide a secondary seed must indicate this by
 * setting the `seed` parameter to zero and returning 'kErrorOk'.
 *
 * @param seed_idx The index of the seed, if multiple are stored.
 * @param seed The retrieved 32-bit seed. Set to zero if not provided.
 * @return An `error.h` defined error if retrieval fails. Returns `kErrorOk`
 * if the seed is successfully retrieved, or if no seed is required/available
 * by the hardware top (in which case `seed` must be zeroed).
 */
OT_WARN_UNUSED_RESULT
rom_error_t acc_boot_attestation_keygen_seed(uint32_t seed_idx, uint32_t *seed);

#ifdef __cplusplus
}  // extern "C"
#endif  // __cplusplus

#endif  // OPENTITAN_SW_DEVICE_SILICON_CREATOR_LIB_ATTESTATION_SEED_H_
