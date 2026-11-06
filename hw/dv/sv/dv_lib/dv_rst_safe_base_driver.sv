// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0


// This is a base class for all drivers. The base class provides tasks and methods to make the
// driver reset safe.

class dv_rst_safe_base_driver #(type ITEM_T     = uvm_sequence_item,
                                type CFG_T      = dv_base_agent_cfg,
                                type RSP_ITEM_T = ITEM_T)
  extends uvm_driver #(.REQ(ITEM_T), .RSP(RSP_ITEM_T));

  `uvm_component_param_utils(dv_rst_safe_base_driver #(.ITEM_T     (ITEM_T),
                                                       .CFG_T      (CFG_T),
                                                       .RSP_ITEM_T (RSP_ITEM_T)))
  CFG_T cfg;

  bit processing_item = 0;

  // Standard UVM component task/functions
  extern function new (string name, uvm_component parent);
  extern task run_phase(uvm_phase phase);

  // 'get_and_drive' task is the main thread of the driver. A derived class will need to implement
  // the logic with the assumption that when this task is operational reset will be stable.
  // When reset is asserted the body() task implemented here will terminate the thread that invokes
  // this task and will restart it when reset is stable again.
  extern virtual task get_and_drive();

  // 'reset_interface_and_driver' function is invoked when reset is triggered
  // The derived driver needs to implement this as to get the driver and the pins to the default
  // state when in reset.
  extern virtual function void reset_interface_and_driver();

  extern task get_next_item(output ITEM_T item);
  extern virtual function void item_done(ITEM_T rsp = null);
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

  // The first reset is POR. Wait until a full reset cycle is observed before driving any transaction
  // on the interface.
  cfg.reset_domain.wait_reset_assert();
  reset_interface_and_driver();

  cfg.reset_domain.wait_reset_deassert();
  `uvm_info (get_name(), "POR Released", UVM_MEDIUM)

  forever begin
    reset_thread_id         = null;
    get_and_drive_thread_id = null;

    // Process threading is used instead of isolation forks as it is cleaner and allows for fine
    // grained thread control.
    `uvm_info (get_name(), "Reset Deasserted - Starting Reset Monitor and Main Thread", UVM_MEDIUM)
    fork
      begin : reset_thread
        // Capture Process handle for the spawned process
        reset_thread_id = process::self();
        cfg.reset_domain.wait_reset_assert();
        `uvm_info (get_name(), "Reset Asserted", UVM_MEDIUM)
        reset_interface_and_driver();
      end
      begin : interface_drive_thread
        get_and_drive_thread_id = process::self();
        get_and_drive();
      end
    join_none

    `uvm_info (get_name(), "Wait for For Process Handles", UVM_MEDIUM)

    // Wait until both threads have spawned properly
    wait (reset_thread_id != null && get_and_drive_thread_id  != null);

    `uvm_info (get_name(), "Wait for Reset Monitor Thread to finish", UVM_MEDIUM)

    // Now wait till reset thread finishes. Reset Thread should be the only one to finish first as
    // the 'interface_drive_thread' should be a forever loop getting transactions from the sequencer
    // and driving the interface signals.
    // Since we are using threading mechanism the 'await()' method blocks until the process on
    // which it is called has finished.
    reset_thread_id.await();

    `uvm_info (get_name(), "Reset Thread finished", UVM_MEDIUM)

    if (get_and_drive_thread_id.status() == process::RUNNING ||
        get_and_drive_thread_id.status() == process::WAITING ||
        get_and_drive_thread_id.status() == process::SUSPENDED) begin
      `uvm_info (get_name(), "killing get_and_drive_thread_id() thread", UVM_MEDIUM)
      get_and_drive_thread_id.kill();
      if (processing_item) begin
        `uvm_info (get_name(), "get_and_drive_thread() killed while processing item", UVM_MEDIUM)
        seq_item_port.item_done();
      end
      processing_item = 0;
    end else if (get_and_drive_thread_id.status() == process::FINISHED ||
                 get_and_drive_thread_id.status() == process::KILLED)  begin
      `uvm_fatal (`gfn, "get_and_drive_thread_id() thread finished before reset thread")
    end

    `uvm_info (get_name(), "Waiting for Reset to Deassert", UVM_MEDIUM)
    cfg.reset_domain.wait_reset_deassert();
  end // forever
endtask

function void dv_rst_safe_base_driver::reset_interface_and_driver();
  `uvm_fatal (`gfn, "reset_interface_and_driver() needs an implementation")
endfunction

// Main task of the driver that will fetch a transaction from the sequencer and then convert
// the commands in the transaction to pin wiggles on the interface of the DUT
task dv_rst_safe_base_driver::get_and_drive();
  `uvm_fatal (`gfn, "get_and_drive() needs an implementation")
endtask

task dv_rst_safe_base_driver::get_next_item(output ITEM_T item);
  seq_item_port.get_next_item(item);
  processing_item = 1;
endtask

// Completes the item the driver owns. The optional argument is the response returned to the
// sequence: a responder sequence that calls get_response() after finish_item() blocks forever
// unless the driver returns one, which is why this carries a response rather than only releasing
// the item. It defaults to null, which is exactly seq_item_port.item_done() for the drivers that
// return nothing.
function void dv_rst_safe_base_driver::item_done(ITEM_T rsp = null);
  seq_item_port.item_done(rsp);
  processing_item = 0;
endfunction
