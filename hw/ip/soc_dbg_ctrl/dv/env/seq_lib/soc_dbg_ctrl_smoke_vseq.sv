// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Test Parameters: Holds 'rand' elements that  are randomized only once for the test run and held
// constant. These inherit the base parameters and should only be set. If you need to add any new
// test control specific 'rand' elements, please review the base class and add it there
class soc_dbg_ctrl_smoke_test_seq_parameters extends soc_dbg_ctrl_base_test_seq_parameters;
  `uvm_object_utils(soc_dbg_ctrl_smoke_test_seq_parameters)

  function new(string name="");
    super.new(name);
  endfunction : new
endclass : soc_dbg_ctrl_smoke_test_seq_parameters


// Smoke-specific config parameters
class soc_dbg_ctrl_smoke_config_parameters extends soc_dbg_ctrl_base_config_parameters;
  `uvm_object_utils(soc_dbg_ctrl_smoke_config_parameters)

  function new(string name="");
    super.new(name);
  endfunction : new
endclass : soc_dbg_ctrl_smoke_config_parameters


// Basic smoke test virtual sequence
class soc_dbg_ctrl_smoke_vseq extends soc_dbg_ctrl_base_vseq;
  `uvm_object_utils(soc_dbg_ctrl_smoke_vseq)

  // Standard SV/UVM methods
  extern function new(string name="");
  extern virtual task main_thread();
endclass : soc_dbg_ctrl_smoke_vseq


function soc_dbg_ctrl_smoke_vseq::new(string name="");
  super.new(name);
  soc_dbg_ctrl_base_test_seq_parameters::type_id::set_type_override(
      soc_dbg_ctrl_smoke_test_seq_parameters::get_type());
  soc_dbg_ctrl_base_config_parameters::type_id::set_type_override(
      soc_dbg_ctrl_smoke_config_parameters::get_type());
endfunction : new

task soc_dbg_ctrl_smoke_vseq::main_thread();
  `uvm_error(`gfn, "FIXME")
endtask : main_thread
