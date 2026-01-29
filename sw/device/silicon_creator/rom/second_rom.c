// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/silicon_creator/rom/second_rom.h"

#include <stdbool.h>
#include <stdint.h>

#include "sw/device/lib/arch/device.h"
#include "sw/device/lib/base/bitfield.h"
#include "sw/device/lib/base/csr.h"
#include "sw/device/lib/base/hardened.h"
#include "sw/device/lib/base/macros.h"
#include "sw/device/lib/base/memory.h"
#include "sw/device/lib/base/stdasm.h"
#include "sw/device/silicon_creator/lib/acc_boot_services.h"
#include "sw/device/silicon_creator/lib/base/boot_measurements.h"
#include "sw/device/silicon_creator/lib/base/sec_mmio.h"
#include "sw/device/silicon_creator/lib/base/static_critical_version.h"
#include "sw/device/silicon_creator/lib/cfi.h"
#include "sw/device/silicon_creator/lib/dbg_print.h"
#include "sw/device/silicon_creator/lib/drivers/alert.h"
#include "sw/device/silicon_creator/lib/drivers/ast.h"
#include "sw/device/silicon_creator/lib/drivers/ibex.h"
#include "sw/device/silicon_creator/lib/drivers/keymgr_dpe.h"
#include "sw/device/silicon_creator/lib/drivers/lifecycle.h"
#include "sw/device/silicon_creator/lib/drivers/otp.h"
#include "sw/device/silicon_creator/lib/drivers/pinmux.h"
#include "sw/device/silicon_creator/lib/drivers/pwrmgr.h"
#include "sw/device/silicon_creator/lib/drivers/retention_sram.h"
#include "sw/device/silicon_creator/lib/drivers/rnd.h"
#include "sw/device/silicon_creator/lib/drivers/rstmgr.h"
#include "sw/device/silicon_creator/lib/drivers/uart.h"
#include "sw/device/silicon_creator/lib/drivers/watchdog.h"
#include "sw/device/silicon_creator/lib/epmp_state.h"
#include "sw/device/silicon_creator/lib/error.h"
#include "sw/device/silicon_creator/lib/manifest.h"
#include "sw/device/silicon_creator/lib/shutdown.h"
#include "sw/device/silicon_creator/lib/sigverify/sigverify.h"
#include "sw/device/silicon_creator/rom/second_rom_epmp.h"
#include "sw/device/silicon_creator/rom/sigverify_keys_ecdsa_p256.h"
#include "sw/device/silicon_creator/rom/sigverify_keys_spx.h"

#include "hw/top/otp_ctrl_regs.h"
#include "hw/top_dragonfly/sw/autogen/top_dragonfly.h"

/**
 * Type alias for the ROM_EXT entry point.
 *
 * The entry point address obtained from the ROM_EXT manifest must be cast to a
 * pointer to this type before being called.
 */
typedef void rom_ext_entry_point(void);

/**
 * Table of forward branch Control Flow Integrity (CFI) counters.
 *
 * Columns: Name, Initital Value.
 *
 * Each counter is indexed by Name. The Initial Value is used to initialize the
 * counters with unique values with a good hamming distance. The values are
 * restricted to 11-bit to be able use immediate load instructions.

 * Encoding generated with
 * $ ./util/design/sparse-fsm-encode.py -d 6 -m 6 -n 11 \
 *     -s 1630646358 --language=c
 *
 * Minimum Hamming distance: 6
 * Maximum Hamming distance: 8
 * Minimum Hamming weight: 5
 * Maximum Hamming weight: 8
 */
// clang-format off
#define ROM_CFI_FUNC_COUNTERS_TABLE(X) \
  X(kCfiRomMain,         0x14b) \
  X(kCfiRomInit,         0x7dc) \
  X(kCfiRomVerify,       0x5a7) \
  X(kCfiRomTryBoot,      0x235) \
  X(kCfiRomPreBootCheck, 0x43a) \
  X(kCfiRomBoot,         0x2e2)
