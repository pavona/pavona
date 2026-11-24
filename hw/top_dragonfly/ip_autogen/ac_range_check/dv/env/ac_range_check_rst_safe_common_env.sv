// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Common register tests do not send range-filter traffic. Keep the two datapath drivers so
// their interfaces have the same idle/reset behavior as the functional environment.
// The common environment checks CSR-side traffic without constructing the range predictor.
class ac_range_check_rst_safe_common_env extends cip_rst_safe_common_env #(
    .RAL_T(ac_range_check_reg_block),
    .CFG_T(ac_range_check_env_cfg)
  );
  `uvm_component_utils(ac_range_check_rst_safe_common_env)
  `uvm_component_new

  tl_rst_safe_agent tl_unfilt_agt;
  tl_rst_safe_agent tl_filt_agt;

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    tl_unfilt_agt = tl_rst_safe_agent::type_id::create("tl_unfilt_agt", this);
    cfg.tl_unfilt_agt_cfg.en_cov = cfg.en_cov;
    cfg.tl_unfilt_agt_cfg.reset_domain = cfg.reset_domain;
    uvm_config_db#(tl_agent_cfg)::set(this, "tl_unfilt_agt*", "cfg", cfg.tl_unfilt_agt_cfg);

    tl_filt_agt = tl_rst_safe_agent::type_id::create("tl_filt_agt", this);
    cfg.tl_filt_agt_cfg.en_cov = cfg.en_cov;
    cfg.tl_filt_agt_cfg.reset_domain = cfg.reset_domain;
    uvm_config_db#(tl_agent_cfg)::set(this, "tl_filt_agt*", "cfg", cfg.tl_filt_agt_cfg);

    if (!uvm_config_db#(misc_vif_t)::get(this, "", "misc_vif", cfg.misc_vif)) begin
      `uvm_fatal(`gfn, "Failed to get misc_vif from uvm_config_db")
    end
  endfunction : build_phase

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // Malformed requests are verified on the CSR interface, not the range-filter datapath.
    // Preserve the functional environment's coverage policy for the idle upstream agent.
    if (cfg.en_cov) begin
      foreach (tl_unfilt_agt.cov.m_tl_error_cov_objs[tl_error_name]) begin
        tl_unfilt_agt.cov.m_tl_error_cov_objs[tl_error_name].bit_toggle_cg.option.weight = 0;
      end
    end
  endfunction : connect_phase
endclass : ac_range_check_rst_safe_common_env
