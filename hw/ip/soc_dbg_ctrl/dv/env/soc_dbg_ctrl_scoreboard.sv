// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class soc_dbg_ctrl_scoreboard extends cip_base_scoreboard #(
    .CFG_T(soc_dbg_ctrl_env_cfg),
    .RAL_T(soc_dbg_ctrl_core_reg_block),
    .COV_T(soc_dbg_ctrl_env_cov)
  );
  `uvm_component_utils(soc_dbg_ctrl_scoreboard)

  // JTAG RAL handle (downcast from cfg.ral_models[] in connect_phase)
  soc_dbg_ctrl_jtag_reg_block jtag_ral;

  // HW-side values not derivable from RAL mirrors alone
  dbg_category_e sw_category_hw;  // RTL's internal category shadowed reg
  halt_state_e   halt_state;      // halt FSM shadow, advanced one state per clock

  // Standard SV/UVM methods
  extern function new(string name, uvm_component parent);
  extern function void build_phase(uvm_phase phase);
  extern function void connect_phase(uvm_phase phase);
  extern task run_phase(uvm_phase phase);
  extern function void check_phase(uvm_phase phase);

  // Class specific methods
  extern task process_tl_access(tl_seq_item item, tl_channels_e channel, string ral_name);
  extern task process_tl_core_access(tl_seq_item item, uvm_reg_addr_t csr_addr,
    tl_phase_e tl_phase);
  extern task process_tl_jtag_access(tl_seq_item item, uvm_reg_addr_t csr_addr,
    tl_phase_e tl_phase);
  extern function void reset(string kind = "HARD");

  // Prediction helpers
  extern function void on_category_shadowed_write();
  extern function void predict_jtag_status_from_status(uvm_reg_data_t a_data);
  extern function void predict_trace_regs();
  extern function void predict_jtag_boot_status();
  extern function void predict_jtag_trace_soc_dbg_state();
  extern function soc_dbg_policy_t compute_expected_policy();
  extern function uvm_reg_data_t   compute_expected_jtag_boot_status();
  extern task advance_halt_fsm();
endclass : soc_dbg_ctrl_scoreboard


function soc_dbg_ctrl_scoreboard::new(string name, uvm_component parent);
  super.new(name, parent);
endfunction : new

function void soc_dbg_ctrl_scoreboard::build_phase(uvm_phase phase);
  super.build_phase(phase);
  // TODO: remove once support alert checking
  do_alert_check = 0;
endfunction : build_phase

function void soc_dbg_ctrl_scoreboard::connect_phase(uvm_phase phase);
  super.connect_phase(phase);
  `downcast(jtag_ral, cfg.ral_models[cfg.jtag_ral_name])
endfunction : connect_phase

task soc_dbg_ctrl_scoreboard::run_phase(uvm_phase phase);
  super.run_phase(phase);
  wait(cfg.under_reset);
  forever begin
    wait(!cfg.under_reset);
    fork begin : isolation_fork
      fork
        advance_halt_fsm();
        begin : reset_thread
          wait(cfg.under_reset);
        end
      join_any
      disable fork;
    end join
  end
endtask : run_phase

task soc_dbg_ctrl_scoreboard::process_tl_access(tl_seq_item item,
                                                tl_channels_e channel,
                                                string ral_name);
  bit            write    = item.is_write();
  uvm_reg_addr_t csr_addr = cfg.ral_models[ral_name].get_word_aligned_addr(item.a_addr);
  tl_phase_e     tl_phase;

  if (!write && channel == AddrChannel) begin
    tl_phase = AddrRead;
  end
  if ( write && channel == AddrChannel) begin
    tl_phase = AddrWrite;
  end
  if (!write && channel == DataChannel) begin
    tl_phase = DataRead;
  end
  if ( write && channel == DataChannel) begin
    tl_phase = DataWrite;
  end

  if (ral_name == ral.get_name()) begin
    process_tl_core_access(item, csr_addr, tl_phase);
  end else if (ral_name == cfg.jtag_ral_name) begin
    process_tl_jtag_access(item, csr_addr, tl_phase);
  end else begin
    `uvm_fatal(`gfn, $sformatf("Specified RAL name %0s doesn't exist!", ral_name))
  end
endtask : process_tl_access

