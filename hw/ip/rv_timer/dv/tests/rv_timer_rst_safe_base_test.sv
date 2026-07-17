// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class rv_timer_rst_safe_base_test extends cip_base_test #(
    .ENV_T(rv_timer_rst_safe_env),
    .CFG_T(rv_timer_env_cfg)
  );
  `uvm_component_utils(rv_timer_rst_safe_base_test)

  extern function new(string name = "", uvm_component parent = null);
  extern function void build_phase(uvm_phase phase);
  extern virtual function void add_message_demotes(dv_report_catcher catcher);
endclass : rv_timer_rst_safe_base_test

function rv_timer_rst_safe_base_test::new(string name = "", uvm_component parent = null);
  super.new(name, parent);
endfunction : new

function void rv_timer_rst_safe_base_test::build_phase(uvm_phase phase);
  test_timeout_ns = 1_000_000_000; // 1s
  // rst_safe: scope the conservative TL source cooldown policy to rv_timer reset-safe tests.
  tl_agent_cfg::type_id::set_type_override(rv_timer_rst_safe_tl_agent_cfg::get_type());
  super.build_phase(phase);
endfunction : build_phase

function void rv_timer_rst_safe_base_test::add_message_demotes(dv_report_catcher catcher);
  string msg;
  string csr_test_type;

  super.add_message_demotes(catcher);

  void'($value$plusargs("csr_%0s", csr_test_type));

  if (csr_test_type == "hw_reset" || csr_test_type == "rw" || csr_test_type == "bit_bash" ||
      csr_test_type == "aliasing" || csr_test_type == "same_csr_outstanding") begin
    msg = {
      "\s*Reset Testing Enabled and main_thread() finished before reset_trigger_thread().",
      "\s*Check timings in generated rst_seq. May need to reduce the delays for reset assertion."
    };
    catcher.add_change_sev("uvm_test_top.env.virtual_sequencer.rv_timer_common_vseq",
                           msg, UVM_INFO);
  end

  msg = {
    "\s*Reset Testing Enabled and main_thread() finished before reset_trigger_thread().",
    "\s*Check timings in generated rst_seq. May need to reduce the delays for reset assertion."
  };
  catcher.add_change_sev("uvm_test_top.env.virtual_sequencer.rv_timer_rst_safe_smoke_vseq",
                         msg, UVM_INFO);
  catcher.add_change_sev(
      "uvm_test_top.env.virtual_sequencer.rv_timer_rst_safe_stress_all_with_rand_reset_vseq",
      msg, UVM_INFO);

  msg = {"\s*Trying to predict value of field '.*' while register '.*' is being accessed"};
  catcher.add_change_sev("RegModel", msg, UVM_INFO, UVM_HIGH);
endfunction : add_message_demotes
