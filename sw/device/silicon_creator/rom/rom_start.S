// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/base/hardened_asm.h"
#include "sw/device/lib/base/multibits_asm.h"
#include "sw/device/silicon_creator/lib/base/chip.h"
#include "sw/device/silicon_creator/lib/stack_utilization_asm.h"
#include "hw/top/aon_timer_regs.h"
#include "hw/top/ast_regs.h"
#include "hw/top/clkmgr_regs.h"
#include "hw/top/csrng_regs.h"
#include "hw/top/edn_regs.h"
#include "hw/top/entropy_src_regs.h"
#include "hw/top/gpio_regs.h"
#include "hw/top/lc_ctrl_regs.h"
#include "hw/top/otp_ctrl_regs.h"
#include "hw/top/pinmux_regs.h"
#include "hw/top/pwrmgr_regs.h"
#include "hw/top/rstmgr_regs.h"
#include "hw/top/rv_core_ibex_regs.h"
#include "hw/top/sram_ctrl_regs.h"

#ifdef HAS_SENSOR_CTRL
#include "hw/top/sensor_ctrl_regs.h"
#endif

// This macro defines convenience labels for tests that use a debugger.
#define LABEL_FOR_TEST(kName_) .local kName_ ; kName_: ;

// Define top-specific address constants.
//
// Using `dt` is unsuitable here for this purpose because it would require
// explicit `call` instructions prior to setting up the stack.
#if defined(OPENTITAN_IS_EGRET)
#include "hw/top_egret/sw/autogen/top_egret_memory.h"

#define TOPLEVEL_CONST(x) TOP_EGRET_##x
#elif defined(OPENTITAN_IS_DRAGONFLY)
#include "hw/top_dragonfly/sw/autogen/top_dragonfly_memory.h"

#define TOPLEVEL_CONST(x) TOP_DRAGONFLY_##x
#endif

.equ UNIMP, 0xc0001073
// We will configure the watchdog timers to reset the chip in the event that the
// ROM stalls. The watchdog's bite and bark thresholds are set to 1 and 1.125
// seconds, respectively, assuming a clock frequency of 200 kHz.
.equ WDOG_BITE_THOLD, 0x30d40
.equ WDOG_BARK_THOLD, WDOG_BITE_THOLD * 9 / 8

/**
 * ROM interrupt vectors.
 */

  // Push ROM interrupt vector options.
  .option push

  // Disable RISC-V instruction compression: we need all instructions to
  // be exactly word wide in the interrupt vector.
  .option norvc

  // Disable RISC-V linker relaxation, as it can compress instructions at
  // link-time, which we also really don't want.
  .option norelax

  /**
   * Initial RISC-V vectored exception/interrupt handlers.
   *
   * After reset, all interrupts are disabled. Only exceptions (interrupt 0) and
   * non-maskable interrupts (interrupt 31) are possible. For simplicity,
   * however, we just set all interrupt handlers to the same exception handler.
   *
   * Since the C runtime is not initialized immediately after reset, the initial
   * interrupt vector must only call functions written in assembly. Once the C
   * runtime is intialized, the interrupt vector should be replaced.
   *
   * If the hardware is operating correctly, the assembly interrupt handlers
   * should never be called.
   *
   * Note that the Ibex reset handler (entry point) immediately follows this
   * interrupt vector and can be thought of as an extra entry.
   *
   * More information about Ibex's interrupts can be found here:
   *   https://ibex-core.readthedocs.io/en/latest/03_reference/exception_interrupts.html
   */
  .section .vectors, "ax"
  .balignl 256, UNIMP
  .global _rom_interrupt_vector_asm
  .type _rom_interrupt_vector_asm, @function
_rom_interrupt_vector_asm:
  // Each jump instruction must be exactly 4 bytes in order to ensure that the
  // entries are properly located.
  .rept 32
  j _asm_exception_handler
  .endr

  // Ibex Reset Handler:
  j _rom_start_boot
  .size _rom_interrupt_vector_asm, .-_rom_interrupt_vector_asm

// -----------------------------------------------------------------------------

  /**
   * Post C runtime initialization RISC-V vectored exception/interrupt handlers.
   */
  .balignl 256, UNIMP
  .global _rom_interrupt_vector_c
  .type _rom_interrupt_vector_c, @function
