// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Connect standard CIP tests without requiring the block's functional virtual sequencer.
// Keep the block configuration and its RAL specialization. The shared coverage, scoreboard,
// and virtual sequencer all use that same configuration type.
//
// The CSR and memory test mappings retain register checking in the CSR leaves with en_scb=0.
// The scoreboard still owns reset cleanup, TL error checks, and enabled memory checks.
// A block extension supplies any additional drivers needed to keep its other interfaces idle.
class cip_rst_safe_common_env #(
  type RAL_T = dv_base_reg_block,
  type CFG_T = cip_rst_safe_base_env_cfg #(RAL_T),
  type COV_T = cip_base_env_cov #(CFG_T),
  type VIRTUAL_SEQUENCER_T = cip_base_virtual_sequencer #(CFG_T, COV_T),
  type SCOREBOARD_T = cip_rst_safe_scoreboard #(RAL_T, CFG_T, COV_T)
) extends cip_rst_safe_base_env #(CFG_T, VIRTUAL_SEQUENCER_T, SCOREBOARD_T, COV_T);
  `uvm_component_param_utils(cip_rst_safe_common_env #(
      RAL_T, CFG_T, COV_T, VIRTUAL_SEQUENCER_T, SCOREBOARD_T))
  `uvm_component_new
endclass : cip_rst_safe_common_env
