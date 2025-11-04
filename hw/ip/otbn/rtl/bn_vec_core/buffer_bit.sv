// Copyright Ruben Niederhagen and Hoang Nguyen Hien Pham - authors of
// "Improving ML-KEM & ML-DSA on OpenTitan - Efficient Multiplication Vector Instructions for OTBN"
// (https://eprint.iacr.org/2025/2028)
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// This module implements a buffered-bit adder which performs a 256-bit addition
// (original BN-ALU addition) for base bignum instructions (such as BN.ADD/SUB,
// BN.ADDM/SUBM, etc.), 8 32-bit additions for BN.{ADDV,SUBV}(.m).8S and 16 16-bit
// additions for BN.{ADDV,SUBV}(.m).16H.
// The adder is meant to replace Adder X and Adder Y in BN-ALU. So it can either
// compute in_A + in_B (A + B) or in_A + ~in_B + 1 (A + B + cin).

module buffer_bit
  import otbn_pkg::*;
(
  input logic [WLEN-1:0]  A,
  input logic [WLEN-1:0]  B,
  input vec_type_e        word_mode,
  input logic             cin,
  output logic [WLEN-1:0] res,
  output logic [15:0]     cout
);

  logic [WLEN+14:0] A_buffed;
  logic [WLEN+14:0] B_buffed;
  logic [WLEN+15:0] R_buffed;

  genvar i;

  generate
    for (i = 0; i < 16; i++) begin
      assign A_buffed[i*17 +: 16] = A[i*16 +: 16];
      assign B_buffed[i*17 +: 16] = B[i*16 +: 16];
    end

    for (i = 1; i < 16; i += 1) begin
      assign A_buffed[i*17 - 1] = (word_mode == VecType_h16) ? (((i*16) % 16) == 0 ? cin : 1'b0) :
                                  (word_mode == VecType_s32) ? (((i*16) % 32) == 0 ? cin : 1'b0) :
                                  (word_mode == VecType_d64) ? (((i*16) % 64) == 0 ? cin : 1'b0) :
                                  1'b0;
      assign B_buffed[i*17 - 1] = (word_mode == VecType_h16) ? (((i*16) % 16) == 0 ? cin : 1'b1) :
                                  (word_mode == VecType_s32) ? (((i*16) % 32) == 0 ? cin : 1'b1) :
                                  (word_mode == VecType_d64) ? (((i*16) % 64) == 0 ? cin : 1'b1) :
                                  1'b1;
    end
  endgenerate

  assign R_buffed = A_buffed + B_buffed + {271'b0, cin};

  generate
    for(i = 0; i < 16; i++) begin
      assign res[i*16 +: 16] = R_buffed[i*17 +: 16];
      assign cout[i] = R_buffed[i*17 + 16];
    end
  endgenerate

endmodule
