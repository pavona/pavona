// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// ------------------- W A R N I N G: A U T O - G E N E R A T E D   C O D E !! -------------------//
// PLEASE DO NOT HAND-EDIT THIS FILE. IT HAS BEEN AUTO-GENERATED WITH THE FOLLOWING COMMAND:
// util/gen_top_sw.py -t hw/top_dragonfly/data/autogen/top_dragonfly.gen.hjson

#ifndef OPENTITAN_HW_TOP_DRAGONFLY_SW_AUTOGEN_TOP_DRAGONFLY_H_
#define OPENTITAN_HW_TOP_DRAGONFLY_SW_AUTOGEN_TOP_DRAGONFLY_H_

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
 * Peripheral base address for uart0 in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_UART0_BASE_ADDR 0x30010000u

/**
 * Peripheral size for uart0 in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_UART0_BASE_ADDR and
 * `TOP_DRAGONFLY_UART0_BASE_ADDR + TOP_DRAGONFLY_UART0_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_UART0_SIZE_BYTES 0x40u

/**
 * Peripheral base address for gpio in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_GPIO_BASE_ADDR 0x30000000u

/**
 * Peripheral size for gpio in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_GPIO_BASE_ADDR and
 * `TOP_DRAGONFLY_GPIO_BASE_ADDR + TOP_DRAGONFLY_GPIO_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_GPIO_SIZE_BYTES 0x100u

/**
 * Peripheral base address for spi_device in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_SPI_DEVICE_BASE_ADDR 0x30310000u

/**
 * Peripheral size for spi_device in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_SPI_DEVICE_BASE_ADDR and
 * `TOP_DRAGONFLY_SPI_DEVICE_BASE_ADDR + TOP_DRAGONFLY_SPI_DEVICE_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_SPI_DEVICE_SIZE_BYTES 0x2000u

/**
 * Peripheral base address for i2c0 in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_I2C0_BASE_ADDR 0x30080000u

/**
 * Peripheral size for i2c0 in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_I2C0_BASE_ADDR and
 * `TOP_DRAGONFLY_I2C0_BASE_ADDR + TOP_DRAGONFLY_I2C0_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_I2C0_SIZE_BYTES 0x80u

/**
 * Peripheral base address for rv_timer in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_RV_TIMER_BASE_ADDR 0x30100000u

/**
 * Peripheral size for rv_timer in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_RV_TIMER_BASE_ADDR and
 * `TOP_DRAGONFLY_RV_TIMER_BASE_ADDR + TOP_DRAGONFLY_RV_TIMER_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_RV_TIMER_SIZE_BYTES 0x200u

/**
 * Peripheral base address for core device on otp_ctrl in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_OTP_CTRL_CORE_BASE_ADDR 0x30130000u

/**
 * Peripheral size for core device on otp_ctrl in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_OTP_CTRL_CORE_BASE_ADDR and
 * `TOP_DRAGONFLY_OTP_CTRL_CORE_BASE_ADDR + TOP_DRAGONFLY_OTP_CTRL_CORE_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_OTP_CTRL_CORE_SIZE_BYTES 0x10000u

/**
 * Peripheral base address for prim device on otp_macro in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_OTP_MACRO_PRIM_BASE_ADDR 0x30140000u

/**
 * Peripheral size for prim device on otp_macro in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_OTP_MACRO_PRIM_BASE_ADDR and
 * `TOP_DRAGONFLY_OTP_MACRO_PRIM_BASE_ADDR + TOP_DRAGONFLY_OTP_MACRO_PRIM_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_OTP_MACRO_PRIM_SIZE_BYTES 0x20u

/**
 * Peripheral base address for regs device on lc_ctrl in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_LC_CTRL_REGS_BASE_ADDR 0x30150000u

/**
 * Peripheral size for regs device on lc_ctrl in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_LC_CTRL_REGS_BASE_ADDR and
 * `TOP_DRAGONFLY_LC_CTRL_REGS_BASE_ADDR + TOP_DRAGONFLY_LC_CTRL_REGS_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_LC_CTRL_REGS_SIZE_BYTES 0x100u

/**
 * Peripheral base address for alert_handler in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_ALERT_HANDLER_BASE_ADDR 0x30160000u

/**
 * Peripheral size for alert_handler in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_ALERT_HANDLER_BASE_ADDR and
 * `TOP_DRAGONFLY_ALERT_HANDLER_BASE_ADDR + TOP_DRAGONFLY_ALERT_HANDLER_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_ALERT_HANDLER_SIZE_BYTES 0x800u

/**
 * Peripheral base address for spi_host0 in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_SPI_HOST0_BASE_ADDR 0x30300000u

/**
 * Peripheral size for spi_host0 in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_SPI_HOST0_BASE_ADDR and
 * `TOP_DRAGONFLY_SPI_HOST0_BASE_ADDR + TOP_DRAGONFLY_SPI_HOST0_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_SPI_HOST0_SIZE_BYTES 0x40u

/**
 * Peripheral base address for pwrmgr_aon in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_PWRMGR_AON_BASE_ADDR 0x30400000u

/**
 * Peripheral size for pwrmgr_aon in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_PWRMGR_AON_BASE_ADDR and
 * `TOP_DRAGONFLY_PWRMGR_AON_BASE_ADDR + TOP_DRAGONFLY_PWRMGR_AON_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_PWRMGR_AON_SIZE_BYTES 0x80u

/**
 * Peripheral base address for rstmgr_aon in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_RSTMGR_AON_BASE_ADDR 0x30410000u

/**
 * Peripheral size for rstmgr_aon in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_RSTMGR_AON_BASE_ADDR and
 * `TOP_DRAGONFLY_RSTMGR_AON_BASE_ADDR + TOP_DRAGONFLY_RSTMGR_AON_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_RSTMGR_AON_SIZE_BYTES 0x80u

/**
 * Peripheral base address for clkmgr_aon in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_CLKMGR_AON_BASE_ADDR 0x30420000u

/**
 * Peripheral size for clkmgr_aon in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_CLKMGR_AON_BASE_ADDR and
 * `TOP_DRAGONFLY_CLKMGR_AON_BASE_ADDR + TOP_DRAGONFLY_CLKMGR_AON_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_CLKMGR_AON_SIZE_BYTES 0x40u

/**
 * Peripheral base address for pinmux_aon in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_PINMUX_AON_BASE_ADDR 0x30460000u

/**
 * Peripheral size for pinmux_aon in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_PINMUX_AON_BASE_ADDR and
 * `TOP_DRAGONFLY_PINMUX_AON_BASE_ADDR + TOP_DRAGONFLY_PINMUX_AON_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_PINMUX_AON_SIZE_BYTES 0x800u

/**
 * Peripheral base address for aon_timer_aon in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_AON_TIMER_AON_BASE_ADDR 0x30470000u

/**
 * Peripheral size for aon_timer_aon in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_AON_TIMER_AON_BASE_ADDR and
 * `TOP_DRAGONFLY_AON_TIMER_AON_BASE_ADDR + TOP_DRAGONFLY_AON_TIMER_AON_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_AON_TIMER_AON_SIZE_BYTES 0x40u

/**
 * Peripheral base address for ast in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_AST_BASE_ADDR 0x30480000u

/**
 * Peripheral size for ast in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_AST_BASE_ADDR and
 * `TOP_DRAGONFLY_AST_BASE_ADDR + TOP_DRAGONFLY_AST_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_AST_SIZE_BYTES 0x400u

/**
 * Peripheral base address for core device on soc_proxy in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_SOC_PROXY_CORE_BASE_ADDR 0x22030000u

/**
 * Peripheral size for core device on soc_proxy in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_SOC_PROXY_CORE_BASE_ADDR and
 * `TOP_DRAGONFLY_SOC_PROXY_CORE_BASE_ADDR + TOP_DRAGONFLY_SOC_PROXY_CORE_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_SOC_PROXY_CORE_SIZE_BYTES 0x8u

/**
 * Peripheral base address for regs device on sram_ctrl_ret_aon in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_SRAM_CTRL_RET_AON_REGS_BASE_ADDR 0x30500000u

/**
 * Peripheral size for regs device on sram_ctrl_ret_aon in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_SRAM_CTRL_RET_AON_REGS_BASE_ADDR and
 * `TOP_DRAGONFLY_SRAM_CTRL_RET_AON_REGS_BASE_ADDR + TOP_DRAGONFLY_SRAM_CTRL_RET_AON_REGS_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_SRAM_CTRL_RET_AON_REGS_SIZE_BYTES 0x40u

/**
 * Peripheral base address for regs device on rv_dm in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_RV_DM_REGS_BASE_ADDR 0x21200000u

/**
 * Peripheral size for regs device on rv_dm in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_RV_DM_REGS_BASE_ADDR and
 * `TOP_DRAGONFLY_RV_DM_REGS_BASE_ADDR + TOP_DRAGONFLY_RV_DM_REGS_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_RV_DM_REGS_SIZE_BYTES 0x10u

/**
 * Peripheral base address for mem device on rv_dm in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_RV_DM_MEM_BASE_ADDR 0x40000u

/**
 * Peripheral size for mem device on rv_dm in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_RV_DM_MEM_BASE_ADDR and
 * `TOP_DRAGONFLY_RV_DM_MEM_BASE_ADDR + TOP_DRAGONFLY_RV_DM_MEM_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_RV_DM_MEM_SIZE_BYTES 0x1000u

/**
 * Peripheral base address for rv_plic in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_RV_PLIC_BASE_ADDR 0x28000000u

/**
 * Peripheral size for rv_plic in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_RV_PLIC_BASE_ADDR and
 * `TOP_DRAGONFLY_RV_PLIC_BASE_ADDR + TOP_DRAGONFLY_RV_PLIC_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_RV_PLIC_SIZE_BYTES 0x8000000u

/**
 * Peripheral base address for acc in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_ACC_BASE_ADDR 0x22100000u

/**
 * Peripheral size for acc in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_ACC_BASE_ADDR and
 * `TOP_DRAGONFLY_ACC_BASE_ADDR + TOP_DRAGONFLY_ACC_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_ACC_SIZE_BYTES 0x20000u

/**
 * Peripheral base address for aes in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_AES_BASE_ADDR 0x21100000u

/**
 * Peripheral size for aes in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_AES_BASE_ADDR and
 * `TOP_DRAGONFLY_AES_BASE_ADDR + TOP_DRAGONFLY_AES_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_AES_SIZE_BYTES 0x100u

/**
 * Peripheral base address for hmac in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_HMAC_BASE_ADDR 0x21110000u

/**
 * Peripheral size for hmac in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_HMAC_BASE_ADDR and
 * `TOP_DRAGONFLY_HMAC_BASE_ADDR + TOP_DRAGONFLY_HMAC_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_HMAC_SIZE_BYTES 0x2000u

/**
 * Peripheral base address for kmac in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_KMAC_BASE_ADDR 0x21120000u

/**
 * Peripheral size for kmac in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_KMAC_BASE_ADDR and
 * `TOP_DRAGONFLY_KMAC_BASE_ADDR + TOP_DRAGONFLY_KMAC_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_KMAC_SIZE_BYTES 0x1000u

/**
 * Peripheral base address for keymgr_dpe in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_KEYMGR_DPE_BASE_ADDR 0x21140000u

/**
 * Peripheral size for keymgr_dpe in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_KEYMGR_DPE_BASE_ADDR and
 * `TOP_DRAGONFLY_KEYMGR_DPE_BASE_ADDR + TOP_DRAGONFLY_KEYMGR_DPE_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_KEYMGR_DPE_SIZE_BYTES 0x100u

/**
 * Peripheral base address for csrng in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_CSRNG_BASE_ADDR 0x21150000u

/**
 * Peripheral size for csrng in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_CSRNG_BASE_ADDR and
 * `TOP_DRAGONFLY_CSRNG_BASE_ADDR + TOP_DRAGONFLY_CSRNG_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_CSRNG_SIZE_BYTES 0x80u

/**
 * Peripheral base address for entropy_src in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_ENTROPY_SRC_BASE_ADDR 0x21160000u

/**
 * Peripheral size for entropy_src in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_ENTROPY_SRC_BASE_ADDR and
 * `TOP_DRAGONFLY_ENTROPY_SRC_BASE_ADDR + TOP_DRAGONFLY_ENTROPY_SRC_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_ENTROPY_SRC_SIZE_BYTES 0x100u

/**
 * Peripheral base address for edn0 in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_EDN0_BASE_ADDR 0x21170000u

/**
 * Peripheral size for edn0 in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_EDN0_BASE_ADDR and
 * `TOP_DRAGONFLY_EDN0_BASE_ADDR + TOP_DRAGONFLY_EDN0_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_EDN0_SIZE_BYTES 0x80u

/**
 * Peripheral base address for edn1 in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_EDN1_BASE_ADDR 0x21180000u

/**
 * Peripheral size for edn1 in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_EDN1_BASE_ADDR and
 * `TOP_DRAGONFLY_EDN1_BASE_ADDR + TOP_DRAGONFLY_EDN1_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_EDN1_SIZE_BYTES 0x80u

/**
 * Peripheral base address for regs device on sram_ctrl_main in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_SRAM_CTRL_MAIN_REGS_BASE_ADDR 0x211C0000u

/**
 * Peripheral size for regs device on sram_ctrl_main in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_SRAM_CTRL_MAIN_REGS_BASE_ADDR and
 * `TOP_DRAGONFLY_SRAM_CTRL_MAIN_REGS_BASE_ADDR + TOP_DRAGONFLY_SRAM_CTRL_MAIN_REGS_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_SRAM_CTRL_MAIN_REGS_SIZE_BYTES 0x40u

/**
 * Peripheral base address for regs device on sram_ctrl_mbox in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_SRAM_CTRL_MBOX_REGS_BASE_ADDR 0x211D0000u

/**
 * Peripheral size for regs device on sram_ctrl_mbox in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_SRAM_CTRL_MBOX_REGS_BASE_ADDR and
 * `TOP_DRAGONFLY_SRAM_CTRL_MBOX_REGS_BASE_ADDR + TOP_DRAGONFLY_SRAM_CTRL_MBOX_REGS_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_SRAM_CTRL_MBOX_REGS_SIZE_BYTES 0x40u

/**
 * Peripheral base address for regs device on rom_ctrl0 in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_ROM_CTRL0_REGS_BASE_ADDR 0x211E0000u

/**
 * Peripheral size for regs device on rom_ctrl0 in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_ROM_CTRL0_REGS_BASE_ADDR and
 * `TOP_DRAGONFLY_ROM_CTRL0_REGS_BASE_ADDR + TOP_DRAGONFLY_ROM_CTRL0_REGS_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_ROM_CTRL0_REGS_SIZE_BYTES 0x80u

/**
 * Peripheral base address for regs device on rom_ctrl1 in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_ROM_CTRL1_REGS_BASE_ADDR 0x211E1000u

/**
 * Peripheral size for regs device on rom_ctrl1 in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_ROM_CTRL1_REGS_BASE_ADDR and
 * `TOP_DRAGONFLY_ROM_CTRL1_REGS_BASE_ADDR + TOP_DRAGONFLY_ROM_CTRL1_REGS_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_ROM_CTRL1_REGS_SIZE_BYTES 0x80u

/**
 * Peripheral base address for dma in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_DMA_BASE_ADDR 0x22010000u

/**
 * Peripheral size for dma in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_DMA_BASE_ADDR and
 * `TOP_DRAGONFLY_DMA_BASE_ADDR + TOP_DRAGONFLY_DMA_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_DMA_SIZE_BYTES 0x200u

/**
 * Peripheral base address for core device on mbx0 in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_MBX0_CORE_BASE_ADDR 0x22000000u

/**
 * Peripheral size for core device on mbx0 in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_MBX0_CORE_BASE_ADDR and
 * `TOP_DRAGONFLY_MBX0_CORE_BASE_ADDR + TOP_DRAGONFLY_MBX0_CORE_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_MBX0_CORE_SIZE_BYTES 0x80u

/**
 * Peripheral base address for core device on mbx1 in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_MBX1_CORE_BASE_ADDR 0x22000100u

/**
 * Peripheral size for core device on mbx1 in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_MBX1_CORE_BASE_ADDR and
 * `TOP_DRAGONFLY_MBX1_CORE_BASE_ADDR + TOP_DRAGONFLY_MBX1_CORE_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_MBX1_CORE_SIZE_BYTES 0x80u

/**
 * Peripheral base address for core device on mbx2 in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_MBX2_CORE_BASE_ADDR 0x22000200u

/**
 * Peripheral size for core device on mbx2 in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_MBX2_CORE_BASE_ADDR and
 * `TOP_DRAGONFLY_MBX2_CORE_BASE_ADDR + TOP_DRAGONFLY_MBX2_CORE_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_MBX2_CORE_SIZE_BYTES 0x80u

/**
 * Peripheral base address for core device on mbx3 in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_MBX3_CORE_BASE_ADDR 0x22000300u

/**
 * Peripheral size for core device on mbx3 in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_MBX3_CORE_BASE_ADDR and
 * `TOP_DRAGONFLY_MBX3_CORE_BASE_ADDR + TOP_DRAGONFLY_MBX3_CORE_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_MBX3_CORE_SIZE_BYTES 0x80u

/**
 * Peripheral base address for core device on mbx4 in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_MBX4_CORE_BASE_ADDR 0x22000400u

/**
 * Peripheral size for core device on mbx4 in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_MBX4_CORE_BASE_ADDR and
 * `TOP_DRAGONFLY_MBX4_CORE_BASE_ADDR + TOP_DRAGONFLY_MBX4_CORE_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_MBX4_CORE_SIZE_BYTES 0x80u

/**
 * Peripheral base address for core device on mbx5 in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_MBX5_CORE_BASE_ADDR 0x22000500u

/**
 * Peripheral size for core device on mbx5 in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_MBX5_CORE_BASE_ADDR and
 * `TOP_DRAGONFLY_MBX5_CORE_BASE_ADDR + TOP_DRAGONFLY_MBX5_CORE_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_MBX5_CORE_SIZE_BYTES 0x80u

/**
 * Peripheral base address for core device on mbx6 in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_MBX6_CORE_BASE_ADDR 0x22000600u

/**
 * Peripheral size for core device on mbx6 in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_MBX6_CORE_BASE_ADDR and
 * `TOP_DRAGONFLY_MBX6_CORE_BASE_ADDR + TOP_DRAGONFLY_MBX6_CORE_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_MBX6_CORE_SIZE_BYTES 0x80u

/**
 * Peripheral base address for core device on mbx_jtag in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_MBX_JTAG_CORE_BASE_ADDR 0x22000800u

/**
 * Peripheral size for core device on mbx_jtag in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_MBX_JTAG_CORE_BASE_ADDR and
 * `TOP_DRAGONFLY_MBX_JTAG_CORE_BASE_ADDR + TOP_DRAGONFLY_MBX_JTAG_CORE_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_MBX_JTAG_CORE_SIZE_BYTES 0x80u

/**
 * Peripheral base address for core device on mbx_pcie0 in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_MBX_PCIE0_CORE_BASE_ADDR 0x22040000u

/**
 * Peripheral size for core device on mbx_pcie0 in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_MBX_PCIE0_CORE_BASE_ADDR and
 * `TOP_DRAGONFLY_MBX_PCIE0_CORE_BASE_ADDR + TOP_DRAGONFLY_MBX_PCIE0_CORE_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_MBX_PCIE0_CORE_SIZE_BYTES 0x80u

/**
 * Peripheral base address for core device on mbx_pcie1 in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_MBX_PCIE1_CORE_BASE_ADDR 0x22040100u

/**
 * Peripheral size for core device on mbx_pcie1 in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_MBX_PCIE1_CORE_BASE_ADDR and
 * `TOP_DRAGONFLY_MBX_PCIE1_CORE_BASE_ADDR + TOP_DRAGONFLY_MBX_PCIE1_CORE_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_MBX_PCIE1_CORE_SIZE_BYTES 0x80u

/**
 * Peripheral base address for core device on soc_dbg_ctrl in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_SOC_DBG_CTRL_CORE_BASE_ADDR 0x30170000u

/**
 * Peripheral size for core device on soc_dbg_ctrl in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_SOC_DBG_CTRL_CORE_BASE_ADDR and
 * `TOP_DRAGONFLY_SOC_DBG_CTRL_CORE_BASE_ADDR + TOP_DRAGONFLY_SOC_DBG_CTRL_CORE_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_SOC_DBG_CTRL_CORE_SIZE_BYTES 0x20u

/**
 * Peripheral base address for cfg device on rv_core_ibex in top dragonfly.
 *
 * This should be used with #mmio_region_from_addr to access the memory-mapped
 * registers associated with the peripheral (usually via a DIF).
 */
