// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class rv_timer_rst_safe_smoke_with_rand_reset_test_seq_parameters
    extends rv_timer_rst_safe_smoke_test_seq_parameters;
  `uvm_object_utils(rv_timer_rst_safe_smoke_with_rand_reset_test_seq_parameters)

  constraint reset_enable_c {
    reset_testing == ENABLE;
  }

  constraint reset_loops_c {
    num_reset_loops inside {[2:4]};
  }

  function new(string name = "");
    super.new(name);
  endfunction : new
endclass : rv_timer_rst_safe_smoke_with_rand_reset_test_seq_parameters

class rv_timer_rst_safe_smoke_with_rand_reset_vseq extends rv_timer_rst_safe_smoke_vseq;
  `uvm_object_utils(rv_timer_rst_safe_smoke_with_rand_reset_vseq)

  constraint rand_reset_delay_c {
    rand_reset_delay inside {[10:75]};
  }

  extern function new(string name = "");
endclass : rv_timer_rst_safe_smoke_with_rand_reset_vseq

function rv_timer_rst_safe_smoke_with_rand_reset_vseq::new(string name = "");
  super.new(name);
  rv_timer_rst_safe_test_seq_parameters::type_id::set_type_override(
      rv_timer_rst_safe_smoke_with_rand_reset_test_seq_parameters::get_type());
endfunction : new
