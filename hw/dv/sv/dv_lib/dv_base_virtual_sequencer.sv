// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class dv_base_virtual_sequencer #(type CFG_T = dv_base_env_cfg,
                                  type COV_T = dv_base_env_cov) extends dv_base_sequencer;
  `uvm_component_param_utils(dv_base_virtual_sequencer #(CFG_T, COV_T))

  CFG_T         cfg;
  COV_T         cov;

  function new(string name = "", uvm_component parent);
    super.new(name, parent);
    do_not_reset         = 1;
    is_virtual_sequencer = 1;
  endfunction

  function void handle_reset_assertion();
    `uvm_fatal(`gfn, "handle_reset_assertion() need implementation in derived class")
  endfunction : handle_reset_assertion
endclass