_rom_interrupt_vector_c:
#ifdef HAS_FLASH_CTRL
  // Entry 0: exception handler.
  j flash_exception_handler
#else
  // Entry 0: interrupt handler.
  j rom_exception_handler
#endif
  // Entries 1-30: interrupt handlers.
  .rept 30
  j rom_interrupt_handler
  .endr

  // Entry 31: non-maskable interrupt handler.
  j rom_nmi_handler
  .size _rom_interrupt_vector_c, .-_rom_interrupt_vector_c

  // Pop ROM interrupt vector options.
  //
  // Re-enable compressed instructions, linker relaxation.
  .option pop

  /**
   * ROM shadow stack.
   */
  .section .bss
  .balignl 4
  .global _rom_shadow_stack
  .type _rom_shadow_stack, @object
_rom_shadow_stack:
  .zero 256 * 4
  .size _rom_shadow_stack, .-_rom_shadow_stack

// -----------------------------------------------------------------------------

/**
 * ROM runtime initialization code.
 */

  // NOTE: The "ax" flag below is necessary to ensure that this section
  // is allocated executable space in ROM by the linker.
  .section .crt, "ax"

  // Linker relaxations are disabled until `gp` is set below, because otherwise
  // some sequences may be turned into `gp`-relative sequences, which is
  // incorrect when `gp` is not initialized.
  .option push
  .option norelax

  /**
   * Entry point after reset.
   */
  .balignl 4, UNIMP
  .global _rom_start_boot
  .type _rom_start_boot, @function
_rom_start_boot:
  // Set up the global pointer and re-enable linker relaxations.
  la gp, __global_pointer$
  .option pop

LABEL_FOR_TEST(kRomStartBootMaybeHalt)
  // Check if we should halt here.
  li   a0, (TOPLEVEL_CONST(OTP_CTRL_CORE_BASE_ADDR) + \
            OTP_CTRL_SW_CFG_WINDOW_REG_OFFSET)
  lw   t0, OTP_CTRL_PARAM_CREATOR_SW_CFG_ROM_EXEC_EN_OFFSET(a0)
  bnez t0, .L_exec_en
LABEL_FOR_TEST(kRomStartBootHalted)
.L_halt_loop:
  wfi
  j .L_halt_loop

LABEL_FOR_TEST(kRomStartBootExecEn)
.L_exec_en:
  // Enable NMIs from the watchdog timer.
  li t0, TOPLEVEL_CONST(RV_CORE_IBEX_CFG_BASE_ADDR)
  li t1, (1 << RV_CORE_IBEX_NMI_ENABLE_WDOG_EN_BIT)
  sw t1, RV_CORE_IBEX_NMI_ENABLE_REG_OFFSET(t0)

  // Configure the power manager to enable resets.
  // Note: this enables all types of reset request for simplicity.
  li t0, TOPLEVEL_CONST(PWRMGR_AON_BASE_ADDR)
  li t1, -1
  sw t1, PWRMGR_RESET_EN_REG_OFFSET(t0)

  // Trigger a power manager configuration synchronization.
  li t1, (1 << PWRMGR_CFG_CDC_SYNC_SYNC_BIT)
  sw t1, PWRMGR_CFG_CDC_SYNC_REG_OFFSET(t0)

  // In case of waking from low power, with AON IP state intact,
  // skip watchdog configuration.
  li a0, TOPLEVEL_CONST(RSTMGR_AON_BASE_ADDR)
  lw t0, RSTMGR_RESET_INFO_REG_OFFSET(a0)
  li t1, (1 << RSTMGR_RESET_INFO_LOW_POWER_EXIT_BIT)
  beq t0, t1, .L_skip_watchdog_init

  // Configure the watchdog's bark and bite thresholds.
  li t0, TOPLEVEL_CONST(AON_TIMER_AON_BASE_ADDR)
  li t1, WDOG_BARK_THOLD
  sw t1, AON_TIMER_WDOG_BARK_THOLD_REG_OFFSET(t0)
  li t1, WDOG_BITE_THOLD
