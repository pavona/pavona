// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// ------------------- W A R N I N G: A U T O - G E N E R A T E D   C O D E !! -------------------//
// PLEASE DO NOT HAND-EDIT THIS FILE. IT HAS BEEN AUTO-GENERATED WITH THE FOLLOWING COMMAND:
// util/topgen.py -t hw/top_egret/data/top_egret.hjson
//                -o hw/top_egret/

#ifndef OPENTITAN_HW_TOP_EGRET_SW_AUTOGEN_TOP_EGRET_H_
#define OPENTITAN_HW_TOP_EGRET_SW_AUTOGEN_TOP_EGRET_H_

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
 * - Alert ID Names and Source Mappings
 * - Pinmux Pin/Select Names
 * - Power Manager Wakeups
 */

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Peripheral base address for uart0 in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_UART0_BASE_ADDR 0x40000000u

/**
 * Peripheral size for uart0 in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_UART0_BASE_ADDR and
 * `TOP_EGRET_UART0_BASE_ADDR + TOP_EGRET_UART0_SIZE_BYTES`.
 */
#define TOP_EGRET_UART0_SIZE_BYTES 0x40u

/**
 * Peripheral base address for uart1 in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_UART1_BASE_ADDR 0x40010000u

/**
 * Peripheral size for uart1 in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_UART1_BASE_ADDR and
 * `TOP_EGRET_UART1_BASE_ADDR + TOP_EGRET_UART1_SIZE_BYTES`.
 */
#define TOP_EGRET_UART1_SIZE_BYTES 0x40u

/**
 * Peripheral base address for uart2 in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_UART2_BASE_ADDR 0x40020000u

/**
 * Peripheral size for uart2 in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_UART2_BASE_ADDR and
 * `TOP_EGRET_UART2_BASE_ADDR + TOP_EGRET_UART2_SIZE_BYTES`.
 */
#define TOP_EGRET_UART2_SIZE_BYTES 0x40u

/**
 * Peripheral base address for uart3 in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_UART3_BASE_ADDR 0x40030000u

/**
 * Peripheral size for uart3 in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_UART3_BASE_ADDR and
 * `TOP_EGRET_UART3_BASE_ADDR + TOP_EGRET_UART3_SIZE_BYTES`.
 */
#define TOP_EGRET_UART3_SIZE_BYTES 0x40u

/**
 * Peripheral base address for gpio in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_GPIO_BASE_ADDR 0x40040000u

/**
 * Peripheral size for gpio in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_GPIO_BASE_ADDR and
 * `TOP_EGRET_GPIO_BASE_ADDR + TOP_EGRET_GPIO_SIZE_BYTES`.
 */
#define TOP_EGRET_GPIO_SIZE_BYTES 0x80u

/**
 * Peripheral base address for spi_device in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_SPI_DEVICE_BASE_ADDR 0x40050000u

/**
 * Peripheral size for spi_device in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_SPI_DEVICE_BASE_ADDR and
 * `TOP_EGRET_SPI_DEVICE_BASE_ADDR + TOP_EGRET_SPI_DEVICE_SIZE_BYTES`.
 */
#define TOP_EGRET_SPI_DEVICE_SIZE_BYTES 0x2000u

/**
 * Peripheral base address for i2c0 in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_I2C0_BASE_ADDR 0x40080000u

/**
 * Peripheral size for i2c0 in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_I2C0_BASE_ADDR and
 * `TOP_EGRET_I2C0_BASE_ADDR + TOP_EGRET_I2C0_SIZE_BYTES`.
 */
#define TOP_EGRET_I2C0_SIZE_BYTES 0x80u

/**
 * Peripheral base address for i2c1 in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_I2C1_BASE_ADDR 0x40090000u

/**
 * Peripheral size for i2c1 in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_I2C1_BASE_ADDR and
 * `TOP_EGRET_I2C1_BASE_ADDR + TOP_EGRET_I2C1_SIZE_BYTES`.
 */
#define TOP_EGRET_I2C1_SIZE_BYTES 0x80u

/**
 * Peripheral base address for i2c2 in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_I2C2_BASE_ADDR 0x400A0000u

/**
 * Peripheral size for i2c2 in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_I2C2_BASE_ADDR and
 * `TOP_EGRET_I2C2_BASE_ADDR + TOP_EGRET_I2C2_SIZE_BYTES`.
 */
#define TOP_EGRET_I2C2_SIZE_BYTES 0x80u

/**
 * Peripheral base address for pattgen in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_PATTGEN_BASE_ADDR 0x400E0000u

/**
 * Peripheral size for pattgen in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_PATTGEN_BASE_ADDR and
 * `TOP_EGRET_PATTGEN_BASE_ADDR + TOP_EGRET_PATTGEN_SIZE_BYTES`.
 */
#define TOP_EGRET_PATTGEN_SIZE_BYTES 0x40u

/**
 * Peripheral base address for rv_timer in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_RV_TIMER_BASE_ADDR 0x40100000u

/**
 * Peripheral size for rv_timer in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_RV_TIMER_BASE_ADDR and
 * `TOP_EGRET_RV_TIMER_BASE_ADDR + TOP_EGRET_RV_TIMER_SIZE_BYTES`.
 */
#define TOP_EGRET_RV_TIMER_SIZE_BYTES 0x200u

/**
 * Peripheral base address for core device on otp_ctrl in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_OTP_CTRL_CORE_BASE_ADDR 0x40130000u

/**
 * Peripheral size for core device on otp_ctrl in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_OTP_CTRL_CORE_BASE_ADDR and
 * `TOP_EGRET_OTP_CTRL_CORE_BASE_ADDR + TOP_EGRET_OTP_CTRL_CORE_SIZE_BYTES`.
 */
#define TOP_EGRET_OTP_CTRL_CORE_SIZE_BYTES 0x1000u

/**
 * Peripheral base address for prim device on otp_macro in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_OTP_MACRO_PRIM_BASE_ADDR 0x40138000u

/**
 * Peripheral size for prim device on otp_macro in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_OTP_MACRO_PRIM_BASE_ADDR and
 * `TOP_EGRET_OTP_MACRO_PRIM_BASE_ADDR + TOP_EGRET_OTP_MACRO_PRIM_SIZE_BYTES`.
 */
#define TOP_EGRET_OTP_MACRO_PRIM_SIZE_BYTES 0x20u

/**
 * Peripheral base address for regs device on lc_ctrl in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_LC_CTRL_REGS_BASE_ADDR 0x40140000u

/**
 * Peripheral size for regs device on lc_ctrl in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_LC_CTRL_REGS_BASE_ADDR and
 * `TOP_EGRET_LC_CTRL_REGS_BASE_ADDR + TOP_EGRET_LC_CTRL_REGS_SIZE_BYTES`.
 */
#define TOP_EGRET_LC_CTRL_REGS_SIZE_BYTES 0x100u

/**
 * Peripheral base address for dmi device on lc_ctrl in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_LC_CTRL_DMI_BASE_ADDR 0x0u

/**
 * Peripheral size for dmi device on lc_ctrl in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_LC_CTRL_DMI_BASE_ADDR and
 * `TOP_EGRET_LC_CTRL_DMI_BASE_ADDR + TOP_EGRET_LC_CTRL_DMI_SIZE_BYTES`.
 */
#define TOP_EGRET_LC_CTRL_DMI_SIZE_BYTES 0x1000u

/**
 * Peripheral base address for alert_handler in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_ALERT_HANDLER_BASE_ADDR 0x40150000u

/**
 * Peripheral size for alert_handler in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_ALERT_HANDLER_BASE_ADDR and
 * `TOP_EGRET_ALERT_HANDLER_BASE_ADDR + TOP_EGRET_ALERT_HANDLER_SIZE_BYTES`.
 */
#define TOP_EGRET_ALERT_HANDLER_SIZE_BYTES 0x800u

/**
 * Peripheral base address for spi_host0 in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_SPI_HOST0_BASE_ADDR 0x40300000u

/**
 * Peripheral size for spi_host0 in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_SPI_HOST0_BASE_ADDR and
 * `TOP_EGRET_SPI_HOST0_BASE_ADDR + TOP_EGRET_SPI_HOST0_SIZE_BYTES`.
 */
#define TOP_EGRET_SPI_HOST0_SIZE_BYTES 0x40u

/**
 * Peripheral base address for spi_host1 in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_SPI_HOST1_BASE_ADDR 0x40310000u

/**
 * Peripheral size for spi_host1 in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_SPI_HOST1_BASE_ADDR and
 * `TOP_EGRET_SPI_HOST1_BASE_ADDR + TOP_EGRET_SPI_HOST1_SIZE_BYTES`.
 */
#define TOP_EGRET_SPI_HOST1_SIZE_BYTES 0x40u

/**
 * Peripheral base address for usbdev in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_USBDEV_BASE_ADDR 0x40320000u

/**
 * Peripheral size for usbdev in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_USBDEV_BASE_ADDR and
 * `TOP_EGRET_USBDEV_BASE_ADDR + TOP_EGRET_USBDEV_SIZE_BYTES`.
 */
#define TOP_EGRET_USBDEV_SIZE_BYTES 0x1000u

/**
 * Peripheral base address for pwrmgr_aon in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_PWRMGR_AON_BASE_ADDR 0x40400000u

/**
 * Peripheral size for pwrmgr_aon in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_PWRMGR_AON_BASE_ADDR and
 * `TOP_EGRET_PWRMGR_AON_BASE_ADDR + TOP_EGRET_PWRMGR_AON_SIZE_BYTES`.
 */
#define TOP_EGRET_PWRMGR_AON_SIZE_BYTES 0x80u

/**
 * Peripheral base address for rstmgr_aon in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_RSTMGR_AON_BASE_ADDR 0x40410000u

/**
 * Peripheral size for rstmgr_aon in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_RSTMGR_AON_BASE_ADDR and
 * `TOP_EGRET_RSTMGR_AON_BASE_ADDR + TOP_EGRET_RSTMGR_AON_SIZE_BYTES`.
 */
#define TOP_EGRET_RSTMGR_AON_SIZE_BYTES 0x80u

/**
 * Peripheral base address for clkmgr_aon in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_CLKMGR_AON_BASE_ADDR 0x40420000u

/**
 * Peripheral size for clkmgr_aon in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_CLKMGR_AON_BASE_ADDR and
 * `TOP_EGRET_CLKMGR_AON_BASE_ADDR + TOP_EGRET_CLKMGR_AON_SIZE_BYTES`.
 */
#define TOP_EGRET_CLKMGR_AON_SIZE_BYTES 0x80u

/**
 * Peripheral base address for sysrst_ctrl_aon in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_SYSRST_CTRL_AON_BASE_ADDR 0x40430000u

/**
 * Peripheral size for sysrst_ctrl_aon in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_SYSRST_CTRL_AON_BASE_ADDR and
 * `TOP_EGRET_SYSRST_CTRL_AON_BASE_ADDR + TOP_EGRET_SYSRST_CTRL_AON_SIZE_BYTES`.
 */
#define TOP_EGRET_SYSRST_CTRL_AON_SIZE_BYTES 0x100u

/**
 * Peripheral base address for adc_ctrl_aon in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_ADC_CTRL_AON_BASE_ADDR 0x40440000u

/**
 * Peripheral size for adc_ctrl_aon in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_ADC_CTRL_AON_BASE_ADDR and
 * `TOP_EGRET_ADC_CTRL_AON_BASE_ADDR + TOP_EGRET_ADC_CTRL_AON_SIZE_BYTES`.
 */
#define TOP_EGRET_ADC_CTRL_AON_SIZE_BYTES 0x80u

/**
 * Peripheral base address for pwm_aon in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_PWM_AON_BASE_ADDR 0x40450000u

/**
 * Peripheral size for pwm_aon in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_PWM_AON_BASE_ADDR and
 * `TOP_EGRET_PWM_AON_BASE_ADDR + TOP_EGRET_PWM_AON_SIZE_BYTES`.
 */
#define TOP_EGRET_PWM_AON_SIZE_BYTES 0x80u

