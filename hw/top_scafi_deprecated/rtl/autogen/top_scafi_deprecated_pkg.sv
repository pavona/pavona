// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// ------------------- W A R N I N G: A U T O - G E N E R A T E D   C O D E !! -------------------//
// PLEASE DO NOT HAND-EDIT THIS FILE. IT HAS BEEN AUTO-GENERATED WITH THE FOLLOWING COMMAND:
//
// util/topgen.py -t hw/top_scafi_deprecated/data/top_scafi_deprecated.hjson
//                -o hw/top_scafi_deprecated/

package top_scafi_deprecated_pkg;
  /**
   * Peripheral base address for uart0 in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_UART0_BASE_ADDR = 32'h40000000;

  /**
   * Peripheral size in bytes for uart0 in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_UART0_SIZE_BYTES = 32'h40;

  /**
   * Peripheral base address for uart1 in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_UART1_BASE_ADDR = 32'h40010000;

  /**
   * Peripheral size in bytes for uart1 in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_UART1_SIZE_BYTES = 32'h40;

  /**
   * Peripheral base address for gpio in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_GPIO_BASE_ADDR = 32'h40040000;

  /**
   * Peripheral size in bytes for gpio in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_GPIO_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for spi_device in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_SPI_DEVICE_BASE_ADDR = 32'h40050000;

  /**
   * Peripheral size in bytes for spi_device in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_SPI_DEVICE_SIZE_BYTES = 32'h2000;

  /**
   * Peripheral base address for spi_host0 in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_SPI_HOST0_BASE_ADDR = 32'h40060000;

  /**
   * Peripheral size in bytes for spi_host0 in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_SPI_HOST0_SIZE_BYTES = 32'h40;

  /**
   * Peripheral base address for rv_timer in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_RV_TIMER_BASE_ADDR = 32'h40100000;

  /**
   * Peripheral size in bytes for rv_timer in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_RV_TIMER_SIZE_BYTES = 32'h200;

  /**
   * Peripheral base address for usbdev in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_USBDEV_BASE_ADDR = 32'h40320000;

  /**
   * Peripheral size in bytes for usbdev in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_USBDEV_SIZE_BYTES = 32'h1000;

  /**
   * Peripheral base address for pwrmgr_aon in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_PWRMGR_AON_BASE_ADDR = 32'h40400000;

  /**
   * Peripheral size in bytes for pwrmgr_aon in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_PWRMGR_AON_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for rstmgr_aon in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_RSTMGR_AON_BASE_ADDR = 32'h40410000;

  /**
   * Peripheral size in bytes for rstmgr_aon in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_RSTMGR_AON_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for clkmgr_aon in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_CLKMGR_AON_BASE_ADDR = 32'h40420000;

  /**
   * Peripheral size in bytes for clkmgr_aon in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_CLKMGR_AON_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for pinmux_aon in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_PINMUX_AON_BASE_ADDR = 32'h40460000;

  /**
   * Peripheral size in bytes for pinmux_aon in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_PINMUX_AON_SIZE_BYTES = 32'h1000;

  /**
   * Peripheral base address for aon_timer_aon in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_AON_TIMER_AON_BASE_ADDR = 32'h40470000;

  /**
   * Peripheral size in bytes for aon_timer_aon in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_AON_TIMER_AON_SIZE_BYTES = 32'h40;

  /**
   * Peripheral base address for ast in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_AST_BASE_ADDR = 32'h40480000;

  /**
   * Peripheral size in bytes for ast in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_AST_SIZE_BYTES = 32'h400;

  /**
   * Peripheral base address for core device on flash_ctrl in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_FLASH_CTRL_CORE_BASE_ADDR = 32'h41000000;

  /**
   * Peripheral size in bytes for core device on flash_ctrl in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_FLASH_CTRL_CORE_SIZE_BYTES = 32'h200;

  /**
   * Peripheral base address for flash_macro_wrapper in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_FLASH_MACRO_WRAPPER_BASE_ADDR = 32'h41008000;

  /**
   * Peripheral size in bytes for flash_macro_wrapper in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_FLASH_MACRO_WRAPPER_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for rv_plic in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_RV_PLIC_BASE_ADDR = 32'h48000000;

  /**
   * Peripheral size in bytes for rv_plic in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_RV_PLIC_SIZE_BYTES = 32'h8000000;

  /**
   * Peripheral base address for aes in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_AES_BASE_ADDR = 32'h41100000;

  /**
   * Peripheral size in bytes for aes in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_AES_SIZE_BYTES = 32'h100;

  /**
   * Peripheral base address for regs device on sram_ctrl_main in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_SRAM_CTRL_MAIN_REGS_BASE_ADDR = 32'h411C0000;

  /**
   * Peripheral size in bytes for regs device on sram_ctrl_main in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_SRAM_CTRL_MAIN_REGS_SIZE_BYTES = 32'h40;

  /**
   * Peripheral base address for regs device on rom_ctrl in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_ROM_CTRL_REGS_BASE_ADDR = 32'h411E0000;

  /**
   * Peripheral size in bytes for regs device on rom_ctrl in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_ROM_CTRL_REGS_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for cfg device on rv_core_ibex in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_RV_CORE_IBEX_CFG_BASE_ADDR = 32'h411F0000;

  /**
   * Peripheral size in bytes for cfg device on rv_core_ibex in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_RV_CORE_IBEX_CFG_SIZE_BYTES = 32'h100;

  /**
   * Memory base address for mem memory on flash_ctrl in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_FLASH_CTRL_MEM_BASE_ADDR = 32'h20000000;

  /**
   * Memory size for mem memory on flash_ctrl in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_FLASH_CTRL_MEM_SIZE_BYTES = 32'h10000;

  /**
   * Memory base address for ram memory on sram_ctrl_main in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_SRAM_CTRL_MAIN_RAM_BASE_ADDR = 32'h10000000;

  /**
   * Memory size for ram memory on sram_ctrl_main in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_SRAM_CTRL_MAIN_RAM_SIZE_BYTES = 32'h20000;

  /**
   * Memory base address for rom memory on rom_ctrl in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_ROM_CTRL_ROM_BASE_ADDR = 32'h8000;

  /**
   * Memory size for rom memory on rom_ctrl in top scafi_deprecated.
   */
  parameter int unsigned TOP_SCAFI_DEPRECATED_ROM_CTRL_ROM_SIZE_BYTES = 32'h8000;


  // Number of scafi_deprecated outgoing alerts
  parameter int unsigned NOutgoingAlertsScafi_deprecated = 28;

  // Number of LPGs for outgoing alert group scafi_deprecated
  parameter int unsigned NOutgoingLpgsScafi_deprecated = 13;

  // Enumeration of scafi_deprecated outgoing alert modules
  typedef enum int unsigned {
    TopScafiDeprecatedAlertPeripheralUart0 = 0,
    TopScafiDeprecatedAlertPeripheralUart1 = 1,
    TopScafiDeprecatedAlertPeripheralGpio = 2,
    TopScafiDeprecatedAlertPeripheralSpiDevice = 3,
    TopScafiDeprecatedAlertPeripheralSpiHost0 = 4,
    TopScafiDeprecatedAlertPeripheralRvTimer = 5,
    TopScafiDeprecatedAlertPeripheralUsbdev = 6,
    TopScafiDeprecatedAlertPeripheralPwrmgrAon = 7,
    TopScafiDeprecatedAlertPeripheralRstmgrAon = 8,
    TopScafiDeprecatedAlertPeripheralClkmgrAon = 9,
    TopScafiDeprecatedAlertPeripheralPinmuxAon = 10,
    TopScafiDeprecatedAlertPeripheralAonTimerAon = 11,
    TopScafiDeprecatedAlertPeripheralFlashCtrl = 12,
    TopScafiDeprecatedAlertPeripheralRvPlic = 13,
    TopScafiDeprecatedAlertPeripheralAes = 14,
    TopScafiDeprecatedAlertPeripheralSramCtrlMain = 15,
    TopScafiDeprecatedAlertPeripheralRomCtrl = 16,
    TopScafiDeprecatedAlertPeripheralRvCoreIbex = 17,
    TopScafiDeprecatedOutgoingAlertScafiDeprecatedPeripheralCount
  } outgoing_alert_scafi_deprecated_peripheral_e;

  // Enumeration of scafi_deprecated outgoing alerts
  typedef enum int unsigned {
    TopScafiDeprecatedAlertIdUart0FatalFault = 0,
    TopScafiDeprecatedAlertIdUart1FatalFault = 1,
    TopScafiDeprecatedAlertIdGpioFatalFault = 2,
    TopScafiDeprecatedAlertIdSpiDeviceFatalFault = 3,
    TopScafiDeprecatedAlertIdSpiHost0FatalFault = 4,
    TopScafiDeprecatedAlertIdRvTimerFatalFault = 5,
    TopScafiDeprecatedAlertIdUsbdevFatalFault = 6,
    TopScafiDeprecatedAlertIdPwrmgrAonFatalFault = 7,
    TopScafiDeprecatedAlertIdRstmgrAonFatalFault = 8,
    TopScafiDeprecatedAlertIdRstmgrAonFatalCnstyFault = 9,
    TopScafiDeprecatedAlertIdClkmgrAonRecovFault = 10,
    TopScafiDeprecatedAlertIdClkmgrAonFatalFault = 11,
    TopScafiDeprecatedAlertIdPinmuxAonFatalFault = 12,
    TopScafiDeprecatedAlertIdAonTimerAonFatalFault = 13,
    TopScafiDeprecatedAlertIdFlashCtrlRecovErr = 14,
    TopScafiDeprecatedAlertIdFlashCtrlFatalStdErr = 15,
    TopScafiDeprecatedAlertIdFlashCtrlFatalErr = 16,
    TopScafiDeprecatedAlertIdFlashCtrlFatalPrimFlashAlert = 17,
    TopScafiDeprecatedAlertIdFlashCtrlRecovPrimFlashAlert = 18,
    TopScafiDeprecatedAlertIdRvPlicFatalFault = 19,
    TopScafiDeprecatedAlertIdAesRecovCtrlUpdateErr = 20,
    TopScafiDeprecatedAlertIdAesFatalFault = 21,
    TopScafiDeprecatedAlertIdSramCtrlMainFatalError = 22,
    TopScafiDeprecatedAlertIdRomCtrlFatal = 23,
    TopScafiDeprecatedAlertIdRvCoreIbexFatalSwErr = 24,
    TopScafiDeprecatedAlertIdRvCoreIbexRecovSwErr = 25,
    TopScafiDeprecatedAlertIdRvCoreIbexFatalHwErr = 26,
    TopScafiDeprecatedAlertIdRvCoreIbexRecovHwErr = 27,
    TopScafiDeprecatedOutgoingAlertScafiDeprecatedIdCount
  } outgoing_alert_scafi_deprecated_id_e;

  // Enumeration of scafi_deprecated outgoing alerts AsyncOn configuration
  parameter logic [NOutgoingAlertsScafi_deprecated-1:0] AsyncOnOutgoingAlertScafi_deprecated = {
    1'b1,
    1'b1,
    1'b1,
    1'b1,
    1'b1,
    1'b1,
    1'b1,
    1'b1,
    1'b1,
    1'b1,
    1'b1,
    1'b1,
    1'b1,
    1'b1,
    1'b1,
    1'b1,
    1'b1,
    1'b1,
    1'b1,
    1'b1,
    1'b1,
    1'b1,
    1'b1,
    1'b1,
    1'b1,
    1'b1,
    1'b1,
    1'b1
  };

  // Enumeration of interrupts
  typedef enum int unsigned {
    TopScafiDeprecatedPlicIrqIdNone = 0,
    TopScafiDeprecatedPlicIrqIdUart0TxWatermark = 1,
    TopScafiDeprecatedPlicIrqIdUart0RxWatermark = 2,
    TopScafiDeprecatedPlicIrqIdUart0TxDone = 3,
    TopScafiDeprecatedPlicIrqIdUart0RxOverflow = 4,
    TopScafiDeprecatedPlicIrqIdUart0RxFrameErr = 5,
    TopScafiDeprecatedPlicIrqIdUart0RxBreakErr = 6,
    TopScafiDeprecatedPlicIrqIdUart0RxTimeout = 7,
    TopScafiDeprecatedPlicIrqIdUart0RxParityErr = 8,
    TopScafiDeprecatedPlicIrqIdUart0TxEmpty = 9,
    TopScafiDeprecatedPlicIrqIdUart1TxWatermark = 10,
    TopScafiDeprecatedPlicIrqIdUart1RxWatermark = 11,
    TopScafiDeprecatedPlicIrqIdUart1TxDone = 12,
    TopScafiDeprecatedPlicIrqIdUart1RxOverflow = 13,
    TopScafiDeprecatedPlicIrqIdUart1RxFrameErr = 14,
    TopScafiDeprecatedPlicIrqIdUart1RxBreakErr = 15,
    TopScafiDeprecatedPlicIrqIdUart1RxTimeout = 16,
    TopScafiDeprecatedPlicIrqIdUart1RxParityErr = 17,
    TopScafiDeprecatedPlicIrqIdUart1TxEmpty = 18,
    TopScafiDeprecatedPlicIrqIdGpioGpio0 = 19,
    TopScafiDeprecatedPlicIrqIdGpioGpio1 = 20,
    TopScafiDeprecatedPlicIrqIdGpioGpio2 = 21,
    TopScafiDeprecatedPlicIrqIdGpioGpio3 = 22,
    TopScafiDeprecatedPlicIrqIdGpioGpio4 = 23,
    TopScafiDeprecatedPlicIrqIdGpioGpio5 = 24,
    TopScafiDeprecatedPlicIrqIdGpioGpio6 = 25,
    TopScafiDeprecatedPlicIrqIdGpioGpio7 = 26,
    TopScafiDeprecatedPlicIrqIdGpioGpio8 = 27,
    TopScafiDeprecatedPlicIrqIdGpioGpio9 = 28,
    TopScafiDeprecatedPlicIrqIdGpioGpio10 = 29,
    TopScafiDeprecatedPlicIrqIdGpioGpio11 = 30,
    TopScafiDeprecatedPlicIrqIdGpioGpio12 = 31,
    TopScafiDeprecatedPlicIrqIdGpioGpio13 = 32,
    TopScafiDeprecatedPlicIrqIdGpioGpio14 = 33,
    TopScafiDeprecatedPlicIrqIdGpioGpio15 = 34,
    TopScafiDeprecatedPlicIrqIdGpioGpio16 = 35,
    TopScafiDeprecatedPlicIrqIdGpioGpio17 = 36,
    TopScafiDeprecatedPlicIrqIdGpioGpio18 = 37,
    TopScafiDeprecatedPlicIrqIdGpioGpio19 = 38,
    TopScafiDeprecatedPlicIrqIdGpioGpio20 = 39,
    TopScafiDeprecatedPlicIrqIdGpioGpio21 = 40,
    TopScafiDeprecatedPlicIrqIdGpioGpio22 = 41,
    TopScafiDeprecatedPlicIrqIdGpioGpio23 = 42,
    TopScafiDeprecatedPlicIrqIdGpioGpio24 = 43,
    TopScafiDeprecatedPlicIrqIdGpioGpio25 = 44,
    TopScafiDeprecatedPlicIrqIdGpioGpio26 = 45,
    TopScafiDeprecatedPlicIrqIdGpioGpio27 = 46,
    TopScafiDeprecatedPlicIrqIdGpioGpio28 = 47,
    TopScafiDeprecatedPlicIrqIdGpioGpio29 = 48,
    TopScafiDeprecatedPlicIrqIdGpioGpio30 = 49,
    TopScafiDeprecatedPlicIrqIdGpioGpio31 = 50,
    TopScafiDeprecatedPlicIrqIdSpiDeviceUploadCmdfifoNotEmpty = 51,
    TopScafiDeprecatedPlicIrqIdSpiDeviceUploadPayloadNotEmpty = 52,
    TopScafiDeprecatedPlicIrqIdSpiDeviceUploadPayloadOverflow = 53,
    TopScafiDeprecatedPlicIrqIdSpiDeviceReadbufWatermark = 54,
    TopScafiDeprecatedPlicIrqIdSpiDeviceReadbufFlip = 55,
    TopScafiDeprecatedPlicIrqIdSpiDeviceTpmHeaderNotEmpty = 56,
    TopScafiDeprecatedPlicIrqIdSpiDeviceTpmRdfifoCmdEnd = 57,
    TopScafiDeprecatedPlicIrqIdSpiDeviceTpmRdfifoDrop = 58,
    TopScafiDeprecatedPlicIrqIdSpiHost0Error = 59,
    TopScafiDeprecatedPlicIrqIdSpiHost0SpiEvent = 60,
    TopScafiDeprecatedPlicIrqIdUsbdevPktReceived = 61,
    TopScafiDeprecatedPlicIrqIdUsbdevPktSent = 62,
    TopScafiDeprecatedPlicIrqIdUsbdevDisconnected = 63,
    TopScafiDeprecatedPlicIrqIdUsbdevHostLost = 64,
    TopScafiDeprecatedPlicIrqIdUsbdevLinkReset = 65,
    TopScafiDeprecatedPlicIrqIdUsbdevLinkSuspend = 66,
    TopScafiDeprecatedPlicIrqIdUsbdevLinkResume = 67,
    TopScafiDeprecatedPlicIrqIdUsbdevAvOutEmpty = 68,
    TopScafiDeprecatedPlicIrqIdUsbdevRxFull = 69,
    TopScafiDeprecatedPlicIrqIdUsbdevAvOverflow = 70,
    TopScafiDeprecatedPlicIrqIdUsbdevLinkInErr = 71,
    TopScafiDeprecatedPlicIrqIdUsbdevRxCrcErr = 72,
    TopScafiDeprecatedPlicIrqIdUsbdevRxPidErr = 73,
    TopScafiDeprecatedPlicIrqIdUsbdevRxBitstuffErr = 74,
    TopScafiDeprecatedPlicIrqIdUsbdevFrame = 75,
    TopScafiDeprecatedPlicIrqIdUsbdevPowered = 76,
    TopScafiDeprecatedPlicIrqIdUsbdevLinkOutErr = 77,
    TopScafiDeprecatedPlicIrqIdUsbdevAvSetupEmpty = 78,
    TopScafiDeprecatedPlicIrqIdPwrmgrAonWakeup = 79,
    TopScafiDeprecatedPlicIrqIdAonTimerAonWkupTimerExpired = 80,
    TopScafiDeprecatedPlicIrqIdAonTimerAonWdogTimerBark = 81,
    TopScafiDeprecatedPlicIrqIdFlashCtrlProgEmpty = 82,
    TopScafiDeprecatedPlicIrqIdFlashCtrlProgLvl = 83,
    TopScafiDeprecatedPlicIrqIdFlashCtrlRdFull = 84,
    TopScafiDeprecatedPlicIrqIdFlashCtrlRdLvl = 85,
    TopScafiDeprecatedPlicIrqIdFlashCtrlOpDone = 86,
    TopScafiDeprecatedPlicIrqIdFlashCtrlCorrErr = 87,
    TopScafiDeprecatedPlicIrqIdCount
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
    MioInUart0Rx = 32,
    MioInUart1Rx = 33,
    MioInUsbdevSense = 34,
    MioInCount = 35
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
    MioOutUart0Tx = 32,
    MioOutUart1Tx = 33,
    MioOutCount = 34
  } mio_out_e;

  // Enumeration for DIO signals, used on both the top and chip-levels.
  typedef enum int unsigned {
    DioSpiHost0Sd0 = 0,
    DioSpiHost0Sd1 = 1,
    DioSpiHost0Sd2 = 2,
    DioSpiHost0Sd3 = 3,
    DioSpiDeviceSd0 = 4,
    DioSpiDeviceSd1 = 5,
    DioSpiDeviceSd2 = 6,
    DioSpiDeviceSd3 = 7,
    DioUsbdevUsbDp = 8,
    DioUsbdevUsbDn = 9,
    DioSpiDeviceSck = 10,
    DioSpiDeviceCsb = 11,
    DioSpiHost0Sck = 12,
    DioSpiHost0Csb = 13,
    DioCount = 14
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
    DioPadSpiHostD0 = 8,
    DioPadSpiHostD1 = 9,
    DioPadSpiHostD2 = 10,
    DioPadSpiHostD3 = 11,
    DioPadSpiHostClk = 12,
    DioPadSpiHostCsL = 13,
    DioPadSpiDevD0 = 14,
    DioPadSpiDevD1 = 15,
    DioPadSpiDevD2 = 16,
    DioPadSpiDevD3 = 17,
    DioPadSpiDevClk = 18,
    DioPadSpiDevCsL = 19,
    DioPadCount
  } dio_pad_e;

  // List of peripheral instantiated in this chip.
  typedef enum {
    PeripheralAes,
    PeripheralAonTimerAon,
    PeripheralAst,
    PeripheralClkmgrAon,
    PeripheralFlashCtrl,
    PeripheralFlashMacroWrapper,
    PeripheralGpio,
    PeripheralPinmuxAon,
    PeripheralPwrmgrAon,
    PeripheralRomCtrl,
    PeripheralRstmgrAon,
    PeripheralRvCoreIbex,
    PeripheralRvPlic,
    PeripheralRvTimer,
    PeripheralSpiDevice,
    PeripheralSpiHost0,
    PeripheralSramCtrlMain,
    PeripheralUart0,
    PeripheralUart1,
    PeripheralUsbdev,
    PeripheralCount
  } peripheral_e;

  // MMIO Region
  //
  parameter int unsigned TOP_SCAFI_DEPRECATED_MMIO_BASE_ADDR = 32'h40000000;
  parameter int unsigned TOP_SCAFI_DEPRECATED_MMIO_SIZE_BYTES = 32'h10000000;

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
