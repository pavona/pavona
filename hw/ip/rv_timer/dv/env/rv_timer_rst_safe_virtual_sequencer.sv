// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class rv_timer_rst_safe_virtual_sequencer extends cip_base_virtual_sequencer #(
    .CFG_T(rv_timer_env_cfg),
    .COV_T(rv_timer_env_cov)
  );
  `uvm_component_utils(rv_timer_rst_safe_virtual_sequencer)

  delay_sequencer delay_sequencer_h;

  extern function new(string name = "", uvm_component parent = null);
  extern virtual function void handle_reset_assertion();
endclass : rv_timer_rst_safe_virtual_sequencer

function rv_timer_rst_safe_virtual_sequencer::new(string name = "", uvm_component parent = null);
  super.new(name, parent);
endfunction : new

function void rv_timer_rst_safe_virtual_sequencer::handle_reset_assertion();
  `uvm_info(`gfn, "Reset Assertion - 'stop_sequences()' on non-rst-safe agents", UVM_LOW)

  // Low level agents that do not use 'dv_rst_safe_base_agent' as the parent class need to have
  // 'stop_sequences()' called on the appropriate sequencer here.
endfunction : handle_reset_assertion
