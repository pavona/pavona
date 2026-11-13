// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// This sequence forces the `wait_cyc_mask` input from alert_handler_ping_timer so alert_handler
// will send out pings more frequently.
// Then the sequence waits until all alerts are pinged at least once.
// Finally it checks alert cause register to make sure there is no error in alert_handler.
class chip_sw_alert_handler_entropy_vseq extends chip_sw_base_vseq;
  `uvm_object_utils(chip_sw_alert_handler_entropy_vseq)

  `uvm_object_new

  virtual task pre_start();
    void'(cfg.chip_vif.signal_probe_alert_handler_ping_timer_wait_cyc_mask_i(SignalProbeForce, 7));
    super.pre_start();
  endtask

  virtual task body();
    super.body();

    // This test injects a fault on purpose. The fatal alert it raises stays asserted
    // until reset, and some blocks raise their own alerts once escalation starts, so the
    // sweep at the end of cip_base_vseq would call every one of them unexpected.
    expect_fatal_alerts = 1'b1;

    // That same path re-initializes the chip once the body task exits, which resets it while
    // accesses are still in flight. pre_start has already done the initial init, so clearing
    // the bit here only stops the one at the end.
    do_dut_init = 1'b0;

    fork begin : isolation_fork
      int num_alerts = NUM_ALERTS;
      foreach (LIST_OF_ALERTS[i]) begin
        automatic int index = i;
        fork begin
          cfg.m_alert_agent_cfgs[LIST_OF_ALERTS[index]].vif.wait_alert_ping();
          num_alerts--;
          `uvm_info(`gfn, $sformatf("alert %0s received ping request.\n %0d alerts remaining.",
                    LIST_OF_ALERTS[index], num_alerts), UVM_LOW)
        end join_none
      end
      wait fork;
    end join

    cfg.clk_rst_vif.wait_clks($urandom_range(50, 500));

    // Check alert_handler cause registers to make sure there is no error from alert_handler.
    foreach (ral.alert_handler.alert_cause[i]) begin
      csr_rd_check(.ptr(ral.alert_handler.alert_cause[i]), .compare_value(0), .backdoor(1));
    end
    foreach (ral.alert_handler.loc_alert_cause[i]) begin
      csr_rd_check(.ptr(ral.alert_handler.loc_alert_cause[i]), .compare_value(0), .backdoor(1));
    end
  endtask

endclass
