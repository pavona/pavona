// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// The mixed workload retains its longer error stream and instruction-request policy.
// These constraints override the standalone limits without duplicating the request generator.
class cip_csr_mem_tl_errors_config_parameters extends cip_tl_access_errors_config_parameters;
  `uvm_object_utils(cip_csr_mem_tl_errors_config_parameters)

  constraint error_iterations_c {
    error_iterations inside {[10:1000]};
  }

  constraint error_gap_clks_c {
    error_gap_clks inside {[500:10_000]};
  }

  function new(string name = "");
    super.new(name);
    instr_req_abort_en = 1'b1;
    instr_priority = 1;
    check_instr_rsp = 1'b0;
  endfunction : new
endclass : cip_csr_mem_tl_errors_config_parameters

// Keep separate controls for the shared memory and TL-error children. Each child clones its
// controls, so concurrent request workers cannot change each other's stimulus choices.
class cip_rst_safe_csr_mem_config_parameters extends cip_rst_safe_csr_config_parameters;
  `uvm_object_utils_begin(cip_rst_safe_csr_mem_config_parameters)
    `uvm_field_object(memory_config_params, UVM_DEFAULT)
    `uvm_field_object(tl_error_config_params, UVM_DEFAULT)
  `uvm_object_utils_end

  cip_mem_partial_access_config_parameters memory_config_params;
  cip_tl_access_errors_config_parameters tl_error_config_params;

  function new(string name = "");
    super.new(name);
    memory_config_params =
        cip_mem_partial_access_config_parameters::type_id::create("memory_config_params");
    tl_error_config_params =
        cip_csr_mem_tl_errors_config_parameters::type_id::create("tl_error_config_params");
  endfunction : new
endclass : cip_rst_safe_csr_mem_config_parameters

// Check normal register and memory accesses while the DUT also receives TL access-error traffic.
// Concurrent workers generate CSR read/write traffic, applicable partial memory accesses, and
// malformed or forbidden requests that exercise the DUT's error responses.
// The objective is to detect incorrect data or responses when these requests share an interface.
// Each worker is finite; normal completion requires all workers to finish, not only the CSR pass.
//
// CSR checks remain with the inherited CSR workload and its configured checking ownership.
// Existing scoreboard checks use monitored transactions: cfg.en_scb_mem_chk enables memory
// checking and cfg.en_scb_tl_err_chk enables TL error checking, independently of cfg.en_scb.
// This workload relies on those checks; it does not add a common register checker.
// Memory reads select bytes from successful writes in the current epoch.
// A block without memory windows skips that worker and does not validate memory behavior.
// Integrity corruption and fatal-alert recovery are outside this test.
//
// The normal variant completes without an injected reset; the derived variant adds random reset.
// All workers run below main_thread(), so the inherited reset owner can terminate them together.
// Worker-local address history and concurrency controls are rebuilt for each epoch.
class cip_rst_safe_csr_mem_vseq #(
  type RAL_T               = dv_base_reg_block,
  type CFG_T               = cip_base_env_cfg,
  type COV_T               = cip_base_env_cov,
  type VIRTUAL_SEQUENCER_T = cip_base_virtual_sequencer
) extends cip_rst_safe_csr_vseq #(RAL_T, CFG_T, COV_T, VIRTUAL_SEQUENCER_T);
  `uvm_object_param_utils(cip_rst_safe_csr_mem_vseq #(
      RAL_T, CFG_T, COV_T, VIRTUAL_SEQUENCER_T))
  `uvm_object_new

  // This is sequence-local epoch history, not DUT state shared through configuration.
  protected bit check_reset_values;

  extern virtual task body();
  extern virtual task main_thread();
  extern virtual task run_memory_traffic(string ral_name);
  extern virtual task run_error_traffic(string ral_name);
endclass : cip_rst_safe_csr_mem_vseq

task cip_rst_safe_csr_mem_vseq::body();
  bit saved_tl_assert_en = 1'b1;
  cip_rst_safe_csr_mem_config_parameters mixed_config_params;

  if (test_params == null) begin
    test_params = cip_rst_safe_csr_test_seq_parameters::type_id::create("test_params");
  end
  if (config_params == null) begin
    config_params = cip_rst_safe_csr_mem_config_parameters::type_id::create("config_params");
  end
  `downcast(mixed_config_params, config_params)
  void'($value$plusargs("max_accesses_for_partial_mem_access_vseq=%0d",
                       mixed_config_params.memory_config_params.max_mem_accesses));
  test_params.csr_test_type = "rw";
  check_reset_values = 1'b0;

  // Malformed requests deliberately violate protocol assertions. The outer body survives each
  // internal reset, so it owns this setting across all epochs and restores it after all workers
  // finish. No worker must reach a cleanup statement for this setting to be restored.
  void'(uvm_config_db#(bit)::get(null, "*", "tlul_assert_en", saved_tl_assert_en));
  uvm_config_db#(bit)::set(null, "*", "tlul_assert_en", 1'b0);
  super.body();
  uvm_config_db#(bit)::set(null, "*", "tlul_assert_en", saved_tl_assert_en);
