// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// ------------------- W A R N I N G: A U T O - G E N E R A T E D   C O D E !! -------------------//
// PLEASE DO NOT HAND-EDIT THIS FILE. IT HAS BEEN AUTO-GENERATED WITH THE FOLLOWING COMMAND:
// util/topgen.py -t hw/top_scafi_deprecated/data/top_scafi_deprecated.hjson
//                -o hw/top_scafi_deprecated/

#ifndef OPENTITAN_HW_TOP_SCAFI_DEPRECATED_SW_AUTOGEN_TOP_SCAFI_DEPRECATED_H_
#define OPENTITAN_HW_TOP_SCAFI_DEPRECATED_SW_AUTOGEN_TOP_SCAFI_DEPRECATED_H_

/**
 * @file
 * @brief Top-specific Definitions
 *
 * This file contains preprocessor and type definitions for use within the
 * device C/C++ codebase.
 *
 * These definitions are for information that depends on the top-specific chip
 * configuration, which includes:
 * - Device Memory Information (for Peripherals and Memory)
 * - PLIC Interrupt ID Names and Source Mappings
 * - Pinmux Pin/Select Names
 * - Power Manager Wakeups
 */

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Peripheral base address for uart0 in top scafi_deprecated.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_SCAFI_DEPRECATED_UART0_BASE_ADDR 0x40000000u

/**
 * Peripheral size for uart0 in top scafi_deprecated.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_SCAFI_DEPRECATED_UART0_BASE_ADDR and
 * `TOP_SCAFI_DEPRECATED_UART0_BASE_ADDR + TOP_SCAFI_DEPRECATED_UART0_SIZE_BYTES`.
 */
#define TOP_SCAFI_DEPRECATED_UART0_SIZE_BYTES 0x40u

/**
 * Peripheral base address for uart1 in top scafi_deprecated.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_SCAFI_DEPRECATED_UART1_BASE_ADDR 0x40010000u

/**
 * Peripheral size for uart1 in top scafi_deprecated.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_SCAFI_DEPRECATED_UART1_BASE_ADDR and
 * `TOP_SCAFI_DEPRECATED_UART1_BASE_ADDR + TOP_SCAFI_DEPRECATED_UART1_SIZE_BYTES`.
 */
#define TOP_SCAFI_DEPRECATED_UART1_SIZE_BYTES 0x40u

/**
 * Peripheral base address for gpio in top scafi_deprecated.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_SCAFI_DEPRECATED_GPIO_BASE_ADDR 0x40040000u

/**
 * Peripheral size for gpio in top scafi_deprecated.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_SCAFI_DEPRECATED_GPIO_BASE_ADDR and
 * `TOP_SCAFI_DEPRECATED_GPIO_BASE_ADDR + TOP_SCAFI_DEPRECATED_GPIO_SIZE_BYTES`.
 */
#define TOP_SCAFI_DEPRECATED_GPIO_SIZE_BYTES 0x80u

/**
 * Peripheral base address for spi_device in top scafi_deprecated.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_SCAFI_DEPRECATED_SPI_DEVICE_BASE_ADDR 0x40050000u

/**
 * Peripheral size for spi_device in top scafi_deprecated.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_SCAFI_DEPRECATED_SPI_DEVICE_BASE_ADDR and
 * `TOP_SCAFI_DEPRECATED_SPI_DEVICE_BASE_ADDR + TOP_SCAFI_DEPRECATED_SPI_DEVICE_SIZE_BYTES`.
 */
#define TOP_SCAFI_DEPRECATED_SPI_DEVICE_SIZE_BYTES 0x2000u

/**
 * Peripheral base address for spi_host0 in top scafi_deprecated.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_SCAFI_DEPRECATED_SPI_HOST0_BASE_ADDR 0x40060000u

/**
 * Peripheral size for spi_host0 in top scafi_deprecated.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_SCAFI_DEPRECATED_SPI_HOST0_BASE_ADDR and
 * `TOP_SCAFI_DEPRECATED_SPI_HOST0_BASE_ADDR + TOP_SCAFI_DEPRECATED_SPI_HOST0_SIZE_BYTES`.
 */
#define TOP_SCAFI_DEPRECATED_SPI_HOST0_SIZE_BYTES 0x40u

/**
 * Peripheral base address for rv_timer in top scafi_deprecated.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_SCAFI_DEPRECATED_RV_TIMER_BASE_ADDR 0x40100000u

/**
 * Peripheral size for rv_timer in top scafi_deprecated.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_SCAFI_DEPRECATED_RV_TIMER_BASE_ADDR and
 * `TOP_SCAFI_DEPRECATED_RV_TIMER_BASE_ADDR + TOP_SCAFI_DEPRECATED_RV_TIMER_SIZE_BYTES`.
 */
#define TOP_SCAFI_DEPRECATED_RV_TIMER_SIZE_BYTES 0x200u

/**
 * Peripheral base address for usbdev in top scafi_deprecated.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_SCAFI_DEPRECATED_USBDEV_BASE_ADDR 0x40320000u

/**
 * Peripheral size for usbdev in top scafi_deprecated.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_SCAFI_DEPRECATED_USBDEV_BASE_ADDR and
 * `TOP_SCAFI_DEPRECATED_USBDEV_BASE_ADDR + TOP_SCAFI_DEPRECATED_USBDEV_SIZE_BYTES`.
 */
#define TOP_SCAFI_DEPRECATED_USBDEV_SIZE_BYTES 0x1000u

/**
 * Peripheral base address for pwrmgr_aon in top scafi_deprecated.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_SCAFI_DEPRECATED_PWRMGR_AON_BASE_ADDR 0x40400000u

/**
 * Peripheral size for pwrmgr_aon in top scafi_deprecated.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_SCAFI_DEPRECATED_PWRMGR_AON_BASE_ADDR and
 * `TOP_SCAFI_DEPRECATED_PWRMGR_AON_BASE_ADDR + TOP_SCAFI_DEPRECATED_PWRMGR_AON_SIZE_BYTES`.
 */
#define TOP_SCAFI_DEPRECATED_PWRMGR_AON_SIZE_BYTES 0x80u

/**
 * Peripheral base address for rstmgr_aon in top scafi_deprecated.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_SCAFI_DEPRECATED_RSTMGR_AON_BASE_ADDR 0x40410000u

/**
 * Peripheral size for rstmgr_aon in top scafi_deprecated.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_SCAFI_DEPRECATED_RSTMGR_AON_BASE_ADDR and
 * `TOP_SCAFI_DEPRECATED_RSTMGR_AON_BASE_ADDR + TOP_SCAFI_DEPRECATED_RSTMGR_AON_SIZE_BYTES`.
 */
#define TOP_SCAFI_DEPRECATED_RSTMGR_AON_SIZE_BYTES 0x80u

/**
 * Peripheral base address for clkmgr_aon in top scafi_deprecated.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_SCAFI_DEPRECATED_CLKMGR_AON_BASE_ADDR 0x40420000u

/**
 * Peripheral size for clkmgr_aon in top scafi_deprecated.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_SCAFI_DEPRECATED_CLKMGR_AON_BASE_ADDR and
 * `TOP_SCAFI_DEPRECATED_CLKMGR_AON_BASE_ADDR + TOP_SCAFI_DEPRECATED_CLKMGR_AON_SIZE_BYTES`.
 */
#define TOP_SCAFI_DEPRECATED_CLKMGR_AON_SIZE_BYTES 0x80u

