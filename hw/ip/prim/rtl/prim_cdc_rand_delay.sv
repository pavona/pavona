// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// This module should be instantiated within flops of CDC synchronization primitives,
// and allows DV to model real CDC delays within simulations, especially useful at the chip level
// or in IPs that communicate across clock domains.
//
// Models three physical outcomes per bit when a signal crosses clock domains:
//
//   Normal capture: The input meets FF1's setup time. FF1 captures cleanly.
//                   dst_data_o = src_data_i, race_through_o = 0. Synchronizer delay = 2 cycles.
//
//   Missed capture: The input arrives too late for FF1. FF1 retains its old value for one cycle
//                   and captures on the next edge.
//                   dst_data_o = prev_data_i, race_through_o = 0. Synchronizer delay = 3 cycles.
//
//   Race-through:   The input arrives during FF1's setup/hold violation window. Because there is
//                   no STA closure across asynchronous clock domains, the input can race through
//                   FF1's internal latch structure and appear at its output combinationally. FF2
//                   captures it on the next edge.
//                   dst_data_o = src_data_i, race_through_o = 1, Synchronizer delay = 1 cycle.
//                   The consumer (prim_flop_2sync) uses race_through_o to bypass FF1.
//
// Each bit independently selects one of these three outcomes on every input transition.
// The select is randomized when the input changes and cleared on the next clock edge.

module prim_cdc_rand_delay #(
    parameter int DataWidth = 1,
    parameter bit Enable = 1
) (
    input logic                   clk_i,
    input logic                   rst_ni,
    input logic [DataWidth-1:0]   prev_data_i,
    input logic [DataWidth-1:0]   src_data_i,
    output logic [DataWidth-1:0]  dst_data_o,
    output logic [DataWidth-1:0]  race_through_o
);
`ifdef SIMULATION
  if (Enable) begin : gen_enable

    // This controls dst_data_o: any bit with its data_sel set uses prev_data_i, others use
    // src_data_i.
    bit [DataWidth-1:0] data_sel;
    bit [DataWidth-1:0] race_sel;
    bit                 cdc_instrumentation_enabled;

    initial begin
      void'($value$plusargs("cdc_instrumentation_enabled=%d", cdc_instrumentation_enabled));
      data_sel = '0;
    end

    // Randomize the synchronizer delay independently per bit when the input changes
    always @(src_data_i) begin
      if (cdc_instrumentation_enabled) begin
        for (int i = 0; i < DataWidth; i++) begin
          case ($urandom_range(1, 3))
            1: begin data_sel[i] = 1'b0; race_sel[i] = 1'b1; end // race-through
            2: begin data_sel[i] = 1'b0; race_sel[i] = 1'b0; end // normal capture
            3: begin data_sel[i] = 1'b1; race_sel[i] = 1'b0; end // missed capture
            default: begin data_sel[i] = 1'b0; race_sel[i] = 1'b0; end
          endcase
        end
      end else begin
        data_sel = '0;
        race_sel = '0;
      end
    end

    // Clear data_del on any cycle start.
    always @(posedge clk_i or negedge rst_ni) begin
      data_sel <= 0;
      race_sel <= 0;
    end

    always_comb dst_data_o = (prev_data_i & data_sel) | (src_data_i & ~data_sel);
    assign race_through_o = race_sel;
  end else begin : gen_no_enable
    assign dst_data_o = src_data_i;
    assign race_through_o = '0;
  end
`else  // SIMULATION
    assign dst_data_o = src_data_i;
    assign race_through_o = '0;
`endif  // SIMULATION
endmodule
