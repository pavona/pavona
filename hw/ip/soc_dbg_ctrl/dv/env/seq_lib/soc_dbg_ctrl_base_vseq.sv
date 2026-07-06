// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Base sequence with random reset safety from which all other 'soc_dbg_ctrl' test sequences
// can be derived.

// First declare soc_dbg_ctrl_test_seq_parameters class (inherits dv_test_seq_parameters) that
// contains the control knobs required by the sequence.
// Instance of soc_dbg_ctrl_base_test_seq_parameters is randomized at the beginning of sequence
// execution and held constant until the end.
//
// 'soc_dbg_ctrl_base_config_parameters' contains all the other control knobs/parameters that any
// soc_dbg_ctrl test sequence will require. An instance of this class can be used to generate
// constraint random data during the execution of the 'main_thread()'

class soc_dbg_ctrl_base_test_seq_parameters extends dv_test_seq_parameters;
  `uvm_object_utils(soc_dbg_ctrl_base_test_seq_parameters)

  // The following control knobs / parameters are inherited that allow controlling
  // random reset assertion
  // reset_testing   = DISABLE / ENABLE;
  // num_reset_loops = <integer_value>;
  // num_trans       = <integer_value>;  -- Controls how many transactions are triggered in each run
  //                                        of the main_thread()
  // do_dut_init     = 1                 -- Controls if DUT needs to be initialized just after
  //                                        release of reset and before main_thread() is invoked
  // do_dut_shutdown = 1                 -- Controls if 'dut_shutdown()' task has to be executed

  // If reset_testing == ENABLE, 'num_reset_loops > 0' -- Put a constraint in the derived sequence
  //                                                      to limit the number of runs.
  // If reset_testing == DISABLE,'num_reset_loops == 1'-- Ensure is at least equal to '1'

  // A derived class can set the reset_enable constraint to only ENABLE or DISABLE and still will
  // not violate any constraints in this base class
  constraint reset_enable_c {
    reset_testing inside {DISABLE, ENABLE};
  }

  constraint reset_loops_c {
      if (reset_testing == ENABLE) num_reset_loops inside {[2:5]};
      if (reset_testing == DISABLE) num_reset_loops == 1;
  }

  constraint num_trans_c {
    num_trans inside {[5:50]};
  }

  function new(string name="");
    super.new(name);
  endfunction : new
endclass : soc_dbg_ctrl_base_test_seq_parameters


// The control knobs below are all the control knobs that are used inside the 'main_thread()' of
// 'soc_dbg_ctrl sequences' via 'config_params'. These control knobs are expected to be
// potentially randomized multiple times over the course of the execution of the test.
//
// Derived classes only need to add constraints
class soc_dbg_ctrl_base_config_parameters extends dv_config_parameters;
  `uvm_object_utils(soc_dbg_ctrl_base_config_parameters)

  rand soc_dbg_state_e soc_dbg_state;
  rand lc_tx_t         lc_dft_en;
  rand lc_tx_t         lc_hw_debug_en;
  rand lc_tx_t         lc_raw_test_rma;
  rand lc_tx_t         lc_cpu_en;
  rand lc_tx_t         lc_rma_state;

  rand dbg_category_e  sw_dbg_category;
  rand mubi4_t         sw_relocked;

  rand bit             zero_delays;

  function new(string name="");
    super.new(name);
  endfunction : new
endclass : soc_dbg_ctrl_base_config_parameters

// TODO:
// Base virtual sequence. Extends the legacy cip_base_vseq so that run_common_vseq_wrapper
// dispatches to cip_base_vseq. The reset-safe parent class and framework method
// overrides below are commented out for a future migration back to the reset-safe
// framework once it's stable.
// class soc_dbg_ctrl_base_vseq extends cip_rand_rst_safe_base_vseq #(
//     .RAL_T               (soc_dbg_ctrl_core_reg_block),
//     .CFG_T               (soc_dbg_ctrl_env_cfg),
//     .COV_T               (soc_dbg_ctrl_env_cov),
//     .VIRTUAL_SEQUENCER_T (soc_dbg_ctrl_virtual_sequencer),
//     .TEST_PARAMS_T       (soc_dbg_ctrl_base_test_seq_parameters),
//     .CONFIG_PARAMS_T     (soc_dbg_ctrl_base_config_parameters)
//   );
class soc_dbg_ctrl_base_vseq extends cip_base_vseq #(
    .RAL_T               (soc_dbg_ctrl_core_reg_block),
    .CFG_T               (soc_dbg_ctrl_env_cfg),
    .COV_T               (soc_dbg_ctrl_env_cov),
    .VIRTUAL_SEQUENCER_T (soc_dbg_ctrl_virtual_sequencer)
  );
  `uvm_object_utils(soc_dbg_ctrl_base_vseq)

  soc_dbg_ctrl_jtag_reg_block jtag_ral;

  // TODO:
  // Bias reset injection to arrive mid-transaction. Consumed by
  // cip_base_vseq::run_seq_with_rand_reset_vseq.
  constraint rand_reset_delay_c {
    rand_reset_delay dist {
      [10  : 50]  :/ 6,
      [51  : 200] :/ 3,
      [201 : 500] :/ 1
    };
  }

  // Standard SV/UVM methods
  extern function new(string name="");
  extern function void set_handles();
  extern virtual task dut_init(string reset_kind = "HARD");

  extern virtual task pre_start();
  extern virtual task reset_trigger_thread();
  extern task wait_delay(int unsigned num_clks);
  // TODO:
  // Reset-safe framework overrides kept commented for future migration.
  // extern virtual function void handle_reset_assertion();
  // extern virtual task          main_thread();
endclass : soc_dbg_ctrl_base_vseq


function soc_dbg_ctrl_base_vseq::new(string name="");
  super.new(name);
endfunction : new

function void soc_dbg_ctrl_base_vseq::set_handles();
  super.set_handles();
  `downcast(jtag_ral, cfg.ral_models[cfg.jtag_ral_name]);
endfunction : set_handles

task soc_dbg_ctrl_base_vseq::dut_init(string reset_kind = "HARD");
  super.dut_init(reset_kind);
endtask : dut_init

task soc_dbg_ctrl_base_vseq::pre_start();
  super.pre_start();
  `downcast(jtag_ral, cfg.ral_models[cfg.jtag_ral_name]);
endtask : pre_start

task soc_dbg_ctrl_base_vseq::wait_delay(int unsigned num_clks);
  delay_seq del_seq;
  del_seq = delay_seq::type_id::create("del_seq");
  del_seq.delay_time_steps = num_clks;
  del_seq.start(p_sequencer.delay_sequencer_h);
endtask : wait_delay

task soc_dbg_ctrl_base_vseq::reset_trigger_thread();
  delay_seq del_seq;
  reset_seq rst_seq;

  del_seq = delay_seq::type_id::create("del_seq:reset_trigger");
  del_seq.delay_time_steps = rand_reset_delay;
  del_seq.start(p_sequencer.delay_sequencer_h);

  `uvm_info(`gfn, "Triggering Reset", UVM_MEDIUM)
  rst_seq = reset_seq::type_id::create("rst_seq");
  rst_seq.start(p_sequencer.clk_rst_sequencer_h);
endtask : reset_trigger_thread

// TODO: To be included once cip_rand_rst_safe_base_vseq is stable
// function void soc_dbg_ctrl_base_vseq::handle_reset_assertion();
//   super.handle_reset_assertion();
// endfunction : handle_reset_assertion
//
// task soc_dbg_ctrl_base_vseq::main_thread();
//   `uvm_fatal(`gfn, "Derived sequence must implement main_thread()")
// endtask : main_thread
