// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class tl_rst_safe_host_agent_base_test extends tl_rst_safe_agent_base_test;
  `uvm_component_utils(tl_rst_safe_host_agent_base_test)
  `uvm_component_new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // All timing policy is fixed before the agents are built. Host request
    // items select their A-valid delay, while the Device withholds A-ready long
    // enough to create both pre-handshake Host reset scenarios.
    cfg.host_agent_cfg.use_seq_item_a_valid_delay = 1'b1;
    cfg.host_agent_cfg.d_ready_delay_min = 0;
    cfg.host_agent_cfg.d_ready_delay_max = 0;
    cfg.host_agent_cfg.host_can_stall_rsp_when_a_valid_high = 1'b0;
    cfg.device_agent_cfg.a_ready_delay_min = 100;
    cfg.device_agent_cfg.a_ready_delay_max = 100;
  endfunction : build_phase
endclass : tl_rst_safe_host_agent_base_test
