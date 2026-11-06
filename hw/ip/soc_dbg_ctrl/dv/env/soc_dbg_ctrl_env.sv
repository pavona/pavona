// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// TODO: Reset-safe base env kept commented for future migration
// class soc_dbg_ctrl_env extends cip_rst_safe_base_env #(
//     .CFG_T              (soc_dbg_ctrl_env_cfg),
//     .COV_T              (soc_dbg_ctrl_env_cov),
//     .VIRTUAL_SEQUENCER_T(soc_dbg_ctrl_virtual_sequencer),
//     .SCOREBOARD_T       (soc_dbg_ctrl_scoreboard)
//   );
class soc_dbg_ctrl_env extends cip_base_env #(
    .CFG_T              (soc_dbg_ctrl_env_cfg),
    .COV_T              (soc_dbg_ctrl_env_cov),
    .VIRTUAL_SEQUENCER_T(soc_dbg_ctrl_virtual_sequencer),
    .SCOREBOARD_T       (soc_dbg_ctrl_scoreboard)
  );
  `uvm_component_utils(soc_dbg_ctrl_env)

  // TODO: Reset-safe agents kept commented for future migration
  // clk_rst_agent clk_rst_agt;
  // delay_agent   delay_agt;

  // Standard SV/UVM methods
  extern function new(string name, uvm_component parent);
  extern function void build_phase(uvm_phase phase);
  extern function void connect_phase(uvm_phase phase);
endclass : soc_dbg_ctrl_env


function soc_dbg_ctrl_env::new(string name, uvm_component parent);
  super.new(name, parent);
endfunction : new

function void soc_dbg_ctrl_env::build_phase(uvm_phase phase);
  super.build_phase(phase);

  // TODO: Reset-safe agent instantiation kept commented for future migration.
  // clk_rst_agt = clk_rst_agent::type_id::create("clk_rst_agt", this);
  // uvm_config_db#(clk_rst_agent_cfg)::set(this, "clk_rst_agt*", "cfg", cfg.clk_rst_agt_cfg);
  // cfg.clk_rst_agt_cfg.en_cov       = cfg.en_cov;
  // cfg.clk_rst_agt_cfg.reset_domain = cfg.reset_domain;
  //
  // delay_agt = delay_agent::type_id::create("delay_agt", this);
  // uvm_config_db#(clk_rst_agent_cfg)::set(this, "delay_agt*", "cfg", cfg.clk_rst_agt_cfg);

  // Retrieve the soc_dbg_ctrl_misc_io_if virtual interface
  if (!uvm_config_db#(misc_vif_t)::get(this, "", "misc_vif", cfg.misc_vif)) begin
    `uvm_fatal(`gfn, "Failed to get misc_vif from uvm_config_db")
  end
endfunction : build_phase

function void soc_dbg_ctrl_env::connect_phase(uvm_phase phase);
  super.connect_phase(phase);
  // TODO: Reset-safe wire-up kept commented for future migration.
  // virtual_sequencer.clk_rst_sequencer_h = clk_rst_agt.sequencer;
  // virtual_sequencer.delay_sequencer_h   = delay_agt.sequencer;
endfunction : connect_phase
