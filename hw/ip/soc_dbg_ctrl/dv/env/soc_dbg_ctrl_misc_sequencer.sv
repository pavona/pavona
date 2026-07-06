// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class soc_dbg_ctrl_misc_sequencer extends dv_base_sequencer #(
    .ITEM_T(soc_dbg_ctrl_misc_item),
    .CFG_T (soc_dbg_ctrl_misc_agent_cfg));
  `uvm_component_utils(soc_dbg_ctrl_misc_sequencer)
  `uvm_component_new
endclass : soc_dbg_ctrl_misc_sequencer
