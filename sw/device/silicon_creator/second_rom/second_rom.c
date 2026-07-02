// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/silicon_creator/second_rom/second_rom.h"

#include <stdbool.h>
#include <stdint.h>

#include "sw/device/lib/arch/device.h"
#include "sw/device/lib/base/hardened.h"
#include "sw/device/silicon_creator/lib/base/sec_mmio.h"
#include "sw/device/silicon_creator/lib/base/static_critical_version.h"
#include "sw/device/silicon_creator/lib/dbg_print.h"
#include "sw/device/silicon_creator/lib/drivers/ast.h"
#include "sw/device/silicon_creator/lib/drivers/epmp.h"
#include "sw/device/silicon_creator/lib/drivers/lifecycle.h"
#include "sw/device/silicon_creator/lib/drivers/rnd.h"
#include "sw/device/silicon_creator/lib/drivers/watchdog.h"
#include "sw/device/silicon_creator/lib/epmp_state.h"
#include "sw/device/silicon_creator/lib/error.h"
#include "sw/device/silicon_creator/lib/manifest.h"
#include "sw/device/silicon_creator/lib/shutdown.h"
#include "sw/device/silicon_creator/rom/boot_rom_ext.h"
#include "sw/device/silicon_creator/rom/rom_cfi.h"
#include "sw/device/silicon_creator/second_rom/second_rom_epmp.h"

/**
 * Type alias for the ROM_EXT entry point.
 *
 * The entry point address obtained from the ROM_EXT manifest must be cast to a
 * pointer to this type before being called.
 */
typedef void rom_ext_entry_point(void);

// Life cycle state of the chip.
lifecycle_state_t lc_state = (lifecycle_state_t)0;

/**
 * Performs once-per-boot initialization of ROM modules and peripherals.
 */
OT_WARN_UNUSED_RESULT
static rom_error_t rom_init(void) {
  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomInit, 1);

  dbg_printf("Starting 2nd stage ROM\r\n");

  // Reset MMIO counters
  sec_mmio_next_stage_init();

  // Set static_critical region format version.
  static_critical_version = kStaticCriticalVersion1;

  // Update ePMP register configuration.
  epmp_advance_boot_stage();
  second_rom_epmp_state_init();
  HARDENED_RETURN_IF_ERROR(epmp_state_check());

  lc_state = lifecycle_state_get();

  // Re-initialize the watchdog timer.
  watchdog_init(lc_state);
  SEC_MMIO_WRITE_INCREMENT(kWatchdogSecMmioInit);

  // Check that AST is in the expected state.
  HARDENED_RETURN_IF_ERROR(ast_check(lc_state));

  // This function is a NOP unless ROM is built for an fpga.
  device_fpga_version_print();

  sec_mmio_check_values(rnd_uint32());
  sec_mmio_check_counters(/*expected_check_count=*/1);

  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomInit, 2);
  return kErrorOk;
}

/* Function that alerts to the UART we are waiting for a JTAG bootstrap, and
 * then busy waits to allow it to occur. This function never returns because we
 * expect the host performing the bootstrap to reset the chip afterwards.
 */
void wait_for_jtag_bootstrap(void) {
  dbg_printf("No valid ECDSA key found in CTN. Waiting for JTAG bootstrap.\n");
  while (true) {
  }
}

void second_rom_main(void) {
  CFI_FUNC_COUNTER_INIT(rom_counters, kCfiRomMain);

  CFI_FUNC_COUNTER_PREPCALL(rom_counters, kCfiRomMain, 1, kCfiRomInit);
  SHUTDOWN_IF_ERROR(rom_init());
  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomMain, 3);
  CFI_FUNC_COUNTER_CHECK(rom_counters, kCfiRomInit, 3);

  // `rom_try_boot_rom_ext` will not return unless there is an error.
  CFI_FUNC_COUNTER_PREPCALL(rom_counters, kCfiRomMain, 4, kCfiRomTryBootRomExt);
  shutdown_finalize(rom_try_boot_rom_ext(lc_state));
}
