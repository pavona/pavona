// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

package clk_rst_agent_pkg;
  // dep packages
  import uvm_pkg::*;
  import dv_utils_pkg::*;
  import dv_lib_pkg::*;

  // macro includes
  `include "uvm_macros.svh"
  `include "dv_macros.svh"

  // local types
  // forward declare classes to allow typedefs below
  typedef class clk_rst_item;
  typedef class clk_rst_agent_cfg;

  // reuse dv_base_sequencer as is with the right parameter set
  typedef dv_base_sequencer #(.ITEM_T(clk_rst_item),
                              .CFG_T (clk_rst_agent_cfg)) clk_rst_sequencer;
  typedef dv_base_sequencer #(.ITEM_T(clk_rst_item),
                              .CFG_T (clk_rst_agent_cfg)) delay_sequencer  ;

  // package sources
  `include "clk_rst_item.sv"
  `include "clk_rst_agent_cfg.sv"
  `include "clk_rst_agent_cov.sv"
  `include "clk_rst_driver.sv"
  `include "clk_rst_monitor.sv"
  `include "clk_rst_agent.sv"

  `include "delay_driver.sv"
  `include "delay_agent.sv"
//
//  `include "clk_rst_seq_list.sv"
endpackage: clk_rst_agent_pkg
