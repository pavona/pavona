// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/silicon_creator/rom/rom.h"

#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

#include "hw/top/dt/rom_ctrl.h"  // Generated.
#include "sw/device/lib/arch/device.h"
#include "sw/device/lib/base/bitfield.h"
#include "sw/device/lib/base/csr.h"
#include "sw/device/lib/base/hardened.h"
#include "sw/device/lib/base/macros.h"
#include "sw/device/lib/base/memory.h"
#include "sw/device/lib/base/multibits.h"
#include "sw/device/silicon_creator/lib/base/sec_mmio.h"
#include "sw/device/silicon_creator/lib/base/static_critical_version.h"
#include "sw/device/silicon_creator/lib/base/util.h"
#include "sw/device/silicon_creator/lib/boot_log.h"
#include "sw/device/silicon_creator/lib/chip_info.h"
#include "sw/device/silicon_creator/lib/drivers/ast.h"
#include "sw/device/silicon_creator/lib/drivers/epmp.h"
#include "sw/device/silicon_creator/lib/drivers/lifecycle.h"
#include "sw/device/silicon_creator/lib/drivers/otp.h"
#include "sw/device/silicon_creator/lib/drivers/pinmux.h"
#include "sw/device/silicon_creator/lib/drivers/pwrmgr.h"
#include "sw/device/silicon_creator/lib/drivers/retention_sram.h"
#include "sw/device/silicon_creator/lib/drivers/rnd.h"
#include "sw/device/silicon_creator/lib/drivers/rstmgr.h"
#include "sw/device/silicon_creator/lib/drivers/uart.h"
#include "sw/device/silicon_creator/lib/drivers/watchdog.h"
#include "sw/device/silicon_creator/lib/error.h"
#include "sw/device/silicon_creator/lib/shutdown.h"
#include "sw/device/silicon_creator/rom/bootstrap.h"
#include "sw/device/silicon_creator/rom/rom_cfi.h"
#include "sw/device/silicon_creator/rom/rom_epmp.h"
#include "sw/device/silicon_creator/rom/rom_state.h"

#include "hw/top/otp_ctrl_regs.h"
#include "hw/top/rstmgr_regs.h"

#ifdef HAS_FLASH_CTRL
#include "sw/device/silicon_creator/lib/drivers/flash_ctrl.h"
#endif

#ifdef HAS_SENSOR_CTRL
#include "sw/device/silicon_creator/lib/drivers/sensor_ctrl.h"
#endif

#ifdef HAS_ROM_CTRL1
#include "sw/device/silicon_creator/rom/boot_second_rom.h"
#else
#include "sw/device/silicon_creator/rom/boot_rom_ext.h"
#endif

// Life cycle state of the chip.
lifecycle_state_t lc_state = (lifecycle_state_t)0;
// Whether we are "simply" waking from low power mode.
static hardened_bool_t waking_from_low_power = 0;
// A ram copy of the OTP word controlling how to handle flash ECC errors.
uint32_t flash_ecc_exc_handler_en;
// A check value for the reset reason.
uint32_t reset_reason_check;

static inline bool rom_console_enabled(void) {
#ifdef DISCRETE_OTP_MAP
  return otp_read32(OTP_CTRL_PARAM_OWNER_SW_CFG_ROM_BANNER_EN_OFFSET) !=
         kHardenedBoolFalse;
#else
  return true;
#endif
}

/**
 * Prints a banner during bootup.
 *
 * Pavona:ssss-pppp-rr
 *
 * Where:
 * - ssss: Silicon Creator ID.
 * - pppp: Product ID.
 * - rr: Revision ID.
 */
static void rom_banner(void) {
  if (!rom_console_enabled()) {
    return;
  }
  //                         : a n o v a P
  const uint64_t kTitle = 0x3a616e6f766150;
  const uint32_t kNewline = 0x0a0d;
  lifecycle_hw_rev_t hw;
  lifecycle_hw_rev_get(&hw);
  uart_write_imm(kTitle);
  uart_write_hex(hw.silicon_creator_id, sizeof(hw.silicon_creator_id), '-');
  uart_write_hex(hw.product_id, sizeof(hw.product_id), '-');
  uart_write_hex(hw.revision_id, sizeof(hw.revision_id), kNewline);
}