/**
 * Peripheral base address for pinmux_aon in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_PINMUX_AON_BASE_ADDR 0x40460000u

/**
 * Peripheral size for pinmux_aon in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_PINMUX_AON_BASE_ADDR and
 * `TOP_EGRET_PINMUX_AON_BASE_ADDR + TOP_EGRET_PINMUX_AON_SIZE_BYTES`.
 */
#define TOP_EGRET_PINMUX_AON_SIZE_BYTES 0x1000u

/**
 * Peripheral base address for aon_timer_aon in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_AON_TIMER_AON_BASE_ADDR 0x40470000u

/**
 * Peripheral size for aon_timer_aon in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_AON_TIMER_AON_BASE_ADDR and
 * `TOP_EGRET_AON_TIMER_AON_BASE_ADDR + TOP_EGRET_AON_TIMER_AON_SIZE_BYTES`.
 */
#define TOP_EGRET_AON_TIMER_AON_SIZE_BYTES 0x40u

/**
 * Peripheral base address for ast in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_AST_BASE_ADDR 0x40480000u

/**
 * Peripheral size for ast in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_AST_BASE_ADDR and
 * `TOP_EGRET_AST_BASE_ADDR + TOP_EGRET_AST_SIZE_BYTES`.
 */
#define TOP_EGRET_AST_SIZE_BYTES 0x400u

/**
 * Peripheral base address for sensor_ctrl_aon in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_SENSOR_CTRL_AON_BASE_ADDR 0x40490000u

/**
 * Peripheral size for sensor_ctrl_aon in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_SENSOR_CTRL_AON_BASE_ADDR and
 * `TOP_EGRET_SENSOR_CTRL_AON_BASE_ADDR + TOP_EGRET_SENSOR_CTRL_AON_SIZE_BYTES`.
 */
#define TOP_EGRET_SENSOR_CTRL_AON_SIZE_BYTES 0x80u

/**
 * Peripheral base address for regs device on sram_ctrl_ret_aon in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_SRAM_CTRL_RET_AON_REGS_BASE_ADDR 0x40500000u

/**
 * Peripheral size for regs device on sram_ctrl_ret_aon in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_SRAM_CTRL_RET_AON_REGS_BASE_ADDR and
 * `TOP_EGRET_SRAM_CTRL_RET_AON_REGS_BASE_ADDR + TOP_EGRET_SRAM_CTRL_RET_AON_REGS_SIZE_BYTES`.
 */
#define TOP_EGRET_SRAM_CTRL_RET_AON_REGS_SIZE_BYTES 0x40u

/**
 * Peripheral base address for core device on flash_ctrl in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_FLASH_CTRL_CORE_BASE_ADDR 0x41000000u

/**
 * Peripheral size for core device on flash_ctrl in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_FLASH_CTRL_CORE_BASE_ADDR and
 * `TOP_EGRET_FLASH_CTRL_CORE_BASE_ADDR + TOP_EGRET_FLASH_CTRL_CORE_SIZE_BYTES`.
 */
#define TOP_EGRET_FLASH_CTRL_CORE_SIZE_BYTES 0x200u

/**
 * Peripheral base address for flash_macro_wrapper in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_FLASH_MACRO_WRAPPER_BASE_ADDR 0x41008000u

/**
 * Peripheral size for flash_macro_wrapper in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_FLASH_MACRO_WRAPPER_BASE_ADDR and
 * `TOP_EGRET_FLASH_MACRO_WRAPPER_BASE_ADDR + TOP_EGRET_FLASH_MACRO_WRAPPER_SIZE_BYTES`.
 */
#define TOP_EGRET_FLASH_MACRO_WRAPPER_SIZE_BYTES 0x80u

/**
 * Peripheral base address for regs device on rv_dm in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_RV_DM_REGS_BASE_ADDR 0x41200000u

/**
 * Peripheral size for regs device on rv_dm in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_RV_DM_REGS_BASE_ADDR and
 * `TOP_EGRET_RV_DM_REGS_BASE_ADDR + TOP_EGRET_RV_DM_REGS_SIZE_BYTES`.
 */
#define TOP_EGRET_RV_DM_REGS_SIZE_BYTES 0x10u

/**
 * Peripheral base address for mem device on rv_dm in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_RV_DM_MEM_BASE_ADDR 0x10000u

/**
 * Peripheral size for mem device on rv_dm in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_RV_DM_MEM_BASE_ADDR and
 * `TOP_EGRET_RV_DM_MEM_BASE_ADDR + TOP_EGRET_RV_DM_MEM_SIZE_BYTES`.
 */
#define TOP_EGRET_RV_DM_MEM_SIZE_BYTES 0x1000u

/**
 * Peripheral base address for dbg device on rv_dm in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_RV_DM_DBG_BASE_ADDR 0x1000u

/**
 * Peripheral size for dbg device on rv_dm in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_RV_DM_DBG_BASE_ADDR and
 * `TOP_EGRET_RV_DM_DBG_BASE_ADDR + TOP_EGRET_RV_DM_DBG_SIZE_BYTES`.
 */
#define TOP_EGRET_RV_DM_DBG_SIZE_BYTES 0x200u

/**
 * Peripheral base address for rv_plic in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_RV_PLIC_BASE_ADDR 0x48000000u

/**
 * Peripheral size for rv_plic in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_RV_PLIC_BASE_ADDR and
 * `TOP_EGRET_RV_PLIC_BASE_ADDR + TOP_EGRET_RV_PLIC_SIZE_BYTES`.
 */
#define TOP_EGRET_RV_PLIC_SIZE_BYTES 0x8000000u

/**
 * Peripheral base address for acc in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_ACC_BASE_ADDR 0x41300000u

/**
 * Peripheral size for acc in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_ACC_BASE_ADDR and
 * `TOP_EGRET_ACC_BASE_ADDR + TOP_EGRET_ACC_SIZE_BYTES`.
 */
#define TOP_EGRET_ACC_SIZE_BYTES 0x20000u

/**
 * Peripheral base address for aes in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_AES_BASE_ADDR 0x41100000u

/**
 * Peripheral size for aes in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_AES_BASE_ADDR and
 * `TOP_EGRET_AES_BASE_ADDR + TOP_EGRET_AES_SIZE_BYTES`.
 */
#define TOP_EGRET_AES_SIZE_BYTES 0x100u

/**
 * Peripheral base address for hmac in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_HMAC_BASE_ADDR 0x41110000u

/**
 * Peripheral size for hmac in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_HMAC_BASE_ADDR and
 * `TOP_EGRET_HMAC_BASE_ADDR + TOP_EGRET_HMAC_SIZE_BYTES`.
 */
#define TOP_EGRET_HMAC_SIZE_BYTES 0x2000u

/**
 * Peripheral base address for kmac in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_KMAC_BASE_ADDR 0x41120000u

/**
 * Peripheral size for kmac in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_KMAC_BASE_ADDR and
 * `TOP_EGRET_KMAC_BASE_ADDR + TOP_EGRET_KMAC_SIZE_BYTES`.
 */
#define TOP_EGRET_KMAC_SIZE_BYTES 0x1000u

/**
 * Peripheral base address for keymgr in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_KEYMGR_BASE_ADDR 0x41140000u

/**
 * Peripheral size for keymgr in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_KEYMGR_BASE_ADDR and
 * `TOP_EGRET_KEYMGR_BASE_ADDR + TOP_EGRET_KEYMGR_SIZE_BYTES`.
 */
#define TOP_EGRET_KEYMGR_SIZE_BYTES 0x100u

/**
 * Peripheral base address for csrng in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_CSRNG_BASE_ADDR 0x41150000u

/**
 * Peripheral size for csrng in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_CSRNG_BASE_ADDR and
 * `TOP_EGRET_CSRNG_BASE_ADDR + TOP_EGRET_CSRNG_SIZE_BYTES`.
 */
#define TOP_EGRET_CSRNG_SIZE_BYTES 0x80u

/**
 * Peripheral base address for entropy_src in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_ENTROPY_SRC_BASE_ADDR 0x41160000u

/**
 * Peripheral size for entropy_src in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_ENTROPY_SRC_BASE_ADDR and
 * `TOP_EGRET_ENTROPY_SRC_BASE_ADDR + TOP_EGRET_ENTROPY_SRC_SIZE_BYTES`.
 */
#define TOP_EGRET_ENTROPY_SRC_SIZE_BYTES 0x100u

/**
 * Peripheral base address for edn0 in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_EDN0_BASE_ADDR 0x41170000u

/**
 * Peripheral size for edn0 in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_EDN0_BASE_ADDR and
 * `TOP_EGRET_EDN0_BASE_ADDR + TOP_EGRET_EDN0_SIZE_BYTES`.
 */
#define TOP_EGRET_EDN0_SIZE_BYTES 0x80u

/**
 * Peripheral base address for edn1 in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_EDN1_BASE_ADDR 0x41180000u

/**
 * Peripheral size for edn1 in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_EDN1_BASE_ADDR and
 * `TOP_EGRET_EDN1_BASE_ADDR + TOP_EGRET_EDN1_SIZE_BYTES`.
 */
#define TOP_EGRET_EDN1_SIZE_BYTES 0x80u

/**
 * Peripheral base address for regs device on sram_ctrl_main in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_SRAM_CTRL_MAIN_REGS_BASE_ADDR 0x411C0000u

/**
 * Peripheral size for regs device on sram_ctrl_main in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_SRAM_CTRL_MAIN_REGS_BASE_ADDR and
 * `TOP_EGRET_SRAM_CTRL_MAIN_REGS_BASE_ADDR + TOP_EGRET_SRAM_CTRL_MAIN_REGS_SIZE_BYTES`.
 */
#define TOP_EGRET_SRAM_CTRL_MAIN_REGS_SIZE_BYTES 0x40u

/**
 * Peripheral base address for regs device on rom_ctrl in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_ROM_CTRL_REGS_BASE_ADDR 0x411E0000u

/**
 * Peripheral size for regs device on rom_ctrl in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_ROM_CTRL_REGS_BASE_ADDR and
 * `TOP_EGRET_ROM_CTRL_REGS_BASE_ADDR + TOP_EGRET_ROM_CTRL_REGS_SIZE_BYTES`.
 */
#define TOP_EGRET_ROM_CTRL_REGS_SIZE_BYTES 0x80u

/**
 * Peripheral base address for cfg device on rv_core_ibex in top egret.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_EGRET_RV_CORE_IBEX_CFG_BASE_ADDR 0x411F0000u

/**
 * Peripheral size for cfg device on rv_core_ibex in top egret.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_EGRET_RV_CORE_IBEX_CFG_BASE_ADDR and
 * `TOP_EGRET_RV_CORE_IBEX_CFG_BASE_ADDR + TOP_EGRET_RV_CORE_IBEX_CFG_SIZE_BYTES`.
 */
#define TOP_EGRET_RV_CORE_IBEX_CFG_SIZE_BYTES 0x100u


/**
 * Memory base address for ram memory on sram_ctrl_ret_aon in top egret.
 */
#define TOP_EGRET_SRAM_CTRL_RET_AON_RAM_BASE_ADDR 0x40600000u

/**
 * Memory size for ram memory on sram_ctrl_ret_aon in top egret.
 */
#define TOP_EGRET_SRAM_CTRL_RET_AON_RAM_SIZE_BYTES 0x1000u

/**
 * Memory base address for mem memory on flash_ctrl in top egret.
 */
#define TOP_EGRET_FLASH_CTRL_MEM_BASE_ADDR 0x20000000u

/**
 * Memory size for mem memory on flash_ctrl in top egret.
 */
#define TOP_EGRET_FLASH_CTRL_MEM_SIZE_BYTES 0x100000u

/**
 * Memory base address for ram memory on sram_ctrl_main in top egret.
 */
#define TOP_EGRET_SRAM_CTRL_MAIN_RAM_BASE_ADDR 0x10000000u

/**
 * Memory size for ram memory on sram_ctrl_main in top egret.
 */
