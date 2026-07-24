// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/tests/pwrmgr_sleep_resets_lib.h"

#include <assert.h>
#include <limits.h>
#include <stdbool.h>
#include <stdint.h>

#include "sw/device/lib/base/abs_mmio.h"
#include "sw/device/lib/base/math.h"
#include "sw/device/lib/base/mmio.h"
#include "sw/device/lib/dif/dif_alert_handler.h"
#include "sw/device/lib/dif/dif_aon_timer.h"
#if defined(OPENTITAN_IS_EGRET)
#include "sw/device/lib/dif/dif_flash_ctrl.h"
#endif
#include "sw/device/lib/dif/dif_pinmux.h"
#include "sw/device/lib/dif/dif_pwrmgr.h"
#include "sw/device/lib/dif/dif_rstmgr.h"
#include "sw/device/lib/dif/dif_rv_plic.h"
#include "sw/device/lib/dif/dif_rv_timer.h"

#if defined(OPENTITAN_IS_EGRET)
#include "sw/device/lib/dif/dif_sysrst_ctrl.h"
#endif
#include "sw/device/lib/runtime/irq.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/alert_handler_testutils.h"
#include "sw/device/lib/testing/aon_timer_testutils.h"
#include "sw/device/lib/testing/pwrmgr_testutils.h"
#include "sw/device/lib/testing/rstmgr_testutils.h"
#include "sw/device/lib/testing/rv_plic_testutils.h"
#include "sw/device/lib/testing/test_framework/check.h"

static const uint32_t kPlicTarget = 0;

static_assert(
    kWdogBarkMicros < kWdogBiteMicros &&
        kWdogBarkMicros > kEscalationPhase0Micros &&
        kWdogBarkMicros < (kEscalationPhase0Micros + kEscalationPhase1Micros) &&
        kWdogBiteMicros < (kEscalationPhase0Micros + kEscalationPhase1Micros),
    "The wdog bark and bite should happen during the escalation phase 1");

#if defined(OPENTITAN_IS_EGRET)
dif_flash_ctrl_state_t *flash_ctrl;
#endif
dif_rv_plic_t *plic;
dif_alert_handler_t *alert_handler;
dif_aon_timer_t *aon_timer;
dif_pwrmgr_t *pwrmgr;
#if defined(OPENTITAN_IS_EGRET)
dif_sysrst_ctrl_t *sysrst_ctrl_aon;
#endif
dif_rstmgr_t *rstmgr;

#if defined(OPENTITAN_IS_EGRET)
dif_flash_ctrl_state_t flash_ctrl_actual;
#endif
dif_rv_plic_t plic_actual;
dif_alert_handler_t alert_handler_actual;
dif_aon_timer_t aon_timer_actual;
dif_pwrmgr_t pwrmgr_actual;
#if defined(OPENTITAN_IS_EGRET)
dif_sysrst_ctrl_t sysrst_ctrl_aon_actual;
#endif
dif_rstmgr_t rstmgr_actual;

static dif_pwrmgr_request_sources_t aon_timer_wakeup_sources;
static dif_pwrmgr_request_sources_t sysrst_ctrl_wakeup_sources;

static const dt_rstmgr_t kRstmgrDt = 0;
static_assert(kDtRstmgrCount == 1, "this test expects a rstmgr");
static const dt_pwrmgr_t kPwrmgrDt = 0;
static_assert(kDtPwrmgrCount == 1, "this library expects exactly one pwrmgr");
static const dt_alert_handler_t kAlertHandlerDt = 0;
static_assert(kDtAlertHandlerCount == 1,
              "this library expects exactly one alert_handler");
static const dt_aon_timer_t kAonTimerDt = 0;
static_assert(kDtAonTimerCount == 1,
              "this library expects exactly one aon_timer");
#if defined(OPENTITAN_IS_EGRET)
static const dt_flash_ctrl_t kFlashCtrlDt = 0;
static_assert(kDtFlashCtrlCount >= 1,
              "this test expects at least one flash_ctrl");
