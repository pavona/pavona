// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class dv_test_seq_parameters extends uvm_sequence_item;
  typedef enum {DISABLE=0, ENABLE} ENABLE_TYPE;

  // The following parameters will be inherited that allow controlling random reset assertion
  // reset_testing   = DISABLE / ENABLE; -- Control if reset_testing is enabled in a run or not
  // num_reset_loops = <integer_value>;  -- Number of time the reset loop need to be executed

  // If reset_testing == ENABLE, 'num_reset_loops > 0' -- Put a constraint in the derived sequence
  //                                                      to limit the number of runs.
  // If reset_testing == DISABLE,'num_reset_loops == 1'-- Ensure is at least equal to '1'

  // num_trans       = <integer_value>;  -- Controls how many transactions are triggered in each run
  //                                        of the main_thread()
  // do_dut_init     = 1                 -- Controls if DUT needs to be initialized at the beginning
  //                                        of after release of reset and before main_thread() is
  //                                        invoked
  // do_dut_shutdown = 1                 -- Controls if 'dut_shutdown90' task has to be executed

  rand ENABLE_TYPE      reset_testing  ;
  rand int              num_reset_loops;

  rand uint             num_trans;

  // Controls for DUT initialization and Shutdown
  bit do_dut_init       = 1'b1;
  bit do_dut_shutdown   = 1'b1;

  `uvm_object_utils_begin (dv_test_seq_parameters)
    `uvm_field_enum (ENABLE_TYPE, reset_testing  , UVM_ALL_ON          )
    `uvm_field_int  (             num_reset_loops, UVM_ALL_ON | UVM_DEC)
    `uvm_field_int  (             num_trans      , UVM_ALL_ON | UVM_DEC)
    `uvm_field_int  (             do_dut_init    , UVM_ALL_ON | UVM_DEC)
    `uvm_field_int  (             do_dut_shutdown, UVM_ALL_ON | UVM_DEC)
  `uvm_object_utils_end

  function new(string name = "");
  endfunction : new

  constraint num_trans_c {
    num_trans inside {[1:20]};
  }

  constraint reset_loops {
    if (reset_testing == ENABLE) num_reset_loops > 0;
    if (reset_testing == DISABLE) {
      soft num_reset_loops == 1;
    }
  }

  constraint additional {
      // Constraints for Test that are to be specified in the
      // derived class
  }
endclass : dv_test_seq_parameters