#define TOP_DRAGONFLY_RV_CORE_IBEX_CFG_BASE_ADDR 0x211F0000u

/**
 * Peripheral size for cfg device on rv_core_ibex in top dragonfly.
 *
 * This is the size (in bytes) of the peripheral's reserved memory area. All
 * memory-mapped registers associated with this peripheral should have an
 * address between #TOP_DRAGONFLY_RV_CORE_IBEX_CFG_BASE_ADDR and
 * `TOP_DRAGONFLY_RV_CORE_IBEX_CFG_BASE_ADDR + TOP_DRAGONFLY_RV_CORE_IBEX_CFG_SIZE_BYTES`.
 */
#define TOP_DRAGONFLY_RV_CORE_IBEX_CFG_SIZE_BYTES 0x800u


/**
 * Memory base address for ctn memory on soc_proxy in top dragonfly.
 */
#define TOP_DRAGONFLY_SOC_PROXY_CTN_BASE_ADDR 0x40000000u

/**
 * Memory size for ctn memory on soc_proxy in top dragonfly.
 */
#define TOP_DRAGONFLY_SOC_PROXY_CTN_SIZE_BYTES 0x80000000u

/**
 * Memory base address for ram_ctn in top dragonfly.
 */
#define TOP_DRAGONFLY_SOC_PROXY_RAM_CTN_BASE_ADDR 0x41000000u

