// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Check recovery when reset interrupts concurrent CSR, memory, and TL access-error traffic.
// Select two through five total epochs, with reset in each epoch except the final one.
// Each epoch after reset first checks register reset values, then starts the same mixed workload.
// Reset can interrupt those register checks too; it need not arrive during the mixed traffic.
// The final epoch must finish its checks and all traffic workers to demonstrate useful recovery.
//
// The parent discards worker-local history and concurrency controls with each interrupted epoch.
// Memory behavior is exercised only when the block exposes memory windows.
// The inherited reset thread uses delay and reset sequences; traffic workers never apply reset.
class cip_rst_safe_csr_mem_with_rand_reset_vseq #(
  type RAL_T               = dv_base_reg_block,
  type CFG_T               = cip_base_env_cfg,
  type COV_T               = cip_base_env_cov,
  type VIRTUAL_SEQUENCER_T = cip_base_virtual_sequencer
) extends cip_rst_safe_csr_mem_vseq #(RAL_T, CFG_T, COV_T, VIRTUAL_SEQUENCER_T);
  `uvm_object_param_utils(cip_rst_safe_csr_mem_with_rand_reset_vseq #(
      RAL_T, CFG_T, COV_T, VIRTUAL_SEQUENCER_T))
  `uvm_object_new

  extern virtual task body();
endclass : cip_rst_safe_csr_mem_with_rand_reset_vseq

task cip_rst_safe_csr_mem_with_rand_reset_vseq::body();
  if (test_params == null) begin
    test_params = cip_rst_safe_csr_with_rand_reset_test_seq_parameters::type_id::create(
        "test_params");
  end
  super.body();
endtask : body
