// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// This is the base class for the new reset safe/aware monitor.
class dv_monitor #(type ITEM_T = uvm_sequence_item) extends uvm_monitor;
  `uvm_component_param_utils(dv_monitor #(ITEM_T))

  // Analysis port for the collected transfer.
  uvm_analysis_port #(ITEM_T) analysis_port;

  extern function new(string name, uvm_component parent);
  extern function void build_phase(uvm_phase phase);
  extern virtual function void notify(ITEM_T   trans);
endclass : dv_monitor


function dv_monitor::new(string name, uvm_component parent);
  super.new(name, parent);
  uvm_callbacks#(dv_monitor#(ITEM_T), dv_callback#(ITEM_T))::m_register_pair(this.get_type_name(),
                                                                             {name,"_monitor_cb"});
endfunction : new

function void dv_monitor::build_phase(uvm_phase phase);
  super.build_phase(phase);
  analysis_port = new("analysis_port", this);
endfunction


// Notify method is available to all monitors. This method wraps the analysis port 'write()' and
// performs callbacks to registered clients at the same time.
function void  dv_monitor::notify(ITEM_T trans);
  // Indicate the current transaction being driven.
  `uvm_info(get_name(), "dv_monitor::notify() - Called", UVM_HIGH);
  `uvm_do_callbacks(dv_monitor#(ITEM_T), dv_callback#(ITEM_T), indicated(trans))

  analysis_port.write(trans);
endfunction : notify
