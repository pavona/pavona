// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/silicon_creator/rom/mock_boot_policy_ptrs.h"

namespace rom_test {
extern "C" {
const manifest_t *boot_policy_manifest_get(slot_t slot) {
  if (slot == kSlotA) {
    return MockBootPolicyPtrs::Instance().ManifestA();
  } else {
    return MockBootPolicyPtrs::Instance().ManifestB();
  }
}
}  // extern "C"
}  // namespace rom_test
