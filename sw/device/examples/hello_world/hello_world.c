// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hw/top/dt/uart.h"
#include "sw/device/lib/arch/device.h"
#include "sw/device/lib/runtime/print_uart.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_test_config.h"

OTTF_DEFINE_TEST_CONFIG();

void _ottf_main(void) {
  // Initialize the UART from the device table
  dif_uart_t uart;
  CHECK_DIF_OK(dif_uart_init_from_dt(kDtUart0, &uart));

  // Configure UART baud and parity
  CHECK(kUartBaudrate <= UINT32_MAX, "kUartBaudrate must fit in uint32_t");
  CHECK(kClockFreqPeripheralHz <= UINT32_MAX,
        "kClockFreqPeripheralHz must fit in uint32_t");
  CHECK_DIF_OK(dif_uart_configure(
      &uart, (dif_uart_config_t){
                 .baudrate = (uint32_t)kUartBaudrate,
                 .clk_freq_hz = (uint32_t)kClockFreqPeripheralHz,
                 .parity_enable = kDifToggleDisabled,
                 .parity = kDifUartParityEven,
                 .tx_enable = kDifToggleEnabled,
                 .rx_enable = kDifToggleEnabled,
             }));

  // Route LOG_INFO to this UART
  base_uart_stdout(&uart);

  LOG_INFO("Hello World!");

  // Add DATE and TIME because I keep fooling myself with old versions
  LOG_INFO("Built at: " __DATE__ ", " __TIME__);

  // The test environment searches for this string to complete the test
  LOG_INFO("PASS!");
}