/**
 * Peripheral base address for pinmux_aon in top scafi_deprecated.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_SCAFI_DEPRECATED_PINMUX_AON_BASE_ADDR 0x40460000u

/**
 * Peripheral size for pinmux_aon in top scafi_deprecated.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_SCAFI_DEPRECATED_PINMUX_AON_BASE_ADDR and
 * `TOP_SCAFI_DEPRECATED_PINMUX_AON_BASE_ADDR + TOP_SCAFI_DEPRECATED_PINMUX_AON_SIZE_BYTES`.
 */
#define TOP_SCAFI_DEPRECATED_PINMUX_AON_SIZE_BYTES 0x1000u

/**
 * Peripheral base address for aon_timer_aon in top scafi_deprecated.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_SCAFI_DEPRECATED_AON_TIMER_AON_BASE_ADDR 0x40470000u

/**
 * Peripheral size for aon_timer_aon in top scafi_deprecated.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_SCAFI_DEPRECATED_AON_TIMER_AON_BASE_ADDR and
 * `TOP_SCAFI_DEPRECATED_AON_TIMER_AON_BASE_ADDR + TOP_SCAFI_DEPRECATED_AON_TIMER_AON_SIZE_BYTES`.
 */
#define TOP_SCAFI_DEPRECATED_AON_TIMER_AON_SIZE_BYTES 0x40u

/**
 * Peripheral base address for ast in top scafi_deprecated.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_SCAFI_DEPRECATED_AST_BASE_ADDR 0x40480000u

/**
 * Peripheral size for ast in top scafi_deprecated.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_SCAFI_DEPRECATED_AST_BASE_ADDR and
 * `TOP_SCAFI_DEPRECATED_AST_BASE_ADDR + TOP_SCAFI_DEPRECATED_AST_SIZE_BYTES`.
 */
#define TOP_SCAFI_DEPRECATED_AST_SIZE_BYTES 0x400u

/**
 * Peripheral base address for core device on flash_ctrl in top scafi_deprecated.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_SCAFI_DEPRECATED_FLASH_CTRL_CORE_BASE_ADDR 0x41000000u

/**
 * Peripheral size for core device on flash_ctrl in top scafi_deprecated.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_SCAFI_DEPRECATED_FLASH_CTRL_CORE_BASE_ADDR and
 * `TOP_SCAFI_DEPRECATED_FLASH_CTRL_CORE_BASE_ADDR + TOP_SCAFI_DEPRECATED_FLASH_CTRL_CORE_SIZE_BYTES`.
 */
#define TOP_SCAFI_DEPRECATED_FLASH_CTRL_CORE_SIZE_BYTES 0x200u

/**
 * Peripheral base address for flash_macro_wrapper in top scafi_deprecated.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_SCAFI_DEPRECATED_FLASH_MACRO_WRAPPER_BASE_ADDR 0x41008000u

/**
 * Peripheral size for flash_macro_wrapper in top scafi_deprecated.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_SCAFI_DEPRECATED_FLASH_MACRO_WRAPPER_BASE_ADDR and
 * `TOP_SCAFI_DEPRECATED_FLASH_MACRO_WRAPPER_BASE_ADDR + TOP_SCAFI_DEPRECATED_FLASH_MACRO_WRAPPER_SIZE_BYTES`.
 */
#define TOP_SCAFI_DEPRECATED_FLASH_MACRO_WRAPPER_SIZE_BYTES 0x80u

/**
 * Peripheral base address for rv_plic in top scafi_deprecated.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_SCAFI_DEPRECATED_RV_PLIC_BASE_ADDR 0x48000000u

/**
 * Peripheral size for rv_plic in top scafi_deprecated.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_SCAFI_DEPRECATED_RV_PLIC_BASE_ADDR and
 * `TOP_SCAFI_DEPRECATED_RV_PLIC_BASE_ADDR + TOP_SCAFI_DEPRECATED_RV_PLIC_SIZE_BYTES`.
 */
#define TOP_SCAFI_DEPRECATED_RV_PLIC_SIZE_BYTES 0x8000000u

/**
 * Peripheral base address for aes in top scafi_deprecated.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_SCAFI_DEPRECATED_AES_BASE_ADDR 0x41100000u

/**
 * Peripheral size for aes in top scafi_deprecated.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_SCAFI_DEPRECATED_AES_BASE_ADDR and
 * `TOP_SCAFI_DEPRECATED_AES_BASE_ADDR + TOP_SCAFI_DEPRECATED_AES_SIZE_BYTES`.
 */
#define TOP_SCAFI_DEPRECATED_AES_SIZE_BYTES 0x100u

/**
 * Peripheral base address for regs device on sram_ctrl_main in top scafi_deprecated.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_SCAFI_DEPRECATED_SRAM_CTRL_MAIN_REGS_BASE_ADDR 0x411C0000u

/**
 * Peripheral size for regs device on sram_ctrl_main in top scafi_deprecated.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_SCAFI_DEPRECATED_SRAM_CTRL_MAIN_REGS_BASE_ADDR and
 * `TOP_SCAFI_DEPRECATED_SRAM_CTRL_MAIN_REGS_BASE_ADDR + TOP_SCAFI_DEPRECATED_SRAM_CTRL_MAIN_REGS_SIZE_BYTES`.
 */
#define TOP_SCAFI_DEPRECATED_SRAM_CTRL_MAIN_REGS_SIZE_BYTES 0x40u

/**
 * Peripheral base address for regs device on rom_ctrl in top scafi_deprecated.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_SCAFI_DEPRECATED_ROM_CTRL_REGS_BASE_ADDR 0x411E0000u

/**
 * Peripheral size for regs device on rom_ctrl in top scafi_deprecated.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_SCAFI_DEPRECATED_ROM_CTRL_REGS_BASE_ADDR and
 * `TOP_SCAFI_DEPRECATED_ROM_CTRL_REGS_BASE_ADDR + TOP_SCAFI_DEPRECATED_ROM_CTRL_REGS_SIZE_BYTES`.
 */
#define TOP_SCAFI_DEPRECATED_ROM_CTRL_REGS_SIZE_BYTES 0x80u

/**
 * Peripheral base address for cfg device on rv_core_ibex in top scafi_deprecated.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_SCAFI_DEPRECATED_RV_CORE_IBEX_CFG_BASE_ADDR 0x411F0000u

/**
 * Peripheral size for cfg device on rv_core_ibex in top scafi_deprecated.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_SCAFI_DEPRECATED_RV_CORE_IBEX_CFG_BASE_ADDR and
 * `TOP_SCAFI_DEPRECATED_RV_CORE_IBEX_CFG_BASE_ADDR + TOP_SCAFI_DEPRECATED_RV_CORE_IBEX_CFG_SIZE_BYTES`.
 */
#define TOP_SCAFI_DEPRECATED_RV_CORE_IBEX_CFG_SIZE_BYTES 0x100u


/**
 * Memory base address for mem memory on flash_ctrl in top scafi_deprecated.
 */
#define TOP_SCAFI_DEPRECATED_FLASH_CTRL_MEM_BASE_ADDR 0x20000000u

/**
 * Memory size for mem memory on flash_ctrl in top scafi_deprecated.
 */
#define TOP_SCAFI_DEPRECATED_FLASH_CTRL_MEM_SIZE_BYTES 0x10000u

/**
 * Memory base address for ram memory on sram_ctrl_main in top scafi_deprecated.
 */
#define TOP_SCAFI_DEPRECATED_SRAM_CTRL_MAIN_RAM_BASE_ADDR 0x10000000u

