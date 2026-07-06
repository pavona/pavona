// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class soc_dbg_ctrl_misc_seq extends uvm_sequence #(soc_dbg_ctrl_misc_item);
  `uvm_object_utils(soc_dbg_ctrl_misc_seq)
  `uvm_object_new

  // Desired input state; set by the caller before start(). Retained across calls.
  soc_dbg_state_t   soc_dbg_state   = SocDbgStBlank;
  lc_tx_t           lc_dft_en       = Off;
  lc_tx_t           lc_hw_debug_en  = Off;
  lc_tx_t           lc_raw_test_rma = Off;
  lc_tx_t           lc_cpu_en       = Off;
  lc_tx_t           lc_rma_state    = Off;
  pwr_boot_status_t boot_status     = '0;
  logic             halt_cpu_boot   = 1'b1;
  int unsigned      delay           = 0;

  virtual task body();
    req = soc_dbg_ctrl_misc_item::type_id::create("req");
    start_item(req);
    req.soc_dbg_state   = soc_dbg_state;
    req.lc_dft_en       = lc_dft_en;
    req.lc_hw_debug_en  = lc_hw_debug_en;
    req.lc_raw_test_rma = lc_raw_test_rma;
    req.lc_cpu_en       = lc_cpu_en;
    req.lc_rma_state    = lc_rma_state;
    req.boot_status     = boot_status;
    req.halt_cpu_boot   = halt_cpu_boot;
    req.delay           = delay;
    finish_item(req);
  endtask
endclass : soc_dbg_ctrl_misc_seq
