// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class soc_dbg_ctrl_misc_agent extends dv_base_agent #(
    .CFG_T      (soc_dbg_ctrl_misc_agent_cfg),
    .DRIVER_T   (soc_dbg_ctrl_misc_driver),
    .SEQUENCER_T(soc_dbg_ctrl_misc_sequencer),
    .MONITOR_T  (soc_dbg_ctrl_misc_monitor));
  `uvm_component_utils(soc_dbg_ctrl_misc_agent)
  `uvm_component_new
endclass : soc_dbg_ctrl_misc_agent