#define TOP_EGRET_SRAM_CTRL_MAIN_RAM_SIZE_BYTES 0x20000u

/**
 * Memory base address for rom memory on rom_ctrl in top egret.
 */
#define TOP_EGRET_ROM_CTRL_ROM_BASE_ADDR 0x8000u

/**
 * Memory size for rom memory on rom_ctrl in top egret.
 */
#define TOP_EGRET_ROM_CTRL_ROM_SIZE_BYTES 0x8000u


/**
 * PLIC Interrupt Source Peripheral.
 *
 * Enumeration used to determine which peripheral asserted the corresponding
 * interrupt.
 */
typedef enum top_egret_plic_peripheral {
  kTopEgretPlicPeripheralUnknown = 0, /**< Unknown Peripheral */
  kTopEgretPlicPeripheralUart0 = 1, /**< uart0 */
  kTopEgretPlicPeripheralUart1 = 2, /**< uart1 */
  kTopEgretPlicPeripheralUart2 = 3, /**< uart2 */
  kTopEgretPlicPeripheralUart3 = 4, /**< uart3 */
  kTopEgretPlicPeripheralGpio = 5, /**< gpio */
  kTopEgretPlicPeripheralSpiDevice = 6, /**< spi_device */
  kTopEgretPlicPeripheralI2c0 = 7, /**< i2c0 */
  kTopEgretPlicPeripheralI2c1 = 8, /**< i2c1 */
  kTopEgretPlicPeripheralI2c2 = 9, /**< i2c2 */
  kTopEgretPlicPeripheralPattgen = 10, /**< pattgen */
  kTopEgretPlicPeripheralRvTimer = 11, /**< rv_timer */
  kTopEgretPlicPeripheralOtpCtrl = 12, /**< otp_ctrl */
  kTopEgretPlicPeripheralAlertHandler = 13, /**< alert_handler */
  kTopEgretPlicPeripheralSpiHost0 = 14, /**< spi_host0 */
  kTopEgretPlicPeripheralSpiHost1 = 15, /**< spi_host1 */
  kTopEgretPlicPeripheralUsbdev = 16, /**< usbdev */
  kTopEgretPlicPeripheralPwrmgrAon = 17, /**< pwrmgr_aon */
  kTopEgretPlicPeripheralSysrstCtrlAon = 18, /**< sysrst_ctrl_aon */
  kTopEgretPlicPeripheralAdcCtrlAon = 19, /**< adc_ctrl_aon */
  kTopEgretPlicPeripheralAonTimerAon = 20, /**< aon_timer_aon */
  kTopEgretPlicPeripheralSensorCtrlAon = 21, /**< sensor_ctrl_aon */
  kTopEgretPlicPeripheralFlashCtrl = 22, /**< flash_ctrl */
  kTopEgretPlicPeripheralAcc = 23, /**< acc */
  kTopEgretPlicPeripheralHmac = 24, /**< hmac */
  kTopEgretPlicPeripheralKmac = 25, /**< kmac */
  kTopEgretPlicPeripheralKeymgr = 26, /**< keymgr */
  kTopEgretPlicPeripheralCsrng = 27, /**< csrng */
  kTopEgretPlicPeripheralEntropySrc = 28, /**< entropy_src */
  kTopEgretPlicPeripheralEdn0 = 29, /**< edn0 */
  kTopEgretPlicPeripheralEdn1 = 30, /**< edn1 */
  kTopEgretPlicPeripheralLast = 30, /**< \internal Final PLIC peripheral */
} top_egret_plic_peripheral_t;

/**
 * PLIC Interrupt Source.
 *
 * Enumeration of all PLIC interrupt sources. The interrupt sources belonging to
 * the same peripheral are guaranteed to be consecutive.
 */
