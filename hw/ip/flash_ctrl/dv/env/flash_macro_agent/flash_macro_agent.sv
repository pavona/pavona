// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class flash_macro_agent extends dv_base_agent #(
  .CFG_T          (flash_macro_agent_cfg),
  .DRIVER_T       (flash_macro_driver),
  .SEQUENCER_T    (flash_macro_sequencer),
  .MONITOR_T      (flash_macro_monitor),
  .COV_T          (flash_macro_agent_cov)
);

  `uvm_component_utils(flash_macro_agent)
  `uvm_component_new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // get flash_macro_if handle
    if (!uvm_config_db#(virtual flash_macro_if)::get(this, "", "vif", cfg.vif)) begin
      `uvm_fatal(`gfn, "failed to get flash_macro_if handle from uvm_config_db")
    end
  endfunction

endclass
