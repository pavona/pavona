module otbn_bignum_mul
(
  input  logic [256-1:0]              A,
  input  logic [256-1:0]              B,
  input  logic [$clog2(256/64)-1:0] word_sel_A,
  input  logic [$clog2(256/64)-1:0] word_sel_B,
  input  logic [1:0]                  data_type_64_shift,
  output logic [256-1:0]              result
);

  localparam int QWLEN = 64;
  localparam int WLEN = 256;

  logic [QWLEN-1:0]  mul_op_a;
  logic [QWLEN-1:0]  mul_op_b;
  logic [WLEN/2-1:0] mul_res;

  // Extract QWLEN multiply operands from WLEN operand inputs based on chosen quarter word from the
  // instruction (operand_[a|b]_qw_sel).
  always_comb begin
    mul_op_a = '0;
    mul_op_b = '0;

    unique case (word_sel_A)
      2'd0: mul_op_a = A[QWLEN*0+:QWLEN];
      2'd1: mul_op_a = A[QWLEN*1+:QWLEN];
      2'd2: mul_op_a = A[QWLEN*2+:QWLEN];
      2'd3: mul_op_a = A[QWLEN*3+:QWLEN];
      default: mul_op_a = '0;
    endcase

    unique case (word_sel_B)
      2'd0: mul_op_b = B[QWLEN*0+:QWLEN];
      2'd1: mul_op_b = B[QWLEN*1+:QWLEN];
      2'd2: mul_op_b = B[QWLEN*2+:QWLEN];
      2'd3: mul_op_b = B[QWLEN*3+:QWLEN];
      default: mul_op_b = '0;
    endcase
  end

  assign mul_res = mul_op_a * mul_op_b;

  // Shift the QWLEN multiply result into a WLEN word before accumulating using the shift amount
  // supplied in the instruction (pre_acc_shift_imm).
  always_comb begin
    result = '0;

    unique case (data_type_64_shift)
      2'd0: result = {{QWLEN * 2{1'b0}}, mul_res};
      2'd1: result = {{QWLEN{1'b0}}, mul_res, {QWLEN{1'b0}}};
      2'd2: result = {mul_res, {QWLEN * 2{1'b0}}};
      2'd3: result = {mul_res[63:0], {QWLEN * 3{1'b0}}};
      default: result = '0;
    endcase
  end

endmodule
