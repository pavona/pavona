// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// The frequency timeout vseq exercises the frequency measurement counters. More details
// in the clkmgr_testplan.hjson file.
class clkmgr_frequency_timeout_vseq extends clkmgr_base_vseq;
  `uvm_object_utils(clkmgr_frequency_timeout_vseq)

  `uvm_object_new

  // If cause_timeout is set, turn off clk_timeout so it gets a timeout.
  rand bit cause_timeout;
  constraint cause_timeout_c {
    cause_timeout dist {
      1 := 4,
      0 := 1
    };
  }
  rand clk_mesr_e clk_timeout;
  constraint clk_timeout_c {clk_timeout != ClkMesrSize;}

  constraint all_clk_en_c {
    io_ip_clk_en == 1;
    main_ip_clk_en == 1;
  }

  // The clock that will be disabled.
  clk_mesr_e clk_mesr_timeout;

  // Get things back in normal order.
  virtual task apply_resets_concurrently(int reset_duration_ps = 0);
    super.apply_resets_concurrently(reset_duration_ps);
    if (cause_timeout) begin
      disturb_measured_clock(.clk(clk_mesr_timeout), .enable(1'b1));
      // Reset cleared the pulse-sync, so both checks are safe to re-arm immediately (the round
      // that stopped the clock and masked them was abandoned by the reset)
      control_sync_pulse_assert(.clk(clk_mesr_timeout), .enable(1'b1));
      control_dst_pulse_assert(.clk(clk_mesr_timeout), .enable(1'b1));
    end
  endtask

  task body();
    logic [TL_DW-1:0] value;
    int start_alert_count;
    int current_alert_count;
    int total_timeouts = 0;
    int prior_meas_count;
    int prior_measure_err_count;
    csr_wr(.ptr(ral.measure_ctrl_regwen), .value(1));

    // Make sure the aon clock is running as slow as it is meant to.
    cfg.aon_clk_rst_vif.set_freq_khz(AonClkHz / 1_000);
    control_ip_clocks();
    // Wait so the frequency change takes effect.
    cfg.aon_clk_rst_vif.wait_clks(2);

    // Disable cip scoreboard exp_alert checks since they need very fine control, making checks
    // really cumbersome. Instead we rely on the alert count to detect if alerts were triggered.
    cfg.scoreboard.do_alert_check = 0;

    // recov_alert is a 1-cycle edge the sender can drop when errors fall close together,
    // so we don't gate per round on the alert count: each round proves its timeout
    // and we only confirm at the end that alerts fired
    start_alert_count = cfg.scoreboard.get_alert_count("recov_fault");

    `uvm_info(`gfn, $sformatf("Will run %0d rounds", num_trans), UVM_MEDIUM)
    for (int i = 0; i < num_trans; ++i) begin
      clkmgr_recov_err_t actual_recov_err = '{default: '0};
      logic [ClkMesrSize-1:0] expected_recov_timeout_err = '0;
      bit expect_alert = 0;
      `DV_CHECK_RANDOMIZE_FATAL(this)
      `uvm_info(`gfn, "New round", UVM_MEDIUM)

      foreach (ExpectedCounts[clk]) begin
        clk_mesr_e clk_mesr = clk_mesr_e'(clk);
        int min_threshold;
        int max_threshold;
        int expected = ExpectedCounts[clk];
        min_threshold = expected - 2;
        max_threshold = expected + 2;
        enable_frequency_measurement(clk_mesr, min_threshold, max_threshold);
      end

      clk_mesr_timeout = clk_mesr_e'(clk_timeout);
      // Wait until the measurement is actually running (enable reached the AON domain), rather than
      // counting a fixed number of AON cycles.
      `DV_SPINWAIT(wait (cfg.clkmgr_vif.meas_running[clk_mesr_timeout] || cfg.under_reset);,
                   "timed out waiting for the measurement to start", CLK_STATUS_TIMEOUT_NS)

      if (cause_timeout) begin
        `uvm_info(`gfn, $sformatf("Will cause a timeout for clk %0s", clk_mesr_timeout.name()),
                  UVM_MEDIUM)
          expected_recov_timeout_err[clk_mesr_timeout] = 1;
        disturb_measured_clock(.clk(clk_mesr_timeout), .enable(1'b0));
        // Wait on recov_err_code, not the recov_fault alert (whose
        // 1-cycle edge can be dropped under back-to-back errors)
        `DV_SPINWAIT(
            wait (((cfg.clkmgr_vif.recov_timeout_err & expected_recov_timeout_err)
                   == expected_recov_timeout_err) || cfg.under_reset);,
            "timed out waiting for the timeout error(s) to latch", CLK_STATUS_TIMEOUT_NS)
        if (!cfg.under_reset) total_timeouts++;
      end else begin
        // No timeout expected: wait for a real measurement to complete (count advances), then
        // confirm no spurious error was logged
        prior_meas_count = cfg.clkmgr_vif.meas_valid_count[clk_mesr_timeout];
        `DV_SPINWAIT(
            wait (cfg.clkmgr_vif.meas_valid_count[clk_mesr_timeout] != prior_meas_count
                  || cfg.under_reset);,
            "timed out waiting for a frequency measurement", CLK_STATUS_TIMEOUT_NS)
      end
      // The disturbed clock is still stopped, so its measurement is frozen and can't log a
      // spurious measurement error in this read.
      csr_rd(.ptr(ral.recov_err_code), .value(actual_recov_err));
      `uvm_info(`gfn, $sformatf("Got recov err register=0x%x", actual_recov_err), UVM_MEDIUM)
      if (actual_recov_err.measures) begin
        report_recov_error_mismatch("measurement", recov_bits_t'(0), actual_recov_err.measures);
      end
      if (!cfg.under_reset && actual_recov_err.timeouts != expected_recov_timeout_err) begin
        report_recov_error_mismatch("timeout", expected_recov_timeout_err,
                                    actual_recov_err.timeouts);
      end
      if (actual_recov_err.shadow_update != 0) begin
        `uvm_error(`gfn, "Unexpected recoverable shadow update error")
      end

      foreach (ExpectedCounts[clk]) begin
        clk_mesr_e clk_mesr = clk_mesr_e'(clk);
        disable_frequency_measurement(clk_mesr);
      end
      // Restore a timed-out clock
      if (cause_timeout) begin
        prior_measure_err_count = cfg.clkmgr_vif.recov_measure_err_count[clk_mesr_timeout];
        cfg.clkmgr_vif.clear_meas_oor(clk_mesr_timeout);
        disturb_measured_clock(.clk(clk_mesr_e'(clk_timeout)), .enable(1'b1));
        `DV_SPINWAIT(wait (!cfg.clkmgr_vif.meas_running[clk_mesr_timeout] || cfg.under_reset);,
                     "timed out waiting for the measurement to quiesce", CLK_STATUS_TIMEOUT_NS)
        control_sync_pulse_assert(.clk(clk_mesr_timeout), .enable(1'b1));
        control_dst_pulse_assert(.clk(clk_mesr_timeout), .enable(1'b1));
        if (cfg.clkmgr_vif.meas_oor_seen[clk_mesr_timeout] && !cfg.under_reset) begin
          `DV_SPINWAIT(
              wait (cfg.clkmgr_vif.recov_measure_err_count[clk_mesr_timeout]
                        != prior_measure_err_count || cfg.under_reset);,
              "timed out waiting for the restart measurement error to latch", CLK_STATUS_TIMEOUT_NS)
        end
      end
      // Wait for every measurement to wind down
      foreach (ExpectedCounts[clk]) begin
        clk_mesr_e clk_mesr = clk_mesr_e'(clk);
        `DV_SPINWAIT(wait (!cfg.clkmgr_vif.meas_running[clk_mesr] || cfg.under_reset);,
                     "timed out waiting for measurements to quiesce", CLK_STATUS_TIMEOUT_NS)
      end
      // And clear errors.
      csr_wr(.ptr(ral.recov_err_code), .value('1));
    end

    // Test-level alert check: recov_alert edges can coalesce, so we don't count per round, but if
    // any timeout fired then at least one recov_fault alert must have been observed over the run
    current_alert_count = cfg.scoreboard.get_alert_count("recov_fault");
    if (total_timeouts > 0) begin
      `DV_CHECK_GT(current_alert_count, start_alert_count,
                   "expected at least one recov_fault alert when timeouts occur")
    end
  endtask : body

endclass
