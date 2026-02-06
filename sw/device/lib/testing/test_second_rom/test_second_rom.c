// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hw/top/dt/soc_proxy.h"
#include "sw/device/lib/arch/device.h"
#include "sw/device/lib/base/abs_mmio.h"
#include "sw/device/lib/base/bitfield.h"
#include "sw/device/lib/base/csr.h"
#include "sw/device/lib/base/mmio.h"
#include "sw/device/lib/dif/dif_base.h"
#include "sw/device/lib/dif/dif_gpio.h"
#include "sw/device/lib/dif/dif_rv_core_ibex.h"
#include "sw/device/lib/dif/dif_uart.h"
#include "sw/device/lib/runtime/hart.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/runtime/print_uart.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/status.h"
#include "sw/device/silicon_creator/lib/base/sec_mmio.h"
#include "sw/device/silicon_creator/lib/chip_info.h"
#include "sw/device/silicon_creator/lib/drivers/retention_sram.h"
#include "sw/device/silicon_creator/lib/manifest.h"

static const dt_rv_core_ibex_t kRvCoreIbexDt = kDtRvCoreIbex;

static const dt_uart_t kUart0Dt = kDtUart0;
static dif_uart_t uart0;

/* These symbols are defined in
 * `opentitan/sw/device/lib/testing/test_rom/test_rom.ld`, and describes the
 * location of the flash header and manifest.
 */
extern char _rom_ext_virtual_start_address[];
extern char _rom_ext_virtual_size[];
extern char _manifest_address[];

/**
 * Type alias for the OTTF entry point.
 *
 * The entry point address obtained from the OTTF manifest must be cast to a
 * pointer to this type before being called.
 */
typedef void ottf_entry_point(void);

static dif_rv_core_ibex_t ibex;

/**
 * Compute the virtual address corresponding to the physical address `lma_addr`.
 *
 * @param manifest Pointer to the current manifest.
 * @param lma_addr Load address or physical address.
 * @return the computed virtual address.
 */
static inline uintptr_t rom_ext_vma_get(const manifest_t *manifest,
                                        uintptr_t lma_addr) {
  return (lma_addr - (uintptr_t)manifest +
          (uintptr_t)_rom_ext_virtual_start_address);
}

// `test_in_rom = True` tests can override this symbol to provide their own
// rom tests. By default, it simply jumps into the OTTF's flash.
OT_WEAK
bool second_rom_test_main(void) {
  // Setup the UART for printing messages to the console.
  if (kDeviceType != kDeviceSimDV) {
    CHECK_DIF_OK(dif_uart_init_from_dt(kUart0Dt, &uart0));
    base_uart_stdout(&uart0);
  }

  // Print the chip version information
  LOG_INFO("kChipInfo: scm_revision=%x", kChipInfo.scm_revision);

  // Print the FPGA version-id.
  // This is guaranteed to be zero on all non-FPGA implementations.
  dif_rv_core_ibex_fpga_info_t fpga;
  CHECK_DIF_OK(dif_rv_core_ibex_init_from_dt(kRvCoreIbexDt, &ibex));
  CHECK_DIF_OK(dif_rv_core_ibex_read_fpga_info(&ibex, &fpga));
  if (fpga != 0) {
    LOG_INFO("TestSecondROM:%08x", fpga);
  }

  const manifest_t *manifest = (const manifest_t *)_manifest_address;

  uintptr_t entry_point = manifest_entry_point_get(manifest);
  // Enable address translation if manifest says to
  if (manifest->address_translation == kHardenedBoolTrue) {
    dif_rv_core_ibex_addr_translation_mapping_t addr_map = {
        .matching_addr = (uintptr_t)_rom_ext_virtual_start_address,
        .remap_addr = (uintptr_t)manifest,
        .size = (size_t)_rom_ext_virtual_size,
    };
    CHECK_DIF_OK(dif_rv_core_ibex_configure_addr_translation(
        &ibex, kDifRvCoreIbexAddrTranslationSlot_0,
        kDifRvCoreIbexAddrTranslationDBus, addr_map));
    CHECK_DIF_OK(dif_rv_core_ibex_configure_addr_translation(
        &ibex, kDifRvCoreIbexAddrTranslationSlot_0,
        kDifRvCoreIbexAddrTranslationIBus, addr_map));
    CHECK_DIF_OK(dif_rv_core_ibex_enable_addr_translation(
        &ibex, kDifRvCoreIbexAddrTranslationSlot_0,
        kDifRvCoreIbexAddrTranslationDBus));
    CHECK_DIF_OK(dif_rv_core_ibex_enable_addr_translation(
        &ibex, kDifRvCoreIbexAddrTranslationSlot_0,
        kDifRvCoreIbexAddrTranslationIBus));
    entry_point = rom_ext_vma_get(manifest, entry_point);
  }

  // Jump to the OTTF in SRAM. Within the SRAM binary, it is the responsibily
  // of the OTTF to set up its own stack, and to never return.
  LOG_INFO("Test Second ROM complete, jumping to SRAM (addr: %x)!",
           entry_point);
  ((ottf_entry_point *)entry_point)();

  // If the flash image returns, we should abort anyway.
  abort();
}

void _second_rom_boot_start(void) {
  test_status_set(kTestStatusInBootRom);
  test_status_set(second_rom_test_main() ? kTestStatusPassed
                                         : kTestStatusFailed);

  abort();
}