/**
 * Memory size for ram memory on sram_ctrl_main in top scafi_deprecated.
 */
#define TOP_SCAFI_DEPRECATED_SRAM_CTRL_MAIN_RAM_SIZE_BYTES 0x20000u

/**
 * Memory base address for rom memory on rom_ctrl in top scafi_deprecated.
 */
#define TOP_SCAFI_DEPRECATED_ROM_CTRL_ROM_BASE_ADDR 0x8000u

/**
 * Memory size for rom memory on rom_ctrl in top scafi_deprecated.
 */
#define TOP_SCAFI_DEPRECATED_ROM_CTRL_ROM_SIZE_BYTES 0x8000u


/**
 * PLIC Interrupt Source Peripheral.
 *
 * Enumeration used to determine which peripheral asserted the corresponding
 * interrupt.
 */
typedef enum top_scafi_deprecated_plic_peripheral {
  kTopScafiDeprecatedPlicPeripheralUnknown = 0, /**< Unknown Peripheral */
  kTopScafiDeprecatedPlicPeripheralUart0 = 1, /**< uart0 */
  kTopScafiDeprecatedPlicPeripheralUart1 = 2, /**< uart1 */
  kTopScafiDeprecatedPlicPeripheralGpio = 3, /**< gpio */
  kTopScafiDeprecatedPlicPeripheralSpiDevice = 4, /**< spi_device */
  kTopScafiDeprecatedPlicPeripheralSpiHost0 = 5, /**< spi_host0 */
  kTopScafiDeprecatedPlicPeripheralUsbdev = 6, /**< usbdev */
  kTopScafiDeprecatedPlicPeripheralPwrmgrAon = 7, /**< pwrmgr_aon */
  kTopScafiDeprecatedPlicPeripheralAonTimerAon = 8, /**< aon_timer_aon */
  kTopScafiDeprecatedPlicPeripheralFlashCtrl = 9, /**< flash_ctrl */
  kTopScafiDeprecatedPlicPeripheralLast = 9, /**< \internal Final PLIC peripheral */
} top_scafi_deprecated_plic_peripheral_t;

/**
 * PLIC Interrupt Source.
 *
 * Enumeration of all PLIC interrupt sources. The interrupt sources belonging to
 * the same peripheral are guaranteed to be consecutive.
 */