LABEL_FOR_TEST(kRomStartStoreT1ToBiteThold)
  sw t1, AON_TIMER_WDOG_BITE_THOLD_REG_OFFSET(t0)

  // Enable the watchdog timer.
  li t1, (1 << AON_TIMER_WDOG_CTRL_ENABLE_BIT)
  sw t1, AON_TIMER_WDOG_CTRL_REG_OFFSET(t0)
.L_skip_watchdog_init:

  // Configure rstmgr alert and cpu info collection.
  li   a0, (TOPLEVEL_CONST(OTP_CTRL_CORE_BASE_ADDR) + \
            OTP_CTRL_SW_CFG_WINDOW_REG_OFFSET)
  lw   t0, OTP_CTRL_PARAM_OWNER_SW_CFG_ROM_RSTMGR_INFO_EN_OFFSET(a0)
  li   t1, HARDENED_BYTE_BOOL_TRUE
  li   a0, TOPLEVEL_CONST(RSTMGR_AON_BASE_ADDR)
  // Enable alert info collection if enabled in OTP.
  andi t2, t0, 0xff
  bne  t2, t1, .L_skip_rstmgr_alert_info_en
  li   t2, (1 << RSTMGR_ALERT_INFO_CTRL_EN_BIT)
  sw   t2,  RSTMGR_ALERT_INFO_CTRL_REG_OFFSET(a0)
.L_skip_rstmgr_alert_info_en:
  // Enable cpu info collection if enabled in OTP.
  srli t0, t0, 8
  andi t2, t0, 0xff
  bne  t2, t1, .L_skip_rstmgr_cpu_info_en
  li   t2, (1 << RSTMGR_CPU_INFO_CTRL_EN_BIT)
  sw   t2,  RSTMGR_CPU_INFO_CTRL_REG_OFFSET(a0)
.L_skip_rstmgr_cpu_info_en:

LABEL_FOR_TEST(kRomStartWatchdogEnabled)
  // Clear all the machine-defined interrupts, `MEIE`, `MTIE`, and `MSIE` fields
  // of `mie`.
  li   t0, 0x00000888
  csrc mie, t0

  // Copy the AST configuration from OTP.
  li   a0, (TOPLEVEL_CONST(AST_BASE_ADDR))
  li   a1, (TOPLEVEL_CONST(AST_BASE_ADDR) + AST_REGAL_REG_OFFSET + 4)
  li   a2, (TOPLEVEL_CONST(OTP_CTRL_CORE_BASE_ADDR) + \
            OTP_CTRL_SW_CFG_WINDOW_REG_OFFSET + \
            OTP_CTRL_PARAM_CREATOR_SW_CFG_AST_CFG_OFFSET)
  call crt_section_copy

  // Enable jittery clock if not strictly disabled in OTP.
  // Use hardcoded MULTIBIT_ASM_BOOL4_TRUE as the enable word to reduce all
  // other possible OTP values to true.
  li   a0, (TOPLEVEL_CONST(OTP_CTRL_CORE_BASE_ADDR) + \
            OTP_CTRL_SW_CFG_WINDOW_REG_OFFSET)
  lw   t0, OTP_CTRL_PARAM_CREATOR_SW_CFG_JITTER_EN_OFFSET(a0)
  li   t1, MULTIBIT_ASM_BOOL4_FALSE
  beq  t0, t1, .L_ast_init_end
  li   a0, TOPLEVEL_CONST(CLKMGR_AON_BASE_ADDR)
  li   t1, MULTIBIT_ASM_BOOL4_TRUE
  sw   t1, CLKMGR_JITTER_ENABLE_REG_OFFSET(a0)

