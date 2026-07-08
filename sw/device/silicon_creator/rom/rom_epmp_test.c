// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/silicon_creator/rom/rom_epmp.h"

#include <stdbool.h>
#include <stdint.h>

#include "hw/top/dt/rom_ctrl.h"
#include "hw/top/dt/sram_ctrl.h"
#include "sw/device/lib/arch/device.h"
#include "sw/device/lib/base/abs_mmio.h"
#include "sw/device/lib/base/csr.h"
#include "sw/device/lib/base/memory.h"
#include "sw/device/lib/base/stdasm.h"
#include "sw/device/lib/dif/dif_pinmux.h"
#include "sw/device/lib/dif/dif_sram_ctrl.h"
#include "sw/device/lib/runtime/hart.h"
#include "sw/device/lib/runtime/ibex.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/runtime/print.h"
#include "sw/device/lib/testing/pinmux_testutils.h"
#include "sw/device/lib/testing/test_framework/status.h"
#include "sw/device/silicon_creator/lib/base/sec_mmio.h"
#include "sw/device/silicon_creator/lib/drivers/epmp.h"
#include "sw/device/silicon_creator/lib/drivers/uart.h"
#include "sw/device/silicon_creator/lib/epmp_test_unlock.h"

#ifdef OPENTITAN_IS_EGRET
#include "hw/top/dt/flash_ctrl.h"  // Generated.
#include "sw/device/silicon_creator/lib/drivers/flash_ctrl.h"

#include "hw/top/flash_ctrl_regs.h"  // Generated.
#elif defined(OPENTITAN_IS_DRAGONFLY)
#include "hw/top/dt/soc_proxy.h"  // Generated.

#include "hw/top/soc_proxy_regs.h"  // Generated.
#endif

/**
 * ROM ePMP test.
 *
 * This test uses the ROM linker script and ePMP setup code to initialize
 * its own ePMP configuration and then attempts to execute instructions in
 * various address spaces. Typically execution in these address spaces should be
 * blocked unless the unlock function has been called with a region containing
 * the address of the access.
 */

/**
 * Get the value of the `mcause` register.
 *
 * @returns The encoded interrupt or exception cause.
 */
static uint32_t get_mcause(void) {
  uint32_t mcause;
  CSR_READ(CSR_REG_MCAUSE, &mcause);
  return mcause;
}

/**
 * Get the value of the `mepc` register.
 *
 * @returns The value of the machine exception program counter.
 */
static uint32_t get_mepc(void) {
  uint32_t mepc;
  CSR_READ(CSR_REG_MEPC, &mepc);
  return mepc;
}

/**
 * Set the value of the `mepc` register.
 *
 * After an exception has been handled execution will be resumed at the address
 * contained within `mepc`.
 *
 * @param pc The value to set the machine exception program counter to.
 */
static void set_mepc(uint32_t pc) { CSR_WRITE(CSR_REG_MEPC, pc); }

/**
 * Interrupt handlers.
 *
 * If operating correctly this test should only trigger exceptions. Interrupts
 * are therefore not recovered.
 */
void rom_nmi_handler(void) { wait_for_interrupt(); }
void rom_interrupt_handler(void) { wait_for_interrupt(); }

/**
 * The type of last exception (if any) received.
 *
 * Set by the exception handler.
 */
volatile ibex_exc_t exception_received = 0;

/**
 * The `mepc` value for the last exception (if any) received.
 *
 * Set by the exception handler.
 */
volatile uintptr_t exception_pc = 0;

/**
 * Exception handler.
 *
 * Handle instruction access faults and illegal instructions by setting
 * `exception_received` and `exception_pc` and then returning to the code
 * that jumped (via a call) to the offending instruction.
 *
 * This will likely only work correctly if the instruction exception was
 * caused by a jump from `execute` to an invalid instruction (whether illegal
 * or inaccessible).
 *
 * For all other exceptions hang (could also shutdown) so as not to hide them.
 */
void rom_exception_handler(void) __attribute__((interrupt));
void rom_exception_handler(void) {
  uint32_t mcause = get_mcause();
  if (mcause == kIbexExcInstrAccessFault ||
      mcause == kIbexExcIllegalInstrFault) {
    exception_received = (ibex_exc_t)mcause;
    exception_pc = get_mepc();

    // Return to caller.
    uintptr_t ret = (uintptr_t)__builtin_return_address(0);
    set_mepc((uint32_t)ret);
    return;
  }

  // Wait forever if an unexpected exception is encountered.
  wait_for_interrupt();
}

// The ROM jumps to the flash_exception_handler first to deal with ECC errors.
// We don't use the flash exception handler in this test, so we alias the
// symbol to rom_exception_handler to allow the test program to link.
OT_ALIAS("rom_exception_handler")
void flash_exception_handler(void);

