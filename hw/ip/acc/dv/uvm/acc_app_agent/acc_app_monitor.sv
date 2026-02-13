// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class acc_app_monitor extends dv_base_monitor #(
    .ITEM_T (acc_app_item),
    .CFG_T  (acc_app_agent_cfg),
    .COV_T  (acc_app_agent_cov)
  );

  `uvm_component_utils(acc_app_monitor)
  `uvm_component_new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  virtual protected task collect_trans();
    forever fork
      begin : isolation_fork
        fork
          process_trans();
          @(negedge cfg.vif.rst_n);
        join_any
        disable fork;
      end : isolation_fork
    join
  endtask

  virtual protected task process_trans();
    bit done      = 0;
    bit prev_next = 0;
    bit new_next  = 0;
    bit new_hold  = 0;
    bit start     = 0;

    // Capture the MSG payload
    forever begin
      acc_app_item base_item = acc_app_item::type_id::create("base_item");
      acc_app_item next_rsp;
      acc_app_item rst_rsp;

      // Wait for the first valid word in the message
      // Wait for reset to deassert
      do begin
        @(cfg.vif.mon_cb);
      end while (!cfg.vif.mon_cb.rst_n);

      // Wait for req_valid to be asserted after reset is deasserted
      do begin
        @(cfg.vif.mon_cb);
      end while (!cfg.vif.mon_cb.req_valid);

      // Collect first req word without ready asserted
      base_item.req_valid       = cfg.vif.mon_cb.req_valid;
      base_item.req_data        = cfg.vif.mon_cb.req_data;
      base_item.req_strb        = cfg.vif.mon_cb.req_strb;
      base_item.rsp_ready       = cfg.vif.mon_cb.rsp_ready;
      base_item.req_next        = cfg.vif.mon_cb.req_next;
      base_item.req_hold        = cfg.vif.mon_cb.req_hold;
      base_item.drive_rsp_ready = 1;

      req_analysis_port.write(base_item);
      `uvm_info(`gfn, $sformatf("Captured configuration request from ACC (rsp_ready = 0):\n%0s",
                base_item.sprint()), UVM_MEDIUM)

      // Collect the req from DUT
      done = 0;
      do begin
        @(cfg.vif.mon_cb);
        // Only capture if word is valid and KMAC is ready to accept
        if (cfg.vif.mon_cb.req_valid && cfg.vif.mon_cb.rsp_ready && cfg.vif.mon_cb.rst_n) begin
          base_item.req_strb        = cfg.vif.mon_cb.req_strb;
          base_item.req_data        = cfg.vif.mon_cb.req_data;
          base_item.req_valid       = cfg.vif.mon_cb.req_valid;
          base_item.drive_rsp_ready = 1;

          // Only add valid words using strb
          for (int i = 0; i < KmacDataIfWidth/8; i++) begin
            if (cfg.vif.mon_cb.req_strb[i]) begin
              base_item.byte_data_q.push_back(cfg.vif.mon_cb.req_data[i*8+:8]);
            end
          end

          // If end of req stop accumulating msg payload
          if (cfg.vif.mon_cb.req_last) begin
            base_item.req_last        = 1;
            base_item.drive_rsp_ready = 0;
            done = 1;
          end
        end

        if (!cfg.vif.mon_cb.req_hold) begin
          done = 1;
        end

        base_item.req_valid   = cfg.vif.mon_cb.req_valid;
        base_item.req_next    = cfg.vif.mon_cb.req_next; // Should be 0
        base_item.req_hold    = cfg.vif.mon_cb.req_hold; // Still 1 for first msg unless early exit
        base_item.rsp_ready   = cfg.vif.mon_cb.rsp_ready;

        req_analysis_port.write(base_item);
        `uvm_info(`gfn, $sformatf("Capturing request:\n%0s", base_item.sprint()), UVM_MEDIUM)
      end while (!done); // Stop capture msg payload after req_last

      // Capture requests for additional responses for each req_next pulse while hold == 1
      prev_next = 0;
      do begin
        @(cfg.vif.mon_cb);
        new_next = cfg.vif.mon_cb.req_next; // Get current value of next
        new_hold = cfg.vif.mon_cb.req_hold; // Get current value of hold

        // Start a rsp if we see a posedge on next
        if (new_next && !prev_next) begin
          next_rsp = acc_app_item::type_id::create("rsp_next");
          next_rsp.byte_data_q = base_item.byte_data_q; // Maintain msg payload
          next_rsp.req_next    = 1;                     // Indicate we want a new rsp
          next_rsp.req_hold    = new_hold;              // Maintain hold value
          req_analysis_port.write(next_rsp);
          `uvm_info(`gfn, $sformatf("Captured additional response (req_next pulse):\n%0s",
                    next_rsp.sprint()), UVM_MEDIUM)
        end

        prev_next = new_next;
      end while (cfg.vif.mon_cb.req_hold == 1); // Once hold is dropped transaction is over

      // Capture req_hold = 0 to stop sequence
      rst_rsp = acc_app_item::type_id::create("rst_rsp");
      rst_rsp.req_hold = cfg.vif.mon_cb.req_hold;
      req_analysis_port.write(rst_rsp);

      `uvm_info(`gfn, "Completed response sequence (req_hold = 0)", UVM_MEDIUM)
    end
  endtask

endclass
