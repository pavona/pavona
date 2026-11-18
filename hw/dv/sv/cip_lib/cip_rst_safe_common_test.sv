// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Run shared CSR, memory, and TL workloads with the block's existing configuration type.
// A block registers this test once. Every supported workload then uses the same environment,
// without a block sequence class for each common test or random-reset variant.
// The selected sequence retains its own test/config parameters and reset-safe execution.
class cip_rst_safe_common_test #(
  type RAL_T = dv_base_reg_block,
  type CFG_T = cip_rst_safe_base_env_cfg #(RAL_T),
  type COV_T = cip_base_env_cov #(CFG_T),
  type VIRTUAL_SEQUENCER_T = cip_base_virtual_sequencer #(CFG_T, COV_T),
  type ENV_T = cip_rst_safe_common_env #(RAL_T, CFG_T, COV_T, VIRTUAL_SEQUENCER_T)
) extends cip_base_test #(CFG_T, ENV_T);
  `uvm_component_param_utils(cip_rst_safe_common_test #(
      RAL_T, CFG_T, COV_T, VIRTUAL_SEQUENCER_T, ENV_T))
  `uvm_component_new

  typedef cip_rst_safe_csr_vseq #(
      RAL_T, CFG_T, COV_T, VIRTUAL_SEQUENCER_T) csr_seq_t;
  typedef cip_rst_safe_csr_with_rand_reset_vseq #(
      RAL_T, CFG_T, COV_T, VIRTUAL_SEQUENCER_T) csr_reset_seq_t;
  typedef cip_rst_safe_csr_mem_vseq #(
      RAL_T, CFG_T, COV_T, VIRTUAL_SEQUENCER_T) csr_mem_seq_t;
  typedef cip_rst_safe_csr_mem_with_rand_reset_vseq #(
      RAL_T, CFG_T, COV_T, VIRTUAL_SEQUENCER_T) csr_mem_reset_seq_t;
  typedef cip_rst_safe_mem_partial_access_vseq #(
      RAL_T, CFG_T, COV_T, VIRTUAL_SEQUENCER_T) mem_partial_seq_t;
  typedef cip_rst_safe_tl_errors_vseq #(
      RAL_T, CFG_T, COV_T, VIRTUAL_SEQUENCER_T) tl_errors_seq_t;
  typedef cip_rst_safe_tl_intg_err_vseq #(
      RAL_T, CFG_T, COV_T, VIRTUAL_SEQUENCER_T) tl_intg_err_seq_t;

  // HJSON selects a workload name. Type-based factory creation supplies the specialization
  // which matches this test's environment, instead of looking for a block sequence by name.
  virtual function uvm_sequence create_common_seq(string seq_name);
    case (seq_name)
      "cip_rst_safe_csr_vseq": return csr_seq_t::type_id::create(seq_name);
      "cip_rst_safe_csr_with_rand_reset_vseq":
        return csr_reset_seq_t::type_id::create(seq_name);
      "cip_rst_safe_csr_mem_vseq": return csr_mem_seq_t::type_id::create(seq_name);
      "cip_rst_safe_csr_mem_with_rand_reset_vseq":
        return csr_mem_reset_seq_t::type_id::create(seq_name);
      "cip_rst_safe_mem_partial_access_vseq":
        return mem_partial_seq_t::type_id::create(seq_name);
      "cip_rst_safe_tl_errors_vseq": return tl_errors_seq_t::type_id::create(seq_name);
      "cip_rst_safe_tl_intg_err_vseq": return tl_intg_err_seq_t::type_id::create(seq_name);
      default: begin
        `uvm_fatal(`gfn, $sformatf("Unsupported common CIP sequence: %s", seq_name))
        return null;
      end
    endcase
  endfunction : create_common_seq

  virtual task run_seq(string test_seq_s, uvm_phase phase);
    uvm_sequence test_seq = create_common_seq(test_seq_s);

    configure_sequence(test_seq);
    `DV_CHECK_RANDOMIZE_FATAL(test_seq)

    // Keep the standard execution order and one primary objection. The shared base test is
    // unchanged; only sequence creation differs here. Reset remains owned by the sequence.
    // TODO: Review this duplicated execution and shutdown code after common-test validation.
    `uvm_info(`gfn, {"Starting test sequence ", test_seq_s}, UVM_MEDIUM)
    phase.raise_objection(this, $sformatf("%s objection raised", `gn));
    test_seq.start(env.virtual_sequencer);
    phase.drop_objection(this, $sformatf("%s objection dropped", `gn));
    `uvm_info(`gfn, {"Finished test sequence ", test_seq_s}, UVM_MEDIUM)

    // Preserve CIP shutdown after the foreground sequence returns. An active ping can finish
    // before its producer stops; this test does not change alert response ownership.
    foreach (env.m_alert_agent[alert_name]) begin
      env.m_alert_agent[alert_name].stop_default_ping_sequence();
    end
  endtask : run_seq
endclass : cip_rst_safe_common_test
