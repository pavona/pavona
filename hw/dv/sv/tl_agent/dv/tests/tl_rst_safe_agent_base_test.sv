// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class tl_rst_safe_agent_base_test extends dv_base_test #(
  .ENV_T(tl_rst_safe_agent_env),
  .CFG_T(tl_agent_env_cfg)
);
  `uvm_component_utils(tl_rst_safe_agent_base_test)
  `uvm_component_new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Keep request acceptance immediate and take the response delay from the
    // sequence item. The focused vseq uses that delay to place reset while the
    // reset-safe device driver owns the response.
    cfg.zero_delays = 1'b0;
    cfg.host_agent_cfg.a_valid_delay_min = 0;
    cfg.host_agent_cfg.a_valid_delay_max = 0;
    // Hold D-ready low long enough to exercise reset while D-valid is asserted.
    cfg.host_agent_cfg.d_ready_delay_min = 100;
    cfg.host_agent_cfg.d_ready_delay_max = 100;
    cfg.host_agent_cfg.host_can_stall_rsp_when_a_valid_high = 1'b1;
    cfg.device_agent_cfg.a_ready_delay_min = 0;
    cfg.device_agent_cfg.a_ready_delay_max = 0;
    cfg.device_agent_cfg.device_can_rsp_on_same_cycle = 1'b1;
    cfg.device_agent_cfg.use_seq_item_d_valid_delay = 1'b1;
  endfunction : build_phase
endclass : tl_rst_safe_agent_base_test