task soc_dbg_ctrl_scoreboard::process_tl_core_access(
  tl_seq_item item, uvm_reg_addr_t csr_addr, tl_phase_e tl_phase);
  string  ral_name      = ral.get_name();
  bit     do_read_check = 1;
  uvm_reg csr;

  if (csr_addr inside {cfg.ral_models[ral_name].csr_addrs}) begin
    csr = cfg.ral_models[ral_name].default_map.get_reg_by_offset(csr_addr);
    `DV_CHECK_NE_FATAL(csr, null)
  end else begin
    `uvm_fatal(`gfn, $sformatf("Access unexpected addr 0x%0h", csr_addr))
  end

  if (tl_phase == AddrWrite) begin
    void'(csr.predict(.value(item.a_data), .kind(UVM_PREDICT_WRITE), .be(item.a_mask)));
  end

  case (csr.get_name())
    "debug_policy_valid_shadowed": begin
      // Broadcast valid stays MuBi4True in Prod+cpu_en, but recompute so any other state
      // path stays consistent
      if (tl_phase == AddrWrite) begin
        predict_trace_regs();
      end
    end
    "debug_policy_relocked": begin
      // Sw_relocked feeds the broadcast under Prod+cpu_en+not-RMA
      if (tl_phase == AddrWrite) begin
        predict_trace_regs();
      end
    end
    "status": begin
      // Mirror STATUS writes onto jtag_status so the JTAG-side auto compare stays valid
      if (tl_phase == AddrWrite) begin
        predict_jtag_status_from_status(item.a_data);
      end
    end
    "alert_test": begin
      // FIXME TODO Mvy
    end
    "debug_policy_category_shadowed": begin
      // Track sw_category_hw with RTL gating; RAL mirror alone diverges after VALID locks
      if (tl_phase == AddrWrite) begin
        on_category_shadowed_write();
        predict_trace_regs();
      end
      do_read_check = 1'b0;
    end
    "trace_debug_policy_category": begin
      // Mirror updated at write-time via predict_trace_regs
    end
    "trace_debug_policy_valid_relocked": begin
      // Mirror updated at write-time via predict_trace_regs
    end
    default: begin
      `uvm_fatal(`gfn, $sformatf("invalid CSR: %0s", csr.get_full_name()))
    end
  endcase

  if (tl_phase == DataRead) begin
    if (do_read_check) begin
      `DV_CHECK_EQ(csr.get_mirrored_value(), item.d_data,
                   $sformatf("reg name: %0s", csr.get_full_name()))
    end
    void'(csr.predict(.value(item.d_data), .kind(UVM_PREDICT_READ)));
  end
endtask : process_tl_core_access

task soc_dbg_ctrl_scoreboard::process_tl_jtag_access(
  tl_seq_item item, uvm_reg_addr_t csr_addr, tl_phase_e tl_phase);
  string  ral_name      = cfg.jtag_ral_name;
  bit     do_read_check = 1;
  uvm_reg csr;

  if (csr_addr inside {cfg.ral_models[ral_name].csr_addrs}) begin
    csr = cfg.ral_models[ral_name].default_map.get_reg_by_offset(csr_addr);
    `DV_CHECK_NE_FATAL(csr, null)
  end else begin
    `uvm_fatal(`gfn, $sformatf("Access unexpected addr 0x%0h", csr_addr))
  end

  if (tl_phase == AddrWrite) begin
    void'(csr.predict(.value(item.a_data), .kind(UVM_PREDICT_WRITE), .be(item.a_mask)));
  end

  case (csr.get_name())
    "jtag_control": begin
      // FIXME TODO Mvy
    end
    "jtag_trace_debug_policy_category": begin
      // Mirror updated by core-side writes via predict_trace_regs
    end
    "jtag_trace_debug_policy_valid_relocked": begin
      // Mirror updated by core-side writes via predict_trace_regs
    end
    "jtag_status": begin
      // Mirror synced from the core "status" case on write
    end
    "jtag_boot_status": begin
      // TODO: mirror driven by misc_vif and the halt FSM; no write-time trigger yet
      do_read_check = 1'b0;
    end
    "jtag_trace_soc_dbg_state": begin
      // TODO: mirror driven by misc_vif; no write-time trigger yet
      do_read_check = 1'b0;
    end
    default: begin
      `uvm_fatal(`gfn, $sformatf("invalid CSR: %0s", csr.get_full_name()))
    end
  endcase

  if (tl_phase == DataRead) begin
    if (do_read_check) begin
      `DV_CHECK_EQ(csr.get_mirrored_value(), item.d_data,
                   $sformatf("reg name: %0s", csr.get_full_name()))
    end
    void'(csr.predict(.value(item.d_data), .kind(UVM_PREDICT_READ)));
  end
endtask : process_tl_jtag_access

function void soc_dbg_ctrl_scoreboard::reset(string kind = "HARD");
  super.reset(kind);
  sw_category_hw = DbgCategoryLocked;
  halt_state     = Idle;
endfunction : reset

function void soc_dbg_ctrl_scoreboard::check_phase(uvm_phase phase);
  super.check_phase(phase);
endfunction : check_phase

function void soc_dbg_ctrl_scoreboard::on_category_shadowed_write();
  mubi4_t sw_valid = mubi4_t'(ral.debug_policy_valid_shadowed.get_mirrored_value());
  if (mubi4_test_false_strict(sw_valid)) begin
    sw_category_hw = dbg_category_e'(ral.debug_policy_category_shadowed.get_mirrored_value());
  end
endfunction : on_category_shadowed_write

function void soc_dbg_ctrl_scoreboard::predict_jtag_status_from_status(uvm_reg_data_t a_data);
  void'(jtag_ral.jtag_status.predict(.value(a_data), .kind(UVM_PREDICT_DIRECT)));
endfunction : predict_jtag_status_from_status

function void soc_dbg_ctrl_scoreboard::predict_trace_regs();
  soc_dbg_policy_t exp     = compute_expected_policy();
  uvm_reg_data_t   cat_val = exp.category;
  uvm_reg_data_t   vr_val  = {exp.relocked, exp.valid};

  if (cfg.en_cov) begin
    cov.sample_soc_dbg_policy_cg(cfg.misc_vif.soc_dbg_state,
                                 exp.valid, exp.category, exp.relocked);
  end

  void'(ral.trace_debug_policy_category.predict(
      .value(cat_val), .kind(UVM_PREDICT_DIRECT)));
  void'(ral.trace_debug_policy_valid_relocked.predict(
      .value(vr_val),  .kind(UVM_PREDICT_DIRECT)));
  void'(jtag_ral.jtag_trace_debug_policy_category.predict(
      .value(cat_val), .kind(UVM_PREDICT_DIRECT)));
  void'(jtag_ral.jtag_trace_debug_policy_valid_relocked.predict(
      .value(vr_val),  .kind(UVM_PREDICT_DIRECT)));
