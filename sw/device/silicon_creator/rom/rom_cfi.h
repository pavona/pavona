// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_SILICON_CREATOR_ROM_ROM_CFI_H_
#define OPENTITAN_SW_DEVICE_SILICON_CREATOR_ROM_ROM_CFI_H_

#include "sw/device/silicon_creator/lib/cfi.h"

#ifdef __cplusplus
extern "C" {
#endif  // __cplusplus

// Control-flow integrity validation for metal ROM execution.

/**
 * Table of forward branch Control Flow Integrity (CFI) counters.
 *
 * Columns: Name, Initital Value.
 *
 * Each counter is indexed by Name. The Initial Value is used to initialize the
 * counters with unique values with a good hamming distance. The values are
 * restricted to 11-bit to be able use immediate load instructions.

 * Encoding generated with
 * $ ./util/design/sparse-fsm-encode.py -d 6 -m 9 -n 11 -s 1630646358
 *
 * Minimum Hamming distance: 6
 * Maximum Hamming distance: 8
 * Minimum Hamming weight: 4
 * Maximum Hamming weight: 8
 */
// clang-format off
#define ROM_CFI_FUNC_COUNTERS_TABLE(X) \
  X(kCfiRomMain,            0x382) \
  X(kCfiRomInit,            0x4ab) \
  X(kCfiRomBootSecondRom,   0x695) \
  X(kCfiRomSecondRomPatch,  0x565) \
  X(kCfiRomTryBootRomExt,   0x1df) \
  X(kCfiRomVerifyRomExt,    0x0f0) \
  X(kCfiRomBootRomExt,      0x518) \
  X(kCfiRomConfigureRomExt, 0x22c) \
  X(kCfiRomPreBootCheck,    0x289)
// clang-format on

// Define constant values required by the CFI counter macros.
CFI_DEFINE_CONSTANTS(rom_counters, ROM_CFI_FUNC_COUNTERS_TABLE);

#ifdef __cplusplus
}  // extern "C"
#endif  // __cplusplus

#endif  // OPENTITAN_SW_DEVICE_SILICON_CREATOR_ROM_ROM_CFI_H_
