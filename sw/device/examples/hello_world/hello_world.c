// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hw/top/dt/gpio.h"
#include "hw/top/dt/pinmux.h"
#include "hw/top/dt/uart.h"
#include "sw/device/examples/demos.h"
#include "sw/device/lib/arch/device.h"
#include "sw/device/lib/dif/dif_gpio.h"
#include "sw/device/lib/dif/dif_pinmux.h"
#include "sw/device/lib/dif/dif_uart.h"
#include "sw/device/lib/runtime/hart.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/runtime/print_uart.h"
#include "sw/device/lib/testing/pinmux_testutils.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_test_config.h"

OTTF_DEFINE_TEST_CONFIG();

static dif_gpio_t gpio;
static dif_uart_t uart;

/**
 * Base address of the gpio registers.
 */
static inline uint32_t gpio_reg_base(void) {
  return dt_gpio_reg_block(kDtGpio, kDtGpioRegBlockCore);
}

/**
 * Base address of the pinmux registers.
 */
static inline uint32_t pinmux_reg_base(void) {
  return dt_pinmux_reg_block(kDtPinmuxAon, kDtPinmuxRegBlockCore);
}

/**
 * Base address of the uart registers.
 */
static inline uint32_t uart0_reg_base(void) {
  return dt_uart_reg_block(kDtUart0, kDtUartRegBlockCore);
}

#ifdef PAVONA_IS_EGRET
static dif_pinmux_t pinmux;

static dif_pinmux_index_t leds[] = {
    kTopEgretPinmuxMioOutIor10,
    kTopEgretPinmuxMioOutIor11,
    kTopEgretPinmuxMioOutIor12,
    kTopEgretPinmuxMioOutIor13,
};

static dif_pinmux_index_t switches[] = {
    kTopEgretPinmuxInselIob6,
    kTopEgretPinmuxInselIob9,
    kTopEgretPinmuxInselIob10,
    kTopEgretPinmuxInselIor5,
};

void configure_pinmux(void) {
  pinmux_testutils_init(&pinmux);
  // Hook up some LEDs.
  for (size_t i = 0; i < ARRAYSIZE(leds); ++i) {
    dif_pinmux_index_t gpio = kTopEgretPinmuxOutselGpioGpio0 + i;
    CHECK_DIF_OK(dif_pinmux_output_select(&pinmux, leds[i], gpio));
  }
  // Hook up DIP switches.
  for (size_t i = 0; i < ARRAYSIZE(switches); ++i) {
    dif_pinmux_index_t gpio = kTopEgretPinmuxPeripheralInGpioGpio8 + i;
    CHECK_DIF_OK(dif_pinmux_input_select(&pinmux, gpio, switches[i]));
  }
}
#endif

void _ottf_main(void) {
#if defined(PAVONA_IS_EGRET)
  CHECK_DIF_OK(
      dif_pinmux_init(mmio_region_from_addr(pinmux_reg_base()), &pinmux));
  configure_pinmux();
#endif

  CHECK_DIF_OK(dif_uart_init(mmio_region_from_addr(uart0_reg_base()), &uart));

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
  base_uart_stdout(&uart);

  CHECK_DIF_OK(dif_gpio_init(mmio_region_from_addr(gpio_reg_base()), &gpio));
  // Enable GPIO: 0-3 is output; 8-11 is input.
  CHECK_DIF_OK(dif_gpio_output_set_enabled_all(&gpio, 0xF));

  // Add DATE and TIME because I keep fooling myself with old versions
  LOG_INFO("Hello World!");
  LOG_INFO("Built at: " __DATE__ ", " __TIME__);

  demo_gpio_startup(&gpio);

  // Now have UART <-> Buttons/LEDs demo
  // all LEDs off
  CHECK_DIF_OK(dif_gpio_write_all(&gpio, 0x0000));
  LOG_INFO("Try out USERDIP switches 0-thru-3 on the board");
  LOG_INFO("or type anything into the console window.");
  LOG_INFO(
      "The LEDs show the lower nibble of the ASCII code of the last "
      "character.");

  LOG_INFO("PASSED");

  uint32_t gpio_state = 0;
  while (true) {
    busy_spin_micros(10 * 1000);  // 10 ms
    gpio_state = demo_gpio_to_log_echo(&gpio, gpio_state);
    demo_uart_to_uart_and_gpio_echo(&uart, &gpio);
  }
}