/**
 * Performs once-per-boot initialization of ROM modules and peripherals.
 */
OT_WARN_UNUSED_RESULT
static rom_error_t rom_init(void) {
  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomInit, 1);
  sec_mmio_init();
  uint32_t reset_reasons = rstmgr_reason_get();
#ifdef DISCRETE_OTP_MAP
  reset_reason_check =
      reset_reasons ^
      (otp_read32(
           OTP_CTRL_PARAM_OWNER_SW_CFG_ROM_RESET_REASON_CHECK_VALUE_OFFSET) &
       0xFFFF);
#else
  reset_reason_check = reset_reasons ^ kHardenedBoolTrue;
#endif
  if (reset_reasons != (1U << RSTMGR_RESET_INFO_LOW_POWER_EXIT_BIT)) {
    // The above compares all bits, rather than just the one indication "low
    // power exit", because if there is any other reset reason, besides
    // LOW_POWER_EXIT, it means that the chip did full reset while coming out of
    // low power.  In that case, the state of AON IP blocks would have been
    // reset, and the ROM should not treat this as "waking from low power".
    waking_from_low_power = kHardenedBoolFalse;

    // Initialize pinmux configuration so we can use the UART, (except if waking
    // up from low power, as the pinmux will in such case have retained its
    // previous configuration.)
    pinmux_init();
  } else {
    waking_from_low_power = kHardenedBoolTrue;
  }

  // Configure UART0 as stdout.
  uart_init(kUartNCOValue);

  // Set static_critical region format version.
  static_critical_version = kStaticCriticalVersion2;

  // There are no conditional checks before writing to this CSR because it is
  // expected that if relevant Ibex countermeasures are disabled, this will
  // result in a nop.
  CSR_WRITE(CSR_REG_SECURESEED, rnd_uint32());

  // Write the OTP value to bits 0 to 5 of the cpuctrl CSR.
  uint32_t cpuctrl_csr;
  CSR_READ(CSR_REG_CPUCTRL, &cpuctrl_csr);
  cpuctrl_csr = bitfield_field32_write(
      cpuctrl_csr, (bitfield_field32_t){.mask = 0x3f, .index = 0},
      otp_read32(OTP_CTRL_PARAM_CREATOR_SW_CFG_CPUCTRL_OFFSET));
  CSR_WRITE(CSR_REG_CPUCTRL, cpuctrl_csr);

  lc_state = lifecycle_state_get();

  if (launder32(waking_from_low_power) != kHardenedBoolTrue) {
    HARDENED_CHECK_EQ(waking_from_low_power, kHardenedBoolFalse);
    // Re-initialize the watchdog timer, if the RESET was caused by anything
    // besides waking from low power (which would have left the watchdog in its
    // previous configuration).
    watchdog_init(lc_state);
    SEC_MMIO_WRITE_INCREMENT(kWatchdogSecMmioInit);

#if defined(HAS_SENSOR_CTRL)
    // Re-initialize sensor_ctrl.
    HARDENED_RETURN_IF_ERROR(sensor_ctrl_configure(lc_state));
    pwrmgr_cdc_sync(kSensorCtrlSyncCycles);
#endif
  } else {
    HARDENED_CHECK_EQ(waking_from_low_power, kHardenedBoolTrue);
  }

  // Initialize the shutdown policy.
  HARDENED_RETURN_IF_ERROR(shutdown_init(lc_state));

#if defined(HAS_FLASH_CTRL)
  flash_ctrl_init();
  SEC_MMIO_WRITE_INCREMENT(kFlashCtrlSecMmioInit);
  flash_ecc_exc_handler_en = otp_read32(
      OTP_CTRL_PARAM_OWNER_SW_CFG_ROM_FLASH_ECC_EXC_HANDLER_EN_OFFSET);