static_assert(kDtSysrstCtrlCount >= 1,
              "this test expects at least one sysrst_ctrl");
static const dt_sysrst_ctrl_t kSysrstCtrlDt = 0;
#endif
static const dt_rv_plic_t kRvPlicDt = 0;
static_assert(kDtRvPlicCount >= 1, "this test expects at least one rv_plic");

void init_peripherals(void) {
  // Initialize pwrmgr.
  CHECK_DIF_OK(dif_pwrmgr_init_from_dt(kPwrmgrDt, &pwrmgr_actual));
  pwrmgr = &pwrmgr_actual;

#if defined(OPENTITAN_IS_EGRET)
  // Initialize sysrst_ctrl.
  CHECK_DIF_OK(
      dif_sysrst_ctrl_init_from_dt(kSysrstCtrlDt, &sysrst_ctrl_aon_actual));
  sysrst_ctrl_aon = &sysrst_ctrl_aon_actual;
#endif

  // Initialize rstmgr to check the reset reason.
  CHECK_DIF_OK(dif_rstmgr_init_from_dt(kRstmgrDt, &rstmgr_actual));
  rstmgr = &rstmgr_actual;

  // Initialize aon timer to use the wdog.
  CHECK_DIF_OK(dif_aon_timer_init_from_dt(kAonTimerDt, &aon_timer_actual));
  aon_timer = &aon_timer_actual;

#if defined(OPENTITAN_IS_EGRET)
  // Initialize flash_ctrl
  CHECK_DIF_OK(
      dif_flash_ctrl_init_state_from_dt(&flash_ctrl_actual, kFlashCtrlDt));
  flash_ctrl = &flash_ctrl_actual;
#endif

  // Initialize plic.
  CHECK_DIF_OK(dif_rv_plic_init_from_dt(kRvPlicDt, &plic_actual));
  plic = &plic_actual;

  rv_plic_testutils_irq_range_enable(
      plic, kPlicTarget,
      dt_aon_timer_irq_to_plic_id(kAonTimerDt, kDtAonTimerIrqWkupTimerExpired),
      dt_aon_timer_irq_to_plic_id(kAonTimerDt, kDtAonTimerIrqWdogTimerBark));
  rv_plic_testutils_irq_range_enable(
      plic, kPlicTarget,
      dt_alert_handler_irq_to_plic_id(kAlertHandlerDt,
                                      kDtAlertHandlerIrqClassa),
      dt_alert_handler_irq_to_plic_id(kAlertHandlerDt,
                                      kDtAlertHandlerIrqClassd));

  // Initialize alert handler.
  CHECK_DIF_OK(
      dif_alert_handler_init_from_dt(kAlertHandlerDt, &alert_handler_actual));
  alert_handler = &alert_handler_actual;

  // Wakeup sources.
  CHECK_DIF_OK(dif_pwrmgr_find_request_source(
      pwrmgr, kDifPwrmgrReqTypeWakeup, dt_aon_timer_instance_id(kAonTimerDt),
      kDtAonTimerWakeupWkupReq, &aon_timer_wakeup_sources));
#if defined(OPENTITAN_IS_EGRET)
  CHECK_DIF_OK(dif_pwrmgr_find_request_source(
      pwrmgr, kDifPwrmgrReqTypeWakeup,
      dt_sysrst_ctrl_instance_id(kSysrstCtrlDt), kDtSysrstCtrlWakeupWkupReq,
      &sysrst_ctrl_wakeup_sources));
#endif
}

