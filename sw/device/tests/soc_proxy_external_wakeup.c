// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/dif/dif_pwrmgr.h"
#include "sw/device/lib/dif/dif_rv_plic.h"
#include "sw/device/lib/dif/dif_soc_proxy.h"
#include "sw/device/lib/runtime/hart.h"
#include "sw/device/lib/runtime/irq.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/rv_plic_testutils.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"
#include "sw/device/lib/testing/test_framework/status.h"

OTTF_DEFINE_TEST_CONFIG();

enum {
  kPlicTarget = 0,
};

static dif_pwrmgr_t pwrmgr;
static dif_rv_plic_t plic;

// Replaces the generated `isr_testutils` handler, which identifies the
// peripheral through the top level interrupt tables rather than the device
// table.
bool ottf_handle_irq(uint32_t *exc_info, dt_instance_id_t inst_id,
                     dif_rv_plic_irq_id_t plic_id) {
  if (inst_id == dt_pwrmgr_instance_id(kDtPwrmgrAon) &&
      plic_id == dt_pwrmgr_irq_to_plic_id(kDtPwrmgrAon, kDtPwrmgrIrqWakeup)) {
    // The wakeup is meant to be the only interrupt the power manager raises in
    // this test, so anything else pending alongside it is a failure rather than
    // something to acknowledge and forget.
    dif_pwrmgr_irq_state_snapshot_t snapshot;
    CHECK_DIF_OK(dif_pwrmgr_irq_get_state(&pwrmgr, &snapshot));
    CHECK(
        snapshot == (dif_pwrmgr_irq_state_snapshot_t)(1 << kDtPwrmgrIrqWakeup),
        "Only the pwrmgr wakeup IRQ was expected to fire. IRQ state = %x",
        snapshot);
    CHECK_DIF_OK(dif_pwrmgr_irq_acknowledge(&pwrmgr, kDtPwrmgrIrqWakeup));
    return true;
  }
  return false;
}

bool test_main(void) {
  CHECK_DIF_OK(dif_pwrmgr_init_from_dt(kDtPwrmgrAon, &pwrmgr));
  CHECK_DIF_OK(dif_rv_plic_init_from_dt(kDtRvPlic, &plic));

  // Enable global and external IRQ in Ibex.
  irq_global_ctrl(true);
  irq_external_ctrl(true);

  // Enable wakeup interrupt output from Power Manager.
  dif_rv_plic_irq_id_t wakeup_plic_id =
      dt_pwrmgr_irq_to_plic_id(kDtPwrmgrAon, kDtPwrmgrIrqWakeup);
  rv_plic_testutils_irq_range_enable(&plic, kPlicTarget, wakeup_plic_id,
                                     wakeup_plic_id);
  CHECK_DIF_OK(dif_pwrmgr_irq_set_enabled(&pwrmgr, kDtPwrmgrIrqWakeup,
                                          kDifToggleEnabled));

  // Get currently enabled sources for wakeup requests in Power Manager.
  dif_pwrmgr_request_sources_t wakeup_req_srcs;
  CHECK_DIF_OK(dif_pwrmgr_get_request_sources(&pwrmgr, kDifPwrmgrReqTypeWakeup,
                                              &wakeup_req_srcs));

  // Enable external wakeup request in Power Manager.
  dif_pwrmgr_request_sources_t ext_wkup_req;
  CHECK_DIF_OK(dif_pwrmgr_find_request_source(
      &pwrmgr, kDifPwrmgrReqTypeWakeup, dt_soc_proxy_instance_id(kDtSocProxy),
      kDtSocProxyWakeupWkupExternalReq, &ext_wkup_req));
  wakeup_req_srcs |= ext_wkup_req;
  CHECK_DIF_OK(dif_pwrmgr_set_request_sources(
      &pwrmgr, kDifPwrmgrReqTypeWakeup, wakeup_req_srcs, kDifToggleEnabled));
  LOG_INFO("Power Manager configured.");
  CHECK_DIF_OK(
      dif_pwrmgr_low_power_set_enabled(&pwrmgr, /*new_state=*/kDifToggleEnabled,
                                       /*sync_state=*/kDifToggleEnabled));
  test_status_set(kTestStatusInWfi);
  wait_for_interrupt();
  test_status_set(kTestStatusInTest);

  // Wait for wakeup request to show up in Power Manager.
  while (true) {
    dif_pwrmgr_request_sources_t cur_wakeup_srcs;
    CHECK_DIF_OK(dif_pwrmgr_get_current_request_sources(
        &pwrmgr, kDifPwrmgrReqTypeWakeup, &cur_wakeup_srcs));
    if (cur_wakeup_srcs & ext_wkup_req) {
      LOG_INFO("External wakeup request detected.");
      break;
    }
    busy_spin_micros(5);
  }

  return true;
}
