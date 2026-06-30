// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hw/top/dt/clkmgr.h"
#include "hw/top/dt/rstmgr.h"
#ifdef HAS_SENSOR_CTRL
#include "hw/top/dt/sensor_ctrl.h"
#endif
#include "sw/device/lib/base/memory.h"
#ifdef HAS_SENSOR_CTRL
#include "sw/device/lib/dif/dif_sensor_ctrl.h"
#endif
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/aon_timer_testutils.h"
#include "sw/device/lib/testing/clkmgr_testutils.h"
#include "sw/device/lib/testing/rstmgr_testutils.h"
#ifdef HAS_SENSOR_CTRL
#include "sw/device/lib/testing/sensor_ctrl_testutils.h"
#endif
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_alerts.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"

OTTF_DEFINE_TEST_CONFIG();

/**
 * This test measures clock counts with clkmgr frequency measurements and
 * 100 measurements per round. Measurement errors (fast or slow clocks) are
 * recorded as recoverable error in clkmgr.
 *
 * This test configures the clock thresholds so it generates errors, after 100
 * measurements it checks that some errors are found, then a reset is triggered,
 * and it checks the measurements should be disabled, and no errors should be
 * reported.
 */
enum {
  kWaitForCSRPolling = 1,  // 1us
  kMeasurementsPerRound = 100,
};

// Configure the counters to trigger an error by setting them correctly
// and then halving each of the thresholds. Triggering errors can also be
// done by configuring the clock thresholds for external clock without
// configuring the external clock to be active; however, that is not
// possible for tops without support for external clocks, like dragonfly.
void configure_clock_thresholds_for_failures(const dif_clkmgr_t *clkmgr) {
  CHECK_STATUS_OK(clkmgr_testutils_enable_clock_counts_with_expected_thresholds(
      clkmgr, /*jitter_enabled=*/false, /*external_clk=*/false,
      /*low_speed=*/true));
  dt_clkmgr_t clkmgr_dt;
  CHECK_DIF_OK(dif_clkmgr_get_dt(clkmgr, &clkmgr_dt));

  for (size_t clk = 0; clk < dt_clkmgr_measurable_clock_count(clkmgr_dt);
       ++clk) {
    uint32_t min_threshold;
    uint32_t max_threshold;
    CHECK_DIF_OK(dif_clkmgr_measure_counts_get_thresholds(
        clkmgr, clk, &min_threshold, &max_threshold));
    CHECK_STATUS_OK(clkmgr_testutils_enable_clock_count(
        clkmgr, clk, min_threshold / 2, max_threshold / 2));
  }
}

bool test_main(void) {
  dif_clkmgr_t clkmgr;
  dif_rstmgr_t rstmgr;

  uint32_t delay_micros = 0;
  CHECK_STATUS_OK(aon_timer_testutils_get_us_from_aon_cycles(
      kMeasurementsPerRound, &delay_micros));

  CHECK_DIF_OK(dif_clkmgr_init_from_dt(kDtClkmgrAon, &clkmgr));
  CHECK_DIF_OK(dif_rstmgr_init_from_dt(kDtRstmgrAon, &rstmgr));

  // The test will trigger many measurement errors which cause an alert that
  // fires constantly with each new measurement and cannot really be
  // acknowledged. Ignore this alert for the purpose of this test.
  CHECK_STATUS_OK(ottf_alerts_ignore_alert(
      dt_clkmgr_alert_to_alert_id(kDtClkmgrAon, kDtClkmgrAlertRecovFault)));

#ifdef HAS_SENSOR_CTRL
  dif_sensor_ctrl_t sensor_ctrl;
  CHECK_DIF_OK(dif_sensor_ctrl_init_from_dt(kSensorCtrl, &sensor_ctrl));

  LOG_INFO("TEST: wait for ast init");
  IBEX_SPIN_FOR(sensor_ctrl_ast_init_done(&sensor_ctrl), 1000);
  LOG_INFO("TEST: done ast init");
#endif

  if (UNWRAP(
          rstmgr_testutils_reset_info_any(&rstmgr, kDifRstmgrResetInfoPor))) {
    LOG_INFO("POR reset");

    configure_clock_thresholds_for_failures(&clkmgr);
    busy_spin_micros(delay_micros);

    // Check we get errors, but let the counters keep going.
    dif_clkmgr_recov_err_codes_t err_codes;
    CHECK_DIF_OK(dif_clkmgr_recov_err_code_get_codes(&clkmgr, &err_codes));
    CHECK(err_codes != 0);

    // Trigger a rstmgr SW reset.
    CHECK_DIF_OK(dif_rstmgr_software_device_reset(&rstmgr));
  } else if (UNWRAP(rstmgr_testutils_reset_info_any(&rstmgr,
                                                    kDifRstmgrResetInfoSw))) {
    LOG_INFO("Back from rstmgr SW reset");
    bool all_disabled = UNWRAP(clkmgr_testutils_check_measurement_enables(
        &clkmgr, kDifToggleDisabled));
    CHECK(all_disabled);

    CHECK_STATUS_OK(clkmgr_testutils_check_measurement_counts(&clkmgr));
    return true;
  } else {
    dif_rstmgr_reset_info_bitfield_t rst_info;
    CHECK_DIF_OK(dif_rstmgr_reset_info_get(&rstmgr, &rst_info));
    LOG_ERROR("Unexpected rst_info 0x%x", rst_info);
    return false;
  }
  return true;
}
