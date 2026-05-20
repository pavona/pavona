// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// ------------------- W A R N I N G: A U T O - G E N E R A T E D   C O D E !! -------------------//
// PLEASE DO NOT HAND-EDIT THIS FILE. IT HAS BEEN AUTO-GENERATED WITH THE FOLLOWING COMMAND:
//
// util/topgen.py -t hw/top_dragonfly/data/top_dragonfly.hjson
//                -o hw/top_dragonfly/

package top_dragonfly_pkg;
  /**
   * Peripheral base address for uart0 in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_UART0_BASE_ADDR = 32'h30010000;

  /**
   * Peripheral size in bytes for uart0 in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_UART0_SIZE_BYTES = 32'h40;

  /**
   * Peripheral base address for gpio in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_GPIO_BASE_ADDR = 32'h30000000;

  /**
   * Peripheral size in bytes for gpio in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_GPIO_SIZE_BYTES = 32'h100;

  /**
   * Peripheral base address for spi_device in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_SPI_DEVICE_BASE_ADDR = 32'h30310000;

  /**
   * Peripheral size in bytes for spi_device in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_SPI_DEVICE_SIZE_BYTES = 32'h2000;

  /**
   * Peripheral base address for i2c0 in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_I2C0_BASE_ADDR = 32'h30080000;

  /**
   * Peripheral size in bytes for i2c0 in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_I2C0_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for rv_timer in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_RV_TIMER_BASE_ADDR = 32'h30100000;

  /**
   * Peripheral size in bytes for rv_timer in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_RV_TIMER_SIZE_BYTES = 32'h200;

  /**
   * Peripheral base address for core device on otp_ctrl in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_OTP_CTRL_CORE_BASE_ADDR = 32'h30130000;

  /**
   * Peripheral size in bytes for core device on otp_ctrl in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_OTP_CTRL_CORE_SIZE_BYTES = 32'h10000;

  /**
   * Peripheral base address for prim device on otp_macro in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_OTP_MACRO_PRIM_BASE_ADDR = 32'h30140000;

  /**
   * Peripheral size in bytes for prim device on otp_macro in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_OTP_MACRO_PRIM_SIZE_BYTES = 32'h20;

  /**
   * Peripheral base address for regs device on lc_ctrl in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_LC_CTRL_REGS_BASE_ADDR = 32'h30150000;

  /**
   * Peripheral size in bytes for regs device on lc_ctrl in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_LC_CTRL_REGS_SIZE_BYTES = 32'h100;

  /**
   * Peripheral base address for alert_handler in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_ALERT_HANDLER_BASE_ADDR = 32'h30160000;

  /**
   * Peripheral size in bytes for alert_handler in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_ALERT_HANDLER_SIZE_BYTES = 32'h800;

  /**
   * Peripheral base address for spi_host0 in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_SPI_HOST0_BASE_ADDR = 32'h30300000;

  /**
   * Peripheral size in bytes for spi_host0 in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_SPI_HOST0_SIZE_BYTES = 32'h40;

  /**
   * Peripheral base address for pwrmgr_aon in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_PWRMGR_AON_BASE_ADDR = 32'h30400000;

  /**
   * Peripheral size in bytes for pwrmgr_aon in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_PWRMGR_AON_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for rstmgr_aon in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_RSTMGR_AON_BASE_ADDR = 32'h30410000;

  /**
   * Peripheral size in bytes for rstmgr_aon in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_RSTMGR_AON_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for clkmgr_aon in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_CLKMGR_AON_BASE_ADDR = 32'h30420000;

  /**
   * Peripheral size in bytes for clkmgr_aon in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_CLKMGR_AON_SIZE_BYTES = 32'h40;

  /**
   * Peripheral base address for pinmux_aon in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_PINMUX_AON_BASE_ADDR = 32'h30460000;

  /**
   * Peripheral size in bytes for pinmux_aon in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_PINMUX_AON_SIZE_BYTES = 32'h800;

  /**
   * Peripheral base address for aon_timer_aon in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_AON_TIMER_AON_BASE_ADDR = 32'h30470000;

  /**
   * Peripheral size in bytes for aon_timer_aon in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_AON_TIMER_AON_SIZE_BYTES = 32'h40;

  /**
   * Peripheral base address for ast in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_AST_BASE_ADDR = 32'h30480000;

  /**
   * Peripheral size in bytes for ast in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_AST_SIZE_BYTES = 32'h400;

  /**
   * Peripheral base address for core device on soc_proxy in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_SOC_PROXY_CORE_BASE_ADDR = 32'h22030000;

  /**
   * Peripheral size in bytes for core device on soc_proxy in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_SOC_PROXY_CORE_SIZE_BYTES = 32'h8;

  /**
   * Peripheral base address for regs device on sram_ctrl_ret_aon in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_SRAM_CTRL_RET_AON_REGS_BASE_ADDR = 32'h30500000;

  /**
   * Peripheral size in bytes for regs device on sram_ctrl_ret_aon in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_SRAM_CTRL_RET_AON_REGS_SIZE_BYTES = 32'h40;

  /**
   * Peripheral base address for regs device on rv_dm in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_RV_DM_REGS_BASE_ADDR = 32'h21200000;

  /**
   * Peripheral size in bytes for regs device on rv_dm in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_RV_DM_REGS_SIZE_BYTES = 32'h10;

  /**
   * Peripheral base address for mem device on rv_dm in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_RV_DM_MEM_BASE_ADDR = 32'h40000;

  /**
   * Peripheral size in bytes for mem device on rv_dm in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_RV_DM_MEM_SIZE_BYTES = 32'h1000;

  /**
   * Peripheral base address for rv_plic in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_RV_PLIC_BASE_ADDR = 32'h28000000;

  /**
   * Peripheral size in bytes for rv_plic in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_RV_PLIC_SIZE_BYTES = 32'h8000000;

  /**
   * Peripheral base address for acc in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_ACC_BASE_ADDR = 32'h22100000;

  /**
   * Peripheral size in bytes for acc in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_ACC_SIZE_BYTES = 32'h20000;

  /**
   * Peripheral base address for aes in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_AES_BASE_ADDR = 32'h21100000;

  /**
   * Peripheral size in bytes for aes in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_AES_SIZE_BYTES = 32'h100;

  /**
   * Peripheral base address for hmac in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_HMAC_BASE_ADDR = 32'h21110000;

  /**
   * Peripheral size in bytes for hmac in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_HMAC_SIZE_BYTES = 32'h2000;

  /**
   * Peripheral base address for kmac in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_KMAC_BASE_ADDR = 32'h21120000;

  /**
   * Peripheral size in bytes for kmac in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_KMAC_SIZE_BYTES = 32'h1000;

  /**
   * Peripheral base address for keymgr_dpe in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_KEYMGR_DPE_BASE_ADDR = 32'h21140000;

  /**
   * Peripheral size in bytes for keymgr_dpe in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_KEYMGR_DPE_SIZE_BYTES = 32'h100;

  /**
   * Peripheral base address for csrng in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_CSRNG_BASE_ADDR = 32'h21150000;

  /**
   * Peripheral size in bytes for csrng in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_CSRNG_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for entropy_src in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_ENTROPY_SRC_BASE_ADDR = 32'h21160000;

  /**
   * Peripheral size in bytes for entropy_src in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_ENTROPY_SRC_SIZE_BYTES = 32'h100;

  /**
   * Peripheral base address for edn0 in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_EDN0_BASE_ADDR = 32'h21170000;

  /**
   * Peripheral size in bytes for edn0 in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_EDN0_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for edn1 in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_EDN1_BASE_ADDR = 32'h21180000;

  /**
   * Peripheral size in bytes for edn1 in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_EDN1_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for regs device on sram_ctrl_main in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_SRAM_CTRL_MAIN_REGS_BASE_ADDR = 32'h211C0000;

  /**
   * Peripheral size in bytes for regs device on sram_ctrl_main in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_SRAM_CTRL_MAIN_REGS_SIZE_BYTES = 32'h40;

  /**
   * Peripheral base address for regs device on sram_ctrl_mbox in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_SRAM_CTRL_MBOX_REGS_BASE_ADDR = 32'h211D0000;

  /**
   * Peripheral size in bytes for regs device on sram_ctrl_mbox in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_SRAM_CTRL_MBOX_REGS_SIZE_BYTES = 32'h40;

  /**
   * Peripheral base address for regs device on rom_ctrl0 in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_ROM_CTRL0_REGS_BASE_ADDR = 32'h211E0000;

  /**
   * Peripheral size in bytes for regs device on rom_ctrl0 in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_ROM_CTRL0_REGS_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for regs device on rom_ctrl1 in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_ROM_CTRL1_REGS_BASE_ADDR = 32'h211E1000;

  /**
   * Peripheral size in bytes for regs device on rom_ctrl1 in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_ROM_CTRL1_REGS_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for dma in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_DMA_BASE_ADDR = 32'h22010000;

  /**
   * Peripheral size in bytes for dma in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_DMA_SIZE_BYTES = 32'h200;

  /**
   * Peripheral base address for core device on mbx0 in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_MBX0_CORE_BASE_ADDR = 32'h22000000;

  /**
   * Peripheral size in bytes for core device on mbx0 in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_MBX0_CORE_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for core device on mbx1 in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_MBX1_CORE_BASE_ADDR = 32'h22000100;

  /**
   * Peripheral size in bytes for core device on mbx1 in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_MBX1_CORE_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for core device on mbx2 in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_MBX2_CORE_BASE_ADDR = 32'h22000200;

  /**
   * Peripheral size in bytes for core device on mbx2 in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_MBX2_CORE_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for core device on mbx3 in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_MBX3_CORE_BASE_ADDR = 32'h22000300;

  /**
   * Peripheral size in bytes for core device on mbx3 in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_MBX3_CORE_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for core device on mbx4 in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_MBX4_CORE_BASE_ADDR = 32'h22000400;

  /**
   * Peripheral size in bytes for core device on mbx4 in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_MBX4_CORE_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for core device on mbx5 in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_MBX5_CORE_BASE_ADDR = 32'h22000500;

  /**
   * Peripheral size in bytes for core device on mbx5 in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_MBX5_CORE_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for core device on mbx6 in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_MBX6_CORE_BASE_ADDR = 32'h22000600;

  /**
   * Peripheral size in bytes for core device on mbx6 in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_MBX6_CORE_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for core device on mbx_jtag in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_MBX_JTAG_CORE_BASE_ADDR = 32'h22000800;

  /**
   * Peripheral size in bytes for core device on mbx_jtag in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_MBX_JTAG_CORE_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for core device on mbx_pcie0 in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_MBX_PCIE0_CORE_BASE_ADDR = 32'h22040000;

  /**
   * Peripheral size in bytes for core device on mbx_pcie0 in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_MBX_PCIE0_CORE_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for core device on mbx_pcie1 in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_MBX_PCIE1_CORE_BASE_ADDR = 32'h22040100;

  /**
   * Peripheral size in bytes for core device on mbx_pcie1 in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_MBX_PCIE1_CORE_SIZE_BYTES = 32'h80;

  /**
   * Peripheral base address for core device on soc_dbg_ctrl in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_SOC_DBG_CTRL_CORE_BASE_ADDR = 32'h30170000;

  /**
   * Peripheral size in bytes for core device on soc_dbg_ctrl in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_SOC_DBG_CTRL_CORE_SIZE_BYTES = 32'h20;

  /**
   * Peripheral base address for cfg device on rv_core_ibex in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_RV_CORE_IBEX_CFG_BASE_ADDR = 32'h211F0000;

  /**
   * Peripheral size in bytes for cfg device on rv_core_ibex in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_RV_CORE_IBEX_CFG_SIZE_BYTES = 32'h800;

  /**
   * Memory base address for ctn memory on soc_proxy in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_SOC_PROXY_CTN_BASE_ADDR = 32'h40000000;

  /**
   * Memory size for ctn memory on soc_proxy in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_SOC_PROXY_CTN_SIZE_BYTES = 32'h80000000;

  /**
  * Memory base address for ram_ctn in top dragonfly.
  */
  parameter int unsigned TOP_DRAGONFLY_SOC_PROXY_RAM_CTN_BASE_ADDR = 32'h41000000;

  /**
  * Memory size for ram_ctn in top dragonfly.
  */
  parameter int unsigned TOP_DRAGONFLY_SOC_PROXY_RAM_CTN_SIZE_BYTES = 32'h100000;

  /**
   * Memory base address for ram memory on sram_ctrl_ret_aon in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_SRAM_CTRL_RET_AON_RAM_BASE_ADDR = 32'h30600000;

  /**
   * Memory size for ram memory on sram_ctrl_ret_aon in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_SRAM_CTRL_RET_AON_RAM_SIZE_BYTES = 32'h1000;

  /**
   * Memory base address for ram memory on sram_ctrl_main in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_SRAM_CTRL_MAIN_RAM_BASE_ADDR = 32'h10000000;

  /**
   * Memory size for ram memory on sram_ctrl_main in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_SRAM_CTRL_MAIN_RAM_SIZE_BYTES = 32'h10000;

  /**
   * Memory base address for ram memory on sram_ctrl_mbox in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_SRAM_CTRL_MBOX_RAM_BASE_ADDR = 32'h11000000;

  /**
   * Memory size for ram memory on sram_ctrl_mbox in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_SRAM_CTRL_MBOX_RAM_SIZE_BYTES = 32'h1000;

  /**
   * Memory base address for rom memory on rom_ctrl0 in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_ROM_CTRL0_ROM_BASE_ADDR = 32'h8000;

  /**
   * Memory size for rom memory on rom_ctrl0 in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_ROM_CTRL0_ROM_SIZE_BYTES = 32'h8000;

  /**
   * Memory base address for rom memory on rom_ctrl1 in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_ROM_CTRL1_ROM_BASE_ADDR = 32'h20000;

  /**
   * Memory size for rom memory on rom_ctrl1 in top dragonfly.
   */
  parameter int unsigned TOP_DRAGONFLY_ROM_CTRL1_ROM_SIZE_BYTES = 32'h10000;


  // Enumeration of alert modules
  typedef enum int unsigned {
    TopDragonflyAlertPeripheralUart0 = 0,
    TopDragonflyAlertPeripheralGpio = 1,
    TopDragonflyAlertPeripheralSpiDevice = 2,
    TopDragonflyAlertPeripheralI2c0 = 3,
    TopDragonflyAlertPeripheralRvTimer = 4,
    TopDragonflyAlertPeripheralOtpCtrl = 5,
    TopDragonflyAlertPeripheralLcCtrl = 6,
    TopDragonflyAlertPeripheralSpiHost0 = 7,
    TopDragonflyAlertPeripheralPwrmgrAon = 8,
    TopDragonflyAlertPeripheralRstmgrAon = 9,
    TopDragonflyAlertPeripheralClkmgrAon = 10,
    TopDragonflyAlertPeripheralPinmuxAon = 11,
    TopDragonflyAlertPeripheralAonTimerAon = 12,
    TopDragonflyAlertPeripheralSocProxy = 13,
    TopDragonflyAlertPeripheralSramCtrlRetAon = 14,
    TopDragonflyAlertPeripheralRvDm = 15,
    TopDragonflyAlertPeripheralRvPlic = 16,
    TopDragonflyAlertPeripheralAcc = 17,
    TopDragonflyAlertPeripheralAes = 18,
    TopDragonflyAlertPeripheralHmac = 19,
    TopDragonflyAlertPeripheralKmac = 20,
    TopDragonflyAlertPeripheralKeymgrDpe = 21,
    TopDragonflyAlertPeripheralCsrng = 22,
    TopDragonflyAlertPeripheralEntropySrc = 23,
    TopDragonflyAlertPeripheralEdn0 = 24,
    TopDragonflyAlertPeripheralEdn1 = 25,
    TopDragonflyAlertPeripheralSramCtrlMain = 26,
    TopDragonflyAlertPeripheralSramCtrlMbox = 27,
    TopDragonflyAlertPeripheralRomCtrl0 = 28,
    TopDragonflyAlertPeripheralRomCtrl1 = 29,
    TopDragonflyAlertPeripheralDma = 30,
    TopDragonflyAlertPeripheralMbx0 = 31,
    TopDragonflyAlertPeripheralMbx1 = 32,
    TopDragonflyAlertPeripheralMbx2 = 33,
    TopDragonflyAlertPeripheralMbx3 = 34,
    TopDragonflyAlertPeripheralMbx4 = 35,
    TopDragonflyAlertPeripheralMbx5 = 36,
    TopDragonflyAlertPeripheralMbx6 = 37,
    TopDragonflyAlertPeripheralMbxJtag = 38,
    TopDragonflyAlertPeripheralMbxPcie0 = 39,
    TopDragonflyAlertPeripheralMbxPcie1 = 40,
    TopDragonflyAlertPeripheralSocDbgCtrl = 41,
    TopDragonflyAlertPeripheralRaclCtrl = 42,
    TopDragonflyAlertPeripheralAcRangeCheck = 43,
    TopDragonflyAlertPeripheralRvCoreIbex = 44,
    TopDragonflyAlertPeripheralCount
  } alert_peripheral_e;

  // Enumeration of alerts
  typedef enum int unsigned {
    TopDragonflyAlertIdUart0FatalFault = 0,
    TopDragonflyAlertIdGpioFatalFault = 1,
    TopDragonflyAlertIdSpiDeviceFatalFault = 2,
    TopDragonflyAlertIdI2c0FatalFault = 3,
    TopDragonflyAlertIdRvTimerFatalFault = 4,
    TopDragonflyAlertIdOtpCtrlFatalMacroError = 5,
    TopDragonflyAlertIdOtpCtrlFatalCheckError = 6,
    TopDragonflyAlertIdOtpCtrlFatalBusIntegError = 7,
    TopDragonflyAlertIdOtpCtrlFatalPrimOtpAlert = 8,
    TopDragonflyAlertIdOtpCtrlRecovPrimOtpAlert = 9,
    TopDragonflyAlertIdLcCtrlFatalProgError = 10,
    TopDragonflyAlertIdLcCtrlFatalStateError = 11,
    TopDragonflyAlertIdLcCtrlFatalBusIntegError = 12,
    TopDragonflyAlertIdSpiHost0FatalFault = 13,
    TopDragonflyAlertIdPwrmgrAonFatalFault = 14,
    TopDragonflyAlertIdRstmgrAonFatalFault = 15,
    TopDragonflyAlertIdRstmgrAonFatalCnstyFault = 16,
    TopDragonflyAlertIdClkmgrAonRecovFault = 17,
    TopDragonflyAlertIdClkmgrAonFatalFault = 18,
    TopDragonflyAlertIdPinmuxAonFatalFault = 19,
    TopDragonflyAlertIdAonTimerAonFatalFault = 20,
    TopDragonflyAlertIdSocProxyFatalAlertIntg = 21,
    TopDragonflyAlertIdSramCtrlRetAonFatalError = 22,
    TopDragonflyAlertIdRvDmFatalFault = 23,
    TopDragonflyAlertIdRvPlicFatalFault = 24,
    TopDragonflyAlertIdAccFatal = 25,
    TopDragonflyAlertIdAccRecov = 26,
    TopDragonflyAlertIdAesRecovCtrlUpdateErr = 27,
    TopDragonflyAlertIdAesFatalFault = 28,
    TopDragonflyAlertIdHmacFatalFault = 29,
    TopDragonflyAlertIdKmacRecovOperationErr = 30,
    TopDragonflyAlertIdKmacFatalFaultErr = 31,
    TopDragonflyAlertIdKeymgrDpeRecovOperationErr = 32,
    TopDragonflyAlertIdKeymgrDpeFatalFaultErr = 33,
    TopDragonflyAlertIdCsrngRecovAlert = 34,
    TopDragonflyAlertIdCsrngFatalAlert = 35,
    TopDragonflyAlertIdEntropySrcRecovAlert = 36,
    TopDragonflyAlertIdEntropySrcFatalAlert = 37,
    TopDragonflyAlertIdEdn0RecovAlert = 38,
    TopDragonflyAlertIdEdn0FatalAlert = 39,
    TopDragonflyAlertIdEdn1RecovAlert = 40,
    TopDragonflyAlertIdEdn1FatalAlert = 41,
    TopDragonflyAlertIdSramCtrlMainFatalError = 42,
    TopDragonflyAlertIdSramCtrlMboxFatalError = 43,
    TopDragonflyAlertIdRomCtrl0Fatal = 44,
    TopDragonflyAlertIdRomCtrl1Fatal = 45,
    TopDragonflyAlertIdDmaFatalFault = 46,
    TopDragonflyAlertIdMbx0FatalFault = 47,
    TopDragonflyAlertIdMbx0RecovFault = 48,
    TopDragonflyAlertIdMbx1FatalFault = 49,
    TopDragonflyAlertIdMbx1RecovFault = 50,
    TopDragonflyAlertIdMbx2FatalFault = 51,
    TopDragonflyAlertIdMbx2RecovFault = 52,
    TopDragonflyAlertIdMbx3FatalFault = 53,
    TopDragonflyAlertIdMbx3RecovFault = 54,
    TopDragonflyAlertIdMbx4FatalFault = 55,
    TopDragonflyAlertIdMbx4RecovFault = 56,
    TopDragonflyAlertIdMbx5FatalFault = 57,
    TopDragonflyAlertIdMbx5RecovFault = 58,
    TopDragonflyAlertIdMbx6FatalFault = 59,
    TopDragonflyAlertIdMbx6RecovFault = 60,
    TopDragonflyAlertIdMbxJtagFatalFault = 61,
    TopDragonflyAlertIdMbxJtagRecovFault = 62,
    TopDragonflyAlertIdMbxPcie0FatalFault = 63,
    TopDragonflyAlertIdMbxPcie0RecovFault = 64,
    TopDragonflyAlertIdMbxPcie1FatalFault = 65,
    TopDragonflyAlertIdMbxPcie1RecovFault = 66,
    TopDragonflyAlertIdSocDbgCtrlFatalFault = 67,
    TopDragonflyAlertIdSocDbgCtrlRecovCtrlUpdateErr = 68,
    TopDragonflyAlertIdRaclCtrlFatalFault = 69,
    TopDragonflyAlertIdRaclCtrlRecovCtrlUpdateErr = 70,
    TopDragonflyAlertIdAcRangeCheckRecovCtrlUpdateErr = 71,
    TopDragonflyAlertIdAcRangeCheckFatalFault = 72,
    TopDragonflyAlertIdRvCoreIbexFatalSwErr = 73,
    TopDragonflyAlertIdRvCoreIbexRecovSwErr = 74,
    TopDragonflyAlertIdRvCoreIbexFatalHwErr = 75,
    TopDragonflyAlertIdRvCoreIbexRecovHwErr = 76,
    TopDragonflyAlertIdCount
  } alert_id_e;

  // Enumeration of interrupts
  typedef enum int unsigned {
    TopDragonflyPlicIrqIdNone = 0,
    TopDragonflyPlicIrqIdUart0TxWatermark = 1,
    TopDragonflyPlicIrqIdUart0RxWatermark = 2,
    TopDragonflyPlicIrqIdUart0TxDone = 3,
    TopDragonflyPlicIrqIdUart0RxOverflow = 4,
    TopDragonflyPlicIrqIdUart0RxFrameErr = 5,
    TopDragonflyPlicIrqIdUart0RxBreakErr = 6,
    TopDragonflyPlicIrqIdUart0RxTimeout = 7,
    TopDragonflyPlicIrqIdUart0RxParityErr = 8,
    TopDragonflyPlicIrqIdUart0TxEmpty = 9,
    TopDragonflyPlicIrqIdGpioGpio0 = 10,
    TopDragonflyPlicIrqIdGpioGpio1 = 11,
    TopDragonflyPlicIrqIdGpioGpio2 = 12,
    TopDragonflyPlicIrqIdGpioGpio3 = 13,
    TopDragonflyPlicIrqIdGpioGpio4 = 14,
    TopDragonflyPlicIrqIdGpioGpio5 = 15,
    TopDragonflyPlicIrqIdGpioGpio6 = 16,
    TopDragonflyPlicIrqIdGpioGpio7 = 17,
    TopDragonflyPlicIrqIdGpioGpio8 = 18,
    TopDragonflyPlicIrqIdGpioGpio9 = 19,
    TopDragonflyPlicIrqIdGpioGpio10 = 20,
    TopDragonflyPlicIrqIdGpioGpio11 = 21,
    TopDragonflyPlicIrqIdGpioGpio12 = 22,
    TopDragonflyPlicIrqIdGpioGpio13 = 23,
    TopDragonflyPlicIrqIdGpioGpio14 = 24,
    TopDragonflyPlicIrqIdGpioGpio15 = 25,
    TopDragonflyPlicIrqIdGpioGpio16 = 26,
    TopDragonflyPlicIrqIdGpioGpio17 = 27,
    TopDragonflyPlicIrqIdGpioGpio18 = 28,
    TopDragonflyPlicIrqIdGpioGpio19 = 29,
    TopDragonflyPlicIrqIdGpioGpio20 = 30,
    TopDragonflyPlicIrqIdGpioGpio21 = 31,
    TopDragonflyPlicIrqIdGpioGpio22 = 32,
    TopDragonflyPlicIrqIdGpioGpio23 = 33,
    TopDragonflyPlicIrqIdGpioGpio24 = 34,
    TopDragonflyPlicIrqIdGpioGpio25 = 35,
    TopDragonflyPlicIrqIdGpioGpio26 = 36,
    TopDragonflyPlicIrqIdGpioGpio27 = 37,
    TopDragonflyPlicIrqIdGpioGpio28 = 38,
    TopDragonflyPlicIrqIdGpioGpio29 = 39,
    TopDragonflyPlicIrqIdGpioGpio30 = 40,
    TopDragonflyPlicIrqIdGpioGpio31 = 41,
    TopDragonflyPlicIrqIdSpiDeviceUploadCmdfifoNotEmpty = 42,
    TopDragonflyPlicIrqIdSpiDeviceUploadPayloadNotEmpty = 43,
    TopDragonflyPlicIrqIdSpiDeviceUploadPayloadOverflow = 44,
    TopDragonflyPlicIrqIdSpiDeviceReadbufWatermark = 45,
    TopDragonflyPlicIrqIdSpiDeviceReadbufFlip = 46,
    TopDragonflyPlicIrqIdSpiDeviceTpmHeaderNotEmpty = 47,
    TopDragonflyPlicIrqIdSpiDeviceTpmRdfifoCmdEnd = 48,
    TopDragonflyPlicIrqIdSpiDeviceTpmRdfifoDrop = 49,
    TopDragonflyPlicIrqIdI2c0FmtThreshold = 50,
    TopDragonflyPlicIrqIdI2c0RxThreshold = 51,
    TopDragonflyPlicIrqIdI2c0AcqThreshold = 52,
    TopDragonflyPlicIrqIdI2c0RxOverflow = 53,
    TopDragonflyPlicIrqIdI2c0ControllerHalt = 54,
    TopDragonflyPlicIrqIdI2c0SclInterference = 55,
    TopDragonflyPlicIrqIdI2c0SdaInterference = 56,
    TopDragonflyPlicIrqIdI2c0StretchTimeout = 57,
    TopDragonflyPlicIrqIdI2c0SdaUnstable = 58,
    TopDragonflyPlicIrqIdI2c0CmdComplete = 59,
    TopDragonflyPlicIrqIdI2c0TxStretch = 60,
    TopDragonflyPlicIrqIdI2c0TxThreshold = 61,
    TopDragonflyPlicIrqIdI2c0AcqStretch = 62,
    TopDragonflyPlicIrqIdI2c0UnexpStop = 63,
    TopDragonflyPlicIrqIdI2c0HostTimeout = 64,
    TopDragonflyPlicIrqIdRvTimerTimerExpiredHart0Timer0 = 65,
    TopDragonflyPlicIrqIdOtpCtrlOtpOperationDone = 66,
    TopDragonflyPlicIrqIdOtpCtrlOtpError = 67,
    TopDragonflyPlicIrqIdAlertHandlerClassa = 68,
    TopDragonflyPlicIrqIdAlertHandlerClassb = 69,
    TopDragonflyPlicIrqIdAlertHandlerClassc = 70,
    TopDragonflyPlicIrqIdAlertHandlerClassd = 71,
    TopDragonflyPlicIrqIdSpiHost0Error = 72,
    TopDragonflyPlicIrqIdSpiHost0SpiEvent = 73,
    TopDragonflyPlicIrqIdPwrmgrAonWakeup = 74,
    TopDragonflyPlicIrqIdAonTimerAonWkupTimerExpired = 75,
    TopDragonflyPlicIrqIdAonTimerAonWdogTimerBark = 76,
    TopDragonflyPlicIrqIdAccDone = 77,
    TopDragonflyPlicIrqIdHmacHmacDone = 78,
    TopDragonflyPlicIrqIdHmacFifoEmpty = 79,
    TopDragonflyPlicIrqIdHmacHmacErr = 80,
    TopDragonflyPlicIrqIdKmacKmacDone = 81,
    TopDragonflyPlicIrqIdKmacFifoEmpty = 82,
    TopDragonflyPlicIrqIdKmacKmacErr = 83,
    TopDragonflyPlicIrqIdKeymgrDpeOpDone = 84,
    TopDragonflyPlicIrqIdCsrngCsCmdReqDone = 85,
    TopDragonflyPlicIrqIdCsrngCsEntropyReq = 86,
    TopDragonflyPlicIrqIdCsrngCsHwInstExc = 87,
    TopDragonflyPlicIrqIdCsrngCsFatalErr = 88,
    TopDragonflyPlicIrqIdEntropySrcEsEntropyValid = 89,
    TopDragonflyPlicIrqIdEntropySrcEsHealthTestFailed = 90,
    TopDragonflyPlicIrqIdEntropySrcEsObserveFifoReady = 91,
    TopDragonflyPlicIrqIdEntropySrcEsFatalErr = 92,
    TopDragonflyPlicIrqIdEdn0EdnCmdReqDone = 93,
    TopDragonflyPlicIrqIdEdn0EdnFatalErr = 94,
    TopDragonflyPlicIrqIdEdn1EdnCmdReqDone = 95,
    TopDragonflyPlicIrqIdEdn1EdnFatalErr = 96,
    TopDragonflyPlicIrqIdDmaDmaDone = 97,
    TopDragonflyPlicIrqIdDmaDmaChunkDone = 98,
    TopDragonflyPlicIrqIdDmaDmaError = 99,
    TopDragonflyPlicIrqIdMbx0MbxReady = 100,
    TopDragonflyPlicIrqIdMbx0MbxAbort = 101,
    TopDragonflyPlicIrqIdMbx0MbxError = 102,
    TopDragonflyPlicIrqIdMbx1MbxReady = 103,
    TopDragonflyPlicIrqIdMbx1MbxAbort = 104,
    TopDragonflyPlicIrqIdMbx1MbxError = 105,
    TopDragonflyPlicIrqIdMbx2MbxReady = 106,
    TopDragonflyPlicIrqIdMbx2MbxAbort = 107,
    TopDragonflyPlicIrqIdMbx2MbxError = 108,
    TopDragonflyPlicIrqIdMbx3MbxReady = 109,
    TopDragonflyPlicIrqIdMbx3MbxAbort = 110,
    TopDragonflyPlicIrqIdMbx3MbxError = 111,
    TopDragonflyPlicIrqIdMbx4MbxReady = 112,
    TopDragonflyPlicIrqIdMbx4MbxAbort = 113,
    TopDragonflyPlicIrqIdMbx4MbxError = 114,
    TopDragonflyPlicIrqIdMbx5MbxReady = 115,
    TopDragonflyPlicIrqIdMbx5MbxAbort = 116,
    TopDragonflyPlicIrqIdMbx5MbxError = 117,
    TopDragonflyPlicIrqIdMbx6MbxReady = 118,
    TopDragonflyPlicIrqIdMbx6MbxAbort = 119,
    TopDragonflyPlicIrqIdMbx6MbxError = 120,
    TopDragonflyPlicIrqIdMbxJtagMbxReady = 121,
    TopDragonflyPlicIrqIdMbxJtagMbxAbort = 122,
    TopDragonflyPlicIrqIdMbxJtagMbxError = 123,
    TopDragonflyPlicIrqIdMbxPcie0MbxReady = 124,
    TopDragonflyPlicIrqIdMbxPcie0MbxAbort = 125,
    TopDragonflyPlicIrqIdMbxPcie0MbxError = 126,
    TopDragonflyPlicIrqIdMbxPcie1MbxReady = 127,
    TopDragonflyPlicIrqIdMbxPcie1MbxAbort = 128,
    TopDragonflyPlicIrqIdMbxPcie1MbxError = 129,
    TopDragonflyPlicIrqIdRaclCtrlRaclError = 130,
    TopDragonflyPlicIrqIdAcRangeCheckDenyCntReached = 131,
    TopDragonflyPlicIrqIdCount
  } interrupt_rv_plic_id_e;


  // Enumeration of IO power domains.
  // Only used in ASIC target.
  typedef enum logic [0:0] {
    IoBankVio = 0,
    IoBankCount = 1
  } pwr_dom_e;

  // Enumeration for MIO signals on the top-level.
  typedef enum int unsigned {
    MioInSocProxySocGpi12 = 0,
    MioInSocProxySocGpi13 = 1,
    MioInSocProxySocGpi14 = 2,
    MioInSocProxySocGpi15 = 3,
    MioInCount = 4
  } mio_in_e;

  typedef enum {
    MioOutSocProxySocGpo12 = 0,
    MioOutSocProxySocGpo13 = 1,
    MioOutSocProxySocGpo14 = 2,
    MioOutSocProxySocGpo15 = 3,
    MioOutOtpMacroTest0 = 4,
    MioOutCount = 5
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
    DioI2c0Scl = 8,
    DioI2c0Sda = 9,
    DioGpioGpio0 = 10,
    DioGpioGpio1 = 11,
    DioGpioGpio2 = 12,
    DioGpioGpio3 = 13,
    DioGpioGpio4 = 14,
    DioGpioGpio5 = 15,
    DioGpioGpio6 = 16,
    DioGpioGpio7 = 17,
    DioGpioGpio8 = 18,
    DioGpioGpio9 = 19,
    DioGpioGpio10 = 20,
    DioGpioGpio11 = 21,
    DioGpioGpio12 = 22,
    DioGpioGpio13 = 23,
    DioGpioGpio14 = 24,
    DioGpioGpio15 = 25,
    DioGpioGpio16 = 26,
    DioGpioGpio17 = 27,
    DioGpioGpio18 = 28,
    DioGpioGpio19 = 29,
    DioGpioGpio20 = 30,
    DioGpioGpio21 = 31,
    DioGpioGpio22 = 32,
    DioGpioGpio23 = 33,
    DioGpioGpio24 = 34,
    DioGpioGpio25 = 35,
    DioGpioGpio26 = 36,
    DioGpioGpio27 = 37,
    DioGpioGpio28 = 38,
    DioGpioGpio29 = 39,
    DioGpioGpio30 = 40,
    DioGpioGpio31 = 41,
    DioSpiDeviceSck = 42,
    DioSpiDeviceCsb = 43,
    DioSpiDeviceTpmCsb = 44,
    DioUart0Rx = 45,
    DioSocProxySocGpi0 = 46,
    DioSocProxySocGpi1 = 47,
    DioSocProxySocGpi2 = 48,
    DioSocProxySocGpi3 = 49,
    DioSocProxySocGpi4 = 50,
    DioSocProxySocGpi5 = 51,
    DioSocProxySocGpi6 = 52,
    DioSocProxySocGpi7 = 53,
    DioSocProxySocGpi8 = 54,
    DioSocProxySocGpi9 = 55,
    DioSocProxySocGpi10 = 56,
    DioSocProxySocGpi11 = 57,
    DioSpiHost0Sck = 58,
    DioSpiHost0Csb = 59,
    DioUart0Tx = 60,
    DioSocProxySocGpo0 = 61,
    DioSocProxySocGpo1 = 62,
    DioSocProxySocGpo2 = 63,
    DioSocProxySocGpo3 = 64,
    DioSocProxySocGpo4 = 65,
    DioSocProxySocGpo5 = 66,
    DioSocProxySocGpo6 = 67,
    DioSocProxySocGpo7 = 68,
    DioSocProxySocGpo8 = 69,
    DioSocProxySocGpo9 = 70,
    DioSocProxySocGpo10 = 71,
    DioSocProxySocGpo11 = 72,
    DioCount = 73
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
    MioPadMio0 = 0,
    MioPadMio1 = 1,
    MioPadMio2 = 2,
    MioPadMio3 = 3,
    MioPadMio4 = 4,
    MioPadMio5 = 5,
    MioPadMio6 = 6,
    MioPadMio7 = 7,
    MioPadMio8 = 8,
    MioPadMio9 = 9,
    MioPadMio10 = 10,
    MioPadMio11 = 11,
    MioPadCount
  } mio_pad_e;

  typedef enum int unsigned {
    DioPadPorN = 0,
    DioPadJtagTck = 1,
    DioPadJtagTms = 2,
    DioPadJtagTdi = 3,
    DioPadJtagTdo = 4,
    DioPadJtagTrstN = 5,
    DioPadOtpExtVolt = 6,
    DioPadSpiHostD0 = 7,
    DioPadSpiHostD1 = 8,
    DioPadSpiHostD2 = 9,
    DioPadSpiHostD3 = 10,
    DioPadSpiHostClk = 11,
    DioPadSpiHostCsL = 12,
    DioPadSpiDevD0 = 13,
    DioPadSpiDevD1 = 14,
    DioPadSpiDevD2 = 15,
    DioPadSpiDevD3 = 16,
    DioPadSpiDevClk = 17,
    DioPadSpiDevCsL = 18,
    DioPadSpiDevTpmCsL = 19,
    DioPadUartRx = 20,
    DioPadUartTx = 21,
    DioPadI2cScl = 22,
    DioPadI2cSda = 23,
    DioPadGpio0 = 24,
    DioPadGpio1 = 25,
    DioPadGpio2 = 26,
    DioPadGpio3 = 27,
    DioPadGpio4 = 28,
    DioPadGpio5 = 29,
    DioPadGpio6 = 30,
    DioPadGpio7 = 31,
    DioPadGpio8 = 32,
    DioPadGpio9 = 33,
    DioPadGpio10 = 34,
    DioPadGpio11 = 35,
    DioPadGpio12 = 36,
    DioPadGpio13 = 37,
    DioPadGpio14 = 38,
    DioPadGpio15 = 39,
    DioPadGpio16 = 40,
    DioPadGpio17 = 41,
    DioPadGpio18 = 42,
    DioPadGpio19 = 43,
    DioPadGpio20 = 44,
    DioPadGpio21 = 45,
    DioPadGpio22 = 46,
    DioPadGpio23 = 47,
    DioPadGpio24 = 48,
    DioPadGpio25 = 49,
    DioPadGpio26 = 50,
    DioPadGpio27 = 51,
    DioPadGpio28 = 52,
    DioPadGpio29 = 53,
    DioPadGpio30 = 54,
    DioPadGpio31 = 55,
    DioPadSocGpi0 = 56,
    DioPadSocGpi1 = 57,
    DioPadSocGpi2 = 58,
    DioPadSocGpi3 = 59,
    DioPadSocGpi4 = 60,
    DioPadSocGpi5 = 61,
    DioPadSocGpi6 = 62,
    DioPadSocGpi7 = 63,
    DioPadSocGpi8 = 64,
    DioPadSocGpi9 = 65,
    DioPadSocGpi10 = 66,
    DioPadSocGpi11 = 67,
    DioPadSocGpo0 = 68,
    DioPadSocGpo1 = 69,
    DioPadSocGpo2 = 70,
    DioPadSocGpo3 = 71,
    DioPadSocGpo4 = 72,
    DioPadSocGpo5 = 73,
    DioPadSocGpo6 = 74,
    DioPadSocGpo7 = 75,
    DioPadSocGpo8 = 76,
    DioPadSocGpo9 = 77,
    DioPadSocGpo10 = 78,
    DioPadSocGpo11 = 79,
    DioPadCount
  } dio_pad_e;

  // List of peripheral instantiated in this chip.
  typedef enum {
    PeripheralAcc,
    PeripheralAes,
    PeripheralAlertHandler,
    PeripheralAonTimerAon,
    PeripheralAst,
    PeripheralClkmgrAon,
    PeripheralCsrng,
    PeripheralDma,
    PeripheralEdn0,
    PeripheralEdn1,
    PeripheralEntropySrc,
    PeripheralGpio,
    PeripheralHmac,
    PeripheralI2c0,
    PeripheralKeymgrDpe,
    PeripheralKmac,
    PeripheralLcCtrl,
    PeripheralMbx0,
    PeripheralMbx1,
    PeripheralMbx2,
    PeripheralMbx3,
    PeripheralMbx4,
    PeripheralMbx5,
    PeripheralMbx6,
    PeripheralMbxJtag,
    PeripheralMbxPcie0,
    PeripheralMbxPcie1,
    PeripheralOtpCtrl,
    PeripheralOtpMacro,
    PeripheralPinmuxAon,
    PeripheralPwrmgrAon,
    PeripheralRomCtrl0,
    PeripheralRomCtrl1,
    PeripheralRstmgrAon,
    PeripheralRvCoreIbex,
    PeripheralRvDm,
    PeripheralRvPlic,
    PeripheralRvTimer,
    PeripheralSocDbgCtrl,
    PeripheralSocProxy,
    PeripheralSpiDevice,
    PeripheralSpiHost0,
    PeripheralSramCtrlMain,
    PeripheralSramCtrlMbox,
    PeripheralSramCtrlRetAon,
    PeripheralUart0,
    PeripheralCount
  } peripheral_e;

  // MMIO Region
  //
  parameter int unsigned TOP_DRAGONFLY_MMIO_BASE_ADDR = 32'h21100000;
  parameter int unsigned TOP_DRAGONFLY_MMIO_SIZE_BYTES = 32'hF501000;

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
