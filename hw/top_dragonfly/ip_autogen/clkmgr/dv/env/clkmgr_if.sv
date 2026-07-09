// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// clkmgr interface.

interface clkmgr_if (
  input logic clk,
  input logic rst_n,
  input logic rst_aon_n,
  input logic rst_io_n,
  input logic rst_main_n
);
  import uvm_pkg::*;
  import clkmgr_env_pkg::*;

  // The ports to the dut side.

  localparam int LcTxTWidth = $bits(lc_ctrl_pkg::lc_tx_t);

  // Encodes the transactional units that are idle.
  mubi_hintables_t idle_i;

  // pwrmgr req contains ip_clk_en, set to enable the gated clocks.
  pwrmgr_pkg::pwr_clk_req_t pwr_i;

  // outputs clk_status: transitions to 1 if all clocks are enabled, and
  // to 0 when all are disabled.
  pwrmgr_pkg::pwr_clk_rsp_t pwr_o;

  // scanmode_i == MuBi4True defeats all clock gating.
  prim_mubi_pkg::mubi4_t scanmode_i;

  prim_mubi_pkg::mubi4_t jitter_en_o;
  clkmgr_pkg::clkmgr_out_t clocks_o;

  // Internal DUT signals.
  // ICEBOX(lowrisc/opentitan#18379): This is a core env component (i.e. reusable entity) that
  // makes hierarchical references into the DUT. A better strategy would be to bind this interface
  // to the DUT in tb.sv and use relative paths instead.
`ifndef CLKMGR_HIER
  `define CLKMGR_HIER tb.dut
