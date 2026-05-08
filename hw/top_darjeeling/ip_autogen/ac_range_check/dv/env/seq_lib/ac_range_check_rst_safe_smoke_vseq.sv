// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class ac_range_check_smoke_test_seq_parameters extends ac_range_check_base_test_seq_parameters;

  import ac_range_check_reg_pkg::*;
  `uvm_object_utils(ac_range_check_smoke_test_seq_parameters)

  // The following parameters are inherited that allow controlling of test parameters for
  // ac_range_smoke sequence
  //
  // reset_testing   = DISABLE / ENABLE;
  // num_reset_loops = <integer_value>;
  // num_trans       = <integer_value>;  -- Controls how many transactions are triggered in each run
  //                                        of the main_thread()
  // do_dut_init     = 1                 -- Controls if DUT needs to be initialized at the beginning
  //                                        of after release of reset and before main_thread() is
  //                                        invoked
  // do_dut_shutdown = 1                 -- Controls if 'dut_shutdown90' task has to be executed
  // do_ac_range_check_init = 1;         -- Controls if ac_range_check is initialized inside the
  //                                        call for 'dut_init()'

  // If reset_testing == ENABLE, 'num_reset_loops > 0' -- Put a constraint in the derived sequence
  //                                                      to limit the number of runs.
  // If reset_testing == DISABLE,'num_reset_loops == 1'-- Ensure is at least equal to '1'



  constraint reset_enable_c {
    reset_testing == ENABLE;
  }

  constraint num_trans_c {
    num_trans inside {[(2 << DenyCountWidth)+50:(2 << DenyCountWidth)+150]};
  }

  function new(string name="");
    super.new(name);
  endfunction : new
endclass : ac_range_check_smoke_test_seq_parameters


// Config Parameters
class ac_range_check_smoke_config_parameters extends ac_range_check_base_config_parameters;

  import ac_range_check_reg_pkg::*;

  `uvm_object_utils(ac_range_check_smoke_config_parameters)

  constraint log_enable_c {
    if (apply_log_enable_c) {
      log_enable dist {
        0 :/ 3,
        1 :/ 7
      };
    } else {
      log_enable == fixed_log_enable;
    }
  }

  constraint deny_cnt_threshold_c {
    if (apply_deny_cnt_threshold_c) {
      deny_cnt_threshold dist {
        [8'd0                     : 8'd5]                     :/ 2,
        [8'd6                     : (1 << DenyCountWidth)-7]  :/ 1,
        [(1 << DenyCountWidth)-6  : (1 << DenyCountWidth)-1]  :/ 2
      };
    } else {
      deny_cnt_threshold == fixed_deny_cnt_threshold;
    }
  }

  constraint intr_enable_c {
    if (apply_intr_enable_c) {
      intr_enable dist {
        0 :/ 1,
        1 :/ 1
      };
    } else {
      intr_enable == fixed_intr_enable;
    }
  }

  function new(string name="");
    super.new(name);
  endfunction : new
endclass : ac_range_check_smoke_config_parameters



class ac_range_check_rst_safe_smoke_vseq extends ac_range_check_rand_rst_safe_base_vseq;
  import ac_range_check_reg_pkg::*;
  `uvm_object_utils(ac_range_check_rst_safe_smoke_vseq)


  // Standard SV/UVM methods
  extern function new(string name="");
  extern virtual task body();

  // Task/Methods added in dv_rand_rst_safe_base_vseq that need implementations in any derived
  // class. For this implementation of the ac_range_check_smoke sequence only the 'main_thread()'
  // is needed as there is an implementation to handle reset triggering and handling reset assertion
  // in 'ac_range_check_rand_rst_safe_base_vseq'
  //
  // extern virtual task reset_trigger_thread();
  // extern virtual function void handle_reset_assertion ();
  extern virtual task main_thread();

  // Specific tasks for
  extern task set_logging();
  extern task check_logging();
endclass : ac_range_check_rst_safe_smoke_vseq


function ac_range_check_rst_safe_smoke_vseq::new(string name="");
  super.new(name);
  ac_range_check_base_test_seq_parameters::type_id::set_type_override(
                                              ac_range_check_smoke_test_seq_parameters::get_type());
  ac_range_check_base_config_parameters::type_id::set_type_override(
                                              ac_range_check_smoke_config_parameters::get_type());
endfunction : new


task ac_range_check_rst_safe_smoke_vseq::body();
  super.body();
endtask : body


task ac_range_check_rst_safe_smoke_vseq::main_thread();
  set_logging();
  for (int i=1; i <= test_params.num_trans; i++) begin
    `uvm_info(`gfn, $sformatf("Starting seq %0d/%0d", i, test_params.num_trans), UVM_LOW)

    // Randomly keep the same configuration to allow transactions back to back transactions, as no
    // configuration change will happen in between
    randcase
      // 25% of the time, change the config
      1: begin
        `DV_CHECK_RANDOMIZE_FATAL(config_params)
        ac_range_check_init();
      end
      // 75% of the time, keep the same config
      3: begin
        `uvm_info(`gfn, $sformatf("Keep the same configuration for seq #%0d", i), UVM_MEDIUM)
      end
    endcase

    randcase
      // Trigger log_clear 10% of the time
      1: begin
        ral.log_config.log_clear.set(1);
        csr_update(.csr(ral.log_config));
      end

      // Other times, leave the configuration as is
      9: begin
        `uvm_info(`gfn, $sformatf("Do not trigger a log_clear for seq #%0d", i), UVM_MEDIUM)
      end
    endcase

    // Send a single TLUL seq with random zero delays
    send_single_tl_unfilt_tr(config_params.zero_delays);

    $display("\n");
    ral.log_config.log_clear.set(0);
    csr_update(.csr(ral.log_config));
    check_logging();
  end
  wait_no_outstanding_access();
endtask : main_thread


task ac_range_check_rst_safe_smoke_vseq::set_logging();
    config_params.apply_log_enable_c         = 1;
    config_params.apply_deny_cnt_threshold_c = 1;
    config_params.apply_intr_enable_c        = 1;

    // Randomize with constraints enabled for logging
    `DV_CHECK_RANDOMIZE_FATAL(config_params)
    // Store it
    config_params.fixed_deny_cnt_threshold = config_params.deny_cnt_threshold;
    config_params.fixed_log_enable         = config_params.log_enable;
    config_params.fixed_intr_enable        = config_params.intr_enable;

    // Set logging in CSRs
    ral.log_config.log_enable.set(config_params.log_enable);
    ral.log_config.deny_cnt_threshold.set(config_params.deny_cnt_threshold);
    csr_update(.csr(ral.log_config));

    // Set interrupt enable
    ral.intr_enable.set(config_params.intr_enable);
    csr_update(.csr(ral.intr_enable));

    // Disable constraints for logging
    config_params.apply_log_enable_c         = 0;
    config_params.apply_deny_cnt_threshold_c = 0;
    config_params.apply_intr_enable_c        = 0;
endtask : set_logging


task ac_range_check_rst_safe_smoke_vseq::check_logging();
  uvm_reg_data_t    act_config,
                    act_status,
                    act_address;

  csr_rd(.ptr(ral.log_config), .value(act_config));
  csr_rd(.ptr(ral.log_status), .value(act_status));
  csr_rd(.ptr(ral.log_address), .value(act_address));
endtask : check_logging
