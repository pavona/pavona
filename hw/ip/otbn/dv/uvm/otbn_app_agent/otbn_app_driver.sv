// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class otbn_app_driver extends dv_base_driver #(
  .ITEM_T (otbn_app_item),
  .CFG_T  (otbn_app_agent_cfg)
  );

  `uvm_component_utils(otbn_app_driver)
  `uvm_component_new

  virtual task run_phase(uvm_phase phase);
    // base class forks off reset_signals() and get_and_drive() tasks
    super.run_phase(phase);
  endtask

  // reset signals
  virtual task reset_signals();
    forever begin
      @(negedge cfg.vif.rst_n);
      `uvm_info(`gfn, "Reset asserted: invalidating app interface immediately", UVM_MEDIUM);
      invalidate_signals();
      @(posedge cfg.vif.rst_n);
      `uvm_info(`gfn, "Reset deasserted: resume driver activity", UVM_MEDIUM);
    end
  endtask

  virtual function void invalidate_signals();
    // Done, ready, and error need known values
    cfg.vif.host_cb.rsp_done          <= 0;
    cfg.vif.host_cb.rsp_ready         <= 0;
    cfg.vif.host_cb.rsp_digest_share0 <= 'x;
    cfg.vif.host_cb.rsp_digest_share1 <= 'x;
    cfg.vif.host_cb.rsp_error         <= 0;
  endfunction

  // drive trans received from sequencer
  virtual task get_and_drive();
    forever begin
      otbn_app_item item;
      seq_item_port.get_next_item(item);
      // TODO: This driver needs to be updated to use the random reset base class
      // which will fix the non-blocking call to the sequencer before the item has
      // been driven to the interface.
      seq_item_port.item_done();

      // Rsp sequence always occurs after the DUT sends the initial request
      // drive_rsp_ready is set during the ready signal assertion stage only
      if (item.drive_rsp_ready) begin
        drive_rsp_ready(item);
      end else begin
        drive_rsp_response(item);
      end

      // Drives additional responses from next as long as hold is asserted
      while (cfg.vif.mon_cb.req_hold && ~item.drive_rsp_ready) begin
        otbn_app_item next_item;
        if (!cfg.vif.rst_n) begin
          break;
        end
        // Break when hold is 0
        if (cfg.vif.mon_cb.req_next && cfg.vif.mon_cb.req_hold) begin
          seq_item_port.get_next_item(next_item);
          seq_item_port.item_done();
          `uvm_info(`gfn, $sformatf("Got next item for response %0s",
                                    next_item.sprint()), UVM_MEDIUM)

          // Drives additional digest response
          drive_rsp_response(next_item);
        end else begin
          @(posedge cfg.vif.clk);
        end
      end
    end
  endtask

  // Drive rsp_ready signal
  task automatic drive_rsp_ready(otbn_app_item item);
    int remaining = 0;

    `uvm_info(`gfn, $sformatf("Item received by ready driver:\n%0s", item.sprint()), UVM_MEDIUM)
    // Fixed value to delay initial rsp ready from first received req word
    for (int i = 0; i < item.rsp_ready_delay; i++) begin
      if (!cfg.vif.rst_n) begin
        `uvm_info(`gfn, $sformatf("Reset Detected During Ready Drive"), UVM_MEDIUM)
        return;
      end
      @(posedge cfg.vif.clk);
      remaining = item.rsp_ready_delay - i;
      `uvm_info(`gfn, $sformatf("AppIntf rsp KMAC model waiting, %0d cycles remaining",
                remaining), UVM_MEDIUM)
    end
    if (!cfg.vif.rst_n) begin
      `uvm_info(`gfn, $sformatf("Reset Detected During Ready Drive"), UVM_MEDIUM)
      return;
    end
    cfg.vif.host_cb.rsp_ready <= item.rsp_ready && item.drive_rsp_ready;
  endtask

  // Drive digest and rsp_done
  task automatic drive_rsp_response(otbn_app_item item);
    int remaining = 0;

    cfg.vif.host_cb.rsp_ready <= 1'b0;

    for (int i = 0; i < item.rsp_delay; i++) begin
      @(posedge cfg.vif.clk);
      if (!cfg.vif.mon_cb.req_hold) begin
        `uvm_info(`gfn, $sformatf("Exit manual run response from speculative next"), UVM_MEDIUM)
        invalidate_signals();
        return;
      end

      if (!cfg.vif.rst_n) begin
        `uvm_info(`gfn, $sformatf("Reset Detected During Rsp Drive"), UVM_MEDIUM)
        return;
      end
      remaining = item.rsp_delay - i;
      `uvm_info(`gfn, $sformatf("AppIntf rsp KMAC model waiting, %0d cycles remaining",
                remaining), UVM_MEDIUM)
    end

    if (!cfg.vif.rst_n) begin
      `uvm_info(`gfn, $sformatf("Reset Detected During Rsp Drive"), UVM_MEDIUM)
      return;
    end

    // Set response from sequence
    cfg.vif.host_cb.rsp_digest_share0 <= item.rsp_digest_share0;
    cfg.vif.host_cb.rsp_digest_share1 <= item.rsp_digest_share1;
    cfg.vif.host_cb.rsp_error         <= item.rsp_error;
    cfg.vif.host_cb.rsp_done          <= item.rsp_done;
    `uvm_info(`gfn, "item sent", UVM_MEDIUM)

    @(posedge cfg.vif.clk);

    // Invalidate signals if not driving a response
    invalidate_signals();
  endtask

endclass