void config_alert_handler(void) {
  dif_alert_handler_alert_t alerts[1] = {
      dt_pwrmgr_alert_to_alert_id(kPwrmgrDt, kDtPwrmgrAlertFatalFault)};
  dif_alert_handler_class_t alert_classes[] = {kDifAlertHandlerClassA};

  uint32_t cycles[4] = {0};
  CHECK_STATUS_OK(alert_handler_testutils_get_cycles_from_us(
      kEscalationPhase0Micros, &cycles[0]));
  CHECK_STATUS_OK(alert_handler_testutils_get_cycles_from_us(
      kEscalationPhase1Micros, &cycles[1]));
  CHECK_STATUS_OK(alert_handler_testutils_get_cycles_from_us(
      kEscalationPhase2Micros, &cycles[2]));
  CHECK_STATUS_OK(alert_handler_testutils_get_cycles_from_us(10, &cycles[3]));

  dif_alert_handler_escalation_phase_t esc_phases[] = {
      {.phase = kDifAlertHandlerClassStatePhase0,
       .signal = 0,
       .duration_cycles =
           cycles[0] * alert_handler_testutils_cycle_rescaling_factor()},
      {.phase = kDifAlertHandlerClassStatePhase1,
       .signal = 1,
       .duration_cycles =
           cycles[1] * alert_handler_testutils_cycle_rescaling_factor()},
      {.phase = kDifAlertHandlerClassStatePhase2,
       .signal = 3,
       .duration_cycles =
           cycles[2] * alert_handler_testutils_cycle_rescaling_factor()}};

  dif_alert_handler_class_config_t class_config[] = {{
      .auto_lock_accumulation_counter = kDifToggleDisabled,
      .accumulator_threshold = 0,
      .irq_deadline_cycles =
          cycles[3] * alert_handler_testutils_cycle_rescaling_factor(),
      .escalation_phases = esc_phases,
      .escalation_phases_len = ARRAYSIZE(esc_phases),
      .crashdump_escalation_phase = kDifAlertHandlerClassStatePhase3,
  }};

  dif_alert_handler_class_t classes[] = {kDifAlertHandlerClassA};
  dif_alert_handler_config_t config = {
      .alerts = alerts,
      .alert_classes = alert_classes,
      .alerts_len = ARRAYSIZE(alerts),
      .classes = classes,
      .class_configs = class_config,
      .classes_len = ARRAYSIZE(class_config),
      .ping_timeout = kAlertHandlerTestutilsDefaultPingTimeout,
  };

  CHECK_STATUS_OK(alert_handler_testutils_configure_all(alert_handler, config,
                                                        kDifToggleEnabled));
  // Enables alert handler irq.
  CHECK_DIF_OK(dif_alert_handler_irq_set_enabled(
      alert_handler, kDifAlertHandlerIrqClassa, kDifToggleEnabled));
}

#if defined(OPENTITAN_IS_EGRET)
void config_sysrst(dif_pinmux_index_t pad_pin) {
  LOG_INFO("sysrst enabled");

  // Set sysrst as a reset source.
  dif_pwrmgr_request_sources_t reset_sources;
  CHECK_DIF_OK(dif_pwrmgr_find_request_source(
      pwrmgr, kDifPwrmgrReqTypeReset, dt_sysrst_ctrl_instance_id(kSysrstCtrlDt),
      kDtSysrstCtrlResetReqRstReq, &reset_sources));
  CHECK_DIF_OK(dif_pwrmgr_set_request_sources(
      pwrmgr, kDifPwrmgrReqTypeReset, reset_sources, kDifToggleEnabled));
  LOG_INFO("Reset Request SourceOne is set");

  // Configure sysrst key combo
  // reset pulse : 50 us
  // detect duration : 50 us

  dif_sysrst_ctrl_key_combo_config_t sysrst_ctrl_key_combo_config = {
      .keys = kDifSysrstCtrlKeyAll,
      .detection_time_threshold = 10,
      .actions = kDifSysrstCtrlKeyComboActionAll,
      .embedded_controller_reset_duration = 10};

  CHECK_DIF_OK(dif_sysrst_ctrl_key_combo_detect_configure(
      sysrst_ctrl_aon, kDifSysrstCtrlKeyCombo0, sysrst_ctrl_key_combo_config));
  // Configure sysrst input change
  // debounce duration : 100 us
  dif_sysrst_ctrl_input_change_config_t sysrst_ctrl_input_change_config = {
      .input_changes = kDifSysrstCtrlInputAll, .debounce_time_threshold = 20};

  // Configure pinmux
  dif_pinmux_t pinmux;
  CHECK_DIF_OK(dif_pinmux_init(
      mmio_region_from_addr(TOP_EGRET_PINMUX_AON_BASE_ADDR), &pinmux));

  CHECK_DIF_OK(dif_sysrst_ctrl_input_change_detect_configure(
      sysrst_ctrl_aon, sysrst_ctrl_input_change_config));

  CHECK_DIF_OK(dif_pinmux_input_select(
      &pinmux, kTopEgretPinmuxPeripheralInSysrstCtrlAonKey0In, pad_pin));
}
#endif

