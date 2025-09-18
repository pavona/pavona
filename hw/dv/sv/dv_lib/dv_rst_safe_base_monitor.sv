// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class dv_rst_safe_base_monitor #(type ITEM_T = uvm_sequence_item,
                                 type REQ_ITEM_T = ITEM_T,
                                 type RSP_ITEM_T = ITEM_T,
                                 type CFG_T  = dv_base_agent_cfg,
                                 type COV_T  = dv_base_agent_cov) extends dv_monitor#(ITEM_T);
  `uvm_component_param_utils(dv_rst_safe_base_monitor #(ITEM_T, REQ_ITEM_T, RSP_ITEM_T,
                                                        CFG_T, COV_T))

  CFG_T cfg;
  COV_T cov;

  // item will be sent to this port for seq when req phase is done (last is set)
  uvm_analysis_port #(REQ_ITEM_T) req_analysis_port;
  // item will be sent to this port for seq when rsp phase is done (rsp_done is set)
  uvm_analysis_port #(RSP_ITEM_T) rsp_analysis_port;

  // Standard UVM component task/functions
  extern function new (string name, uvm_component parent);
  extern function void build_phase(uvm_phase phase);
  extern task run_phase(uvm_phase phase);

  // 'collect_trans()' task is the main task that monitors the inteface and builds the necessary
  // transactions that the scoreboard uses.
  extern virtual task collect_trans();

  // 'reset_monitor()' function is used by the reset_thread to get the monitor to the default
  // state
  extern function void reset_monitor();
endclass


function dv_rst_safe_base_monitor::new (string name, uvm_component parent);
  super.new(name, parent);
endfunction

function void dv_rst_safe_base_monitor::build_phase(uvm_phase phase);
  super.build_phase(phase);
  req_analysis_port = new("req_analysis_port", this);
  rsp_analysis_port = new("rsp_analysis_port", this);
endfunction

task dv_rst_safe_base_monitor::run_phase(uvm_phase phase);
  process reset_thread_id;
  process collect_trans_thread_id;

  super.run_phase(phase);

  if (cfg.reset_domain == null)  begin
    `uvm_fatal (`gfn, "cfg.reset_domain == null, please ensure reset_domain is setup in cfg")
  end

  // The first reset is POR. Wait until a full reset cycle is observed before
  // capturing any transaction on the interface
  cfg.reset_domain.wait_reset_assert();
  reset_monitor();

  cfg.reset_domain.wait_reset_deassert();

  forever begin
    // At this point reset is released and the monitor is the default state. We now need to monitor
    // reset and the interface signals conurrently. The interface monitor thread
    // Process threading is used instead of isolation forks as it is cleaner and allows for fine
    // grained thread control.
    fork
      begin : reset_thread
        // Capture Process handle for the spawned process
        reset_thread_id = process::self();
        cfg.reset_domain.wait_reset_assert();
        reset_monitor();
      end
      begin : interface_monitor_thread
        collect_trans_thread_id = process::self();
        collect_trans();
      end
    join_none

    // Wait until both threads have spawned properly
    wait (reset_thread_id != null && collect_trans_thread_id != null);

    // Now wait till reset thread finishes. Reset Thread should be the only one to finish first as
    // the 'interface_monitor_thread' should be a forever loop monitoring the the interface
    // signals.
    // Since we are using threading mechanism the 'await()' method blocks until the process on
    // which it is called has finished.
    reset_thread_id.await();

    // At this point the reset has been triggered on the interface. The monitor needs to get back
    // to the original state as it was to just after the POR. So we will terminate anything the
    // monitor is doing and wait till reset is released.
    if (   collect_trans_thread_id.status() == process::RUNNING
        || collect_trans_thread_id.status() == process::WAITING
        || collect_trans_thread_id.status() == process::SUSPENDED) begin
      `uvm_info (get_name(), "killing collect_trans() thread", UVM_MEDIUM)
      collect_trans_thread_id.kill();
    end else if (collect_trans_thread_id.status() == process::FINISHED)  begin
      `uvm_fatal (`gfn, "collect_trans() thread finished before reset thread")
    end

    cfg.reset_domain.wait_reset_deassert();
  end // forever
endtask

// collect transactions forever
task dv_rst_safe_base_monitor::collect_trans();
  // This task has to be be implemented by the derived monitor to observe the interface and build
  // transactions that the scoreboard can use
  `uvm_fatal (`gfn, "collect_trans() needs an implementation")
endtask

function void dv_rst_safe_base_monitor::reset_monitor();
  // This function has to be be implemented by the derived monitor to get the monitor back to
  // default state
  `uvm_fatal (`gfn, "reset_interface_and_monitor() needs an implementation")
endfunction
