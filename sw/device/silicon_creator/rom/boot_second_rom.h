// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_SILICON_CREATOR_ROM_BOOT_SECOND_ROM_H_
#define OPENTITAN_SW_DEVICE_SILICON_CREATOR_ROM_BOOT_SECOND_ROM_H_

#include "sw/device/silicon_creator/lib/error.h"

#ifdef __cplusplus
extern "C" {
#endif  // __cplusplus

/**
 * Attempts to boot second stage ROM in dual-stage ROM designs.
 *
 * Note: This function should not return under normal conditions. Any returns
 * from this function must result in shutdown.
 */
OT_WARN_UNUSED_RESULT
rom_error_t rom_boot_second_rom(void);

#ifdef __cplusplus
}  // extern "C"
#endif  // __cplusplus

#endif  // OPENTITAN_SW_DEVICE_SILICON_CREATOR_ROM_BOOT_SECOND_ROM_H_