#endif

  // Initialize in-memory copy of the ePMP register configuration.
  rom_epmp_state_init(lc_state);

  // Check that AST is in the expected state.
  HARDENED_RETURN_IF_ERROR(ast_check(lc_state));

  // Initialize the retention RAM based on the reset reason and the OTP value.
  // Note: Retention RAM is always reset on PoR regardless of the OTP value.
  uint32_t reset_mask =
      (1 << kRstmgrReasonPowerOn) |
      otp_read32(OTP_CTRL_PARAM_CREATOR_SW_CFG_RET_RAM_RESET_MASK_OFFSET);
  if ((reset_reasons & reset_mask) != 0) {
    retention_sram_init();
    // In the discrete OTP map, the high nybble of `ROM_SRAM_READBACK_EN`
    // controls the retram readback enable. In the integrated OTP map, this
    // unconditionally runs.
    uint32_t sram_ret_readback_en;
#if DISCRETE_OTP_MAP
    sram_ret_readback_en =
        otp_read32(OTP_CTRL_PARAM_OWNER_SW_CFG_ROM_SRAM_READBACK_EN_OFFSET) >>
        4;
#else
    sram_ret_readback_en = kMultiBitBool4True;
#endif
    retention_sram_readback_enable(sram_ret_readback_en);
    retention_sram_get()->creator.last_shutdown_reason = kErrorOk;
  }

  // Initialize boot_log
  boot_log_t *boot_log = &retention_sram_get()->creator.boot_log;
  memset(boot_log, 0, sizeof(*boot_log));
  boot_log->identifier = kBootLogIdentifier;
  boot_log->chip_version = kChipInfo.scm_revision;
  boot_log->retention_ram_initialized =
      reset_reasons & reset_mask ? kHardenedBoolTrue : kHardenedBoolFalse;

  // Always store the retention RAM version so the ROM_EXT can depend on its
  // accuracy even after scrambling.
  retention_sram_get()->version = kRetentionSramVersion4;

  // Store the reset reason in retention RAM.
  retention_sram_get()->creator.reset_reasons = reset_reasons;

  // Print a nice message.
  if (waking_from_low_power != kHardenedBoolTrue) {
    rom_banner();
  }
  // This function is a NOP unless ROM is built for an fpga.
  device_fpga_version_print();

  // Double check the reset reason value against the OTP-defined value.
  reset_reason_check = launder32(reset_reason_check) ^ rstmgr_reason_get();
  uint32_t check_val;
#ifdef DISCRETE_OTP_MAP
  check_val =
      otp_read32(
          OTP_CTRL_PARAM_OWNER_SW_CFG_ROM_RESET_REASON_CHECK_VALUE_OFFSET) >>
      16;
#else
  check_val = kHardenedBoolTrue;
#endif
  if (launder32(check_val) != kHardenedBoolFalse) {
    // Double-check the reset reason.
    if (launder32(check_val) == reset_reason_check) {
      HARDENED_CHECK_EQ(check_val, reset_reason_check);
      // Reset reasons equal, do nothing.
    } else {
      return kErrorRomResetReasonFault;
    }
  } else {
    // Configured to not double-check the reset reason.
    HARDENED_CHECK_EQ(check_val, kHardenedBoolFalse);
  }

  // Clear the register if configured to do so in the discrete OTP map. In
  // integrated designs, the reset reason is unconditionally cleared.
  uint32_t preserve_reset_reason;
#ifdef DISCRETE_OTP_MAP
  preserve_reset_reason = otp_read32(
      OTP_CTRL_PARAM_OWNER_SW_CFG_ROM_PRESERVE_RESET_REASON_EN_OFFSET);
#else
  preserve_reset_reason = kHardenedBoolFalse;
#endif
  if (preserve_reset_reason != kHardenedBoolTrue) {
    rstmgr_reason_clear(reset_reasons);
  }

  sec_mmio_check_values(rnd_uint32());
  sec_mmio_check_counters(/*expected_check_count=*/1);

  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomInit, 2);
  return kErrorOk;
}

/**
 * Table of ROM states.
 *
 * Encoding generated with:
 * $ ./util/design/sparse-fsm-encode.py -d 6 -m 4 -n 16 \
 *     -s 519644925 --language=c
 */
// clang-format off
enum {
  kRomStateCnt = 4,
};

/*
 * The bootstrap request is the `kRomStateBootstrapCheck` and
 * `kRomStateBootstrap` ROM states argument. It must be undefined before
 * entering the `kRomStateBootstrapCheck` state as only the
 * `kRomStateBootstrapCheck` run callback or hooks should set it to either
 * `kHardenedBoolFalse` or `kHardenedBoolTrue`.
 */
static hardened_bool_t bootstrap_request = 0;

