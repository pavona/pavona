// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

package acc_model_agent_pkg;
  // dep packages
  import uvm_pkg::*;
  import dv_utils_pkg::*;
  import dv_lib_pkg::*;

  import "DPI-C" function bit
    acc_trace_checker_pop_iss_insn(output bit [31:0] insn_addr, output string mnemonic);

  typedef enum {
    AccModelStatus,
    AccModelInsn
  } acc_model_item_type_e;

  // macro includes
  `include "uvm_macros.svh"
  `include "dv_macros.svh"

  typedef acc_model_item;
  typedef acc_model_agent_cfg;
  // driver and sequencer are not used in this agent. Create these dummy components to avoid compile
  // error due to the TLM connection between monitor and sequencer in dv_base_*.
  // Both TLM fifo/port need to use the same item object (acc_model_item)
  typedef dv_base_sequencer #(acc_model_item, acc_model_agent_cfg) acc_dummy_sequencer;
  typedef dv_base_driver #(acc_model_item, acc_model_agent_cfg) acc_dummy_driver;

  // package sources
  `include "acc_model_item.sv"

  `include "acc_model_agent_cfg.sv"
  `include "acc_model_monitor.sv"
  `include "acc_model_agent.sv"

endpackage: acc_model_agent_pkg
