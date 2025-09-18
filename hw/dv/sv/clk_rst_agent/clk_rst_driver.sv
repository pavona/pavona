// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class clk_rst_driver extends dv_rst_safe_base_driver #(.ITEM_T(clk_rst_item),
                                              .CFG_T (clk_rst_agent_cfg));
  `uvm_component_utils(clk_rst_driver)


  // the base class provides the following handles for use:
  // clk_rst_agent_cfg: cfg

  `uvm_component_new

  virtual task run_phase(uvm_phase phase);
    // Need to fork off get_and_drive(). So that when a new transaction is seen from the sequencer
    // it is handled. Do not fork super.run_phase as this class implements the reset assertion and
    // de-assertion ans therefore we do not need anything from the parent class.
    fork
      get_and_drive();
    join_none
  endtask


  virtual task get_and_drive();
    clk_rst_item  item;
    forever begin
      // Get the next data item from sequencer
      seq_item_port.get_next_item (item);

      // Execute the item.
      if (item.item_type == clk_rst_item::APPLY_RESET) begin
        // call cfg.reset_domain.apply_reset()
      end else if (item.item_type == clk_rst_item::CONFIG_CLK_INTF) begin
        // call cfg.reset_domain.clk_rst_vif.config_clk_intf()
      end else begin
        `uvm_fatal (`gfn, {"clk_rst_driver only supports clk_rst_item::item_type inside",
                           "{APPLY_RESET, CONFIG_CLK_INTF}"})
      end

      seq_item_port.item_done();
    end // forever
  endtask

endclass
