// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class cip_base_virtual_sequencer #(type CFG_T = cip_base_env_cfg,
                                   type COV_T = cip_base_env_cov)
                                   extends dv_base_virtual_sequencer #(CFG_T, COV_T);
  `uvm_component_param_utils(cip_base_virtual_sequencer #(CFG_T, COV_T))

  // similar to (ral, ral_models) and (m_tl_agent_cfg, m_tl_agent_cfgs)
  // if the block supports only one RAL, just use tl_sequencer_h
  // if there are multiple RALs, `tl_sequencer_h` is the default one for RAL with type `RAL_T`
  tl_sequencer        tl_sequencer_h;
  tl_sequencer        tl_sequencer_hs[string];

  clk_rst_sequencer   clk_rst_sequencer_h;
  delay_sequencer     delay_sequencer_h;

  alert_esc_sequencer alert_esc_sequencer_h[string];
  push_pull_sequencer#(.DeviceDataWidth(EDN_DATA_WIDTH)) edn_pull_sequencer_h;

  // Independent monitor subscriptions for sequence-level response and recovery checks.
  // A consumer must not take observations from the scoreboard or the responder request FIFO.
  // The reset-safe environment connects these ports; legacy connections stay unchanged.
  uvm_tlm_analysis_fifo #(alert_esc_seq_item) alert_observation_fifos[string];

  `uvm_component_new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    foreach (cfg.list_of_alerts[i]) begin
      string alert_name = cfg.list_of_alerts[i];
      alert_observation_fifos[alert_name] = new({"alert_observation_fifo_", alert_name}, this);
    end
  endfunction : build_phase

  virtual function void handle_reset_assertion();
    // No observation from an earlier reset epoch may satisfy a new response check.
    // Derived virtual sequencers must call this hook as well as flushing their local FIFOs.
    foreach (alert_observation_fifos[i]) alert_observation_fifos[i].flush();
  endfunction : handle_reset_assertion

endclass
