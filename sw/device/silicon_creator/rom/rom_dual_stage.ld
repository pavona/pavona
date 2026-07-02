/* Copyright lowRISC contributors (OpenTitan project). */
/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * Linker script for the Pavona first-stage ROM.
 *
 * Portions of this file are Ibex-specific.
 */

INCLUDE OPENTITAN_TOP_MEMORY_LD
REGION_ALIAS("rom", rom0);
_rom_chip_info_start = _rom0_chip_info_start;

/**
 * The first ROM boot address, which indicates the location of the initial
 * interrupt vector.
 */
_rom_boot_address = ORIGIN(rom0);

/**
 * The second-stage ROM boot address.
 */
_second_rom_boot_address = ORIGIN(rom1);

INCLUDE sw/device/silicon_creator/rom/rom_common.ld
