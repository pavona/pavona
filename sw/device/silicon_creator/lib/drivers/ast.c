// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/silicon_creator/lib/drivers/ast.h"

#include "sw/device/lib/arch/device.h"
#include "sw/device/lib/base/abs_mmio.h"
#include "sw/device/lib/base/csr.h"
#include "sw/device/lib/base/multibits.h"
#include "sw/device/silicon_creator/lib/drivers/otp.h"

#include "hw/top/ast_regs.h"
#include "hw/top/otp_ctrl_regs.h"

#ifdef TOP_EARLGREY
#include "hw/top/sensor_ctrl_regs.h"
#include "hw/top_earlgrey/sw/autogen/top_earlgrey.h"

enum {
  kBaseSensorCtrl = TOP_EARLGREY_SENSOR_CTRL_AON_BASE_ADDR,
  kBaseAst = TOP_EARLGREY_AST_BASE_ADDR,
};
#endif

#ifdef TOP_DARJEELING
#include "hw/top_darjeeling/sw/autogen/top_darjeeling.h"

enum {
  kBaseAst = TOP_DARJEELING_AST_BASE_ADDR,
};
#endif

#ifndef OT_PLATFORM_RV32
// Provide a definition for off-target unit tests.
const uint32_t kAstCheckPollCpuCycles = 10000;
#endif

rom_error_t ast_check(lifecycle_state_t lc_state) {
  // In some lifecycle states we want to continue the boot process even if the
  // AST is not initialized. Note that in these states OTP may not have been
  // configured.
  switch (launder32(lc_state)) {
    case kLcStateTest:
      HARDENED_CHECK_EQ(lc_state, kLcStateTest);
      return kErrorOk;
    case kLcStateRma:
      HARDENED_CHECK_EQ(lc_state, kLcStateRma);
      return kErrorOk;
    case kLcStateDev:
      HARDENED_CHECK_EQ(lc_state, kLcStateDev);
      break;
    case kLcStateProd:
      HARDENED_CHECK_EQ(lc_state, kLcStateProd);
      break;
    case kLcStateProdEnd:
      HARDENED_CHECK_EQ(lc_state, kLcStateProdEnd);
      break;
    default:
      HARDENED_TRAP();
  }

  // AST initialization may take up to 100us. It is most likely already complete
  // at this point but for resilience poll for up to 100us.
  uint32_t mcycle;
  rom_error_t res = kErrorAstInitNotDone;
  CSR_WRITE(CSR_REG_MCYCLE, 0);
  do {
    CSR_READ(CSR_REG_MCYCLE, &mcycle);
    hardened_bool_t init_done = ast_init_done();
    if (init_done != kHardenedBoolFalse) {
      static_assert(kErrorOk == (rom_error_t)kHardenedBoolTrue,
                    "kErrorOk must be equal to kHardenedBoolTrue");
      res = (rom_error_t)init_done;
      break;
    }
  } while (mcycle < kAstCheckPollCpuCycles);

  return res;
}

#ifdef TOP_EARLGREY
OT_WARN_UNUSED_RESULT
static bool done_bit_get(void) {
  uint32_t reg =
      abs_mmio_read32(kBaseSensorCtrl + SENSOR_CTRL_STATUS_REG_OFFSET);
  return bitfield_bit32_read(reg, SENSOR_CTRL_STATUS_AST_INIT_DONE_BIT);
}
#endif

hardened_bool_t ast_init_done(void) {
  static_assert(kHardenedBoolTrue == 0x739,
                "This function expects kHardenedBoolTrue to be 0x739");

// No sensor_ctrl on Darjeeling
#ifdef TOP_EARLGREY
  // The code below reads the AST_INIT_DONE bit twice and modifies `res` with
  // the result of each attempt. `res` should be `kHardenedBoolTrue` if all
  // attempts return true.
  hardened_bool_t res = 0x631;
  res |= (hardened_bool_t)done_bit_get() << 3;
  res |= (hardened_bool_t)done_bit_get() << 8;

  if (res != kHardenedBoolTrue) {
    return kHardenedBoolFalse;
  }
  return res;
#else
  return kHardenedBoolTrue;
#endif
}
