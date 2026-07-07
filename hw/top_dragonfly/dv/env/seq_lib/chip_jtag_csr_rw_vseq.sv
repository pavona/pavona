// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Run chip csr_rw sequence via JTAG RV_DM interface.
class chip_jtag_csr_rw_vseq extends chip_common_vseq;
  `uvm_object_utils(chip_jtag_csr_rw_vseq)

  `uvm_object_new

  virtual task pre_start();
    cfg.m_jtag_riscv_agent_cfg.is_rv_dm = 1;
    super.pre_start();
  endtask

  virtual task body();
    jtag_riscv_dm_activation_seq jtag_dm_activation_seq =
        jtag_riscv_dm_activation_seq::type_id::create("jtag_dm_activation_seq");

    `DV_CHECK_FATAL(cfg.use_jtag_dmi)
    `DV_CHECK_NE_FATAL(cfg.debugger.m_sba_access_reg_frontdoor, null)

    cfg.m_jtag_riscv_agent_cfg.allow_errors = 1;
    jtag_dm_activation_seq.start(p_sequencer.jtag_sequencer_h);
    cfg.m_jtag_riscv_agent_cfg.allow_errors = 0;

    set_sba_frontdoor_on_chip_csrs();
    apply_jtag_sba_csr_exclusions();
    run_common_vseq_wrapper(num_trans);
  endtask : body

  virtual function void apply_jtag_sba_csr_exclusions();
    csr_excl_item csr_excl;

    if (cfg.ral_models.exists("chip_reg_block")) begin
      csr_excl = cfg.ral_models["chip_reg_block"].get_excl_item();
      `DV_CHECK_NE_FATAL(csr_excl, null)

      // These trace CSRs are driven by soc_dbg_ctrl hardware policy state. The generic CSR RW
      // sequence may touch policy inputs first, so a later read can legitimately differ from the
      // static reset value in the RAL model.
      csr_excl.add_excl("chip_reg_block.soc_dbg_ctrl_core.trace_debug_policy_category",
                        CsrExclCheck, CsrRwTest);
      csr_excl.add_excl("chip_reg_block.soc_dbg_ctrl_core.trace_debug_policy_valid_relocked",
                        CsrExclCheck, CsrRwTest);
    end

  endfunction

  virtual function void set_sba_frontdoor_on_chip_csrs();
    uvm_reg regs[$];

    // Attach the SBA frontdoor only to chip CSRs under test. Do not set
    // csr_utils_pkg::default_user_frontdoor globally: the SBA frontdoor itself uses csr_utils to
    // access JTAG-DMI registers, and a global default would recursively start the SBA frontdoor.
    // The SBA path only reaches chip_reg_block, which represents the hart address space. Do not
    // attach the SBA frontdoor to the soc_dbg or soc_mbx RAL models.
    if (!cfg.ral_models.exists("chip_reg_block")) return;

    cfg.ral_models["chip_reg_block"].get_registers(regs);
    foreach (regs[j]) begin
      regs[j].set_frontdoor(cfg.debugger.m_sba_access_reg_frontdoor);
    end
  endfunction

  virtual task run_csr_vseq(string csr_test_type,
                            int    num_test_csrs = 0,
                            bit    do_rand_wr_and_reset = 1,
                            dv_base_reg_block models[$] = {},
                            string ral_name = "");
    string sba_ral_name = "chip_reg_block";
    dv_base_reg_block sba_models[$];

    // JTAG cannot process outstanding access, so JTAG protocol will process one request at a time.
    // However, still set this variable to 1 to avoid spinwait timeout when sequence sends all csrs
    // transaction requests at .
    max_outstanding_accesses = 1;

    // This sequence accesses CSRs through RV_DM SBA. SBA is a host in the hart address space, which
    // is represented by chip_reg_block. Do not let the common CSR sequence expand an empty model list
    // to all RAL models, since chip_soc_dbg_reg_block and chip_soc_mbx_reg_block are separate
    // non-SBA address spaces.
    if (models.size() == 0 && ral_name == "") begin
      `DV_CHECK_FATAL(cfg.ral_models.exists(sba_ral_name))
      sba_models.push_back(cfg.ral_models[sba_ral_name]);
    end else begin
      sba_models = models;
    end

    // Run 500 csrs at one sequence to avoid simulation timeout.
    super.run_csr_vseq(csr_test_type, 500, do_rand_wr_and_reset, sba_models, ral_name);
  endtask

endclass
