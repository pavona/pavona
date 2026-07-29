// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class cip_rst_safe_base_env_cfg #(type RAL_T = dv_base_reg_block)
    extends cip_base_env_cfg #(.RAL_T(RAL_T));
  rand clk_rst_agent_cfg clk_rst_agt_cfg;

  `uvm_object_param_utils_begin(cip_rst_safe_base_env_cfg #(RAL_T))
    `uvm_field_object(clk_rst_agt_cfg, UVM_DEFAULT)
  `uvm_object_utils_end
  `uvm_object_new

  virtual function void initialize(bit [BUS_AW-1:0] csr_base_addr = '1);
    super.initialize(csr_base_addr);
    clk_rst_agt_cfg = clk_rst_agent_cfg::type_id::create("clk_rst_agt_cfg");
  endfunction : initialize
endclass : cip_rst_safe_base_env_cfg
