// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Interface used to have the SPI host FSM decrement the counter by more than 1 unit by
// forcing a decrement in the FSM counter
// This is used currently on tests running VSEQ `spi_host_upper_range_clkdiv_vseq`
// with the purpose of making simulations take less time for longer tests
interface spi_host_fsm_if ();

  // Knob to be enabled in UVM VSEQs whenever we want the decrement signal to be
  // greater than 1 (currently hardcoded at 16 when in fast_mode)
  bit fast_mode;

  localparam int unsigned FastDecrement = 16;

  // Re-evaluated every edge, since suspending this process on an edge would apply the force on
  // alternate cycles only and decrement by 17 every two cycles. Saturates at zero, the only value
  // at which the FSM advances and reloads clkdiv, so the 16-bit counter never wraps past it.
  always @(posedge u_fsm.clk_i or negedge u_fsm.rst_ni) begin
    // Matches the condition defining clk_cntr_d in spi_host_fsm.sv, which decrements by 1.
    if (u_fsm.rst_ni && fast_mode &&
        !(u_fsm.sw_rst_i || !u_fsm.clk_cntr_en ||
          u_fsm.new_command || u_fsm.is_idle || !u_fsm.clk_cntr_q)) begin
      force u_fsm.clk_cntr_d = (u_fsm.clk_cntr_q > FastDecrement) ?
                               (u_fsm.clk_cntr_q - FastDecrement) : '0;
    end else begin
      release u_fsm.clk_cntr_d;
    end
  end
endinterface
