// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class dv_rst_safe_scoreboard #(type RAL_T = dv_base_reg_block,
                               type CFG_T = dv_base_env_cfg,
                               type COV_T = dv_base_env_cov) extends uvm_component;
  `uvm_component_param_utils(dv_rst_safe_scoreboard #(RAL_T, CFG_T, COV_T))

  CFG_T    cfg;
  RAL_T    ral;
  COV_T    cov;

  bit obj_raised      = 1'b0;
  bit under_pre_abort = 1'b0;
  protected bit under_reset = 1'b0;

  `uvm_component_new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ral = cfg.ral;
  endfunction

  virtual task run_phase(uvm_phase phase);
    super.run_phase(phase);
    fork
      sample_resets();
    join_none
  endtask

  virtual task sample_resets();
    // Do nothing, actual coverage collection is under extended classes.
  endtask

  virtual function bit in_reset();
    return under_reset;
  endfunction

  virtual function void process_reset_asserted();
    `uvm_info(`gfn, "dv_rst_safe_scoreboard observed RESET_ASSERTED; calling reset()",
              UVM_LOW)
    under_reset = 1'b1;
    reset();
  endfunction

  virtual function void process_reset_deasserted();
    `uvm_info(`gfn, "dv_rst_safe_scoreboard observed RESET_DEASSERTED", UVM_LOW)
    under_reset = 1'b0;
  endfunction

  virtual function void reset(string kind = "HARD");
    `uvm_info(`gfn, $sformatf("dv_rst_safe_scoreboard::reset(%0s): resetting RAL models", kind),
              UVM_LOW)
    // reset the ral model
    foreach (cfg.ral_models[i]) cfg.ral_models[i].reset(kind);
  endfunction

  virtual function void pre_abort();
    super.pre_abort();

    // In UVM, a fatal error normally aborts the test completely and skips the check phase. However,
    // it's sometimes helpful to run that phase on the scoreboard anyway (it might make it easier to
    // debug whatever went wrong), so we do that here.
    //
    // We only run the check phase if we were in the run phase: if something went wrong in the build
    // or connect phase, there's not much point in "checking the run" further. We also have to be
    // careful to avoid an infinite loop, so we set a flag to avoid doing this a second time if we
    // have errors in the check phase.
    if (has_uvm_fatal_occurred() &&
        !under_pre_abort &&
        m_current_phase.is(uvm_run_phase::get())) begin

      under_pre_abort = 1;
      check_phase(m_current_phase);
      under_pre_abort = 0;
    end
  endfunction : pre_abort

endclass
