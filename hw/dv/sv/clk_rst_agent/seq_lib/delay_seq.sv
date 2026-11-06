// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// 'delay_seq' is an interface sequence that work on the delay sequencer connected to the clock
// reset interface.
//
// The primary function of the delay sequence is to consume time in the primary sequence that uses
// it.
//
// To use this sequence in a higher level virtual sequence
// - Create an instance of the 'delay_seq'
// - Start the execution of the sequence : delay_seq_inst.start(delay_sequencer)


class delay_seq extends dv_base_seq #(
    .REQ         (clk_rst_item),
    .CFG_T       (clk_rst_agent_cfg),
    .SEQUENCER_T (delay_sequencer)
  );
  rand int delay_time_steps;

  constraint delay_steps_c {
    delay_time_steps inside {[100:500]};
  }

  `uvm_object_utils(delay_seq)
  `uvm_object_new

  virtual task body();
    clk_rst_item  item;
    clk_rst_item  rsp;

    `uvm_info (get_name(), "Starting delay_sequence::body()", UVM_LOW)

    item                  = clk_rst_item::type_id::create("item");
    item.item_type        = clk_rst_item::DELAY;
    item.delay_time_steps = delay_time_steps;

    start_item(item);
    finish_item(item); // Returns when driver has called item_done() as the delay count has started.
    get_response(rsp); // Returns when driver calls put_response() after the delay count has ended.

    `uvm_info (get_name(), "Completed - body()", UVM_LOW)
  endtask

endclass