/**
 * Memory size for ram_ctn in top dragonfly.
 */
#define TOP_DRAGONFLY_SOC_PROXY_RAM_CTN_SIZE_BYTES 0x100000u

/**
 * Memory base address for ram memory on sram_ctrl_ret_aon in top dragonfly.
 */
#define TOP_DRAGONFLY_SRAM_CTRL_RET_AON_RAM_BASE_ADDR 0x30600000u

/**
 * Memory size for ram memory on sram_ctrl_ret_aon in top dragonfly.
 */
#define TOP_DRAGONFLY_SRAM_CTRL_RET_AON_RAM_SIZE_BYTES 0x1000u

/**
 * Memory base address for ram memory on sram_ctrl_main in top dragonfly.
 */
#define TOP_DRAGONFLY_SRAM_CTRL_MAIN_RAM_BASE_ADDR 0x10000000u

/**
 * Memory size for ram memory on sram_ctrl_main in top dragonfly.
 */
#define TOP_DRAGONFLY_SRAM_CTRL_MAIN_RAM_SIZE_BYTES 0x10000u

/**
 * Memory base address for ram memory on sram_ctrl_mbox in top dragonfly.
 */
#define TOP_DRAGONFLY_SRAM_CTRL_MBOX_RAM_BASE_ADDR 0x11000000u

/**
 * Memory size for ram memory on sram_ctrl_mbox in top dragonfly.
 */
#define TOP_DRAGONFLY_SRAM_CTRL_MBOX_RAM_SIZE_BYTES 0x1000u

/**
 * Memory base address for rom memory on rom_ctrl0 in top dragonfly.
 */
#define TOP_DRAGONFLY_ROM_CTRL0_ROM_BASE_ADDR 0x8000u

/**
 * Memory size for rom memory on rom_ctrl0 in top dragonfly.
 */
#define TOP_DRAGONFLY_ROM_CTRL0_ROM_SIZE_BYTES 0x8000u

/**
 * Memory base address for rom memory on rom_ctrl1 in top dragonfly.
 */
#define TOP_DRAGONFLY_ROM_CTRL1_ROM_BASE_ADDR 0x20000u

/**
 * Memory size for rom memory on rom_ctrl1 in top dragonfly.
 */
#define TOP_DRAGONFLY_ROM_CTRL1_ROM_SIZE_BYTES 0x10000u


/**
 * PLIC Interrupt Source Peripheral.
 *
 * Enumeration used to determine which peripheral asserted the corresponding
 * interrupt.
 */
typedef enum top_dragonfly_plic_peripheral {
  kTopDragonflyPlicPeripheralUnknown = 0, /**< Unknown Peripheral */
  kTopDragonflyPlicPeripheralUart0 = 1, /**< uart0 */
  kTopDragonflyPlicPeripheralGpio = 2, /**< gpio */
  kTopDragonflyPlicPeripheralSpiDevice = 3, /**< spi_device */
  kTopDragonflyPlicPeripheralI2c0 = 4, /**< i2c0 */
  kTopDragonflyPlicPeripheralRvTimer = 5, /**< rv_timer */
  kTopDragonflyPlicPeripheralOtpCtrl = 6, /**< otp_ctrl */
  kTopDragonflyPlicPeripheralAlertHandler = 7, /**< alert_handler */
  kTopDragonflyPlicPeripheralSpiHost0 = 8, /**< spi_host0 */
  kTopDragonflyPlicPeripheralPwrmgrAon = 9, /**< pwrmgr_aon */
  kTopDragonflyPlicPeripheralAonTimerAon = 10, /**< aon_timer_aon */
  kTopDragonflyPlicPeripheralAcc = 11, /**< acc */
  kTopDragonflyPlicPeripheralHmac = 12, /**< hmac */
  kTopDragonflyPlicPeripheralKmac = 13, /**< kmac */
  kTopDragonflyPlicPeripheralKeymgrDpe = 14, /**< keymgr_dpe */
  kTopDragonflyPlicPeripheralCsrng = 15, /**< csrng */
  kTopDragonflyPlicPeripheralEntropySrc = 16, /**< entropy_src */
  kTopDragonflyPlicPeripheralEdn0 = 17, /**< edn0 */
  kTopDragonflyPlicPeripheralEdn1 = 18, /**< edn1 */
  kTopDragonflyPlicPeripheralDma = 19, /**< dma */
  kTopDragonflyPlicPeripheralMbx0 = 20, /**< mbx0 */
  kTopDragonflyPlicPeripheralMbx1 = 21, /**< mbx1 */
  kTopDragonflyPlicPeripheralMbx2 = 22, /**< mbx2 */
  kTopDragonflyPlicPeripheralMbx3 = 23, /**< mbx3 */
  kTopDragonflyPlicPeripheralMbx4 = 24, /**< mbx4 */
  kTopDragonflyPlicPeripheralMbx5 = 25, /**< mbx5 */
  kTopDragonflyPlicPeripheralMbx6 = 26, /**< mbx6 */
  kTopDragonflyPlicPeripheralMbxJtag = 27, /**< mbx_jtag */
  kTopDragonflyPlicPeripheralMbxPcie0 = 28, /**< mbx_pcie0 */
  kTopDragonflyPlicPeripheralMbxPcie1 = 29, /**< mbx_pcie1 */
  kTopDragonflyPlicPeripheralRaclCtrl = 30, /**< racl_ctrl */
  kTopDragonflyPlicPeripheralAcRangeCheck = 31, /**< ac_range_check */
  kTopDragonflyPlicPeripheralLast = 31, /**< \internal Final PLIC peripheral */
} top_dragonfly_plic_peripheral_t;

/**
 * PLIC Interrupt Source.
 *
 * Enumeration of all PLIC interrupt sources. The interrupt sources belonging to
 * the same peripheral are guaranteed to be consecutive.
 */
