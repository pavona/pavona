// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Random-reset specialization of rst_safe_stress_all. It uses the identical child inventory and
// functional workloads, but permits reset to terminate an active child and restart stress from a
// clean DUT/testbench epoch. The final main-thread pass completes without another injected reset.

class ${module_instance_name}_rst_safe_stress_all_with_rand_reset_test_seq_parameters
    extends ${module_instance_name}_rst_safe_stress_all_test_seq_parameters;
  `uvm_object_utils(${module_instance_name}_rst_safe_stress_all_with_rand_reset_test_seq_parameters)

  constraint reset_enable_c {
    reset_testing == ENABLE;
  }

  constraint reset_loops_c {
    num_reset_loops inside {[2:4]};
  }

  function new(string name = "");
    super.new(name);
  endfunction : new
endclass : ${module_instance_name}_rst_safe_stress_all_with_rand_reset_test_seq_parameters

class ${module_instance_name}_rst_safe_stress_all_with_rand_reset_vseq
    extends ${module_instance_name}_rst_safe_stress_all_vseq;
  `uvm_object_utils(${module_instance_name}_rst_safe_stress_all_with_rand_reset_vseq)

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
endclass : ${module_instance_name}_rst_safe_stress_all_with_rand_reset_vseq

function ${module_instance_name}_rst_safe_stress_all_with_rand_reset_vseq::new(string name = "");
  super.new(name);
endfunction : new

task ${module_instance_name}_rst_safe_stress_all_with_rand_reset_vseq::body();
  if (test_params == null) begin
    test_params =
        ${module_instance_name}_rst_safe_stress_all_with_rand_reset_test_seq_parameters::type_id::create(
            "test_params");
  end
  super.body();
endtask : body
