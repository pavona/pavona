// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Focused unit-test environment for the reset-safe TL path. The existing
// tl_agent_env remains unchanged so its legacy smoke test keeps the original
// agents, drivers, and sequencers.
class tl_rst_safe_agent_env extends dv_base_env #(
  .CFG_T              (tl_agent_env_cfg),
  .VIRTUAL_SEQUENCER_T(tl_rst_safe_agent_virtual_sequencer),
  .SCOREBOARD_T       (tl_agent_scoreboard),
  .COV_T              (tl_agent_env_cov)
);

  tl_rst_safe_agent host_agent;
  tl_rst_safe_agent device_agent;

  `uvm_component_utils(tl_rst_safe_agent_env)
  `uvm_component_new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Both agents observe the unit testbench's single reset domain.
    cfg.host_agent_cfg.reset_domain   = cfg.reset_domain;
    cfg.device_agent_cfg.reset_domain = cfg.reset_domain;

    uvm_config_db#(tl_agent_cfg)::set(this, "host_agent", "cfg", cfg.host_agent_cfg);
    host_agent = tl_rst_safe_agent::type_id::create("host_agent", this);

    uvm_config_db#(tl_agent_cfg)::set(this, "device_agent", "cfg", cfg.device_agent_cfg);
    device_agent = tl_rst_safe_agent::type_id::create("device_agent", this);

    if (cfg.zero_delays) begin
      cfg.host_agent_cfg.a_valid_delay_min   = 0;
      cfg.host_agent_cfg.a_valid_delay_max   = 0;
      cfg.host_agent_cfg.d_ready_delay_min   = 0;
      cfg.host_agent_cfg.d_ready_delay_max   = 0;
      cfg.device_agent_cfg.d_valid_delay_min = 0;
      cfg.device_agent_cfg.d_valid_delay_max = 0;
      cfg.device_agent_cfg.a_ready_delay_min = 0;
      cfg.device_agent_cfg.a_ready_delay_max = 0;
    end

    scoreboard.add_item_port("host_req_chan", scoreboard_pkg::kSrcPort);
    scoreboard.add_item_port("host_rsp_chan", scoreboard_pkg::kDstPort);
    scoreboard.add_item_port("device_req_chan", scoreboard_pkg::kDstPort);
    scoreboard.add_item_port("device_rsp_chan", scoreboard_pkg::kSrcPort);
    scoreboard.add_item_queue("req_chan", scoreboard_pkg::kInOrderCheck);
    scoreboard.add_item_queue("rsp_chan", scoreboard_pkg::kInOrderCheck);
  endfunction : build_phase

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    if (cfg.is_active) begin
      virtual_sequencer.host_seqr   = host_agent.sequencer;
      virtual_sequencer.device_seqr = device_agent.sequencer;
    end

    host_agent.monitor.a_chan_port.connect(scoreboard.item_fifos["host_req_chan"].analysis_export);
    host_agent.monitor.d_chan_port.connect(scoreboard.item_fifos["host_rsp_chan"].analysis_export);
    device_agent.monitor.a_chan_port.connect(
        scoreboard.item_fifos["device_req_chan"].analysis_export);
    device_agent.monitor.d_chan_port.connect(
        scoreboard.item_fifos["device_rsp_chan"].analysis_export);

    // Observe accepted device requests without consuming the responder FIFO.
    device_agent.monitor.a_chan_port.connect(virtual_sequencer.device_a_chan_fifo.analysis_export);
  endfunction : connect_phase
endclass : tl_rst_safe_agent_env