#define ROM_STATES(X)                                                               \
  X(kRomStateInit,           0x5616, rom_state_init, NULL)                          \
  X(kRomStateBootstrapCheck, 0x0a92, rom_state_bootstrap_check, &bootstrap_request) \
  X(kRomStateBootstrap,      0xd0a0, rom_state_bootstrap, &bootstrap_request)       \
  X(kRomStateBoot,           0xed14, rom_state_boot, NULL)
// clang-format on

ROM_STATE_INIT_TABLE(rom_states, kRomStateCnt, ROM_STATES);

static OT_WARN_UNUSED_RESULT rom_error_t rom_state_init(void *arg,
                                                        uint32_t *next_state) {
  CFI_FUNC_COUNTER_INIT(rom_counters, kCfiRomMain);

  CFI_FUNC_COUNTER_PREPCALL(rom_counters, kCfiRomMain, 1, kCfiRomInit);
  HARDENED_RETURN_IF_ERROR(rom_init());
  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomMain, 3);

  *next_state = kRomStateBootstrapCheck;

  return kErrorOk;
}

/**
 * Prints a status message indicating that the ROM is entering bootstrap mode.
 */
static void rom_bootstrap_message(void) {
  //                              a r t s t o o b
  const uint64_t kBootstrap1 = 0x61727473746f6f62;
  //                             \n\r 1 : p
  const uint64_t kBootstrap2 = 0x0a0d313a70;
  uart_write_imm(kBootstrap1);
  uart_write_imm(kBootstrap2);
}

static OT_WARN_UNUSED_RESULT rom_error_t
rom_state_bootstrap_check(void *arg, uint32_t *next_state) {
  if (launder32(waking_from_low_power) != kHardenedBoolTrue) {
    HARDENED_CHECK_EQ(waking_from_low_power, kHardenedBoolFalse);

    hardened_bool_t *bootstrap_req = (hardened_bool_t *)arg;

    if (launder32(*bootstrap_req) == 0) {
      // The pre_ hook has not set the bootstrap request flag, it has to be
      // checked and set to True or False
      HARDENED_CHECK_EQ(*bootstrap_req, 0);
      *bootstrap_req = bootstrap_requested();
    }

    // The bootstrap request flag must now be True or False.
    if (launder32(*bootstrap_req) == kHardenedBoolTrue) {
      HARDENED_CHECK_EQ(*bootstrap_req, kHardenedBoolTrue);
      *next_state = kRomStateBootstrap;
      return kErrorOk;
    }
  }

  // We are not bootstrapping, aiming for ROM_EXT in single-ROM designs, or the
  // second ROM in dual-ROM designs.
  *next_state = kRomStateBoot;
  return kErrorOk;
}

static OT_WARN_UNUSED_RESULT rom_error_t
rom_state_bootstrap(void *arg, uint32_t *next_state) {
  hardened_bool_t *bootstrap_req = (hardened_bool_t *)arg;

  if (launder32(*bootstrap_req) == kHardenedBoolTrue) {
    HARDENED_CHECK_EQ(*bootstrap_req, kHardenedBoolTrue);
    rom_bootstrap_message();
    watchdog_disable();
    // `bootstrap` will not return unless there is an error.
    HARDENED_RETURN_IF_ERROR(bootstrap());
  }

  return kErrorRomBootFailed;
}

static OT_WARN_UNUSED_RESULT rom_error_t rom_state_boot(void *arg,
                                                        uint32_t *next_state) {
#ifdef HAS_ROM_CTRL1
  CFI_FUNC_COUNTER_PREPCALL(rom_counters, kCfiRomMain, 4, kCfiRomBootSecondRom);
  // `rom_boot_second_rom` will not return unless there is an error.
  return rom_boot_second_rom();
#else
  CFI_FUNC_COUNTER_PREPCALL(rom_counters, kCfiRomMain, 4, kCfiRomTryBootRomExt);
  // `rom_try_boot_rom_ext` will not return unless there is an error.
  return rom_try_boot_rom_ext(lc_state);
#endif
}

void rom_main(void) {
  CFI_FUNC_COUNTER_INIT(rom_counters, kCfiRomMain);
  // `rom_state_fsm_walk` will not return unless there is an error.
  shutdown_finalize(rom_state_fsm_walk(rom_states, kRomStateCnt, kRomStateInit,
                                       rom_states_cfi));
}
