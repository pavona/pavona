// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// This agent is a customized/cut down version. Do not need all aspects of the dv_base_agent
// Need only the sequencer and driver alone and the other aspects are not relevant.

class delay_agent extends uvm_agent;

  `uvm_component_utils(delay_agent)

  clk_rst_agent_cfg  cfg;
  delay_driver       driver;
  delay_sequencer    sequencer;

  `uvm_component_new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // get clk_rst_agent_cfg object from uvm_config_db
    if (!uvm_config_db#(clk_rst_agent_cfg)::get(this, "", "cfg", cfg)) begin
      `uvm_fatal(`gfn, $sformatf("failed to get %s from uvm_config_db", cfg.get_type_name()))
    end
    `uvm_info(`gfn, $sformatf("\n%0s", cfg.sprint()), UVM_HIGH)

    if (cfg.is_active) begin
      sequencer = delay_sequencer::type_id::create("sequencer", this);
      sequencer.cfg = cfg;

      if (cfg.has_driver) begin
        driver = delay_driver::type_id::create("driver", this);
        driver.cfg = cfg;
      end
    end
  endfunction


  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (cfg.is_active && cfg.has_driver) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end
  endfunction


  function void start_of_simulation_phase(uvm_phase phase);
    super.start_of_simulation_phase(phase);
    if (cfg.reset_domain == null)
      `uvm_fatal(`gfn, "'cfg.reset_domain' is null. Resolve this before proceeding")
  endfunction


  task run_phase(uvm_phase phase);
    super.run_phase(phase);

    // The first reset is POR. Wait until a full reset cycle is observed
    cfg.reset_domain.wait_reset_assert();
    cfg.reset_domain.wait_reset_deassert();

    fork
      begin : agent_reset_thread
        forever begin
          cfg.reset_domain.wait_reset_assert();
          sequencer.stop_sequences();

          cfg.reset_domain.wait_reset_deassert();
        end // forever
      end
    join_none
  endtask
endclass
