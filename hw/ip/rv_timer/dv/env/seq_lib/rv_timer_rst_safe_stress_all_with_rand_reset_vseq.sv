// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Reset-enabled variant of rv_timer_rst_safe_stress_all_vseq.
//
// Keep this in a separate file so the non-reset and reset-enabled stress-all entry points map
// cleanly to distinct dvsim test names and UVM sequence classes.
class rv_timer_rst_safe_stress_all_with_rand_reset_test_seq_parameters
    extends rv_timer_rst_safe_stress_all_test_seq_parameters;
  `uvm_object_utils(rv_timer_rst_safe_stress_all_with_rand_reset_test_seq_parameters)

  // The base stress-all sequence disables reset testing. This parameter override enables the
  // reset-safe body loop to fork reset_trigger_thread() against main_thread().
  constraint reset_enable_c {
    reset_testing == ENABLE;
  }

  // Run multiple reset epochs, but keep the count bounded for stress regression runtime.
  constraint reset_loops_c {
    num_reset_loops inside {[2:4]};
  }

  function new(string name = "");
    super.new(name);
  endfunction : new
endclass : rv_timer_rst_safe_stress_all_with_rand_reset_test_seq_parameters

class rv_timer_rst_safe_stress_all_with_rand_reset_vseq
    extends rv_timer_rst_safe_stress_all_vseq;
  `uvm_object_utils(rv_timer_rst_safe_stress_all_with_rand_reset_vseq)

  // rand_reset_delay controls the delay sequence used by reset_trigger_thread() before asserting
  // reset. For stress-all, this needs to cover both short children and longer future children so
  // reset can land randomly inside any selected sequence instead of consistently before/after it.
  constraint rand_reset_delay_c {
    rand_reset_delay dist {
      [1 : 1_000]                :/ 1,
      [1_001 : 100_000]          :/ 4,
      [100_001 : 1_000_000]      :/ 4,
      [1_000_001 : 10_000_000]   :/ 1
    };
  }

  extern function new(string name = "");
  extern virtual task body();
endclass : rv_timer_rst_safe_stress_all_with_rand_reset_vseq

function rv_timer_rst_safe_stress_all_with_rand_reset_vseq::new(string name = "");
  super.new(name);
endfunction : new

task rv_timer_rst_safe_stress_all_with_rand_reset_vseq::body();
  if (test_params == null) begin
    test_params =
        rv_timer_rst_safe_stress_all_with_rand_reset_test_seq_parameters::type_id::create(
            "test_seq_parameters");
  end
  super.body();
endtask : body