typedef enum top_scafi_deprecated_plic_irq_id {
  kTopScafiDeprecatedPlicIrqIdNone = 0, /**< No Interrupt */
  kTopScafiDeprecatedPlicIrqIdUart0TxWatermark = 1, /**< uart0_tx_watermark */
  kTopScafiDeprecatedPlicIrqIdUart0RxWatermark = 2, /**< uart0_rx_watermark */
  kTopScafiDeprecatedPlicIrqIdUart0TxDone = 3, /**< uart0_tx_done */
  kTopScafiDeprecatedPlicIrqIdUart0RxOverflow = 4, /**< uart0_rx_overflow */
  kTopScafiDeprecatedPlicIrqIdUart0RxFrameErr = 5, /**< uart0_rx_frame_err */
  kTopScafiDeprecatedPlicIrqIdUart0RxBreakErr = 6, /**< uart0_rx_break_err */
  kTopScafiDeprecatedPlicIrqIdUart0RxTimeout = 7, /**< uart0_rx_timeout */
  kTopScafiDeprecatedPlicIrqIdUart0RxParityErr = 8, /**< uart0_rx_parity_err */
  kTopScafiDeprecatedPlicIrqIdUart0TxEmpty = 9, /**< uart0_tx_empty */
  kTopScafiDeprecatedPlicIrqIdUart1TxWatermark = 10, /**< uart1_tx_watermark */
  kTopScafiDeprecatedPlicIrqIdUart1RxWatermark = 11, /**< uart1_rx_watermark */
  kTopScafiDeprecatedPlicIrqIdUart1TxDone = 12, /**< uart1_tx_done */
  kTopScafiDeprecatedPlicIrqIdUart1RxOverflow = 13, /**< uart1_rx_overflow */
  kTopScafiDeprecatedPlicIrqIdUart1RxFrameErr = 14, /**< uart1_rx_frame_err */
  kTopScafiDeprecatedPlicIrqIdUart1RxBreakErr = 15, /**< uart1_rx_break_err */
  kTopScafiDeprecatedPlicIrqIdUart1RxTimeout = 16, /**< uart1_rx_timeout */
  kTopScafiDeprecatedPlicIrqIdUart1RxParityErr = 17, /**< uart1_rx_parity_err */
  kTopScafiDeprecatedPlicIrqIdUart1TxEmpty = 18, /**< uart1_tx_empty */
  kTopScafiDeprecatedPlicIrqIdGpioGpio0 = 19, /**< gpio_gpio 0 */
  kTopScafiDeprecatedPlicIrqIdGpioGpio1 = 20, /**< gpio_gpio 1 */
  kTopScafiDeprecatedPlicIrqIdGpioGpio2 = 21, /**< gpio_gpio 2 */
  kTopScafiDeprecatedPlicIrqIdGpioGpio3 = 22, /**< gpio_gpio 3 */
  kTopScafiDeprecatedPlicIrqIdGpioGpio4 = 23, /**< gpio_gpio 4 */
  kTopScafiDeprecatedPlicIrqIdGpioGpio5 = 24, /**< gpio_gpio 5 */
  kTopScafiDeprecatedPlicIrqIdGpioGpio6 = 25, /**< gpio_gpio 6 */
  kTopScafiDeprecatedPlicIrqIdGpioGpio7 = 26, /**< gpio_gpio 7 */
  kTopScafiDeprecatedPlicIrqIdGpioGpio8 = 27, /**< gpio_gpio 8 */
  kTopScafiDeprecatedPlicIrqIdGpioGpio9 = 28, /**< gpio_gpio 9 */
  kTopScafiDeprecatedPlicIrqIdGpioGpio10 = 29, /**< gpio_gpio 10 */
  kTopScafiDeprecatedPlicIrqIdGpioGpio11 = 30, /**< gpio_gpio 11 */
  kTopScafiDeprecatedPlicIrqIdGpioGpio12 = 31, /**< gpio_gpio 12 */
  kTopScafiDeprecatedPlicIrqIdGpioGpio13 = 32, /**< gpio_gpio 13 */
  kTopScafiDeprecatedPlicIrqIdGpioGpio14 = 33, /**< gpio_gpio 14 */
  kTopScafiDeprecatedPlicIrqIdGpioGpio15 = 34, /**< gpio_gpio 15 */
  kTopScafiDeprecatedPlicIrqIdGpioGpio16 = 35, /**< gpio_gpio 16 */
  kTopScafiDeprecatedPlicIrqIdGpioGpio17 = 36, /**< gpio_gpio 17 */
  kTopScafiDeprecatedPlicIrqIdGpioGpio18 = 37, /**< gpio_gpio 18 */
  kTopScafiDeprecatedPlicIrqIdGpioGpio19 = 38, /**< gpio_gpio 19 */
  kTopScafiDeprecatedPlicIrqIdGpioGpio20 = 39, /**< gpio_gpio 20 */
  kTopScafiDeprecatedPlicIrqIdGpioGpio21 = 40, /**< gpio_gpio 21 */
  kTopScafiDeprecatedPlicIrqIdGpioGpio22 = 41, /**< gpio_gpio 22 */
  kTopScafiDeprecatedPlicIrqIdGpioGpio23 = 42, /**< gpio_gpio 23 */
  kTopScafiDeprecatedPlicIrqIdGpioGpio24 = 43, /**< gpio_gpio 24 */
  kTopScafiDeprecatedPlicIrqIdGpioGpio25 = 44, /**< gpio_gpio 25 */
  kTopScafiDeprecatedPlicIrqIdGpioGpio26 = 45, /**< gpio_gpio 26 */
  kTopScafiDeprecatedPlicIrqIdGpioGpio27 = 46, /**< gpio_gpio 27 */
  kTopScafiDeprecatedPlicIrqIdGpioGpio28 = 47, /**< gpio_gpio 28 */
  kTopScafiDeprecatedPlicIrqIdGpioGpio29 = 48, /**< gpio_gpio 29 */
  kTopScafiDeprecatedPlicIrqIdGpioGpio30 = 49, /**< gpio_gpio 30 */
  kTopScafiDeprecatedPlicIrqIdGpioGpio31 = 50, /**< gpio_gpio 31 */
  kTopScafiDeprecatedPlicIrqIdSpiDeviceUploadCmdfifoNotEmpty = 51, /**< spi_device_upload_cmdfifo_not_empty */
  kTopScafiDeprecatedPlicIrqIdSpiDeviceUploadPayloadNotEmpty = 52, /**< spi_device_upload_payload_not_empty */
  kTopScafiDeprecatedPlicIrqIdSpiDeviceUploadPayloadOverflow = 53, /**< spi_device_upload_payload_overflow */
  kTopScafiDeprecatedPlicIrqIdSpiDeviceReadbufWatermark = 54, /**< spi_device_readbuf_watermark */
  kTopScafiDeprecatedPlicIrqIdSpiDeviceReadbufFlip = 55, /**< spi_device_readbuf_flip */
  kTopScafiDeprecatedPlicIrqIdSpiDeviceTpmHeaderNotEmpty = 56, /**< spi_device_tpm_header_not_empty */
  kTopScafiDeprecatedPlicIrqIdSpiDeviceTpmRdfifoCmdEnd = 57, /**< spi_device_tpm_rdfifo_cmd_end */
  kTopScafiDeprecatedPlicIrqIdSpiDeviceTpmRdfifoDrop = 58, /**< spi_device_tpm_rdfifo_drop */
  kTopScafiDeprecatedPlicIrqIdSpiHost0Error = 59, /**< spi_host0_error */
  kTopScafiDeprecatedPlicIrqIdSpiHost0SpiEvent = 60, /**< spi_host0_spi_event */
  kTopScafiDeprecatedPlicIrqIdUsbdevPktReceived = 61, /**< usbdev_pkt_received */
  kTopScafiDeprecatedPlicIrqIdUsbdevPktSent = 62, /**< usbdev_pkt_sent */
  kTopScafiDeprecatedPlicIrqIdUsbdevDisconnected = 63, /**< usbdev_disconnected */
  kTopScafiDeprecatedPlicIrqIdUsbdevHostLost = 64, /**< usbdev_host_lost */
  kTopScafiDeprecatedPlicIrqIdUsbdevLinkReset = 65, /**< usbdev_link_reset */
  kTopScafiDeprecatedPlicIrqIdUsbdevLinkSuspend = 66, /**< usbdev_link_suspend */
  kTopScafiDeprecatedPlicIrqIdUsbdevLinkResume = 67, /**< usbdev_link_resume */
  kTopScafiDeprecatedPlicIrqIdUsbdevAvOutEmpty = 68, /**< usbdev_av_out_empty */
  kTopScafiDeprecatedPlicIrqIdUsbdevRxFull = 69, /**< usbdev_rx_full */
  kTopScafiDeprecatedPlicIrqIdUsbdevAvOverflow = 70, /**< usbdev_av_overflow */
  kTopScafiDeprecatedPlicIrqIdUsbdevLinkInErr = 71, /**< usbdev_link_in_err */
  kTopScafiDeprecatedPlicIrqIdUsbdevRxCrcErr = 72, /**< usbdev_rx_crc_err */
  kTopScafiDeprecatedPlicIrqIdUsbdevRxPidErr = 73, /**< usbdev_rx_pid_err */
  kTopScafiDeprecatedPlicIrqIdUsbdevRxBitstuffErr = 74, /**< usbdev_rx_bitstuff_err */
  kTopScafiDeprecatedPlicIrqIdUsbdevFrame = 75, /**< usbdev_frame */
  kTopScafiDeprecatedPlicIrqIdUsbdevPowered = 76, /**< usbdev_powered */
  kTopScafiDeprecatedPlicIrqIdUsbdevLinkOutErr = 77, /**< usbdev_link_out_err */
  kTopScafiDeprecatedPlicIrqIdUsbdevAvSetupEmpty = 78, /**< usbdev_av_setup_empty */
  kTopScafiDeprecatedPlicIrqIdPwrmgrAonWakeup = 79, /**< pwrmgr_aon_wakeup */
  kTopScafiDeprecatedPlicIrqIdAonTimerAonWkupTimerExpired = 80, /**< aon_timer_aon_wkup_timer_expired */
  kTopScafiDeprecatedPlicIrqIdAonTimerAonWdogTimerBark = 81, /**< aon_timer_aon_wdog_timer_bark */
  kTopScafiDeprecatedPlicIrqIdFlashCtrlProgEmpty = 82, /**< flash_ctrl_prog_empty */
  kTopScafiDeprecatedPlicIrqIdFlashCtrlProgLvl = 83, /**< flash_ctrl_prog_lvl */
  kTopScafiDeprecatedPlicIrqIdFlashCtrlRdFull = 84, /**< flash_ctrl_rd_full */
  kTopScafiDeprecatedPlicIrqIdFlashCtrlRdLvl = 85, /**< flash_ctrl_rd_lvl */
  kTopScafiDeprecatedPlicIrqIdFlashCtrlOpDone = 86, /**< flash_ctrl_op_done */
  kTopScafiDeprecatedPlicIrqIdFlashCtrlCorrErr = 87, /**< flash_ctrl_corr_err */
  kTopScafiDeprecatedPlicIrqIdLast = 87, /**< \internal The Last Valid Interrupt ID. */
} top_scafi_deprecated_plic_irq_id_t;

/**
 * PLIC Interrupt Source to Peripheral Map
 *
 * This array is a mapping from `top_scafi_deprecated_plic_irq_id_t` to
 * `top_scafi_deprecated_plic_peripheral_t`.
 */
extern const top_scafi_deprecated_plic_peripheral_t
    top_scafi_deprecated_plic_interrupt_for_peripheral[88];

/**
 * PLIC Interrupt Target.
 *
 * Enumeration used to determine which set of IE, CC, threshold registers to
 * access for a given interrupt target.
 */
typedef enum top_scafi_deprecated_plic_target {
  kTopScafiDeprecatedPlicTargetIbex0 = 0, /**< Ibex Core 0 */
  kTopScafiDeprecatedPlicTargetLast = 0, /**< \internal Final PLIC target */
} top_scafi_deprecated_plic_target_t;


#define PINMUX_MIO_PERIPH_INSEL_IDX_OFFSET 2

// PERIPH_INSEL ranges from 0 to NUM_MIO_PADS + 2 -1}
//  0 and 1 are tied to value 0 and 1
#define NUM_MIO_PADS 47
#define NUM_DIO_PADS 14

#define PINMUX_PERIPH_OUTSEL_IDX_OFFSET 3

/**
 * Pinmux Peripheral Input.
 */
