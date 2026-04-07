// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class acc_kmac_intf_err_vseq extends acc_single_vseq;
  `uvm_object_utils(acc_kmac_intf_err_vseq)
  `uvm_object_new

  task body();
    do_end_addr_check = 0; // Disable due to errors in middle of assembly

    // Wait for ACC to complete its secure wipe after reset and become Idle.
    // Otherwise reset_if_locked() will not fire.
    wait(cfg.model_agent_cfg.vif.status == acc_pkg::StatusIdle);

    super.body();
    reset_if_locked();
  endtask : body

endclass : acc_kmac_intf_err_vseq