typedef enum top_dragonfly_plic_irq_id {
  kTopDragonflyPlicIrqIdNone = 0, /**< No Interrupt */
  kTopDragonflyPlicIrqIdUart0TxWatermark = 1, /**< uart0_tx_watermark */
  kTopDragonflyPlicIrqIdUart0RxWatermark = 2, /**< uart0_rx_watermark */
  kTopDragonflyPlicIrqIdUart0TxDone = 3, /**< uart0_tx_done */
  kTopDragonflyPlicIrqIdUart0RxOverflow = 4, /**< uart0_rx_overflow */
  kTopDragonflyPlicIrqIdUart0RxFrameErr = 5, /**< uart0_rx_frame_err */
  kTopDragonflyPlicIrqIdUart0RxBreakErr = 6, /**< uart0_rx_break_err */
  kTopDragonflyPlicIrqIdUart0RxTimeout = 7, /**< uart0_rx_timeout */
  kTopDragonflyPlicIrqIdUart0RxParityErr = 8, /**< uart0_rx_parity_err */
  kTopDragonflyPlicIrqIdUart0TxEmpty = 9, /**< uart0_tx_empty */
  kTopDragonflyPlicIrqIdGpioGpio0 = 10, /**< gpio_gpio 0 */
  kTopDragonflyPlicIrqIdGpioGpio1 = 11, /**< gpio_gpio 1 */
  kTopDragonflyPlicIrqIdGpioGpio2 = 12, /**< gpio_gpio 2 */
  kTopDragonflyPlicIrqIdGpioGpio3 = 13, /**< gpio_gpio 3 */
  kTopDragonflyPlicIrqIdGpioGpio4 = 14, /**< gpio_gpio 4 */
  kTopDragonflyPlicIrqIdGpioGpio5 = 15, /**< gpio_gpio 5 */
  kTopDragonflyPlicIrqIdGpioGpio6 = 16, /**< gpio_gpio 6 */
  kTopDragonflyPlicIrqIdGpioGpio7 = 17, /**< gpio_gpio 7 */
  kTopDragonflyPlicIrqIdGpioGpio8 = 18, /**< gpio_gpio 8 */
  kTopDragonflyPlicIrqIdGpioGpio9 = 19, /**< gpio_gpio 9 */
  kTopDragonflyPlicIrqIdGpioGpio10 = 20, /**< gpio_gpio 10 */
  kTopDragonflyPlicIrqIdGpioGpio11 = 21, /**< gpio_gpio 11 */
  kTopDragonflyPlicIrqIdGpioGpio12 = 22, /**< gpio_gpio 12 */
  kTopDragonflyPlicIrqIdGpioGpio13 = 23, /**< gpio_gpio 13 */
  kTopDragonflyPlicIrqIdGpioGpio14 = 24, /**< gpio_gpio 14 */
  kTopDragonflyPlicIrqIdGpioGpio15 = 25, /**< gpio_gpio 15 */
  kTopDragonflyPlicIrqIdGpioGpio16 = 26, /**< gpio_gpio 16 */
  kTopDragonflyPlicIrqIdGpioGpio17 = 27, /**< gpio_gpio 17 */
  kTopDragonflyPlicIrqIdGpioGpio18 = 28, /**< gpio_gpio 18 */
  kTopDragonflyPlicIrqIdGpioGpio19 = 29, /**< gpio_gpio 19 */
  kTopDragonflyPlicIrqIdGpioGpio20 = 30, /**< gpio_gpio 20 */
  kTopDragonflyPlicIrqIdGpioGpio21 = 31, /**< gpio_gpio 21 */
  kTopDragonflyPlicIrqIdGpioGpio22 = 32, /**< gpio_gpio 22 */
  kTopDragonflyPlicIrqIdGpioGpio23 = 33, /**< gpio_gpio 23 */
  kTopDragonflyPlicIrqIdGpioGpio24 = 34, /**< gpio_gpio 24 */
  kTopDragonflyPlicIrqIdGpioGpio25 = 35, /**< gpio_gpio 25 */
  kTopDragonflyPlicIrqIdGpioGpio26 = 36, /**< gpio_gpio 26 */
  kTopDragonflyPlicIrqIdGpioGpio27 = 37, /**< gpio_gpio 27 */
  kTopDragonflyPlicIrqIdGpioGpio28 = 38, /**< gpio_gpio 28 */
  kTopDragonflyPlicIrqIdGpioGpio29 = 39, /**< gpio_gpio 29 */
  kTopDragonflyPlicIrqIdGpioGpio30 = 40, /**< gpio_gpio 30 */
  kTopDragonflyPlicIrqIdGpioGpio31 = 41, /**< gpio_gpio 31 */
  kTopDragonflyPlicIrqIdSpiDeviceUploadCmdfifoNotEmpty = 42, /**< spi_device_upload_cmdfifo_not_empty */
  kTopDragonflyPlicIrqIdSpiDeviceUploadPayloadNotEmpty = 43, /**< spi_device_upload_payload_not_empty */
  kTopDragonflyPlicIrqIdSpiDeviceUploadPayloadOverflow = 44, /**< spi_device_upload_payload_overflow */
  kTopDragonflyPlicIrqIdSpiDeviceReadbufWatermark = 45, /**< spi_device_readbuf_watermark */
  kTopDragonflyPlicIrqIdSpiDeviceReadbufFlip = 46, /**< spi_device_readbuf_flip */
  kTopDragonflyPlicIrqIdSpiDeviceTpmHeaderNotEmpty = 47, /**< spi_device_tpm_header_not_empty */
  kTopDragonflyPlicIrqIdSpiDeviceTpmRdfifoCmdEnd = 48, /**< spi_device_tpm_rdfifo_cmd_end */
  kTopDragonflyPlicIrqIdSpiDeviceTpmRdfifoDrop = 49, /**< spi_device_tpm_rdfifo_drop */
  kTopDragonflyPlicIrqIdI2c0FmtThreshold = 50, /**< i2c0_fmt_threshold */
  kTopDragonflyPlicIrqIdI2c0RxThreshold = 51, /**< i2c0_rx_threshold */
  kTopDragonflyPlicIrqIdI2c0AcqThreshold = 52, /**< i2c0_acq_threshold */
  kTopDragonflyPlicIrqIdI2c0RxOverflow = 53, /**< i2c0_rx_overflow */
  kTopDragonflyPlicIrqIdI2c0ControllerHalt = 54, /**< i2c0_controller_halt */
  kTopDragonflyPlicIrqIdI2c0SclInterference = 55, /**< i2c0_scl_interference */
  kTopDragonflyPlicIrqIdI2c0SdaInterference = 56, /**< i2c0_sda_interference */
  kTopDragonflyPlicIrqIdI2c0StretchTimeout = 57, /**< i2c0_stretch_timeout */
  kTopDragonflyPlicIrqIdI2c0SdaUnstable = 58, /**< i2c0_sda_unstable */
  kTopDragonflyPlicIrqIdI2c0CmdComplete = 59, /**< i2c0_cmd_complete */
  kTopDragonflyPlicIrqIdI2c0TxStretch = 60, /**< i2c0_tx_stretch */
  kTopDragonflyPlicIrqIdI2c0TxThreshold = 61, /**< i2c0_tx_threshold */
  kTopDragonflyPlicIrqIdI2c0AcqStretch = 62, /**< i2c0_acq_stretch */
  kTopDragonflyPlicIrqIdI2c0UnexpStop = 63, /**< i2c0_unexp_stop */
  kTopDragonflyPlicIrqIdI2c0HostTimeout = 64, /**< i2c0_host_timeout */
  kTopDragonflyPlicIrqIdRvTimerTimerExpiredHart0Timer0 = 65, /**< rv_timer_timer_expired_hart0_timer0 */
  kTopDragonflyPlicIrqIdOtpCtrlOtpOperationDone = 66, /**< otp_ctrl_otp_operation_done */
  kTopDragonflyPlicIrqIdOtpCtrlOtpError = 67, /**< otp_ctrl_otp_error */
  kTopDragonflyPlicIrqIdAlertHandlerClassa = 68, /**< alert_handler_classa */
  kTopDragonflyPlicIrqIdAlertHandlerClassb = 69, /**< alert_handler_classb */
  kTopDragonflyPlicIrqIdAlertHandlerClassc = 70, /**< alert_handler_classc */
  kTopDragonflyPlicIrqIdAlertHandlerClassd = 71, /**< alert_handler_classd */
  kTopDragonflyPlicIrqIdSpiHost0Error = 72, /**< spi_host0_error */
  kTopDragonflyPlicIrqIdSpiHost0SpiEvent = 73, /**< spi_host0_spi_event */
  kTopDragonflyPlicIrqIdPwrmgrAonWakeup = 74, /**< pwrmgr_aon_wakeup */
  kTopDragonflyPlicIrqIdAonTimerAonWkupTimerExpired = 75, /**< aon_timer_aon_wkup_timer_expired */
  kTopDragonflyPlicIrqIdAonTimerAonWdogTimerBark = 76, /**< aon_timer_aon_wdog_timer_bark */
  kTopDragonflyPlicIrqIdAccDone = 77, /**< acc_done */
  kTopDragonflyPlicIrqIdHmacHmacDone = 78, /**< hmac_hmac_done */
  kTopDragonflyPlicIrqIdHmacFifoEmpty = 79, /**< hmac_fifo_empty */
  kTopDragonflyPlicIrqIdHmacHmacErr = 80, /**< hmac_hmac_err */
  kTopDragonflyPlicIrqIdKmacKmacDone = 81, /**< kmac_kmac_done */
  kTopDragonflyPlicIrqIdKmacFifoEmpty = 82, /**< kmac_fifo_empty */
  kTopDragonflyPlicIrqIdKmacKmacErr = 83, /**< kmac_kmac_err */
  kTopDragonflyPlicIrqIdKeymgrDpeOpDone = 84, /**< keymgr_dpe_op_done */
  kTopDragonflyPlicIrqIdCsrngCsCmdReqDone = 85, /**< csrng_cs_cmd_req_done */
  kTopDragonflyPlicIrqIdCsrngCsEntropyReq = 86, /**< csrng_cs_entropy_req */
  kTopDragonflyPlicIrqIdCsrngCsHwInstExc = 87, /**< csrng_cs_hw_inst_exc */
  kTopDragonflyPlicIrqIdCsrngCsFatalErr = 88, /**< csrng_cs_fatal_err */
  kTopDragonflyPlicIrqIdEntropySrcEsEntropyValid = 89, /**< entropy_src_es_entropy_valid */
  kTopDragonflyPlicIrqIdEntropySrcEsHealthTestFailed = 90, /**< entropy_src_es_health_test_failed */
  kTopDragonflyPlicIrqIdEntropySrcEsObserveFifoReady = 91, /**< entropy_src_es_observe_fifo_ready */
  kTopDragonflyPlicIrqIdEntropySrcEsFatalErr = 92, /**< entropy_src_es_fatal_err */
  kTopDragonflyPlicIrqIdEdn0EdnCmdReqDone = 93, /**< edn0_edn_cmd_req_done */
  kTopDragonflyPlicIrqIdEdn0EdnFatalErr = 94, /**< edn0_edn_fatal_err */
  kTopDragonflyPlicIrqIdEdn1EdnCmdReqDone = 95, /**< edn1_edn_cmd_req_done */
  kTopDragonflyPlicIrqIdEdn1EdnFatalErr = 96, /**< edn1_edn_fatal_err */
  kTopDragonflyPlicIrqIdDmaDmaDone = 97, /**< dma_dma_done */
  kTopDragonflyPlicIrqIdDmaDmaChunkDone = 98, /**< dma_dma_chunk_done */
  kTopDragonflyPlicIrqIdDmaDmaError = 99, /**< dma_dma_error */
  kTopDragonflyPlicIrqIdMbx0MbxReady = 100, /**< mbx0_mbx_ready */
  kTopDragonflyPlicIrqIdMbx0MbxAbort = 101, /**< mbx0_mbx_abort */
  kTopDragonflyPlicIrqIdMbx0MbxError = 102, /**< mbx0_mbx_error */
  kTopDragonflyPlicIrqIdMbx1MbxReady = 103, /**< mbx1_mbx_ready */
  kTopDragonflyPlicIrqIdMbx1MbxAbort = 104, /**< mbx1_mbx_abort */
  kTopDragonflyPlicIrqIdMbx1MbxError = 105, /**< mbx1_mbx_error */
  kTopDragonflyPlicIrqIdMbx2MbxReady = 106, /**< mbx2_mbx_ready */
  kTopDragonflyPlicIrqIdMbx2MbxAbort = 107, /**< mbx2_mbx_abort */
  kTopDragonflyPlicIrqIdMbx2MbxError = 108, /**< mbx2_mbx_error */
  kTopDragonflyPlicIrqIdMbx3MbxReady = 109, /**< mbx3_mbx_ready */
  kTopDragonflyPlicIrqIdMbx3MbxAbort = 110, /**< mbx3_mbx_abort */
  kTopDragonflyPlicIrqIdMbx3MbxError = 111, /**< mbx3_mbx_error */
  kTopDragonflyPlicIrqIdMbx4MbxReady = 112, /**< mbx4_mbx_ready */
  kTopDragonflyPlicIrqIdMbx4MbxAbort = 113, /**< mbx4_mbx_abort */
  kTopDragonflyPlicIrqIdMbx4MbxError = 114, /**< mbx4_mbx_error */
  kTopDragonflyPlicIrqIdMbx5MbxReady = 115, /**< mbx5_mbx_ready */
  kTopDragonflyPlicIrqIdMbx5MbxAbort = 116, /**< mbx5_mbx_abort */
  kTopDragonflyPlicIrqIdMbx5MbxError = 117, /**< mbx5_mbx_error */
  kTopDragonflyPlicIrqIdMbx6MbxReady = 118, /**< mbx6_mbx_ready */
  kTopDragonflyPlicIrqIdMbx6MbxAbort = 119, /**< mbx6_mbx_abort */
  kTopDragonflyPlicIrqIdMbx6MbxError = 120, /**< mbx6_mbx_error */
  kTopDragonflyPlicIrqIdMbxJtagMbxReady = 121, /**< mbx_jtag_mbx_ready */
  kTopDragonflyPlicIrqIdMbxJtagMbxAbort = 122, /**< mbx_jtag_mbx_abort */
  kTopDragonflyPlicIrqIdMbxJtagMbxError = 123, /**< mbx_jtag_mbx_error */
  kTopDragonflyPlicIrqIdMbxPcie0MbxReady = 124, /**< mbx_pcie0_mbx_ready */
  kTopDragonflyPlicIrqIdMbxPcie0MbxAbort = 125, /**< mbx_pcie0_mbx_abort */
  kTopDragonflyPlicIrqIdMbxPcie0MbxError = 126, /**< mbx_pcie0_mbx_error */
  kTopDragonflyPlicIrqIdMbxPcie1MbxReady = 127, /**< mbx_pcie1_mbx_ready */
  kTopDragonflyPlicIrqIdMbxPcie1MbxAbort = 128, /**< mbx_pcie1_mbx_abort */
  kTopDragonflyPlicIrqIdMbxPcie1MbxError = 129, /**< mbx_pcie1_mbx_error */
  kTopDragonflyPlicIrqIdRaclCtrlRaclError = 130, /**< racl_ctrl_racl_error */
  kTopDragonflyPlicIrqIdAcRangeCheckDenyCntReached = 131, /**< ac_range_check_deny_cnt_reached */
  kTopDragonflyPlicIrqIdLast = 131, /**< \internal The Last Valid Interrupt ID. */
} top_dragonfly_plic_irq_id_t;

