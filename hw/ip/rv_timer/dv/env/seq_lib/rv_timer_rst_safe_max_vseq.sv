// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class rv_timer_rst_safe_max_config_parameters
    extends rv_timer_rst_safe_smoke_config_parameters;
  `uvm_object_utils(rv_timer_rst_safe_max_config_parameters)

  constraint prescale_c {
    foreach (prescale[i]) {
      prescale[i] == (2**PRESCALER_WIDTH-1);
    }
  }

  constraint step_c {
    foreach (step[i]) {
      step[i] == (2**STEP_WIDTH-1);
    }
  }

  constraint timer_exp_c {
    foreach (en_harts[i]) {
      timer_val[i] == (2**MTIME_WIDTH-1);
      foreach (en_timers[j]) {
        compare_val[i][j] == (2**MTIME_WIDTH-1);
      }
    }
  }

  function new(string name = "");
    super.new(name);
  endfunction : new
endclass : rv_timer_rst_safe_max_config_parameters

class rv_timer_rst_safe_max_vseq extends rv_timer_rst_safe_smoke_vseq;
  `uvm_object_utils(rv_timer_rst_safe_max_vseq)

  extern function new(string name = "");
  extern virtual task body();
endclass : rv_timer_rst_safe_max_vseq

function rv_timer_rst_safe_max_vseq::new(string name = "");
  super.new(name);
endfunction : new

task rv_timer_rst_safe_max_vseq::body();
  if (test_params == null) begin
    test_params =
        rv_timer_rst_safe_smoke_test_seq_parameters::type_id::create("test_seq_parameters");
  end
  if (config_params == null) begin
    config_params =
        rv_timer_rst_safe_max_config_parameters::type_id::create("config_parameters");
  end
  super.body();
endtask : body