typedef enum top_egret_plic_irq_id {
  kTopEgretPlicIrqIdNone = 0, /**< No Interrupt */
  kTopEgretPlicIrqIdUart0TxWatermark = 1, /**< uart0_tx_watermark */
  kTopEgretPlicIrqIdUart0RxWatermark = 2, /**< uart0_rx_watermark */
  kTopEgretPlicIrqIdUart0TxDone = 3, /**< uart0_tx_done */
  kTopEgretPlicIrqIdUart0RxOverflow = 4, /**< uart0_rx_overflow */
  kTopEgretPlicIrqIdUart0RxFrameErr = 5, /**< uart0_rx_frame_err */
  kTopEgretPlicIrqIdUart0RxBreakErr = 6, /**< uart0_rx_break_err */
  kTopEgretPlicIrqIdUart0RxTimeout = 7, /**< uart0_rx_timeout */
  kTopEgretPlicIrqIdUart0RxParityErr = 8, /**< uart0_rx_parity_err */
  kTopEgretPlicIrqIdUart0TxEmpty = 9, /**< uart0_tx_empty */
  kTopEgretPlicIrqIdUart1TxWatermark = 10, /**< uart1_tx_watermark */
  kTopEgretPlicIrqIdUart1RxWatermark = 11, /**< uart1_rx_watermark */
  kTopEgretPlicIrqIdUart1TxDone = 12, /**< uart1_tx_done */
  kTopEgretPlicIrqIdUart1RxOverflow = 13, /**< uart1_rx_overflow */
  kTopEgretPlicIrqIdUart1RxFrameErr = 14, /**< uart1_rx_frame_err */
  kTopEgretPlicIrqIdUart1RxBreakErr = 15, /**< uart1_rx_break_err */
  kTopEgretPlicIrqIdUart1RxTimeout = 16, /**< uart1_rx_timeout */
  kTopEgretPlicIrqIdUart1RxParityErr = 17, /**< uart1_rx_parity_err */
  kTopEgretPlicIrqIdUart1TxEmpty = 18, /**< uart1_tx_empty */
  kTopEgretPlicIrqIdUart2TxWatermark = 19, /**< uart2_tx_watermark */
  kTopEgretPlicIrqIdUart2RxWatermark = 20, /**< uart2_rx_watermark */
  kTopEgretPlicIrqIdUart2TxDone = 21, /**< uart2_tx_done */
  kTopEgretPlicIrqIdUart2RxOverflow = 22, /**< uart2_rx_overflow */
  kTopEgretPlicIrqIdUart2RxFrameErr = 23, /**< uart2_rx_frame_err */
  kTopEgretPlicIrqIdUart2RxBreakErr = 24, /**< uart2_rx_break_err */
  kTopEgretPlicIrqIdUart2RxTimeout = 25, /**< uart2_rx_timeout */
  kTopEgretPlicIrqIdUart2RxParityErr = 26, /**< uart2_rx_parity_err */
  kTopEgretPlicIrqIdUart2TxEmpty = 27, /**< uart2_tx_empty */
  kTopEgretPlicIrqIdUart3TxWatermark = 28, /**< uart3_tx_watermark */
  kTopEgretPlicIrqIdUart3RxWatermark = 29, /**< uart3_rx_watermark */
  kTopEgretPlicIrqIdUart3TxDone = 30, /**< uart3_tx_done */
  kTopEgretPlicIrqIdUart3RxOverflow = 31, /**< uart3_rx_overflow */
  kTopEgretPlicIrqIdUart3RxFrameErr = 32, /**< uart3_rx_frame_err */
  kTopEgretPlicIrqIdUart3RxBreakErr = 33, /**< uart3_rx_break_err */
  kTopEgretPlicIrqIdUart3RxTimeout = 34, /**< uart3_rx_timeout */
  kTopEgretPlicIrqIdUart3RxParityErr = 35, /**< uart3_rx_parity_err */
  kTopEgretPlicIrqIdUart3TxEmpty = 36, /**< uart3_tx_empty */
  kTopEgretPlicIrqIdGpioGpio0 = 37, /**< gpio_gpio 0 */
  kTopEgretPlicIrqIdGpioGpio1 = 38, /**< gpio_gpio 1 */
  kTopEgretPlicIrqIdGpioGpio2 = 39, /**< gpio_gpio 2 */
  kTopEgretPlicIrqIdGpioGpio3 = 40, /**< gpio_gpio 3 */
  kTopEgretPlicIrqIdGpioGpio4 = 41, /**< gpio_gpio 4 */
  kTopEgretPlicIrqIdGpioGpio5 = 42, /**< gpio_gpio 5 */
  kTopEgretPlicIrqIdGpioGpio6 = 43, /**< gpio_gpio 6 */
  kTopEgretPlicIrqIdGpioGpio7 = 44, /**< gpio_gpio 7 */
  kTopEgretPlicIrqIdGpioGpio8 = 45, /**< gpio_gpio 8 */
  kTopEgretPlicIrqIdGpioGpio9 = 46, /**< gpio_gpio 9 */
  kTopEgretPlicIrqIdGpioGpio10 = 47, /**< gpio_gpio 10 */
  kTopEgretPlicIrqIdGpioGpio11 = 48, /**< gpio_gpio 11 */
  kTopEgretPlicIrqIdGpioGpio12 = 49, /**< gpio_gpio 12 */
  kTopEgretPlicIrqIdGpioGpio13 = 50, /**< gpio_gpio 13 */
  kTopEgretPlicIrqIdGpioGpio14 = 51, /**< gpio_gpio 14 */
  kTopEgretPlicIrqIdGpioGpio15 = 52, /**< gpio_gpio 15 */
  kTopEgretPlicIrqIdGpioGpio16 = 53, /**< gpio_gpio 16 */
  kTopEgretPlicIrqIdGpioGpio17 = 54, /**< gpio_gpio 17 */
  kTopEgretPlicIrqIdGpioGpio18 = 55, /**< gpio_gpio 18 */
  kTopEgretPlicIrqIdGpioGpio19 = 56, /**< gpio_gpio 19 */
  kTopEgretPlicIrqIdGpioGpio20 = 57, /**< gpio_gpio 20 */
  kTopEgretPlicIrqIdGpioGpio21 = 58, /**< gpio_gpio 21 */
  kTopEgretPlicIrqIdGpioGpio22 = 59, /**< gpio_gpio 22 */
  kTopEgretPlicIrqIdGpioGpio23 = 60, /**< gpio_gpio 23 */
  kTopEgretPlicIrqIdGpioGpio24 = 61, /**< gpio_gpio 24 */
  kTopEgretPlicIrqIdGpioGpio25 = 62, /**< gpio_gpio 25 */
  kTopEgretPlicIrqIdGpioGpio26 = 63, /**< gpio_gpio 26 */
  kTopEgretPlicIrqIdGpioGpio27 = 64, /**< gpio_gpio 27 */
  kTopEgretPlicIrqIdGpioGpio28 = 65, /**< gpio_gpio 28 */
  kTopEgretPlicIrqIdGpioGpio29 = 66, /**< gpio_gpio 29 */
  kTopEgretPlicIrqIdGpioGpio30 = 67, /**< gpio_gpio 30 */
  kTopEgretPlicIrqIdGpioGpio31 = 68, /**< gpio_gpio 31 */
  kTopEgretPlicIrqIdSpiDeviceUploadCmdfifoNotEmpty = 69, /**< spi_device_upload_cmdfifo_not_empty */
  kTopEgretPlicIrqIdSpiDeviceUploadPayloadNotEmpty = 70, /**< spi_device_upload_payload_not_empty */
  kTopEgretPlicIrqIdSpiDeviceUploadPayloadOverflow = 71, /**< spi_device_upload_payload_overflow */
  kTopEgretPlicIrqIdSpiDeviceReadbufWatermark = 72, /**< spi_device_readbuf_watermark */
  kTopEgretPlicIrqIdSpiDeviceReadbufFlip = 73, /**< spi_device_readbuf_flip */
  kTopEgretPlicIrqIdSpiDeviceTpmHeaderNotEmpty = 74, /**< spi_device_tpm_header_not_empty */
  kTopEgretPlicIrqIdSpiDeviceTpmRdfifoCmdEnd = 75, /**< spi_device_tpm_rdfifo_cmd_end */
  kTopEgretPlicIrqIdSpiDeviceTpmRdfifoDrop = 76, /**< spi_device_tpm_rdfifo_drop */
  kTopEgretPlicIrqIdI2c0FmtThreshold = 77, /**< i2c0_fmt_threshold */
  kTopEgretPlicIrqIdI2c0RxThreshold = 78, /**< i2c0_rx_threshold */
  kTopEgretPlicIrqIdI2c0AcqThreshold = 79, /**< i2c0_acq_threshold */
  kTopEgretPlicIrqIdI2c0RxOverflow = 80, /**< i2c0_rx_overflow */
  kTopEgretPlicIrqIdI2c0ControllerHalt = 81, /**< i2c0_controller_halt */
  kTopEgretPlicIrqIdI2c0SclInterference = 82, /**< i2c0_scl_interference */
  kTopEgretPlicIrqIdI2c0SdaInterference = 83, /**< i2c0_sda_interference */
  kTopEgretPlicIrqIdI2c0StretchTimeout = 84, /**< i2c0_stretch_timeout */
  kTopEgretPlicIrqIdI2c0SdaUnstable = 85, /**< i2c0_sda_unstable */
  kTopEgretPlicIrqIdI2c0CmdComplete = 86, /**< i2c0_cmd_complete */
  kTopEgretPlicIrqIdI2c0TxStretch = 87, /**< i2c0_tx_stretch */
  kTopEgretPlicIrqIdI2c0TxThreshold = 88, /**< i2c0_tx_threshold */
  kTopEgretPlicIrqIdI2c0AcqStretch = 89, /**< i2c0_acq_stretch */
  kTopEgretPlicIrqIdI2c0UnexpStop = 90, /**< i2c0_unexp_stop */
  kTopEgretPlicIrqIdI2c0HostTimeout = 91, /**< i2c0_host_timeout */
  kTopEgretPlicIrqIdI2c1FmtThreshold = 92, /**< i2c1_fmt_threshold */
  kTopEgretPlicIrqIdI2c1RxThreshold = 93, /**< i2c1_rx_threshold */
  kTopEgretPlicIrqIdI2c1AcqThreshold = 94, /**< i2c1_acq_threshold */
  kTopEgretPlicIrqIdI2c1RxOverflow = 95, /**< i2c1_rx_overflow */
  kTopEgretPlicIrqIdI2c1ControllerHalt = 96, /**< i2c1_controller_halt */
  kTopEgretPlicIrqIdI2c1SclInterference = 97, /**< i2c1_scl_interference */
  kTopEgretPlicIrqIdI2c1SdaInterference = 98, /**< i2c1_sda_interference */
  kTopEgretPlicIrqIdI2c1StretchTimeout = 99, /**< i2c1_stretch_timeout */
  kTopEgretPlicIrqIdI2c1SdaUnstable = 100, /**< i2c1_sda_unstable */
  kTopEgretPlicIrqIdI2c1CmdComplete = 101, /**< i2c1_cmd_complete */
  kTopEgretPlicIrqIdI2c1TxStretch = 102, /**< i2c1_tx_stretch */
  kTopEgretPlicIrqIdI2c1TxThreshold = 103, /**< i2c1_tx_threshold */
  kTopEgretPlicIrqIdI2c1AcqStretch = 104, /**< i2c1_acq_stretch */
  kTopEgretPlicIrqIdI2c1UnexpStop = 105, /**< i2c1_unexp_stop */
  kTopEgretPlicIrqIdI2c1HostTimeout = 106, /**< i2c1_host_timeout */
  kTopEgretPlicIrqIdI2c2FmtThreshold = 107, /**< i2c2_fmt_threshold */
  kTopEgretPlicIrqIdI2c2RxThreshold = 108, /**< i2c2_rx_threshold */
  kTopEgretPlicIrqIdI2c2AcqThreshold = 109, /**< i2c2_acq_threshold */
  kTopEgretPlicIrqIdI2c2RxOverflow = 110, /**< i2c2_rx_overflow */
  kTopEgretPlicIrqIdI2c2ControllerHalt = 111, /**< i2c2_controller_halt */
  kTopEgretPlicIrqIdI2c2SclInterference = 112, /**< i2c2_scl_interference */
  kTopEgretPlicIrqIdI2c2SdaInterference = 113, /**< i2c2_sda_interference */
  kTopEgretPlicIrqIdI2c2StretchTimeout = 114, /**< i2c2_stretch_timeout */
  kTopEgretPlicIrqIdI2c2SdaUnstable = 115, /**< i2c2_sda_unstable */
  kTopEgretPlicIrqIdI2c2CmdComplete = 116, /**< i2c2_cmd_complete */
  kTopEgretPlicIrqIdI2c2TxStretch = 117, /**< i2c2_tx_stretch */
  kTopEgretPlicIrqIdI2c2TxThreshold = 118, /**< i2c2_tx_threshold */
  kTopEgretPlicIrqIdI2c2AcqStretch = 119, /**< i2c2_acq_stretch */
  kTopEgretPlicIrqIdI2c2UnexpStop = 120, /**< i2c2_unexp_stop */
  kTopEgretPlicIrqIdI2c2HostTimeout = 121, /**< i2c2_host_timeout */
  kTopEgretPlicIrqIdPattgenDoneCh0 = 122, /**< pattgen_done_ch0 */
  kTopEgretPlicIrqIdPattgenDoneCh1 = 123, /**< pattgen_done_ch1 */
  kTopEgretPlicIrqIdRvTimerTimerExpiredHart0Timer0 = 124, /**< rv_timer_timer_expired_hart0_timer0 */
  kTopEgretPlicIrqIdOtpCtrlOtpOperationDone = 125, /**< otp_ctrl_otp_operation_done */
  kTopEgretPlicIrqIdOtpCtrlOtpError = 126, /**< otp_ctrl_otp_error */
  kTopEgretPlicIrqIdAlertHandlerClassa = 127, /**< alert_handler_classa */
  kTopEgretPlicIrqIdAlertHandlerClassb = 128, /**< alert_handler_classb */
  kTopEgretPlicIrqIdAlertHandlerClassc = 129, /**< alert_handler_classc */
  kTopEgretPlicIrqIdAlertHandlerClassd = 130, /**< alert_handler_classd */
  kTopEgretPlicIrqIdSpiHost0Error = 131, /**< spi_host0_error */
  kTopEgretPlicIrqIdSpiHost0SpiEvent = 132, /**< spi_host0_spi_event */
  kTopEgretPlicIrqIdSpiHost1Error = 133, /**< spi_host1_error */
  kTopEgretPlicIrqIdSpiHost1SpiEvent = 134, /**< spi_host1_spi_event */
  kTopEgretPlicIrqIdUsbdevPktReceived = 135, /**< usbdev_pkt_received */
  kTopEgretPlicIrqIdUsbdevPktSent = 136, /**< usbdev_pkt_sent */
  kTopEgretPlicIrqIdUsbdevDisconnected = 137, /**< usbdev_disconnected */
  kTopEgretPlicIrqIdUsbdevHostLost = 138, /**< usbdev_host_lost */
  kTopEgretPlicIrqIdUsbdevLinkReset = 139, /**< usbdev_link_reset */
  kTopEgretPlicIrqIdUsbdevLinkSuspend = 140, /**< usbdev_link_suspend */
  kTopEgretPlicIrqIdUsbdevLinkResume = 141, /**< usbdev_link_resume */
  kTopEgretPlicIrqIdUsbdevAvOutEmpty = 142, /**< usbdev_av_out_empty */
  kTopEgretPlicIrqIdUsbdevRxFull = 143, /**< usbdev_rx_full */
  kTopEgretPlicIrqIdUsbdevAvOverflow = 144, /**< usbdev_av_overflow */
  kTopEgretPlicIrqIdUsbdevLinkInErr = 145, /**< usbdev_link_in_err */
  kTopEgretPlicIrqIdUsbdevRxCrcErr = 146, /**< usbdev_rx_crc_err */
  kTopEgretPlicIrqIdUsbdevRxPidErr = 147, /**< usbdev_rx_pid_err */
  kTopEgretPlicIrqIdUsbdevRxBitstuffErr = 148, /**< usbdev_rx_bitstuff_err */
  kTopEgretPlicIrqIdUsbdevFrame = 149, /**< usbdev_frame */
  kTopEgretPlicIrqIdUsbdevPowered = 150, /**< usbdev_powered */
  kTopEgretPlicIrqIdUsbdevLinkOutErr = 151, /**< usbdev_link_out_err */
  kTopEgretPlicIrqIdUsbdevAvSetupEmpty = 152, /**< usbdev_av_setup_empty */
  kTopEgretPlicIrqIdPwrmgrAonWakeup = 153, /**< pwrmgr_aon_wakeup */
  kTopEgretPlicIrqIdSysrstCtrlAonEventDetected = 154, /**< sysrst_ctrl_aon_event_detected */
  kTopEgretPlicIrqIdAdcCtrlAonMatchPending = 155, /**< adc_ctrl_aon_match_pending */
  kTopEgretPlicIrqIdAonTimerAonWkupTimerExpired = 156, /**< aon_timer_aon_wkup_timer_expired */
  kTopEgretPlicIrqIdAonTimerAonWdogTimerBark = 157, /**< aon_timer_aon_wdog_timer_bark */
  kTopEgretPlicIrqIdSensorCtrlAonIoStatusChange = 158, /**< sensor_ctrl_aon_io_status_change */
  kTopEgretPlicIrqIdSensorCtrlAonInitStatusChange = 159, /**< sensor_ctrl_aon_init_status_change */
  kTopEgretPlicIrqIdFlashCtrlProgEmpty = 160, /**< flash_ctrl_prog_empty */
  kTopEgretPlicIrqIdFlashCtrlProgLvl = 161, /**< flash_ctrl_prog_lvl */
  kTopEgretPlicIrqIdFlashCtrlRdFull = 162, /**< flash_ctrl_rd_full */
  kTopEgretPlicIrqIdFlashCtrlRdLvl = 163, /**< flash_ctrl_rd_lvl */
  kTopEgretPlicIrqIdFlashCtrlOpDone = 164, /**< flash_ctrl_op_done */
  kTopEgretPlicIrqIdFlashCtrlCorrErr = 165, /**< flash_ctrl_corr_err */
  kTopEgretPlicIrqIdAccDone = 166, /**< acc_done */
  kTopEgretPlicIrqIdHmacHmacDone = 167, /**< hmac_hmac_done */
  kTopEgretPlicIrqIdHmacFifoEmpty = 168, /**< hmac_fifo_empty */
  kTopEgretPlicIrqIdHmacHmacErr = 169, /**< hmac_hmac_err */
  kTopEgretPlicIrqIdKmacKmacDone = 170, /**< kmac_kmac_done */
  kTopEgretPlicIrqIdKmacFifoEmpty = 171, /**< kmac_fifo_empty */
  kTopEgretPlicIrqIdKmacKmacErr = 172, /**< kmac_kmac_err */
  kTopEgretPlicIrqIdKeymgrOpDone = 173, /**< keymgr_op_done */
  kTopEgretPlicIrqIdCsrngCsCmdReqDone = 174, /**< csrng_cs_cmd_req_done */
  kTopEgretPlicIrqIdCsrngCsEntropyReq = 175, /**< csrng_cs_entropy_req */
  kTopEgretPlicIrqIdCsrngCsHwInstExc = 176, /**< csrng_cs_hw_inst_exc */
  kTopEgretPlicIrqIdCsrngCsFatalErr = 177, /**< csrng_cs_fatal_err */
  kTopEgretPlicIrqIdEntropySrcEsEntropyValid = 178, /**< entropy_src_es_entropy_valid */
  kTopEgretPlicIrqIdEntropySrcEsHealthTestFailed = 179, /**< entropy_src_es_health_test_failed */
  kTopEgretPlicIrqIdEntropySrcEsObserveFifoReady = 180, /**< entropy_src_es_observe_fifo_ready */
  kTopEgretPlicIrqIdEntropySrcEsFatalErr = 181, /**< entropy_src_es_fatal_err */
  kTopEgretPlicIrqIdEdn0EdnCmdReqDone = 182, /**< edn0_edn_cmd_req_done */
  kTopEgretPlicIrqIdEdn0EdnFatalErr = 183, /**< edn0_edn_fatal_err */
  kTopEgretPlicIrqIdEdn1EdnCmdReqDone = 184, /**< edn1_edn_cmd_req_done */
  kTopEgretPlicIrqIdEdn1EdnFatalErr = 185, /**< edn1_edn_fatal_err */
  kTopEgretPlicIrqIdLast = 185, /**< \internal The Last Valid Interrupt ID. */
} top_egret_plic_irq_id_t;

