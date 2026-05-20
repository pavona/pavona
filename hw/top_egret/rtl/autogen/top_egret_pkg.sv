// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// ------------------- W A R N I N G: A U T O - G E N E R A T E D   C O D E !! -------------------//
// PLEASE DO NOT HAND-EDIT THIS FILE. IT HAS BEEN AUTO-GENERATED WITH THE FOLLOWING COMMAND:
//
// util/topgen.py -t hw/top_egret/data/top_egret.hjson
//                -o hw/top_egret/

package top_egret_pkg;
  /**
   * Peripheral base address for uart0 in top egret.
   */
  parameter int unsigned TOP_EGRET_UART0_BASE_ADDR = 32'h40000000;

  /**
   * Peripheral size in bytes for uart0 in top egret.
   */
  parameter int unsigned TOP_EGRET_UART0_SIZE_BYTES = 32'h40;

  /**
   * Peripheral base address for uart1 in top egret.
   */
  parameter int unsigned TOP_EGRET_UART1_BASE_ADDR = 32'h40010000;

  /**
   * Peripheral size in bytes for uart1 in top egret.
   */
  parameter int unsigned TOP_EGRET_UART1_SIZE_BYTES = 32'h40;

  /**
   * Peripheral base address for uart2 in top egret.
   */
  parameter int unsigned TOP_EGRET_UART2_BASE_ADDR = 32'h40020000;

  /**
   * Peripheral size in bytes for uart2 in top egret.
   */
  parameter int unsigned TOP_EGRET_UART2_SIZE_BYTES = 32'h40;

  /**
   * Peripheral base address for uart3 in top egret.
   */
  parameter int unsigned TOP_EGRET_UART3_BASE_ADDR = 32'h40030000;

  /**
   * Peripheral size in bytes for uart3 in top egret.
   */
  parameter int unsigned TOP_EGRET_UART3_SIZE_BYTES = 32'h40;

  /**
   * Peripheral base address for gpio in top egret.
   */
  parameter int unsigned TOP_EGRET_GPIO_BASE_ADDR = 32'h40040000;

  /**
   * Peripheral size in bytes for gpio in top egret.
   */
  parameter int unsigned TOP_EGRET_GPIO_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for spi_device in top egret.
   */
  parameter int unsigned TOP_EGRET_SPI_DEVICE_BASE_ADDR = 32'h40050000;

  /**
   * Peripheral size in bytes for spi_device in top egret.
   */
  parameter int unsigned TOP_EGRET_SPI_DEVICE_SIZE_BYTES = 32'h2000;

  /**
   * Peripheral base address for i2c0 in top egret.
   */
  parameter int unsigned TOP_EGRET_I2C0_BASE_ADDR = 32'h40080000;

  /**
   * Peripheral size in bytes for i2c0 in top egret.
   */
  parameter int unsigned TOP_EGRET_I2C0_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for i2c1 in top egret.
   */
  parameter int unsigned TOP_EGRET_I2C1_BASE_ADDR = 32'h40090000;

  /**
   * Peripheral size in bytes for i2c1 in top egret.
   */
  parameter int unsigned TOP_EGRET_I2C1_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for i2c2 in top egret.
   */
  parameter int unsigned TOP_EGRET_I2C2_BASE_ADDR = 32'h400A0000;

  /**
   * Peripheral size in bytes for i2c2 in top egret.
   */
  parameter int unsigned TOP_EGRET_I2C2_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for pattgen in top egret.
   */
  parameter int unsigned TOP_EGRET_PATTGEN_BASE_ADDR = 32'h400E0000;

  /**
   * Peripheral size in bytes for pattgen in top egret.
   */
  parameter int unsigned TOP_EGRET_PATTGEN_SIZE_BYTES = 32'h40;

  /**
   * Peripheral base address for rv_timer in top egret.
   */
  parameter int unsigned TOP_EGRET_RV_TIMER_BASE_ADDR = 32'h40100000;

  /**
   * Peripheral size in bytes for rv_timer in top egret.
   */
  parameter int unsigned TOP_EGRET_RV_TIMER_SIZE_BYTES = 32'h200;

  /**
   * Peripheral base address for core device on otp_ctrl in top egret.
   */
  parameter int unsigned TOP_EGRET_OTP_CTRL_CORE_BASE_ADDR = 32'h40130000;

  /**
   * Peripheral size in bytes for core device on otp_ctrl in top egret.
   */
  parameter int unsigned TOP_EGRET_OTP_CTRL_CORE_SIZE_BYTES = 32'h1000;

  /**
   * Peripheral base address for prim device on otp_macro in top egret.
   */
  parameter int unsigned TOP_EGRET_OTP_MACRO_PRIM_BASE_ADDR = 32'h40138000;

  /**
   * Peripheral size in bytes for prim device on otp_macro in top egret.
   */
  parameter int unsigned TOP_EGRET_OTP_MACRO_PRIM_SIZE_BYTES = 32'h20;

  /**
   * Peripheral base address for regs device on lc_ctrl in top egret.
   */
  parameter int unsigned TOP_EGRET_LC_CTRL_REGS_BASE_ADDR = 32'h40140000;

  /**
   * Peripheral size in bytes for regs device on lc_ctrl in top egret.
   */
  parameter int unsigned TOP_EGRET_LC_CTRL_REGS_SIZE_BYTES = 32'h100;

  /**
   * Peripheral base address for dmi device on lc_ctrl in top egret.
   */
  parameter int unsigned TOP_EGRET_LC_CTRL_DMI_BASE_ADDR = 32'h0;

  /**
   * Peripheral size in bytes for dmi device on lc_ctrl in top egret.
   */
  parameter int unsigned TOP_EGRET_LC_CTRL_DMI_SIZE_BYTES = 32'h1000;

  /**
   * Peripheral base address for alert_handler in top egret.
   */
  parameter int unsigned TOP_EGRET_ALERT_HANDLER_BASE_ADDR = 32'h40150000;

  /**
   * Peripheral size in bytes for alert_handler in top egret.
   */
  parameter int unsigned TOP_EGRET_ALERT_HANDLER_SIZE_BYTES = 32'h800;

  /**
   * Peripheral base address for spi_host0 in top egret.
   */
  parameter int unsigned TOP_EGRET_SPI_HOST0_BASE_ADDR = 32'h40300000;

  /**
   * Peripheral size in bytes for spi_host0 in top egret.
   */
  parameter int unsigned TOP_EGRET_SPI_HOST0_SIZE_BYTES = 32'h40;

  /**
   * Peripheral base address for spi_host1 in top egret.
   */
  parameter int unsigned TOP_EGRET_SPI_HOST1_BASE_ADDR = 32'h40310000;

  /**
   * Peripheral size in bytes for spi_host1 in top egret.
   */
  parameter int unsigned TOP_EGRET_SPI_HOST1_SIZE_BYTES = 32'h40;

  /**
   * Peripheral base address for usbdev in top egret.
   */
  parameter int unsigned TOP_EGRET_USBDEV_BASE_ADDR = 32'h40320000;

  /**
   * Peripheral size in bytes for usbdev in top egret.
   */
  parameter int unsigned TOP_EGRET_USBDEV_SIZE_BYTES = 32'h1000;

  /**
   * Peripheral base address for pwrmgr_aon in top egret.
   */
  parameter int unsigned TOP_EGRET_PWRMGR_AON_BASE_ADDR = 32'h40400000;

  /**
   * Peripheral size in bytes for pwrmgr_aon in top egret.
   */
  parameter int unsigned TOP_EGRET_PWRMGR_AON_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for rstmgr_aon in top egret.
   */
  parameter int unsigned TOP_EGRET_RSTMGR_AON_BASE_ADDR = 32'h40410000;

  /**
   * Peripheral size in bytes for rstmgr_aon in top egret.
   */
  parameter int unsigned TOP_EGRET_RSTMGR_AON_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for clkmgr_aon in top egret.
   */
  parameter int unsigned TOP_EGRET_CLKMGR_AON_BASE_ADDR = 32'h40420000;

  /**
   * Peripheral size in bytes for clkmgr_aon in top egret.
   */
  parameter int unsigned TOP_EGRET_CLKMGR_AON_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for sysrst_ctrl_aon in top egret.
   */
  parameter int unsigned TOP_EGRET_SYSRST_CTRL_AON_BASE_ADDR = 32'h40430000;

  /**
   * Peripheral size in bytes for sysrst_ctrl_aon in top egret.
   */
  parameter int unsigned TOP_EGRET_SYSRST_CTRL_AON_SIZE_BYTES = 32'h100;

  /**
   * Peripheral base address for adc_ctrl_aon in top egret.
   */
  parameter int unsigned TOP_EGRET_ADC_CTRL_AON_BASE_ADDR = 32'h40440000;

  /**
   * Peripheral size in bytes for adc_ctrl_aon in top egret.
   */
  parameter int unsigned TOP_EGRET_ADC_CTRL_AON_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for pwm_aon in top egret.
   */
  parameter int unsigned TOP_EGRET_PWM_AON_BASE_ADDR = 32'h40450000;

  /**
   * Peripheral size in bytes for pwm_aon in top egret.
   */
  parameter int unsigned TOP_EGRET_PWM_AON_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for pinmux_aon in top egret.
   */
  parameter int unsigned TOP_EGRET_PINMUX_AON_BASE_ADDR = 32'h40460000;

  /**
   * Peripheral size in bytes for pinmux_aon in top egret.
   */
  parameter int unsigned TOP_EGRET_PINMUX_AON_SIZE_BYTES = 32'h1000;

  /**
   * Peripheral base address for aon_timer_aon in top egret.
   */
  parameter int unsigned TOP_EGRET_AON_TIMER_AON_BASE_ADDR = 32'h40470000;

  /**
   * Peripheral size in bytes for aon_timer_aon in top egret.
   */
  parameter int unsigned TOP_EGRET_AON_TIMER_AON_SIZE_BYTES = 32'h40;

  /**
   * Peripheral base address for ast in top egret.
   */
  parameter int unsigned TOP_EGRET_AST_BASE_ADDR = 32'h40480000;

  /**
   * Peripheral size in bytes for ast in top egret.
   */
  parameter int unsigned TOP_EGRET_AST_SIZE_BYTES = 32'h400;

  /**
   * Peripheral base address for sensor_ctrl_aon in top egret.
   */
  parameter int unsigned TOP_EGRET_SENSOR_CTRL_AON_BASE_ADDR = 32'h40490000;

  /**
   * Peripheral size in bytes for sensor_ctrl_aon in top egret.
   */
  parameter int unsigned TOP_EGRET_SENSOR_CTRL_AON_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for regs device on sram_ctrl_ret_aon in top egret.
   */
  parameter int unsigned TOP_EGRET_SRAM_CTRL_RET_AON_REGS_BASE_ADDR = 32'h40500000;

  /**
   * Peripheral size in bytes for regs device on sram_ctrl_ret_aon in top egret.
   */
  parameter int unsigned TOP_EGRET_SRAM_CTRL_RET_AON_REGS_SIZE_BYTES = 32'h40;

  /**
   * Peripheral base address for core device on flash_ctrl in top egret.
   */
  parameter int unsigned TOP_EGRET_FLASH_CTRL_CORE_BASE_ADDR = 32'h41000000;

  /**
   * Peripheral size in bytes for core device on flash_ctrl in top egret.
   */
  parameter int unsigned TOP_EGRET_FLASH_CTRL_CORE_SIZE_BYTES = 32'h200;

  /**
   * Peripheral base address for flash_macro_wrapper in top egret.
   */
  parameter int unsigned TOP_EGRET_FLASH_MACRO_WRAPPER_BASE_ADDR = 32'h41008000;

  /**
   * Peripheral size in bytes for flash_macro_wrapper in top egret.
   */
  parameter int unsigned TOP_EGRET_FLASH_MACRO_WRAPPER_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for regs device on rv_dm in top egret.
   */
  parameter int unsigned TOP_EGRET_RV_DM_REGS_BASE_ADDR = 32'h41200000;

  /**
   * Peripheral size in bytes for regs device on rv_dm in top egret.
   */
  parameter int unsigned TOP_EGRET_RV_DM_REGS_SIZE_BYTES = 32'h10;

  /**
   * Peripheral base address for mem device on rv_dm in top egret.
   */
  parameter int unsigned TOP_EGRET_RV_DM_MEM_BASE_ADDR = 32'h10000;

  /**
   * Peripheral size in bytes for mem device on rv_dm in top egret.
   */
  parameter int unsigned TOP_EGRET_RV_DM_MEM_SIZE_BYTES = 32'h1000;

  /**
   * Peripheral base address for dbg device on rv_dm in top egret.
   */
  parameter int unsigned TOP_EGRET_RV_DM_DBG_BASE_ADDR = 32'h1000;

  /**
   * Peripheral size in bytes for dbg device on rv_dm in top egret.
   */
  parameter int unsigned TOP_EGRET_RV_DM_DBG_SIZE_BYTES = 32'h200;

  /**
   * Peripheral base address for rv_plic in top egret.
   */
  parameter int unsigned TOP_EGRET_RV_PLIC_BASE_ADDR = 32'h48000000;

  /**
   * Peripheral size in bytes for rv_plic in top egret.
   */
  parameter int unsigned TOP_EGRET_RV_PLIC_SIZE_BYTES = 32'h8000000;

  /**
   * Peripheral base address for acc in top egret.
   */
  parameter int unsigned TOP_EGRET_ACC_BASE_ADDR = 32'h41300000;

  /**
   * Peripheral size in bytes for acc in top egret.
   */
  parameter int unsigned TOP_EGRET_ACC_SIZE_BYTES = 32'h20000;

  /**
   * Peripheral base address for aes in top egret.
   */
  parameter int unsigned TOP_EGRET_AES_BASE_ADDR = 32'h41100000;

  /**
   * Peripheral size in bytes for aes in top egret.
   */
  parameter int unsigned TOP_EGRET_AES_SIZE_BYTES = 32'h100;

  /**
   * Peripheral base address for hmac in top egret.
   */
  parameter int unsigned TOP_EGRET_HMAC_BASE_ADDR = 32'h41110000;

  /**
   * Peripheral size in bytes for hmac in top egret.
   */
  parameter int unsigned TOP_EGRET_HMAC_SIZE_BYTES = 32'h2000;

  /**
   * Peripheral base address for kmac in top egret.
   */
  parameter int unsigned TOP_EGRET_KMAC_BASE_ADDR = 32'h41120000;

  /**
   * Peripheral size in bytes for kmac in top egret.
   */
  parameter int unsigned TOP_EGRET_KMAC_SIZE_BYTES = 32'h1000;

  /**
   * Peripheral base address for keymgr in top egret.
   */
  parameter int unsigned TOP_EGRET_KEYMGR_BASE_ADDR = 32'h41140000;

  /**
   * Peripheral size in bytes for keymgr in top egret.
   */
  parameter int unsigned TOP_EGRET_KEYMGR_SIZE_BYTES = 32'h100;

  /**
   * Peripheral base address for csrng in top egret.
   */
  parameter int unsigned TOP_EGRET_CSRNG_BASE_ADDR = 32'h41150000;

  /**
   * Peripheral size in bytes for csrng in top egret.
   */
  parameter int unsigned TOP_EGRET_CSRNG_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for entropy_src in top egret.
   */
  parameter int unsigned TOP_EGRET_ENTROPY_SRC_BASE_ADDR = 32'h41160000;

  /**
   * Peripheral size in bytes for entropy_src in top egret.
   */
  parameter int unsigned TOP_EGRET_ENTROPY_SRC_SIZE_BYTES = 32'h100;

  /**
   * Peripheral base address for edn0 in top egret.
   */
  parameter int unsigned TOP_EGRET_EDN0_BASE_ADDR = 32'h41170000;

  /**
   * Peripheral size in bytes for edn0 in top egret.
   */
  parameter int unsigned TOP_EGRET_EDN0_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for edn1 in top egret.
   */
  parameter int unsigned TOP_EGRET_EDN1_BASE_ADDR = 32'h41180000;

  /**
   * Peripheral size in bytes for edn1 in top egret.
   */
  parameter int unsigned TOP_EGRET_EDN1_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for regs device on sram_ctrl_main in top egret.
   */
  parameter int unsigned TOP_EGRET_SRAM_CTRL_MAIN_REGS_BASE_ADDR = 32'h411C0000;

  /**
   * Peripheral size in bytes for regs device on sram_ctrl_main in top egret.
   */
  parameter int unsigned TOP_EGRET_SRAM_CTRL_MAIN_REGS_SIZE_BYTES = 32'h40;

  /**
   * Peripheral base address for regs device on rom_ctrl in top egret.
   */
  parameter int unsigned TOP_EGRET_ROM_CTRL_REGS_BASE_ADDR = 32'h411E0000;

  /**
   * Peripheral size in bytes for regs device on rom_ctrl in top egret.
   */
  parameter int unsigned TOP_EGRET_ROM_CTRL_REGS_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for cfg device on rv_core_ibex in top egret.
   */
  parameter int unsigned TOP_EGRET_RV_CORE_IBEX_CFG_BASE_ADDR = 32'h411F0000;

  /**
   * Peripheral size in bytes for cfg device on rv_core_ibex in top egret.
   */
  parameter int unsigned TOP_EGRET_RV_CORE_IBEX_CFG_SIZE_BYTES = 32'h100;

  /**
   * Memory base address for ram memory on sram_ctrl_ret_aon in top egret.
   */
  parameter int unsigned TOP_EGRET_SRAM_CTRL_RET_AON_RAM_BASE_ADDR = 32'h40600000;

  /**
   * Memory size for ram memory on sram_ctrl_ret_aon in top egret.
   */
  parameter int unsigned TOP_EGRET_SRAM_CTRL_RET_AON_RAM_SIZE_BYTES = 32'h1000;

  /**
   * Memory base address for mem memory on flash_ctrl in top egret.
   */
  parameter int unsigned TOP_EGRET_FLASH_CTRL_MEM_BASE_ADDR = 32'h20000000;

  /**
   * Memory size for mem memory on flash_ctrl in top egret.
   */
  parameter int unsigned TOP_EGRET_FLASH_CTRL_MEM_SIZE_BYTES = 32'h100000;

  /**
   * Memory base address for ram memory on sram_ctrl_main in top egret.
   */
  parameter int unsigned TOP_EGRET_SRAM_CTRL_MAIN_RAM_BASE_ADDR = 32'h10000000;

  /**
   * Memory size for ram memory on sram_ctrl_main in top egret.
   */
  parameter int unsigned TOP_EGRET_SRAM_CTRL_MAIN_RAM_SIZE_BYTES = 32'h20000;

  /**
   * Memory base address for rom memory on rom_ctrl in top egret.
   */
  parameter int unsigned TOP_EGRET_ROM_CTRL_ROM_BASE_ADDR = 32'h8000;

  /**
   * Memory size for rom memory on rom_ctrl in top egret.
   */
  parameter int unsigned TOP_EGRET_ROM_CTRL_ROM_SIZE_BYTES = 32'h8000;


  // Enumeration of alert modules
  typedef enum int unsigned {
    TopEgretAlertPeripheralUart0 = 0,
    TopEgretAlertPeripheralUart1 = 1,
    TopEgretAlertPeripheralUart2 = 2,
    TopEgretAlertPeripheralUart3 = 3,
    TopEgretAlertPeripheralGpio = 4,
    TopEgretAlertPeripheralSpiDevice = 5,
    TopEgretAlertPeripheralI2c0 = 6,
    TopEgretAlertPeripheralI2c1 = 7,
    TopEgretAlertPeripheralI2c2 = 8,
    TopEgretAlertPeripheralPattgen = 9,
    TopEgretAlertPeripheralRvTimer = 10,
    TopEgretAlertPeripheralOtpCtrl = 11,
    TopEgretAlertPeripheralLcCtrl = 12,
    TopEgretAlertPeripheralSpiHost0 = 13,
    TopEgretAlertPeripheralSpiHost1 = 14,
    TopEgretAlertPeripheralUsbdev = 15,
    TopEgretAlertPeripheralPwrmgrAon = 16,
    TopEgretAlertPeripheralRstmgrAon = 17,
    TopEgretAlertPeripheralClkmgrAon = 18,
    TopEgretAlertPeripheralSysrstCtrlAon = 19,
    TopEgretAlertPeripheralAdcCtrlAon = 20,
    TopEgretAlertPeripheralPwmAon = 21,
    TopEgretAlertPeripheralPinmuxAon = 22,
    TopEgretAlertPeripheralAonTimerAon = 23,
    TopEgretAlertPeripheralSensorCtrlAon = 24,
    TopEgretAlertPeripheralSramCtrlRetAon = 25,
    TopEgretAlertPeripheralFlashCtrl = 26,
    TopEgretAlertPeripheralRvDm = 27,
    TopEgretAlertPeripheralRvPlic = 28,
    TopEgretAlertPeripheralAcc = 29,
    TopEgretAlertPeripheralAes = 30,
    TopEgretAlertPeripheralHmac = 31,
    TopEgretAlertPeripheralKmac = 32,
    TopEgretAlertPeripheralKeymgr = 33,
    TopEgretAlertPeripheralCsrng = 34,
    TopEgretAlertPeripheralEntropySrc = 35,
    TopEgretAlertPeripheralEdn0 = 36,
    TopEgretAlertPeripheralEdn1 = 37,
    TopEgretAlertPeripheralSramCtrlMain = 38,
    TopEgretAlertPeripheralRomCtrl = 39,
    TopEgretAlertPeripheralRvCoreIbex = 40,
    TopEgretAlertPeripheralCount
  } alert_peripheral_e;

  // Enumeration of alerts
  typedef enum int unsigned {
    TopEgretAlertIdUart0FatalFault = 0,
    TopEgretAlertIdUart1FatalFault = 1,
    TopEgretAlertIdUart2FatalFault = 2,
    TopEgretAlertIdUart3FatalFault = 3,
    TopEgretAlertIdGpioFatalFault = 4,
    TopEgretAlertIdSpiDeviceFatalFault = 5,
    TopEgretAlertIdI2c0FatalFault = 6,
    TopEgretAlertIdI2c1FatalFault = 7,
    TopEgretAlertIdI2c2FatalFault = 8,
    TopEgretAlertIdPattgenFatalFault = 9,
    TopEgretAlertIdRvTimerFatalFault = 10,
    TopEgretAlertIdOtpCtrlFatalMacroError = 11,
    TopEgretAlertIdOtpCtrlFatalCheckError = 12,
    TopEgretAlertIdOtpCtrlFatalBusIntegError = 13,
    TopEgretAlertIdOtpCtrlFatalPrimOtpAlert = 14,
    TopEgretAlertIdOtpCtrlRecovPrimOtpAlert = 15,
    TopEgretAlertIdLcCtrlFatalProgError = 16,
    TopEgretAlertIdLcCtrlFatalStateError = 17,
    TopEgretAlertIdLcCtrlFatalBusIntegError = 18,
    TopEgretAlertIdSpiHost0FatalFault = 19,
    TopEgretAlertIdSpiHost1FatalFault = 20,
    TopEgretAlertIdUsbdevFatalFault = 21,
    TopEgretAlertIdPwrmgrAonFatalFault = 22,
    TopEgretAlertIdRstmgrAonFatalFault = 23,
    TopEgretAlertIdRstmgrAonFatalCnstyFault = 24,
    TopEgretAlertIdClkmgrAonRecovFault = 25,
    TopEgretAlertIdClkmgrAonFatalFault = 26,
    TopEgretAlertIdSysrstCtrlAonFatalFault = 27,
    TopEgretAlertIdAdcCtrlAonFatalFault = 28,
    TopEgretAlertIdPwmAonFatalFault = 29,
    TopEgretAlertIdPinmuxAonFatalFault = 30,
    TopEgretAlertIdAonTimerAonFatalFault = 31,
    TopEgretAlertIdSensorCtrlAonRecovAlert = 32,
    TopEgretAlertIdSensorCtrlAonFatalAlert = 33,
    TopEgretAlertIdSramCtrlRetAonFatalError = 34,
    TopEgretAlertIdFlashCtrlRecovErr = 35,
    TopEgretAlertIdFlashCtrlFatalStdErr = 36,
    TopEgretAlertIdFlashCtrlFatalErr = 37,
    TopEgretAlertIdFlashCtrlFatalPrimFlashAlert = 38,
    TopEgretAlertIdFlashCtrlRecovPrimFlashAlert = 39,
    TopEgretAlertIdRvDmFatalFault = 40,
    TopEgretAlertIdRvPlicFatalFault = 41,
    TopEgretAlertIdAccFatal = 42,
    TopEgretAlertIdAccRecov = 43,
    TopEgretAlertIdAesRecovCtrlUpdateErr = 44,
    TopEgretAlertIdAesFatalFault = 45,
    TopEgretAlertIdHmacFatalFault = 46,
    TopEgretAlertIdKmacRecovOperationErr = 47,
    TopEgretAlertIdKmacFatalFaultErr = 48,
    TopEgretAlertIdKeymgrRecovOperationErr = 49,
    TopEgretAlertIdKeymgrFatalFaultErr = 50,
    TopEgretAlertIdCsrngRecovAlert = 51,
    TopEgretAlertIdCsrngFatalAlert = 52,
    TopEgretAlertIdEntropySrcRecovAlert = 53,
    TopEgretAlertIdEntropySrcFatalAlert = 54,
    TopEgretAlertIdEdn0RecovAlert = 55,
    TopEgretAlertIdEdn0FatalAlert = 56,
    TopEgretAlertIdEdn1RecovAlert = 57,
    TopEgretAlertIdEdn1FatalAlert = 58,
    TopEgretAlertIdSramCtrlMainFatalError = 59,
    TopEgretAlertIdRomCtrlFatal = 60,
    TopEgretAlertIdRvCoreIbexFatalSwErr = 61,
    TopEgretAlertIdRvCoreIbexRecovSwErr = 62,
    TopEgretAlertIdRvCoreIbexFatalHwErr = 63,
    TopEgretAlertIdRvCoreIbexRecovHwErr = 64,
    TopEgretAlertIdCount
  } alert_id_e;

  // Enumeration of interrupts
  typedef enum int unsigned {
    TopEgretPlicIrqIdNone = 0,
    TopEgretPlicIrqIdUart0TxWatermark = 1,
    TopEgretPlicIrqIdUart0RxWatermark = 2,
    TopEgretPlicIrqIdUart0TxDone = 3,
    TopEgretPlicIrqIdUart0RxOverflow = 4,
    TopEgretPlicIrqIdUart0RxFrameErr = 5,
    TopEgretPlicIrqIdUart0RxBreakErr = 6,
    TopEgretPlicIrqIdUart0RxTimeout = 7,
    TopEgretPlicIrqIdUart0RxParityErr = 8,
    TopEgretPlicIrqIdUart0TxEmpty = 9,
    TopEgretPlicIrqIdUart1TxWatermark = 10,
    TopEgretPlicIrqIdUart1RxWatermark = 11,
    TopEgretPlicIrqIdUart1TxDone = 12,
    TopEgretPlicIrqIdUart1RxOverflow = 13,
    TopEgretPlicIrqIdUart1RxFrameErr = 14,
    TopEgretPlicIrqIdUart1RxBreakErr = 15,
    TopEgretPlicIrqIdUart1RxTimeout = 16,
    TopEgretPlicIrqIdUart1RxParityErr = 17,
    TopEgretPlicIrqIdUart1TxEmpty = 18,
    TopEgretPlicIrqIdUart2TxWatermark = 19,
    TopEgretPlicIrqIdUart2RxWatermark = 20,
    TopEgretPlicIrqIdUart2TxDone = 21,
    TopEgretPlicIrqIdUart2RxOverflow = 22,
    TopEgretPlicIrqIdUart2RxFrameErr = 23,
    TopEgretPlicIrqIdUart2RxBreakErr = 24,
    TopEgretPlicIrqIdUart2RxTimeout = 25,
    TopEgretPlicIrqIdUart2RxParityErr = 26,
    TopEgretPlicIrqIdUart2TxEmpty = 27,
    TopEgretPlicIrqIdUart3TxWatermark = 28,
    TopEgretPlicIrqIdUart3RxWatermark = 29,
    TopEgretPlicIrqIdUart3TxDone = 30,
    TopEgretPlicIrqIdUart3RxOverflow = 31,
    TopEgretPlicIrqIdUart3RxFrameErr = 32,
    TopEgretPlicIrqIdUart3RxBreakErr = 33,
    TopEgretPlicIrqIdUart3RxTimeout = 34,
    TopEgretPlicIrqIdUart3RxParityErr = 35,
    TopEgretPlicIrqIdUart3TxEmpty = 36,
    TopEgretPlicIrqIdGpioGpio0 = 37,
    TopEgretPlicIrqIdGpioGpio1 = 38,
    TopEgretPlicIrqIdGpioGpio2 = 39,
    TopEgretPlicIrqIdGpioGpio3 = 40,
    TopEgretPlicIrqIdGpioGpio4 = 41,
    TopEgretPlicIrqIdGpioGpio5 = 42,
    TopEgretPlicIrqIdGpioGpio6 = 43,
    TopEgretPlicIrqIdGpioGpio7 = 44,
    TopEgretPlicIrqIdGpioGpio8 = 45,
    TopEgretPlicIrqIdGpioGpio9 = 46,
    TopEgretPlicIrqIdGpioGpio10 = 47,
    TopEgretPlicIrqIdGpioGpio11 = 48,
    TopEgretPlicIrqIdGpioGpio12 = 49,
    TopEgretPlicIrqIdGpioGpio13 = 50,
    TopEgretPlicIrqIdGpioGpio14 = 51,
    TopEgretPlicIrqIdGpioGpio15 = 52,
    TopEgretPlicIrqIdGpioGpio16 = 53,
    TopEgretPlicIrqIdGpioGpio17 = 54,
    TopEgretPlicIrqIdGpioGpio18 = 55,
    TopEgretPlicIrqIdGpioGpio19 = 56,
    TopEgretPlicIrqIdGpioGpio20 = 57,
    TopEgretPlicIrqIdGpioGpio21 = 58,
    TopEgretPlicIrqIdGpioGpio22 = 59,
    TopEgretPlicIrqIdGpioGpio23 = 60,
    TopEgretPlicIrqIdGpioGpio24 = 61,
    TopEgretPlicIrqIdGpioGpio25 = 62,
    TopEgretPlicIrqIdGpioGpio26 = 63,
    TopEgretPlicIrqIdGpioGpio27 = 64,
    TopEgretPlicIrqIdGpioGpio28 = 65,
    TopEgretPlicIrqIdGpioGpio29 = 66,
    TopEgretPlicIrqIdGpioGpio30 = 67,
    TopEgretPlicIrqIdGpioGpio31 = 68,
    TopEgretPlicIrqIdSpiDeviceUploadCmdfifoNotEmpty = 69,
    TopEgretPlicIrqIdSpiDeviceUploadPayloadNotEmpty = 70,
    TopEgretPlicIrqIdSpiDeviceUploadPayloadOverflow = 71,
    TopEgretPlicIrqIdSpiDeviceReadbufWatermark = 72,
    TopEgretPlicIrqIdSpiDeviceReadbufFlip = 73,
    TopEgretPlicIrqIdSpiDeviceTpmHeaderNotEmpty = 74,
    TopEgretPlicIrqIdSpiDeviceTpmRdfifoCmdEnd = 75,
    TopEgretPlicIrqIdSpiDeviceTpmRdfifoDrop = 76,
    TopEgretPlicIrqIdI2c0FmtThreshold = 77,
    TopEgretPlicIrqIdI2c0RxThreshold = 78,
    TopEgretPlicIrqIdI2c0AcqThreshold = 79,
    TopEgretPlicIrqIdI2c0RxOverflow = 80,
    TopEgretPlicIrqIdI2c0ControllerHalt = 81,
    TopEgretPlicIrqIdI2c0SclInterference = 82,
    TopEgretPlicIrqIdI2c0SdaInterference = 83,
    TopEgretPlicIrqIdI2c0StretchTimeout = 84,
    TopEgretPlicIrqIdI2c0SdaUnstable = 85,
    TopEgretPlicIrqIdI2c0CmdComplete = 86,
    TopEgretPlicIrqIdI2c0TxStretch = 87,
    TopEgretPlicIrqIdI2c0TxThreshold = 88,
    TopEgretPlicIrqIdI2c0AcqStretch = 89,
    TopEgretPlicIrqIdI2c0UnexpStop = 90,
    TopEgretPlicIrqIdI2c0HostTimeout = 91,
    TopEgretPlicIrqIdI2c1FmtThreshold = 92,
    TopEgretPlicIrqIdI2c1RxThreshold = 93,
    TopEgretPlicIrqIdI2c1AcqThreshold = 94,
    TopEgretPlicIrqIdI2c1RxOverflow = 95,
    TopEgretPlicIrqIdI2c1ControllerHalt = 96,
    TopEgretPlicIrqIdI2c1SclInterference = 97,
    TopEgretPlicIrqIdI2c1SdaInterference = 98,
    TopEgretPlicIrqIdI2c1StretchTimeout = 99,
    TopEgretPlicIrqIdI2c1SdaUnstable = 100,
    TopEgretPlicIrqIdI2c1CmdComplete = 101,
    TopEgretPlicIrqIdI2c1TxStretch = 102,
    TopEgretPlicIrqIdI2c1TxThreshold = 103,
    TopEgretPlicIrqIdI2c1AcqStretch = 104,
    TopEgretPlicIrqIdI2c1UnexpStop = 105,
    TopEgretPlicIrqIdI2c1HostTimeout = 106,
    TopEgretPlicIrqIdI2c2FmtThreshold = 107,
    TopEgretPlicIrqIdI2c2RxThreshold = 108,
    TopEgretPlicIrqIdI2c2AcqThreshold = 109,
    TopEgretPlicIrqIdI2c2RxOverflow = 110,
    TopEgretPlicIrqIdI2c2ControllerHalt = 111,
    TopEgretPlicIrqIdI2c2SclInterference = 112,
    TopEgretPlicIrqIdI2c2SdaInterference = 113,
    TopEgretPlicIrqIdI2c2StretchTimeout = 114,
    TopEgretPlicIrqIdI2c2SdaUnstable = 115,
    TopEgretPlicIrqIdI2c2CmdComplete = 116,
    TopEgretPlicIrqIdI2c2TxStretch = 117,
    TopEgretPlicIrqIdI2c2TxThreshold = 118,
    TopEgretPlicIrqIdI2c2AcqStretch = 119,
    TopEgretPlicIrqIdI2c2UnexpStop = 120,
    TopEgretPlicIrqIdI2c2HostTimeout = 121,
    TopEgretPlicIrqIdPattgenDoneCh0 = 122,
    TopEgretPlicIrqIdPattgenDoneCh1 = 123,
    TopEgretPlicIrqIdRvTimerTimerExpiredHart0Timer0 = 124,
    TopEgretPlicIrqIdOtpCtrlOtpOperationDone = 125,
    TopEgretPlicIrqIdOtpCtrlOtpError = 126,
    TopEgretPlicIrqIdAlertHandlerClassa = 127,
    TopEgretPlicIrqIdAlertHandlerClassb = 128,
    TopEgretPlicIrqIdAlertHandlerClassc = 129,
    TopEgretPlicIrqIdAlertHandlerClassd = 130,
    TopEgretPlicIrqIdSpiHost0Error = 131,
    TopEgretPlicIrqIdSpiHost0SpiEvent = 132,
    TopEgretPlicIrqIdSpiHost1Error = 133,
    TopEgretPlicIrqIdSpiHost1SpiEvent = 134,
    TopEgretPlicIrqIdUsbdevPktReceived = 135,
    TopEgretPlicIrqIdUsbdevPktSent = 136,
    TopEgretPlicIrqIdUsbdevDisconnected = 137,
    TopEgretPlicIrqIdUsbdevHostLost = 138,
    TopEgretPlicIrqIdUsbdevLinkReset = 139,
    TopEgretPlicIrqIdUsbdevLinkSuspend = 140,
    TopEgretPlicIrqIdUsbdevLinkResume = 141,
    TopEgretPlicIrqIdUsbdevAvOutEmpty = 142,
    TopEgretPlicIrqIdUsbdevRxFull = 143,
    TopEgretPlicIrqIdUsbdevAvOverflow = 144,
    TopEgretPlicIrqIdUsbdevLinkInErr = 145,
    TopEgretPlicIrqIdUsbdevRxCrcErr = 146,
    TopEgretPlicIrqIdUsbdevRxPidErr = 147,
    TopEgretPlicIrqIdUsbdevRxBitstuffErr = 148,
    TopEgretPlicIrqIdUsbdevFrame = 149,
    TopEgretPlicIrqIdUsbdevPowered = 150,
    TopEgretPlicIrqIdUsbdevLinkOutErr = 151,
    TopEgretPlicIrqIdUsbdevAvSetupEmpty = 152,
    TopEgretPlicIrqIdPwrmgrAonWakeup = 153,
    TopEgretPlicIrqIdSysrstCtrlAonEventDetected = 154,
    TopEgretPlicIrqIdAdcCtrlAonMatchPending = 155,
    TopEgretPlicIrqIdAonTimerAonWkupTimerExpired = 156,
    TopEgretPlicIrqIdAonTimerAonWdogTimerBark = 157,
    TopEgretPlicIrqIdSensorCtrlAonIoStatusChange = 158,
    TopEgretPlicIrqIdSensorCtrlAonInitStatusChange = 159,
    TopEgretPlicIrqIdFlashCtrlProgEmpty = 160,
    TopEgretPlicIrqIdFlashCtrlProgLvl = 161,
    TopEgretPlicIrqIdFlashCtrlRdFull = 162,
    TopEgretPlicIrqIdFlashCtrlRdLvl = 163,
    TopEgretPlicIrqIdFlashCtrlOpDone = 164,
    TopEgretPlicIrqIdFlashCtrlCorrErr = 165,
    TopEgretPlicIrqIdAccDone = 166,
    TopEgretPlicIrqIdHmacHmacDone = 167,
    TopEgretPlicIrqIdHmacFifoEmpty = 168,
    TopEgretPlicIrqIdHmacHmacErr = 169,
    TopEgretPlicIrqIdKmacKmacDone = 170,
    TopEgretPlicIrqIdKmacFifoEmpty = 171,
    TopEgretPlicIrqIdKmacKmacErr = 172,
    TopEgretPlicIrqIdKeymgrOpDone = 173,
    TopEgretPlicIrqIdCsrngCsCmdReqDone = 174,
    TopEgretPlicIrqIdCsrngCsEntropyReq = 175,
    TopEgretPlicIrqIdCsrngCsHwInstExc = 176,
    TopEgretPlicIrqIdCsrngCsFatalErr = 177,
    TopEgretPlicIrqIdEntropySrcEsEntropyValid = 178,
    TopEgretPlicIrqIdEntropySrcEsHealthTestFailed = 179,
    TopEgretPlicIrqIdEntropySrcEsObserveFifoReady = 180,
    TopEgretPlicIrqIdEntropySrcEsFatalErr = 181,
    TopEgretPlicIrqIdEdn0EdnCmdReqDone = 182,
    TopEgretPlicIrqIdEdn0EdnFatalErr = 183,
    TopEgretPlicIrqIdEdn1EdnCmdReqDone = 184,
    TopEgretPlicIrqIdEdn1EdnFatalErr = 185,
    TopEgretPlicIrqIdCount
  } interrupt_rv_plic_id_e;


  // Enumeration of IO power domains.
  // Only used in ASIC target.
  typedef enum logic [2:0] {
    IoBankVcc = 0,
    IoBankAvcc = 1,
    IoBankVioa = 2,
    IoBankViob = 3,
    IoBankCount = 4
  } pwr_dom_e;

  // Enumeration for MIO signals on the top-level.
  typedef enum int unsigned {
    MioInGpioGpio0 = 0,
    MioInGpioGpio1 = 1,
    MioInGpioGpio2 = 2,
    MioInGpioGpio3 = 3,
    MioInGpioGpio4 = 4,
    MioInGpioGpio5 = 5,
    MioInGpioGpio6 = 6,
    MioInGpioGpio7 = 7,
    MioInGpioGpio8 = 8,
    MioInGpioGpio9 = 9,
    MioInGpioGpio10 = 10,
    MioInGpioGpio11 = 11,
    MioInGpioGpio12 = 12,
    MioInGpioGpio13 = 13,
    MioInGpioGpio14 = 14,
    MioInGpioGpio15 = 15,
    MioInGpioGpio16 = 16,
    MioInGpioGpio17 = 17,
    MioInGpioGpio18 = 18,
    MioInGpioGpio19 = 19,
    MioInGpioGpio20 = 20,
    MioInGpioGpio21 = 21,
    MioInGpioGpio22 = 22,
    MioInGpioGpio23 = 23,
    MioInGpioGpio24 = 24,
    MioInGpioGpio25 = 25,
    MioInGpioGpio26 = 26,
    MioInGpioGpio27 = 27,
    MioInGpioGpio28 = 28,
    MioInGpioGpio29 = 29,
    MioInGpioGpio30 = 30,
    MioInGpioGpio31 = 31,
    MioInI2c0Sda = 32,
    MioInI2c0Scl = 33,
    MioInI2c1Sda = 34,
    MioInI2c1Scl = 35,
    MioInI2c2Sda = 36,
    MioInI2c2Scl = 37,
    MioInSpiHost1Sd0 = 38,
    MioInSpiHost1Sd1 = 39,
    MioInSpiHost1Sd2 = 40,
    MioInSpiHost1Sd3 = 41,
    MioInUart0Rx = 42,
    MioInUart1Rx = 43,
    MioInUart2Rx = 44,
    MioInUart3Rx = 45,
    MioInSpiDeviceTpmCsb = 46,
    MioInFlashMacroWrapperTck = 47,
    MioInFlashMacroWrapperTms = 48,
    MioInFlashMacroWrapperTdi = 49,
    MioInSysrstCtrlAonAcPresent = 50,
    MioInSysrstCtrlAonKey0In = 51,
    MioInSysrstCtrlAonKey1In = 52,
    MioInSysrstCtrlAonKey2In = 53,
    MioInSysrstCtrlAonPwrbIn = 54,
    MioInSysrstCtrlAonLidOpen = 55,
    MioInUsbdevSense = 56,
    MioInCount = 57
  } mio_in_e;

  typedef enum {
    MioOutGpioGpio0 = 0,
    MioOutGpioGpio1 = 1,
    MioOutGpioGpio2 = 2,
    MioOutGpioGpio3 = 3,
    MioOutGpioGpio4 = 4,
    MioOutGpioGpio5 = 5,
    MioOutGpioGpio6 = 6,
    MioOutGpioGpio7 = 7,
    MioOutGpioGpio8 = 8,
    MioOutGpioGpio9 = 9,
    MioOutGpioGpio10 = 10,
    MioOutGpioGpio11 = 11,
    MioOutGpioGpio12 = 12,
    MioOutGpioGpio13 = 13,
    MioOutGpioGpio14 = 14,
    MioOutGpioGpio15 = 15,
    MioOutGpioGpio16 = 16,
    MioOutGpioGpio17 = 17,
    MioOutGpioGpio18 = 18,
    MioOutGpioGpio19 = 19,
    MioOutGpioGpio20 = 20,
    MioOutGpioGpio21 = 21,
    MioOutGpioGpio22 = 22,
    MioOutGpioGpio23 = 23,
    MioOutGpioGpio24 = 24,
    MioOutGpioGpio25 = 25,
    MioOutGpioGpio26 = 26,
    MioOutGpioGpio27 = 27,
    MioOutGpioGpio28 = 28,
    MioOutGpioGpio29 = 29,
    MioOutGpioGpio30 = 30,
    MioOutGpioGpio31 = 31,
    MioOutI2c0Sda = 32,
    MioOutI2c0Scl = 33,
    MioOutI2c1Sda = 34,
    MioOutI2c1Scl = 35,
    MioOutI2c2Sda = 36,
    MioOutI2c2Scl = 37,
    MioOutSpiHost1Sd0 = 38,
    MioOutSpiHost1Sd1 = 39,
    MioOutSpiHost1Sd2 = 40,
    MioOutSpiHost1Sd3 = 41,
    MioOutUart0Tx = 42,
    MioOutUart1Tx = 43,
    MioOutUart2Tx = 44,
    MioOutUart3Tx = 45,
    MioOutPattgenPda0Tx = 46,
    MioOutPattgenPcl0Tx = 47,
    MioOutPattgenPda1Tx = 48,
    MioOutPattgenPcl1Tx = 49,
    MioOutSpiHost1Sck = 50,
    MioOutSpiHost1Csb = 51,
    MioOutFlashMacroWrapperTdo = 52,
    MioOutSensorCtrlAonAstDebugOut0 = 53,
    MioOutSensorCtrlAonAstDebugOut1 = 54,
    MioOutSensorCtrlAonAstDebugOut2 = 55,
    MioOutSensorCtrlAonAstDebugOut3 = 56,
    MioOutSensorCtrlAonAstDebugOut4 = 57,
    MioOutSensorCtrlAonAstDebugOut5 = 58,
    MioOutSensorCtrlAonAstDebugOut6 = 59,
    MioOutSensorCtrlAonAstDebugOut7 = 60,
    MioOutSensorCtrlAonAstDebugOut8 = 61,
    MioOutPwmAonPwm0 = 62,
    MioOutPwmAonPwm1 = 63,
    MioOutPwmAonPwm2 = 64,
    MioOutPwmAonPwm3 = 65,
    MioOutPwmAonPwm4 = 66,
    MioOutPwmAonPwm5 = 67,
    MioOutOtpMacroTest0 = 68,
    MioOutSysrstCtrlAonBatDisable = 69,
    MioOutSysrstCtrlAonKey0Out = 70,
    MioOutSysrstCtrlAonKey1Out = 71,
    MioOutSysrstCtrlAonKey2Out = 72,
    MioOutSysrstCtrlAonPwrbOut = 73,
    MioOutSysrstCtrlAonZ3Wakeup = 74,
    MioOutCount = 75
  } mio_out_e;

  // Enumeration for DIO signals, used on both the top and chip-levels.
  typedef enum int unsigned {
    DioUsbdevUsbDp = 0,
    DioUsbdevUsbDn = 1,
    DioSpiHost0Sd0 = 2,
    DioSpiHost0Sd1 = 3,
    DioSpiHost0Sd2 = 4,
    DioSpiHost0Sd3 = 5,
    DioSpiDeviceSd0 = 6,
    DioSpiDeviceSd1 = 7,
    DioSpiDeviceSd2 = 8,
    DioSpiDeviceSd3 = 9,
    DioSysrstCtrlAonEcRstL = 10,
    DioSysrstCtrlAonFlashWpL = 11,
    DioSpiDeviceSck = 12,
    DioSpiDeviceCsb = 13,
    DioSpiHost0Sck = 14,
    DioSpiHost0Csb = 15,
    DioCount = 16
  } dio_e;

  // Enumeration for the types of pads.
  typedef enum {
    MioPad,
    DioPad
  } pad_type_e;

  // Raw MIO/DIO input array indices on chip-level.
  // TODO: Does not account for target specific stubbed/added pads.
  // Need to make a target-specific package for those.
  typedef enum int unsigned {
    MioPadIoa0 = 0,
    MioPadIoa1 = 1,
    MioPadIoa2 = 2,
    MioPadIoa3 = 3,
    MioPadIoa4 = 4,
    MioPadIoa5 = 5,
    MioPadIoa6 = 6,
    MioPadIoa7 = 7,
    MioPadIoa8 = 8,
    MioPadIob0 = 9,
    MioPadIob1 = 10,
    MioPadIob2 = 11,
    MioPadIob3 = 12,
    MioPadIob4 = 13,
    MioPadIob5 = 14,
    MioPadIob6 = 15,
    MioPadIob7 = 16,
    MioPadIob8 = 17,
    MioPadIob9 = 18,
    MioPadIob10 = 19,
    MioPadIob11 = 20,
    MioPadIob12 = 21,
    MioPadIoc0 = 22,
    MioPadIoc1 = 23,
    MioPadIoc2 = 24,
    MioPadIoc3 = 25,
    MioPadIoc4 = 26,
    MioPadIoc5 = 27,
    MioPadIoc6 = 28,
    MioPadIoc7 = 29,
    MioPadIoc8 = 30,
    MioPadIoc9 = 31,
    MioPadIoc10 = 32,
    MioPadIoc11 = 33,
    MioPadIoc12 = 34,
    MioPadIor0 = 35,
    MioPadIor1 = 36,
    MioPadIor2 = 37,
    MioPadIor3 = 38,
    MioPadIor4 = 39,
    MioPadIor5 = 40,
    MioPadIor6 = 41,
    MioPadIor7 = 42,
    MioPadIor10 = 43,
    MioPadIor11 = 44,
    MioPadIor12 = 45,
    MioPadIor13 = 46,
    MioPadCount
  } mio_pad_e;

  typedef enum int unsigned {
    DioPadPorN = 0,
    DioPadUsbP = 1,
    DioPadUsbN = 2,
    DioPadCc1 = 3,
    DioPadCc2 = 4,
    DioPadFlashTestVolt = 5,
    DioPadFlashTestMode0 = 6,
    DioPadFlashTestMode1 = 7,
    DioPadOtpExtVolt = 8,
    DioPadSpiHostD0 = 9,
    DioPadSpiHostD1 = 10,
    DioPadSpiHostD2 = 11,
    DioPadSpiHostD3 = 12,
    DioPadSpiHostClk = 13,
    DioPadSpiHostCsL = 14,
    DioPadSpiDevD0 = 15,
    DioPadSpiDevD1 = 16,
    DioPadSpiDevD2 = 17,
    DioPadSpiDevD3 = 18,
    DioPadSpiDevClk = 19,
    DioPadSpiDevCsL = 20,
    DioPadIor8 = 21,
    DioPadIor9 = 22,
    DioPadCount
  } dio_pad_e;

  // List of peripheral instantiated in this chip.
  typedef enum {
    PeripheralAcc,
    PeripheralAdcCtrlAon,
    PeripheralAes,
    PeripheralAlertHandler,
    PeripheralAonTimerAon,
    PeripheralAst,
    PeripheralClkmgrAon,
    PeripheralCsrng,
    PeripheralEdn0,
    PeripheralEdn1,
    PeripheralEntropySrc,
    PeripheralFlashCtrl,
    PeripheralFlashMacroWrapper,
    PeripheralGpio,
    PeripheralHmac,
    PeripheralI2c0,
    PeripheralI2c1,
    PeripheralI2c2,
    PeripheralKeymgr,
    PeripheralKmac,
    PeripheralLcCtrl,
    PeripheralOtpCtrl,
    PeripheralOtpMacro,
    PeripheralPattgen,
    PeripheralPinmuxAon,
    PeripheralPwmAon,
    PeripheralPwrmgrAon,
    PeripheralRomCtrl,
    PeripheralRstmgrAon,
    PeripheralRvCoreIbex,
    PeripheralRvDm,
    PeripheralRvPlic,
    PeripheralRvTimer,
    PeripheralSensorCtrlAon,
    PeripheralSpiDevice,
    PeripheralSpiHost0,
    PeripheralSpiHost1,
    PeripheralSramCtrlMain,
    PeripheralSramCtrlRetAon,
    PeripheralSysrstCtrlAon,
    PeripheralUart0,
    PeripheralUart1,
    PeripheralUart2,
    PeripheralUart3,
    PeripheralUsbdev,
    PeripheralCount
  } peripheral_e;

  // MMIO Region
  //
  parameter int unsigned TOP_EGRET_MMIO_BASE_ADDR = 32'h40000000;
  parameter int unsigned TOP_EGRET_MMIO_SIZE_BYTES = 32'h10000000;

  // TODO: Enumeration for PLIC Interrupt source peripheral.

// MACROs for AST analog simulation support
`ifdef ANALOGSIM
  `define INOUT_AI input ast_pkg::awire_t
  `define INOUT_AO output ast_pkg::awire_t
`else
  `define INOUT_AI inout
  `define INOUT_AO inout
`endif

endpackage
