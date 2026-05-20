// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/silicon_creator/lib/drivers/pinmux.h"

#include "gtest/gtest.h"
#include "sw/device/lib/arch/device.h"
#include "sw/device/lib/base/hardened.h"
#include "sw/device/lib/base/mmio.h"
#include "sw/device/lib/base/mock_abs_mmio.h"
#include "sw/device/silicon_creator/lib/base/chip.h"
#include "sw/device/silicon_creator/lib/base/mock_csr.h"
#include "sw/device/silicon_creator/lib/drivers/mock_otp.h"
#include "sw/device/silicon_creator/testing/rom_test.h"

#include "hw/top/otp_ctrl_regs.h"
#include "hw/top/pinmux_regs.h"
#include "hw/top_egret/sw/autogen/top_egret.h"

namespace pinmux_unittest {
namespace {
using ::testing::Return;

class PinmuxTest : public rom_test::RomTest {
 protected:
  uint32_t base_ = TOP_EGRET_PINMUX_AON_BASE_ADDR;
  rom_test::MockAbsMmio mmio_;
  rom_test::MockOtp otp_;
  mock_csr::MockCsr csr_;
};

class InitTest : public PinmuxTest {
 protected:
  /**
   * Set to track which peripheral inputs have already been configured.
   */
  std::set<top_egret_pinmux_peripheral_in_t> configured_in_;

  /**
   * Register the configuration of the input peripheral in the tracking
   * set and return its computed address.
   *
   * Triggers a test failure if the input has already been registered.
   */
  uint32_t RegInSel(top_egret_pinmux_peripheral_in_t index) {
    EXPECT_TRUE(index >= 0 && index < kTopEgretPinmuxPeripheralInLast);
    EXPECT_TRUE(configured_in_.insert(index).second);
    return base_ + PINMUX_MIO_PERIPH_INSEL_0_REG_OFFSET +
           static_cast<uint32_t>(index) * sizeof(uint32_t);
  }

  uint32_t RegPadAttr(top_egret_muxed_pads_t pad) {
    return base_ + PINMUX_MIO_PAD_ATTR_0_REG_OFFSET +
           static_cast<uint32_t>(pad) * sizeof(uint32_t);
  }

  /**
   * Set to track which MIO outputs have already been configured.
   */
  std::set<top_egret_pinmux_mio_out_t> configured_out_;

  /**
   * Register the configuration of the MIO output in the tracking
   * set and return its computed address.
   *
   * Triggers a test failure if the input has already been registered.
   */
  uint32_t RegOutSel(top_egret_pinmux_mio_out_t index) {
    EXPECT_TRUE(index >= 0 && index < kTopEgretPinmuxMioOutLast);
    EXPECT_TRUE(configured_out_.insert(index).second);
    return base_ + PINMUX_MIO_OUTSEL_0_REG_OFFSET +
           static_cast<uint32_t>(index) * sizeof(uint32_t);
  };
};

TEST_F(InitTest, PadAttrPropagationDelay) {
  const uint64_t kCpuClockPeriodNs = 1'000'000'000 / kClockFreqCpuHz;
  const uint64_t kCpuCyclesIn5Micros = 5000 / kCpuClockPeriodNs;
  EXPECT_EQ(PINMUX_PAD_ATTR_PROP_CYCLES, kCpuCyclesIn5Micros);
}

TEST_F(InitTest, WithBootstrap) {
  // The inputs that will be configured.
  EXPECT_CALL(otp_,
              read32(OTP_CTRL_PARAM_OWNER_SW_CFG_ROM_BOOTSTRAP_DIS_OFFSET))
      .WillOnce(Return(kHardenedBoolFalse));
  EXPECT_ABS_WRITE32(RegPadAttr(kTopEgretMuxedPadsIoc0),
                     {{PINMUX_MIO_PAD_ATTR_0_PULL_EN_0_BIT, 1}});
  EXPECT_ABS_WRITE32(RegPadAttr(kTopEgretMuxedPadsIoc1),
                     {{PINMUX_MIO_PAD_ATTR_0_PULL_EN_0_BIT, 1}});
  EXPECT_ABS_WRITE32(RegPadAttr(kTopEgretMuxedPadsIoc2),
                     {{PINMUX_MIO_PAD_ATTR_0_PULL_EN_0_BIT, 1}});
  EXPECT_CSR_WRITE(CSR_REG_MCYCLE, 0);
  for (size_t i = 0; i < 6; ++i) {
    EXPECT_CSR_READ(CSR_REG_MCYCLE, i * 100);
  }
  EXPECT_ABS_WRITE32(RegInSel(kTopEgretPinmuxPeripheralInGpioGpio22),
                     kTopEgretPinmuxInselIoc0)
  EXPECT_ABS_WRITE32(RegInSel(kTopEgretPinmuxPeripheralInGpioGpio23),
                     kTopEgretPinmuxInselIoc1)
  EXPECT_ABS_WRITE32(RegInSel(kTopEgretPinmuxPeripheralInGpioGpio24),
                     kTopEgretPinmuxInselIoc2)

  // UART configuration: RX line pulled up, RX is IOC3, TX is IOC4.
  EXPECT_ABS_WRITE32(RegPadAttr(kTopEgretMuxedPadsIoc3),
                     {{PINMUX_MIO_PAD_ATTR_0_PULL_EN_0_BIT, 1},
                      {PINMUX_MIO_PAD_ATTR_0_PULL_SELECT_0_BIT, 1}});
  EXPECT_ABS_WRITE32(RegInSel(kTopEgretPinmuxPeripheralInUart0Rx),
                     kTopEgretPinmuxInselIoc3);
  EXPECT_ABS_WRITE32(RegOutSel(kTopEgretPinmuxMioOutIoc4),
                     kTopEgretPinmuxOutselUart0Tx);

  pinmux_init();
}

TEST_F(InitTest, WithoutBootstrap) {
  // The inputs that will be configured.
  EXPECT_CALL(otp_,
              read32(OTP_CTRL_PARAM_OWNER_SW_CFG_ROM_BOOTSTRAP_DIS_OFFSET))
      .WillOnce(Return(kHardenedBoolTrue));

  // UART configuration: RX line pulled up, RX is IOC3, TX is IOC4.
  EXPECT_ABS_WRITE32(RegPadAttr(kTopEgretMuxedPadsIoc3),
                     {{PINMUX_MIO_PAD_ATTR_0_PULL_EN_0_BIT, 1},
                      {PINMUX_MIO_PAD_ATTR_0_PULL_SELECT_0_BIT, 1}});
  EXPECT_ABS_WRITE32(RegInSel(kTopEgretPinmuxPeripheralInUart0Rx),
                     kTopEgretPinmuxInselIoc3);
  EXPECT_ABS_WRITE32(RegOutSel(kTopEgretPinmuxMioOutIoc4),
                     kTopEgretPinmuxOutselUart0Tx);

  pinmux_init();
}

TEST_F(InitTest, Uart0TxOnly) {
  // The outputs that will be configured.
  EXPECT_ABS_WRITE32(RegOutSel(kTopEgretPinmuxMioOutIoc4),
                     kTopEgretPinmuxOutselUart0Tx);

  pinmux_init_uart0_tx();
}

}  // namespace
}  // namespace pinmux_unittest
