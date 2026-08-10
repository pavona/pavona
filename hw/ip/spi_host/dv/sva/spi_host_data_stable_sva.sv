// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

import uvm_pkg::*;

module spi_host_data_stable_sva #(
  parameter int unsigned NumCS = 1
) (
  input logic                                              clk_i,
  input logic                                              rst_ni,
  input logic                                              cio_sck_o,
  input logic [NumCS-1:0]                                  cio_csb_o,
  input logic [3:0]                                        cio_sd_i,
  input logic [3:0]                                        cio_sd_en_o,
  input spi_host_reg_pkg::spi_host_reg2hw_configopts_reg_t configopts,
  input logic [15:0]                                       fsm_clk_cntr_i,
  input logic [15:0]                                       fsm_clkdiv_i,
  input spi_device_pkg::passthrough_req_t                  passthrough_i
 );

  // Check to ensure cio_sd_o[i] stays stable for a whole clock cycle
  // Truth table:
  // ---------------------------------
  // CPHA | CPOL | posedge | negedge |
  // ---------------------------------
  // 0    | 0    | 1       | 0       | -> XNOR(cpha, cpol): drive negedge, sample posedge
  // 0    | 1    | 0       | 1       | -> XOR(cpha, cpol): drive posedge, sample negedge
  // 1    | 0    | 0       | 1       | -> XOR(cpha, cpol): drive posedge, sample negedge
  // 1    | 1    | 1       | 0       | -> XNOR(cpha, cpol): drive negedge, sample posedge
  // ---------------------------------


  // Driven in pos-edge, sampled in neg-edge
  reg    sampled_negedge_enable;
  logic  csbs;
  // Current design support NumCS=1 only
  assign csbs = &cio_csb_o;

  // HIGH when driven on pos-edge, sampled on the negedge
  assign sampled_negedge_enable = !csbs & (configopts.cpha.q ^ configopts.cpol.q);

  // Comparing against the previous value flags only an enable dropping mid-phase. An enable can
  // come on anywhere, since a new segment can start driving once the FSM has been paused.
  logic [3:0] sd_en_o_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) sd_en_o_q <= '0;
    else         sd_en_o_q <= cio_sd_en_o;
  end

  // A cio_sd_i lane is only an input while the DUT is not driving it.
  whole_cycle_data_stable_signal_checker #(.VECTOR_WIDTH(4))
  u_sva_cio_sd_i_whole_cycle_data_stable_check (
     .clk_i (clk_i),
     .rst_ni (rst_ni),
     .sck_o (cio_sck_o),
     .csb_o (csbs),
     .clk_cntr_i (fsm_clk_cntr_i),
     .clkdiv_i (fsm_clkdiv_i),
     .signal2check_i (cio_sd_i),
     .lane_check_en_i (~cio_sd_en_o),
     .sampled_negedge_enable (sampled_negedge_enable),
     .passthrough_en (passthrough_i.passthrough_en)
     );

  whole_cycle_data_stable_signal_checker #(.VECTOR_WIDTH(4))
  u_sva_cio_sd_en_o_whole_cycle_data_stable_check (
     .clk_i (clk_i),
     .rst_ni (rst_ni),
     .sck_o (cio_sck_o),
     .csb_o (csbs),
     .clk_cntr_i (fsm_clk_cntr_i),
     .clkdiv_i (fsm_clkdiv_i),
     .signal2check_i (cio_sd_en_o),
     .lane_check_en_i (sd_en_o_q),
     .sampled_negedge_enable (sampled_negedge_enable),
     .passthrough_en (passthrough_i.passthrough_en)
     );

endmodule // spi_host_data_stable_sva


module whole_cycle_data_stable_signal_checker #( parameter int VECTOR_WIDTH = 4 )
(
 input logic                    clk_i,
 input logic                    rst_ni,
 input logic                    sck_o,
 input logic                    csb_o,
 input logic [15:0]             clk_cntr_i,
 input logic [15:0]             clkdiv_i,
 input logic [VECTOR_WIDTH-1:0] signal2check_i,
 input logic [VECTOR_WIDTH-1:0] lane_check_en_i,
 input logic                    sampled_negedge_enable,
 input logic                    passthrough_en
 );

  // The FSM holds clk_cntr_i whenever it is not clocking, so a moving counter means the FSM is
  // inside a phase.
  logic [15:0] clk_cntr_d1;
  logic        cntr_advancing, in_sample_phase;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) clk_cntr_d1 <= '0;
    else         clk_cntr_d1 <= clk_cntr_i;
  end

  assign cntr_advancing  = (clk_cntr_i != clk_cntr_d1);
  assign in_sample_phase = sampled_negedge_enable ? sck_o : ~sck_o;

  for (genvar i = 0; i < VECTOR_WIDTH; i++) begin : g_signal_stable_sva

    // The bus is driven on one edge and sampled on the next, so it can't toggle in between. Skip
    // the reload cycle, where the value just driven becomes visible, and require the counter to
    // have been moving for both samples the comparison spans.
    property sample_phase_stable_p;
      @(posedge clk_i) disable iff (!rst_ni || csb_o)
        in_sample_phase && (clk_cntr_i < clkdiv_i) &&
        cntr_advancing && $past(cntr_advancing) &&
        !passthrough_en && lane_check_en_i[i] && !$isunknown(signal2check_i[i])
          |-> $stable(signal2check_i[i]);
    endproperty

    SAMPLE_PHASE_STABLE_P: assert property (sample_phase_stable_p)
    else begin
      uvm_report_error("SAMPLE_PHASE_STABLE_P",
                       {$sformatf("%m: [i=%0d] - ASSERTION FAILED",i),
                        $sformatf(" moved from 0x%0x to 0x%0x with clk_cntr at %0d of %0d",
                                  $past(signal2check_i[i]), $sampled(signal2check_i[i]),
                                  $sampled(clk_cntr_i), $sampled(clkdiv_i)),
                        $sformatf(" - time=%t", $time)});
    end
  end // block: g_signal_stable_sva

endmodule