// clang-format on

// Define counters and constant values required by the CFI counter macros.
CFI_DEFINE_COUNTERS(rom_counters, ROM_CFI_FUNC_COUNTERS_TABLE);

// Life cycle state of the chip.
lifecycle_state_t lc_state = (lifecycle_state_t)0;
// Boot data from flash.
boot_data_t boot_data = {0};
// First stage (ROM-->ROM_EXT) secure boot keys loaded from OTP.
static sigverify_otp_key_ctx_t sigverify_ctx;

OT_ALWAYS_INLINE
OT_WARN_UNUSED_RESULT
static rom_error_t rom_irq_error(void) {
  uint32_t mcause;
  CSR_READ(CSR_REG_MCAUSE, &mcause);
  // Shuffle the mcause bits into the uppermost byte of the word and report
  // the cause as kErrorInterrupt.
  // Based on the ibex verilog, it appears that the most significant bit
  // indicates whether the cause is an exception (0) or external interrupt (1),
  // and the 5 least significant bits indicate which exception/interrupt.
  //
  // Preserve the MSB and shift the 7 LSBs into the upper byte.
  // (we preserve 7 instead of 5 because the verilog hardcodes the unused bits
  // as zero and those would be the next bits used should the number of
  // interrupt causes increase).
  mcause = (mcause & 0x80000000) | ((mcause & 0x7f) << 24);
  return kErrorInterrupt + mcause;
}

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

  lc_state = lifecycle_state_get();

  // Re-initialize the watchdog timer.
  watchdog_init(lc_state);
  SEC_MMIO_WRITE_INCREMENT(kWatchdogSecMmioInit);

  // Update in-memory copy of the ePMP register configuration.
  second_rom_epmp_state_init(lc_state);
  HARDENED_RETURN_IF_ERROR(epmp_state_check());

  // Check that AST is in the expected state.
  HARDENED_RETURN_IF_ERROR(ast_check(lc_state));

  // This function is a NOP unless ROM is built for an fpga.
  device_fpga_version_print();

  sec_mmio_check_values(rnd_uint32());
  sec_mmio_check_counters(/*expected_check_count=*/1);

  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomInit, 2);
  return kErrorOk;
}

/* These symbols are defined in
 * `sw/device/silicon_creator/rom/second_rom.ld`, and describes the
 * location of the flash header.
 */
extern char _rom_ext_virtual_start[];
extern char _rom_ext_virtual_size[];
extern char _ctn_ram[];
extern char _ctn_ram_size[];
/**
 * Compute the virtual address corresponding to the physical address `lma_addr`.
 *
 * @param manifest Pointer to the current manifest.
 * @param lma_addr Load address or physical address.
 * @return the computed virtual address.
 */
OT_WARN_UNUSED_RESULT
static inline uintptr_t rom_ext_vma_get(const manifest_t *manifest,
                                        uintptr_t lma_addr) {
  return (lma_addr - (uintptr_t)manifest + (uintptr_t)_rom_ext_virtual_start);
}

/**
 * Performs consistency checks before booting a ROM_EXT.
 *
 * All of the checks in this function are expected to pass and any failures
 * result in shutdown.
 */
