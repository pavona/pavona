// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class acc_model_agent extends dv_base_agent #(
  .CFG_T          (acc_model_agent_cfg),
  .MONITOR_T      (acc_model_monitor),
  .DRIVER_T       (acc_dummy_driver),
  .SEQUENCER_T    (acc_dummy_sequencer)
);

  `uvm_component_utils(acc_model_agent)
  `uvm_component_new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // This agent doesn't support active use (it's just for monitoring the model interface).
    `DV_CHECK_FATAL(!cfg.is_active)

    // get acc_model_if handle
    if (!uvm_config_db#(
                        virtual acc_model_if#(.ImemSizeByte(acc_reg_pkg::ACC_IMEM_SIZE))
                       )::get(this, "", "vif", cfg.vif)) begin
      `uvm_fatal(`gfn, "failed to get acc_model_if handle from uvm_config_db")
    end
  endfunction

endclass
