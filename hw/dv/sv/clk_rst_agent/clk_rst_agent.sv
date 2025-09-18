// Copyright zeroRISC Inc
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class clk_rst_agent extends dv_base_agent #(
  .CFG_T          (clk_rst_agent_cfg),
  .DRIVER_T       (clk_rst_driver),
  .SEQUENCER_T    (clk_rst_sequencer),
  .MONITOR_T      (clk_rst_monitor),
  .COV_T          (clk_rst_agent_cov)
);

  `uvm_component_utils(clk_rst_agent)

  `uvm_component_new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  function void start_of_simulation_phase(uvm_phase phase);
    super.start_of_simulation_phase(phase);
    if (cfg.reset_domain == null)
      `uvm_fatal(`gfn, "cfg.reset_domain is null. Resolve this before proceeding")
  endfunction
endclass
