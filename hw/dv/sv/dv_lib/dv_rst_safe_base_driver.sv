// Copyright zeroRISC
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class dv_rst_safe_base_driver #(type ITEM_T     = uvm_sequence_item,
                                type CFG_T      = dv_base_agent_cfg,
                                type RSP_ITEM_T = ITEM_T)
  extends uvm_driver #(.REQ(ITEM_T), .RSP(RSP_ITEM_T));

  `uvm_component_param_utils(dv_rst_safe_base_driver #(.ITEM_T     (ITEM_T),
                                                       .CFG_T      (CFG_T),
                                                       .RSP_ITEM_T (RSP_ITEM_T)))
  CFG_T cfg;

  // Standard UVM component task/functions
  extern function new (string name, uvm_component parent);
  extern task run_phase(uvm_phase phase);

  // 'get_and_drive' task is the main thread of the driver. This task functions
  extern virtual task get_and_drive();

  // 'reset_interface_and_driver' function is invoked when reset is triggered
  // The derived driver needs to implement this as to get the driver and the pins to the default
  // state when in POR
  extern virtual function void reset_interface_and_driver();
endclass


function dv_rst_safe_base_driver::new (string name, uvm_component parent);
  super.new(name, parent);
endfunction

task dv_rst_safe_base_driver::run_phase(uvm_phase phase);
  process reset_thread_id;
  process get_and_drive_thread_id;

  super.run_phase(phase);

  if (cfg.reset_domain == null)  begin
    `uvm_fatal (`gfn, "cfg.reset_domain == null, please ensure reset_domain is setup in cfg")
  end

  // The first reset is POR. Wait until a full reset cycle is observed before
  // driving any transaction on the interface
  cfg.reset_domain.wait_reset_assert();
  reset_interface_and_driver();

  cfg.reset_domain.wait_reset_deassert();

  forever begin
    // Process threading is used instead of isolation forks as it is cleaner and allows for fine
    // grained thread control.
    fork
      begin : reset_thread
        // Capture Process handle for the spawned process
        reset_thread_id = process::self();
        cfg.reset_domain.wait_reset_assert();
        reset_interface_and_driver();
      end
      begin : interface_drive_thread
        get_and_drive_thread_id = process::self();
        get_and_drive();
      end
    join_none

    // Wait until both threads have spawned properly
    wait (reset_thread_id != null && get_and_drive_thread_id  != null);

    // Now wait till reset thread finishes. Reset Thread should be the only one to finish first as
    // the 'interface_drive_thread' should be a forever loop getting transactions from the sequencer
    // and driving the interface signals.
    // Since we are using threading mechanism the 'await()' method blocks until the process on
    // which it is called has finished.
    reset_thread_id.await();

    if (   get_and_drive_thread_id.status() == process::RUNNING
        || get_and_drive_thread_id.status() == process::WAITING
        || get_and_drive_thread_id.status() == process::SUSPENDED) begin
      `uvm_info (get_name(), "killing get_and_drive_thread_id() thread", UVM_MEDIUM)
      get_and_drive_thread_id.kill();
    end else if (get_and_drive_thread_id.status() == process::FINISHED)  begin
      `uvm_fatal (`gfn, "get_and_drive_thread_id() thread finished before reset thread")
    end

    cfg.reset_domain.wait_reset_deassert();
  end // forever
endtask

function void dv_rst_safe_base_driver::reset_interface_and_driver();
  `uvm_fatal (`gfn, "reset_interface_and_driver() needs an implementation")
endfunction

// drive trans received from sequencer
task dv_rst_safe_base_driver::get_and_drive();
  `uvm_fatal (`gfn, "get_and_drive() needs an implementation")
endtask
