// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// This generates wakeup stimuli for the wakeups triggered by external
// sources. Right now it only includes pinmux, but dragonfly can also be
// woken up by soc_proxy, except the corresponding input is grounded in
// the generated chip wrapper.
class chip_sw_pwrmgr_deep_sleep_all_wake_ups_vseq extends chip_sw_base_vseq;
  `uvm_object_utils(chip_sw_pwrmgr_deep_sleep_all_wake_ups_vseq)
  `uvm_object_new

  virtual task body();
    uint timeout_long  = 10_000_000;
    uint timeout_short = 1_000_000;
    bit twice_each   = 0;
    int repeat_count = 1;
    super.body();

    // Give the pin a default value.
    cfg.chip_vif.pinmux_wkup_if.set_pulldown_en(1'b1);

    if ($value$plusargs("do_random=%b", twice_each) && twice_each) begin
      repeat_count = 2;
    end

    // Need to use hard coded string.
    // Loop with sformatf %d doesn't work

    // Add sample number for the future reference.
    // This is sampled from sv simulation and can be varied
    // over test run as well as the version of design.
    // Total run time was 21ms.
    // @3.5ms
    repeat (repeat_count) begin
      `DV_SPINWAIT(wait(cfg.sw_logger_vif.printed_log == "Issue WFI to enter sleep 0");,
                   "Timed out waiting for enter sleep 0", timeout_long)
      wakeup_action(0);
      // @6.3ms
      `DV_SPINWAIT(wait(cfg.sw_logger_vif.printed_log == "Woke up by source 0");,
                   "Timed out waiting for wake up by source 0", timeout_long)
      release_action(0);
    end
 endtask // body

  // Trigger wakeup signal for each test round
  // Round 0 : input for pinmux wakeup detector
  task wakeup_action(int round);
    repeat(20) @(posedge cfg.ast_supply_vif.clk);
    case(round)
      0: begin
        `uvm_info(`gfn, "Send pattern to pinmux wakeup detector ", UVM_MEDIUM)
        cfg.chip_vif.pinmux_wkup_if.drive(1'b1);
      end
      default: `uvm_fatal(`gfn, $sformatf("round %d is not allowed", round))
    endcase
  endtask // wakeup_action

  // Release wakeup signals
  task release_action(int round);
    case(round)
      0:     cfg.chip_vif.pinmux_wkup_if.drive(1'b0);
      default: `uvm_fatal(`gfn, $sformatf("round %d is not allowed", round))
    endcase
  endtask // release_action
endclass // chip_sw_pwrmgr_deep_sleep_all_wake_ups_vseq