typedef enum top_scafi_deprecated_pinmux_peripheral_in {
  kTopScafiDeprecatedPinmuxPeripheralInGpioGpio0 = 0, /**< Peripheral Input 0 */
  kTopScafiDeprecatedPinmuxPeripheralInGpioGpio1 = 1, /**< Peripheral Input 1 */
  kTopScafiDeprecatedPinmuxPeripheralInGpioGpio2 = 2, /**< Peripheral Input 2 */
  kTopScafiDeprecatedPinmuxPeripheralInGpioGpio3 = 3, /**< Peripheral Input 3 */
  kTopScafiDeprecatedPinmuxPeripheralInGpioGpio4 = 4, /**< Peripheral Input 4 */
  kTopScafiDeprecatedPinmuxPeripheralInGpioGpio5 = 5, /**< Peripheral Input 5 */
  kTopScafiDeprecatedPinmuxPeripheralInGpioGpio6 = 6, /**< Peripheral Input 6 */
  kTopScafiDeprecatedPinmuxPeripheralInGpioGpio7 = 7, /**< Peripheral Input 7 */
  kTopScafiDeprecatedPinmuxPeripheralInGpioGpio8 = 8, /**< Peripheral Input 8 */
  kTopScafiDeprecatedPinmuxPeripheralInGpioGpio9 = 9, /**< Peripheral Input 9 */
  kTopScafiDeprecatedPinmuxPeripheralInGpioGpio10 = 10, /**< Peripheral Input 10 */
  kTopScafiDeprecatedPinmuxPeripheralInGpioGpio11 = 11, /**< Peripheral Input 11 */
  kTopScafiDeprecatedPinmuxPeripheralInGpioGpio12 = 12, /**< Peripheral Input 12 */
  kTopScafiDeprecatedPinmuxPeripheralInGpioGpio13 = 13, /**< Peripheral Input 13 */
  kTopScafiDeprecatedPinmuxPeripheralInGpioGpio14 = 14, /**< Peripheral Input 14 */
  kTopScafiDeprecatedPinmuxPeripheralInGpioGpio15 = 15, /**< Peripheral Input 15 */
  kTopScafiDeprecatedPinmuxPeripheralInGpioGpio16 = 16, /**< Peripheral Input 16 */
  kTopScafiDeprecatedPinmuxPeripheralInGpioGpio17 = 17, /**< Peripheral Input 17 */
  kTopScafiDeprecatedPinmuxPeripheralInGpioGpio18 = 18, /**< Peripheral Input 18 */
  kTopScafiDeprecatedPinmuxPeripheralInGpioGpio19 = 19, /**< Peripheral Input 19 */
  kTopScafiDeprecatedPinmuxPeripheralInGpioGpio20 = 20, /**< Peripheral Input 20 */
  kTopScafiDeprecatedPinmuxPeripheralInGpioGpio21 = 21, /**< Peripheral Input 21 */
  kTopScafiDeprecatedPinmuxPeripheralInGpioGpio22 = 22, /**< Peripheral Input 22 */
  kTopScafiDeprecatedPinmuxPeripheralInGpioGpio23 = 23, /**< Peripheral Input 23 */
  kTopScafiDeprecatedPinmuxPeripheralInGpioGpio24 = 24, /**< Peripheral Input 24 */
  kTopScafiDeprecatedPinmuxPeripheralInGpioGpio25 = 25, /**< Peripheral Input 25 */
  kTopScafiDeprecatedPinmuxPeripheralInGpioGpio26 = 26, /**< Peripheral Input 26 */
  kTopScafiDeprecatedPinmuxPeripheralInGpioGpio27 = 27, /**< Peripheral Input 27 */
  kTopScafiDeprecatedPinmuxPeripheralInGpioGpio28 = 28, /**< Peripheral Input 28 */
  kTopScafiDeprecatedPinmuxPeripheralInGpioGpio29 = 29, /**< Peripheral Input 29 */
  kTopScafiDeprecatedPinmuxPeripheralInGpioGpio30 = 30, /**< Peripheral Input 30 */
  kTopScafiDeprecatedPinmuxPeripheralInGpioGpio31 = 31, /**< Peripheral Input 31 */
  kTopScafiDeprecatedPinmuxPeripheralInUart0Rx = 32, /**< Peripheral Input 32 */
  kTopScafiDeprecatedPinmuxPeripheralInUart1Rx = 33, /**< Peripheral Input 33 */
  kTopScafiDeprecatedPinmuxPeripheralInUsbdevSense = 34, /**< Peripheral Input 34 */
  kTopScafiDeprecatedPinmuxPeripheralInLast = 34, /**< \internal Last valid peripheral input */
} top_scafi_deprecated_pinmux_peripheral_in_t;

/**
 * Pinmux MIO Input Selector.
 */
typedef enum top_scafi_deprecated_pinmux_insel {
  kTopScafiDeprecatedPinmuxInselConstantZero = 0, /**< Tie constantly to zero */
  kTopScafiDeprecatedPinmuxInselConstantOne = 1, /**< Tie constantly to one */
  kTopScafiDeprecatedPinmuxInselIoa0 = 2, /**< MIO Pad 0 */
  kTopScafiDeprecatedPinmuxInselIoa1 = 3, /**< MIO Pad 1 */
  kTopScafiDeprecatedPinmuxInselIoa2 = 4, /**< MIO Pad 2 */
  kTopScafiDeprecatedPinmuxInselIoa3 = 5, /**< MIO Pad 3 */
  kTopScafiDeprecatedPinmuxInselIoa4 = 6, /**< MIO Pad 4 */
  kTopScafiDeprecatedPinmuxInselIoa5 = 7, /**< MIO Pad 5 */
  kTopScafiDeprecatedPinmuxInselIoa6 = 8, /**< MIO Pad 6 */
  kTopScafiDeprecatedPinmuxInselIoa7 = 9, /**< MIO Pad 7 */
  kTopScafiDeprecatedPinmuxInselIoa8 = 10, /**< MIO Pad 8 */
  kTopScafiDeprecatedPinmuxInselIob0 = 11, /**< MIO Pad 9 */
  kTopScafiDeprecatedPinmuxInselIob1 = 12, /**< MIO Pad 10 */
  kTopScafiDeprecatedPinmuxInselIob2 = 13, /**< MIO Pad 11 */
  kTopScafiDeprecatedPinmuxInselIob3 = 14, /**< MIO Pad 12 */
  kTopScafiDeprecatedPinmuxInselIob4 = 15, /**< MIO Pad 13 */
  kTopScafiDeprecatedPinmuxInselIob5 = 16, /**< MIO Pad 14 */
  kTopScafiDeprecatedPinmuxInselIob6 = 17, /**< MIO Pad 15 */
  kTopScafiDeprecatedPinmuxInselIob7 = 18, /**< MIO Pad 16 */
  kTopScafiDeprecatedPinmuxInselIob8 = 19, /**< MIO Pad 17 */
  kTopScafiDeprecatedPinmuxInselIob9 = 20, /**< MIO Pad 18 */
  kTopScafiDeprecatedPinmuxInselIob10 = 21, /**< MIO Pad 19 */
  kTopScafiDeprecatedPinmuxInselIob11 = 22, /**< MIO Pad 20 */
  kTopScafiDeprecatedPinmuxInselIob12 = 23, /**< MIO Pad 21 */
  kTopScafiDeprecatedPinmuxInselIoc0 = 24, /**< MIO Pad 22 */
  kTopScafiDeprecatedPinmuxInselIoc1 = 25, /**< MIO Pad 23 */
  kTopScafiDeprecatedPinmuxInselIoc2 = 26, /**< MIO Pad 24 */
  kTopScafiDeprecatedPinmuxInselIoc3 = 27, /**< MIO Pad 25 */
  kTopScafiDeprecatedPinmuxInselIoc4 = 28, /**< MIO Pad 26 */
  kTopScafiDeprecatedPinmuxInselIoc5 = 29, /**< MIO Pad 27 */
  kTopScafiDeprecatedPinmuxInselIoc6 = 30, /**< MIO Pad 28 */
  kTopScafiDeprecatedPinmuxInselIoc7 = 31, /**< MIO Pad 29 */
  kTopScafiDeprecatedPinmuxInselIoc8 = 32, /**< MIO Pad 30 */
  kTopScafiDeprecatedPinmuxInselIoc9 = 33, /**< MIO Pad 31 */
  kTopScafiDeprecatedPinmuxInselIoc10 = 34, /**< MIO Pad 32 */
  kTopScafiDeprecatedPinmuxInselIoc11 = 35, /**< MIO Pad 33 */
  kTopScafiDeprecatedPinmuxInselIoc12 = 36, /**< MIO Pad 34 */
  kTopScafiDeprecatedPinmuxInselIor0 = 37, /**< MIO Pad 35 */
  kTopScafiDeprecatedPinmuxInselIor1 = 38, /**< MIO Pad 36 */
  kTopScafiDeprecatedPinmuxInselIor2 = 39, /**< MIO Pad 37 */
  kTopScafiDeprecatedPinmuxInselIor3 = 40, /**< MIO Pad 38 */
  kTopScafiDeprecatedPinmuxInselIor4 = 41, /**< MIO Pad 39 */
  kTopScafiDeprecatedPinmuxInselIor5 = 42, /**< MIO Pad 40 */
  kTopScafiDeprecatedPinmuxInselIor6 = 43, /**< MIO Pad 41 */
  kTopScafiDeprecatedPinmuxInselIor7 = 44, /**< MIO Pad 42 */
  kTopScafiDeprecatedPinmuxInselIor10 = 45, /**< MIO Pad 43 */
  kTopScafiDeprecatedPinmuxInselIor11 = 46, /**< MIO Pad 44 */
  kTopScafiDeprecatedPinmuxInselIor12 = 47, /**< MIO Pad 45 */
  kTopScafiDeprecatedPinmuxInselIor13 = 48, /**< MIO Pad 46 */
  kTopScafiDeprecatedPinmuxInselLast = 48, /**< \internal Last valid insel value */
} top_scafi_deprecated_pinmux_insel_t;