/**
 * PLIC Interrupt Source to Peripheral Map
 *
 * This array is a mapping from `top_dragonfly_plic_irq_id_t` to
 * `top_dragonfly_plic_peripheral_t`.
 */
extern const top_dragonfly_plic_peripheral_t
    top_dragonfly_plic_interrupt_for_peripheral[132];

/**
 * PLIC Interrupt Target.
 *
 * Enumeration used to determine which set of IE, CC, threshold registers to
 * access for a given interrupt target.
 */
typedef enum top_dragonfly_plic_target {
  kTopDragonflyPlicTargetIbex0 = 0, /**< Ibex Core 0 */
  kTopDragonflyPlicTargetLast = 0, /**< \internal Final PLIC target */
} top_dragonfly_plic_target_t;


/**
 * Alert Handler Source Peripheral.
 *
 * Enumeration used to determine which peripheral asserted the corresponding
 * alert.
 */
typedef enum top_dragonfly_alert_peripheral {
  kTopDragonflyAlertPeripheralExternal = 0, /**< External Peripheral */
  kTopDragonflyAlertPeripheralUart0 = 1, /**< uart0 */
  kTopDragonflyAlertPeripheralGpio = 2, /**< gpio */
  kTopDragonflyAlertPeripheralSpiDevice = 3, /**< spi_device */
  kTopDragonflyAlertPeripheralI2c0 = 4, /**< i2c0 */
  kTopDragonflyAlertPeripheralRvTimer = 5, /**< rv_timer */
  kTopDragonflyAlertPeripheralOtpCtrl = 6, /**< otp_ctrl */
  kTopDragonflyAlertPeripheralLcCtrl = 7, /**< lc_ctrl */
  kTopDragonflyAlertPeripheralSpiHost0 = 8, /**< spi_host0 */
  kTopDragonflyAlertPeripheralPwrmgrAon = 9, /**< pwrmgr_aon */
  kTopDragonflyAlertPeripheralRstmgrAon = 10, /**< rstmgr_aon */
  kTopDragonflyAlertPeripheralClkmgrAon = 11, /**< clkmgr_aon */
  kTopDragonflyAlertPeripheralPinmuxAon = 12, /**< pinmux_aon */
  kTopDragonflyAlertPeripheralAonTimerAon = 13, /**< aon_timer_aon */
  kTopDragonflyAlertPeripheralSocProxy = 14, /**< soc_proxy */
  kTopDragonflyAlertPeripheralSramCtrlRetAon = 15, /**< sram_ctrl_ret_aon */
  kTopDragonflyAlertPeripheralRvDm = 16, /**< rv_dm */
  kTopDragonflyAlertPeripheralRvPlic = 17, /**< rv_plic */
  kTopDragonflyAlertPeripheralAcc = 18, /**< acc */
  kTopDragonflyAlertPeripheralAes = 19, /**< aes */
  kTopDragonflyAlertPeripheralHmac = 20, /**< hmac */
  kTopDragonflyAlertPeripheralKmac = 21, /**< kmac */
  kTopDragonflyAlertPeripheralKeymgrDpe = 22, /**< keymgr_dpe */
  kTopDragonflyAlertPeripheralCsrng = 23, /**< csrng */
  kTopDragonflyAlertPeripheralEntropySrc = 24, /**< entropy_src */
  kTopDragonflyAlertPeripheralEdn0 = 25, /**< edn0 */
  kTopDragonflyAlertPeripheralEdn1 = 26, /**< edn1 */
  kTopDragonflyAlertPeripheralSramCtrlMain = 27, /**< sram_ctrl_main */
  kTopDragonflyAlertPeripheralSramCtrlMbox = 28, /**< sram_ctrl_mbox */
  kTopDragonflyAlertPeripheralRomCtrl0 = 29, /**< rom_ctrl0 */
  kTopDragonflyAlertPeripheralRomCtrl1 = 30, /**< rom_ctrl1 */
  kTopDragonflyAlertPeripheralDma = 31, /**< dma */
  kTopDragonflyAlertPeripheralMbx0 = 32, /**< mbx0 */
  kTopDragonflyAlertPeripheralMbx1 = 33, /**< mbx1 */
  kTopDragonflyAlertPeripheralMbx2 = 34, /**< mbx2 */
  kTopDragonflyAlertPeripheralMbx3 = 35, /**< mbx3 */
  kTopDragonflyAlertPeripheralMbx4 = 36, /**< mbx4 */
  kTopDragonflyAlertPeripheralMbx5 = 37, /**< mbx5 */
  kTopDragonflyAlertPeripheralMbx6 = 38, /**< mbx6 */
  kTopDragonflyAlertPeripheralMbxJtag = 39, /**< mbx_jtag */
  kTopDragonflyAlertPeripheralMbxPcie0 = 40, /**< mbx_pcie0 */
  kTopDragonflyAlertPeripheralMbxPcie1 = 41, /**< mbx_pcie1 */
  kTopDragonflyAlertPeripheralSocDbgCtrl = 42, /**< soc_dbg_ctrl */
  kTopDragonflyAlertPeripheralRaclCtrl = 43, /**< racl_ctrl */
  kTopDragonflyAlertPeripheralAcRangeCheck = 44, /**< ac_range_check */
  kTopDragonflyAlertPeripheralRvCoreIbex = 45, /**< rv_core_ibex */
  kTopDragonflyAlertPeripheralLast = 45, /**< \internal Final Alert peripheral */
} top_dragonfly_alert_peripheral_t;

