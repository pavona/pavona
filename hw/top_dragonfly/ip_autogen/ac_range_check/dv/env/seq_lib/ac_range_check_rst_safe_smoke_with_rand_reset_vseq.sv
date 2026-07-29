// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class ac_range_check_smoke_with_rand_reset_test_seq_parameters
    extends ac_range_check_smoke_test_seq_parameters;
  `uvm_object_utils(ac_range_check_smoke_with_rand_reset_test_seq_parameters)

  constraint reset_enable_c {
    reset_testing == ENABLE;
  }

  constraint reset_loops_c {
    num_reset_loops inside {[2:4]};
  }

  function new(string name = "");
    super.new(name);
  endfunction : new
endclass : ac_range_check_smoke_with_rand_reset_test_seq_parameters

class ac_range_check_rst_safe_smoke_with_rand_reset_vseq
    extends ac_range_check_rst_safe_smoke_vseq;
  `uvm_object_utils(ac_range_check_rst_safe_smoke_with_rand_reset_vseq)

  extern function new(string name = "");
  extern virtual task body();
endclass : ac_range_check_rst_safe_smoke_with_rand_reset_vseq

function ac_range_check_rst_safe_smoke_with_rand_reset_vseq::new(string name = "");
  super.new(name);
endfunction : new

task ac_range_check_rst_safe_smoke_with_rand_reset_vseq::body();
  if (test_params == null) begin
    test_params =
        ac_range_check_smoke_with_rand_reset_test_seq_parameters::type_id::create(
            "test_params");
  end
  super.body();
endtask : body