/**
 * Attempt to execute the code at `pc` by calling it like a function.
 *
 * Typically the contents of `pc` should be an invalid instruction such
 * as an all zero value. In this case if execution was blocked by PMP an
 * instruction fault exception will be raised. If however execution was
 * allowed then an illegal instruction exception will be raised instead.
 *
 * The interrupt handler will arrange for control to be returned to the
 * caller on encountering either an instruction fault or illegal
 * instruction error so this function will report a result in either
 * case.
 *
 * @param pc The address of the instruction to try and execute.
 * @param expect The expected exception that will be raised.
 * @returns Whether the expected exception was raised at the correct PC.
 */
static bool execute(const void *pc, ibex_exc_t expect) {
  exception_pc = 0;
  exception_received = kIbexExcMax;

  // Jump to the target PC.
  //
  // Using a `call` here (`jal` or `jalr`) sets the return address (`ra`)
  // register. When an exception is raised the interrupt handler will recover
  // by restarting execution at the address in `ra` thereby making it appear
  // as if the call returned normally.
  //
  //   ...
  //   jal ra, pc # <- Set return address and jump to pc.
  //   ...        # <- Interrupt handler restarts execution at the next
  //              #    instruction in the caller, here.
  //
  // pc:
  //   unimp      # <- Illegal instruction or access fault. Enter interrupt
  //                   handler.
  //
  ((void (*)(void))pc)();

  // Be careful to ensure that the exception was raised when trying to
  // execute `pc` just in case a valid instruction is actually executed
  // and then execution continued to a point where an exception is
  // raised.
  if (exception_received != kIbexExcMax && exception_pc != (uintptr_t)pc) {
    return false;
  }
  return exception_received == expect;
}

/**
 * An instruction that has all bits set. This value is specifically chosen to
 * match an erased flash.
 *
 * Attempts to execute this instruction, `unimp`, will result in an illegal
 * instruction exception.
 *
 * Note that if compressed instructions are enabled only the first two bytes
 * will be decoded (as `c.unimp`).
 */
static const uint32_t kUnimpInstruction = UINT32_MAX;

/**
 * Illegal instruction residing in .rodata.
 */
static const uint32_t illegal_ins_ro[] = {
    kUnimpInstruction,
};

/**
 * Illegal instruction residing in .bss.
 */
static uint32_t illegal_ins_rw[] = {
    0,
};

/**
 * Report whether the given pointer points to a location with the provided
 * address space.
 *
 * @param ptr Pointer to test.
 * @param start Address of the start of the address space.
 * @param size The size of the address space in bytes.
 * @returns Whether the pointer is in the address space.
 */
static bool is_in_address_space(const void *ptr, uintptr_t start,
                                uintptr_t size) {
  return (uintptr_t)ptr >= start && (uintptr_t)ptr < (start + size);
}

/**
 * Set to false if a test fails.
 */
static bool passed = false;

/**
 * Custom CHECK macro to assert a condition that if false should cause the
 * test to fail. Note: we can't use the normal CHECK macro because it tries to
 * write to the DV address space but that is locked by the ePMP configuration.
 */