endfunction : predict_trace_regs

function void soc_dbg_ctrl_scoreboard::predict_jtag_boot_status();
  void'(jtag_ral.jtag_boot_status.predict(
      .value(compute_expected_jtag_boot_status()), .kind(UVM_PREDICT_DIRECT)));
endfunction : predict_jtag_boot_status

function void soc_dbg_ctrl_scoreboard::predict_jtag_trace_soc_dbg_state();
  uvm_reg_data_t val = lc_tx_test_true_strict(cfg.misc_vif.lc_dft_en) ?
                          cfg.misc_vif.soc_dbg_state : '0;
  void'(jtag_ral.jtag_trace_soc_dbg_state.predict(.value(val), .kind(UVM_PREDICT_DIRECT)));
endfunction : predict_jtag_trace_soc_dbg_state

// Mirrors the RTL decode switch
function soc_dbg_policy_t soc_dbg_ctrl_scoreboard::compute_expected_policy();
  soc_dbg_policy_t exp;
  soc_dbg_state_t  dbg_state = cfg.misc_vif.soc_dbg_state;
  lc_tx_t          dft_en    = cfg.misc_vif.lc_dft_en;
  lc_tx_t          hw_dbg_en = cfg.misc_vif.lc_hw_debug_en;
  lc_tx_t          rma       = cfg.misc_vif.lc_rma_state;
  lc_tx_t          cpu_en    = cfg.misc_vif.lc_cpu_en;
  logic            lc_done   = cfg.misc_vif.boot_status.lc_done;
  mubi4_t          sw_reloc  = mubi4_t'(ral.debug_policy_relocked.get_mirrored_value());

  case (dbg_state)
    SocDbgStBlank: begin
      exp.category = (lc_tx_test_true_strict(dft_en) || lc_tx_test_true_strict(hw_dbg_en))
                     ? DbgCategory4 : DbgCategoryLocked;
      exp.valid    = mubi4_bool_to_mubi(lc_done);
      exp.relocked = MuBi4False;
    end
    SocDbgStPreProd: begin
      exp.category = DbgCategory4;
      exp.valid    = mubi4_bool_to_mubi(lc_done);
      exp.relocked = MuBi4False;
    end
    SocDbgStProd: begin
      if (lc_tx_test_true_strict(rma)) begin
        exp.category = DbgCategory4;
        exp.valid    = MuBi4True;
        exp.relocked = MuBi4False;
      end else if (lc_tx_test_true_strict(cpu_en)) begin
        exp.category = sw_category_hw;
        exp.valid    = MuBi4True;
        exp.relocked = sw_reloc;
      end else begin
        exp.category = DbgCategoryLocked;
        exp.valid    = mubi4_bool_to_mubi(lc_done);
        exp.relocked = MuBi4False;
      end
    end
    default: begin
      exp.category = DbgCategoryLocked;
      exp.valid    = MuBi4False;
      exp.relocked = MuBi4False;
    end
  endcase

  return exp;
