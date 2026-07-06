// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Interface for the miscellaneous soc_dbg_ctrl signals. Inputs are driven by
// soc_dbg_ctrl_misc_driver; outputs are sampled by soc_dbg_ctrl_misc_monitor.
interface soc_dbg_ctrl_misc_io_if(input logic clk, input logic rst_n);
  // Dep packages
  import uvm_pkg::*;
  import dv_utils_pkg::*;
  import soc_dbg_ctrl_env_pkg::*;
  import soc_dbg_ctrl_test_pkg::*;

  // Macro includes
  `include "uvm_macros.svh"
  `include "dv_macros.svh"

  // Imports from packages
  import soc_dbg_ctrl_pkg::soc_dbg_policy_t;
  import lc_ctrl_state_pkg::soc_dbg_state_t;
  import lc_ctrl_state_pkg::SocDbgStBlank;
  import lc_ctrl_pkg::lc_tx_t;
  import lc_ctrl_pkg::Off;
  import pwrmgr_pkg::pwr_boot_status_t;
  import rom_ctrl_pkg::pwrmgr_data_t;

  // Variables corresponding to the DUT signals
  soc_dbg_policy_t  soc_dbg_policy_bus;
  soc_dbg_state_t   soc_dbg_state;
  lc_tx_t           lc_dft_en;
  lc_tx_t           lc_hw_debug_en;
  lc_tx_t           lc_raw_test_rma;
  lc_tx_t           lc_cpu_en;
  lc_tx_t           lc_rma_state;
  pwr_boot_status_t boot_status;
  logic             halt_cpu_boot;
  pwrmgr_data_t     continue_cpu_boot;

  // Drive inputs to safe defaults at time 0 so the DUT's ASSERT_KNOWN checks on
  // soc_dbg_policy_bus_o do not fire in the window between reset deassertion and the
  // driver's first reset-default drive.
  initial begin
    soc_dbg_state   = SocDbgStBlank;
    lc_dft_en       = Off;
    lc_hw_debug_en  = Off;
    lc_raw_test_rma = Off;
    lc_cpu_en       = Off;
    lc_rma_state    = Off;
    boot_status     = '0;
    halt_cpu_boot   = 1'b1;
  end

  // Driver clocking block for the DUT inputs.
  clocking drv_cb @(posedge clk);
    output soc_dbg_state, lc_dft_en, lc_hw_debug_en, lc_raw_test_rma,
           lc_cpu_en, lc_rma_state, boot_status, halt_cpu_boot;
  endclocking

  // Monitor clocking block: samples inputs and outputs in the preponed region so the
  // captured values match what the DUT registers on the same edge.
  clocking mon_cb @(posedge clk);
    input soc_dbg_state, lc_dft_en, lc_hw_debug_en, lc_raw_test_rma, lc_cpu_en,
          lc_rma_state, boot_status, halt_cpu_boot, continue_cpu_boot, soc_dbg_policy_bus;
  endclocking

endinterface : soc_dbg_ctrl_misc_io_if