/**
 * Alert Handler Alert Source.
 *
 * Enumeration of all Alert Handler Alert Sources. The alert sources belonging to
 * the same peripheral are guaranteed to be consecutive.
 */
typedef enum top_dragonfly_alert_id {
  kTopDragonflyAlertIdUart0FatalFault = 0, /**< uart0_fatal_fault */
  kTopDragonflyAlertIdGpioFatalFault = 1, /**< gpio_fatal_fault */
  kTopDragonflyAlertIdSpiDeviceFatalFault = 2, /**< spi_device_fatal_fault */
  kTopDragonflyAlertIdI2c0FatalFault = 3, /**< i2c0_fatal_fault */
  kTopDragonflyAlertIdRvTimerFatalFault = 4, /**< rv_timer_fatal_fault */
  kTopDragonflyAlertIdOtpCtrlFatalMacroError = 5, /**< otp_ctrl_fatal_macro_error */
  kTopDragonflyAlertIdOtpCtrlFatalCheckError = 6, /**< otp_ctrl_fatal_check_error */
  kTopDragonflyAlertIdOtpCtrlFatalBusIntegError = 7, /**< otp_ctrl_fatal_bus_integ_error */
  kTopDragonflyAlertIdOtpCtrlFatalPrimOtpAlert = 8, /**< otp_ctrl_fatal_prim_otp_alert */
  kTopDragonflyAlertIdOtpCtrlRecovPrimOtpAlert = 9, /**< otp_ctrl_recov_prim_otp_alert */
  kTopDragonflyAlertIdLcCtrlFatalProgError = 10, /**< lc_ctrl_fatal_prog_error */
  kTopDragonflyAlertIdLcCtrlFatalStateError = 11, /**< lc_ctrl_fatal_state_error */
  kTopDragonflyAlertIdLcCtrlFatalBusIntegError = 12, /**< lc_ctrl_fatal_bus_integ_error */
  kTopDragonflyAlertIdSpiHost0FatalFault = 13, /**< spi_host0_fatal_fault */
  kTopDragonflyAlertIdPwrmgrAonFatalFault = 14, /**< pwrmgr_aon_fatal_fault */
  kTopDragonflyAlertIdRstmgrAonFatalFault = 15, /**< rstmgr_aon_fatal_fault */
  kTopDragonflyAlertIdRstmgrAonFatalCnstyFault = 16, /**< rstmgr_aon_fatal_cnsty_fault */
  kTopDragonflyAlertIdClkmgrAonRecovFault = 17, /**< clkmgr_aon_recov_fault */
  kTopDragonflyAlertIdClkmgrAonFatalFault = 18, /**< clkmgr_aon_fatal_fault */
  kTopDragonflyAlertIdPinmuxAonFatalFault = 19, /**< pinmux_aon_fatal_fault */
  kTopDragonflyAlertIdAonTimerAonFatalFault = 20, /**< aon_timer_aon_fatal_fault */
  kTopDragonflyAlertIdSocProxyFatalAlertIntg = 21, /**< soc_proxy_fatal_alert_intg */
  kTopDragonflyAlertIdSramCtrlRetAonFatalError = 22, /**< sram_ctrl_ret_aon_fatal_error */
  kTopDragonflyAlertIdRvDmFatalFault = 23, /**< rv_dm_fatal_fault */
  kTopDragonflyAlertIdRvPlicFatalFault = 24, /**< rv_plic_fatal_fault */
  kTopDragonflyAlertIdAccFatal = 25, /**< acc_fatal */
  kTopDragonflyAlertIdAccRecov = 26, /**< acc_recov */
  kTopDragonflyAlertIdAesRecovCtrlUpdateErr = 27, /**< aes_recov_ctrl_update_err */
  kTopDragonflyAlertIdAesFatalFault = 28, /**< aes_fatal_fault */
  kTopDragonflyAlertIdHmacFatalFault = 29, /**< hmac_fatal_fault */
  kTopDragonflyAlertIdKmacRecovOperationErr = 30, /**< kmac_recov_operation_err */
  kTopDragonflyAlertIdKmacFatalFaultErr = 31, /**< kmac_fatal_fault_err */
  kTopDragonflyAlertIdKeymgrDpeRecovOperationErr = 32, /**< keymgr_dpe_recov_operation_err */
  kTopDragonflyAlertIdKeymgrDpeFatalFaultErr = 33, /**< keymgr_dpe_fatal_fault_err */
  kTopDragonflyAlertIdCsrngRecovAlert = 34, /**< csrng_recov_alert */
  kTopDragonflyAlertIdCsrngFatalAlert = 35, /**< csrng_fatal_alert */
  kTopDragonflyAlertIdEntropySrcRecovAlert = 36, /**< entropy_src_recov_alert */
  kTopDragonflyAlertIdEntropySrcFatalAlert = 37, /**< entropy_src_fatal_alert */
  kTopDragonflyAlertIdEdn0RecovAlert = 38, /**< edn0_recov_alert */
  kTopDragonflyAlertIdEdn0FatalAlert = 39, /**< edn0_fatal_alert */
  kTopDragonflyAlertIdEdn1RecovAlert = 40, /**< edn1_recov_alert */
  kTopDragonflyAlertIdEdn1FatalAlert = 41, /**< edn1_fatal_alert */
  kTopDragonflyAlertIdSramCtrlMainFatalError = 42, /**< sram_ctrl_main_fatal_error */
  kTopDragonflyAlertIdSramCtrlMboxFatalError = 43, /**< sram_ctrl_mbox_fatal_error */
  kTopDragonflyAlertIdRomCtrl0Fatal = 44, /**< rom_ctrl0_fatal */
  kTopDragonflyAlertIdRomCtrl1Fatal = 45, /**< rom_ctrl1_fatal */
  kTopDragonflyAlertIdDmaFatalFault = 46, /**< dma_fatal_fault */
  kTopDragonflyAlertIdMbx0FatalFault = 47, /**< mbx0_fatal_fault */
  kTopDragonflyAlertIdMbx0RecovFault = 48, /**< mbx0_recov_fault */
  kTopDragonflyAlertIdMbx1FatalFault = 49, /**< mbx1_fatal_fault */
  kTopDragonflyAlertIdMbx1RecovFault = 50, /**< mbx1_recov_fault */
  kTopDragonflyAlertIdMbx2FatalFault = 51, /**< mbx2_fatal_fault */
  kTopDragonflyAlertIdMbx2RecovFault = 52, /**< mbx2_recov_fault */
  kTopDragonflyAlertIdMbx3FatalFault = 53, /**< mbx3_fatal_fault */
  kTopDragonflyAlertIdMbx3RecovFault = 54, /**< mbx3_recov_fault */
  kTopDragonflyAlertIdMbx4FatalFault = 55, /**< mbx4_fatal_fault */
  kTopDragonflyAlertIdMbx4RecovFault = 56, /**< mbx4_recov_fault */
  kTopDragonflyAlertIdMbx5FatalFault = 57, /**< mbx5_fatal_fault */
  kTopDragonflyAlertIdMbx5RecovFault = 58, /**< mbx5_recov_fault */
  kTopDragonflyAlertIdMbx6FatalFault = 59, /**< mbx6_fatal_fault */
  kTopDragonflyAlertIdMbx6RecovFault = 60, /**< mbx6_recov_fault */
  kTopDragonflyAlertIdMbxJtagFatalFault = 61, /**< mbx_jtag_fatal_fault */
  kTopDragonflyAlertIdMbxJtagRecovFault = 62, /**< mbx_jtag_recov_fault */
  kTopDragonflyAlertIdMbxPcie0FatalFault = 63, /**< mbx_pcie0_fatal_fault */
  kTopDragonflyAlertIdMbxPcie0RecovFault = 64, /**< mbx_pcie0_recov_fault */
  kTopDragonflyAlertIdMbxPcie1FatalFault = 65, /**< mbx_pcie1_fatal_fault */
  kTopDragonflyAlertIdMbxPcie1RecovFault = 66, /**< mbx_pcie1_recov_fault */
  kTopDragonflyAlertIdSocDbgCtrlFatalFault = 67, /**< soc_dbg_ctrl_fatal_fault */
  kTopDragonflyAlertIdSocDbgCtrlRecovCtrlUpdateErr = 68, /**< soc_dbg_ctrl_recov_ctrl_update_err */
  kTopDragonflyAlertIdRaclCtrlFatalFault = 69, /**< racl_ctrl_fatal_fault */
  kTopDragonflyAlertIdRaclCtrlRecovCtrlUpdateErr = 70, /**< racl_ctrl_recov_ctrl_update_err */
  kTopDragonflyAlertIdAcRangeCheckRecovCtrlUpdateErr = 71, /**< ac_range_check_recov_ctrl_update_err */
  kTopDragonflyAlertIdAcRangeCheckFatalFault = 72, /**< ac_range_check_fatal_fault */
  kTopDragonflyAlertIdRvCoreIbexFatalSwErr = 73, /**< rv_core_ibex_fatal_sw_err */
  kTopDragonflyAlertIdRvCoreIbexRecovSwErr = 74, /**< rv_core_ibex_recov_sw_err */
  kTopDragonflyAlertIdRvCoreIbexFatalHwErr = 75, /**< rv_core_ibex_fatal_hw_err */
  kTopDragonflyAlertIdRvCoreIbexRecovHwErr = 76, /**< rv_core_ibex_recov_hw_err */
  kTopDragonflyAlertIdLast = 76, /**< \internal The Last Valid Alert ID. */
} top_dragonfly_alert_id_t;