/**
 * PLIC Interrupt Source to Peripheral Map
 *
 * This array is a mapping from `top_egret_plic_irq_id_t` to
 * `top_egret_plic_peripheral_t`.
 */
extern const top_egret_plic_peripheral_t
    top_egret_plic_interrupt_for_peripheral[186];

/**
 * PLIC Interrupt Target.
 *
 * Enumeration used to determine which set of IE, CC, threshold registers to
 * access for a given interrupt target.
 */
typedef enum top_egret_plic_target {
  kTopEgretPlicTargetIbex0 = 0, /**< Ibex Core 0 */
  kTopEgretPlicTargetLast = 0, /**< \internal Final PLIC target */
} top_egret_plic_target_t;


/**
 * Alert Handler Source Peripheral.
 *
 * Enumeration used to determine which peripheral asserted the corresponding
 * alert.
 */
typedef enum top_egret_alert_peripheral {
  kTopEgretAlertPeripheralExternal = 0, /**< External Peripheral */
  kTopEgretAlertPeripheralUart0 = 1, /**< uart0 */
  kTopEgretAlertPeripheralUart1 = 2, /**< uart1 */
  kTopEgretAlertPeripheralUart2 = 3, /**< uart2 */
  kTopEgretAlertPeripheralUart3 = 4, /**< uart3 */
  kTopEgretAlertPeripheralGpio = 5, /**< gpio */
  kTopEgretAlertPeripheralSpiDevice = 6, /**< spi_device */
  kTopEgretAlertPeripheralI2c0 = 7, /**< i2c0 */
  kTopEgretAlertPeripheralI2c1 = 8, /**< i2c1 */
  kTopEgretAlertPeripheralI2c2 = 9, /**< i2c2 */
  kTopEgretAlertPeripheralPattgen = 10, /**< pattgen */
  kTopEgretAlertPeripheralRvTimer = 11, /**< rv_timer */
  kTopEgretAlertPeripheralOtpCtrl = 12, /**< otp_ctrl */
  kTopEgretAlertPeripheralLcCtrl = 13, /**< lc_ctrl */
  kTopEgretAlertPeripheralSpiHost0 = 14, /**< spi_host0 */
  kTopEgretAlertPeripheralSpiHost1 = 15, /**< spi_host1 */
  kTopEgretAlertPeripheralUsbdev = 16, /**< usbdev */
  kTopEgretAlertPeripheralPwrmgrAon = 17, /**< pwrmgr_aon */
  kTopEgretAlertPeripheralRstmgrAon = 18, /**< rstmgr_aon */
  kTopEgretAlertPeripheralClkmgrAon = 19, /**< clkmgr_aon */
  kTopEgretAlertPeripheralSysrstCtrlAon = 20, /**< sysrst_ctrl_aon */
  kTopEgretAlertPeripheralAdcCtrlAon = 21, /**< adc_ctrl_aon */
  kTopEgretAlertPeripheralPwmAon = 22, /**< pwm_aon */
  kTopEgretAlertPeripheralPinmuxAon = 23, /**< pinmux_aon */
  kTopEgretAlertPeripheralAonTimerAon = 24, /**< aon_timer_aon */
  kTopEgretAlertPeripheralSensorCtrlAon = 25, /**< sensor_ctrl_aon */
  kTopEgretAlertPeripheralSramCtrlRetAon = 26, /**< sram_ctrl_ret_aon */
  kTopEgretAlertPeripheralFlashCtrl = 27, /**< flash_ctrl */
  kTopEgretAlertPeripheralRvDm = 28, /**< rv_dm */
  kTopEgretAlertPeripheralRvPlic = 29, /**< rv_plic */
  kTopEgretAlertPeripheralAcc = 30, /**< acc */
  kTopEgretAlertPeripheralAes = 31, /**< aes */
  kTopEgretAlertPeripheralHmac = 32, /**< hmac */
  kTopEgretAlertPeripheralKmac = 33, /**< kmac */
  kTopEgretAlertPeripheralKeymgr = 34, /**< keymgr */
  kTopEgretAlertPeripheralCsrng = 35, /**< csrng */
  kTopEgretAlertPeripheralEntropySrc = 36, /**< entropy_src */
  kTopEgretAlertPeripheralEdn0 = 37, /**< edn0 */
  kTopEgretAlertPeripheralEdn1 = 38, /**< edn1 */
  kTopEgretAlertPeripheralSramCtrlMain = 39, /**< sram_ctrl_main */
  kTopEgretAlertPeripheralRomCtrl = 40, /**< rom_ctrl */
  kTopEgretAlertPeripheralRvCoreIbex = 41, /**< rv_core_ibex */
  kTopEgretAlertPeripheralLast = 41, /**< \internal Final Alert peripheral */
} top_egret_alert_peripheral_t;

/**
 * Alert Handler Alert Source.
 *
 * Enumeration of all Alert Handler Alert Sources. The alert sources belonging to
 * the same peripheral are guaranteed to be consecutive.
 */
typedef enum top_egret_alert_id {
  kTopEgretAlertIdUart0FatalFault = 0, /**< uart0_fatal_fault */
  kTopEgretAlertIdUart1FatalFault = 1, /**< uart1_fatal_fault */
  kTopEgretAlertIdUart2FatalFault = 2, /**< uart2_fatal_fault */
  kTopEgretAlertIdUart3FatalFault = 3, /**< uart3_fatal_fault */
  kTopEgretAlertIdGpioFatalFault = 4, /**< gpio_fatal_fault */
  kTopEgretAlertIdSpiDeviceFatalFault = 5, /**< spi_device_fatal_fault */
  kTopEgretAlertIdI2c0FatalFault = 6, /**< i2c0_fatal_fault */
  kTopEgretAlertIdI2c1FatalFault = 7, /**< i2c1_fatal_fault */
  kTopEgretAlertIdI2c2FatalFault = 8, /**< i2c2_fatal_fault */
  kTopEgretAlertIdPattgenFatalFault = 9, /**< pattgen_fatal_fault */
  kTopEgretAlertIdRvTimerFatalFault = 10, /**< rv_timer_fatal_fault */
  kTopEgretAlertIdOtpCtrlFatalMacroError = 11, /**< otp_ctrl_fatal_macro_error */
  kTopEgretAlertIdOtpCtrlFatalCheckError = 12, /**< otp_ctrl_fatal_check_error */
  kTopEgretAlertIdOtpCtrlFatalBusIntegError = 13, /**< otp_ctrl_fatal_bus_integ_error */
  kTopEgretAlertIdOtpCtrlFatalPrimOtpAlert = 14, /**< otp_ctrl_fatal_prim_otp_alert */
  kTopEgretAlertIdOtpCtrlRecovPrimOtpAlert = 15, /**< otp_ctrl_recov_prim_otp_alert */
  kTopEgretAlertIdLcCtrlFatalProgError = 16, /**< lc_ctrl_fatal_prog_error */
  kTopEgretAlertIdLcCtrlFatalStateError = 17, /**< lc_ctrl_fatal_state_error */
  kTopEgretAlertIdLcCtrlFatalBusIntegError = 18, /**< lc_ctrl_fatal_bus_integ_error */
  kTopEgretAlertIdSpiHost0FatalFault = 19, /**< spi_host0_fatal_fault */
  kTopEgretAlertIdSpiHost1FatalFault = 20, /**< spi_host1_fatal_fault */
  kTopEgretAlertIdUsbdevFatalFault = 21, /**< usbdev_fatal_fault */
  kTopEgretAlertIdPwrmgrAonFatalFault = 22, /**< pwrmgr_aon_fatal_fault */
  kTopEgretAlertIdRstmgrAonFatalFault = 23, /**< rstmgr_aon_fatal_fault */
  kTopEgretAlertIdRstmgrAonFatalCnstyFault = 24, /**< rstmgr_aon_fatal_cnsty_fault */
  kTopEgretAlertIdClkmgrAonRecovFault = 25, /**< clkmgr_aon_recov_fault */
  kTopEgretAlertIdClkmgrAonFatalFault = 26, /**< clkmgr_aon_fatal_fault */
  kTopEgretAlertIdSysrstCtrlAonFatalFault = 27, /**< sysrst_ctrl_aon_fatal_fault */
  kTopEgretAlertIdAdcCtrlAonFatalFault = 28, /**< adc_ctrl_aon_fatal_fault */
  kTopEgretAlertIdPwmAonFatalFault = 29, /**< pwm_aon_fatal_fault */
  kTopEgretAlertIdPinmuxAonFatalFault = 30, /**< pinmux_aon_fatal_fault */
  kTopEgretAlertIdAonTimerAonFatalFault = 31, /**< aon_timer_aon_fatal_fault */
  kTopEgretAlertIdSensorCtrlAonRecovAlert = 32, /**< sensor_ctrl_aon_recov_alert */
  kTopEgretAlertIdSensorCtrlAonFatalAlert = 33, /**< sensor_ctrl_aon_fatal_alert */
  kTopEgretAlertIdSramCtrlRetAonFatalError = 34, /**< sram_ctrl_ret_aon_fatal_error */
  kTopEgretAlertIdFlashCtrlRecovErr = 35, /**< flash_ctrl_recov_err */
  kTopEgretAlertIdFlashCtrlFatalStdErr = 36, /**< flash_ctrl_fatal_std_err */
  kTopEgretAlertIdFlashCtrlFatalErr = 37, /**< flash_ctrl_fatal_err */
  kTopEgretAlertIdFlashCtrlFatalPrimFlashAlert = 38, /**< flash_ctrl_fatal_prim_flash_alert */
  kTopEgretAlertIdFlashCtrlRecovPrimFlashAlert = 39, /**< flash_ctrl_recov_prim_flash_alert */
  kTopEgretAlertIdRvDmFatalFault = 40, /**< rv_dm_fatal_fault */
  kTopEgretAlertIdRvPlicFatalFault = 41, /**< rv_plic_fatal_fault */
  kTopEgretAlertIdAccFatal = 42, /**< acc_fatal */
  kTopEgretAlertIdAccRecov = 43, /**< acc_recov */
  kTopEgretAlertIdAesRecovCtrlUpdateErr = 44, /**< aes_recov_ctrl_update_err */
  kTopEgretAlertIdAesFatalFault = 45, /**< aes_fatal_fault */
  kTopEgretAlertIdHmacFatalFault = 46, /**< hmac_fatal_fault */
  kTopEgretAlertIdKmacRecovOperationErr = 47, /**< kmac_recov_operation_err */
  kTopEgretAlertIdKmacFatalFaultErr = 48, /**< kmac_fatal_fault_err */
  kTopEgretAlertIdKeymgrRecovOperationErr = 49, /**< keymgr_recov_operation_err */
  kTopEgretAlertIdKeymgrFatalFaultErr = 50, /**< keymgr_fatal_fault_err */
  kTopEgretAlertIdCsrngRecovAlert = 51, /**< csrng_recov_alert */
  kTopEgretAlertIdCsrngFatalAlert = 52, /**< csrng_fatal_alert */
  kTopEgretAlertIdEntropySrcRecovAlert = 53, /**< entropy_src_recov_alert */
  kTopEgretAlertIdEntropySrcFatalAlert = 54, /**< entropy_src_fatal_alert */
  kTopEgretAlertIdEdn0RecovAlert = 55, /**< edn0_recov_alert */
  kTopEgretAlertIdEdn0FatalAlert = 56, /**< edn0_fatal_alert */
  kTopEgretAlertIdEdn1RecovAlert = 57, /**< edn1_recov_alert */
  kTopEgretAlertIdEdn1FatalAlert = 58, /**< edn1_fatal_alert */
  kTopEgretAlertIdSramCtrlMainFatalError = 59, /**< sram_ctrl_main_fatal_error */
  kTopEgretAlertIdRomCtrlFatal = 60, /**< rom_ctrl_fatal */
  kTopEgretAlertIdRvCoreIbexFatalSwErr = 61, /**< rv_core_ibex_fatal_sw_err */
  kTopEgretAlertIdRvCoreIbexRecovSwErr = 62, /**< rv_core_ibex_recov_sw_err */
  kTopEgretAlertIdRvCoreIbexFatalHwErr = 63, /**< rv_core_ibex_fatal_hw_err */
  kTopEgretAlertIdRvCoreIbexRecovHwErr = 64, /**< rv_core_ibex_recov_hw_err */
  kTopEgretAlertIdLast = 64, /**< \internal The Last Valid Alert ID. */
} top_egret_alert_id_t;

