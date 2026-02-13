// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// A sequence that runs other sequences one after the other. This *always* re-loads binaries, which
// is different from acc_multi_vseq where we are cleverer about reloading things.

class acc_stress_all_vseq extends acc_base_vseq;
  `uvm_object_utils(acc_stress_all_vseq)

  `uvm_object_new

  // The sequences that we'll run back-to-back
  string vseq_names[$] = {
    "acc_dmem_err_vseq",
    "acc_imem_err_vseq",
    "acc_single_vseq"
  };

  task body();
    `uvm_info(`gfn, $sformatf("Running %0d sub-sequences", num_trans), UVM_LOW)
    for (int i = 0; i < num_trans; i++) begin
      uvm_sequence   seq;
      acc_base_vseq acc_vseq;
      uint           seq_idx = $urandom_range(0, vseq_names.size() - 1);
      string         cur_vseq_name = vseq_names[seq_idx];

      // If we're running as a subsequence of acc_stress_all_with_rand_reset and i > 0, the
      // previous sequence might have exited early when the controlling sequence applied a reset. In
      // this case, wait until we come back out of reset before running the next one.
      if (cfg.under_reset) begin
        cfg.clk_rst_vif.wait_for_reset(.wait_negedge(1'b0), .wait_posedge(1'b1));
      end

      seq = create_seq_by_name(cur_vseq_name);
      `downcast(acc_vseq, seq)

      // Only force a reset at the start of the sequence if ACC is currently locked (in which case,
      // we wouldn't be able to do anything)
      acc_vseq.do_apply_reset = (cfg.model_agent_cfg.vif.status == acc_pkg::StatusLocked);
      acc_vseq.set_sequencer(p_sequencer);
      acc_vseq.start(p_sequencer);
    end
  endtask

endclass