.L_ast_init_end:
  // Skip the `entropy_src` health checks configuration if the
  // `RNG_HEALTH_CONFIG_DIGEST` is not programmed. The default digest value is
  // 0 given that it is stored in a software OTP partition.
  li   a0, (TOPLEVEL_CONST(OTP_CTRL_CORE_BASE_ADDR) + \
            OTP_CTRL_SW_CFG_WINDOW_REG_OFFSET)
  lw t0, OTP_CTRL_PARAM_CREATOR_SW_CFG_RNG_HEALTH_CONFIG_DIGEST_OFFSET(a0)
  beqz t0, .L_entropy_enable

  // Copy the entropy source health checks configuration thresholds from OTP.
  li   a0, (TOPLEVEL_CONST(ENTROPY_SRC_BASE_ADDR) + \
            ENTROPY_SRC_REPCNT_THRESHOLDS_REG_OFFSET)
  li   a1, (TOPLEVEL_CONST(ENTROPY_SRC_BASE_ADDR) + \
            ENTROPY_SRC_EXTHT_LO_THRESHOLDS_REG_OFFSET + 4)
  li   a2, (TOPLEVEL_CONST(OTP_CTRL_CORE_BASE_ADDR) + \
            OTP_CTRL_SW_CFG_WINDOW_REG_OFFSET + \
            OTP_CTRL_PARAM_CREATOR_SW_CFG_RNG_REPCNT_THRESHOLDS_OFFSET)
  call crt_section_copy

  // Configure the entropy source health alert threshold.
  li a0, TOPLEVEL_CONST(ENTROPY_SRC_BASE_ADDR)
  li a1, (TOPLEVEL_CONST(OTP_CTRL_CORE_BASE_ADDR) + \
            OTP_CTRL_SW_CFG_WINDOW_REG_OFFSET)
  lw t1, OTP_CTRL_PARAM_CREATOR_SW_CFG_RNG_ALERT_THRESHOLD_OFFSET(a1)
  sw t1, ENTROPY_SRC_ALERT_THRESHOLD_REG_OFFSET(a0)

.L_entropy_enable:
  // The following sequence enables the minimum level of entropy required to
  // initialize memory scrambling, as well as the entropy distribution network.
  li a0, TOPLEVEL_CONST(ENTROPY_SRC_BASE_ADDR)

  // Note for BOOT_ROM initialization the FIPS_ENABLE bit is set to kMultiBitBool4False
  // to prevent the release of FIPS entropy until all the thresholds are set
  li t0, (MULTIBIT_ASM_BOOL4_FALSE << ENTROPY_SRC_CONF_FIPS_ENABLE_OFFSET) | \
         (MULTIBIT_ASM_BOOL4_FALSE << ENTROPY_SRC_CONF_ENTROPY_DATA_REG_ENABLE_OFFSET) | \
         (MULTIBIT_ASM_BOOL4_FALSE << ENTROPY_SRC_CONF_FIPS_FLAG_OFFSET) | \
         (MULTIBIT_ASM_BOOL4_FALSE << ENTROPY_SRC_CONF_RNG_FIPS_OFFSET) | \
         (MULTIBIT_ASM_BOOL4_FALSE << ENTROPY_SRC_CONF_THRESHOLD_SCOPE_OFFSET) | \
         (MULTIBIT_ASM_BOOL4_FALSE << ENTROPY_SRC_CONF_RNG_BIT_ENABLE_OFFSET)
  sw t0, ENTROPY_SRC_CONF_REG_OFFSET(a0)

  li t0, (MULTIBIT_ASM_BOOL4_TRUE << ENTROPY_SRC_MODULE_ENABLE_MODULE_ENABLE_OFFSET)
  sw t0, ENTROPY_SRC_MODULE_ENABLE_REG_OFFSET(a0)

  li a0, TOPLEVEL_CONST(CSRNG_BASE_ADDR)
  li t0, (MULTIBIT_ASM_BOOL4_TRUE << CSRNG_CTRL_ENABLE_OFFSET) | \
         (MULTIBIT_ASM_BOOL4_TRUE << CSRNG_CTRL_SW_APP_ENABLE_OFFSET) | \
         (MULTIBIT_ASM_BOOL4_TRUE << CSRNG_CTRL_READ_INT_STATE_OFFSET) | \
         (MULTIBIT_ASM_BOOL4_FALSE << CSRNG_CTRL_FIPS_FORCE_ENABLE_OFFSET)
  sw t0, CSRNG_CTRL_REG_OFFSET(a0)

  li a0, TOPLEVEL_CONST(EDN0_BASE_ADDR)
  li t0, (MULTIBIT_ASM_BOOL4_TRUE << EDN_CTRL_EDN_ENABLE_OFFSET) | \
         (MULTIBIT_ASM_BOOL4_TRUE << EDN_CTRL_BOOT_REQ_MODE_OFFSET) | \
         (MULTIBIT_ASM_BOOL4_FALSE << EDN_CTRL_AUTO_REQ_MODE_OFFSET) | \
         (MULTIBIT_ASM_BOOL4_FALSE << EDN_CTRL_CMD_FIFO_RST_OFFSET)
  sw t0, EDN_CTRL_REG_OFFSET(a0)

  // Scramble and initialize main memory (main SRAM).
  // Memory accesses will stall until initialization is complete.
  // Set `SRAM_KEY_RENEW_AND_INIT_EN` OTP item to `HARDENED_BOOL_FALSE` to disable and
  // any other value to enable.
  li   a0, (TOPLEVEL_CONST(OTP_CTRL_CORE_BASE_ADDR) + \
            OTP_CTRL_SW_CFG_WINDOW_REG_OFFSET)
  lw   t2, OTP_CTRL_PARAM_OWNER_SW_CFG_ROM_SRAM_READBACK_EN_OFFSET(a0)
  lw   t0, OTP_CTRL_PARAM_CREATOR_SW_CFG_SRAM_KEY_RENEW_AND_INIT_EN_OFFSET(a0)
  li   t1, HARDENED_BOOL_FALSE
  beq t0, t1, .L_sram_key_renew_skip
  li a0, TOPLEVEL_CONST(SRAM_CTRL_MAIN_REGS_BASE_ADDR)
  li a1, (1 << SRAM_CTRL_CTRL_RENEW_SCR_KEY_BIT) | (1 << SRAM_CTRL_CTRL_INIT_BIT)
  sw a1, SRAM_CTRL_CTRL_REG_OFFSET(a0)
