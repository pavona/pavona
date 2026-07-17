// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class rv_timer_rst_safe_env extends cip_rst_safe_base_env #(
    .CFG_T               (rv_timer_env_cfg),
    .COV_T               (rv_timer_env_cov),
    .VIRTUAL_SEQUENCER_T (rv_timer_rst_safe_virtual_sequencer),
    .SCOREBOARD_T        (rv_timer_rst_safe_scoreboard)
  );
  `uvm_component_utils(rv_timer_rst_safe_env)

  clk_rst_agent rst_safe_clk_rst_agt;
  delay_agent   rst_safe_delay_agt;

  extern function new(string name = "", uvm_component parent = null);
  extern function void build_phase(uvm_phase phase);
  extern function void connect_phase(uvm_phase phase);
endclass : rv_timer_rst_safe_env

function rv_timer_rst_safe_env::new(string name = "", uvm_component parent = null);
  super.new(name, parent);
endfunction : new

function void rv_timer_rst_safe_env::build_phase(uvm_phase phase);
  super.build_phase(phase);

  // rst_safe: rv_timer reset-safe stress sequences can generate dense blocking CSR traffic across
  // child sequence boundaries. Avoid deliberately biasing the TL source allocator toward the most
  // recently released source for this reset-safe TB path.
  cfg.m_tl_agent_cfg.use_last_a_source_released_pct = 0;

  rst_safe_clk_rst_agt = clk_rst_agent::type_id::create("rst_safe_clk_rst_agt", this);
  uvm_config_db#(clk_rst_agent_cfg)::set(this, "rst_safe_clk_rst_agt*", "cfg",
                                         cfg.clk_rst_agt_cfg);
  cfg.clk_rst_agt_cfg.en_cov       = cfg.en_cov;
  cfg.clk_rst_agt_cfg.reset_domain = cfg.reset_domain;

  rst_safe_delay_agt = delay_agent::type_id::create("rst_safe_delay_agt", this);
  uvm_config_db#(clk_rst_agent_cfg)::set(this, "rst_safe_delay_agt*", "cfg",
                                         cfg.clk_rst_agt_cfg);
endfunction : build_phase

function void rv_timer_rst_safe_env::connect_phase(uvm_phase phase);
  super.connect_phase(phase);
  rst_safe_clk_rst_agt.monitor.analysis_port.connect(scoreboard.clk_rst_fifo.analysis_export);
  virtual_sequencer.clk_rst_sequencer_h = rst_safe_clk_rst_agt.sequencer;
  virtual_sequencer.delay_sequencer_h   = rst_safe_delay_agt.sequencer;
endfunction : connect_phase
