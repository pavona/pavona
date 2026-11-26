// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Select the total epoch count once per test, including the final uninterrupted pass.
// The inherited body owns reset and consumes this count as each epoch starts.
class cip_rst_safe_csr_with_rand_reset_test_seq_parameters
    extends cip_rst_safe_csr_test_seq_parameters;
  `uvm_object_utils(cip_rst_safe_csr_with_rand_reset_test_seq_parameters)

  constraint reset_enable_c {
    reset_testing == ENABLE;
  }

  constraint reset_loops_c {
    num_reset_loops inside {[2:5]};
  }

  `uvm_object_new
endclass : cip_rst_safe_csr_with_rand_reset_test_seq_parameters

// Check that register accesses recover after reset cancels an earlier CSR workload.
// Reuse the normal read/write, bit-bash, aliasing, or same-register outstanding test unchanged.
// Repeat completed CSR passes in each nonfinal epoch until reset terminates the workload.
// The final epoch completes one checked pass without reset.
// This tests recovery without a final reset hiding incomplete work or incorrect register results.
// A random delay does not guarantee an accepted bus request is pending when reset arrives.
// The parent supplies each finite workload pass and the independent reset-trigger sequence.
class cip_rst_safe_csr_with_rand_reset_vseq #(
  type RAL_T               = dv_base_reg_block,
  type CFG_T               = cip_base_env_cfg,
  type COV_T               = cip_base_env_cov,
  type VIRTUAL_SEQUENCER_T = cip_base_virtual_sequencer
) extends cip_rst_safe_csr_vseq #(RAL_T, CFG_T, COV_T, VIRTUAL_SEQUENCER_T);
  `uvm_object_param_utils(cip_rst_safe_csr_with_rand_reset_vseq #(
      RAL_T, CFG_T, COV_T, VIRTUAL_SEQUENCER_T))
  `uvm_object_new

  extern virtual task body();
  extern virtual task main_thread();
endclass : cip_rst_safe_csr_with_rand_reset_vseq

task cip_rst_safe_csr_with_rand_reset_vseq::body();
  if (test_params == null) begin
    test_params = cip_rst_safe_csr_with_rand_reset_test_seq_parameters::type_id::create(
        "test_params");
  end
  super.body();
endtask : body

task cip_rst_safe_csr_with_rand_reset_vseq::main_thread();
  bit repeat_until_reset;
  uint completed_passes = 0;

  // The base decrements the epoch count before calling main_thread(). Zero identifies the final
  // pass. Repeat only when this sequence will apply reset; a child with reset delegated to its
  // wrapper must still return so the wrapper can select its next workload.
  repeat_until_reset = !reset_ctrl_higher_seq &&
                      test_params.reset_testing == dv_test_seq_parameters::ENABLE &&
                      test_params.num_reset_loops > 0;
  `uvm_info(`gfn, $sformatf(
      "CSR reset epoch: epochs_remaining=%0d repeat_until_reset=%0b",
      test_params.num_reset_loops, repeat_until_reset), UVM_LOW)

  // A short pass can finish before the random reset delay expires. Start another real CSR pass
  // instead of waiting idle. Reset terminates this main thread and its access workers through
  // the existing base flow. The final epoch returns after its finite workload completes.
  do begin
    super.main_thread();
    completed_passes++;
    `uvm_info(`gfn, $sformatf(
        "CSR reset epoch: pass %0d complete; repeat_until_reset=%0b",
        completed_passes, repeat_until_reset), UVM_LOW)
  end while (repeat_until_reset);
endtask : main_thread