/**
 * Pinmux MIO Output.
 */
typedef enum top_scafi_deprecated_pinmux_mio_out {
  kTopScafiDeprecatedPinmuxMioOutIoa0 = 0, /**< MIO Pad 0 */
  kTopScafiDeprecatedPinmuxMioOutIoa1 = 1, /**< MIO Pad 1 */
  kTopScafiDeprecatedPinmuxMioOutIoa2 = 2, /**< MIO Pad 2 */
  kTopScafiDeprecatedPinmuxMioOutIoa3 = 3, /**< MIO Pad 3 */
  kTopScafiDeprecatedPinmuxMioOutIoa4 = 4, /**< MIO Pad 4 */
  kTopScafiDeprecatedPinmuxMioOutIoa5 = 5, /**< MIO Pad 5 */
  kTopScafiDeprecatedPinmuxMioOutIoa6 = 6, /**< MIO Pad 6 */
  kTopScafiDeprecatedPinmuxMioOutIoa7 = 7, /**< MIO Pad 7 */
  kTopScafiDeprecatedPinmuxMioOutIoa8 = 8, /**< MIO Pad 8 */
  kTopScafiDeprecatedPinmuxMioOutIob0 = 9, /**< MIO Pad 9 */
  kTopScafiDeprecatedPinmuxMioOutIob1 = 10, /**< MIO Pad 10 */
  kTopScafiDeprecatedPinmuxMioOutIob2 = 11, /**< MIO Pad 11 */
  kTopScafiDeprecatedPinmuxMioOutIob3 = 12, /**< MIO Pad 12 */
  kTopScafiDeprecatedPinmuxMioOutIob4 = 13, /**< MIO Pad 13 */
  kTopScafiDeprecatedPinmuxMioOutIob5 = 14, /**< MIO Pad 14 */
  kTopScafiDeprecatedPinmuxMioOutIob6 = 15, /**< MIO Pad 15 */
  kTopScafiDeprecatedPinmuxMioOutIob7 = 16, /**< MIO Pad 16 */
  kTopScafiDeprecatedPinmuxMioOutIob8 = 17, /**< MIO Pad 17 */
  kTopScafiDeprecatedPinmuxMioOutIob9 = 18, /**< MIO Pad 18 */
  kTopScafiDeprecatedPinmuxMioOutIob10 = 19, /**< MIO Pad 19 */
  kTopScafiDeprecatedPinmuxMioOutIob11 = 20, /**< MIO Pad 20 */
  kTopScafiDeprecatedPinmuxMioOutIob12 = 21, /**< MIO Pad 21 */
  kTopScafiDeprecatedPinmuxMioOutIoc0 = 22, /**< MIO Pad 22 */
  kTopScafiDeprecatedPinmuxMioOutIoc1 = 23, /**< MIO Pad 23 */
  kTopScafiDeprecatedPinmuxMioOutIoc2 = 24, /**< MIO Pad 24 */
  kTopScafiDeprecatedPinmuxMioOutIoc3 = 25, /**< MIO Pad 25 */
  kTopScafiDeprecatedPinmuxMioOutIoc4 = 26, /**< MIO Pad 26 */
  kTopScafiDeprecatedPinmuxMioOutIoc5 = 27, /**< MIO Pad 27 */
  kTopScafiDeprecatedPinmuxMioOutIoc6 = 28, /**< MIO Pad 28 */
  kTopScafiDeprecatedPinmuxMioOutIoc7 = 29, /**< MIO Pad 29 */
  kTopScafiDeprecatedPinmuxMioOutIoc8 = 30, /**< MIO Pad 30 */
  kTopScafiDeprecatedPinmuxMioOutIoc9 = 31, /**< MIO Pad 31 */
  kTopScafiDeprecatedPinmuxMioOutIoc10 = 32, /**< MIO Pad 32 */
  kTopScafiDeprecatedPinmuxMioOutIoc11 = 33, /**< MIO Pad 33 */
  kTopScafiDeprecatedPinmuxMioOutIoc12 = 34, /**< MIO Pad 34 */
  kTopScafiDeprecatedPinmuxMioOutIor0 = 35, /**< MIO Pad 35 */
  kTopScafiDeprecatedPinmuxMioOutIor1 = 36, /**< MIO Pad 36 */
  kTopScafiDeprecatedPinmuxMioOutIor2 = 37, /**< MIO Pad 37 */
  kTopScafiDeprecatedPinmuxMioOutIor3 = 38, /**< MIO Pad 38 */
  kTopScafiDeprecatedPinmuxMioOutIor4 = 39, /**< MIO Pad 39 */
  kTopScafiDeprecatedPinmuxMioOutIor5 = 40, /**< MIO Pad 40 */
  kTopScafiDeprecatedPinmuxMioOutIor6 = 41, /**< MIO Pad 41 */
  kTopScafiDeprecatedPinmuxMioOutIor7 = 42, /**< MIO Pad 42 */
  kTopScafiDeprecatedPinmuxMioOutIor10 = 43, /**< MIO Pad 43 */
  kTopScafiDeprecatedPinmuxMioOutIor11 = 44, /**< MIO Pad 44 */
  kTopScafiDeprecatedPinmuxMioOutIor12 = 45, /**< MIO Pad 45 */
  kTopScafiDeprecatedPinmuxMioOutIor13 = 46, /**< MIO Pad 46 */
  kTopScafiDeprecatedPinmuxMioOutLast = 46, /**< \internal Last valid mio output */
} top_scafi_deprecated_pinmux_mio_out_t;

