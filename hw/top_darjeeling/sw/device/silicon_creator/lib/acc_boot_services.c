// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/base/macros.h"
#include "sw/device/lib/base/memory.h"
#include "sw/device/silicon_creator/lib/attestation.h"
#include "sw/device/silicon_creator/lib/drivers/flash_ctrl.h"

OT_WARN_UNUSED_RESULT
rom_error_t acc_boot_attestation_keygen_seed(uint32_t seed_idx,
                                             uint32_t *seed) {
  // TODO: Load the seed from OTP.
  //
  // Temporarily load all-zeroes to the buffer to keep deterministic.
  memset(seed, 0, kAttestationSeedBytes);

  return kErrorOk;
}
