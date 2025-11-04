// Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`include "prim_assert.sv"

module otbn_mul
  import otbn_pkg::*;
(
  input   logic [WLEN/4-1:0]  multiplier_op_a_i,
  input   logic [WLEN/4-1:0]  multiplier_op_b_i,
  input   logic               multiplier_vector_i, // 0: 64-bit, 1: vectorized
  input   logic               multiplier_selvector_i, //1: Kyber, 0: Dilithium
  output  logic [WLEN/2-1:0]  multiplier_res_o
);

  // Splitt operands into NOF_OP chunks of width OP_W
  localparam OP_W = 16;
  localparam NOF_OP = 4;

  // Carry-Save-Addition function to build CSA-tree after computation of partial products
  function automatic logic [WLEN-1:0] csa(
    input logic [WLEN/2-1:0] op0_i,
    input logic [WLEN/2-1:0] op1_i,
    input logic [WLEN/2-1:0] op2_i
  );
    logic [WLEN/2:0] c;
    logic [WLEN/2-1:0] s;

    c[0] = 1'b0;
    for (int i=0; i<WLEN/2; ++i) begin
        {c[i+1], s[i]} = op0_i[i] + op1_i[i] + op2_i[i];
    end

    return {c[WLEN/2-1:0],s};
  endfunction

  // Splitt multiplier_op_a_i and multiplier_op_b_i into NOF_OP chunks of width OP_W
  logic [OP_W-1:0] multiplier_op_a [NOF_OP-1:0];
  logic [OP_W-1:0] multiplier_op_b [NOF_OP-1:0];

  generate
    for (genvar i=0; i<NOF_OP-1; ++i) begin
      assign multiplier_op_a[i] = multiplier_op_a_i[(OP_W*(i+1))-1:(OP_W*i)];
      assign multiplier_op_b[i] = multiplier_op_b_i[(OP_W*(i+1))-1:(OP_W*i)];
    end
    assign multiplier_op_a[NOF_OP-1] = multiplier_op_a_i[$left(multiplier_op_a_i):(OP_W*(NOF_OP-1))];
    assign multiplier_op_b[NOF_OP-1] = multiplier_op_b_i[$left(multiplier_op_b_i):(OP_W*(NOF_OP-1))];
  endgenerate


  // Partial Product Generation
  logic [2*OP_W-1:0] partialproduct [NOF_OP*NOF_OP-1:0];
  logic [WLEN/2-1:0] mul2csa [NOF_OP*NOF_OP-1:0];

  always_comb begin
    for (int i=0; i<NOF_OP; ++i) begin
      for (int j=0; j<NOF_OP; ++j) begin
        if (multiplier_vector_i) begin
          if (multiplier_selvector_i) begin
            partialproduct[i*NOF_OP + j] = (i==j) ? (multiplier_op_a[j] * multiplier_op_b[i]) : 'b0;
          end else begin
            if (    ((i==0) && (j==0)) || ((i==1) && (j==0)) || ((i==0) && (j==1)) || ((i==1) && (j==1))
                ||  ((i==2) && (j==2)) || ((i==3) && (j==2)) || ((i==2) && (j==3)) || ((i==3) && (j==3))  ) begin
              partialproduct[i*NOF_OP + j] = (multiplier_op_a[j] * multiplier_op_b[i]);
            end else begin
              partialproduct[i*NOF_OP + j] = 'b0;
            end
          end
        end else begin
          partialproduct[i*NOF_OP + j] = multiplier_op_a[j] * multiplier_op_b[i];
        end
      end
    end
  end

  generate
    for (genvar i=0; i<NOF_OP; ++i) begin
      for (genvar j=0; j<NOF_OP; ++j) begin
        assign mul2csa[i*NOF_OP + j]  = {{(WLEN/2-2*OP_W){1'b0}} , partialproduct[i*NOF_OP + j]} << (OP_W*j + OP_W*i);
      end
    end
  endgenerate

  // Partial Product Combination
  localparam NOF_PARTIALPROD = NOF_OP*NOF_OP;
  localparam NOF_CSASTAGES = NOF_PARTIALPROD-2;

  logic [WLEN/2-1:0] carry [NOF_CSASTAGES-1:0];
  logic [WLEN/2-1:0] sum [NOF_CSASTAGES-1:0];

  // Build CSA tree for addition of (NOF_DSP_W x NOF_DSP_H) operands
  /* verilator lint_off SIDEEFFECT */
  generate
    for (genvar i=0; i<NOF_CSASTAGES; ++i) begin
      if (i == 0) begin : g_inital_stage
        assign {carry[i],sum[i]} = csa (.op0_i(mul2csa[0]), .op1_i(mul2csa[1]), .op2_i(mul2csa[2]));
      end : g_inital_stage else begin : g_intermediate_stage
        assign {carry[i],sum[i]} = csa (.op0_i(sum[i-1]), .op1_i(carry[i-1]), .op2_i(mul2csa[2+i]));
      end : g_intermediate_stage
    end
  endgenerate
  /* verilator lint_on SIDEEFFECT */

  assign multiplier_res_o = sum[$left(sum)] + carry[$left(carry)];
endmodule
