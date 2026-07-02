// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Test parameters for the common vseq
class soc_dbg_ctrl_common_test_seq_parameters extends soc_dbg_ctrl_base_test_seq_parameters;
  `uvm_object_utils(soc_dbg_ctrl_common_test_seq_parameters)

  constraint reset_enable_c {
    reset_testing == DISABLE;
  }

  constraint num_trans_c {
    num_trans == 1;
  }

  function new(string name="");
    super.new(name);
  endfunction : new
endclass : soc_dbg_ctrl_common_test_seq_parameters


// CIP-specific config parameters
class soc_dbg_ctrl_common_config_parameters extends soc_dbg_ctrl_base_config_parameters;
  `uvm_object_utils(soc_dbg_ctrl_common_config_parameters)

  function new(string name="");
    super.new(name);
  endfunction : new
endclass : soc_dbg_ctrl_common_config_parameters


// Common vseq wraps the CIP common tests (csr_hw_reset, csr_rw, csr_bit_bash, etc.).
class soc_dbg_ctrl_common_vseq extends soc_dbg_ctrl_base_vseq;
  `uvm_object_utils(soc_dbg_ctrl_common_vseq)

  constraint num_trans_c {
    num_trans == 1;
  }

  // Standard SV/UVM methods
  extern function new(string name="");
  extern task body();
  // TODO:
  // extern virtual task main_thread();   // rst-safe method, for future migration
endclass : soc_dbg_ctrl_common_vseq


function soc_dbg_ctrl_common_vseq::new(string name="");
  super.new(name);
  soc_dbg_ctrl_base_test_seq_parameters::type_id::set_type_override(
      soc_dbg_ctrl_common_test_seq_parameters::get_type());
  soc_dbg_ctrl_base_config_parameters::type_id::set_type_override(
      soc_dbg_ctrl_common_config_parameters::get_type());
endfunction : new

task soc_dbg_ctrl_common_vseq::body();
  run_common_vseq_wrapper(num_trans);
endtask : body

// TODO: To be implemented in future rst-safe migration
// task soc_dbg_ctrl_common_vseq::main_thread();
//   run_common_vseq_wrapper(test_params.num_trans);
// endtask : main_thread
