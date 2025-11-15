// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class ac_range_check_virtual_sequencer extends cip_base_virtual_sequencer #(
    .CFG_T(ac_range_check_env_cfg),
    .COV_T(ac_range_check_env_cov)
  );
  `uvm_component_utils(ac_range_check_virtual_sequencer)

  // This virtual sequencer inherits the following handles from cip_base_virtual_sequencer
  // that need be connected at an environment level
  // - clk_rst_sequencer clk_rst_sequencer_h;     -- Default clocking and reset control
  // - tl_sequencer      tl_sequencer_h;          -- TODO: Understand how this gets connected up
  // - tl_sequencer      tl_sequencer_hs[string]; -- TODO: Understand how this gets connected up

  tl_sequencer tl_unfilt_sqr;
  tl_sequencer tl_filt_sqr;

  // Standard SV/UVM methods
  extern function new(string name, uvm_component parent);

  extern virtual function void handle_reset_assertion();
endclass : ac_range_check_virtual_sequencer

function ac_range_check_virtual_sequencer::new(string name, uvm_component parent);
  super.new(name, parent);
endfunction : new

function void ac_range_check_virtual_sequencer::handle_reset_assertion();
  `uvm_info(`gfn, "Reset Assertion - Anything at a sequence level that needs to be reset", UVM_LOW)

  // Low level agent that have not used 'dv_rst_safe_base_agent' as the parent class will need to
  // have 'stop_sequences()' called on the appropriate sequencer.
  //
  // 'tl_agent' is migrated to use 'dv_rst_safe_base_agent' as the parent class, below is an example
  // of what should be done with other sequencers.
  // <sequencer_handle>.stop_sequences();
  //
  // Example:
  // tl_unfilt_sqr.stop_sequences();
  // tl_filt_sqr.stop_sequences();
endfunction : handle_reset_assertion
