// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/base/abs_mmio.h"
#include "sw/device/lib/base/csr.h"
#include "sw/device/lib/base/hardened.h"
#include "sw/device/lib/base/macros.h"
#include "sw/device/silicon_creator/lib/base/chip.h"
#include "sw/device/silicon_creator/lib/drivers/otp.h"
#include "sw/device/silicon_creator/lib/drivers/pinmux.h"

#include "hw/top/otp_ctrl_regs.h"  // Generated
#include "hw/top/pinmux_regs.h"    // Generated
#include "hw/top_darjeeling/sw/autogen/top_darjeeling.h"

enum {
  /**
   * Base address of the pinmux registers.
   */
  kBase = TOP_DARJEELING_PINMUX_AON_BASE_ADDR,
};

/**
 * A peripheral input and MIO pad to link it to.
 */
typedef struct pinmux_input {
  top_darjeeling_pinmux_peripheral_in_t periph;
  top_darjeeling_pinmux_insel_t insel;
  top_darjeeling_muxed_pads_t pad;
} pinmux_input_t;

/**
 * An MIO pad and a peripheral output to link it to.
 */
typedef struct pinmux_output {
  top_darjeeling_pinmux_mio_out_t mio;
  top_darjeeling_pinmux_outsel_t outsel;
  top_darjeeling_muxed_pads_t pad;
} pinmux_output_t;

/**
 * Enables pull-down for the specified pad.
 *
 * @param pad A MIO pad.
 */
static void enable_pull_down(top_darjeeling_muxed_pads_t pad) {
  uint32_t reg =
      bitfield_bit32_write(0, PINMUX_MIO_PAD_ATTR_0_PULL_EN_0_BIT, true);
  abs_mmio_write32(
      kBase + PINMUX_MIO_PAD_ATTR_0_REG_OFFSET + pad * sizeof(uint32_t), reg);
}

void pinmux_init(void) {}
