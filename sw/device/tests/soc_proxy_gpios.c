// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/dif/dif_pinmux.h"
#include "sw/device/lib/dif/dif_soc_proxy.h"
#include "sw/device/lib/runtime/irq.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"
#include "sw/device/lib/testing/test_framework/status.h"

#include "hw/top_dragonfly/sw/autogen/top_dragonfly.h"

OTTF_DEFINE_TEST_CONFIG();

bool test_main(void) {
  dif_pinmux_t pinmux = {};

  // Map muxable SoC GPIs in pinmux.
  top_dragonfly_pinmux_peripheral_in_t peripheral_in[] = {
      kTopDragonflyPinmuxPeripheralInSocProxySocGpi12,
      kTopDragonflyPinmuxPeripheralInSocProxySocGpi13,
      kTopDragonflyPinmuxPeripheralInSocProxySocGpi14,
      kTopDragonflyPinmuxPeripheralInSocProxySocGpi15,
  };
  top_dragonfly_pinmux_insel_t insel[] = {
      kTopDragonflyPinmuxInselMio4,
      kTopDragonflyPinmuxInselMio5,
      kTopDragonflyPinmuxInselMio6,
      kTopDragonflyPinmuxInselMio7,
  };
  static_assert(ARRAYSIZE(peripheral_in) == ARRAYSIZE(insel),
                "Illegal pinmux input configuration arrays!");
  for (size_t i = 0; i < ARRAYSIZE(peripheral_in); i++) {
    CHECK_DIF_OK(dif_pinmux_input_select(&pinmux, peripheral_in[i], insel[i]));
  }
  LOG_INFO("Muxable SoC GPIs mapped.");

  // Map muxable SoC GPOs in pinmux.
  top_dragonfly_pinmux_mio_out_t mio_out[] = {
      kTopDragonflyPinmuxMioOutMio4,
      kTopDragonflyPinmuxMioOutMio5,
      kTopDragonflyPinmuxMioOutMio6,
      kTopDragonflyPinmuxMioOutMio7,
  };
  top_dragonfly_pinmux_outsel_t outsel[] = {
      kTopDragonflyPinmuxOutselSocProxySocGpo12,
      kTopDragonflyPinmuxOutselSocProxySocGpo13,
      kTopDragonflyPinmuxOutselSocProxySocGpo14,
      kTopDragonflyPinmuxOutselSocProxySocGpo15,
  };
  static_assert(ARRAYSIZE(mio_out) == ARRAYSIZE(outsel),
                "Illegal pinmux output configuration arrays!");
  for (size_t i = 0; i < ARRAYSIZE(mio_out); i++) {
    CHECK_DIF_OK(dif_pinmux_output_select(&pinmux, mio_out[i], outsel[i]));
  }
  LOG_INFO("Muxable SoC GPOs mapped.");

  return true;
}