static void rom_pre_boot_check(void) {
  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomPreBootCheck, 1);

  // Check the alert_handler configuration.
  SHUTDOWN_IF_ERROR(alert_config_check(lc_state));
  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomPreBootCheck, 2);

  // Check cached life cycle state against the value reported by hardware.
  lifecycle_state_t lc_state_check = lifecycle_state_get();
  if (launder32(lc_state_check) != lc_state) {
    HARDENED_TRAP();
  }
  HARDENED_CHECK_EQ(lc_state_check, lc_state);
  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomPreBootCheck, 3);

  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomPreBootCheck, 4);

  // Check the ePMP state
  SHUTDOWN_IF_ERROR(epmp_state_check());
  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomPreBootCheck, 5);

  // Check the cpuctrl CSR.
  uint32_t cpuctrl_csr;
  uint32_t cpuctrl_otp =
      otp_read32(OTP_CTRL_PARAM_CREATOR_SW_CFG_CPUCTRL_OFFSET);
  CSR_READ(CSR_REG_CPUCTRL, &cpuctrl_csr);
  // We only mask the 8th bit (`ic_scr_key_valid`) to include exception flags
  // (bits 6 and 7) in the check.
  cpuctrl_csr = bitfield_bit32_write(cpuctrl_csr, 8, false);
  if (launder32(cpuctrl_csr) != cpuctrl_otp) {
    HARDENED_TRAP();
  }
  HARDENED_CHECK_EQ(cpuctrl_csr, cpuctrl_otp);
  // Check rstmgr alert and cpu info collection configuration.
  SHUTDOWN_IF_ERROR(
      rstmgr_info_en_check(retention_sram_get()->creator.reset_reasons));
  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomPreBootCheck, 6);

  sec_mmio_check_counters(/*expected_check_count=*/2);
  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomPreBootCheck, 7);
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

/**
 * Attempts to boot ROM_EXT.
 *
 * @return Result of the last attempt.
 */
