// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class dv_rst_safe_base_agent #(type CFG_T            = dv_base_agent_cfg,
                               type DRIVER_T         = dv_rst_safe_base_driver,
                               type HOST_DRIVER_T    = DRIVER_T,
                               type DEVICE_DRIVER_T  = DRIVER_T,
                               type SEQUENCER_T      = dv_base_sequencer,
                               type MONITOR_T        = dv_rst_safe_base_monitor,
                               type COV_T            = dv_base_agent_cov) extends uvm_agent;

  `uvm_component_param_utils(dv_rst_safe_base_agent #(CFG_T, DRIVER_T, HOST_DRIVER_T,
                                                     DEVICE_DRIVER_T, SEQUENCER_T, MONITOR_T, COV_T))

  CFG_T       cfg;
  COV_T       cov;
  DRIVER_T    driver;
  SEQUENCER_T sequencer;
  MONITOR_T   monitor;

  `uvm_component_new

  extern virtual function void build_phase(uvm_phase phase);
  extern virtual function void connect_phase(uvm_phase phase);
  extern virtual function void start_of_simulation_phase(uvm_phase phase);
  extern virtual task run_phase(uvm_phase phase);
endclass


function void dv_rst_safe_base_agent::build_phase(uvm_phase phase);
  super.build_phase(phase);
  // get CFG_T object from uvm_config_db
  if (!uvm_config_db#(CFG_T)::get(this, "", "cfg", cfg)) begin
    `uvm_fatal(`gfn, $sformatf("failed to get %s from uvm_config_db", cfg.get_type_name()))
  end
  `uvm_info(`gfn, $sformatf("\n%0s", cfg.sprint()), UVM_LOW)

  // create components
  if (cfg.en_cov) begin
    cov = COV_T::type_id::create("cov", this);
    cov.cfg = cfg;
  end

  monitor = MONITOR_T::type_id::create("monitor", this);
  monitor.cfg = cfg;
  monitor.cov = cov;

  if (cfg.is_active) begin
    sequencer = SEQUENCER_T::type_id::create("sequencer", this);
    sequencer.cfg = cfg;

    if (cfg.has_driver) begin
      if (cfg.if_mode == Host)  DRIVER_T::type_id::set_type_override(HOST_DRIVER_T::get_type());
      else                      DRIVER_T::type_id::set_type_override(DEVICE_DRIVER_T::get_type());

      driver = DRIVER_T::type_id::create("driver", this);
      driver.cfg = cfg;
    end
  end
endfunction


function void dv_rst_safe_base_agent::connect_phase(uvm_phase phase);
  super.connect_phase(phase);
  if (cfg.is_active && cfg.has_driver) begin
    driver.seq_item_port.connect(sequencer.seq_item_export);
  end
  if (cfg.is_active && cfg.has_req_fifo) begin
    monitor.req_analysis_port.connect(sequencer.req_analysis_fifo.analysis_export);
  end
  if (cfg.is_active && cfg.has_rsp_fifo) begin
    monitor.rsp_analysis_port.connect(sequencer.rsp_analysis_fifo.analysis_export);
  end
endfunction

// All agents will need to be associated with at least one reset domain.
// As TB's transition to using reset domains this check is vital to ensure all agents clocking is
// only coming from the interface in the reset domain
function void dv_rst_safe_base_agent::start_of_simulation_phase(uvm_phase phase);
  super.start_of_simulation_phase(phase);
  if (cfg.reset_domain == null)
    `uvm_fatal(`gfn, {"'cfg.reset_domain' is null. Resolve this before proceeding",
                      "\n cfg name: ", cfg.get_name()})
endfunction


task dv_rst_safe_base_agent::run_phase(uvm_phase phase);
  super.run_phase(phase);

  // The first reset is POR. Wait until a full reset cycle is observed
  cfg.reset_domain.wait_reset_assert();
  cfg.reset_domain.wait_reset_deassert();

  `uvm_info(`gfn, "POR Deasserted", UVM_LOW)

  fork
    begin : agent_reset_thread
      forever begin
        cfg.reset_domain.wait_reset_assert();
        `uvm_info(`gfn, "Reset Asserted", UVM_LOW)
        if (!sequencer.do_not_reset) begin
          `uvm_info(`gfn, "Initiating Sequences Termination", UVM_LOW)
          wait (driver.processing_item == 0);
          sequencer.stop_sequences();
          `uvm_info(`gfn, "Sequences Stopped", UVM_LOW)
        end

        cfg.reset_domain.wait_reset_deassert();
        `uvm_info(`gfn, "Reset Deasserted", UVM_LOW)
      end // forever
    end
  join_none
endtask
