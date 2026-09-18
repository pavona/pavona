// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Drives sideload_clear writes between operations to exercise the sideload_clear_cg
// covergroup (states x ops x sideload-clear value x per-destination availability flags
// x regwen). Reuses the smoke flow (which fills slots and runs gen ops in every state)
// so cdi/dest cross-bins also fill in. Ported from keymgr_sideload_vseq.
class keymgr_dpe_sideload_vseq extends keymgr_dpe_smoke_vseq;
  `uvm_object_utils(keymgr_dpe_sideload_vseq)
  `uvm_object_new

  rand bit                              do_clear_sideload;
  rand bit [2:0]                        clear_dest;
  rand bit                              do_repaint_op;
  rand keymgr_dpe_pkg::keymgr_dpe_ops_e repaint_op;

  // Bias the rare "clear all" encodings (>=4) less than the per-destination ones.
  constraint clear_dest_c {
    clear_dest dist {[0:3] :/ 4,
                     [4:$] :/ 2};
  }

  virtual task keymgr_dpe_operations(bit advance_state = $urandom_range(0, 1),
                                     int num_gen_op    = $urandom_range(1, 4),
                                     bit clr_output    = $urandom_range(0, 1),
                                     bit wait_done     = 1);
    super.keymgr_dpe_operations(advance_state, num_gen_op, clr_output, wait_done);
    randomly_clear_sideload();
  endtask : keymgr_dpe_operations

  virtual task randomly_clear_sideload();
    `DV_CHECK_MEMBER_RANDOMIZE_FATAL(do_clear_sideload)
    `DV_CHECK_MEMBER_RANDOMIZE_FATAL(clear_dest)
    `DV_CHECK_MEMBER_RANDOMIZE_FATAL(do_repaint_op)
    `DV_CHECK_MEMBER_RANDOMIZE_FATAL(repaint_op)
    if (do_clear_sideload) begin
      // sideload_clear_cg samples op = `gmv(ral.control_shadowed.operation)`. Without
      // intervention that field stays at the last gen op type, so op_cp gets stuck at
      // 2/6. Optionally re-program operation to a random value (no `start` write) so
      // the sample sees varied ops -- the next real op resets the field anyway.
      if (do_repaint_op) begin
        ral.control_shadowed.operation.set(repaint_op);
        csr_update(.csr(ral.control_shadowed));
      end
      `uvm_info(`gfn, $sformatf("Clear sideload value=%0d op=%s",
                                clear_dest, repaint_op.name), UVM_LOW)
      csr_wr(.ptr(ral.sideload_clear), .value(clear_dest));
    end
  endtask : randomly_clear_sideload
endclass : keymgr_dpe_sideload_vseq
