// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Bind the shared CSR, memory, and TL workloads to the timer's register model and configuration.
// The parent test's default ENV_T creates cip_rst_safe_common_env with the types supplied below.
// That environment provides the TL, alert, clock/reset, and delay agents needed for these tests.
// RV Timer has no additional datapath interfaces that need block-specific drivers or setup.
// A specialized common environment would therefore add no behavior and is not needed here.
// Timer operation is checked in the separate functional environment. RAL exclusions keep ordinary
// CSR tests from enabling the timer.
class rv_timer_rst_safe_common_test extends cip_rst_safe_common_test #(
    .RAL_T(rv_timer_reg_block),
    .CFG_T(rv_timer_env_cfg)
  );
  `uvm_component_utils(rv_timer_rst_safe_common_test)
  `uvm_component_new

  virtual function void build_phase(uvm_phase phase);
    test_timeout_ns = 1_000_000_000; // 1s

    // Use the same TL configuration as the timer's functional tests. It prevents the next
    // request from reusing the most recently released source ID; it does not add a delay.
    // Select this configuration before super.build_phase() creates the TL configuration object.
    tl_agent_cfg::type_id::set_type_override(rv_timer_rst_safe_tl_agent_cfg::get_type());
    super.build_phase(phase);
    cfg.m_tl_agent_cfg.use_last_a_source_released_pct = 0;
  endfunction : build_phase
endclass : rv_timer_rst_safe_common_test
