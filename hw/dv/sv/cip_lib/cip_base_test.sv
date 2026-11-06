// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class cip_base_test #(type CFG_T = cip_base_env_cfg,
                      type ENV_T = cip_base_env) extends dv_base_test #(CFG_T, ENV_T);
  `uvm_component_param_utils(cip_base_test #(CFG_T, ENV_T))

  `uvm_component_new

  virtual function void add_message_demotes(dv_report_catcher catcher);
    string msg;
    bit create_jtag_riscv_map;
    super.add_message_demotes(catcher);

    // Cannot use `cfg` because it has not been created.
    void'($value$plusargs("create_jtag_riscv_map=%0b", create_jtag_riscv_map));
    if (create_jtag_riscv_map) begin
      // Demote address maps warnings
      msg = "\s*map .* does not seem to be initialized correctly.*";
      catcher.add_change_sev("RegModel", msg, UVM_INFO);
    end

    // Demote Type Overrides where Templated Agents have the same type for Base driver, Host Driver
    // and Device Driver
    msg = "\s*Original and override type arguments are identical: clk_rst_driver";
    catcher.add_change_sev("TYPDUP", msg, UVM_INFO);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    void'($value$plusargs("en_scb_tl_err_chk=%0b", cfg.en_scb_tl_err_chk));
  endfunction

  virtual task run_seq(string test_seq_s, uvm_phase phase);
    super.run_seq(test_seq_s, phase);

    // CIP owns the alert agents in both the legacy and reset-safe environments,
    // so their normal end-of-test lifecycle belongs here. Once the primary
    // sequence and its objection lifecycle have completed in dv_base_test,
    // stop only each periodic ping producer. Reactive alert response sequences
    // remain alive through this cleanup, and an already-active ping handshake
    // finishes normally before this task returns.
    foreach (env.m_alert_agent[alert_name]) begin
      env.m_alert_agent[alert_name].stop_default_ping_sequence();
    end
  endtask : run_seq

  virtual task run_phase(uvm_phase phase);
    // Disable random delays in specific `prim_cdc_rand_delay`s even if CDC instrumentation is
    // enabled.  (See `cip_base_env_cfg` for details.)
    foreach (cfg.disabled_prim_cdc_rand_delays[i]) begin
      string path = {cfg.disabled_prim_cdc_rand_delays[i],
                     ".gen_enable.cdc_instrumentation_enabled"};
      `DV_CHECK(uvm_hdl_force(path, 1'b0));
    end
    super.run_phase(phase);
  endtask

endclass : cip_base_test
