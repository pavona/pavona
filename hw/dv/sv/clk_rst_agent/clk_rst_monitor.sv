// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class clk_rst_monitor extends dv_rst_safe_base_monitor #(
    .ITEM_T (clk_rst_item),
    .CFG_T  (clk_rst_agent_cfg),
    .COV_T  (clk_rst_agent_cov)
  );
  `uvm_component_utils(clk_rst_monitor)

  // the base class provides the following handles for use:
  // clk_rst_agent_cfg: cfg
  // clk_rst_agent_cov: cov
  // uvm_analysis_port #(clk_rst_item): analysis_port

  `uvm_component_new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    // This is the monitor that does reset monitoring
    // Hence super.run_phase() is not called.
    fork
      collect_trans();
    join
  endtask

  // collect transactions forever - already forked in dv_base_monitor::run_phase
  virtual protected task collect_trans();
    clk_rst_item item ;
    bit          rst_n;

    `uvm_info (get_name(), "Starting collect_trans()", UVM_LOW);

    forever begin
      @(posedge cfg.reset_domain.clk_rst_vif.clk);
      // Compare previously captured reset status to see if there is a change in the
      // reset signal. If there is a state change let the checkers know.
      if (   rst_n !== cfg.reset_domain.clk_rst_vif.rst_n
          && cfg.reset_domain.clk_rst_vif.rst_n == 1'b0) begin
        item           = clk_rst_item::type_id::create();
        item.item_type = clk_rst_item::RESET_ASSERTED;
        notify (item);
      end
      else if (   rst_n !== cfg.reset_domain.clk_rst_vif.rst_n
               && cfg.reset_domain.clk_rst_vif.rst_n == 1'b1) begin
        item           = clk_rst_item::type_id::create();
        item.item_type = clk_rst_item::RESET_DEASSERTED;
        notify (item);
      end

      // Local capture of current status of reset in the monitor
      rst_n = cfg.reset_domain.clk_rst_vif.rst_n;
    end
  endtask

endclass
