// Copyright zeroRISC Inc
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class dv_rst_domain extends uvm_object;
  string domain_name;
  virtual clk_rst_if clk_rst_vif;

  `uvm_object_new

  // Reset control methods
  virtual task apply_reset();
    fork
      clk_rst_vif.apply_reset();
    join_none
  endtask

  virtual task wait_reset_assert();
    // Default domain only support Async Assert
    wait (!clk_rst_vif.rst_n);
  endtask

  virtual task wait_reset_deassert();
    // Default domain will only look for Sync Deassert
    forever begin
      @(posedge clk_rst_vif.clk);
      if (clk_rst_vif.rst_n === 1) break;
    end
  endtask

  `uvm_object_utils_begin(dv_rst_domain)
  `uvm_object_utils_end
endclass
