// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Reset-safe specialization for the TL sequencer. The monitor-fed FIFOs contain
// observations from one reset epoch. They must be discarded with the sequences
// stopped by reset so that a restarted responder cannot consume stale traffic.
class tl_rst_safe_sequencer extends tl_sequencer;
  `uvm_component_utils(tl_rst_safe_sequencer)
  `uvm_component_new

  virtual function void stop_sequences();
    super.stop_sequences();

    a_chan_req_fifo.flush();
    if (req_analysis_fifo != null) req_analysis_fifo.flush();
    if (rsp_analysis_fifo != null) rsp_analysis_fifo.flush();
  endfunction : stop_sequences
endclass : tl_rst_safe_sequencer
