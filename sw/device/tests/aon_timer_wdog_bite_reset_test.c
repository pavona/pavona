// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include <limits.h>
#include <stdbool.h>
#include <stdint.h>

#include "sw/device/lib/base/math.h"
#include "sw/device/lib/base/mmio.h"
#include "sw/device/lib/dif/dif_aon_timer.h"
#include "sw/device/lib/dif/dif_pwrmgr.h"
#include "sw/device/lib/dif/dif_rstmgr.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/aon_timer_testutils.h"
#include "sw/device/lib/testing/pwrmgr_testutils.h"
#include "sw/device/lib/testing/rstmgr_testutils.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"

static const dt_pwrmgr_t kPwrmgrDt = 0;
static_assert(kDtPwrmgrCount == 1, "this library expects exactly one pwrmgr");
static const dt_rstmgr_t kRstmgrDt = 0;
static_assert(kDtRstmgrCount == 1, "this library expects exactly one rstmgr");
static const dt_aon_timer_t kAonTimerDt = 0;
static_assert(kDtAonTimerCount == 1,
              "this library expects exactly one aon_timer");

OTTF_DEFINE_TEST_CONFIG();
// This test needs to work for tops with different clock frequencies.
// Slow tops like egret take 5us per aon clock cycle, while faster ones
// like dragonfly take 16ns per aon cycle. On the other hand, the test
// uses busy_spin_micros, which counts in microseconds.
// The strategy this test uses to deal with this is to specify the bark
// and bite times in aon clock cycles, except the resulting time must
// exceed 5us.

enum {
  /**
   * The minimum number of microseconds for either bark and bite timeout.
   */
  kMinimumNumMicros = 5,

  /**
   * The minimum number of aon cycles for the same.
   */
  kMinimumAonCycles = 20,
};

static dif_pwrmgr_request_sources_t wakeup_sources;
static dif_pwrmgr_request_sources_t reset_sources;

/**
 * Configure the wdog.
 */
static void config_wdog(const dif_aon_timer_t *aon_timer,
                        const dif_pwrmgr_t *pwrmgr, uint32_t bark_cycles,
                        uint32_t bite_cycles) {
  // Set wdog as a reset source.
  CHECK_DIF_OK(dif_pwrmgr_set_request_sources(
      pwrmgr, kDifPwrmgrReqTypeReset, reset_sources, kDifToggleEnabled));

  // Setup the wdog bark and bite timeouts.
  CHECK_STATUS_OK(aon_timer_testutils_watchdog_config(aon_timer, bark_cycles,
                                                      bite_cycles, false));
}

/**
 * Execute the aon timer wdog bite reset test.
 */
static void wdog_bite_test(const dif_aon_timer_t *aon_timer,
                           const dif_pwrmgr_t *pwrmgr, uint32_t bark_aon_cycles,
                           uint32_t wait_us) {
  config_wdog(aon_timer, pwrmgr, bark_aon_cycles, 2 * bark_aon_cycles);

  // Wait bark time and check that the bark interrupt requested.
  busy_spin_micros(wait_us);
  bool is_pending = false;
  CHECK_DIF_OK(dif_aon_timer_irq_is_pending(
      aon_timer, kDifAonTimerIrqWdogTimerBark, &is_pending));
  CHECK(is_pending, "Wdog bark irq did not rise after %u microseconds",
        wait_us);

  // Wait for the remaining time to the wdog bite.
  busy_spin_micros(wait_us);
  // If we arrive here the test must fail.
  CHECK(false, "Timeout waiting for Wdog bite reset!");
}

/**
 * Execute the aon timer wdog bite reset during sleep test.
 */
static void sleep_wdog_bite_test(const dif_aon_timer_t *aon_timer,
                                 const dif_pwrmgr_t *pwrmgr,
                                 uint32_t bark_aon_cycles) {
  config_wdog(aon_timer, pwrmgr, bark_aon_cycles, 2 * bark_aon_cycles);

  // Program the pwrmgr to go to deep sleep state (clocks off).
  CHECK_STATUS_OK(pwrmgr_testutils_enable_low_power(pwrmgr, wakeup_sources, 0));
  // Enter in low power mode.
  wait_for_interrupt();
  // If we arrive here the test must fail.
  CHECK(false, "Fail to enter in low power mode!");
}

