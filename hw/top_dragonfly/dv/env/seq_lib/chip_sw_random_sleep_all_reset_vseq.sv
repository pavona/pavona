// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// This sequence injects a POR when requested by SW via sw_logger_vif, otherwise
// it waits till SW informs the test is done via sw_logger_vif.

class chip_sw_random_sleep_all_reset_vseq extends chip_sw_base_vseq;
  `uvm_object_utils(chip_sw_random_sleep_all_reset_vseq)

  `uvm_object_new

  rand int cycles_till_reset;
  rand int reset_delay;

  constraint cycles_till_reset_c {cycles_till_reset inside {[0 : 200]};}
  constraint reset_delay_c {reset_delay inside {[0 : 10]};}

  virtual task body();
    int loop_idx = 0;
    super.body();
    // Wait until we reach the SW test state.
    `DV_WAIT(cfg.sw_test_status_vif.sw_test_status == SwTestStatusInTest)
    `uvm_info(`gfn, "SW test ready", UVM_MEDIUM)

    while (1) begin
      `DV_WAIT(cfg.sw_logger_vif.printed_log == "New reset event")
      `DV_WAIT(
          cfg.sw_logger_vif.printed_log == "Booting and setting deep sleep followed by hw por" ||
          cfg.sw_logger_vif.printed_log == "Booting and setting normal sleep followed by hw por" ||
          cfg.sw_logger_vif.printed_log == "Let SV wait timer reset" ||
          cfg.sw_logger_vif.printed_log == "Last Booting" ||
          cfg.sw_logger_vif.printed_log == "Test finish")

      `uvm_info(`gfn, $sformatf("SW message delivered to TB\n >> %0s", cfg.sw_logger_vif.printed_log
                ), UVM_MEDIUM)

      if (cfg.sw_logger_vif.printed_log ==
                   "Booting and setting deep sleep followed by hw por" ||
                   cfg.sw_logger_vif.printed_log ==
                   "Booting and setting normal sleep followed by hw por") begin
        repeat (10) @cfg.chip_vif.pwrmgr_low_power_if.cb;
        repeat (cycles_till_reset) @cfg.chip_vif.pwrmgr_low_power_if.cb;
        execute_reset();
      end else if (cfg.sw_logger_vif.printed_log == "Let SV wait timer reset") begin
        // Wait until c test finishes the current round and goes to reset.
        `DV_WAIT(cfg.sw_test_status_vif.sw_test_status == SwTestStatusInBootRom)
      end else begin
        // Add some time slap for dummy wait event
        repeat (10) @cfg.chip_vif.pwrmgr_low_power_if.fast_cb;
      end

      // Wait for reboot except the last round
      if (cfg.sw_logger_vif.printed_log == "Last Booting" ||
          cfg.sw_logger_vif.printed_log == "Test finish") begin
        break;
      end
      `DV_WAIT(cfg.sw_test_status_vif.sw_test_status == SwTestStatusInBootRom)
    end
  endtask

  task execute_reset();
    `uvm_info(`gfn, "wait for low power entry", UVM_MEDIUM)
    `DV_WAIT(cfg.chip_vif.pwrmgr_low_power_if.low_power == 1, "timeout waiting for low power entry")
    `uvm_info(`gfn, "reset after low power entry", UVM_MEDIUM)
    assert_por_reset_deep_sleep(reset_delay);
  endtask

endclass