/**
 * Alert Handler Alert Source to Peripheral Map
 *
 * This array is a mapping from `top_egret_alert_id_t` to
 * `top_egret_alert_peripheral_t`.
 */
extern const top_egret_alert_peripheral_t
    top_egret_alert_for_peripheral[65];

#define PINMUX_MIO_PERIPH_INSEL_IDX_OFFSET 2

// PERIPH_INSEL ranges from 0 to NUM_MIO_PADS + 2 -1}
//  0 and 1 are tied to value 0 and 1
#define NUM_MIO_PADS 47
#define NUM_DIO_PADS 16

#define PINMUX_PERIPH_OUTSEL_IDX_OFFSET 3

/**
 * Pinmux Peripheral Input.
 */
typedef enum top_egret_pinmux_peripheral_in {
  kTopEgretPinmuxPeripheralInGpioGpio0 = 0, /**< Peripheral Input 0 */
  kTopEgretPinmuxPeripheralInGpioGpio1 = 1, /**< Peripheral Input 1 */
  kTopEgretPinmuxPeripheralInGpioGpio2 = 2, /**< Peripheral Input 2 */
  kTopEgretPinmuxPeripheralInGpioGpio3 = 3, /**< Peripheral Input 3 */
  kTopEgretPinmuxPeripheralInGpioGpio4 = 4, /**< Peripheral Input 4 */
  kTopEgretPinmuxPeripheralInGpioGpio5 = 5, /**< Peripheral Input 5 */
  kTopEgretPinmuxPeripheralInGpioGpio6 = 6, /**< Peripheral Input 6 */
  kTopEgretPinmuxPeripheralInGpioGpio7 = 7, /**< Peripheral Input 7 */
  kTopEgretPinmuxPeripheralInGpioGpio8 = 8, /**< Peripheral Input 8 */
  kTopEgretPinmuxPeripheralInGpioGpio9 = 9, /**< Peripheral Input 9 */
  kTopEgretPinmuxPeripheralInGpioGpio10 = 10, /**< Peripheral Input 10 */
  kTopEgretPinmuxPeripheralInGpioGpio11 = 11, /**< Peripheral Input 11 */
  kTopEgretPinmuxPeripheralInGpioGpio12 = 12, /**< Peripheral Input 12 */
  kTopEgretPinmuxPeripheralInGpioGpio13 = 13, /**< Peripheral Input 13 */
  kTopEgretPinmuxPeripheralInGpioGpio14 = 14, /**< Peripheral Input 14 */
  kTopEgretPinmuxPeripheralInGpioGpio15 = 15, /**< Peripheral Input 15 */
  kTopEgretPinmuxPeripheralInGpioGpio16 = 16, /**< Peripheral Input 16 */
  kTopEgretPinmuxPeripheralInGpioGpio17 = 17, /**< Peripheral Input 17 */
  kTopEgretPinmuxPeripheralInGpioGpio18 = 18, /**< Peripheral Input 18 */
  kTopEgretPinmuxPeripheralInGpioGpio19 = 19, /**< Peripheral Input 19 */
  kTopEgretPinmuxPeripheralInGpioGpio20 = 20, /**< Peripheral Input 20 */
  kTopEgretPinmuxPeripheralInGpioGpio21 = 21, /**< Peripheral Input 21 */
  kTopEgretPinmuxPeripheralInGpioGpio22 = 22, /**< Peripheral Input 22 */
  kTopEgretPinmuxPeripheralInGpioGpio23 = 23, /**< Peripheral Input 23 */
  kTopEgretPinmuxPeripheralInGpioGpio24 = 24, /**< Peripheral Input 24 */
  kTopEgretPinmuxPeripheralInGpioGpio25 = 25, /**< Peripheral Input 25 */
  kTopEgretPinmuxPeripheralInGpioGpio26 = 26, /**< Peripheral Input 26 */
  kTopEgretPinmuxPeripheralInGpioGpio27 = 27, /**< Peripheral Input 27 */
  kTopEgretPinmuxPeripheralInGpioGpio28 = 28, /**< Peripheral Input 28 */
  kTopEgretPinmuxPeripheralInGpioGpio29 = 29, /**< Peripheral Input 29 */
  kTopEgretPinmuxPeripheralInGpioGpio30 = 30, /**< Peripheral Input 30 */
  kTopEgretPinmuxPeripheralInGpioGpio31 = 31, /**< Peripheral Input 31 */
  kTopEgretPinmuxPeripheralInI2c0Sda = 32, /**< Peripheral Input 32 */
  kTopEgretPinmuxPeripheralInI2c0Scl = 33, /**< Peripheral Input 33 */
  kTopEgretPinmuxPeripheralInI2c1Sda = 34, /**< Peripheral Input 34 */
  kTopEgretPinmuxPeripheralInI2c1Scl = 35, /**< Peripheral Input 35 */
  kTopEgretPinmuxPeripheralInI2c2Sda = 36, /**< Peripheral Input 36 */
  kTopEgretPinmuxPeripheralInI2c2Scl = 37, /**< Peripheral Input 37 */
  kTopEgretPinmuxPeripheralInSpiHost1Sd0 = 38, /**< Peripheral Input 38 */
  kTopEgretPinmuxPeripheralInSpiHost1Sd1 = 39, /**< Peripheral Input 39 */
  kTopEgretPinmuxPeripheralInSpiHost1Sd2 = 40, /**< Peripheral Input 40 */
  kTopEgretPinmuxPeripheralInSpiHost1Sd3 = 41, /**< Peripheral Input 41 */
  kTopEgretPinmuxPeripheralInUart0Rx = 42, /**< Peripheral Input 42 */
  kTopEgretPinmuxPeripheralInUart1Rx = 43, /**< Peripheral Input 43 */
  kTopEgretPinmuxPeripheralInUart2Rx = 44, /**< Peripheral Input 44 */
  kTopEgretPinmuxPeripheralInUart3Rx = 45, /**< Peripheral Input 45 */
  kTopEgretPinmuxPeripheralInSpiDeviceTpmCsb = 46, /**< Peripheral Input 46 */
  kTopEgretPinmuxPeripheralInFlashMacroWrapperTck = 47, /**< Peripheral Input 47 */
  kTopEgretPinmuxPeripheralInFlashMacroWrapperTms = 48, /**< Peripheral Input 48 */
  kTopEgretPinmuxPeripheralInFlashMacroWrapperTdi = 49, /**< Peripheral Input 49 */
  kTopEgretPinmuxPeripheralInSysrstCtrlAonAcPresent = 50, /**< Peripheral Input 50 */
  kTopEgretPinmuxPeripheralInSysrstCtrlAonKey0In = 51, /**< Peripheral Input 51 */
  kTopEgretPinmuxPeripheralInSysrstCtrlAonKey1In = 52, /**< Peripheral Input 52 */
  kTopEgretPinmuxPeripheralInSysrstCtrlAonKey2In = 53, /**< Peripheral Input 53 */
  kTopEgretPinmuxPeripheralInSysrstCtrlAonPwrbIn = 54, /**< Peripheral Input 54 */
  kTopEgretPinmuxPeripheralInSysrstCtrlAonLidOpen = 55, /**< Peripheral Input 55 */
  kTopEgretPinmuxPeripheralInUsbdevSense = 56, /**< Peripheral Input 56 */
  kTopEgretPinmuxPeripheralInLast = 56, /**< \internal Last valid peripheral input */
} top_egret_pinmux_peripheral_in_t;

/**
 * Pinmux MIO Input Selector.
 */
typedef enum top_egret_pinmux_insel {
  kTopEgretPinmuxInselConstantZero = 0, /**< Tie constantly to zero */
  kTopEgretPinmuxInselConstantOne = 1, /**< Tie constantly to one */
  kTopEgretPinmuxInselIoa0 = 2, /**< MIO Pad 0 */
  kTopEgretPinmuxInselIoa1 = 3, /**< MIO Pad 1 */
  kTopEgretPinmuxInselIoa2 = 4, /**< MIO Pad 2 */
  kTopEgretPinmuxInselIoa3 = 5, /**< MIO Pad 3 */
  kTopEgretPinmuxInselIoa4 = 6, /**< MIO Pad 4 */
  kTopEgretPinmuxInselIoa5 = 7, /**< MIO Pad 5 */
  kTopEgretPinmuxInselIoa6 = 8, /**< MIO Pad 6 */
  kTopEgretPinmuxInselIoa7 = 9, /**< MIO Pad 7 */
  kTopEgretPinmuxInselIoa8 = 10, /**< MIO Pad 8 */
  kTopEgretPinmuxInselIob0 = 11, /**< MIO Pad 9 */
  kTopEgretPinmuxInselIob1 = 12, /**< MIO Pad 10 */
  kTopEgretPinmuxInselIob2 = 13, /**< MIO Pad 11 */
  kTopEgretPinmuxInselIob3 = 14, /**< MIO Pad 12 */
  kTopEgretPinmuxInselIob4 = 15, /**< MIO Pad 13 */
  kTopEgretPinmuxInselIob5 = 16, /**< MIO Pad 14 */
  kTopEgretPinmuxInselIob6 = 17, /**< MIO Pad 15 */
  kTopEgretPinmuxInselIob7 = 18, /**< MIO Pad 16 */
  kTopEgretPinmuxInselIob8 = 19, /**< MIO Pad 17 */
  kTopEgretPinmuxInselIob9 = 20, /**< MIO Pad 18 */
  kTopEgretPinmuxInselIob10 = 21, /**< MIO Pad 19 */
  kTopEgretPinmuxInselIob11 = 22, /**< MIO Pad 20 */
  kTopEgretPinmuxInselIob12 = 23, /**< MIO Pad 21 */
  kTopEgretPinmuxInselIoc0 = 24, /**< MIO Pad 22 */
  kTopEgretPinmuxInselIoc1 = 25, /**< MIO Pad 23 */
  kTopEgretPinmuxInselIoc2 = 26, /**< MIO Pad 24 */
  kTopEgretPinmuxInselIoc3 = 27, /**< MIO Pad 25 */
  kTopEgretPinmuxInselIoc4 = 28, /**< MIO Pad 26 */
  kTopEgretPinmuxInselIoc5 = 29, /**< MIO Pad 27 */
  kTopEgretPinmuxInselIoc6 = 30, /**< MIO Pad 28 */
  kTopEgretPinmuxInselIoc7 = 31, /**< MIO Pad 29 */
  kTopEgretPinmuxInselIoc8 = 32, /**< MIO Pad 30 */
  kTopEgretPinmuxInselIoc9 = 33, /**< MIO Pad 31 */
  kTopEgretPinmuxInselIoc10 = 34, /**< MIO Pad 32 */
  kTopEgretPinmuxInselIoc11 = 35, /**< MIO Pad 33 */
  kTopEgretPinmuxInselIoc12 = 36, /**< MIO Pad 34 */
  kTopEgretPinmuxInselIor0 = 37, /**< MIO Pad 35 */
  kTopEgretPinmuxInselIor1 = 38, /**< MIO Pad 36 */
  kTopEgretPinmuxInselIor2 = 39, /**< MIO Pad 37 */
  kTopEgretPinmuxInselIor3 = 40, /**< MIO Pad 38 */
  kTopEgretPinmuxInselIor4 = 41, /**< MIO Pad 39 */
  kTopEgretPinmuxInselIor5 = 42, /**< MIO Pad 40 */
  kTopEgretPinmuxInselIor6 = 43, /**< MIO Pad 41 */
  kTopEgretPinmuxInselIor7 = 44, /**< MIO Pad 42 */
  kTopEgretPinmuxInselIor10 = 45, /**< MIO Pad 43 */
  kTopEgretPinmuxInselIor11 = 46, /**< MIO Pad 44 */
  kTopEgretPinmuxInselIor12 = 47, /**< MIO Pad 45 */
  kTopEgretPinmuxInselIor13 = 48, /**< MIO Pad 46 */
  kTopEgretPinmuxInselLast = 48, /**< \internal Last valid insel value */
} top_egret_pinmux_insel_t;