`endif

  // The CSR values from the testbench side.
  clk_enables_t clk_enables_csr;
  always_comb
    clk_enables_csr = '{
      io_peri_en: `CLKMGR_HIER.reg2hw.clk_enables.q
    };

  clk_hints_t clk_hints_csr;
  always_comb
    clk_hints_csr = '{
    kmac: `CLKMGR_HIER.reg2hw.clk_hints.clk_main_kmac_hint.q,
    hmac: `CLKMGR_HIER.reg2hw.clk_hints.clk_main_hmac_hint.q,
    aes: `CLKMGR_HIER.reg2hw.clk_hints.clk_main_aes_hint.q,
    acc: `CLKMGR_HIER.reg2hw.clk_hints.clk_main_acc_hint.q
  };

  clk_hints_t clk_hints_status_csr;
  always_comb
    clk_hints_status_csr = '{
                             kmac: `CLKMGR_HIER.u_reg.clk_hints_status_clk_main_kmac_val_qs,
                             hmac: `CLKMGR_HIER.u_reg.clk_hints_status_clk_main_hmac_val_qs,
                             aes: `CLKMGR_HIER.u_reg.clk_hints_status_clk_main_aes_val_qs,
                             acc: `CLKMGR_HIER.u_reg.clk_hints_status_clk_main_acc_val_qs
                             };
  prim_mubi_pkg::mubi4_t jitter_enable_csr;
  always_comb begin
    jitter_enable_csr = prim_mubi_pkg::mubi4_t'(`CLKMGR_HIER.reg2hw.jitter_enable.q);
  end

  // Per-measured-clock observation state for the frequency_timeout vseq. Pulses
  // (valid_o, meas_err_o) are sampled into monotonic counts so a wait can't miss
  // them
  //   meas_running            : ref_en (measurement running in the AON domain).
  //   meas_valid_count        : completed measurements (valid_o).
  //   meas_oor_seen           : sticky; a completed measurement was out of range (slow/fast).
  //   recov_measure_err_count : measure-error deliveries into recov_err_code (meas_err_o).
  //   recov_timeout_err       : latched recov_err_code timeout bits; packed so a wait can require
  //                             all expected bits at once (a group root times out several clocks).
  logic meas_running[ClkMesrSize];
  int   meas_valid_count[ClkMesrSize];
  logic meas_oor_seen[ClkMesrSize];
  int   recov_measure_err_count[ClkMesrSize];
  logic [ClkMesrSize-1:0] recov_timeout_err;

  // Clear the sticky out-of-range observer before a timeout restart, so it reflects only that
  // restart's drained measurement
  function automatic void clear_meas_oor(clk_mesr_e clk);
    meas_oor_seen[clk] = 1'b0;
  endfunction

  freq_measurement_t io_freq_measurement;
  logic io_timeout_err;
  always @(posedge `CLKMGR_HIER.u_io_meas.u_meas.clk_i) begin
    if (`CLKMGR_HIER.u_io_meas.u_meas.valid_o) begin
      io_freq_measurement = '{valid: `CLKMGR_HIER.u_io_meas.u_meas.valid_o,
                              slow: `CLKMGR_HIER.u_io_meas.u_meas.slow_o,
                              fast: `CLKMGR_HIER.u_io_meas.u_meas.fast_o};
      meas_valid_count[ClkMesrIo] = meas_valid_count[ClkMesrIo] + 1;
      if (`CLKMGR_HIER.u_io_meas.u_meas.slow_o ||
          `CLKMGR_HIER.u_io_meas.u_meas.fast_o) begin
        meas_oor_seen[ClkMesrIo] = 1'b1;
      end
      `uvm_info("clkmgr_if", $sformatf(
                "Sampled coverage for ClkMesrIo as %p", io_freq_measurement), UVM_HIGH)
    end
  end
  always_comb io_timeout_err = `CLKMGR_HIER.u_io_meas.timeout_err_o;
  // Measurement enable as seen in the AON domain (high while a measurement runs).
  always_comb meas_running[ClkMesrIo] = `CLKMGR_HIER.u_io_meas.u_meas.ref_en;
  // meas_err_o is a pulse on the meas_chk local (clk_i) domain; count it so a wait can detect a
  // drained measurement's error landing in recov_err_code.
  always @(posedge `CLKMGR_HIER.u_io_meas.clk_i) begin
    if (`CLKMGR_HIER.u_io_meas.meas_err_o) begin
      recov_measure_err_count[ClkMesrIo] =
          recov_measure_err_count[ClkMesrIo] + 1;
    end
  end
  always_comb recov_timeout_err[ClkMesrIo] =
      `CLKMGR_HIER.u_reg.u_recov_err_code_io_timeout_err.qs;

  freq_measurement_t main_freq_measurement;
  logic main_timeout_err;
  always @(posedge `CLKMGR_HIER.u_main_meas.u_meas.clk_i) begin
    if (`CLKMGR_HIER.u_main_meas.u_meas.valid_o) begin
      main_freq_measurement = '{valid: `CLKMGR_HIER.u_main_meas.u_meas.valid_o,
                                slow: `CLKMGR_HIER.u_main_meas.u_meas.slow_o,
                                fast: `CLKMGR_HIER.u_main_meas.u_meas.fast_o};
      meas_valid_count[ClkMesrMain] = meas_valid_count[ClkMesrMain] + 1;
      if (`CLKMGR_HIER.u_main_meas.u_meas.slow_o ||
          `CLKMGR_HIER.u_main_meas.u_meas.fast_o) begin
        meas_oor_seen[ClkMesrMain] = 1'b1;
      end
      `uvm_info("clkmgr_if", $sformatf(
                "Sampled coverage for ClkMesrMain as %p", main_freq_measurement), UVM_HIGH)
    end
  end
  always_comb main_timeout_err = `CLKMGR_HIER.u_main_meas.timeout_err_o;
  // Measurement enable as seen in the AON domain (high while a measurement runs).
  always_comb meas_running[ClkMesrMain] = `CLKMGR_HIER.u_main_meas.u_meas.ref_en;
  // meas_err_o is a pulse on the meas_chk local (clk_i) domain; count it so a wait can detect a
  // drained measurement's error landing in recov_err_code.
  always @(posedge `CLKMGR_HIER.u_main_meas.clk_i) begin
    if (`CLKMGR_HIER.u_main_meas.meas_err_o) begin
      recov_measure_err_count[ClkMesrMain] =
          recov_measure_err_count[ClkMesrMain] + 1;
    end
  end
  always_comb recov_timeout_err[ClkMesrMain] =
      `CLKMGR_HIER.u_reg.u_recov_err_code_main_timeout_err.qs;


  function automatic void update_idle(mubi_hintables_t value);
    idle_i = value;
  endfunction

  function automatic void update_io_ip_clk_en(bit value);
    pwr_i.io_ip_clk_en = value;
  endfunction

  function automatic void update_main_ip_clk_en(bit value);
    pwr_i.main_ip_clk_en = value;
  endfunction

  function automatic void update_scanmode(prim_mubi_pkg::mubi4_t value);
    scanmode_i = value;
  endfunction

  function automatic void force_high_starting_count(clk_mesr_e clk);
    `uvm_info("clkmgr_if", $sformatf("Forcing count of %0s to all 1.", clk.name()), UVM_MEDIUM)
    case (clk)
      ClkMesrIo: `CLKMGR_HIER.u_io_meas.u_meas.cnt = '1;
      ClkMesrMain: `CLKMGR_HIER.u_main_meas.u_meas.cnt = '1;
      default: ;
    endcase
  endfunction

  task automatic init(mubi_hintables_t idle, prim_mubi_pkg::mubi4_t scanmode,
                      prim_mubi_pkg::mubi4_t calib_rdy = prim_mubi_pkg::MuBi4True);
    `uvm_info("clkmgr_if", "In clkmgr_if init", UVM_MEDIUM)
    foreach (meas_oor_seen[i]) meas_oor_seen[i] = 1'b0; // initalize out of range as not seen
    update_idle(idle);
    update_scanmode(scanmode);
  endtask

  // Pipeline signals that go through synchronizers with the target clock domain's clock.
  // thus the PIPELINE_DEPTH is 2.

  // Use clocking blocks clocked by the target clock domain's clock to transfer relevant
  // control signals back to the scoreboard.
  localparam int PIPELINE_DEPTH = 2;

  // Pipelines and clocking blocks for peripheral clocks.

  logic [PIPELINE_DEPTH-1:0] clk_enable_io_ffs;
  logic [PIPELINE_DEPTH-1:0] ip_clk_en_io_ffs;
  always @(posedge clocks_o.clk_io_powerup or negedge rst_io_n) begin
    if (rst_io_n) begin
      clk_enable_io_ffs <= {
        clk_enable_io_ffs[PIPELINE_DEPTH-2:0], clk_enables_csr.io_peri_en
      };
      ip_clk_en_io_ffs <= {ip_clk_en_io_ffs[PIPELINE_DEPTH-2:0], pwr_i.io_ip_clk_en};
    end else begin
      clk_enable_io_ffs <= '0;
      ip_clk_en_io_ffs  <= '0;
    end
  end
  clocking peri_io_cb @(posedge clocks_o.clk_io_powerup or negedge rst_io_n);
    input ip_clk_en = ip_clk_en_io_ffs[PIPELINE_DEPTH-1];
    input clk_enable = clk_enable_io_ffs[PIPELINE_DEPTH-1];
  endclocking

  // Pipelining and clocking block for transactional unit clocks.
  logic [PIPELINE_DEPTH-1:0][NUM_TRANS-1:0] clk_hints_ffs;
  logic [PIPELINE_DEPTH-1:0]                trans_clk_en_ffs;
  always @(posedge clocks_o.clk_main_powerup or negedge rst_main_n) begin
    if (rst_main_n) begin
      clk_hints_ffs <= {clk_hints_ffs[PIPELINE_DEPTH-2:0], clk_hints_csr};
      trans_clk_en_ffs <= {trans_clk_en_ffs[PIPELINE_DEPTH-2:0], pwr_i.main_ip_clk_en};
    end else begin
      clk_hints_ffs <= '0;
      trans_clk_en_ffs <= '0;
    end
  end
  clocking trans_cb @(posedge clocks_o.clk_main_powerup or negedge rst_main_n);
    input ip_clk_en = trans_clk_en_ffs[PIPELINE_DEPTH-1];
    input clk_hints = clk_hints_ffs[PIPELINE_DEPTH-1];
    input idle_i;
  endclocking

  clocking clk_cb @(posedge clk);
    input jitter_enable_csr;
  endclocking

endinterface