void config_wdog(uint64_t bark_micros, uint64_t bite_micros) {
  uint32_t bark_cycles = 0;
  CHECK_STATUS_OK(
      aon_timer_testutils_get_aon_cycles_32_from_us(bark_micros, &bark_cycles));
  uint32_t bite_cycles = 0;
  CHECK_STATUS_OK(
      aon_timer_testutils_get_aon_cycles_32_from_us(bite_micros, &bite_cycles));

  LOG_INFO("Wdog will bark after %u microseconds (%u aon cycles)",
           (uint32_t)bark_micros, bark_cycles);
  LOG_INFO("Wdog will bite after %u microseconds (%u aon cycles)",
           (uint32_t)bite_micros, bite_cycles);

  // Setup the wdog bark and bite timeouts.
  CHECK_STATUS_OK(aon_timer_testutils_watchdog_config(aon_timer, bark_cycles,
                                                      bite_cycles, false));
  // Set wdog as a reset source.
  dif_pwrmgr_request_sources_t reset_sources;
  CHECK_DIF_OK(dif_pwrmgr_find_request_source(
      pwrmgr, kDifPwrmgrReqTypeReset, dt_aon_timer_instance_id(kDtAonTimerAon),
      kDtAonTimerResetReqAonTimer, &reset_sources));
  CHECK_DIF_OK(dif_pwrmgr_set_request_sources(
      pwrmgr, kDifPwrmgrReqTypeReset, reset_sources, kDifToggleEnabled));
}

void trigger_escalation(void) {
  // The relative times of escalation, time, and bark are set so the aon timer
  // won't trigger bark nor bite.
  config_wdog(
      kWdogBarkMicros * alert_handler_testutils_cycle_rescaling_factor(),
      kWdogBiteMicros * alert_handler_testutils_cycle_rescaling_factor());
  // Trigger the alert handler to escalate.
  dif_pwrmgr_alert_t alert = kDifPwrmgrAlertFatalFault;
  CHECK_DIF_OK(dif_pwrmgr_alert_force(pwrmgr, alert));

  // If this busy spin expires the escalation didn't occur as expected.
  busy_spin_micros(kWdogBiteMicros);
  CHECK(false, "Timeout waiting for escalation to occur.");
}

void prepare_for_wdog(pwrmgr_sleep_resets_lib_modes_t mode) {
  if (mode == kPwrmgrSleepResetsLibModesActive) {
    // Just wait for a reset.
    busy_spin_micros(kWaitWhileActiveMicros);
  } else {
    bool deep_sleep = mode == kPwrmgrSleepResetsLibModesDeepSleep;
    // Place device into low power.
    dif_pwrmgr_domain_config_t config =
        deep_sleep ? 0
                   : kDifPwrmgrDomainOptionCoreClockInLowPower |
                         kDifPwrmgrDomainOptionIoClockInLowPower |
#if defined(OPENTITAN_IS_EGRET)
                         kDifPwrmgrDomainOptionUsbClockInLowPower |
#endif
                         kDifPwrmgrDomainOptionMainPowerInLowPower;

    // Program the pwrmgr to go to deep sleep state (clocks off).
    // Enter in low power mode. Choose a wakeup source different
    // from the aon_timer (we expect a reset, not a wakeup).
    CHECK_STATUS_OK(pwrmgr_testutils_enable_low_power(
        pwrmgr, sysrst_ctrl_wakeup_sources, config));
    wait_for_interrupt();
  }
  // If we arrive here the test must fail.
  CHECK(false, "Failed to reset!");
}

