// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class clk_rst_item extends uvm_sequence_item;
  typedef enum {
    // Monitor Specific Types
    RESET_ASSERTED,
    RESET_DEASSERTED,

    // Driver Specific Types
    APPLY_RESET,
    DELAY,
    CONFIG_CLK_INTF
  } clk_rst_type_e;

  clk_rst_type_e   item_type;
  rand int         reset_time_steps;
  rand int         delay_time_steps;
  realtime         reset_time;

  `uvm_object_utils_begin(clk_rst_item)
  `uvm_object_utils_end

  `uvm_object_new

endclass
