// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class ac_range_check_rst_safe_bypass_vseq
    extends ac_range_check_rst_safe_smoke_vseq;
  `uvm_object_utils(ac_range_check_rst_safe_bypass_vseq)

  extern function new(string name = "");
  extern virtual task main_thread();
  extern virtual task dut_shutdown();
endclass : ac_range_check_rst_safe_bypass_vseq

function ac_range_check_rst_safe_bypass_vseq::new(string name = "");
  super.new(name);
endfunction : new

task ac_range_check_rst_safe_bypass_vseq::main_thread();
  cfg.misc_vif.set_range_check_overwrite(1'b1);
  super.main_thread();
endtask : main_thread

task ac_range_check_rst_safe_bypass_vseq::dut_shutdown();
  cfg.misc_vif.set_range_check_overwrite(1'b0);
  super.dut_shutdown();
endtask : dut_shutdown
