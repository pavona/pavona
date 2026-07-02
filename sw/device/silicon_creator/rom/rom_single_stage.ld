/* Copyright lowRISC contributors (OpenTitan project). */
/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * Linker script for the Pavona single-stage ROM.
 *
 * Portions of this file are Ibex-specific.
 */

INCLUDE OPENTITAN_TOP_MEMORY_LD
INCLUDE sw/device/silicon_creator/rom/rom_common.ld

/*
 * TODO: This check may have to moved to a different included script if a future
 * design includes a either dual-ROM with onboard flash, or single-ROM without
 * onboard flash.
 */
ASSERT((_rom_ext_virtual_size <= (LENGTH(eflash) / 2)),
  "Error: rom ext flash is bigger than slot.");

/**
 * The boot address, which indicates the location of the initial interrupt
 * vector.
 */
_rom_boot_address = ORIGIN(rom);