static uint32_t compute_bark_aon_cycles(void) {
  uint32_t bark_aon_cycles = kMinimumAonCycles;
  uint32_t aon_cycles_for_min_micros;
  CHECK_STATUS_OK(aon_timer_testutils_get_aon_cycles_32_from_us(
      kMinimumNumMicros, &aon_cycles_for_min_micros));
  if (bark_aon_cycles < aon_cycles_for_min_micros) {
    bark_aon_cycles = aon_cycles_for_min_micros;
  }
  return bark_aon_cycles;
}

static uint32_t compute_wait_us(uint32_t bark_aon_cycles) {
  uint32_t bark_time_us;
  CHECK_STATUS_OK(aon_timer_testutils_get_us_from_aon_cycles(bark_aon_cycles,
                                                             &bark_time_us));
  LOG_INFO("bark_time_us = %d", bark_time_us);
  // The `intr_state` takes 3 aon clock cycles to rise plus 2 extra cycles as a
  // precaution.
  uint32_t extra_time_us;
  CHECK_STATUS_OK(
      aon_timer_testutils_get_us_from_aon_cycles(3 + 2, &extra_time_us));
  if (extra_time_us == 0) {
    extra_time_us = 1;
  }
  uint32_t wait_us = bark_time_us + extra_time_us;
  LOG_INFO("wait_us = %d", wait_us);
  return wait_us;
}

bool test_main(void) {
  // Initialize pwrmgr.
  dif_pwrmgr_t pwrmgr;
  CHECK_DIF_OK(dif_pwrmgr_init_from_dt(kPwrmgrDt, &pwrmgr));

  // Find wakeup and reset sources.
  CHECK_DIF_OK(dif_pwrmgr_find_request_source(
      &pwrmgr, kDifPwrmgrReqTypeReset, dt_aon_timer_instance_id(kAonTimerDt),
      kDtAonTimerResetReqAonTimer, &reset_sources));
  CHECK_DIF_OK(dif_pwrmgr_find_request_source(
      &pwrmgr, kDifPwrmgrReqTypeWakeup, dt_aon_timer_instance_id(kAonTimerDt),
      kDtAonTimerWakeupWkupReq, &wakeup_sources));

  // Initialize rstmgr to check the reset reason.
  dif_rstmgr_t rstmgr;
  CHECK_DIF_OK(dif_rstmgr_init_from_dt(kRstmgrDt, &rstmgr));

  // Initialize aon timer to use the wdog.
  dif_aon_timer_t aon_timer;
  CHECK_DIF_OK(dif_aon_timer_init_from_dt(kAonTimerDt, &aon_timer));

  uint32_t bark_aon_cycles = compute_bark_aon_cycles();
  uint32_t wait_us = compute_wait_us(bark_aon_cycles);

  // Check if there was a HW reset caused by the wdog bite.
  dif_rstmgr_reset_info_bitfield_t rst_info;
  rst_info = rstmgr_testutils_reason_get();
  rstmgr_testutils_reason_clear();

  CHECK(rst_info == kDifRstmgrResetInfoPor ||
            rst_info == kDifRstmgrResetInfoWatchdog ||
            rst_info ==
                (kDifRstmgrResetInfoWatchdog | kDifRstmgrResetInfoLowPowerExit),
        "Wrong reset reason %02X", rst_info);

  if (rst_info == kDifRstmgrResetInfoPor) {
    LOG_INFO("Booting for the first time, setting wdog");
    // Executing the wdog bite reset test.
    wdog_bite_test(&aon_timer, &pwrmgr, bark_aon_cycles, wait_us);
  } else if (rst_info == kDifRstmgrResetInfoWatchdog) {
    LOG_INFO("Booting for the second time due to wdog bite reset");
    // Executing the wdog bite reset during sleep test.
    sleep_wdog_bite_test(&aon_timer, &pwrmgr, bark_aon_cycles);
  } else if (rst_info ==
             (kDifRstmgrResetInfoWatchdog | kDifRstmgrResetInfoLowPowerExit)) {
    LOG_INFO("Booting for the third time due to wdog bite reset during sleep");
    return true;
  }

  return false;
}
