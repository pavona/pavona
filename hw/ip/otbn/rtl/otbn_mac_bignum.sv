// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192)
// Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors
// Modified by Ruben Niederhagen and Hoang Nguyen Hien Pham - authors of
// "Improving ML-KEM & ML-DSA on OpenTitan - Efficient Multiplication Vector Instructions for OTBN"
// (https://eprint.iacr.org/2025/2028)
// Copyright Ruben Niederhagen and Hoang Nguyen Hien Pham.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`include "prim_assert.sv"

module otbn_mac_bignum
  import otbn_pkg::*;
#(
  // Enabling PQC hardware support with vector ISA extension
  parameter bit OtbnPQCEn = 1'b1
) (
  input logic clk_i,
  input logic rst_ni,

  input mac_bignum_operation_t operation_i,
  input logic                  mac_en_i,
  input logic                  mac_commit_i,

  output logic [WLEN-1:0] operation_result_o,
  output flags_t          operation_flags_o,
  output flags_t          operation_flags_en_o,
  output logic            operation_intg_violation_err_o,

  input  mac_predec_bignum_t mac_predec_bignum_i,
  output logic               predec_error_o,

  input  logic [WLEN-1:0] urnd_data_i,
  input  logic            sec_wipe_acc_urnd_i,
  input  logic            sec_wipe_running_i,
  output logic            sec_wipe_err_o,

  output logic [ExtWLEN-1:0] ispr_acch_intg_o,
  input  logic [ExtWLEN-1:0] ispr_acch_wr_data_intg_i,
  input  logic               ispr_acch_wr_en_i,

  output logic [ExtWLEN-1:0] ispr_acc_intg_o,
  input  logic [ExtWLEN-1:0] ispr_acc_wr_data_intg_i,
  input  logic               ispr_acc_wr_en_i
);
  // The MAC operates on quarter-words, QWLEN gives the number of bits in a quarter-word.
  localparam int unsigned QWLEN = WLEN / 4;
  // Width of adder and mul nets based on PQC enable
  localparam int ADDER_WIDTH = (OtbnPQCEn) ? 2*WLEN : WLEN;

  // Tie unused ports to '0
  generate
    if (!OtbnPQCEn) begin : gen_unused_outputs
      assign ispr_acch_intg_o = '0;
    end
  endgenerate

  // Adder nets have width assigned based on PQC enable
  logic [ADDER_WIDTH-1:0] adder_op_a;
  logic [ADDER_WIDTH-1:0] adder_op_b;
  logic [ADDER_WIDTH-1:0] adder_result;
  logic [ADDER_WIDTH-1:0] mul_res_shifted;

  logic [1:0]      adder_result_hw_is_zero;

  logic [ExtWLEN-1:0] acc_intg_d;
  logic [ExtWLEN-1:0] acc_intg_q;
  logic [WLEN-1:0]    acc_blanked;
  logic               acc_en;

  logic [WLEN-1:0] operand_a_blanked, operand_b_blanked;

  logic expected_acc_rd_en, expected_op_en;

  // SEC_CM: DATA_REG_SW.SCA
  prim_blanker #(.Width(WLEN)) u_operand_a_blanker (
    .in_i (operation_i.operand_a),
    .en_i (mac_predec_bignum_i.op_en),
    .out_o(operand_a_blanked)
  );

  // SEC_CM: DATA_REG_SW.SCA
  prim_blanker #(.Width(WLEN)) u_operand_b_blanker (
    .in_i (operation_i.operand_b),
    .en_i (mac_predec_bignum_i.op_en),
    .out_o(operand_b_blanked)
  );

  `ASSERT_KNOWN_IF(OperandAQWSelKnown, operation_i.operand_a_qw_sel, mac_en_i)
  `ASSERT_KNOWN_IF(OperandBQWSelKnown, operation_i.operand_b_qw_sel, mac_en_i)

  // The reset signal is not used for any registers in this module but for assertions.  As those
  // assertions are not visible to EDA tools working with the synthesizable subset of the code
  // (e.g., Verilator), they cause lint errors in some of those tools.  Prevent these errors by
  // assigning the reset signal to a signal that is okay to be unused.
  logic unused_ok;
  assign unused_ok = ^(rst_ni);

  generate
    if (OtbnPQCEn) begin : gen_mul_pqc
      unified_mul mul (
        .word_mode         ({operation_i.mulv, operation_i.data_type}), // 00 = 64x64, 11 = 4x32x32, 10 = 16x16x16
        .word_sel_A        (operation_i.operand_a_qw_sel),
        .word_sel_B        (operation_i.operand_b_qw_sel),
        .exec_mode         (operation_i.exec_mode),
        .half_sel          (operation_i.sel),
        .lane_mode         (operation_i.lane_mode),
        .lane_word_32      (operation_i.lane_word_32),
        .lane_word_16      (operation_i.lane_word_16),
        .A                 (operand_a_blanked),
        .B                 (operand_b_blanked),
        .data_type_64_shift(operation_i.pre_acc_shift_imm),
        .result            (mul_res_shifted)
      );
    end else begin : gen_mul
      otbn_bignum_mul mul (
        .A                 (operand_a_blanked),
        .B                 (operand_b_blanked),
        .word_sel_A        (operation_i.operand_a_qw_sel),
        .word_sel_B        (operation_i.operand_b_qw_sel),
        .data_type_64_shift(operation_i.pre_acc_shift_imm),
        .result            (mul_res_shifted)
      );
    end
  endgenerate

  `ASSERT_KNOWN_IF(PreAccShiftImmKnown, operation_i.pre_acc_shift_imm, mac_en_i)

  // ECC encode and decode of accumulator register
  logic [WLEN-1:0]                acc_no_intg_d;
  logic [WLEN-1:0]                acc_no_intg_q;
  logic [ExtWLEN-1:0]             acc_intg_calc;
  logic [2*BaseWordsPerWLEN-1:0]  acc_intg_err;
  for (genvar i_word = 0; i_word < BaseWordsPerWLEN; i_word++) begin : g_acc_words
    prim_secded_inv_39_32_enc i_secded_enc (
      .data_i (acc_no_intg_d[i_word*32+:32]),
      .data_o (acc_intg_calc[i_word*39+:39])
    );
    prim_secded_inv_39_32_dec i_secded_dec (
      .data_i     (acc_intg_q[i_word*39+:39]),
      .data_o     (/* unused because we abort on any integrity error */),
      .syndrome_o (/* unused */),
      .err_o      (acc_intg_err[i_word*2+:2])
    );
    assign acc_no_intg_q[i_word*32+:32] = acc_intg_q[i_word*39+:32];
  end

  generate
    if (OtbnPQCEn) begin : gen_acch_reg
      // ECC encode and decode of accumulator high register
      logic [WLEN-1:0]                acch_no_intg_d;
      logic [WLEN-1:0]                acch_no_intg_q;
      logic [ExtWLEN-1:0]             acch_intg_calc;
      logic [2*BaseWordsPerWLEN-1:0]  acch_intg_err;

      for (genvar i_word = 0; i_word < BaseWordsPerWLEN; i_word++) begin : g_acch_words
        prim_secded_inv_39_32_enc i_secdedh_enc (
          .data_i (acch_no_intg_d[i_word*32+:32]),
          .data_o (acch_intg_calc[i_word*39+:39])
        );
        prim_secded_inv_39_32_dec i_secdedh_dec (
          .data_i     (gen_acch_wr_en.acch_intg_q[i_word*39+:39]),
          .data_o     (/* unused because we abort on any integrity error */),
          .syndrome_o (/* unused */),
          .err_o      (acch_intg_err[i_word*2+:2])
        );
        assign acch_no_intg_q[i_word*32+:32] = gen_acch_wr_en.acch_intg_q[i_word*39+:32];
      end
    end
  endgenerate

  // Propagate integrity error only if accumulator register is used: `acc_intg_q` flows into
  // `operation_result_o` via `acc`, `adder_op_b`, and `adder_result` iff the MAC is enabled and the
  // current operation does not zero the accumulation register.
  logic acc_used;
  assign acc_used = mac_en_i & ~operation_i.zero_acc;

  generate
    if (OtbnPQCEn) begin : gen_op_intg_err_pqc
      // If the MAC is enabled then the ACCH integrity error should be propagated directly
      assign operation_intg_violation_err_o = (acc_used & |(acc_intg_err))
                                              | (mac_en_i & |(gen_acch_reg.acch_intg_err));
    end else begin : gen_op_intg_err
      assign operation_intg_violation_err_o = acc_used & |(acc_intg_err);
    end
  endgenerate

  // Accumulator logic

  // SEC_CM: DATA_REG_SW.SCA
  // acc_rd_en is so if .Z set in MULQACC (zero_acc) so accumulator reads as 0
  prim_blanker #(.Width(WLEN)) u_acc_blanker (
    .in_i (acc_no_intg_q),
    .en_i (mac_predec_bignum_i.acc_rd_en),
    .out_o(acc_blanked)
  );

  generate
    if (OtbnPQCEn) begin : gen_acch_blanker
      logic [WLEN-1:0] acch_blanked;

      prim_blanker #(.Width(WLEN)) u_acch_blanker (
        .in_i (gen_acch_reg.acch_no_intg_q),
        .en_i (mac_predec_bignum_i.acc_rd_en & operation_i.mulv),
        .out_o(acch_blanked)
      );
    end
  endgenerate

  assign adder_op_a = mul_res_shifted;

  generate
    if (OtbnPQCEn) begin : gen_adder_op_pqc
      // Add shifted multiplier result to current accumulator.
      assign adder_op_b = {gen_acch_blanker.acch_blanked, acc_blanked};
    end else begin : gen_adder_op
      // Add shifted multiplier result to current accumulator.
      assign adder_op_b = acc_blanked;
    end
  endgenerate

  generate
    if (OtbnPQCEn) begin : gen_mac_adder_pqc
      vec_type_e mode;
      assign mode = operation_i.mulv ? (operation_i.data_type == 1'b0 ? VecType_s32 : VecType_d64) :
                                      VecType_v256;

      buffer_bit adder (
        .A        (adder_op_a[WLEN-1:0]),
        .B        (adder_op_b[WLEN-1:0]),
        .word_mode(mode),
        .cin      (1'b0),
        .res      (adder_result[WLEN-1:0]),
        .cout     ()
      );

      buffer_bit adder16 (
        .A        (operation_i.mulv ? adder_op_a[WLEN+:WLEN] : 256'b0),
        .B        (operation_i.mulv ? adder_op_b[WLEN+:WLEN] : 256'b0),
        .word_mode(operation_i.data_type == 1'b0 ? VecType_s32 : VecType_d64),
        .cin      (1'b0),
        .res      (adder_result[WLEN+:WLEN]),
        .cout     ()
      );

      // Split zero check between the two halves of the result. This is used for flag setting (see
      // below).
      assign adder_result_hw_is_zero[0] = adder_result[WLEN/2-1:0] == 'h0;
      assign adder_result_hw_is_zero[1] = adder_result[WLEN/2+:WLEN/2] == 'h0;

    end else begin : gen_mac_adder
      assign adder_result = adder_op_a + adder_op_b;
      // Split zero check between the two halves of the result. This is used for flag setting (see
      // below).
      assign adder_result_hw_is_zero[0] = adder_result[WLEN/2-1:0] == 'h0;
      assign adder_result_hw_is_zero[1] = adder_result[WLEN/2+:WLEN/2] == 'h0;
    end
  endgenerate

  always_comb begin
    case (operation_i.mulv)
      1'b0 : begin
        operation_flags_o.L    = adder_result[0];
        // L is always updated for .WO, and for .SO when writing to the lower half-word
        operation_flags_en_o.L = operation_i.shift_acc ? ~operation_i.wr_hw_sel_upper : 1'b1;

        // For .SO M is taken from the top-bit of shifted out half-word, otherwise it is taken from the
        // top-bit of the full result.
        operation_flags_o.M    = operation_i.shift_acc ? adder_result[WLEN/2-1] :
                                                                adder_result[WLEN-1];
        // M is always updated for .WO, and for .SO when writing to the upper half-word.
        operation_flags_en_o.M = operation_i.shift_acc ? operation_i.wr_hw_sel_upper : 1'b1;

        // For .SO Z is calculated from the shifted out half-word, otherwise it is calculated on the full
        // result.
        operation_flags_o.Z    = operation_i.shift_acc ? adder_result_hw_is_zero[0] :
                                                                &adder_result_hw_is_zero;

        // Z is updated for .WO. For .SO updates are based upon result and half-word:
        // - When writing to lower half-word always update Z.
        // - When writing to upper half-word clear Z if result is non-zero otherwise leave it alone.
        operation_flags_en_o.Z =
            operation_i.shift_acc & operation_i.wr_hw_sel_upper ? ~adder_result_hw_is_zero[0] :
                                                                  1'b1;
      end
      default: begin
        operation_flags_o.L    = 1'b0;
        operation_flags_en_o.L = 1'b0;
        operation_flags_o.M    = 1'b0;
        operation_flags_en_o.M = 1'b0;
        operation_flags_o.Z    = 1'b0;
        operation_flags_en_o.Z = 1'b0;
      end
    endcase
  end

  // MAC never sets the carry flag
  assign operation_flags_o.C    = 1'b0;
  assign operation_flags_en_o.C = 1'b0;

  // ACC
  always_comb begin
    acc_no_intg_d = '0;
    unique case (1'b1)
      // Non-encoded inputs have to be encoded before writing to the register.
      sec_wipe_acc_urnd_i: begin
        acc_no_intg_d = urnd_data_i;
        acc_intg_d = acc_intg_calc;
      end
      default: begin
        // If performing an ACC ISPR write the next accumulator value is taken from the ISPR write
        // data, otherwise it is drawn from the adder result. The new accumulator can be optionally
        // shifted right by one half-word (shift_acc).
        if (ispr_acc_wr_en_i) begin
          acc_intg_d = ispr_acc_wr_data_intg_i;
        end else begin
          acc_no_intg_d = operation_i.shift_acc ? {{QWLEN*2{1'b0}}, adder_result[QWLEN*2+:QWLEN*2]}
                                                : adder_result[0+:WLEN];
          acc_intg_d = acc_intg_calc;
        end
      end
    endcase
  end

  // Only write to accumulator if the MAC is enabled or an ACC ISPR write is occurring or secure
  // wipe of the internal state is occurring.
  assign acc_en = (mac_en_i & mac_commit_i) | ispr_acc_wr_en_i | sec_wipe_acc_urnd_i;

  always_ff @(posedge clk_i) begin
    if (acc_en) begin
      acc_intg_q <= acc_intg_d;
    end
  end

  assign ispr_acc_intg_o = acc_intg_q;

  // ACCH
  generate
    if (OtbnPQCEn) begin : gen_acch_wr_en
      // New ACCH nets
      logic [ExtWLEN-1:0] acch_intg_d;
      logic [ExtWLEN-1:0] acch_intg_q;
      logic               acch_en;

      always_comb begin
        gen_acch_reg.acch_no_intg_d = '0;
        unique case (1'b1)
          // Non-encoded inputs have to be encoded before writing to the register.
          sec_wipe_acc_urnd_i: begin   // FIX ME!
            gen_acch_reg.acch_no_intg_d = urnd_data_i;   // FIX ME!
            acch_intg_d = gen_acch_reg.acch_intg_calc;
          end
          default: begin
            if (ispr_acch_wr_en_i) begin
              acch_intg_d = ispr_acch_wr_data_intg_i;
            end else begin
              gen_acch_reg.acch_no_intg_d = adder_result[WLEN+:WLEN];
              acch_intg_d = gen_acch_reg.acch_intg_calc;
            end
          end
        endcase
      end

      // Only write to accumulator if the MAC is enabled or an ACC ISPR write is occurring or secure
      // wipe of the internal state is occurring.
      assign acch_en = (mac_en_i & mac_commit_i & operation_i.mulv) | ispr_acch_wr_en_i | sec_wipe_acc_urnd_i;  // FIX ME acch

      always_ff @(posedge clk_i) begin
        if (acch_en) begin
          acch_intg_q <= acch_intg_d;
        end
      end

      assign ispr_acch_intg_o = acch_intg_q;
    end
  endgenerate

  generate
    if (OtbnPQCEn) begin : gen_op_result_pqc
      always_comb begin
        case (operation_i.mulv)
          1'b0 : begin
            operation_result_o = adder_result[WLEN-1:0];
          end
          default: begin
            case (operation_i.exec_mode)
              2'b00 : begin
                case (operation_i.data_type)
                  1'b1 : begin
                    operation_result_o = {adder_result[384 + 64*operation_i.sel +: 64],
                                          adder_result[256 + 64*operation_i.sel +: 64],
                                          adder_result[128 + 64*operation_i.sel +: 64],
                                          adder_result[      64*operation_i.sel +: 64]};
                  end
                  1'b0 : begin
                    operation_result_o = {adder_result[448 + 32*operation_i.sel +: 32],
                                          adder_result[384 + 32*operation_i.sel +: 32],
                                          adder_result[320 + 32*operation_i.sel +: 32],
                                          adder_result[256 + 32*operation_i.sel +: 32],
                                          adder_result[192 + 32*operation_i.sel +: 32],
                                          adder_result[128 + 32*operation_i.sel +: 32],
                                          adder_result[ 64 + 32*operation_i.sel +: 32],
                                          adder_result[      32*operation_i.sel +: 32]};
                  end
                  default: begin
                    operation_result_o = {WLEN{1'b0}};   // ERROR!
                  end
                endcase
              end
              2'b01 : begin
                case (operation_i.data_type)
                  1'b1 : begin
                    case (operation_i.sel)
                      1'b0: begin
                        operation_result_o = {operand_a_blanked[224+:32], adder_result[384+:32],
                                              operand_a_blanked[160+:32], adder_result[256+:32],
                                              operand_a_blanked[ 96+:32], adder_result[128+:32],
                                              operand_a_blanked[ 32+:32], adder_result[  0+:32]};
                      end
                      1'b1: begin
                        operation_result_o = {adder_result[384+64+:32], operand_a_blanked[192+:32],
                                              adder_result[256+64+:32], operand_a_blanked[128+:32],
                                              adder_result[128+64+:32], operand_a_blanked[ 64+:32],
                                              adder_result[  0+64+:32], operand_a_blanked[  0+:32]};
                      end
                    endcase
                  end
                  1'b0 : begin
                    operation_result_o = {adder_result[480+:16], adder_result[448+:16],
                                          adder_result[416+:16], adder_result[384+:16],
                                          adder_result[352+:16], adder_result[320+:16],
                                          adder_result[288+:16], adder_result[256+:16],
                                          adder_result[224+:16], adder_result[192+:16],
                                          adder_result[160+:16], adder_result[128+:16],
                                          adder_result[ 96+:16], adder_result[ 64+:16],
                                          adder_result[ 32+:16], adder_result[  0+:16]};
                  end
                  default: begin
                    operation_result_o = {WLEN{1'b0}};   // ERROR!
                  end
                endcase
              end
              2'b10, 2'b11 : begin
                case (operation_i.data_type)
                  1'b1 : begin
                    case (operation_i.sel)
                      1'b0: begin
                        operation_result_o = {operand_a_blanked[224+:32], adder_result[416+:32],
                                              operand_a_blanked[160+:32], adder_result[288+:32],
                                              operand_a_blanked[ 96+:32], adder_result[160+:32],
                                              operand_a_blanked[ 32+:32], adder_result[ 32+:32]};
                      end
                      1'b1: begin
                        operation_result_o = {adder_result[416+64+:32], operand_a_blanked[192+:32],
                                              adder_result[288+64+:32], operand_a_blanked[128+:32],
                                              adder_result[160+64+:32], operand_a_blanked[ 64+:32],
                                              adder_result[ 32+64+:32], operand_a_blanked[  0+:32]};
                      end
                    endcase
                  end
                  1'b0 : begin
                    operation_result_o = {adder_result[496+:16], adder_result[464+:16],
                                          adder_result[432+:16], adder_result[400+:16],
                                          adder_result[368+:16], adder_result[336+:16],
                                          adder_result[304+:16], adder_result[272+:16],
                                          adder_result[240+:16], adder_result[208+:16],
                                          adder_result[176+:16], adder_result[144+:16],
                                          adder_result[112+:16], adder_result[ 80+:16],
                                          adder_result[ 48+:16], adder_result[ 16+:16]};
                  end
                  default: begin
                    operation_result_o = {WLEN{1'b0}};   // ERROR!
                  end
                endcase
              end
              default: begin
                operation_result_o = adder_result[WLEN-1:0];
              end
            endcase
          end
        endcase
      end
    end else begin : gen_op_result
      // The operation result is taken directly from the adder, shift_acc only applies to the new value
      // written to the accumulator.
      assign operation_result_o = adder_result;
    end
  endgenerate

  generate
    if (OtbnPQCEn) begin : gen_expected_op_en_pqc
      assign expected_op_en     = mac_en_i | operation_i.mulv;
    end else begin : gen_expected_op_en
      assign expected_op_en     = mac_en_i;
    end
  endgenerate

  assign expected_acc_rd_en = ~operation_i.zero_acc & mac_en_i;

  // SEC_CM: CTRL.REDUN
  assign predec_error_o = |{expected_op_en     != mac_predec_bignum_i.op_en,
                            expected_acc_rd_en != mac_predec_bignum_i.acc_rd_en};

  generate
    if (OtbnPQCEn) begin : gen_sec_wipe_err_pqc
      assign sec_wipe_err_o = sec_wipe_acc_urnd_i & ~sec_wipe_running_i; // FIX ME acch
    end else begin : gen_sec_wipe_err
      assign sec_wipe_err_o = sec_wipe_acc_urnd_i & ~sec_wipe_running_i;
    end
  endgenerate

  `ASSERT(NoISPRAccWrAndMacEn, ~(ispr_acc_wr_en_i & mac_en_i))

  generate
    if (OtbnPQCEn) begin : gen_acch_assert
      `ASSERT(NoISPRAccHWrAndMacEn, ~(ispr_acch_wr_en_i & mac_en_i))
    end
  endgenerate

endmodule