/**
 * Alert Handler Alert Source to Peripheral Map
 *
 * This array is a mapping from `top_dragonfly_alert_id_t` to
 * `top_dragonfly_alert_peripheral_t`.
 */
extern const top_dragonfly_alert_peripheral_t
    top_dragonfly_alert_for_peripheral[77];

#define PINMUX_MIO_PERIPH_INSEL_IDX_OFFSET 2

// PERIPH_INSEL ranges from 0 to NUM_MIO_PADS + 2 -1}
//  0 and 1 are tied to value 0 and 1
#define NUM_MIO_PADS 12
#define NUM_DIO_PADS 73

#define PINMUX_PERIPH_OUTSEL_IDX_OFFSET 3

/**
 * Pinmux Peripheral Input.
 */
typedef enum top_dragonfly_pinmux_peripheral_in {
  kTopDragonflyPinmuxPeripheralInSocProxySocGpi12 = 0, /**< Peripheral Input 0 */
  kTopDragonflyPinmuxPeripheralInSocProxySocGpi13 = 1, /**< Peripheral Input 1 */
  kTopDragonflyPinmuxPeripheralInSocProxySocGpi14 = 2, /**< Peripheral Input 2 */
  kTopDragonflyPinmuxPeripheralInSocProxySocGpi15 = 3, /**< Peripheral Input 3 */
  kTopDragonflyPinmuxPeripheralInLast = 3, /**< \internal Last valid peripheral input */
} top_dragonfly_pinmux_peripheral_in_t;

/**
 * Pinmux MIO Input Selector.
 */
typedef enum top_dragonfly_pinmux_insel {
  kTopDragonflyPinmuxInselConstantZero = 0, /**< Tie constantly to zero */
  kTopDragonflyPinmuxInselConstantOne = 1, /**< Tie constantly to one */
  kTopDragonflyPinmuxInselMio0 = 2, /**< MIO Pad 0 */
  kTopDragonflyPinmuxInselMio1 = 3, /**< MIO Pad 1 */
  kTopDragonflyPinmuxInselMio2 = 4, /**< MIO Pad 2 */
  kTopDragonflyPinmuxInselMio3 = 5, /**< MIO Pad 3 */
  kTopDragonflyPinmuxInselMio4 = 6, /**< MIO Pad 4 */
  kTopDragonflyPinmuxInselMio5 = 7, /**< MIO Pad 5 */
  kTopDragonflyPinmuxInselMio6 = 8, /**< MIO Pad 6 */
  kTopDragonflyPinmuxInselMio7 = 9, /**< MIO Pad 7 */
  kTopDragonflyPinmuxInselMio8 = 10, /**< MIO Pad 8 */
  kTopDragonflyPinmuxInselMio9 = 11, /**< MIO Pad 9 */
  kTopDragonflyPinmuxInselMio10 = 12, /**< MIO Pad 10 */
  kTopDragonflyPinmuxInselMio11 = 13, /**< MIO Pad 11 */
  kTopDragonflyPinmuxInselLast = 13, /**< \internal Last valid insel value */
} top_dragonfly_pinmux_insel_t;

/**
 * Pinmux MIO Output.
 */
typedef enum top_dragonfly_pinmux_mio_out {
  kTopDragonflyPinmuxMioOutMio0 = 0, /**< MIO Pad 0 */
  kTopDragonflyPinmuxMioOutMio1 = 1, /**< MIO Pad 1 */
  kTopDragonflyPinmuxMioOutMio2 = 2, /**< MIO Pad 2 */
  kTopDragonflyPinmuxMioOutMio3 = 3, /**< MIO Pad 3 */
  kTopDragonflyPinmuxMioOutMio4 = 4, /**< MIO Pad 4 */
  kTopDragonflyPinmuxMioOutMio5 = 5, /**< MIO Pad 5 */
  kTopDragonflyPinmuxMioOutMio6 = 6, /**< MIO Pad 6 */
  kTopDragonflyPinmuxMioOutMio7 = 7, /**< MIO Pad 7 */
  kTopDragonflyPinmuxMioOutMio8 = 8, /**< MIO Pad 8 */
  kTopDragonflyPinmuxMioOutMio9 = 9, /**< MIO Pad 9 */
  kTopDragonflyPinmuxMioOutMio10 = 10, /**< MIO Pad 10 */
  kTopDragonflyPinmuxMioOutMio11 = 11, /**< MIO Pad 11 */
  kTopDragonflyPinmuxMioOutLast = 11, /**< \internal Last valid mio output */
} top_dragonfly_pinmux_mio_out_t;

/**
 * Pinmux Peripheral Output Selector.
 */
typedef enum top_dragonfly_pinmux_outsel {
  kTopDragonflyPinmuxOutselConstantZero = 0, /**< Tie constantly to zero */
  kTopDragonflyPinmuxOutselConstantOne = 1, /**< Tie constantly to one */
  kTopDragonflyPinmuxOutselConstantHighZ = 2, /**< Tie constantly to high-Z */
  kTopDragonflyPinmuxOutselSocProxySocGpo12 = 3, /**< Peripheral Output 0 */
  kTopDragonflyPinmuxOutselSocProxySocGpo13 = 4, /**< Peripheral Output 1 */
  kTopDragonflyPinmuxOutselSocProxySocGpo14 = 5, /**< Peripheral Output 2 */
  kTopDragonflyPinmuxOutselSocProxySocGpo15 = 6, /**< Peripheral Output 3 */
  kTopDragonflyPinmuxOutselOtpMacroTest0 = 7, /**< Peripheral Output 4 */
  kTopDragonflyPinmuxOutselLast = 7, /**< \internal Last valid outsel value */
} top_dragonfly_pinmux_outsel_t;

/**
 * Dedicated Pad Selects
 */
