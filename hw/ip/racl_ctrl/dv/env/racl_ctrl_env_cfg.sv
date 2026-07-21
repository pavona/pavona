// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// An environment config for interfacing with racl_ctrl.

class racl_ctrl_env_cfg extends cip_base_env_cfg #(.RAL_T(racl_ctrl_reg_block));
  `uvm_object_utils(racl_ctrl_env_cfg)

  racl_ctrl_reg_window regs;

  // An interface that will be bound to the racl_policies_o output of the dut.
  virtual racl_ctrl_policies_if policies_vif;

  // Configuration for the two error log agents
  rand racl_error_log_agent_cfg internal_error_agent_cfg;
  rand racl_error_log_agent_cfg external_error_agent_cfg;

  extern function new (string name="");
  extern virtual function void initialize(bit [31:0] csr_base_addr = '1);

  // Mark INTR_STATE as scoreboard-predicted so the generic intr_test skips its inline INTR_STATE
  // read/pin check. racl_error's source (ERROR_LOG.VALID) is driven asynchronously by the injection
  // sequences, which racl_ctrl_scoreboard (watch_interrupt / process_tl_d_channel) handles instead.
  extern function void set_intr_state_has_prediction();
endclass

function racl_ctrl_env_cfg::new (string name="");
  super.new(name);

  if (!$cast(regs, racl_ctrl_reg_window::type_id::create("regs")))
    `uvm_fatal(`gfn, "Could not create reg window of correct type")
endfunction

function void racl_ctrl_env_cfg::initialize(bit [31:0] csr_base_addr = '1);
  list_of_alerts = racl_ctrl_env_pkg::LIST_OF_ALERTS;

  // Tell the CIP base code how many interrupts we have (defaults to zero)
  num_interrupts = 1;

  super.initialize(csr_base_addr);

  // Tell regs about ral, which contains the actual register model.
  regs.set_reg_block(ral);

  set_intr_state_has_prediction();

  // Used to allow reset operations without waiting for CSR accesses to complete
  can_reset_with_csr_accesses = 1;

  internal_error_agent_cfg = racl_error_log_agent_cfg::type_id::create("internal_error_agent_cfg");
  external_error_agent_cfg = racl_error_log_agent_cfg::type_id::create("external_error_agent_cfg");
endfunction

function void racl_ctrl_env_cfg::set_intr_state_has_prediction();
  dv_base_reg       intr_state_reg = ral.get_dv_base_reg_by_name("intr_state");
  dv_base_reg_field flds[$];

  if (intr_state_reg == null) `uvm_fatal(`gfn, "Could not find INTR_STATE register.")
  intr_state_reg.get_dv_base_reg_fields(flds);
  foreach (flds[i]) flds[i].has_prediction = 1'b1;
endfunction
