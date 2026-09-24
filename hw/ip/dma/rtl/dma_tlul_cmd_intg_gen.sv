// Copyright Pavona contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`include "prim_assert.sv"

/**
 * Tile-Link UL command integrity generator (wide DMA host-port flavor)
 */

module dma_tlul_cmd_intg_gen import tlul_pkg::*; import dma_tlul_pkg::*; #(
  parameter bit EnableDataIntgGen = 1'b1
) (
  // TL-UL interface
  input  dma_tl_h2d_t tl_i,
  output dma_tl_h2d_t tl_o
);

  dma_tl_h2d_cmd_intg_t cmd;
  assign cmd = dma_extract_h2d_cmd_intg(tl_i);
  logic [DmaH2DCmdMaxWidth-1:0] unused_cmd_payload;

  logic [DmaH2DCmdIntgWidth-1:0] cmd_intg;
  prim_secded_inv_88_80_enc u_cmd_gen (
    .data_i(DmaH2DCmdMaxWidth'(cmd)),
    .data_o({cmd_intg, unused_cmd_payload})
  );

  logic [top_pkg::TL_DW-1:0] data_final;
  logic [DataIntgWidth-1:0] data_intg;

  if (EnableDataIntgGen) begin : gen_data_intg
    assign data_final = tl_i.a_data;

    logic [DataMaxWidth-1:0] unused_data;
    prim_secded_inv_39_32_enc u_data_gen (
      .data_i(DataMaxWidth'(data_final)),
      .data_o({data_intg, unused_data})
    );
  end else begin : gen_passthrough_data_intg
    assign data_final = tl_i.a_data;
    assign data_intg = tl_i.a_user.data_intg;
  end

  always_comb begin
    tl_o = tl_i;
    tl_o.a_data = data_final;
    tl_o.a_user.cmd_intg = cmd_intg;
    tl_o.a_user.data_intg = data_intg;
  end


  logic unused_tl;
  assign unused_tl = ^tl_i;

  `ASSERT_INIT(PayMaxWidthCheck_A,
      $bits(dma_tlul_pkg::dma_tl_h2d_cmd_intg_t) <= dma_tlul_pkg::DmaH2DCmdMaxWidth)

endmodule : dma_tlul_cmd_intg_gen