endtask : body

task cip_rst_safe_csr_mem_vseq::main_thread();
  disable_coverage_sample_for_csr_test();

  // Preserve the register-reset checks after an interrupted epoch. They remain ordinary
  // reset-terminable CSR traffic; they do not hold off the independent reset thread.
  if (check_reset_values) begin
    run_csr_vseq(.csr_test_type("hw_reset"), .do_rand_wr_and_reset(0));
  end
  check_reset_values = 1'b1;

  // Strict FIFO arbitration gives ordinary CSR traffic priority over low-priority error
  // requests. Apply it to every RAL interface used by this workload.
  foreach (p_sequencer.tl_sequencer_hs[i]) begin
    p_sequencer.tl_sequencer_hs[i].set_arbitration(UVM_SEQ_ARB_STRICT_FIFO);
  end

  `uvm_info(`gfn, "Starting concurrent CSR, memory, and TL access-error traffic", UVM_LOW)
  fork
    begin
      run_csr_vseq_wrapper(test_params.num_trans);
      `uvm_info(`gfn, "Mixed workload: CSR passes complete", UVM_LOW)
    end
    begin
      foreach (cfg.ral_models[i]) begin
        automatic string ral_name = i;
        fork
          run_memory_traffic(ral_name);
          run_error_traffic(ral_name);
        join_none
      end
      wait fork;
    end
  join
  `uvm_info(`gfn, "Mixed workload: all workers complete", UVM_LOW)
endtask : main_thread

task cip_rst_safe_csr_mem_vseq::run_memory_traffic(string ral_name);
  cip_rst_safe_csr_mem_config_parameters mixed_config_params;
  cip_mem_partial_access_seq #(CFG_T, VIRTUAL_SEQUENCER_T) mem_seq;
  `downcast(mixed_config_params, config_params)
  mem_seq = cip_mem_partial_access_seq#(CFG_T, VIRTUAL_SEQUENCER_T)::type_id::create("mem_seq");
  mem_seq.ral_name = ral_name;
  mem_seq.test_params = test_params;
  mem_seq.config_params = mixed_config_params.memory_config_params;
  // The shared child starts below main_thread() and inherits its destructive reset boundary.
  // It keeps history within this invocation and leaves the caller's parameter objects unchanged.
  mem_seq.start(p_sequencer, this);
endtask : run_memory_traffic

task cip_rst_safe_csr_mem_vseq::run_error_traffic(string ral_name);
  cip_rst_safe_csr_mem_config_parameters mixed_config_params;
  cip_tl_access_errors_seq #(CFG_T, VIRTUAL_SEQUENCER_T) tl_errors_seq;
  `downcast(mixed_config_params, config_params)
  tl_errors_seq =
      cip_tl_access_errors_seq#(CFG_T, VIRTUAL_SEQUENCER_T)::type_id::create("tl_errors_seq");
  tl_errors_seq.ral_name = ral_name;
  tl_errors_seq.config_params = mixed_config_params.tl_error_config_params;
  // The child clones its controls and owns no reset. All its workers remain below this
  // main_thread(), alongside the CSR and memory traffic, under the same reset owner.
  tl_errors_seq.start(p_sequencer, this);
endtask : run_error_traffic
