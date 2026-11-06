// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Virtual sequencer used only by the focused reset-safe TL agent test.
class tl_rst_safe_agent_virtual_sequencer extends tl_agent_virtual_sequencer;
  // Independent observation stream used to place reset at a transaction
  // boundary. It does not compete with the device responder's request FIFO.
  uvm_tlm_analysis_fifo #(tl_seq_item) device_a_chan_fifo;

  `uvm_component_utils(tl_rst_safe_agent_virtual_sequencer)
  `uvm_component_new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    device_a_chan_fifo = new("device_a_chan_fifo", this);
  endfunction : build_phase
endclass : tl_rst_safe_agent_virtual_sequencer
