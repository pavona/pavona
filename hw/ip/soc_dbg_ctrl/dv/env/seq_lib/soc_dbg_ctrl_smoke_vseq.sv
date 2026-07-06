// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Test Parameters: Holds 'rand' elements that  are randomized only once for the test run and held
// constant. These inherit the base parameters and should only be set. If you need to add any new
// test control specific 'rand' elements, please review the base class and add it there
class soc_dbg_ctrl_smoke_test_seq_parameters extends soc_dbg_ctrl_base_test_seq_parameters;
  `uvm_object_utils(soc_dbg_ctrl_smoke_test_seq_parameters)

  function new(string name="");
    super.new(name);
  endfunction : new
endclass : soc_dbg_ctrl_smoke_test_seq_parameters


// Smoke-specific config parameters
class soc_dbg_ctrl_smoke_config_parameters extends soc_dbg_ctrl_base_config_parameters;
  `uvm_object_utils(soc_dbg_ctrl_smoke_config_parameters)

  function new(string name="");
    super.new(name);
  endfunction : new
endclass : soc_dbg_ctrl_smoke_config_parameters


// Basic smoke test virtual sequence
class soc_dbg_ctrl_smoke_vseq extends soc_dbg_ctrl_base_vseq;
  `uvm_object_utils(soc_dbg_ctrl_smoke_vseq)

  // Per-test knobs (randomized once by the sequence framework)
  constraint num_trans_c { num_trans inside {[5:20]}; }
  rand bit  jtag_release_path;
  rand int  release_delay;
  constraint release_delay_c { release_delay inside {[5:15]}; }

  // Per-iteration stimulus (re-randomized at the top of every loop pass)
  rand dbg_category_e wr_category;
  rand logic [3:0]    wr_valid;
  rand logic [3:0]    wr_relocked;
  rand logic [7:0]    wr_status_val;
  rand int            valid_delay;

  // STATUS bits are non-contiguous (0, 4, 5, 6, 7); force the unused bits to 0 so JTAG_STATUS
  // readback matches the RAL mirror bit-for-bit
  constraint wr_status_val_c {
    wr_status_val[1] == 0;
    wr_status_val[2] == 0;
    wr_status_val[3] == 0;
  }
  constraint valid_delay_c { valid_delay inside {[1:10]}; }

  // Standard SV/UVM methods
  extern function new(string name="");
  extern task body();
  // TODO:
  // extern virtual task main_thread();   // rst-safe method, for future migration
endclass : soc_dbg_ctrl_smoke_vseq


function soc_dbg_ctrl_smoke_vseq::new(string name="");
  super.new(name);
  soc_dbg_ctrl_base_test_seq_parameters::type_id::set_type_override(
      soc_dbg_ctrl_smoke_test_seq_parameters::get_type());
  soc_dbg_ctrl_base_config_parameters::type_id::set_type_override(
      soc_dbg_ctrl_smoke_config_parameters::get_type());
endfunction : new

task soc_dbg_ctrl_smoke_vseq::body();
  uvm_reg_data_t rd_val;
  soc_dbg_ctrl_misc_seq misc_seq = soc_dbg_ctrl_misc_seq::type_id::create("misc_seq");

  // Initial state per testplan
  misc_seq.soc_dbg_state       = SocDbgStProd;
  misc_seq.lc_cpu_en           = On;
  misc_seq.lc_raw_test_rma     = On;
  misc_seq.boot_status.lc_done = 1'b1;
  misc_seq.start(p_sequencer.misc_sequencer_h);
  wait_delay(5);

  // Freeze per-test knobs so the in-loop randomize doesn't churn them
  jtag_release_path.rand_mode(0);
  release_delay.rand_mode(0);

  for (int i = 0; i < num_trans; i++) begin
    `uvm_info(`gfn, $sformatf("Policy iteration %0d/%0d", i + 1, num_trans), UVM_MEDIUM)

    `DV_CHECK_RANDOMIZE_FATAL(this)

    csr_wr(.ptr(ral.debug_policy_category_shadowed), .value(wr_category));
    wait_delay(valid_delay);
    csr_wr(.ptr(ral.debug_policy_valid_shadowed), .value(wr_valid));

    // Let the SW writes propagate through the policy pipeline (reg2hw.q -> policy_q ->
    // trace reg.q, ~2-3 cycles) before reading the trace registers
    wait_delay(3);

    // Interleaved trace reads (scoreboard's DataRead-phase compare is the check)
    csr_rd(.ptr(jtag_ral.jtag_trace_debug_policy_category),       .value(rd_val));
    csr_rd(.ptr(ral.trace_debug_policy_category),                 .value(rd_val));
    csr_rd(.ptr(jtag_ral.jtag_trace_debug_policy_valid_relocked), .value(rd_val));
    csr_rd(.ptr(ral.trace_debug_policy_valid_relocked),           .value(rd_val));

    // Random MuBi4 relocked write; broadcast through the policy under Prod+cpu_en+not-RMA
    csr_wr(.ptr(ral.debug_policy_relocked), .value(wr_relocked));
    wait_delay(3);
    csr_rd(.ptr(ral.trace_debug_policy_valid_relocked),           .value(rd_val));
    csr_rd(.ptr(jtag_ral.jtag_trace_debug_policy_valid_relocked), .value(rd_val));

    // STATUS bits are non-contiguous (0, 4, 5, 6, 7); JTAG_STATUS mirrors them
    csr_wr(.ptr(ral.status), .value(wr_status_val));
    wait_delay(3);
    csr_rd(.ptr(jtag_ral.jtag_status),                            .value(rd_val));
  end

  // The scoreboard continuously checks continue_cpu_boot against its halt-FSM model, so the
  // sequence only needs to drive the release stimulus. Before this point the FSM is parked in
  // Wait4DftEn (done == False); the paths below drive it to HaltDone (done == True).
  if (jtag_release_path) begin
    `uvm_info(`gfn, "Halt release via JTAG_CONTROL.boot_continue", UVM_MEDIUM)
    misc_seq.lc_dft_en = On;
    misc_seq.start(p_sequencer.misc_sequencer_h);
    wait_delay(release_delay);
    csr_wr(.ptr(jtag_ral.jtag_control), .value(32'h1));
  end else begin
    `uvm_info(`gfn, "Halt release via halt_cpu_boot_i de-assertion", UVM_MEDIUM)
    misc_seq.halt_cpu_boot = 1'b0;
    misc_seq.start(p_sequencer.misc_sequencer_h);
    wait_delay(release_delay);
    misc_seq.lc_dft_en = On;
    misc_seq.start(p_sequencer.misc_sequencer_h);
  end

  wait_delay(20);
endtask : body

// TODO: To be implemented in future rst-safe migration
// task soc_dbg_ctrl_smoke_vseq::main_thread();
//   `uvm_error(`gfn, "FIXME")
// endtask : main_thread
