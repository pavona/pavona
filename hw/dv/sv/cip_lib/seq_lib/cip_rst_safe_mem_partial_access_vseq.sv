// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Run one complete partial-memory workload from reset. Block specializations can override the
// repetition constraint without changing the shared memory algorithm or its reset ownership.
class cip_rst_safe_mem_partial_access_test_seq_parameters extends dv_test_seq_parameters;
  `uvm_object_utils(cip_rst_safe_mem_partial_access_test_seq_parameters)

  constraint reset_enable_c {
    reset_testing == DISABLE;
  }

  constraint reset_loops_c {
    num_reset_loops == 1;
  }

  constraint num_trans_c {
    num_trans == 1;
  }

  function new(string name = "");
    super.new(name);
    // Common memory testing uses the memory map without functional register programming.
    do_dut_init = 1'b0;
  endfunction : new
endclass : cip_rst_safe_mem_partial_access_test_seq_parameters

// Check partial memory reads and writes, including outstanding requests, on every RAL interface.
// The shared child also serves the mixed CSR/memory test. This standalone test deliberately
// adds neither CSR traffic nor malformed TL requests. Protocol assertions remain enabled.
// The common scoreboard checks monitored memory traffic under its separate memory-check control.
//
// Only main_thread() starts traffic. Each interface child joins before normal completion, while
// the existing reset lifecycle can terminate the entire subtree without draining transactions.
// The standalone mapping does not inject random reset. Memory reset recovery requires separate
// validation on a block with memory, not a passing run on a CSR-only block.
class cip_rst_safe_mem_partial_access_vseq #(
  type RAL_T               = dv_base_reg_block,
  type CFG_T               = cip_base_env_cfg,
  type COV_T               = cip_base_env_cov,
  type VIRTUAL_SEQUENCER_T = cip_base_virtual_sequencer
) extends cip_rand_rst_safe_base_vseq #(
    .RAL_T(RAL_T),
    .CFG_T(CFG_T),
    .COV_T(COV_T),
    .VIRTUAL_SEQUENCER_T(VIRTUAL_SEQUENCER_T),
    .TEST_PARAMS_T(cip_rst_safe_mem_partial_access_test_seq_parameters),
    .CONFIG_PARAMS_T(cip_mem_partial_access_config_parameters)
  );
  `uvm_object_param_utils(cip_rst_safe_mem_partial_access_vseq #(
      RAL_T, CFG_T, COV_T, VIRTUAL_SEQUENCER_T))

  extern function new(string name = "");
  extern virtual task body();
  extern virtual task main_thread();
endclass : cip_rst_safe_mem_partial_access_vseq

function cip_rst_safe_mem_partial_access_vseq::new(string name = "");
  super.new(name);
  // Keep all traffic inside main_thread(); this test does not service block interrupts.
  do_clear_all_interrupts = 1'b0;
endfunction : new

task cip_rst_safe_mem_partial_access_vseq::body();
  if (test_params == null) begin
    test_params = cip_rst_safe_mem_partial_access_test_seq_parameters::type_id::create(
        "test_params");
  end
  if (config_params == null) begin
    config_params = cip_mem_partial_access_config_parameters::type_id::create("config_params");
  end
  void'($value$plusargs("max_accesses_for_partial_mem_access_vseq=%0d",
                       config_params.max_mem_accesses));
  super.body();
endtask : body

task cip_rst_safe_mem_partial_access_vseq::main_thread();
  disable_coverage_sample_for_csr_test();
  foreach (cfg.ral_models[i]) begin
    automatic string ral_name = i;
    fork
      begin
        cip_mem_partial_access_seq #(CFG_T, VIRTUAL_SEQUENCER_T) mem_seq;
        mem_seq = cip_mem_partial_access_seq#(CFG_T, VIRTUAL_SEQUENCER_T)::type_id::create(
            "mem_seq");
        mem_seq.ral_name = ral_name;
        mem_seq.test_params = test_params;
        mem_seq.config_params = config_params;
        mem_seq.start(p_sequencer, this);
      end
    join_none
  end
  wait fork;
endtask : main_thread