/**
 * Pinmux Peripheral Output Selector.
 */
typedef enum top_scafi_deprecated_pinmux_outsel {
  kTopScafiDeprecatedPinmuxOutselConstantZero = 0, /**< Tie constantly to zero */
  kTopScafiDeprecatedPinmuxOutselConstantOne = 1, /**< Tie constantly to one */
  kTopScafiDeprecatedPinmuxOutselConstantHighZ = 2, /**< Tie constantly to high-Z */
  kTopScafiDeprecatedPinmuxOutselGpioGpio0 = 3, /**< Peripheral Output 0 */
  kTopScafiDeprecatedPinmuxOutselGpioGpio1 = 4, /**< Peripheral Output 1 */
  kTopScafiDeprecatedPinmuxOutselGpioGpio2 = 5, /**< Peripheral Output 2 */
  kTopScafiDeprecatedPinmuxOutselGpioGpio3 = 6, /**< Peripheral Output 3 */
  kTopScafiDeprecatedPinmuxOutselGpioGpio4 = 7, /**< Peripheral Output 4 */
  kTopScafiDeprecatedPinmuxOutselGpioGpio5 = 8, /**< Peripheral Output 5 */
  kTopScafiDeprecatedPinmuxOutselGpioGpio6 = 9, /**< Peripheral Output 6 */
  kTopScafiDeprecatedPinmuxOutselGpioGpio7 = 10, /**< Peripheral Output 7 */
  kTopScafiDeprecatedPinmuxOutselGpioGpio8 = 11, /**< Peripheral Output 8 */
  kTopScafiDeprecatedPinmuxOutselGpioGpio9 = 12, /**< Peripheral Output 9 */
  kTopScafiDeprecatedPinmuxOutselGpioGpio10 = 13, /**< Peripheral Output 10 */
  kTopScafiDeprecatedPinmuxOutselGpioGpio11 = 14, /**< Peripheral Output 11 */
  kTopScafiDeprecatedPinmuxOutselGpioGpio12 = 15, /**< Peripheral Output 12 */
  kTopScafiDeprecatedPinmuxOutselGpioGpio13 = 16, /**< Peripheral Output 13 */
  kTopScafiDeprecatedPinmuxOutselGpioGpio14 = 17, /**< Peripheral Output 14 */
  kTopScafiDeprecatedPinmuxOutselGpioGpio15 = 18, /**< Peripheral Output 15 */
  kTopScafiDeprecatedPinmuxOutselGpioGpio16 = 19, /**< Peripheral Output 16 */
  kTopScafiDeprecatedPinmuxOutselGpioGpio17 = 20, /**< Peripheral Output 17 */
  kTopScafiDeprecatedPinmuxOutselGpioGpio18 = 21, /**< Peripheral Output 18 */
  kTopScafiDeprecatedPinmuxOutselGpioGpio19 = 22, /**< Peripheral Output 19 */
  kTopScafiDeprecatedPinmuxOutselGpioGpio20 = 23, /**< Peripheral Output 20 */
  kTopScafiDeprecatedPinmuxOutselGpioGpio21 = 24, /**< Peripheral Output 21 */
  kTopScafiDeprecatedPinmuxOutselGpioGpio22 = 25, /**< Peripheral Output 22 */
  kTopScafiDeprecatedPinmuxOutselGpioGpio23 = 26, /**< Peripheral Output 23 */
  kTopScafiDeprecatedPinmuxOutselGpioGpio24 = 27, /**< Peripheral Output 24 */
  kTopScafiDeprecatedPinmuxOutselGpioGpio25 = 28, /**< Peripheral Output 25 */
  kTopScafiDeprecatedPinmuxOutselGpioGpio26 = 29, /**< Peripheral Output 26 */
  kTopScafiDeprecatedPinmuxOutselGpioGpio27 = 30, /**< Peripheral Output 27 */
  kTopScafiDeprecatedPinmuxOutselGpioGpio28 = 31, /**< Peripheral Output 28 */
  kTopScafiDeprecatedPinmuxOutselGpioGpio29 = 32, /**< Peripheral Output 29 */
  kTopScafiDeprecatedPinmuxOutselGpioGpio30 = 33, /**< Peripheral Output 30 */
  kTopScafiDeprecatedPinmuxOutselGpioGpio31 = 34, /**< Peripheral Output 31 */
  kTopScafiDeprecatedPinmuxOutselUart0Tx = 35, /**< Peripheral Output 32 */
  kTopScafiDeprecatedPinmuxOutselUart1Tx = 36, /**< Peripheral Output 33 */
  kTopScafiDeprecatedPinmuxOutselLast = 36, /**< \internal Last valid outsel value */
} top_scafi_deprecated_pinmux_outsel_t;

/**
 * Dedicated Pad Selects
 */
typedef enum top_scafi_deprecated_direct_pads {
  kTopScafiDeprecatedDirectPadsSpiHost0Sd0 = 0, /**<  */
  kTopScafiDeprecatedDirectPadsSpiHost0Sd1 = 1, /**<  */
  kTopScafiDeprecatedDirectPadsSpiHost0Sd2 = 2, /**<  */
  kTopScafiDeprecatedDirectPadsSpiHost0Sd3 = 3, /**<  */
  kTopScafiDeprecatedDirectPadsSpiDeviceSd0 = 4, /**<  */
  kTopScafiDeprecatedDirectPadsSpiDeviceSd1 = 5, /**<  */
  kTopScafiDeprecatedDirectPadsSpiDeviceSd2 = 6, /**<  */
  kTopScafiDeprecatedDirectPadsSpiDeviceSd3 = 7, /**<  */
  kTopScafiDeprecatedDirectPadsUsbdevUsbDp = 8, /**<  */
  kTopScafiDeprecatedDirectPadsUsbdevUsbDn = 9, /**<  */
  kTopScafiDeprecatedDirectPadsSpiDeviceSck = 10, /**<  */
  kTopScafiDeprecatedDirectPadsSpiDeviceCsb = 11, /**<  */
  kTopScafiDeprecatedDirectPadsSpiHost0Sck = 12, /**<  */
  kTopScafiDeprecatedDirectPadsSpiHost0Csb = 13, /**<  */
  kTopScafiDeprecatedDirectPadsLast = 13, /**< \internal Last valid direct pad */
} top_scafi_deprecated_direct_pads_t;

/**
 * Muxed Pad Selects
 */
