// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class ${module_instance_name}_rst_safe_env extends cip_rst_safe_base_env #(
    .CFG_T              (${module_instance_name}_env_cfg),
    .COV_T              (${module_instance_name}_env_cov),
    .VIRTUAL_SEQUENCER_T(${module_instance_name}_virtual_sequencer),
    .SCOREBOARD_T       (${module_instance_name}_rst_safe_scoreboard)
  );
  `uvm_component_utils(${module_instance_name}_rst_safe_env)

  tl_rst_safe_agent tl_unfilt_agt;
  tl_rst_safe_agent tl_filt_agt;

  // Standard SV/UVM methods
  extern function new(string name="", uvm_component parent=null);
  extern function void build_phase(uvm_phase phase);
  extern function void connect_phase(uvm_phase phase);
endclass : ${module_instance_name}_rst_safe_env


function ${module_instance_name}_rst_safe_env::new(string name="", uvm_component parent=null);
  super.new(name, parent);
endfunction : new

function void ${module_instance_name}_rst_safe_env::build_phase(uvm_phase phase);
  super.build_phase(phase);

  // Create Unfiltered TL agent
  tl_unfilt_agt = tl_rst_safe_agent::type_id::create("tl_unfilt_agt", this);
  uvm_config_db#(tl_agent_cfg)::set(this, "tl_unfilt_agt*", "cfg", cfg.tl_unfilt_agt_cfg);
  cfg.tl_unfilt_agt_cfg.en_cov = cfg.en_cov;
  cfg.tl_unfilt_agt_cfg.reset_domain = cfg.reset_domain;

  // Create Filtered TL agent
  tl_filt_agt = tl_rst_safe_agent::type_id::create("tl_filt_agt", this);
  uvm_config_db#(tl_agent_cfg)::set(this, "tl_filt_agt*", "cfg", cfg.tl_filt_agt_cfg);
  cfg.tl_filt_agt_cfg.en_cov = cfg.en_cov;
  cfg.tl_filt_agt_cfg.reset_domain = cfg.reset_domain;

  // Retrieve the ac_range_check_misc_io_if virtual interface
  if (!uvm_config_db#(misc_vif_t)::get(this, "", "misc_vif", cfg.misc_vif)) begin
    `uvm_fatal(`gfn, "Failed to get misc_vif from uvm_config_db")
  end
endfunction : build_phase

function void ${module_instance_name}_rst_safe_env::connect_phase(uvm_phase phase);
  super.connect_phase(phase);

  // AC Range Check assumes protocol-compliant requests on its unfiltered TL-UL interface. It
  // enforces range and permission policy, but does not detect malformed opcode, mask, address, or
  // size combinations. The generic host TL agent creates malformed-request covergroups for every
  // host interface, so disable only those instances here. Legal TL coverage on this agent and
  // protocol-error coverage on the CSR agent remain enabled.
  if (cfg.en_cov) begin
    foreach (tl_unfilt_agt.cov.m_tl_error_cov_objs[tl_error_name]) begin
      tl_unfilt_agt.cov.m_tl_error_cov_objs[tl_error_name].bit_toggle_cg.option.weight = 0;
    end
  end

  if (cfg.en_scb) begin
    tl_unfilt_agt.monitor.a_chan_port.connect(
      scoreboard.predict.tl_unfilt_a_chan_fifo.analysis_export);
    tl_unfilt_agt.monitor.d_chan_port.connect(
      scoreboard.tl_unfilt_d_chan_fifo.analysis_export);
    tl_filt_agt.monitor.a_chan_port.connect(
      scoreboard.tl_filt_a_chan_fifo.analysis_export);
    tl_filt_agt.monitor.d_chan_port.connect(
      scoreboard.predict.tl_filt_d_chan_fifo.analysis_export);
  end
  if (cfg.is_active && cfg.tl_unfilt_agt_cfg.is_active) begin
    virtual_sequencer.tl_unfilt_sqr = tl_unfilt_agt.sequencer;
  end
  if (cfg.is_active && cfg.tl_filt_agt_cfg.is_active) begin
    virtual_sequencer.tl_filt_sqr = tl_filt_agt.sequencer;
  end
endfunction : connect_phase
