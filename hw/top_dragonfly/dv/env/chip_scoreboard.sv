// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class chip_scoreboard #(type RAL_T = chip_ral_pkg::chip_reg_block) extends cip_base_scoreboard #(
    .CFG_T(chip_env_cfg),
    .RAL_T(RAL_T),
    .COV_T(chip_env_cov)
  );
  `uvm_component_param_utils(chip_scoreboard#(RAL_T))

  // local variables

  // TLM agent fifos
  uvm_tlm_analysis_fifo #(jtag_riscv_item) jtag_fifo;

  // local queues to hold incoming packets pending comparison
  uart_item       uart_tx_q[$];
  uart_item       uart_rx_q[$];
  jtag_riscv_item jtag_q[$];

  `uvm_component_new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    jtag_fifo = new("jtag_fifo", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    // Disable alert signal integrity check to avoid false alert on low_power_group_en or
    // alert_init. Alert signal integrity can be checked by assertions.
    check_alert_sig_int_err = 0;
    // Disable individual alert checking in scb. Alerts should be checked in SW or DV sequence.
    do_alert_check = 0;
    super.run_phase(phase);
    fork
      process_jtag_fifo();
      if (cfg.en_cov) process_alerts_for_cov();
    join_none
  endtask

  virtual task process_alerts_for_cov();
    int alert_cg_size = 0;
    forever @cfg.chip_vif.alerts_if.alerts_cb.alerts begin
      foreach (cfg.chip_vif.alerts_if.alerts_cb.alerts[i]) begin
        if (cfg.chip_vif.alerts_if.alerts_cb.alerts[i]) cov.alert_cg_wrap[i].sample(1'b1);
      end
    end
  endtask

  virtual task process_jtag_fifo();
    jtag_riscv_item item;
    forever begin
      jtag_fifo.get(item);
      `uvm_info(`gfn, $sformatf("received jtag item:\n%0s", item.sprint()), UVM_HIGH)
    end
  endtask

  // TODO, may add some checking later
  virtual task process_tl_access(tl_seq_item item, tl_channels_e channel, string ral_name);
    return;
  endtask

  local function bit is_rv_dm_dmi_tl_addr(string ral_name, bit [AddrWidth-1:0] addr);
    uvm_reg_addr_t norm_addr;

    if (!cfg.use_jtag_dmi || ral_name != "chip_soc_dbg_reg_block") return 0;

    norm_addr = cfg.ral_models[ral_name].get_normalized_addr(addr);
    // RV_DM's TL-UL DMI aperture in the SoC debug address space is generated at 0x0..0x1ff.
    return norm_addr inside {[32'h0 : 32'h1ff]};
  endfunction

  local function uvm_reg_addr_t get_rv_dm_dmi_word_addr(string ral_name,
                                                        bit [AddrWidth-1:0] addr);
    uvm_reg_addr_t norm_addr = cfg.ral_models[ral_name].get_normalized_addr(addr);
    return norm_addr >> jtag_riscv_agent_pkg::DMI_WORD_SHIFT;
  endfunction

  virtual task process_mem_write(tl_seq_item item, string ral_name);
    if (is_rv_dm_dmi_tl_addr(ral_name, item.a_addr)) begin
      process_rv_dm_dmi_tl_access(item, ral_name);
      return;
    end
    super.process_mem_write(item, ral_name);
  endtask

  virtual task process_mem_read(tl_seq_item item, string ral_name);
    if (is_rv_dm_dmi_tl_addr(ral_name, item.a_addr)) begin
      process_rv_dm_dmi_tl_access(item, ral_name);
      return;
    end
    super.process_mem_read(item, ral_name);
  endtask

  local task process_rv_dm_dmi_tl_access(tl_seq_item item, string ral_name);
    uvm_reg_addr_t dmi_addr = get_rv_dm_dmi_word_addr(ral_name, item.a_addr);

    // The TL-UL JTAG DTM transports stateful DMI register accesses, plus DMI status polls to
    // address 0. These are not memory-like: reads are allowed to return hardwired and side-effected
    // register state rather than the last written data. Keep the useful transport-level check and
    // bypass the generic exp_mem model for this aperture.
    `DV_CHECK_EQ(item.d_error, 0,
                 $sformatf("Unexpected TL error on RV_DM DMI access at DMI word addr 0x%0h",
                           dmi_addr))
    if (item.is_write()) begin
      `uvm_info(`gfn, $sformatf("Observed RV_DM DMI write at word addr 0x%0h, data 0x%0h",
                                dmi_addr, item.a_data), UVM_HIGH)
    end else begin
      `uvm_info(`gfn, $sformatf("Observed RV_DM DMI read at word addr 0x%0h, data 0x%0h",
                                dmi_addr, item.d_data), UVM_HIGH)
    end
  endtask

  virtual function void reset(string kind = "HARD");
    super.reset(kind);
    // reset local fifos queues and variables
  endfunction

  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    // post test checks - ensure that all local fifos and queues are empty
  endfunction

  local function bit is_rv_dm_debug_mem_addr(bit [AddrWidth-1:0] addr);
    return addr inside {[top_dragonfly_pkg::TOP_DRAGONFLY_RV_DM_MEM_BASE_ADDR :
                         top_dragonfly_pkg::TOP_DRAGONFLY_RV_DM_MEM_BASE_ADDR +
                         top_dragonfly_pkg::TOP_DRAGONFLY_RV_DM_MEM_SIZE_BYTES - 1]};
  endfunction

  local function bit is_ast_init_addr(bit [AddrWidth-1:0] addr);
    return addr inside {[top_dragonfly_pkg::TOP_DRAGONFLY_AST_BASE_ADDR :
                         top_dragonfly_pkg::TOP_DRAGONFLY_AST_BASE_ADDR +
                         ast_pkg::AstLastRegOffset]};
  endfunction

  local function bit is_rv_dm_debug_mem_fetch(tl_seq_item item, string ral_name);
    cip_tl_seq_item cip_item;

    `downcast(cip_item, item)
    return ral_name == "chip_reg_block" &&
           item.a_opcode == tlul_pkg::Get &&
           cip_item.get_instr_type() == prim_mubi_pkg::MuBi4True &&
           item.is_a_chan_intg_ok(.throw_error(0)) &&
           is_rv_dm_debug_mem_addr(item.a_addr);
  endfunction

  local function bit is_ast_init_write(tl_seq_item item, string ral_name);
    return cfg.chip_vif.stub_cpu &&
           !cfg.use_jtag_dmi &&
           ral_name == "chip_reg_block" &&
           item.a_opcode inside {tlul_pkg::PutFullData, tlul_pkg::PutPartialData} &&
           item.a_size == 2 &&
           item.a_mask == '1 &&
           item.is_a_chan_intg_ok(.throw_error(0)) &&
           is_ast_init_addr(item.a_addr);
  endfunction

  virtual function bit predict_tl_err(tl_seq_item item, tl_channels_e channel, string ral_name);
    uvm_reg_addr_t addr = cfg.ral_models[ral_name].get_normalized_addr(item.a_addr);
    uvm_mem mem = cfg.ral_models[ral_name].default_map.get_mem_by_offset(addr);

    // any access to dv_sim_window returns d_error since this is a DV mem
    // if stub_cpu is off, we force connect this DV mem with a sim_sram, accessing the DV mem is to
    // passing info from C to SV, which won't set d_error
    if (mem != null && mem.get_name() == "dv_sim_window" && cfg.chip_vif.stub_cpu) begin
      if (channel == DataChannel) `DV_CHECK_EQ(item.d_error, 1)
      return 1;
    end
    // RV_DM block DV allows CSR fetches from the debug memory. At chip level the scoreboard sees
    // chip_reg_block, not the rv_dm_mem sub-block, so handle this aperture before the base
    // scoreboard classifies fetches from memory-mapped CSRs as TL errors.
    if (is_rv_dm_debug_mem_fetch(item, ral_name)) begin
      if (channel == DataChannel) `DV_CHECK_EQ(item.d_error, 0)
      return 1;
    end
    // Stub-CPU chip tests initialize AST by writing OTP-provided config data through the chip TL
    // interface. These full-word writes are legal even when the generic chip RAL map cannot
    // classify the AST addresses as mapped CSRs on the active frontdoor map.
    if (is_ast_init_write(item, ral_name)) begin
      if (channel == DataChannel) `DV_CHECK_EQ(item.d_error, 0)
      return 1;
    end

    return super.predict_tl_err(item, channel, ral_name);
  endfunction

endclass
