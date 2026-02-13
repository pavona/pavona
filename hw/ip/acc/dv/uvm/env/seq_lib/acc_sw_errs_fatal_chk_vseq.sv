// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class acc_sw_errs_fatal_chk_vseq extends acc_single_vseq;
  `uvm_object_utils(acc_sw_errs_fatal_chk_vseq)
  `uvm_object_new

  task body();
    // Wait for ACC to complete its secure wipe after reset and become Idle.  Otherwise, ACC will
    // ignore writes of `CTRL.software_errs_fatal`.
    wait(cfg.model_agent_cfg.vif.status == acc_pkg::StatusIdle);
    // Set ctrl.software_errs_fatal. This change also will be passed to our model through
    // acc_scoreboard.
    csr_utils_pkg::csr_wr(ral.ctrl, 'b1);
    super.body();
    reset_if_locked();
  endtask : body

endclass : acc_sw_errs_fatal_chk_vseq