OT_WARN_UNUSED_RESULT
static rom_error_t rom_try_boot(void) {
  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomTryBoot, 1);
  CFI_FUNC_COUNTER_PREPCALL(rom_counters, kCfiRomTryBoot, 2,
                            kCfiRomPreBootCheck);
  rom_pre_boot_check();
  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomTryBoot, 4);
  CFI_FUNC_COUNTER_CHECK(rom_counters, kCfiRomPreBootCheck, 8);

  uintptr_t rom_ext_lma = 0x41000000;
  const manifest_t *manifest = (const manifest_t *)rom_ext_lma;

  HARDENED_RETURN_IF_ERROR(epmp_state_check());

  // Load secure boot keys from OTP into RAM.
  HARDENED_RETURN_IF_ERROR(sigverify_otp_keys_init(&sigverify_ctx));

  // Load ACC boot services app.
  //
  // This will be reused by later boot stages.
  HARDENED_RETURN_IF_ERROR(acc_boot_app_load());

  // ECDSA key.
  const ecdsa_p256_public_key_t *ecdsa_key = NULL;
  rom_error_t err = sigverify_ecdsa_p256_key_get(
      &sigverify_ctx,
      sigverify_ecdsa_p256_key_id_get(&manifest->ecdsa_public_key), lc_state,
      &ecdsa_key);
  if (err != kErrorOk) {
    HARDENED_CHECK_NE(err, kErrorOk);
    switch (launder32(lc_state)) {
      case kLcStateProd:
        // No JTAG bootstrap available in PROD.
        HARDENED_CHECK_EQ(lc_state, kLcStateProd);
        return err;
      case kLcStateProdEnd:
        // No JTAG bootstrap available in PROD_END.
        HARDENED_CHECK_EQ(lc_state, kLcStateProdEnd);
        return err;
      case kLcStateTest:
        HARDENED_CHECK_EQ(lc_state, kLcStateTest);
        wait_for_jtag_bootstrap();
        OT_UNREACHABLE();
      case kLcStateDev:
        HARDENED_CHECK_EQ(lc_state, kLcStateDev);
        wait_for_jtag_bootstrap();
        OT_UNREACHABLE();
      case kLcStateRma:
        HARDENED_CHECK_EQ(lc_state, kLcStateRma);
        wait_for_jtag_bootstrap();
        OT_UNREACHABLE();
      default:
        HARDENED_TRAP();
        OT_UNREACHABLE();
    }
  }

  // Measure ROM_EXT and portions of manifest via SHA256 digest.
  hmac_sha256_init();

  // Add manifest usage constraints to the measurement.
  manifest_usage_constraints_t usage_constraints_from_hw;
  sigverify_usage_constraints_get(manifest->usage_constraints.selector_bits,
                                  &usage_constraints_from_hw);
  hmac_sha256_update(&usage_constraints_from_hw,
                     sizeof(usage_constraints_from_hw));

  // Add remaining part of manifest / ROM_EXT image to the measurement.
  manifest_digest_region_t digest_region = manifest_digest_region_get(manifest);
  hmac_sha256_update(digest_region.start, digest_region.length);
  hmac_sha256_process();
  hmac_digest_t act_digest;
  hmac_sha256_final(&act_digest);

  // Actually verify the manifest / ROM_EXT
  uint32_t flash_exec = 0;
  HARDENED_RETURN_IF_ERROR(sigverify_ecdsa_p256_verify(
      &manifest->ecdsa_signature, ecdsa_key, &act_digest, &flash_exec));

  // Set up virtual addressing for ROM_EXT.
  if (manifest->address_translation != kHardenedBoolTrue) {
    return kErrorRomBootFailed;
  }
  HARDENED_CHECK_EQ(manifest->address_translation, kHardenedBoolTrue);
  epmp_region_t text_region = manifest_code_region_get(manifest);
  uintptr_t entry_point = manifest_entry_point_get(manifest);
  HARDENED_CHECK_EQ(manifest->address_translation, kHardenedBoolTrue);
  ibex_addr_remap_set(0, (uintptr_t)_rom_ext_virtual_start, (uintptr_t)manifest,
                      (size_t)_rom_ext_virtual_size);
  SEC_MMIO_WRITE_INCREMENT(kAddressTranslationSecMmioConfigure);

  // Move the ROM_EXT execution section from the load address to the virtual
  // address.
  text_region.start = rom_ext_vma_get(manifest, text_region.start);
  text_region.end = rom_ext_vma_get(manifest, text_region.end);
  entry_point = rom_ext_vma_get(manifest, entry_point);

  // Unlock read-only for the whole rom_ext virtual memory.
  HARDENED_RETURN_IF_ERROR(epmp_state_check());
  second_rom_epmp_unlock_rom_ext(
      text_region,
      (epmp_region_t){.start = rom_ext_lma,
                      .end = rom_ext_lma + (uintptr_t)_rom_ext_virtual_size});

  dbg_printf("Jumping to ROM_EXT entry point at 0x%x\r\n",
             (unsigned)entry_point);
  ((rom_ext_entry_point *)entry_point)();

  return kErrorRomBootFailed;
}

void second_rom_main(void) {
  CFI_FUNC_COUNTER_INIT(rom_counters, kCfiRomMain);

  CFI_FUNC_COUNTER_PREPCALL(rom_counters, kCfiRomMain, 1, kCfiRomInit);
  SHUTDOWN_IF_ERROR(rom_init());
  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomMain, 3);
  CFI_FUNC_COUNTER_CHECK(rom_counters, kCfiRomInit, 3);

  // `rom_try_boot` will not return unless there is an error.
  CFI_FUNC_COUNTER_PREPCALL(rom_counters, kCfiRomMain, 4, kCfiRomTryBoot);
  shutdown_finalize(rom_try_boot());
}

void rom_interrupt_handler(void) {
  register rom_error_t error asm("a0") = rom_irq_error();
  asm volatile("tail shutdown_finalize;" ::"r"(error));
  OT_UNREACHABLE();
}

// We only need a single handler for all ROM interrupts, but we want to
// keep distinct symbols to make writing tests easier.  In the ROM,
// alias all interrupt handler symbols to the single handler.
OT_ALIAS("rom_interrupt_handler")
noreturn void rom_exception_handler(void);

OT_ALIAS("rom_interrupt_handler")
noreturn void rom_nmi_handler(void);