endfunction : compute_expected_policy

// Mirrors the RTL trace assembly gated by lc_dft_en
function uvm_reg_data_t soc_dbg_ctrl_scoreboard::compute_expected_jtag_boot_status();
  pwr_boot_status_t boot   = cfg.misc_vif.boot_status;
  lc_tx_t           dft_en = cfg.misc_vif.lc_dft_en;
  logic [2:0]       gl_done;
  logic [2:0]       gl_good;
  uvm_reg_data_t    v      = '0;

  if (!lc_tx_test_true_strict(dft_en)) begin
    return '0;
  end

  v[0]    = boot.clk_status.main_status;
  v[1]    = boot.clk_status.io_status;
  v[2]    = boot.otp_done;
  v[3]    = boot.lc_done;
  v[4]    = lc_tx_test_true_strict(boot.cpu_fetch_en);
  v[10:5] = halt_state;

  for (int i = 0; i < 3; i++) begin
    gl_done[i] = mubi4_test_true_strict(boot.rom_ctrl_status[i].done);
    gl_good[i] = mubi4_test_true_strict(boot.rom_ctrl_status[i].good);
  end
  v[13:11] = gl_done;
  v[16:14] = gl_good;

  return v;
endfunction : compute_expected_jtag_boot_status

// Mirrors the RTL halt FSM
task soc_dbg_ctrl_scoreboard::advance_halt_fsm();
  logic   lc_done;
  lc_tx_t raw_test_rma;
  lc_tx_t dft_en;
  logic   halt_pin;
  logic   jtag_ctrl_bc;

  forever begin
    @(posedge cfg.clk_rst_vif.clk);
    lc_done      = cfg.misc_vif.boot_status.lc_done;
    raw_test_rma = cfg.misc_vif.lc_raw_test_rma;
    dft_en       = cfg.misc_vif.lc_dft_en;
    halt_pin     = cfg.misc_vif.halt_cpu_boot;
    jtag_ctrl_bc = jtag_ral.jtag_control.boot_continue.get_mirrored_value();

    case (halt_state)
      Idle: begin
        if (lc_done) begin
          halt_state = CheckLifecycleState;
        end
      end
      CheckLifecycleState: begin
        halt_state = lc_tx_test_true_strict(raw_test_rma) ? Wait4DftEn : HaltDone;
      end
      Wait4DftEn: begin
        if (lc_tx_test_true_strict(dft_en)) begin
          halt_state = CheckHaltPin;
        end
      end
      CheckHaltPin: begin
        halt_state = halt_pin ? CheckJtagGo : HaltDone;
      end
      CheckJtagGo: begin
        if (jtag_ctrl_bc) begin
          halt_state = HaltDone;
        end
      end
      HaltDone: begin
      end
      default: begin
      end
    endcase
  end
endtask : advance_halt_fsm