typedef enum top_scafi_deprecated_muxed_pads {
  kTopScafiDeprecatedMuxedPadsIoa0 = 0, /**<  */
  kTopScafiDeprecatedMuxedPadsIoa1 = 1, /**<  */
  kTopScafiDeprecatedMuxedPadsIoa2 = 2, /**<  */
  kTopScafiDeprecatedMuxedPadsIoa3 = 3, /**<  */
  kTopScafiDeprecatedMuxedPadsIoa4 = 4, /**<  */
  kTopScafiDeprecatedMuxedPadsIoa5 = 5, /**<  */
  kTopScafiDeprecatedMuxedPadsIoa6 = 6, /**<  */
  kTopScafiDeprecatedMuxedPadsIoa7 = 7, /**<  */
  kTopScafiDeprecatedMuxedPadsIoa8 = 8, /**<  */
  kTopScafiDeprecatedMuxedPadsIob0 = 9, /**<  */
  kTopScafiDeprecatedMuxedPadsIob1 = 10, /**<  */
  kTopScafiDeprecatedMuxedPadsIob2 = 11, /**<  */
  kTopScafiDeprecatedMuxedPadsIob3 = 12, /**<  */
  kTopScafiDeprecatedMuxedPadsIob4 = 13, /**<  */
  kTopScafiDeprecatedMuxedPadsIob5 = 14, /**<  */
  kTopScafiDeprecatedMuxedPadsIob6 = 15, /**<  */
  kTopScafiDeprecatedMuxedPadsIob7 = 16, /**<  */
  kTopScafiDeprecatedMuxedPadsIob8 = 17, /**<  */
  kTopScafiDeprecatedMuxedPadsIob9 = 18, /**<  */
  kTopScafiDeprecatedMuxedPadsIob10 = 19, /**<  */
  kTopScafiDeprecatedMuxedPadsIob11 = 20, /**<  */
  kTopScafiDeprecatedMuxedPadsIob12 = 21, /**<  */
  kTopScafiDeprecatedMuxedPadsIoc0 = 22, /**<  */
  kTopScafiDeprecatedMuxedPadsIoc1 = 23, /**<  */
  kTopScafiDeprecatedMuxedPadsIoc2 = 24, /**<  */
  kTopScafiDeprecatedMuxedPadsIoc3 = 25, /**<  */
  kTopScafiDeprecatedMuxedPadsIoc4 = 26, /**<  */
  kTopScafiDeprecatedMuxedPadsIoc5 = 27, /**<  */
  kTopScafiDeprecatedMuxedPadsIoc6 = 28, /**<  */
  kTopScafiDeprecatedMuxedPadsIoc7 = 29, /**<  */
  kTopScafiDeprecatedMuxedPadsIoc8 = 30, /**<  */
  kTopScafiDeprecatedMuxedPadsIoc9 = 31, /**<  */
  kTopScafiDeprecatedMuxedPadsIoc10 = 32, /**<  */
  kTopScafiDeprecatedMuxedPadsIoc11 = 33, /**<  */
  kTopScafiDeprecatedMuxedPadsIoc12 = 34, /**<  */
  kTopScafiDeprecatedMuxedPadsIor0 = 35, /**<  */
  kTopScafiDeprecatedMuxedPadsIor1 = 36, /**<  */
  kTopScafiDeprecatedMuxedPadsIor2 = 37, /**<  */
  kTopScafiDeprecatedMuxedPadsIor3 = 38, /**<  */
  kTopScafiDeprecatedMuxedPadsIor4 = 39, /**<  */
  kTopScafiDeprecatedMuxedPadsIor5 = 40, /**<  */
  kTopScafiDeprecatedMuxedPadsIor6 = 41, /**<  */
  kTopScafiDeprecatedMuxedPadsIor7 = 42, /**<  */
  kTopScafiDeprecatedMuxedPadsIor10 = 43, /**<  */
  kTopScafiDeprecatedMuxedPadsIor11 = 44, /**<  */
  kTopScafiDeprecatedMuxedPadsIor12 = 45, /**<  */
  kTopScafiDeprecatedMuxedPadsIor13 = 46, /**<  */
  kTopScafiDeprecatedMuxedPadsLast = 46, /**< \internal Last valid muxed pad */
} top_scafi_deprecated_muxed_pads_t;

/**
 * Power Manager Wakeup Signals
 */
typedef enum top_scafi_deprecated_power_manager_wake_ups {
  kTopScafiDeprecatedPowerManagerWakeUpsPinmuxAonPinWkupReq = 0, /**<  */
  kTopScafiDeprecatedPowerManagerWakeUpsPinmuxAonUsbWkupReq = 1, /**<  */
  kTopScafiDeprecatedPowerManagerWakeUpsAonTimerAonWkupReq = 2, /**<  */
  kTopScafiDeprecatedPowerManagerWakeUpsLast = 2, /**< \internal Last valid pwrmgr wakeup signal */
} top_scafi_deprecated_power_manager_wake_ups_t;

/**
 * Reset Manager Software Controlled Resets
 */
typedef enum top_scafi_deprecated_reset_manager_sw_resets {
  kTopScafiDeprecatedResetManagerSwResetsSpiDevice = 0, /**<  */
  kTopScafiDeprecatedResetManagerSwResetsSpiHost0 = 1, /**<  */
  kTopScafiDeprecatedResetManagerSwResetsUsb = 2, /**<  */
  kTopScafiDeprecatedResetManagerSwResetsLast = 2, /**< \internal Last valid rstmgr software reset request */
} top_scafi_deprecated_reset_manager_sw_resets_t;

/**
 * Power Manager Reset Request Signals
 */
typedef enum top_scafi_deprecated_power_manager_reset_requests {
  kTopScafiDeprecatedPowerManagerResetRequestsAonTimerAonAonTimerRstReq = 0, /**<  */
  kTopScafiDeprecatedPowerManagerResetRequestsLast = 0, /**< \internal Last valid pwrmgr reset_request signal */
} top_scafi_deprecated_power_manager_reset_requests_t;

/**
 * Clock Manager Software-Controlled ("Gated") Clocks.
 *
 * The Software has full control over these clocks.
 */
typedef enum top_scafi_deprecated_gateable_clocks {
  kTopScafiDeprecatedGateableClocksIoDiv4Peri = 0, /**< Clock clk_io_div4_peri in group peri */
  kTopScafiDeprecatedGateableClocksIoDiv2Peri = 1, /**< Clock clk_io_div2_peri in group peri */
  kTopScafiDeprecatedGateableClocksIoPeri = 2, /**< Clock clk_io_peri in group peri */
  kTopScafiDeprecatedGateableClocksUsbPeri = 3, /**< Clock clk_usb_peri in group peri */
  kTopScafiDeprecatedGateableClocksLast = 3, /**< \internal Last Valid Gateable Clock */
} top_scafi_deprecated_gateable_clocks_t;

/**
 * Clock Manager Software-Hinted Clocks.
 *
 * The Software has partial control over these clocks. It can ask them to stop,
 * but the clock manager is in control of whether the clock actually is stopped.
 */
typedef enum top_scafi_deprecated_hintable_clocks {
  kTopScafiDeprecatedHintableClocksMainAes = 0, /**< Clock clk_main_aes in group trans */
  kTopScafiDeprecatedHintableClocksLast = 0, /**< \internal Last Valid Hintable Clock */
} top_scafi_deprecated_hintable_clocks_t;

/**
 * MMIO Region
 *
 * MMIO region excludes any memory that is separate from the module
 * configuration space, i.e. ROM, main SRAM, and flash are excluded but
 * retention SRAM, spi_device memory, or usbdev memory are included.
 */
#define TOP_SCAFI_DEPRECATED_MMIO_BASE_ADDR 0x40000000u
#define TOP_SCAFI_DEPRECATED_MMIO_SIZE_BYTES 0x10000000u

// Header Extern Guard
#ifdef __cplusplus
}  // extern "C"
#endif

#endif  // OPENTITAN_HW_TOP_SCAFI_DEPRECATED_SW_AUTOGEN_TOP_SCAFI_DEPRECATED_H_
