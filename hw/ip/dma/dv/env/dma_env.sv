// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class dma_env extends cip_base_env #(
  .CFG_T              (dma_env_cfg),
  .COV_T              (dma_env_cov),
  .VIRTUAL_SEQUENCER_T(dma_virtual_sequencer),
  .SCOREBOARD_T       (dma_scoreboard)
);
  `uvm_component_utils(dma_env)

  `uvm_component_new

  // TL host agents keyed by GLOBAL port index `p`, one per present `DmaPortDesc` entry: 32-bit
  // `tl_agent` for `PortTlul32`, wide `dma_tl_agent` for `PortTlul64`. Keyed by `p` (not ASID) so
  // two ports may share an ASID without overwriting each other's agent handle.
  tl_agent     m_tl32_agent[int];
  dma_tl_agent m_tl64_agent[int];

  // PHASE - BUILD
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    `DV_CHECK_RANDOMIZE_FATAL(cfg)

    // Get dma interface
    if (!uvm_config_db#(dma_vif)::get(this, "", "dma_vif", cfg.dma_vif)) begin
      `uvm_fatal(`gfn, "failed to get dma_vif from uvm_config_db")
    end

    // Create one agent per present host port, keyed by ASID, binding it to the per-port interface
    // published by the testbench under `tl_agent_dma_p<global_port_idx>`.
    foreach (dma_pkg::DmaPortDesc[p]) begin
      string inst = $sformatf("tl_agent_dma_p%0d", p);
      if (dma_pkg::DmaPortDesc[p].cls == dma_pkg::PortTlul32) begin
        tl_agent_cfg c = cfg.m_tl32_cfg[p];
        // Order of monitor items: A channel item first, then D channel item.
        c.synchronise_ports = 1'b1;
        m_tl32_agent[p] = tl_agent::type_id::create(inst, this);
        uvm_config_db#(tl_agent_cfg)::set(this, inst, "cfg", c);
      end else begin
        dma_tl_agent_cfg c = cfg.m_tl64_cfg[p];
        c.synchronise_ports = 1'b1;
        // The SoC System bus does not have a TL-style 'ready' signal on the address channel.
        c.a_ready_delay_min = 0;
        c.a_ready_delay_max = 0;
        m_tl64_agent[p] = dma_tl_agent::type_id::create(inst, this);
        uvm_config_db#(dma_tl_agent_cfg)::set(this, inst, "cfg", c);
      end
    end
  endfunction: build_phase

  // PHASE - CONNECT
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // Publish the scoreboard handle into the cfg so vseqs can set expected alerts.
    cfg.scoreboard_h = scoreboard;

    // Wire each present agent's monitor analysis ports to the scoreboard FIFO for its per-port
    // interface name, and expose its sequencer in the virtual sequencer keyed by global port index
    // `p`. The scoreboard FIFO name is the per-port name `p<p>`; scoreboard ASID routing (which
    // reads `cfg.asid_names[asid]` to recover the same name) is unchanged for the default config.
    foreach (dma_pkg::DmaPortDesc[p]) begin
      string nm = dma_env_cfg::port_if_name(p);
      if (dma_pkg::DmaPortDesc[p].cls == dma_pkg::PortTlul32) begin
        tl_agent a = m_tl32_agent[p];
        virtual_sequencer.tl32_sequencer_h[p] = a.sequencer;
        a.monitor.a_chan_port.connect(
            scoreboard.tl_a_chan_fifos[cfg.dma_a_fifo[nm]].analysis_export);
        a.monitor.d_chan_port.connect(
            scoreboard.tl_d_chan_fifos[cfg.dma_d_fifo[nm]].analysis_export);
        a.monitor.channel_dir_port.connect(
            scoreboard.tl_dir_fifos[cfg.dma_dir_fifo[nm]].analysis_export);
      end else begin
        dma_tl_agent a = m_tl64_agent[p];
        virtual_sequencer.tl64_sequencer_h[p] = a.sequencer;
        a.monitor.a_chan_port.connect(
            scoreboard.tl_a_chan_fifos[cfg.dma_a_fifo[nm]].analysis_export);
        a.monitor.d_chan_port.connect(
            scoreboard.tl_d_chan_fifos[cfg.dma_d_fifo[nm]].analysis_export);
        a.monitor.channel_dir_port.connect(
            scoreboard.tl_dir_fifos[cfg.dma_dir_fifo[nm]].analysis_export);
      end
    end
  endfunction: connect_phase

  // Display scoreboard analysis fifo connections for debug
  function void display_scoreboard_connections(string intf_name);
    `uvm_info(`gfn, $sformatf("[CONNECTION] SCB DEBUG %s agent - FANIN", intf_name), UVM_HIGH)
    scoreboard.tl_a_chan_fifos[cfg.dma_a_fifo[intf_name]].analysis_export.debug_provided_to();
    scoreboard.tl_d_chan_fifos[cfg.dma_d_fifo[intf_name]].analysis_export.debug_provided_to();
    scoreboard.tl_dir_fifos[cfg.dma_dir_fifo[intf_name]].analysis_export.debug_provided_to();
  endfunction

  //  Display port connections in DV environment
  function void start_of_simulation_phase(uvm_phase phase);
    super.start_of_simulation_phase(phase);
    if (uvm_report_enabled(UVM_HIGH)) begin
      foreach (cfg.dma_a_fifo[key]) begin
        display_scoreboard_connections(key);
      end
    end
  endfunction: start_of_simulation_phase
endclass
