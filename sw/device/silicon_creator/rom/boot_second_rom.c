// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hw/top/dt/rom_ctrl.h"
#include "sw/device/lib/base/csr.h"
#include "sw/device/lib/base/memory.h"
#include "sw/device/silicon_creator/lib/base/boot_measurements.h"
#include "sw/device/silicon_creator/lib/drivers/epmp.h"
#include "sw/device/silicon_creator/lib/rom_patch.h"
#include "sw/device/silicon_creator/rom/boot_policy.h"
#include "sw/device/silicon_creator/rom/rom_cfi.h"

// This symbol is defined in `rom_dual_stage.ld` and describes the location of
// the second ROM entry point.
extern char _second_rom_boot_address[];

/**
 * Patches second ROM code with an OTP ROM patch.
 *
 * If a patch is successfully applied, the patch digest
 * is stored into the boot measurement section.
 *
 * @return Result of the second ROM patching.
 */
static rom_error_t second_rom_patch(void) {
  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomSecondRomPatch, 1);
  rom_patch_info_t latest_patch = rom_patch_latest(NULL);

  do {
    /* We could not find a latest patch, we're done */
    if (latest_patch.addr == kRomPatchInvalidAddr) {
      break;
    }

    hmac_digest_t patch_digest;
    rom_error_t error = rom_patch_apply(&latest_patch, &patch_digest);

    /* The latest patch could not be applied, let's try the next one */
    if (launder32(error) != kErrorOk) {
      latest_patch = rom_patch_latest(&latest_patch);
      continue;
    }
    HARDENED_CHECK_EQ(error, kErrorOk);

    /* Latest patch applied, let's store the patch measurement */
    static_assert(sizeof(boot_measurements.rom_patch) == sizeof(patch_digest),
                  "Unexpected ROM patch digest size.");
    memcpy(&boot_measurements.rom_patch, &patch_digest,
           sizeof(boot_measurements.rom_patch));

  } while (false);

  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomSecondRomPatch, 2);
  return kErrorOk;
}

/**
 * Attempts to boot the second-stage ROM in dual-ROM designs.
 *
 * Note: This function should not return under normal conditions. Any returns
 * from this function must result in shutdown.
 *
 * @return rom_error_t Result of the operation.
 */
OT_WARN_UNUSED_RESULT
rom_error_t rom_boot_second_rom(void) {
  CFI_FUNC_COUNTER_PREPCALL(rom_counters, kCfiRomBootSecondRom, 1,
                            kCfiRomSecondRomPatch);
  // Apply the second ROM patch if we have one, and then boot the second ROM.
  HARDENED_RETURN_IF_ERROR(second_rom_patch());
  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomBootSecondRom, 3);
  CFI_FUNC_COUNTER_CHECK(rom_counters, kCfiRomSecondRomPatch, 3);

  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomBootSecondRom, 4);
  // TODO: Don't hard-code the offset of the entry point within the second ROM
  // binary.
  uintptr_t _entry_point = ((uintptr_t)_second_rom_boot_address) + 0x180;

  // Configure ePMP for the second stage ROM
  //
  // ePMP for the second ROM patch was already configured in `second_rom_patch`.
  uint32_t rom_ctrl1_base =
      dt_rom_ctrl_memory_base(kDtRomCtrl1, kDtRomCtrlMemoryRom);
  uint32_t rom_ctrl1_size =
      dt_rom_ctrl_memory_size(kDtRomCtrl1, kDtRomCtrlMemoryRom);
  const epmp_region_t second_rom_text = {
      .start = _entry_point, .end = rom_ctrl1_base + rom_ctrl1_size};
  const epmp_region_t second_rom = {.start = rom_ctrl1_base,
                                    .end = rom_ctrl1_base + rom_ctrl1_size};
  epmp_prepare_boot_stage(second_rom_text, second_rom);

  // Check the ePMP state again
  HARDENED_RETURN_IF_ERROR(epmp_state_check());
  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomBootSecondRom, 5);

  // Re-initialize mtvec
  CSR_WRITE(CSR_REG_MTVEC, ((uintptr_t)_second_rom_boot_address) | 1);

  // Jump to the second rom entry point
  ((entry_point *)_entry_point)();
  return kErrorRomBootFailed;
}
