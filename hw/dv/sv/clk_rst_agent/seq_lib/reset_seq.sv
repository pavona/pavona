// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class reset_seq extends dv_base_seq #(
    .REQ         (clk_rst_item),
    .CFG_T       (clk_rst_agent_cfg),
    .SEQUENCER_T (clk_rst_sequencer)
  );
  `uvm_object_utils(reset_seq)

  `uvm_object_new

  virtual task body();
    clk_rst_item  item;

    `uvm_info (get_name(), "Starting reset_sequence::body()", UVM_LOW)

    item           = clk_rst_item::type_id::create("reset_seq:item");
    item.item_type = clk_rst_item::APPLY_RESET;
    assert (item.randomize())
    else begin
      `uvm_fatal (get_name(), "reset_sequence::body() - clk_rst_item randomisation failed")
    end

    start_item(item);
    finish_item(item);
  endtask

endclass
