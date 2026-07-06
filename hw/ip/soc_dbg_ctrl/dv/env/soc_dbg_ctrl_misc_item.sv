// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Drivable DUT-input state applied by soc_dbg_ctrl_misc_driver.
class soc_dbg_ctrl_misc_item extends uvm_sequence_item;
  rand soc_dbg_state_t   soc_dbg_state;
  rand lc_tx_t           lc_dft_en;
  rand lc_tx_t           lc_hw_debug_en;
  rand lc_tx_t           lc_raw_test_rma;
  rand lc_tx_t           lc_cpu_en;
  rand lc_tx_t           lc_rma_state;
  rand pwr_boot_status_t boot_status;
  rand logic             halt_cpu_boot;
  rand int unsigned      delay;   // cycles to wait before applying

  // Observed DUT outputs, populated by soc_dbg_ctrl_misc_monitor (not driven).
  pwrmgr_data_t    continue_cpu_boot;
  soc_dbg_policy_t soc_dbg_policy_bus;

  constraint delay_c { delay inside {[0:10]}; }

  `uvm_object_utils(soc_dbg_ctrl_misc_item)
  `uvm_object_new
endclass : soc_dbg_ctrl_misc_item
