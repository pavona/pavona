// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_LIB_TESTING_JSON_PINMUX_H_
#define OPENTITAN_SW_DEVICE_LIB_TESTING_JSON_PINMUX_H_
#include "sw/device/lib/ujson/ujson_derive.h"
#ifdef __cplusplus
extern "C" {
#endif

// Note: these definitions rely on constants from top_egret.h
// and therefore this library cannot be used with the `ujson_rust`
// bazel rule.  Instead, these constants are imported into rust
// by way of a bindgen rule and recreated as Rust datatypes with
// appropriate aliases to be used by other `ujson` libraries.
#ifndef RUST_PREPROCESSOR_EMIT
#if defined(OPENTITAN_IS_EGRET)
#include "hw/top_egret/sw/autogen/top_egret.h"
#elif defined(OPENTITAN_IS_DRAGONFLY)
#include "hw/top_dragonfly/sw/autogen/top_dragonfly.h"
#endif
#endif
// clang-format off

#if defined(OPENTITAN_IS_EGRET)
#define TOP_EGRET_PINMUX_PERIPHERAL_IN(_, value) \
    value(_, GpioGpio0, kTopEgretPinmuxPeripheralInGpioGpio0) \
    value(_, GpioGpio1, kTopEgretPinmuxPeripheralInGpioGpio1) \
    value(_, GpioGpio2, kTopEgretPinmuxPeripheralInGpioGpio2) \
    value(_, GpioGpio3, kTopEgretPinmuxPeripheralInGpioGpio3) \
    value(_, GpioGpio4, kTopEgretPinmuxPeripheralInGpioGpio4) \
    value(_, GpioGpio5, kTopEgretPinmuxPeripheralInGpioGpio5) \
    value(_, GpioGpio6, kTopEgretPinmuxPeripheralInGpioGpio6) \
    value(_, GpioGpio7, kTopEgretPinmuxPeripheralInGpioGpio7) \
    value(_, GpioGpio8, kTopEgretPinmuxPeripheralInGpioGpio8) \
    value(_, GpioGpio9, kTopEgretPinmuxPeripheralInGpioGpio9) \
    value(_, GpioGpio10, kTopEgretPinmuxPeripheralInGpioGpio10) \
    value(_, GpioGpio11, kTopEgretPinmuxPeripheralInGpioGpio11) \
    value(_, GpioGpio12, kTopEgretPinmuxPeripheralInGpioGpio12) \
    value(_, GpioGpio13, kTopEgretPinmuxPeripheralInGpioGpio13) \
    value(_, GpioGpio14, kTopEgretPinmuxPeripheralInGpioGpio14) \
    value(_, GpioGpio15, kTopEgretPinmuxPeripheralInGpioGpio15) \
    value(_, GpioGpio16, kTopEgretPinmuxPeripheralInGpioGpio16) \
    value(_, GpioGpio17, kTopEgretPinmuxPeripheralInGpioGpio17) \
    value(_, GpioGpio18, kTopEgretPinmuxPeripheralInGpioGpio18) \
    value(_, GpioGpio19, kTopEgretPinmuxPeripheralInGpioGpio19) \
    value(_, GpioGpio20, kTopEgretPinmuxPeripheralInGpioGpio20) \
    value(_, GpioGpio21, kTopEgretPinmuxPeripheralInGpioGpio21) \
    value(_, GpioGpio22, kTopEgretPinmuxPeripheralInGpioGpio22) \
    value(_, GpioGpio23, kTopEgretPinmuxPeripheralInGpioGpio23) \
    value(_, GpioGpio24, kTopEgretPinmuxPeripheralInGpioGpio24) \
    value(_, GpioGpio25, kTopEgretPinmuxPeripheralInGpioGpio25) \
    value(_, GpioGpio26, kTopEgretPinmuxPeripheralInGpioGpio26) \
    value(_, GpioGpio27, kTopEgretPinmuxPeripheralInGpioGpio27) \
    value(_, GpioGpio28, kTopEgretPinmuxPeripheralInGpioGpio28) \
    value(_, GpioGpio29, kTopEgretPinmuxPeripheralInGpioGpio29) \
    value(_, GpioGpio30, kTopEgretPinmuxPeripheralInGpioGpio30) \
    value(_, GpioGpio31, kTopEgretPinmuxPeripheralInGpioGpio31) \
    value(_, I2c0Sda, kTopEgretPinmuxPeripheralInI2c0Sda) \
    value(_, I2c0Scl, kTopEgretPinmuxPeripheralInI2c0Scl) \
    value(_, I2c1Sda, kTopEgretPinmuxPeripheralInI2c1Sda) \
    value(_, I2c1Scl, kTopEgretPinmuxPeripheralInI2c1Scl) \
    value(_, I2c2Sda, kTopEgretPinmuxPeripheralInI2c2Sda) \
    value(_, I2c2Scl, kTopEgretPinmuxPeripheralInI2c2Scl) \
    value(_, SpiHost1Sd0, kTopEgretPinmuxPeripheralInSpiHost1Sd0) \
    value(_, SpiHost1Sd1, kTopEgretPinmuxPeripheralInSpiHost1Sd1) \
    value(_, SpiHost1Sd2, kTopEgretPinmuxPeripheralInSpiHost1Sd2) \
    value(_, SpiHost1Sd3, kTopEgretPinmuxPeripheralInSpiHost1Sd3) \
    value(_, Uart0Rx, kTopEgretPinmuxPeripheralInUart0Rx) \
    value(_, Uart1Rx, kTopEgretPinmuxPeripheralInUart1Rx) \
    value(_, Uart2Rx, kTopEgretPinmuxPeripheralInUart2Rx) \
    value(_, Uart3Rx, kTopEgretPinmuxPeripheralInUart3Rx) \
    value(_, SpiDeviceTpmCsb, kTopEgretPinmuxPeripheralInSpiDeviceTpmCsb) \
    value(_, FlashCtrlTck, kTopEgretPinmuxPeripheralInFlashMacroWrapperTck) \
    value(_, FlashCtrlTms, kTopEgretPinmuxPeripheralInFlashMacroWrapperTms) \
    value(_, FlashCtrlTdi, kTopEgretPinmuxPeripheralInFlashMacroWrapperTdi) \
    value(_, SysrstCtrlAonAcPresent, kTopEgretPinmuxPeripheralInSysrstCtrlAonAcPresent) \
    value(_, SysrstCtrlAonKey0In, kTopEgretPinmuxPeripheralInSysrstCtrlAonKey0In) \
    value(_, SysrstCtrlAonKey1In, kTopEgretPinmuxPeripheralInSysrstCtrlAonKey1In) \
    value(_, SysrstCtrlAonKey2In, kTopEgretPinmuxPeripheralInSysrstCtrlAonKey2In) \
    value(_, SysrstCtrlAonPwrbIn, kTopEgretPinmuxPeripheralInSysrstCtrlAonPwrbIn) \
    value(_, SysrstCtrlAonLidOpen, kTopEgretPinmuxPeripheralInSysrstCtrlAonLidOpen) \
    value(_, UsbdevSense, kTopEgretPinmuxPeripheralInUsbdevSense) \
    value(_, End, kTopEgretPinmuxPeripheralInLast + 1)
C_ONLY(UJSON_SERDE_ENUM(PinmuxPeripheralIn, pinmux_peripheral_in_t, TOP_EGRET_PINMUX_PERIPHERAL_IN, WITH_UNKNOWN));

#define TOP_EGRET_PINMUX_INSEL(_, value) \
    value(_, ConstantZero, kTopEgretPinmuxInselConstantZero) \
    value(_, ConstantOne, kTopEgretPinmuxInselConstantOne) \
    value(_, Ioa0, kTopEgretPinmuxInselIoa0) \
    value(_, Ioa1, kTopEgretPinmuxInselIoa1) \
    value(_, Ioa2, kTopEgretPinmuxInselIoa2) \
    value(_, Ioa3, kTopEgretPinmuxInselIoa3) \
    value(_, Ioa4, kTopEgretPinmuxInselIoa4) \
    value(_, Ioa5, kTopEgretPinmuxInselIoa5) \
    value(_, Ioa6, kTopEgretPinmuxInselIoa6) \
    value(_, Ioa7, kTopEgretPinmuxInselIoa7) \
    value(_, Ioa8, kTopEgretPinmuxInselIoa8) \
    value(_, Iob0, kTopEgretPinmuxInselIob0) \
    value(_, Iob1, kTopEgretPinmuxInselIob1) \
    value(_, Iob2, kTopEgretPinmuxInselIob2) \
    value(_, Iob3, kTopEgretPinmuxInselIob3) \
    value(_, Iob4, kTopEgretPinmuxInselIob4) \
    value(_, Iob5, kTopEgretPinmuxInselIob5) \
    value(_, Iob6, kTopEgretPinmuxInselIob6) \
    value(_, Iob7, kTopEgretPinmuxInselIob7) \
    value(_, Iob8, kTopEgretPinmuxInselIob8) \
    value(_, Iob9, kTopEgretPinmuxInselIob9) \
    value(_, Iob10, kTopEgretPinmuxInselIob10) \
    value(_, Iob11, kTopEgretPinmuxInselIob11) \
    value(_, Iob12, kTopEgretPinmuxInselIob12) \
    value(_, Ioc0, kTopEgretPinmuxInselIoc0) \
    value(_, Ioc1, kTopEgretPinmuxInselIoc1) \
    value(_, Ioc2, kTopEgretPinmuxInselIoc2) \
    value(_, Ioc3, kTopEgretPinmuxInselIoc3) \
    value(_, Ioc4, kTopEgretPinmuxInselIoc4) \
    value(_, Ioc5, kTopEgretPinmuxInselIoc5) \
    value(_, Ioc6, kTopEgretPinmuxInselIoc6) \
    value(_, Ioc7, kTopEgretPinmuxInselIoc7) \
    value(_, Ioc8, kTopEgretPinmuxInselIoc8) \
    value(_, Ioc9, kTopEgretPinmuxInselIoc9) \
    value(_, Ioc10, kTopEgretPinmuxInselIoc10) \
    value(_, Ioc11, kTopEgretPinmuxInselIoc11) \
    value(_, Ioc12, kTopEgretPinmuxInselIoc12) \
    value(_, Ior0, kTopEgretPinmuxInselIor0) \
    value(_, Ior1, kTopEgretPinmuxInselIor1) \
    value(_, Ior2, kTopEgretPinmuxInselIor2) \
    value(_, Ior3, kTopEgretPinmuxInselIor3) \
    value(_, Ior4, kTopEgretPinmuxInselIor4) \
    value(_, Ior5, kTopEgretPinmuxInselIor5) \
    value(_, Ior6, kTopEgretPinmuxInselIor6) \
    value(_, Ior7, kTopEgretPinmuxInselIor7) \
    value(_, Ior10, kTopEgretPinmuxInselIor10) \
    value(_, Ior11, kTopEgretPinmuxInselIor11) \
    value(_, Ior12, kTopEgretPinmuxInselIor12) \
    value(_, Ior13, kTopEgretPinmuxInselIor13) \
    value(_, End, kTopEgretPinmuxInselLast + 1)
C_ONLY(UJSON_SERDE_ENUM(PinmuxInsel, pinmux_insel_t, TOP_EGRET_PINMUX_INSEL, WITH_UNKNOWN));

#define TOP_EGRET_PINMUX_MIO_OUT(_, value) \
    value(_, Ioa0, kTopEgretPinmuxMioOutIoa0) \
    value(_, Ioa1, kTopEgretPinmuxMioOutIoa1) \
    value(_, Ioa2, kTopEgretPinmuxMioOutIoa2) \
    value(_, Ioa3, kTopEgretPinmuxMioOutIoa3) \
    value(_, Ioa4, kTopEgretPinmuxMioOutIoa4) \
    value(_, Ioa5, kTopEgretPinmuxMioOutIoa5) \
    value(_, Ioa6, kTopEgretPinmuxMioOutIoa6) \
    value(_, Ioa7, kTopEgretPinmuxMioOutIoa7) \
    value(_, Ioa8, kTopEgretPinmuxMioOutIoa8) \
    value(_, Iob0, kTopEgretPinmuxMioOutIob0) \
    value(_, Iob1, kTopEgretPinmuxMioOutIob1) \
    value(_, Iob2, kTopEgretPinmuxMioOutIob2) \
    value(_, Iob3, kTopEgretPinmuxMioOutIob3) \
    value(_, Iob4, kTopEgretPinmuxMioOutIob4) \
    value(_, Iob5, kTopEgretPinmuxMioOutIob5) \
    value(_, Iob6, kTopEgretPinmuxMioOutIob6) \
    value(_, Iob7, kTopEgretPinmuxMioOutIob7) \
    value(_, Iob8, kTopEgretPinmuxMioOutIob8) \
    value(_, Iob9, kTopEgretPinmuxMioOutIob9) \
    value(_, Iob10, kTopEgretPinmuxMioOutIob10) \
    value(_, Iob11, kTopEgretPinmuxMioOutIob11) \
    value(_, Iob12, kTopEgretPinmuxMioOutIob12) \
    value(_, Ioc0, kTopEgretPinmuxMioOutIoc0) \
    value(_, Ioc1, kTopEgretPinmuxMioOutIoc1) \
    value(_, Ioc2, kTopEgretPinmuxMioOutIoc2) \
    value(_, Ioc3, kTopEgretPinmuxMioOutIoc3) \
    value(_, Ioc4, kTopEgretPinmuxMioOutIoc4) \
    value(_, Ioc5, kTopEgretPinmuxMioOutIoc5) \
    value(_, Ioc6, kTopEgretPinmuxMioOutIoc6) \
    value(_, Ioc7, kTopEgretPinmuxMioOutIoc7) \
    value(_, Ioc8, kTopEgretPinmuxMioOutIoc8) \
    value(_, Ioc9, kTopEgretPinmuxMioOutIoc9) \
    value(_, Ioc10, kTopEgretPinmuxMioOutIoc10) \
    value(_, Ioc11, kTopEgretPinmuxMioOutIoc11) \
    value(_, Ioc12, kTopEgretPinmuxMioOutIoc12) \
    value(_, Ior0, kTopEgretPinmuxMioOutIor0) \
    value(_, Ior1, kTopEgretPinmuxMioOutIor1) \
    value(_, Ior2, kTopEgretPinmuxMioOutIor2) \
    value(_, Ior3, kTopEgretPinmuxMioOutIor3) \
    value(_, Ior4, kTopEgretPinmuxMioOutIor4) \
    value(_, Ior5, kTopEgretPinmuxMioOutIor5) \
    value(_, Ior6, kTopEgretPinmuxMioOutIor6) \
    value(_, Ior7, kTopEgretPinmuxMioOutIor7) \
    value(_, Ior10, kTopEgretPinmuxMioOutIor10) \
    value(_, Ior11, kTopEgretPinmuxMioOutIor11) \
    value(_, Ior12, kTopEgretPinmuxMioOutIor12) \
    value(_, Ior13, kTopEgretPinmuxMioOutIor13) \
    value(_, End, kTopEgretPinmuxMioOutLast + 1)
C_ONLY(UJSON_SERDE_ENUM(PinmuxMioOut, pinmux_mio_out_t, TOP_EGRET_PINMUX_MIO_OUT, WITH_UNKNOWN));

#define TOP_EGRET_PINMUX_OUTSEL(_, value) \
    value(_, ConstantZero, kTopEgretPinmuxOutselConstantZero) \
    value(_, ConstantOne, kTopEgretPinmuxOutselConstantOne) \
    value(_, ConstantHighZ, kTopEgretPinmuxOutselConstantHighZ) \
    value(_, GpioGpio0, kTopEgretPinmuxOutselGpioGpio0) \
    value(_, GpioGpio1, kTopEgretPinmuxOutselGpioGpio1) \
    value(_, GpioGpio2, kTopEgretPinmuxOutselGpioGpio2) \
    value(_, GpioGpio3, kTopEgretPinmuxOutselGpioGpio3) \
    value(_, GpioGpio4, kTopEgretPinmuxOutselGpioGpio4) \
    value(_, GpioGpio5, kTopEgretPinmuxOutselGpioGpio5) \
    value(_, GpioGpio6, kTopEgretPinmuxOutselGpioGpio6) \
    value(_, GpioGpio7, kTopEgretPinmuxOutselGpioGpio7) \
    value(_, GpioGpio8, kTopEgretPinmuxOutselGpioGpio8) \
    value(_, GpioGpio9, kTopEgretPinmuxOutselGpioGpio9) \
    value(_, GpioGpio10, kTopEgretPinmuxOutselGpioGpio10) \
    value(_, GpioGpio11, kTopEgretPinmuxOutselGpioGpio11) \
    value(_, GpioGpio12, kTopEgretPinmuxOutselGpioGpio12) \
    value(_, GpioGpio13, kTopEgretPinmuxOutselGpioGpio13) \
    value(_, GpioGpio14, kTopEgretPinmuxOutselGpioGpio14) \
    value(_, GpioGpio15, kTopEgretPinmuxOutselGpioGpio15) \
    value(_, GpioGpio16, kTopEgretPinmuxOutselGpioGpio16) \
    value(_, GpioGpio17, kTopEgretPinmuxOutselGpioGpio17) \
    value(_, GpioGpio18, kTopEgretPinmuxOutselGpioGpio18) \
    value(_, GpioGpio19, kTopEgretPinmuxOutselGpioGpio19) \
    value(_, GpioGpio20, kTopEgretPinmuxOutselGpioGpio20) \
    value(_, GpioGpio21, kTopEgretPinmuxOutselGpioGpio21) \
    value(_, GpioGpio22, kTopEgretPinmuxOutselGpioGpio22) \
    value(_, GpioGpio23, kTopEgretPinmuxOutselGpioGpio23) \
    value(_, GpioGpio24, kTopEgretPinmuxOutselGpioGpio24) \
    value(_, GpioGpio25, kTopEgretPinmuxOutselGpioGpio25) \
    value(_, GpioGpio26, kTopEgretPinmuxOutselGpioGpio26) \
    value(_, GpioGpio27, kTopEgretPinmuxOutselGpioGpio27) \
    value(_, GpioGpio28, kTopEgretPinmuxOutselGpioGpio28) \
    value(_, GpioGpio29, kTopEgretPinmuxOutselGpioGpio29) \
    value(_, GpioGpio30, kTopEgretPinmuxOutselGpioGpio30) \
    value(_, GpioGpio31, kTopEgretPinmuxOutselGpioGpio31) \
    value(_, I2c0Sda, kTopEgretPinmuxOutselI2c0Sda) \
    value(_, I2c0Scl, kTopEgretPinmuxOutselI2c0Scl) \
    value(_, I2c1Sda, kTopEgretPinmuxOutselI2c1Sda) \
    value(_, I2c1Scl, kTopEgretPinmuxOutselI2c1Scl) \
    value(_, I2c2Sda, kTopEgretPinmuxOutselI2c2Sda) \
    value(_, I2c2Scl, kTopEgretPinmuxOutselI2c2Scl) \
    value(_, SpiHost1Sd0, kTopEgretPinmuxOutselSpiHost1Sd0) \
    value(_, SpiHost1Sd1, kTopEgretPinmuxOutselSpiHost1Sd1) \
    value(_, SpiHost1Sd2, kTopEgretPinmuxOutselSpiHost1Sd2) \
    value(_, SpiHost1Sd3, kTopEgretPinmuxOutselSpiHost1Sd3) \
    value(_, Uart0Tx, kTopEgretPinmuxOutselUart0Tx) \
    value(_, Uart1Tx, kTopEgretPinmuxOutselUart1Tx) \
    value(_, Uart2Tx, kTopEgretPinmuxOutselUart2Tx) \
    value(_, Uart3Tx, kTopEgretPinmuxOutselUart3Tx) \
    value(_, PattgenPda0Tx, kTopEgretPinmuxOutselPattgenPda0Tx) \
    value(_, PattgenPcl0Tx, kTopEgretPinmuxOutselPattgenPcl0Tx) \
    value(_, PattgenPda1Tx, kTopEgretPinmuxOutselPattgenPda1Tx) \
    value(_, PattgenPcl1Tx, kTopEgretPinmuxOutselPattgenPcl1Tx) \
    value(_, SpiHost1Sck, kTopEgretPinmuxOutselSpiHost1Sck) \
    value(_, SpiHost1Csb, kTopEgretPinmuxOutselSpiHost1Csb) \
    value(_, FlashMacroWrapperTdo, kTopEgretPinmuxOutselFlashMacroWrapperTdo) \
    value(_, SensorCtrlAstDebugOut0, kTopEgretPinmuxOutselSensorCtrlAonAstDebugOut0) \
    value(_, SensorCtrlAstDebugOut1, kTopEgretPinmuxOutselSensorCtrlAonAstDebugOut1) \
    value(_, SensorCtrlAstDebugOut2, kTopEgretPinmuxOutselSensorCtrlAonAstDebugOut2) \
    value(_, SensorCtrlAstDebugOut3, kTopEgretPinmuxOutselSensorCtrlAonAstDebugOut3) \
    value(_, SensorCtrlAstDebugOut4, kTopEgretPinmuxOutselSensorCtrlAonAstDebugOut4) \
    value(_, SensorCtrlAstDebugOut5, kTopEgretPinmuxOutselSensorCtrlAonAstDebugOut5) \
    value(_, SensorCtrlAstDebugOut6, kTopEgretPinmuxOutselSensorCtrlAonAstDebugOut6) \
    value(_, SensorCtrlAstDebugOut7, kTopEgretPinmuxOutselSensorCtrlAonAstDebugOut7) \
    value(_, SensorCtrlAstDebugOut8, kTopEgretPinmuxOutselSensorCtrlAonAstDebugOut8) \
    value(_, PwmAonPwm0, kTopEgretPinmuxOutselPwmAonPwm0) \
    value(_, PwmAonPwm1, kTopEgretPinmuxOutselPwmAonPwm1) \
    value(_, PwmAonPwm2, kTopEgretPinmuxOutselPwmAonPwm2) \
    value(_, PwmAonPwm3, kTopEgretPinmuxOutselPwmAonPwm3) \
    value(_, PwmAonPwm4, kTopEgretPinmuxOutselPwmAonPwm4) \
    value(_, PwmAonPwm5, kTopEgretPinmuxOutselPwmAonPwm5) \
    value(_, OtpMacroTest0, kTopEgretPinmuxOutselOtpMacroTest0) \
    value(_, SysrstCtrlAonBatDisable, kTopEgretPinmuxOutselSysrstCtrlAonBatDisable) \
    value(_, SysrstCtrlAonKey0Out, kTopEgretPinmuxOutselSysrstCtrlAonKey0Out) \
    value(_, SysrstCtrlAonKey1Out, kTopEgretPinmuxOutselSysrstCtrlAonKey1Out) \
    value(_, SysrstCtrlAonKey2Out, kTopEgretPinmuxOutselSysrstCtrlAonKey2Out) \
    value(_, SysrstCtrlAonPwrbOut, kTopEgretPinmuxOutselSysrstCtrlAonPwrbOut) \
    value(_, SysrstCtrlAonZ3Wakeup, kTopEgretPinmuxOutselSysrstCtrlAonZ3Wakeup) \
    value(_, End, kTopEgretPinmuxOutselLast + 1)
C_ONLY(UJSON_SERDE_ENUM(PinmuxOutsel, pinmux_outsel_t, TOP_EGRET_PINMUX_OUTSEL, WITH_UNKNOWN));

#define TOP_EGRET_DIRECT_PADS(_, value) \
    value(_, UsbdevUsbDp, kTopEgretDirectPadsUsbdevUsbDp) \
    value(_, UsbdevUsbDn, kTopEgretDirectPadsUsbdevUsbDn) \
    value(_, SpiHost0Sd0, kTopEgretDirectPadsSpiHost0Sd0) \
    value(_, SpiHost0Sd1, kTopEgretDirectPadsSpiHost0Sd1) \
    value(_, SpiHost0Sd2, kTopEgretDirectPadsSpiHost0Sd2) \
    value(_, SpiHost0Sd3, kTopEgretDirectPadsSpiHost0Sd3) \
    value(_, SpiDeviceSd0, kTopEgretDirectPadsSpiDeviceSd0) \
    value(_, SpiDeviceSd1, kTopEgretDirectPadsSpiDeviceSd1) \
    value(_, SpiDeviceSd2, kTopEgretDirectPadsSpiDeviceSd2) \
    value(_, SpiDeviceSd3, kTopEgretDirectPadsSpiDeviceSd3) \
    value(_, SysrstCtrlAonEcRstL, kTopEgretDirectPadsSysrstCtrlAonEcRstL) \
    value(_, SysrstCtrlAonFlashWpL, kTopEgretDirectPadsSysrstCtrlAonFlashWpL) \
    value(_, SpiDeviceSck, kTopEgretDirectPadsSpiDeviceSck) \
    value(_, SpiDeviceCsb, kTopEgretDirectPadsSpiDeviceCsb) \
    value(_, SpiHost0Sck, kTopEgretDirectPadsSpiHost0Sck) \
    value(_, SpiHost0Csb, kTopEgretDirectPadsSpiHost0Csb) \
    value(_, End, kTopEgretDirectPadsLast + 1)
C_ONLY(UJSON_SERDE_ENUM(DirectPads, direct_pads_t, TOP_EGRET_DIRECT_PADS, WITH_UNKNOWN));

#define TOP_EGRET_MUXED_PADS(_, value) \
    value(_, Ioa0, kTopEgretMuxedPadsIoa0) \
    value(_, Ioa1, kTopEgretMuxedPadsIoa1) \
    value(_, Ioa2, kTopEgretMuxedPadsIoa2) \
    value(_, Ioa3, kTopEgretMuxedPadsIoa3) \
    value(_, Ioa4, kTopEgretMuxedPadsIoa4) \
    value(_, Ioa5, kTopEgretMuxedPadsIoa5) \
    value(_, Ioa6, kTopEgretMuxedPadsIoa6) \
    value(_, Ioa7, kTopEgretMuxedPadsIoa7) \
    value(_, Ioa8, kTopEgretMuxedPadsIoa8) \
    value(_, Iob0, kTopEgretMuxedPadsIob0) \
    value(_, Iob1, kTopEgretMuxedPadsIob1) \
    value(_, Iob2, kTopEgretMuxedPadsIob2) \
    value(_, Iob3, kTopEgretMuxedPadsIob3) \
    value(_, Iob4, kTopEgretMuxedPadsIob4) \
    value(_, Iob5, kTopEgretMuxedPadsIob5) \
    value(_, Iob6, kTopEgretMuxedPadsIob6) \
    value(_, Iob7, kTopEgretMuxedPadsIob7) \
    value(_, Iob8, kTopEgretMuxedPadsIob8) \
    value(_, Iob9, kTopEgretMuxedPadsIob9) \
    value(_, Iob10, kTopEgretMuxedPadsIob10) \
    value(_, Iob11, kTopEgretMuxedPadsIob11) \
    value(_, Iob12, kTopEgretMuxedPadsIob12) \
    value(_, Ioc0, kTopEgretMuxedPadsIoc0) \
    value(_, Ioc1, kTopEgretMuxedPadsIoc1) \
    value(_, Ioc2, kTopEgretMuxedPadsIoc2) \
    value(_, Ioc3, kTopEgretMuxedPadsIoc3) \
    value(_, Ioc4, kTopEgretMuxedPadsIoc4) \
    value(_, Ioc5, kTopEgretMuxedPadsIoc5) \
    value(_, Ioc6, kTopEgretMuxedPadsIoc6) \
    value(_, Ioc7, kTopEgretMuxedPadsIoc7) \
    value(_, Ioc8, kTopEgretMuxedPadsIoc8) \
    value(_, Ioc9, kTopEgretMuxedPadsIoc9) \
    value(_, Ioc10, kTopEgretMuxedPadsIoc10) \
    value(_, Ioc11, kTopEgretMuxedPadsIoc11) \
    value(_, Ioc12, kTopEgretMuxedPadsIoc12) \
    value(_, Ior0, kTopEgretMuxedPadsIor0) \
    value(_, Ior1, kTopEgretMuxedPadsIor1) \
    value(_, Ior2, kTopEgretMuxedPadsIor2) \
    value(_, Ior3, kTopEgretMuxedPadsIor3) \
    value(_, Ior4, kTopEgretMuxedPadsIor4) \
    value(_, Ior5, kTopEgretMuxedPadsIor5) \
    value(_, Ior6, kTopEgretMuxedPadsIor6) \
    value(_, Ior7, kTopEgretMuxedPadsIor7) \
    value(_, Ior10, kTopEgretMuxedPadsIor10) \
    value(_, Ior11, kTopEgretMuxedPadsIor11) \
    value(_, Ior12, kTopEgretMuxedPadsIor12) \
    value(_, Ior13, kTopEgretMuxedPadsIor13) \
    value(_, End, kTopEgretMuxedPadsLast + 1)
C_ONLY(UJSON_SERDE_ENUM(MuxedPads, muxed_pads_t, TOP_EGRET_MUXED_PADS, WITH_UNKNOWN));

#elif defined(OPENTITAN_IS_DRAGONFLY)

#define TOP_DRAGONFLY_PINMUX_PERIPHERAL_IN(_, value) \
    value(_, SocProxySocGpi12, kTopDragonflyPinmuxPeripheralInSocProxySocGpi12) \
    value(_, SocProxySocGpi13, kTopDragonflyPinmuxPeripheralInSocProxySocGpi13) \
    value(_, SocProxySocGpi14, kTopDragonflyPinmuxPeripheralInSocProxySocGpi14) \
    value(_, SocProxySocGpi15, kTopDragonflyPinmuxPeripheralInSocProxySocGpi15) \
    value(_, End, kTopDragonflyPinmuxPeripheralInLast + 1)
C_ONLY(UJSON_SERDE_ENUM(PinmuxPeripheralIn, pinmux_peripheral_in_t, TOP_DRAGONFLY_PINMUX_PERIPHERAL_IN, WITH_UNKNOWN));

#define TOP_DRAGONFLY_PINMUX_INSEL(_, value) \
    value(_, ConstantZero, kTopDragonflyPinmuxInselConstantZero) \
    value(_, ConstantOne, kTopDragonflyPinmuxInselConstantOne) \
    value(_, Mio0, kTopDragonflyPinmuxInselMio0) \
    value(_, Mio1, kTopDragonflyPinmuxInselMio1) \
    value(_, Mio2, kTopDragonflyPinmuxInselMio2) \
    value(_, Mio3, kTopDragonflyPinmuxInselMio3) \
    value(_, Mio4, kTopDragonflyPinmuxInselMio4) \
    value(_, Mio5, kTopDragonflyPinmuxInselMio5) \
    value(_, Mio6, kTopDragonflyPinmuxInselMio6) \
    value(_, Mio7, kTopDragonflyPinmuxInselMio7) \
    value(_, Mio8, kTopDragonflyPinmuxInselMio8) \
    value(_, Mio9, kTopDragonflyPinmuxInselMio9) \
    value(_, Mio10, kTopDragonflyPinmuxInselMio10) \
    value(_, Mio11, kTopDragonflyPinmuxInselMio11) \
    value(_, End, kTopDragonflyPinmuxInselLast + 1)
C_ONLY(UJSON_SERDE_ENUM(PinmuxInsel, pinmux_insel_t, TOP_DRAGONFLY_PINMUX_INSEL, WITH_UNKNOWN));

#define TOP_DRAGONFLY_PINMUX_MIO_OUT(_, value) \
    value(_, Mio0, kTopDragonflyPinmuxMioOutMio0) \
    value(_, Mio1, kTopDragonflyPinmuxMioOutMio1) \
    value(_, Mio2, kTopDragonflyPinmuxMioOutMio2) \
    value(_, Mio3, kTopDragonflyPinmuxMioOutMio3) \
    value(_, Mio4, kTopDragonflyPinmuxMioOutMio4) \
    value(_, Mio5, kTopDragonflyPinmuxMioOutMio5) \
    value(_, Mio6, kTopDragonflyPinmuxMioOutMio6) \
    value(_, Mio7, kTopDragonflyPinmuxMioOutMio7) \
    value(_, Mio8, kTopDragonflyPinmuxMioOutMio8) \
    value(_, Mio9, kTopDragonflyPinmuxMioOutMio9) \
    value(_, Mio10, kTopDragonflyPinmuxMioOutMio10) \
    value(_, Mio11, kTopDragonflyPinmuxMioOutMio11) \
    value(_, End, kTopDragonflyPinmuxMioOutLast + 1)
C_ONLY(UJSON_SERDE_ENUM(PinmuxMioOut, pinmux_mio_out_t, TOP_DRAGONFLY_PINMUX_MIO_OUT, WITH_UNKNOWN));

#define TOP_DRAGONFLY_PINMUX_OUTSEL(_, value) \
    value(_, ConstantZero, kTopDragonflyPinmuxOutselConstantZero) \
    value(_, ConstantOne, kTopDragonflyPinmuxOutselConstantOne) \
    value(_, ConstantHighZ, kTopDragonflyPinmuxOutselConstantHighZ) \
    value(_, lSocProxySocGpo12, kTopDragonflyPinmuxOutselSocProxySocGpo12) \
    value(_, SocProxySocGpo13, kTopDragonflyPinmuxOutselSocProxySocGpo13) \
    value(_, SocProxySocGpo14, kTopDragonflyPinmuxOutselSocProxySocGpo14) \
    value(_, SocProxySocGpo15, kTopDragonflyPinmuxOutselSocProxySocGpo15) \
    value(_, OtpMacroTest0, kTopDragonflyPinmuxOutselOtpMacroTest0) \
    value(_, End, kTopDragonflyPinmuxOutselLast + 1)
C_ONLY(UJSON_SERDE_ENUM(PinmuxOutsel, pinmux_outsel_t, TOP_DRAGONFLY_PINMUX_OUTSEL, WITH_UNKNOWN));

#define TOP_DRAGONFLY_DIRECT_PADS(_, value) \
    value(_, SpiHost0Sd0, kTopDragonflyDirectPadsSpiHost0Sd0) \
    value(_, SpiHost0Sd1, kTopDragonflyDirectPadsSpiHost0Sd1) \
    value(_, SpiHost0Sd2, kTopDragonflyDirectPadsSpiHost0Sd2) \
    value(_, SpiHost0Sd3, kTopDragonflyDirectPadsSpiHost0Sd3) \
    value(_, SpiDeviceSd0, kTopDragonflyDirectPadsSpiDeviceSd0) \
    value(_, SpiDeviceSd1, kTopDragonflyDirectPadsSpiDeviceSd1) \
    value(_, SpiDeviceSd2, kTopDragonflyDirectPadsSpiDeviceSd2) \
    value(_, SpiDeviceSd3, kTopDragonflyDirectPadsSpiDeviceSd3) \
    value(_, I2c0Scl, kTopDragonflyDirectPadsI2c0Scl) \
    value(_, I2c0Sda, kTopDragonflyDirectPadsI2c0Sda) \
    value(_, GpioGpio0, kTopDragonflyDirectPadsGpioGpio0) \
    value(_, GpioGpio1, kTopDragonflyDirectPadsGpioGpio1) \
    value(_, GpioGpio2, kTopDragonflyDirectPadsGpioGpio2) \
    value(_, GpioGpio3, kTopDragonflyDirectPadsGpioGpio3) \
    value(_, GpioGpio4, kTopDragonflyDirectPadsGpioGpio4) \
    value(_, GpioGpio5, kTopDragonflyDirectPadsGpioGpio5) \
    value(_, GpioGpio6, kTopDragonflyDirectPadsGpioGpio6) \
    value(_, GpioGpio7, kTopDragonflyDirectPadsGpioGpio7) \
    value(_, GpioGpio8, kTopDragonflyDirectPadsGpioGpio8) \
    value(_, GpioGpio9, kTopDragonflyDirectPadsGpioGpio9) \
    value(_, GpioGpio10, kTopDragonflyDirectPadsGpioGpio10) \
    value(_, GpioGpio11, kTopDragonflyDirectPadsGpioGpio11) \
    value(_, GpioGpio12, kTopDragonflyDirectPadsGpioGpio12) \
    value(_, GpioGpio13, kTopDragonflyDirectPadsGpioGpio13) \
    value(_, GpioGpio14, kTopDragonflyDirectPadsGpioGpio14) \
    value(_, GpioGpio15, kTopDragonflyDirectPadsGpioGpio15) \
    value(_, GpioGpio16, kTopDragonflyDirectPadsGpioGpio16) \
    value(_, GpioGpio17, kTopDragonflyDirectPadsGpioGpio17) \
    value(_, GpioGpio18, kTopDragonflyDirectPadsGpioGpio18) \
    value(_, GpioGpio19, kTopDragonflyDirectPadsGpioGpio19) \
    value(_, GpioGpio20, kTopDragonflyDirectPadsGpioGpio20) \
    value(_, GpioGpio21, kTopDragonflyDirectPadsGpioGpio21) \
    value(_, GpioGpio22, kTopDragonflyDirectPadsGpioGpio22) \
    value(_, GpioGpio23, kTopDragonflyDirectPadsGpioGpio23) \
    value(_, GpioGpio24, kTopDragonflyDirectPadsGpioGpio24) \
    value(_, GpioGpio25, kTopDragonflyDirectPadsGpioGpio25) \
    value(_, GpioGpio26, kTopDragonflyDirectPadsGpioGpio26) \
    value(_, GpioGpio27, kTopDragonflyDirectPadsGpioGpio27) \
    value(_, GpioGpio28, kTopDragonflyDirectPadsGpioGpio28) \
    value(_, GpioGpio29, kTopDragonflyDirectPadsGpioGpio29) \
    value(_, GpioGpio30, kTopDragonflyDirectPadsGpioGpio30) \
    value(_, GpioGpio31, kTopDragonflyDirectPadsGpioGpio31) \
    value(_, SpiDeviceSck, kTopDragonflyDirectPadsSpiDeviceSck) \
    value(_, SpiDeviceCsb, kTopDragonflyDirectPadsSpiDeviceCsb) \
    value(_, SpiDeviceTpmCsb, kTopDragonflyDirectPadsSpiDeviceTpmCsb) \
    value(_, Uart0Rx, kTopDragonflyDirectPadsUart0Rx) \
    value(_, SocProxySocGpi0, kTopDragonflyDirectPadsSocProxySocGpi0) \
    value(_, SocProxySocGpi1, kTopDragonflyDirectPadsSocProxySocGpi1) \
    value(_, SocProxySocGpi2, kTopDragonflyDirectPadsSocProxySocGpi2) \
    value(_, SocProxySocGpi3, kTopDragonflyDirectPadsSocProxySocGpi3) \
    value(_, SocProxySocGpi4, kTopDragonflyDirectPadsSocProxySocGpi4) \
    value(_, SocProxySocGpi5, kTopDragonflyDirectPadsSocProxySocGpi5) \
    value(_, SocProxySocGpi6, kTopDragonflyDirectPadsSocProxySocGpi6) \
    value(_, SocProxySocGpi7, kTopDragonflyDirectPadsSocProxySocGpi7) \
    value(_, SocProxySocGpi8, kTopDragonflyDirectPadsSocProxySocGpi8) \
    value(_, SocProxySocGpi9, kTopDragonflyDirectPadsSocProxySocGpi9) \
    value(_, SocProxySocGpi10, kTopDragonflyDirectPadsSocProxySocGpi10) \
    value(_, SocProxySocGpi11, kTopDragonflyDirectPadsSocProxySocGpi11) \
    value(_, SpiHost0Sck, kTopDragonflyDirectPadsSpiHost0Sck) \
    value(_, SpiHost0Csb, kTopDragonflyDirectPadsSpiHost0Csb) \
    value(_, Uart0Tx, kTopDragonflyDirectPadsUart0Tx) \
    value(_, SocProxySocGpo0, kTopDragonflyDirectPadsSocProxySocGpo0) \
    value(_, SocProxySocGpo1, kTopDragonflyDirectPadsSocProxySocGpo1) \
    value(_, SocProxySocGpo2, kTopDragonflyDirectPadsSocProxySocGpo2) \
    value(_, SocProxySocGpo3, kTopDragonflyDirectPadsSocProxySocGpo3) \
    value(_, SocProxySocGpo4, kTopDragonflyDirectPadsSocProxySocGpo4) \
    value(_, SocProxySocGpo5, kTopDragonflyDirectPadsSocProxySocGpo5) \
    value(_, SocProxySocGpo6, kTopDragonflyDirectPadsSocProxySocGpo6) \
    value(_, SocProxySocGpo7, kTopDragonflyDirectPadsSocProxySocGpo7) \
    value(_, SocProxySocGpo8, kTopDragonflyDirectPadsSocProxySocGpo8) \
    value(_, SocProxySocGpo9, kTopDragonflyDirectPadsSocProxySocGpo9) \
    value(_, SocProxySocGpo10, kTopDragonflyDirectPadsSocProxySocGpo10) \
    value(_, SocProxySocGpo11, kTopDragonflyDirectPadsSocProxySocGpo11) \
    value(_, End, kTopDragonflyDirectPadsLast + 1)
C_ONLY(UJSON_SERDE_ENUM(DirectPads, direct_pads_t, TOP_DRAGONFLY_DIRECT_PADS, WITH_UNKNOWN));

#define TOP_DRAGONFLY_MUXED_PADS(_, value) \
    value(_, Mio0, kTopDragonflyMuxedPadsMio0) \
    value(_, Mio1, kTopDragonflyMuxedPadsMio1) \
    value(_, Mio2, kTopDragonflyMuxedPadsMio2) \
    value(_, Mio3, kTopDragonflyMuxedPadsMio3) \
    value(_, Mio4, kTopDragonflyMuxedPadsMio4) \
    value(_, Mio5, kTopDragonflyMuxedPadsMio5) \
    value(_, Mio6, kTopDragonflyMuxedPadsMio6) \
    value(_, Mio7, kTopDragonflyMuxedPadsMio7) \
    value(_, Mio8, kTopDragonflyMuxedPadsMio8) \
    value(_, Mio9, kTopDragonflyMuxedPadsMio9) \
    value(_, Mio10, kTopDragonflyMuxedPadsMio10) \
    value(_, Mio11, kTopDragonflyMuxedPadsMio11) \
    value(_, End, kTopDragonflyMuxedPadsLast + 1)
C_ONLY(UJSON_SERDE_ENUM(MuxedPads, muxed_pads_t, TOP_DRAGONFLY_MUXED_PADS, WITH_UNKNOWN));
#endif

// clang-format on
#ifdef __cplusplus
}
#endif
#endif  // OPENTITAN_SW_DEVICE_LIB_TESTING_JSON_PINMUX_H_
