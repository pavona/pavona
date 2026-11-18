// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Run the standalone access-error workload once from register reset values. Fault recovery
// is not needed for these rejected accesses; integrity faults have a separate reset contract.
class cip_rst_safe_tl_errors_test_seq_parameters extends dv_test_seq_parameters;
  `uvm_object_utils(cip_rst_safe_tl_errors_test_seq_parameters)

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
    // Generic access-error checks do not require block-specific functional programming.
    do_dut_init = 1'b0;
  endfunction : new
endclass : cip_rst_safe_tl_errors_test_seq_parameters

// Verify rejection of malformed and forbidden TL requests on every RAL interface.
// The common child selects only error categories supported by the register and memory map.
// It is also used by the mixed CSR/memory test, but this standalone test keeps the smaller
// workload: one batch of 10 through 20 streams per iteration, with no delay after the batch.
// Response verification relies on the existing scoreboard TL error checks, enabled through
// cfg.en_scb_tl_err_chk. These checks use monitored transactions and do not require cfg.en_scb.
// They are separate from ordinary register checking; this workload adds no register checker.
// The standalone mapping does not inject random reset. The mixed reset test uses the same child.
//
// All stimulus runs below main_thread(). The outer body owns the protocol-assertion setting,
// so restoration does not depend on an interrupted request worker reaching a cleanup step.
// This test does not inject integrity corruption or perform fatal-alert recovery.
class cip_rst_safe_tl_errors_vseq #(
  type RAL_T               = dv_base_reg_block,
  type CFG_T               = cip_base_env_cfg,
  type COV_T               = cip_base_env_cov,
  type VIRTUAL_SEQUENCER_T = cip_base_virtual_sequencer
) extends cip_rand_rst_safe_base_vseq #(
    .RAL_T(RAL_T),
    .CFG_T(CFG_T),
    .COV_T(COV_T),
    .VIRTUAL_SEQUENCER_T(VIRTUAL_SEQUENCER_T),
    .TEST_PARAMS_T(cip_rst_safe_tl_errors_test_seq_parameters),
    .CONFIG_PARAMS_T(cip_tl_access_errors_config_parameters)
  );
  `uvm_object_param_utils(cip_rst_safe_tl_errors_vseq #(RAL_T, CFG_T, COV_T, VIRTUAL_SEQUENCER_T))

  extern function new(string name = "");
  extern virtual task body();
  extern virtual task main_thread();
endclass : cip_rst_safe_tl_errors_vseq

function cip_rst_safe_tl_errors_vseq::new(string name = "");
  super.new(name);
  // Keep register traffic inside the reset-owned workload, not in post_start().
  do_clear_all_interrupts = 1'b0;
endfunction : new

task cip_rst_safe_tl_errors_vseq::body();
  bit saved_tl_assert_en = 1'b1;

  if (test_params == null) begin
    test_params = cip_rst_safe_tl_errors_test_seq_parameters::type_id::create("test_params");
  end
  if (config_params == null) begin
    config_params = cip_tl_access_errors_config_parameters::type_id::create("config_params");
  end

  // The requests deliberately violate protocol assertions. Response checking remains active.
  void'(uvm_config_db#(bit)::get(null, "*", "tlul_assert_en", saved_tl_assert_en));
  uvm_config_db#(bit)::set(null, "*", "tlul_assert_en", 1'b0);
  super.body();
  uvm_config_db#(bit)::set(null, "*", "tlul_assert_en", saved_tl_assert_en);
endtask : body

task cip_rst_safe_tl_errors_vseq::main_thread();
  // Invalid register accesses do not prove intentional MuBi register programming.
  disable_coverage_sample_for_csr_test();

  repeat (test_params.num_trans) begin
    foreach (cfg.ral_models[i]) begin
      automatic string ral_name = i;
      fork
        begin
          cip_tl_access_errors_seq #(CFG_T, VIRTUAL_SEQUENCER_T) tl_errors_seq;
          tl_errors_seq = cip_tl_access_errors_seq#(CFG_T, VIRTUAL_SEQUENCER_T)::type_id::create(
              "tl_errors_seq");
          tl_errors_seq.ral_name = ral_name;
          tl_errors_seq.config_params = config_params;
          tl_errors_seq.start(p_sequencer, this);
        end
      join_none
    end
    // Wait only for this iteration's children. There is no package-wide outstanding counter
    // and no shutdown before reset; destructive reset can terminate this complete subtree.
    wait fork;
  end
endtask : main_thread