/**
 * Pinmux MIO Output.
 */
typedef enum top_egret_pinmux_mio_out {
  kTopEgretPinmuxMioOutIoa0 = 0, /**< MIO Pad 0 */
  kTopEgretPinmuxMioOutIoa1 = 1, /**< MIO Pad 1 */
  kTopEgretPinmuxMioOutIoa2 = 2, /**< MIO Pad 2 */
  kTopEgretPinmuxMioOutIoa3 = 3, /**< MIO Pad 3 */
  kTopEgretPinmuxMioOutIoa4 = 4, /**< MIO Pad 4 */
  kTopEgretPinmuxMioOutIoa5 = 5, /**< MIO Pad 5 */
  kTopEgretPinmuxMioOutIoa6 = 6, /**< MIO Pad 6 */
  kTopEgretPinmuxMioOutIoa7 = 7, /**< MIO Pad 7 */
  kTopEgretPinmuxMioOutIoa8 = 8, /**< MIO Pad 8 */
  kTopEgretPinmuxMioOutIob0 = 9, /**< MIO Pad 9 */
  kTopEgretPinmuxMioOutIob1 = 10, /**< MIO Pad 10 */
  kTopEgretPinmuxMioOutIob2 = 11, /**< MIO Pad 11 */
  kTopEgretPinmuxMioOutIob3 = 12, /**< MIO Pad 12 */
  kTopEgretPinmuxMioOutIob4 = 13, /**< MIO Pad 13 */
  kTopEgretPinmuxMioOutIob5 = 14, /**< MIO Pad 14 */
  kTopEgretPinmuxMioOutIob6 = 15, /**< MIO Pad 15 */
  kTopEgretPinmuxMioOutIob7 = 16, /**< MIO Pad 16 */
  kTopEgretPinmuxMioOutIob8 = 17, /**< MIO Pad 17 */
  kTopEgretPinmuxMioOutIob9 = 18, /**< MIO Pad 18 */
  kTopEgretPinmuxMioOutIob10 = 19, /**< MIO Pad 19 */
  kTopEgretPinmuxMioOutIob11 = 20, /**< MIO Pad 20 */
  kTopEgretPinmuxMioOutIob12 = 21, /**< MIO Pad 21 */
  kTopEgretPinmuxMioOutIoc0 = 22, /**< MIO Pad 22 */
  kTopEgretPinmuxMioOutIoc1 = 23, /**< MIO Pad 23 */
  kTopEgretPinmuxMioOutIoc2 = 24, /**< MIO Pad 24 */
  kTopEgretPinmuxMioOutIoc3 = 25, /**< MIO Pad 25 */
  kTopEgretPinmuxMioOutIoc4 = 26, /**< MIO Pad 26 */
  kTopEgretPinmuxMioOutIoc5 = 27, /**< MIO Pad 27 */
  kTopEgretPinmuxMioOutIoc6 = 28, /**< MIO Pad 28 */
  kTopEgretPinmuxMioOutIoc7 = 29, /**< MIO Pad 29 */
  kTopEgretPinmuxMioOutIoc8 = 30, /**< MIO Pad 30 */
  kTopEgretPinmuxMioOutIoc9 = 31, /**< MIO Pad 31 */
  kTopEgretPinmuxMioOutIoc10 = 32, /**< MIO Pad 32 */
  kTopEgretPinmuxMioOutIoc11 = 33, /**< MIO Pad 33 */
  kTopEgretPinmuxMioOutIoc12 = 34, /**< MIO Pad 34 */
  kTopEgretPinmuxMioOutIor0 = 35, /**< MIO Pad 35 */
  kTopEgretPinmuxMioOutIor1 = 36, /**< MIO Pad 36 */
  kTopEgretPinmuxMioOutIor2 = 37, /**< MIO Pad 37 */
  kTopEgretPinmuxMioOutIor3 = 38, /**< MIO Pad 38 */
  kTopEgretPinmuxMioOutIor4 = 39, /**< MIO Pad 39 */
  kTopEgretPinmuxMioOutIor5 = 40, /**< MIO Pad 40 */
  kTopEgretPinmuxMioOutIor6 = 41, /**< MIO Pad 41 */
  kTopEgretPinmuxMioOutIor7 = 42, /**< MIO Pad 42 */
  kTopEgretPinmuxMioOutIor10 = 43, /**< MIO Pad 43 */
  kTopEgretPinmuxMioOutIor11 = 44, /**< MIO Pad 44 */
  kTopEgretPinmuxMioOutIor12 = 45, /**< MIO Pad 45 */
  kTopEgretPinmuxMioOutIor13 = 46, /**< MIO Pad 46 */
  kTopEgretPinmuxMioOutLast = 46, /**< \internal Last valid mio output */
} top_egret_pinmux_mio_out_t;

/**
 * Pinmux Peripheral Output Selector.
 */
typedef enum top_egret_pinmux_outsel {
  kTopEgretPinmuxOutselConstantZero = 0, /**< Tie constantly to zero */
  kTopEgretPinmuxOutselConstantOne = 1, /**< Tie constantly to one */
  kTopEgretPinmuxOutselConstantHighZ = 2, /**< Tie constantly to high-Z */
  kTopEgretPinmuxOutselGpioGpio0 = 3, /**< Peripheral Output 0 */
  kTopEgretPinmuxOutselGpioGpio1 = 4, /**< Peripheral Output 1 */
  kTopEgretPinmuxOutselGpioGpio2 = 5, /**< Peripheral Output 2 */
  kTopEgretPinmuxOutselGpioGpio3 = 6, /**< Peripheral Output 3 */
  kTopEgretPinmuxOutselGpioGpio4 = 7, /**< Peripheral Output 4 */
  kTopEgretPinmuxOutselGpioGpio5 = 8, /**< Peripheral Output 5 */
  kTopEgretPinmuxOutselGpioGpio6 = 9, /**< Peripheral Output 6 */
  kTopEgretPinmuxOutselGpioGpio7 = 10, /**< Peripheral Output 7 */
  kTopEgretPinmuxOutselGpioGpio8 = 11, /**< Peripheral Output 8 */
  kTopEgretPinmuxOutselGpioGpio9 = 12, /**< Peripheral Output 9 */
  kTopEgretPinmuxOutselGpioGpio10 = 13, /**< Peripheral Output 10 */
  kTopEgretPinmuxOutselGpioGpio11 = 14, /**< Peripheral Output 11 */
  kTopEgretPinmuxOutselGpioGpio12 = 15, /**< Peripheral Output 12 */
  kTopEgretPinmuxOutselGpioGpio13 = 16, /**< Peripheral Output 13 */
  kTopEgretPinmuxOutselGpioGpio14 = 17, /**< Peripheral Output 14 */
  kTopEgretPinmuxOutselGpioGpio15 = 18, /**< Peripheral Output 15 */
  kTopEgretPinmuxOutselGpioGpio16 = 19, /**< Peripheral Output 16 */
  kTopEgretPinmuxOutselGpioGpio17 = 20, /**< Peripheral Output 17 */
  kTopEgretPinmuxOutselGpioGpio18 = 21, /**< Peripheral Output 18 */
  kTopEgretPinmuxOutselGpioGpio19 = 22, /**< Peripheral Output 19 */
  kTopEgretPinmuxOutselGpioGpio20 = 23, /**< Peripheral Output 20 */
  kTopEgretPinmuxOutselGpioGpio21 = 24, /**< Peripheral Output 21 */
  kTopEgretPinmuxOutselGpioGpio22 = 25, /**< Peripheral Output 22 */
  kTopEgretPinmuxOutselGpioGpio23 = 26, /**< Peripheral Output 23 */
  kTopEgretPinmuxOutselGpioGpio24 = 27, /**< Peripheral Output 24 */
  kTopEgretPinmuxOutselGpioGpio25 = 28, /**< Peripheral Output 25 */
  kTopEgretPinmuxOutselGpioGpio26 = 29, /**< Peripheral Output 26 */
  kTopEgretPinmuxOutselGpioGpio27 = 30, /**< Peripheral Output 27 */
  kTopEgretPinmuxOutselGpioGpio28 = 31, /**< Peripheral Output 28 */
  kTopEgretPinmuxOutselGpioGpio29 = 32, /**< Peripheral Output 29 */
  kTopEgretPinmuxOutselGpioGpio30 = 33, /**< Peripheral Output 30 */
  kTopEgretPinmuxOutselGpioGpio31 = 34, /**< Peripheral Output 31 */
  kTopEgretPinmuxOutselI2c0Sda = 35, /**< Peripheral Output 32 */
  kTopEgretPinmuxOutselI2c0Scl = 36, /**< Peripheral Output 33 */
  kTopEgretPinmuxOutselI2c1Sda = 37, /**< Peripheral Output 34 */
  kTopEgretPinmuxOutselI2c1Scl = 38, /**< Peripheral Output 35 */
  kTopEgretPinmuxOutselI2c2Sda = 39, /**< Peripheral Output 36 */
  kTopEgretPinmuxOutselI2c2Scl = 40, /**< Peripheral Output 37 */
  kTopEgretPinmuxOutselSpiHost1Sd0 = 41, /**< Peripheral Output 38 */
  kTopEgretPinmuxOutselSpiHost1Sd1 = 42, /**< Peripheral Output 39 */
  kTopEgretPinmuxOutselSpiHost1Sd2 = 43, /**< Peripheral Output 40 */
  kTopEgretPinmuxOutselSpiHost1Sd3 = 44, /**< Peripheral Output 41 */
  kTopEgretPinmuxOutselUart0Tx = 45, /**< Peripheral Output 42 */
  kTopEgretPinmuxOutselUart1Tx = 46, /**< Peripheral Output 43 */
  kTopEgretPinmuxOutselUart2Tx = 47, /**< Peripheral Output 44 */
  kTopEgretPinmuxOutselUart3Tx = 48, /**< Peripheral Output 45 */
  kTopEgretPinmuxOutselPattgenPda0Tx = 49, /**< Peripheral Output 46 */
  kTopEgretPinmuxOutselPattgenPcl0Tx = 50, /**< Peripheral Output 47 */
  kTopEgretPinmuxOutselPattgenPda1Tx = 51, /**< Peripheral Output 48 */
  kTopEgretPinmuxOutselPattgenPcl1Tx = 52, /**< Peripheral Output 49 */
  kTopEgretPinmuxOutselSpiHost1Sck = 53, /**< Peripheral Output 50 */
  kTopEgretPinmuxOutselSpiHost1Csb = 54, /**< Peripheral Output 51 */
  kTopEgretPinmuxOutselFlashMacroWrapperTdo = 55, /**< Peripheral Output 52 */
  kTopEgretPinmuxOutselSensorCtrlAonAstDebugOut0 = 56, /**< Peripheral Output 53 */
  kTopEgretPinmuxOutselSensorCtrlAonAstDebugOut1 = 57, /**< Peripheral Output 54 */
  kTopEgretPinmuxOutselSensorCtrlAonAstDebugOut2 = 58, /**< Peripheral Output 55 */
  kTopEgretPinmuxOutselSensorCtrlAonAstDebugOut3 = 59, /**< Peripheral Output 56 */
  kTopEgretPinmuxOutselSensorCtrlAonAstDebugOut4 = 60, /**< Peripheral Output 57 */
  kTopEgretPinmuxOutselSensorCtrlAonAstDebugOut5 = 61, /**< Peripheral Output 58 */
  kTopEgretPinmuxOutselSensorCtrlAonAstDebugOut6 = 62, /**< Peripheral Output 59 */
  kTopEgretPinmuxOutselSensorCtrlAonAstDebugOut7 = 63, /**< Peripheral Output 60 */
  kTopEgretPinmuxOutselSensorCtrlAonAstDebugOut8 = 64, /**< Peripheral Output 61 */
  kTopEgretPinmuxOutselPwmAonPwm0 = 65, /**< Peripheral Output 62 */
  kTopEgretPinmuxOutselPwmAonPwm1 = 66, /**< Peripheral Output 63 */
  kTopEgretPinmuxOutselPwmAonPwm2 = 67, /**< Peripheral Output 64 */
  kTopEgretPinmuxOutselPwmAonPwm3 = 68, /**< Peripheral Output 65 */
  kTopEgretPinmuxOutselPwmAonPwm4 = 69, /**< Peripheral Output 66 */
  kTopEgretPinmuxOutselPwmAonPwm5 = 70, /**< Peripheral Output 67 */
  kTopEgretPinmuxOutselOtpMacroTest0 = 71, /**< Peripheral Output 68 */
  kTopEgretPinmuxOutselSysrstCtrlAonBatDisable = 72, /**< Peripheral Output 69 */
  kTopEgretPinmuxOutselSysrstCtrlAonKey0Out = 73, /**< Peripheral Output 70 */
  kTopEgretPinmuxOutselSysrstCtrlAonKey1Out = 74, /**< Peripheral Output 71 */
  kTopEgretPinmuxOutselSysrstCtrlAonKey2Out = 75, /**< Peripheral Output 72 */
  kTopEgretPinmuxOutselSysrstCtrlAonPwrbOut = 76, /**< Peripheral Output 73 */
  kTopEgretPinmuxOutselSysrstCtrlAonZ3Wakeup = 77, /**< Peripheral Output 74 */
  kTopEgretPinmuxOutselLast = 77, /**< \internal Last valid outsel value */
} top_egret_pinmux_outsel_t;

