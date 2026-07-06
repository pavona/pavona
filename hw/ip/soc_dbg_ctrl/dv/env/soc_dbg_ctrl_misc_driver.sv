// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class soc_dbg_ctrl_misc_driver extends dv_base_driver #(
    .ITEM_T(soc_dbg_ctrl_misc_item),
    .CFG_T (soc_dbg_ctrl_misc_agent_cfg));
  `uvm_component_utils(soc_dbg_ctrl_misc_driver)
  `uvm_component_new

  extern virtual task get_and_drive();
  extern virtual task reset_signals();
  extern local task drive_item(soc_dbg_ctrl_misc_item item);
endclass : soc_dbg_ctrl_misc_driver

task soc_dbg_ctrl_misc_driver::get_and_drive();
  if (cfg.vif == null) begin
    `uvm_fatal(`gfn, "cfg.vif is null")
  end
  forever begin
    soc_dbg_ctrl_misc_item item;
    seq_item_port.get_next_item(item);
    drive_item(item);
    seq_item_port.item_done();
  end
endtask : get_and_drive

// Restore the safe defaults that base_vseq::dut_init used to poke directly.
task soc_dbg_ctrl_misc_driver::reset_signals();
  forever begin
    wait(!cfg.vif.rst_n);
    cfg.vif.soc_dbg_state   <= SocDbgStBlank;
    cfg.vif.lc_dft_en       <= Off;
    cfg.vif.lc_hw_debug_en  <= Off;
    cfg.vif.lc_raw_test_rma <= Off;
    cfg.vif.lc_cpu_en       <= Off;
    cfg.vif.lc_rma_state    <= Off;
    cfg.vif.boot_status     <= '0;
    cfg.vif.halt_cpu_boot   <= 1'b1;
    wait(cfg.vif.rst_n);
  end
endtask : reset_signals

task soc_dbg_ctrl_misc_driver::drive_item(soc_dbg_ctrl_misc_item item);
  if (!cfg.vif.rst_n) begin
    wait(cfg.vif.rst_n);
  end
  repeat (item.delay) @(cfg.vif.drv_cb);
  cfg.vif.drv_cb.soc_dbg_state   <= item.soc_dbg_state;
  cfg.vif.drv_cb.lc_dft_en       <= item.lc_dft_en;
  cfg.vif.drv_cb.lc_hw_debug_en  <= item.lc_hw_debug_en;
  cfg.vif.drv_cb.lc_raw_test_rma <= item.lc_raw_test_rma;
  cfg.vif.drv_cb.lc_cpu_en       <= item.lc_cpu_en;
  cfg.vif.drv_cb.lc_rma_state    <= item.lc_rma_state;
  cfg.vif.drv_cb.boot_status     <= item.boot_status;
  cfg.vif.drv_cb.halt_cpu_boot   <= item.halt_cpu_boot;
endtask : drive_item