typedef enum top_dragonfly_direct_pads {
  kTopDragonflyDirectPadsSpiHost0Sd0 = 0, /**<  */
  kTopDragonflyDirectPadsSpiHost0Sd1 = 1, /**<  */
  kTopDragonflyDirectPadsSpiHost0Sd2 = 2, /**<  */
  kTopDragonflyDirectPadsSpiHost0Sd3 = 3, /**<  */
  kTopDragonflyDirectPadsSpiDeviceSd0 = 4, /**<  */
  kTopDragonflyDirectPadsSpiDeviceSd1 = 5, /**<  */
  kTopDragonflyDirectPadsSpiDeviceSd2 = 6, /**<  */
  kTopDragonflyDirectPadsSpiDeviceSd3 = 7, /**<  */
  kTopDragonflyDirectPadsI2c0Scl = 8, /**<  */
  kTopDragonflyDirectPadsI2c0Sda = 9, /**<  */
  kTopDragonflyDirectPadsGpioGpio0 = 10, /**<  */
  kTopDragonflyDirectPadsGpioGpio1 = 11, /**<  */
  kTopDragonflyDirectPadsGpioGpio2 = 12, /**<  */
  kTopDragonflyDirectPadsGpioGpio3 = 13, /**<  */
  kTopDragonflyDirectPadsGpioGpio4 = 14, /**<  */
  kTopDragonflyDirectPadsGpioGpio5 = 15, /**<  */
  kTopDragonflyDirectPadsGpioGpio6 = 16, /**<  */
  kTopDragonflyDirectPadsGpioGpio7 = 17, /**<  */
  kTopDragonflyDirectPadsGpioGpio8 = 18, /**<  */
  kTopDragonflyDirectPadsGpioGpio9 = 19, /**<  */
  kTopDragonflyDirectPadsGpioGpio10 = 20, /**<  */
  kTopDragonflyDirectPadsGpioGpio11 = 21, /**<  */
  kTopDragonflyDirectPadsGpioGpio12 = 22, /**<  */
  kTopDragonflyDirectPadsGpioGpio13 = 23, /**<  */
  kTopDragonflyDirectPadsGpioGpio14 = 24, /**<  */
  kTopDragonflyDirectPadsGpioGpio15 = 25, /**<  */
  kTopDragonflyDirectPadsGpioGpio16 = 26, /**<  */
  kTopDragonflyDirectPadsGpioGpio17 = 27, /**<  */
  kTopDragonflyDirectPadsGpioGpio18 = 28, /**<  */
  kTopDragonflyDirectPadsGpioGpio19 = 29, /**<  */
  kTopDragonflyDirectPadsGpioGpio20 = 30, /**<  */
  kTopDragonflyDirectPadsGpioGpio21 = 31, /**<  */
  kTopDragonflyDirectPadsGpioGpio22 = 32, /**<  */
  kTopDragonflyDirectPadsGpioGpio23 = 33, /**<  */
  kTopDragonflyDirectPadsGpioGpio24 = 34, /**<  */
  kTopDragonflyDirectPadsGpioGpio25 = 35, /**<  */
  kTopDragonflyDirectPadsGpioGpio26 = 36, /**<  */
  kTopDragonflyDirectPadsGpioGpio27 = 37, /**<  */
  kTopDragonflyDirectPadsGpioGpio28 = 38, /**<  */
  kTopDragonflyDirectPadsGpioGpio29 = 39, /**<  */
  kTopDragonflyDirectPadsGpioGpio30 = 40, /**<  */
  kTopDragonflyDirectPadsGpioGpio31 = 41, /**<  */
  kTopDragonflyDirectPadsSpiDeviceSck = 42, /**<  */
  kTopDragonflyDirectPadsSpiDeviceCsb = 43, /**<  */
  kTopDragonflyDirectPadsSpiDeviceTpmCsb = 44, /**<  */
  kTopDragonflyDirectPadsUart0Rx = 45, /**<  */
  kTopDragonflyDirectPadsSocProxySocGpi0 = 46, /**<  */
  kTopDragonflyDirectPadsSocProxySocGpi1 = 47, /**<  */
  kTopDragonflyDirectPadsSocProxySocGpi2 = 48, /**<  */
  kTopDragonflyDirectPadsSocProxySocGpi3 = 49, /**<  */
  kTopDragonflyDirectPadsSocProxySocGpi4 = 50, /**<  */
  kTopDragonflyDirectPadsSocProxySocGpi5 = 51, /**<  */
  kTopDragonflyDirectPadsSocProxySocGpi6 = 52, /**<  */
  kTopDragonflyDirectPadsSocProxySocGpi7 = 53, /**<  */
  kTopDragonflyDirectPadsSocProxySocGpi8 = 54, /**<  */
  kTopDragonflyDirectPadsSocProxySocGpi9 = 55, /**<  */
  kTopDragonflyDirectPadsSocProxySocGpi10 = 56, /**<  */
  kTopDragonflyDirectPadsSocProxySocGpi11 = 57, /**<  */
  kTopDragonflyDirectPadsSpiHost0Sck = 58, /**<  */
  kTopDragonflyDirectPadsSpiHost0Csb = 59, /**<  */
  kTopDragonflyDirectPadsUart0Tx = 60, /**<  */
  kTopDragonflyDirectPadsSocProxySocGpo0 = 61, /**<  */
  kTopDragonflyDirectPadsSocProxySocGpo1 = 62, /**<  */
  kTopDragonflyDirectPadsSocProxySocGpo2 = 63, /**<  */
  kTopDragonflyDirectPadsSocProxySocGpo3 = 64, /**<  */
  kTopDragonflyDirectPadsSocProxySocGpo4 = 65, /**<  */
  kTopDragonflyDirectPadsSocProxySocGpo5 = 66, /**<  */
  kTopDragonflyDirectPadsSocProxySocGpo6 = 67, /**<  */
  kTopDragonflyDirectPadsSocProxySocGpo7 = 68, /**<  */
  kTopDragonflyDirectPadsSocProxySocGpo8 = 69, /**<  */
  kTopDragonflyDirectPadsSocProxySocGpo9 = 70, /**<  */
  kTopDragonflyDirectPadsSocProxySocGpo10 = 71, /**<  */
  kTopDragonflyDirectPadsSocProxySocGpo11 = 72, /**<  */
  kTopDragonflyDirectPadsLast = 72, /**< \internal Last valid direct pad */
} top_dragonfly_direct_pads_t;

/**
 * Muxed Pad Selects
 */
typedef enum top_dragonfly_muxed_pads {
  kTopDragonflyMuxedPadsMio0 = 0, /**<  */
  kTopDragonflyMuxedPadsMio1 = 1, /**<  */
  kTopDragonflyMuxedPadsMio2 = 2, /**<  */
  kTopDragonflyMuxedPadsMio3 = 3, /**<  */
  kTopDragonflyMuxedPadsMio4 = 4, /**<  */
  kTopDragonflyMuxedPadsMio5 = 5, /**<  */
  kTopDragonflyMuxedPadsMio6 = 6, /**<  */
  kTopDragonflyMuxedPadsMio7 = 7, /**<  */
  kTopDragonflyMuxedPadsMio8 = 8, /**<  */
  kTopDragonflyMuxedPadsMio9 = 9, /**<  */
  kTopDragonflyMuxedPadsMio10 = 10, /**<  */
  kTopDragonflyMuxedPadsMio11 = 11, /**<  */
  kTopDragonflyMuxedPadsLast = 11, /**< \internal Last valid muxed pad */
} top_dragonfly_muxed_pads_t;

/**
 * Power Manager Wakeup Signals
 */
typedef enum top_dragonfly_power_manager_wake_ups {
  kTopDragonflyPowerManagerWakeUpsPinmuxAonPinWkupReq = 0, /**<  */
  kTopDragonflyPowerManagerWakeUpsAonTimerAonWkupReq = 1, /**<  */
  kTopDragonflyPowerManagerWakeUpsSocProxyWkupExternalReq = 2, /**<  */
  kTopDragonflyPowerManagerWakeUpsLast = 2, /**< \internal Last valid pwrmgr wakeup signal */
} top_dragonfly_power_manager_wake_ups_t;

/**
 * Reset Manager Software Controlled Resets
 */
typedef enum top_dragonfly_reset_manager_sw_resets {
  kTopDragonflyResetManagerSwResetsSpiDevice = 0, /**<  */
  kTopDragonflyResetManagerSwResetsSpiHost0 = 1, /**<  */
  kTopDragonflyResetManagerSwResetsI2c0 = 2, /**<  */
  kTopDragonflyResetManagerSwResetsLast = 2, /**< \internal Last valid rstmgr software reset request */
} top_dragonfly_reset_manager_sw_resets_t;

/**
 * Power Manager Reset Request Signals
 */
typedef enum top_dragonfly_power_manager_reset_requests {
  kTopDragonflyPowerManagerResetRequestsAonTimerAonAonTimerRstReq = 0, /**<  */
  kTopDragonflyPowerManagerResetRequestsSocProxyRstReqExternal = 1, /**<  */
  kTopDragonflyPowerManagerResetRequestsLast = 1, /**< \internal Last valid pwrmgr reset_request signal */
} top_dragonfly_power_manager_reset_requests_t;

/**
 * Clock Manager Software-Controlled ("Gated") Clocks.
 *
 * The Software has full control over these clocks.
 */
typedef enum top_dragonfly_gateable_clocks {
  kTopDragonflyGateableClocksIoPeri = 0, /**< Clock clk_io_peri in group peri */
  kTopDragonflyGateableClocksLast = 0, /**< \internal Last Valid Gateable Clock */
} top_dragonfly_gateable_clocks_t;

/**
 * Clock Manager Software-Hinted Clocks.
 *
 * The Software has partial control over these clocks. It can ask them to stop,
 * but the clock manager is in control of whether the clock actually is stopped.
 */
typedef enum top_dragonfly_hintable_clocks {
  kTopDragonflyHintableClocksMainAcc = 0, /**< Clock clk_main_acc in group trans */
  kTopDragonflyHintableClocksMainAes = 1, /**< Clock clk_main_aes in group trans */
  kTopDragonflyHintableClocksMainHmac = 2, /**< Clock clk_main_hmac in group trans */
  kTopDragonflyHintableClocksMainKmac = 3, /**< Clock clk_main_kmac in group trans */
  kTopDragonflyHintableClocksLast = 3, /**< \internal Last Valid Hintable Clock */
} top_dragonfly_hintable_clocks_t;

/**
 * MMIO Region
 *
 * MMIO region excludes any memory that is separate from the module
 * configuration space, i.e. ROM, main SRAM, and mbx SRAM are excluded but
 * retention SRAM or spi_device are included.
 */
#define TOP_DRAGONFLY_MMIO_BASE_ADDR 0x21100000u
#define TOP_DRAGONFLY_MMIO_SIZE_BYTES 0xF501000u

// Header Extern Guard
#ifdef __cplusplus
}  // extern "C"
#endif

#endif  // OPENTITAN_HW_TOP_DRAGONFLY_SW_AUTOGEN_TOP_DRAGONFLY_H_