.L_sram_key_renew_skip:
  // Depending on OTP, enable the SRAM readback feature.
  sw   t2, SRAM_CTRL_READBACK_REG_OFFSET(a0)

  // Zero all writable registers except for `gp` (`x3`) since it's already initialized.
  li x1,  0x0
  li x2,  0x0
  li x4,  0x0
  li x5,  0x0
  li x6,  0x0
  li x7,  0x0
  li x8,  0x0
  li x9,  0x0
  li x10, 0x0
  li x11, 0x0
  li x12, 0x0
  li x13, 0x0
  li x14, 0x0
  li x15, 0x0
  li x16, 0x0
  li x17, 0x0
  li x18, 0x0
  li x19, 0x0
  li x20, 0x0
  li x21, 0x0
  li x22, 0x0
  li x23, 0x0
  li x24, 0x0
  li x25, 0x0
  li x26, 0x0
  li x27, 0x0
  li x28, 0x0
  li x29, 0x0
  li x30, 0x0
  li x31, 0x0

  // Must be called prior to any Main RAM access.
  call rom_epmp_init

  /**
   * Setup C Runtime
   */

  // Initialize the `.bss` section.
  la   a0, _bss_start
  la   a1, _bss_end
  call crt_section_clear

  // Set up stack pointer.
  //
  // In RISC-V, the stack grows downwards, so we load the address of the highest
  // word in the stack into sp.
  //
  // If an exception fires, the handler is conventionally only allowed to clobber
  // memory at addresses below `sp`.
  la sp, _stack_end

#ifdef STACK_UTILIZATION_CHECK
  // Fill the stack with a known pattern
  // We configure a No-Access ePMP NA4 region at stack_start as a
  // stack guard.  We cannot access that word, so start filling
  // after the stack guard.
.L_stack_clear:
  la   a0, _stack_start + 4
  li   a1, STACK_UTILIZATION_FREE_PATTERN
.L_stack_clear_loop:
  sw   a1, 0(a0)
  addi a0, a0, 4
  bltu a0, sp, .L_stack_clear_loop
#endif

  // Set up shadow stack pointer.
  //
  // The shadow stack, unlike the regular stack, grows upwards.
  la x18, _rom_shadow_stack


  // Set exception/interrupt handlers.
  //
  // Now that the C runtime is initialized it is safe to use C functions as
  // exception/interrupt handlers.
  //
  // Note: the increment just sets the low bits to 0b01 which is the vectored
  // mode setting.
  la   t0, (_rom_interrupt_vector_c + 1)
  csrw mtvec, t0

  /**
   * Jump to C Code
   */
  tail rom_main
  unimp
  unimp
  unimp
  unimp
  .size _rom_start_boot, .-_rom_start_boot
