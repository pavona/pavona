// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

module tl_agent_smoke #(
  parameter int TL_AW      = 32,
  parameter int TL_DW      = 32,
  parameter int TL_AIW     = 8,
  parameter int TL_DBW     = 4,
  parameter int TL_SZW     = 2,
  parameter int TL_OPCODE_W = 3,
  parameter int TL_PARAM_W  = 3,
  parameter int TL_AUW      = 28,
  parameter int TL_DUW      = 14,
  parameter int TL_DIW      = 1
) ();
  logic clk;
  logic rst_n;

  logic [TL_OPCODE_W-1:0] a_opcode;
  logic [TL_PARAM_W-1:0]  a_param;
  logic [TL_SZW-1:0]      a_size;
  logic [TL_AIW-1:0]      a_source;
  logic [TL_AW-1:0]       a_address;
  logic [TL_DBW-1:0]      a_mask;
  logic [TL_DW-1:0]       a_data;
  logic [TL_AUW-1:0]      a_user;
  logic                   a_valid;
  logic                   a_ready;

  logic [TL_OPCODE_W-1:0] d_opcode;
  logic [TL_PARAM_W-1:0]  d_param;
  logic [TL_SZW-1:0]      d_size;
  logic [TL_AIW-1:0]      d_source;
  logic [TL_DIW-1:0]      d_sink;
  logic [TL_DW-1:0]       d_data;
  logic [TL_DUW-1:0]      d_user;
  logic                   d_error;
  logic                   d_valid;
  logic                   d_ready;
endmodule