#if defined(OPENTITAN_IS_EGRET)
void prepare_for_sysrst(pwrmgr_sleep_resets_lib_modes_t mode) {
  if (mode == kPwrmgrSleepResetsLibModesActive) {
    LOG_INFO("Sysrst reset in active mode");
    // Just wait for a reset.
    busy_spin_micros(kWaitWhileActiveMicros);
  } else {
    bool deep_sleep = mode == kPwrmgrSleepResetsLibModesDeepSleep;
    // Place device into low power.
    dif_pwrmgr_domain_config_t config =
        deep_sleep ? 0
                   : kDifPwrmgrDomainOptionUsbClockInLowPower |
                         kDifPwrmgrDomainOptionCoreClockInLowPower |
                         kDifPwrmgrDomainOptionIoClockInLowPower |
                         kDifPwrmgrDomainOptionMainPowerInLowPower;
    CHECK_STATUS_OK(pwrmgr_testutils_enable_low_power(
        pwrmgr, sysrst_ctrl_wakeup_sources, config));
    // Log message to synchronize with host side: emit it as close as
    // possible before WFI so the host has no chance of sending the reset
    // before it is enabled.
    LOG_INFO("Sysrst reset in %s sleep mode", deep_sleep ? "deep" : "normal");
    // Enter in low power mode.
    wait_for_interrupt();
  }
  // If we arrive here the test must fail.
  CHECK(false, "Failed to reset!");
}
#endif

void ottf_external_isr(uint32_t *exc_info) {
  dt_instance_id_t instance_id;
  dt_plic_irq_id_t irq_id;
  uint32_t alert = 0;

  CHECK_DIF_OK(dif_rv_plic_irq_claim(plic, kPlicTarget, &irq_id));

  instance_id = dt_plic_id_to_instance_id(irq_id);
  if (instance_id == dt_aon_timer_instance_id(kAonTimerDt)) {
    dt_aon_timer_irq_t irq =
        dt_aon_timer_irq_from_plic_id(kDtAonTimerAon, irq_id);

    // Stops escalation process.
    CHECK_DIF_OK(dif_alert_handler_escalation_clear(alert_handler,
                                                    kDifAlertHandlerClassA));
    CHECK_DIF_OK(dif_aon_timer_irq_acknowledge(aon_timer, irq));

    CHECK(irq != kDtAonTimerIrqWdogTimerBark, "AON Timer Wdog should not bark");

  } else if (instance_id == dt_alert_handler_instance_id(kAlertHandlerDt)) {
    dt_alert_handler_irq_t irq =
        dt_alert_handler_irq_from_plic_id(kAlertHandlerDt, irq_id);

    CHECK_DIF_OK(dif_alert_handler_alert_acknowledge(alert_handler, alert));

    dif_alert_handler_class_state_t state;
    CHECK_DIF_OK(dif_alert_handler_get_class_state(
        alert_handler, kDifAlertHandlerClassA, &state));

    CHECK(state == kDifAlertHandlerClassStatePhase0, "Wrong phase %d", state);

    CHECK_DIF_OK(dif_alert_handler_irq_acknowledge(alert_handler, irq));
  }

  // Complete the IRQ by writing the IRQ source to the Ibex specific CC
  // register.
  CHECK_DIF_OK(dif_rv_plic_irq_complete(plic, kPlicTarget, irq_id));
}
