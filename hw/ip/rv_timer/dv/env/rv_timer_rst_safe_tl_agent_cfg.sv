// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// rv_timer-local reset-safe TL cfg. The DUT supports one outstanding TL transaction, so
// max_outstanding_req remains 1. This cfg only adds a one-allocation cooldown for the most recently
// released source ID to avoid immediate source reuse in dense blocking CSR traffic.
class rv_timer_rst_safe_tl_agent_cfg extends tl_agent_cfg;
  `uvm_object_utils(rv_timer_rst_safe_tl_agent_cfg)
  `uvm_object_new

  virtual function void randomize_a_source_in_req(tl_seq_item item);
    bit [SourceWidth-1:0] a_source;

    `DV_CHECK_STD_RANDOMIZE_WITH_FATAL(a_source,
        (!reset_asserted) -> !(a_source inside {a_source_pend_q});
        (!reset_asserted) -> (a_source != last_a_source_released);
        (a_source >> valid_a_source_width) == 0;)

    item.a_source = a_source;
    add_to_a_source_pend_q(item.a_source);
    `uvm_info(`gfn, $sformatf("a_source_pend_q: %p a_source: %0h",
                              a_source_pend_q, item.a_source), UVM_DEBUG)
  endfunction : randomize_a_source_in_req
endclass : rv_timer_rst_safe_tl_agent_cfg
