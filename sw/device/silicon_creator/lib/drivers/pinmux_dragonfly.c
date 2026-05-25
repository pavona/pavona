// Copyright lowRISC contributors.
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hw/top/dt/pinmux.h"
#include "sw/device/lib/base/abs_mmio.h"
#include "sw/device/lib/base/csr.h"
#include "sw/device/lib/base/hardened.h"
#include "sw/device/lib/base/macros.h"
#include "sw/device/silicon_creator/lib/base/chip.h"
#include "sw/device/silicon_creator/lib/drivers/otp.h"
#include "sw/device/silicon_creator/lib/drivers/pinmux.h"

#include "hw/top/otp_ctrl_regs.h"  // Generated
#include "hw/top/pinmux_regs.h"    // Generated

/**
 * Base address of the pinmux registers.
 */
static inline uint32_t pinmux_reg_base(void) {
  return dt_pinmux_reg_block(kDtPinmuxAon, kDtPinmuxRegBlockCore);
}

/**
 * A peripheral input and MIO pad to link it to.
 */
typedef struct pinmux_input {
  dt_pinmux_peripheral_in_t periph;
  dt_pinmux_insel_t insel;
  dt_pinmux_muxed_pad_t pad;
} pinmux_input_t;

/**
 * An MIO pad and a peripheral output to link it to.
 */
typedef struct pinmux_output {
  dt_pinmux_mio_out_t mio;
  dt_pinmux_outsel_t outsel;
  dt_pinmux_muxed_pad_t pad;
} pinmux_output_t;

/**
 * Enables pull-down for the specified pad.
 *
 * @param pad A MIO pad.
 */
static void enable_pull_down(dt_pinmux_muxed_pad_t pad) {
  uint32_t reg =
      bitfield_bit32_write(0, PINMUX_MIO_PAD_ATTR_0_PULL_EN_0_BIT, true);
  abs_mmio_write32(pinmux_reg_base() + PINMUX_MIO_PAD_ATTR_0_REG_OFFSET +
                       pad * sizeof(uint32_t),
                   reg);
}

void pinmux_init(void) {}