#define CHECK(condition)                  \
  if (!(condition)) {                     \
    LOG_ERROR("CHECK-fail: " #condition); \
    passed = false;                       \
  }

/**
 * Returns the base address of the flash memory.
 */
static uint32_t flash_ctrl_mem_base(void) {
  return dt_flash_ctrl_memory_base(kDtFlashCtrl, kDtFlashCtrlMemoryMem);
}

/**
 * Returns the size of the flash memory.
 */
static uint32_t flash_ctrl_mem_size(void) {
  return dt_flash_ctrl_memory_size(kDtFlashCtrl, kDtFlashCtrlMemoryMem);
}

/**
 * Returns the base address of the main SRAM.
 */
static uint32_t sram_ctrl_main_base(void) {
  return dt_sram_ctrl_memory_base(kDtSramCtrlMain, kDtSramCtrlMemoryRam);
}

/**
 * Returns the size of the main SRAM.
 */
static uint32_t sram_ctrl_main_size(void) {
  return dt_sram_ctrl_memory_size(kDtSramCtrlMain, kDtSramCtrlMemoryRam);
}

/**
 * Returns the base address of the retention SRAM registers.
 */
static uint32_t sram_ctrl_ret_reg_base(void) {
  return dt_sram_ctrl_reg_block(kDtSramCtrlRetAon, kDtSramCtrlRegBlockRegs);
}

/**
 * Returns the base address of the retention SRAM.
 */
static uint32_t sram_ctrl_ret_mem_base(void) {
  return dt_sram_ctrl_memory_base(kDtSramCtrlRetAon, kDtSramCtrlMemoryRam);
}

/**
 * Returns the size of the retention SRAM.
 */
static uint32_t sram_ctrl_ret_mem_size(void) {
  return dt_sram_ctrl_memory_size(kDtSramCtrlRetAon, kDtSramCtrlMemoryRam);
}

/**
 * Returns the base address of the pinmux registers.
 */
static uint32_t pinmux_reg_base(void) {
  return dt_pinmux_reg_block(kDtPinmuxAon, kDtPinmuxRegBlockCore);
}

/**
 * Test that .rodata in the ROM is not executable.
 */
static void test_noexec_rodata(void) {
  CHECK(is_in_address_space(
      illegal_ins_ro,
      dt_rom_ctrl_memory_base(kDtRomCtrlFirst, kDtRomCtrlMemoryRom),
      dt_rom_ctrl_memory_size(kDtRomCtrlFirst, kDtRomCtrlMemoryRom)));
  CHECK(execute(illegal_ins_ro, kIbexExcInstrAccessFault));
}

/**
 * Test that the .bss section in RAM is not executable.
 */
static void test_noexec_rwdata(void) {
  dif_sram_ctrl_t sram_ctrl;
  CHECK(dif_sram_ctrl_init(mmio_region_from_addr(sram_ctrl_main_base()),
                           &sram_ctrl) == kDifOk);
  CHECK(dif_sram_ctrl_exec_set_enabled(&sram_ctrl, kDifToggleEnabled) ==
        kDifOk);
  CHECK(is_in_address_space(illegal_ins_rw, sram_ctrl_main_base(),
                            sram_ctrl_main_size()));
  CHECK(execute(illegal_ins_rw, kIbexExcInstrAccessFault));
}

#ifdef OPENTITAN_IS_EGRET
/**
 * Test that eFlash is not executable.
 */
static void test_noexec_eflash(void) {
  // Ideally we'd check all of eFlash but that takes a very long time in
  // simulation. Instead, check the first and last words are not executable and
  // check a sample of other addresses.
  uint32_t *eflash = (uint32_t *)flash_ctrl_mem_base();
  size_t eflash_len = flash_ctrl_mem_size() / sizeof(eflash[0]);
  CHECK(execute(&eflash[0], kIbexExcInstrAccessFault));
  CHECK(execute(&eflash[eflash_len - 1], kIbexExcInstrAccessFault));

  // Step size is picked arbitrarily but should provide a reasonable sample of
  // addresses.
  size_t step = eflash_len / 999;
  for (size_t i = step; i < eflash_len; i += step) {
    if (!execute(&eflash[i], kIbexExcInstrAccessFault)) {
      LOG_ERROR("eflash execution not blocked @ %p", &eflash[i]);
      passed = false;
      break;
    }
  }
}
#elif defined(OPENTITAN_IS_DRAGONFLY)
/**
 * Test that CTN RAM is not executable.
 */
static void test_noexec_ctn(void) {
  // Ideally we'd check all of eFlash but that takes a very long time in
  // simulation. Instead, check the first and last words are not executable and
  // check a sample of other addresses.
  uint32_t *ctn = (uint32_t *)soc_proxy_ctn_base();
  size_t ctn_len = soc_proxy_ctn_size() / sizeof(ctn[0]);
  CHECK(execute(&ctn[0], kIbexExcInstrAccessFault));
  CHECK(execute(&ctn[ctn_len - 1], kIbexExcInstrAccessFault));

  // Step size is picked arbitrarily but should provide a reasonable sample of
  // addresses.
  size_t step = ctn_len / 999;
  for (size_t i = step; i < ctn_len; i += step) {
    if (!execute(&ctn[i], kIbexExcInstrAccessFault)) {
      LOG_ERROR("ctn execution not blocked @ %p", &ctn[i]);
      passed = false;
      break;
    }
  }
}
#endif

/**
 * Test that the MMIO address space (specifically the retention RAM) is not
 * executable.
 */
static void test_noexec_mmio(void) {
  // Note: execution of retention RAM always fails regardless of controller or
  // ePMP configurations however it doesn't hurt to check it anyway.
  dif_sram_ctrl_t ret_ram_ctrl;
  CHECK(dif_sram_ctrl_init(mmio_region_from_addr(sram_ctrl_ret_reg_base()),
                           &ret_ram_ctrl) == kDifOk);
  CHECK(dif_sram_ctrl_exec_set_enabled(&ret_ram_ctrl, kDifToggleEnabled) ==
        kDifOk);
  uint32_t *ret_ram = (uint32_t *)sram_ctrl_ret_mem_base();
  size_t ret_ram_len = sram_ctrl_ret_mem_size() / sizeof(ret_ram[0]);
  ret_ram[0] = kUnimpInstruction;
  CHECK(execute(&ret_ram[0], kIbexExcInstrAccessFault));
  ret_ram[ret_ram_len - 1] = kUnimpInstruction;
  CHECK(execute(&ret_ram[ret_ram_len - 1], kIbexExcInstrAccessFault));
}

/**
 * Test the function used to unlock execution of the ROM extension.
 *
 * Unlock a section of eFlash to simulate the unlocking of the ROM_EXT text.
 * Accesses within the unlocked region should execute (and generate an illegal
 * instruction exception in this case) while accesses outside the unlocked
 * region should still fail with an instruction access fault exception.
 *
 * @param epmp The ePMP state to update.
 */
static void test_unlock_exec_region(void) {
  // Define a region to unlock (this is somewhat arbitrary but must be word-
  // aligned and beyond the ROM region, since this same image is placed in the
  // flash).
#ifdef HAS_FLASH_CTRL
  uint32_t *eflash = (uint32_t *)flash_ctrl_mem_base();
  size_t eflash_len = flash_ctrl_mem_size() / sizeof(eflash[0]);
  uint32_t *image = &eflash[eflash_len / 5];
  size_t image_len = eflash_len / 7;
#else
  uint32_t *ctn = (uint32_t *)soc_proxy_ctn_base();
  size_t ctn_len = soc_proxy_ctn_size() / sizeof(ctn[0]);
  uint32_t *image = &ctn[ctn_len / 5];
  size_t image_len = ctn_len / 7;
#endif
  epmp_region_t region = {.start = (uintptr_t)&image[0],
                          .end = (uintptr_t)&image[image_len]};

  // Unlock execution of the region and check that the same changes are made
  // to the ePMP state.
  epmp_prepare_boot_stage_rx(region);
  CHECK(epmp_state_check() == kErrorOk);

  // Verify that execution within the region succeeds.
  // The image must consist of `unimp` instructions so that an illegal
  // instruction exception is generated. Because the region is not written and
  // tests begin with the flash erased, this instruction is expected to be
  // UINT32_MAX.
  CHECK(image[0] == kUnimpInstruction);
  CHECK(execute(&image[0], kIbexExcIllegalInstrFault));
  CHECK(image[image_len - 1] == kUnimpInstruction);
  CHECK(execute(&image[image_len - 1], kIbexExcIllegalInstrFault));

  // Verify that execution just outside the region still fails.
  CHECK(execute(&image[-1], kIbexExcInstrAccessFault));
  CHECK(execute(&image[image_len], kIbexExcInstrAccessFault));
}

void rom_main(void) {
  // Initialize global variables here so that they don't end up in the .data
  // section since OpenTitan ROM does not have one.
  passed = true;
  exception_received = kIbexExcMax;
  illegal_ins_rw[0] = kUnimpInstruction;

  // Initialize sec_mmio.
  sec_mmio_init();

  // Initialize pinmux configuration so we can use the UART.
  dif_pinmux_t pinmux;
  OT_DISCARD(
      dif_pinmux_init(mmio_region_from_addr(pinmux_reg_base()), &pinmux));
  pinmux_testutils_init(&pinmux);

#ifdef HAS_FLASH_CTRL
  // Enable execution of code in flash.
  flash_ctrl_init();
  flash_ctrl_exec_set(FLASH_CTRL_PARAM_EXEC_EN);
  SEC_MMIO_WRITE_INCREMENT(kFlashCtrlSecMmioInit + kFlashCtrlSecMmioExecSet);
#endif

  // Configure UART0 as stdout.
  uart_init(kUartNCOValue);
  base_set_stdout((buffer_sink_t){
      .data = NULL,
      .sink = uart_sink,
  });

  // Start the tests.
  LOG_INFO("Starting ROM ePMP functional test.");

  // Initialize shadow copy of the ePMP register configuration.
  memset(&epmp_state, 0, sizeof(epmp_state));
  rom_epmp_state_init(kLcStateProd);
  CHECK(epmp_state_check() == kErrorOk);

  // Test that execution outside the ROM text is blocked by default.
  test_noexec_rodata();
  test_noexec_rwdata();
#ifdef HAS_FLASH_CTRL
  test_noexec_eflash();
#else
  test_noexec_ctn();
#endif
  test_noexec_mmio();

  // Test that execution is unlocked for a sub-region of eFlash correctly.
  // Simulates the unlocking of the ROM extension text.
  test_unlock_exec_region();

  // The test of the ROM's ePMP configuration is now complete. Unlock the
  // DV address space so that the test result can be reported. Assumes that PMP
  // entry 6 is allocated for this purpose.
  CHECK(epmp_unlock_test_status());

  // Report the test status.
  //
  // Note that it is only now, after the DV address space has been unlocked that
  // we can signal that the test has started unfortunately.
  test_status_set(kTestStatusInTest);
  test_status_set(passed ? kTestStatusPassed : kTestStatusFailed);

  // Unreachable if reporting the test status correctly caused the
  // test to stop.
  while (true) {
    wait_for_interrupt();
  }
}
