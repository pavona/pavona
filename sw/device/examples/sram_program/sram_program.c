// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include <stdint.h>

#include "hw/top/dt/sram_ctrl.h"
#include "sw/device/lib/arch/device.h"
#include "sw/device/lib/dif/dif_uart.h"
#include "sw/device/lib/runtime/hart.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/runtime/print_uart.h"
#include "sw/device/lib/testing/pinmux_testutils.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/status.h"

static dif_uart_t uart0;
static dif_pinmux_t pinmux;

bool test_main(void) {
  if (kDeviceType != kDeviceSimDV) {
    // Configure the pinmux.
    CHECK_DIF_OK(dif_pinmux_init(mmio_region_from_addr(dt_pinmux_reg_block(
                                     kDtPinmuxAon, kDtPinmuxRegBlockCore)),
                                 &pinmux));
    pinmux_testutils_init(&pinmux);

    // Initialize UART.
    CHECK_DIF_OK(dif_uart_init(
        mmio_region_from_addr(dt_uart_reg_block(kDtUart0, kDtUartRegBlockCore)),
        &uart0));
    CHECK(kUartBaudrate <= UINT32_MAX, "kUartBaudrate must fit in uint32_t");
    CHECK(kClockFreqPeripheralHz <= UINT32_MAX,
          "kClockFreqPeripheralHz must fit in uint32_t");
    CHECK_DIF_OK(dif_uart_configure(
        &uart0, (dif_uart_config_t){
                    .baudrate = (uint32_t)kUartBaudrate,
                    .clk_freq_hz = (uint32_t)kClockFreqPeripheralHz,
                    .parity_enable = kDifToggleDisabled,
                    .parity = kDifUartParityEven,
                    .tx_enable = kDifToggleEnabled,
                    .rx_enable = kDifToggleEnabled,
                }));
    base_uart_stdout(&uart0);
  }

  // Read the program counter and check that we are executing from SRAM.
  uint32_t pc = 0;
  asm("auipc %[pc], 0;" : [pc] "=r"(pc));
  uint32_t sram_start =
      dt_sram_ctrl_memory_base(kDtSramCtrlMain, kDtSramCtrlMemoryRam);
  uint32_t sram_end = sram_start + dt_sram_ctrl_memory_size(
                                       kDtSramCtrlMain, kDtSramCtrlMemoryRam);
  LOG_INFO("PC: %p, SRAM: [%p, %p)", pc, sram_start, sram_end);
  CHECK(pc >= sram_start && pc < sram_end, "PC is outside the main SRAM");
  if (kDeviceType == kDeviceSimDV) {
    test_status_set(kTestStatusPassed);
  }
  return true;
}

// Reference functions that the debugger may wish to call. This prevents the
// compiler from dropping them as unused functions and has the side benefit of
// preventing their includes from appearing unused.
void debugger_support_functions(void) { (void)icache_invalidate; }
