// Copyright Pavona contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Wide (64-bit) TileLink agent for the DMA host64 SoC System port. Uses the wide
// transactor components and is always a Device (memory responder).
class dma_tl_agent extends dv_base_agent#(
    .CFG_T           (dma_tl_agent_cfg),
    .DRIVER_T        (dma_tl_device_driver),
    .HOST_DRIVER_T   (dma_tl_device_driver),
    .DEVICE_DRIVER_T (dma_tl_device_driver),
    .SEQUENCER_T     (dma_tl_sequencer),
    .MONITOR_T       (dma_tl_monitor),
    .COV_T           (tl_agent_cov)
  );

  `uvm_component_utils(dma_tl_agent)

  `uvm_component_new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // Fetch the wide dma_tl_if handle if not already supplied.
    if (cfg.dma_vif == null &&
        !uvm_config_db#(virtual dma_tl_if)::get(this, "", "vif", cfg.dma_vif)) begin
      `uvm_fatal(`gfn, "failed to get dma_tl_if handle from uvm_config_db")
    end
    cfg.dma_vif.if_mode = cfg.if_mode;
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (cfg.if_mode == dv_utils_pkg::Device) begin
      if (cfg.device_can_rsp_on_same_cycle) begin
        monitor.a_chan_same_cycle_rsp_port.connect(sequencer.a_chan_req_fifo.analysis_export);
      end else begin
        monitor.a_chan_port.connect(sequencer.a_chan_req_fifo.analysis_export);
      end
    end
  endfunction
endclass : dma_tl_agent
