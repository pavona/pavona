// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class soc_dbg_ctrl_misc_monitor extends dv_base_monitor #(
    .ITEM_T(soc_dbg_ctrl_misc_item),
    .CFG_T (soc_dbg_ctrl_misc_agent_cfg));
  `uvm_component_utils(soc_dbg_ctrl_misc_monitor)
  `uvm_component_new

  extern protected virtual task collect_trans();
endclass : soc_dbg_ctrl_misc_monitor

// Publish a full snapshot of the misc interface (driven inputs + observed outputs) every
// clock so the scoreboard can advance its halt-FSM model and check continue_cpu_boot without
// touching the interface directly.
task soc_dbg_ctrl_misc_monitor::collect_trans();
  forever begin
    soc_dbg_ctrl_misc_item item;
    @(cfg.vif.mon_cb);
    item = soc_dbg_ctrl_misc_item::type_id::create("item");
    item.soc_dbg_state      = cfg.vif.mon_cb.soc_dbg_state;
    item.lc_dft_en          = cfg.vif.mon_cb.lc_dft_en;
    item.lc_hw_debug_en     = cfg.vif.mon_cb.lc_hw_debug_en;
    item.lc_raw_test_rma    = cfg.vif.mon_cb.lc_raw_test_rma;
    item.lc_cpu_en          = cfg.vif.mon_cb.lc_cpu_en;
    item.lc_rma_state       = cfg.vif.mon_cb.lc_rma_state;
    item.boot_status        = cfg.vif.mon_cb.boot_status;
    item.halt_cpu_boot      = cfg.vif.mon_cb.halt_cpu_boot;
    item.continue_cpu_boot  = cfg.vif.mon_cb.continue_cpu_boot;
    item.soc_dbg_policy_bus = cfg.vif.mon_cb.soc_dbg_policy_bus;
    analysis_port.write(item);
  end
endtask : collect_trans
