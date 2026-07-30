// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class ${module_instance_name}_smoke_with_rand_reset_test_seq_parameters
    extends ${module_instance_name}_smoke_test_seq_parameters;
  `uvm_object_utils(${module_instance_name}_smoke_with_rand_reset_test_seq_parameters)

  constraint reset_enable_c {
    reset_testing == ENABLE;
  }

  constraint reset_loops_c {
    num_reset_loops inside {[2:4]};
  }

  function new(string name = "");
    super.new(name);
  endfunction : new
endclass : ${module_instance_name}_smoke_with_rand_reset_test_seq_parameters

class ${module_instance_name}_rst_safe_smoke_with_rand_reset_vseq
    extends ${module_instance_name}_rst_safe_smoke_vseq;
  `uvm_object_utils(${module_instance_name}_rst_safe_smoke_with_rand_reset_vseq)

  extern function new(string name = "");
  extern virtual task body();
endclass : ${module_instance_name}_rst_safe_smoke_with_rand_reset_vseq

function ${module_instance_name}_rst_safe_smoke_with_rand_reset_vseq::new(string name = "");
  super.new(name);
endfunction : new

task ${module_instance_name}_rst_safe_smoke_with_rand_reset_vseq::body();
  if (test_params == null) begin
    test_params =
        ${module_instance_name}_smoke_with_rand_reset_test_seq_parameters::type_id::create(
            "test_params");
  end
  super.body();
endtask : body