/**
 * Dedicated Pad Selects
 */
typedef enum top_egret_direct_pads {
  kTopEgretDirectPadsUsbdevUsbDp = 0, /**<  */
  kTopEgretDirectPadsUsbdevUsbDn = 1, /**<  */
  kTopEgretDirectPadsSpiHost0Sd0 = 2, /**<  */
  kTopEgretDirectPadsSpiHost0Sd1 = 3, /**<  */
  kTopEgretDirectPadsSpiHost0Sd2 = 4, /**<  */
  kTopEgretDirectPadsSpiHost0Sd3 = 5, /**<  */
  kTopEgretDirectPadsSpiDeviceSd0 = 6, /**<  */
  kTopEgretDirectPadsSpiDeviceSd1 = 7, /**<  */
  kTopEgretDirectPadsSpiDeviceSd2 = 8, /**<  */
  kTopEgretDirectPadsSpiDeviceSd3 = 9, /**<  */
  kTopEgretDirectPadsSysrstCtrlAonEcRstL = 10, /**<  */
  kTopEgretDirectPadsSysrstCtrlAonFlashWpL = 11, /**<  */
  kTopEgretDirectPadsSpiDeviceSck = 12, /**<  */
  kTopEgretDirectPadsSpiDeviceCsb = 13, /**<  */
  kTopEgretDirectPadsSpiHost0Sck = 14, /**<  */
  kTopEgretDirectPadsSpiHost0Csb = 15, /**<  */
  kTopEgretDirectPadsLast = 15, /**< \internal Last valid direct pad */
} top_egret_direct_pads_t;

/**
 * Muxed Pad Selects
 */
typedef enum top_egret_muxed_pads {
  kTopEgretMuxedPadsIoa0 = 0, /**<  */
  kTopEgretMuxedPadsIoa1 = 1, /**<  */
  kTopEgretMuxedPadsIoa2 = 2, /**<  */
  kTopEgretMuxedPadsIoa3 = 3, /**<  */
  kTopEgretMuxedPadsIoa4 = 4, /**<  */
  kTopEgretMuxedPadsIoa5 = 5, /**<  */
  kTopEgretMuxedPadsIoa6 = 6, /**<  */
  kTopEgretMuxedPadsIoa7 = 7, /**<  */
  kTopEgretMuxedPadsIoa8 = 8, /**<  */
  kTopEgretMuxedPadsIob0 = 9, /**<  */
  kTopEgretMuxedPadsIob1 = 10, /**<  */
  kTopEgretMuxedPadsIob2 = 11, /**<  */
  kTopEgretMuxedPadsIob3 = 12, /**<  */
  kTopEgretMuxedPadsIob4 = 13, /**<  */
  kTopEgretMuxedPadsIob5 = 14, /**<  */
  kTopEgretMuxedPadsIob6 = 15, /**<  */
  kTopEgretMuxedPadsIob7 = 16, /**<  */
  kTopEgretMuxedPadsIob8 = 17, /**<  */
  kTopEgretMuxedPadsIob9 = 18, /**<  */
  kTopEgretMuxedPadsIob10 = 19, /**<  */
  kTopEgretMuxedPadsIob11 = 20, /**<  */
  kTopEgretMuxedPadsIob12 = 21, /**<  */
  kTopEgretMuxedPadsIoc0 = 22, /**<  */
  kTopEgretMuxedPadsIoc1 = 23, /**<  */
  kTopEgretMuxedPadsIoc2 = 24, /**<  */
  kTopEgretMuxedPadsIoc3 = 25, /**<  */
  kTopEgretMuxedPadsIoc4 = 26, /**<  */
  kTopEgretMuxedPadsIoc5 = 27, /**<  */
  kTopEgretMuxedPadsIoc6 = 28, /**<  */
  kTopEgretMuxedPadsIoc7 = 29, /**<  */
  kTopEgretMuxedPadsIoc8 = 30, /**<  */
  kTopEgretMuxedPadsIoc9 = 31, /**<  */
  kTopEgretMuxedPadsIoc10 = 32, /**<  */
  kTopEgretMuxedPadsIoc11 = 33, /**<  */
  kTopEgretMuxedPadsIoc12 = 34, /**<  */
  kTopEgretMuxedPadsIor0 = 35, /**<  */
  kTopEgretMuxedPadsIor1 = 36, /**<  */
  kTopEgretMuxedPadsIor2 = 37, /**<  */
  kTopEgretMuxedPadsIor3 = 38, /**<  */
  kTopEgretMuxedPadsIor4 = 39, /**<  */
  kTopEgretMuxedPadsIor5 = 40, /**<  */
  kTopEgretMuxedPadsIor6 = 41, /**<  */
  kTopEgretMuxedPadsIor7 = 42, /**<  */
  kTopEgretMuxedPadsIor10 = 43, /**<  */
  kTopEgretMuxedPadsIor11 = 44, /**<  */
  kTopEgretMuxedPadsIor12 = 45, /**<  */
  kTopEgretMuxedPadsIor13 = 46, /**<  */
  kTopEgretMuxedPadsLast = 46, /**< \internal Last valid muxed pad */
} top_egret_muxed_pads_t;

/**
 * Power Manager Wakeup Signals
 */
typedef enum top_egret_power_manager_wake_ups {
  kTopEgretPowerManagerWakeUpsSysrstCtrlAonWkupReq = 0, /**<  */
  kTopEgretPowerManagerWakeUpsAdcCtrlAonWkupReq = 1, /**<  */
  kTopEgretPowerManagerWakeUpsPinmuxAonPinWkupReq = 2, /**<  */
  kTopEgretPowerManagerWakeUpsPinmuxAonUsbWkupReq = 3, /**<  */
  kTopEgretPowerManagerWakeUpsAonTimerAonWkupReq = 4, /**<  */
  kTopEgretPowerManagerWakeUpsSensorCtrlAonWkupReq = 5, /**<  */
  kTopEgretPowerManagerWakeUpsLast = 5, /**< \internal Last valid pwrmgr wakeup signal */
} top_egret_power_manager_wake_ups_t;

/**
 * Reset Manager Software Controlled Resets
 */
typedef enum top_egret_reset_manager_sw_resets {
  kTopEgretResetManagerSwResetsSpiDevice = 0, /**<  */
  kTopEgretResetManagerSwResetsSpiHost0 = 1, /**<  */
  kTopEgretResetManagerSwResetsSpiHost1 = 2, /**<  */
  kTopEgretResetManagerSwResetsUsb = 3, /**<  */
  kTopEgretResetManagerSwResetsUsbAon = 4, /**<  */
  kTopEgretResetManagerSwResetsI2c0 = 5, /**<  */
  kTopEgretResetManagerSwResetsI2c1 = 6, /**<  */
  kTopEgretResetManagerSwResetsI2c2 = 7, /**<  */
  kTopEgretResetManagerSwResetsLast = 7, /**< \internal Last valid rstmgr software reset request */
} top_egret_reset_manager_sw_resets_t;

/**
 * Power Manager Reset Request Signals
 */
typedef enum top_egret_power_manager_reset_requests {
  kTopEgretPowerManagerResetRequestsSysrstCtrlAonRstReq = 0, /**<  */
  kTopEgretPowerManagerResetRequestsAonTimerAonAonTimerRstReq = 1, /**<  */
  kTopEgretPowerManagerResetRequestsLast = 1, /**< \internal Last valid pwrmgr reset_request signal */
} top_egret_power_manager_reset_requests_t;

/**
 * Clock Manager Software-Controlled ("Gated") Clocks.
 *
 * The Software has full control over these clocks.
 */
typedef enum top_egret_gateable_clocks {
  kTopEgretGateableClocksIoDiv4Peri = 0, /**< Clock clk_io_div4_peri in group peri */
  kTopEgretGateableClocksIoDiv2Peri = 1, /**< Clock clk_io_div2_peri in group peri */
  kTopEgretGateableClocksIoPeri = 2, /**< Clock clk_io_peri in group peri */
  kTopEgretGateableClocksUsbPeri = 3, /**< Clock clk_usb_peri in group peri */
  kTopEgretGateableClocksLast = 3, /**< \internal Last Valid Gateable Clock */
} top_egret_gateable_clocks_t;

/**
 * Clock Manager Software-Hinted Clocks.
 *
 * The Software has partial control over these clocks. It can ask them to stop,
 * but the clock manager is in control of whether the clock actually is stopped.
 */
typedef enum top_egret_hintable_clocks {
  kTopEgretHintableClocksMainAcc = 0, /**< Clock clk_main_acc in group trans */
  kTopEgretHintableClocksMainAes = 1, /**< Clock clk_main_aes in group trans */
  kTopEgretHintableClocksMainHmac = 2, /**< Clock clk_main_hmac in group trans */
  kTopEgretHintableClocksMainKmac = 3, /**< Clock clk_main_kmac in group trans */
  kTopEgretHintableClocksLast = 3, /**< \internal Last Valid Hintable Clock */
} top_egret_hintable_clocks_t;

/**
 * MMIO Region
 *
 * MMIO region excludes any memory that is separate from the module
 * configuration space, i.e. ROM, main SRAM, and flash are excluded but
 * retention SRAM, spi_device memory, or usbdev memory are included.
 */
#define TOP_EGRET_MMIO_BASE_ADDR 0x40000000u
#define TOP_EGRET_MMIO_SIZE_BYTES 0x10000000u

// Header Extern Guard
#ifdef __cplusplus
}  // extern "C"
#endif

#endif  // OPENTITAN_HW_TOP_EGRET_SW_AUTOGEN_TOP_EGRET_H_
