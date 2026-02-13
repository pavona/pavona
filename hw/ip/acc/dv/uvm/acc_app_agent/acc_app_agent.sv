// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class acc_app_agent extends dv_base_agent #(
  .CFG_T          (acc_app_agent_cfg),
  .DRIVER_T       (acc_app_driver),
  .SEQUENCER_T    (acc_app_sequencer),
  .MONITOR_T      (acc_app_monitor),
  .COV_T          (acc_app_agent_cov)
);

  `uvm_component_utils(acc_app_agent)

  `uvm_component_new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    cfg.has_req_fifo = 1;

    // Get acc_app_intf handle from uvm_config_db
    if (!uvm_config_db#(virtual acc_app_intf)::get(this, "", "vif", cfg.vif)) begin
      `uvm_fatal(`gfn, "failed to get acc_app_intf handle from uvm_config_db")
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // Connect monitor req_analysis_port to sequencer req_analysis_fifo if enabled
    if (cfg.has_req_fifo) begin
      monitor.req_analysis_port.connect(sequencer.req_analysis_fifo.analysis_export);
    end

    // Connect monitor rsp_analysis_port to sequencer rsp_analysis_fifo if enabled
    if (cfg.has_rsp_fifo) begin
      monitor.rsp_analysis_port.connect(sequencer.rsp_analysis_fifo.analysis_export);
    end
  endfunction

  virtual task run_phase(uvm_phase phase);
    if (cfg.is_active) begin
      acc_app_base_seq m_seq;
      // Start a device sequence
      `uvm_info(`gfn, $sformatf("Starting AppIntf response sequence"), UVM_MEDIUM)
      m_seq = acc_app_base_seq::type_id::create("m_seq", this);
    end
  endtask
endclass
