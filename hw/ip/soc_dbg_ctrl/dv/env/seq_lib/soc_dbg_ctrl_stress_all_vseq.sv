// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Combine soc_dbg_ctrl functional vseqs into one sequence run sequentially. The CSR/common
// vseq is excluded (it requires the scoreboard disabled), as is any intr vseq (this IP has
// no interrupts).
class soc_dbg_ctrl_stress_all_vseq extends soc_dbg_ctrl_base_vseq;
  `uvm_object_utils(soc_dbg_ctrl_stress_all_vseq)

  `uvm_object_new

  constraint num_trans_c {
    num_trans inside {[3:6]};
  }

  task body();
    // TODO: only the smoke vseq exists today; add more functional vseqs here as they land.
    string seq_names[] = {"soc_dbg_ctrl_smoke_vseq"};
    for (int i = 1; i <= num_trans; i++) begin
      uvm_sequence           seq;
      soc_dbg_ctrl_base_vseq sub_vseq;
      uint                   seq_idx = $urandom_range(0, seq_names.size - 1);

      seq = create_seq_by_name(seq_names[seq_idx]);
      `downcast(sub_vseq, seq)

      // If the upper seq disables do_apply_reset (e.g. stress_all_with_rand_reset drives its
      // own resets), don't issue a reset here.
      if (do_apply_reset) begin
        sub_vseq.do_apply_reset = $urandom_range(0, 1);
      end else begin
        sub_vseq.do_apply_reset = 0;
      end

      sub_vseq.set_sequencer(p_sequencer);
      `DV_CHECK_RANDOMIZE_FATAL(sub_vseq)

      `uvm_info(`gfn, $sformatf("starting stress_all sub-sequence %s", seq_names[seq_idx]),
                UVM_LOW)
      sub_vseq.start(p_sequencer);
    end
  endtask : body

endclass : soc_dbg_ctrl_stress_all_vseq
