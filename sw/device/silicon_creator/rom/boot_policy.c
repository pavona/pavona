// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/silicon_creator/rom/boot_policy.h"

#include "sw/device/lib/base/hardened.h"
#include "sw/device/silicon_creator/lib/base/chip.h"
#include "sw/device/silicon_creator/lib/drivers/lifecycle.h"
#include "sw/device/silicon_creator/lib/error.h"
#include "sw/device/silicon_creator/lib/shutdown.h"
#include "sw/device/silicon_creator/rom/boot_policy_ptrs.h"

#ifdef HAS_FLASH_CTRL
#include "sw/device/silicon_creator/lib/boot_data.h"
#endif

boot_policy_manifests_t boot_policy_manifests_get(void) {
  const manifest_t *slot_a = boot_policy_manifest_get(kSlotA);
  const manifest_t *slot_b = boot_policy_manifest_get(kSlotB);
  // Choose the ROM_EXT with the greater security version.
  // - If equal, choose the ROM_EXT with the greater major version.
  // - If equal, choose the ROM_EXT with the greater minor version,
  // - If equal, prefer slot A.
  //
  // The use of gotos below gives a 30% reduction in the size of
  // this function in the ROM (70 bytes vs. 102 bytes).
  if (slot_a->security_version > slot_b->security_version) {
    goto a_first;
  } else if (slot_a->security_version < slot_b->security_version) {
    goto b_first;
  } else if (slot_a->version_major > slot_b->version_major) {
    goto a_first;
  } else if (slot_a->version_major < slot_b->version_major) {
    goto b_first;
  } else if (slot_a->version_minor >= slot_b->version_minor) {
    goto a_first;
  } else {
    goto b_first;
  }
b_first:
  return (boot_policy_manifests_t){{slot_b, slot_a}};
a_first:
  return (boot_policy_manifests_t){{slot_a, slot_b}};
}

static rom_error_t check_manifest(const manifest_t *manifest) {
  if (manifest->identifier != CHIP_ROM_EXT_IDENTIFIER) {
    return kErrorBootPolicyBadIdentifier;
  }
  if (manifest->length < CHIP_ROM_EXT_SIZE_MIN ||
      manifest->length > CHIP_ROM_EXT_RESIZABLE_SIZE_MAX) {
    return kErrorBootPolicyBadLength;
  }
  RETURN_IF_ERROR(manifest_check(manifest));
  return kErrorOk;
}

rom_error_t boot_policy_manifest_check(const manifest_t *manifest,
                                       const boot_data_t *boot_data) {
  RETURN_IF_ERROR(check_manifest(manifest));
  // The boot_data structure on designs with onboard flash contain a minimum
  // security version for ROM_EXT.
  if (launder32(manifest->security_version) >=
      boot_data->min_security_version_rom_ext) {
    HARDENED_CHECK_GE(manifest->security_version,
                      boot_data->min_security_version_rom_ext);
    return kErrorOk;
  }
  return kErrorBootPolicyRollback;
}
