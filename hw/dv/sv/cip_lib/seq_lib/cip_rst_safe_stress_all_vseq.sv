// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Random controls used by the common reset-safe stress-all sequence. Derived block sequences may
// extend this class with additional parameters needed to configure their stress children.
class cip_rst_safe_stress_all_config_parameters extends dv_config_parameters;
  // Index of the child sequence selected for the current stress iteration.
  rand int unsigned stress_seq_idx;
  // Number of clock cycles inserted between children so agent and scoreboard activity caused by the
  // previous child can settle before the next child starts.
  rand int unsigned child_gap_delay;
  // Runtime size of the block-provided child list; used to constrain stress_seq_idx.
  int unsigned      num_stress_seqs;

  constraint stress_seq_idx_c {
    stress_seq_idx < num_stress_seqs;
  }

  constraint child_gap_delay_c {
    child_gap_delay inside {[1:10]};
  }

  `uvm_object_utils_begin(cip_rst_safe_stress_all_config_parameters)
    `uvm_field_int(stress_seq_idx, UVM_DEFAULT)
    `uvm_field_int(child_gap_delay, UVM_DEFAULT)
    `uvm_field_int(num_stress_seqs, UVM_DEFAULT)
  `uvm_object_utils_end
  `uvm_object_new
endclass : cip_rst_safe_stress_all_config_parameters

// Block-independent reset-safe stress wrapper and reset-control boundary. Depending on its test
// parameters, it either runs without reset or triggers reset while a selected child is active.
// Derived block sequences provide the eligible child list and configure each selected child to
// delegate reset ownership to this wrapper.
virtual class cip_rst_safe_stress_all_vseq #(
  type RAL_T               = dv_base_reg_block,
  type CFG_T               = cip_base_env_cfg,
  type COV_T               = cip_base_env_cov,
  type VIRTUAL_SEQUENCER_T = cip_base_virtual_sequencer,
  type TEST_PARAMS_T       = dv_test_seq_parameters,
  type CONFIG_PARAMS_T     = cip_rst_safe_stress_all_config_parameters
) extends cip_rand_rst_safe_base_vseq #(RAL_T, CFG_T, COV_T, VIRTUAL_SEQUENCER_T,
                                        TEST_PARAMS_T, CONFIG_PARAMS_T);

  extern function new(string name = "");

  // Populate seq_names with factory names for the block's eligible stress child sequences.
  pure virtual function void get_stress_seq_names(ref string seq_names[$]);
  // Supply child-specific parameters and settings, including delegation of reset control.
  pure virtual function void configure_stress_child(uvm_sequence selected_seq);

  extern virtual task body();
  extern virtual task reset_trigger_thread();
  extern virtual task main_thread();
endclass : cip_rst_safe_stress_all_vseq

function cip_rst_safe_stress_all_vseq::new(string name = "");
  super.new(name);
  // Disable inherited post_start interrupt cleanup for the wrapper. Interrupt handling remains part
  // of the selected child's block-specific flow.
  do_clear_all_interrupts = 1'b0;
endfunction : new

task cip_rst_safe_stress_all_vseq::body();
  // Allow a derived sequence to provide specialized parameter objects before entering the common
  // reset-safe body.
  if (test_params == null) begin
    test_params = TEST_PARAMS_T::type_id::create("test_params");
  end
  if (config_params == null) begin
    config_params = CONFIG_PARAMS_T::type_id::create("config_params");
  end

  // Suppress DUT initialization only for the outer stress-all wrapper. Each selected child retains
  // its own initialization policy.
  test_params.do_dut_init = 1'b0;
  super.body();
endtask : body

task cip_rst_safe_stress_all_vseq::reset_trigger_thread();
  reset_seq rst_seq;
  delay_seq del_seq;

  // Route the randomized pre-reset delay and reset request through their dedicated sequencers. The
  // wrapper does not access clock or reset interfaces directly.
  del_seq = delay_seq::type_id::create("del_seq:reset_trigger");
  del_seq.delay_time_steps = rand_reset_delay;
  del_seq.start(p_sequencer.delay_sequencer_h);

  `uvm_info(`gfn, "Triggering reset", UVM_MEDIUM)
  rst_seq = reset_seq::type_id::create("rst_seq");
  rst_seq.start(p_sequencer.clk_rst_sequencer_h);
endtask : reset_trigger_thread

task cip_rst_safe_stress_all_vseq::main_thread();
  string                                           seq_names[$];
  cip_rst_safe_stress_all_config_parameters        stress_config_params;

  // The child list and configuration type form the contract between this common wrapper and each
  // derived block sequence.
  get_stress_seq_names(seq_names);
  if (seq_names.size() == 0) begin
    `uvm_fatal(`gfn, "Reset-safe stress-all child sequence list is empty")
  end
  if (!$cast(stress_config_params, config_params)) begin
    `uvm_fatal(`gfn, $sformatf(
        {"Reset-safe stress-all config parameters have incompatible type %0s; ",
         "expected cip_rst_safe_stress_all_config_parameters or a derived type"},
        config_params.get_type_name()))
  end
  `uvm_info(`gfn, "Starting reset-safe stress-all main_thread()", UVM_LOW)

  for (int i = 1; i <= test_params.num_trans; i++) begin
    uvm_sequence seq;
    uint         seq_idx;
    int unsigned saved_a_valid_delay_min;
    int unsigned saved_a_valid_delay_max;

    stress_config_params.num_stress_seqs = seq_names.size();
    `DV_CHECK_RANDOMIZE_FATAL(stress_config_params)
    seq_idx = stress_config_params.stress_seq_idx;

    if (i > 1) begin
      delay_seq del_seq;

      del_seq = delay_seq::type_id::create("stress_all_child_gap");
      del_seq.delay_time_steps = stress_config_params.child_gap_delay;
      `uvm_info(`gfn, $sformatf("Waiting %0d delay steps before starting next child sequence",
                                del_seq.delay_time_steps), UVM_MEDIUM)
      del_seq.start(p_sequencer.delay_sequencer_h);
    end

    seq = create_seq_by_name(seq_names[seq_idx]);
    seq.set_sequencer(p_sequencer);

    // A child may adjust the primary TL agent's A-channel valid delay. Preserve these values so the
    // adjustment cannot leak into a later child.
    saved_a_valid_delay_min = cfg.m_tl_agent_cfg.a_valid_delay_min;
    saved_a_valid_delay_max = cfg.m_tl_agent_cfg.a_valid_delay_max;

    configure_stress_child(seq);
    `DV_CHECK_RANDOMIZE_FATAL(seq)
    seq.start(p_sequencer);

    cfg.m_tl_agent_cfg.a_valid_delay_min = saved_a_valid_delay_min;
    cfg.m_tl_agent_cfg.a_valid_delay_max = saved_a_valid_delay_max;
  end

  `uvm_info(`gfn, "Exiting reset-safe stress-all main_thread()", UVM_LOW)
endtask : main_thread
