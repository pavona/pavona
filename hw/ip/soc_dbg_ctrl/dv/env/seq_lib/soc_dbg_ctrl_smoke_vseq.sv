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

  // Initial state per testplan
  cfg.misc_vif.set_soc_dbg_state_prod();
  cfg.misc_vif.set_lc_cpu_en_on();
  cfg.misc_vif.set_lc_raw_test_rma_on();
  cfg.misc_vif.set_bs_lc_done(1'b1);
  cfg.clk_rst_vif.wait_clks(5);

  // Freeze per-test knobs so the in-loop randomize doesn't churn them
  jtag_release_path.rand_mode(0);
  release_delay.rand_mode(0);

  for (int i = 0; i < num_trans; i++) begin
    `uvm_info(`gfn, $sformatf("Policy iteration %0d/%0d", i + 1, num_trans), UVM_MEDIUM)

    `DV_CHECK_RANDOMIZE_FATAL(this)

    csr_wr(.ptr(ral.debug_policy_category_shadowed), .value(wr_category));
    cfg.clk_rst_vif.wait_clks(valid_delay);
    csr_wr(.ptr(ral.debug_policy_valid_shadowed), .value(wr_valid));

    // Let the SW writes propagate through the policy pipeline (reg2hw.q -> policy_q ->
    // trace reg.q, ~2-3 cycles) before reading the trace registers
    cfg.clk_rst_vif.wait_clks(3);

    // Interleaved trace reads (scoreboard's DataRead-phase compare is the check)
    csr_rd(.ptr(jtag_ral.jtag_trace_debug_policy_category),       .value(rd_val));
    csr_rd(.ptr(ral.trace_debug_policy_category),                 .value(rd_val));
    csr_rd(.ptr(jtag_ral.jtag_trace_debug_policy_valid_relocked), .value(rd_val));
    csr_rd(.ptr(ral.trace_debug_policy_valid_relocked),           .value(rd_val));

    // Random MuBi4 relocked write; broadcast through the policy under Prod+cpu_en+not-RMA
    csr_wr(.ptr(ral.debug_policy_relocked), .value(wr_relocked));
    cfg.clk_rst_vif.wait_clks(3);
    csr_rd(.ptr(ral.trace_debug_policy_valid_relocked),           .value(rd_val));
    csr_rd(.ptr(jtag_ral.jtag_trace_debug_policy_valid_relocked), .value(rd_val));

    // STATUS bits are non-contiguous (0, 4, 5, 6, 7); JTAG_STATUS mirrors them
    csr_wr(.ptr(ral.status), .value(wr_status_val));
    cfg.clk_rst_vif.wait_clks(3);
    csr_rd(.ptr(jtag_ral.jtag_status),                            .value(rd_val));
  end

  // Halt FSM is parked in Wait4DftEn, so done should be False before we trigger the release
  `DV_CHECK_EQ(cfg.misc_vif.is_continue_cpu_boot_done(), 1'b0,
               "continue_cpu_boot.done should be False before halt release")

  if (jtag_release_path) begin
    `uvm_info(`gfn, "Halt release via JTAG_CONTROL.boot_continue", UVM_MEDIUM)
    cfg.misc_vif.set_lc_dft_en_on();
    cfg.clk_rst_vif.wait_clks(release_delay);
    csr_wr(.ptr(jtag_ral.jtag_control), .value(32'h1));
  end else begin
    `uvm_info(`gfn, "Halt release via halt_cpu_boot_i de-assertion", UVM_MEDIUM)
    cfg.misc_vif.disable_halt_cpu_boot();
    cfg.clk_rst_vif.wait_clks(release_delay);
    cfg.misc_vif.set_lc_dft_en_on();
  end

  cfg.clk_rst_vif.wait_clks(20);
  `DV_CHECK_EQ(cfg.misc_vif.is_continue_cpu_boot_done(), 1'b1,
               "continue_cpu_boot.done should be True after halt release")
endtask : body

// TODO: To be implemented in future rst-safe migration
// task soc_dbg_ctrl_smoke_vseq::main_thread();
//   `uvm_error(`gfn, "FIXME")
// endtask : main_thread
