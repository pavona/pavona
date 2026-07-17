// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Reset-safe wrapper for common CSR-style tests. The common wrapper runs inside main_thread() so the
// reset-safe base sequence can terminate it cleanly when reset is asserted.
class rv_timer_rst_safe_common_test_seq_parameters extends rv_timer_rst_safe_test_seq_parameters;
  `uvm_object_utils(rv_timer_rst_safe_common_test_seq_parameters)

  // Common reset-safe tests are intended to exercise reset interruption by default.
  constraint reset_enable_c {
    reset_testing == ENABLE;
  }

  // Fixed loop count keeps the common wrapper deterministic while the CSR migration is stabilized.
  constraint reset_loops_c {
    num_reset_loops == 3;
  }

  function new(string name = "");
    super.new(name);
  endfunction : new
endclass : rv_timer_rst_safe_common_test_seq_parameters

class rv_timer_rst_safe_common_config_parameters extends rv_timer_rst_safe_config_parameters;
  `uvm_object_utils(rv_timer_rst_safe_common_config_parameters)

  function new(string name = "");
    super.new(name);
  endfunction : new
endclass : rv_timer_rst_safe_common_config_parameters

class rv_timer_rst_safe_common_vseq extends rv_timer_rand_rst_safe_base_vseq;
  `uvm_object_utils(rv_timer_rst_safe_common_vseq)

  extern function new(string name = "");
  extern virtual task main_thread();
endclass : rv_timer_rst_safe_common_vseq

function rv_timer_rst_safe_common_vseq::new(string name = "");
  super.new(name);
  rv_timer_rst_safe_test_seq_parameters::type_id::set_type_override(
      rv_timer_rst_safe_common_test_seq_parameters::get_type());
  rv_timer_rst_safe_config_parameters::type_id::set_type_override(
      rv_timer_rst_safe_common_config_parameters::get_type());
endfunction : new

task rv_timer_rst_safe_common_vseq::main_thread();
  delay_seq del_seq;

  // Running the common_vseq_wrapper defined in 'cip_rand_rst_safe_base_vseq' ensures reset
  // testing is enforced on common CSR tests.
  run_common_vseq_wrapper(.num_times(1));

  // Consume time after the common wrapper so a reset trigger has an active main_thread() window.
  del_seq = delay_seq::type_id::create("del_seq:main_thread");
  `DV_CHECK_RANDOMIZE_FATAL(del_seq)
  del_seq.start(p_sequencer.delay_sequencer_h);
  `uvm_info(`gfn, "Exiting main_thread()", UVM_LOW)
endtask : main_thread
