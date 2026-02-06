// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192).
// Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors.
// Modified by Ruben Niederhagen and Hoang Nguyen Hien Pham - authors of
// "Improving ML-KEM & ML-DSA on OpenTitan - Efficient Multiplication Vector Instructions for OTBN"
// (https://eprint.iacr.org/2025/2028).
// Copyright Ruben Niederhagen and Hoang Nguyen Hien Pham.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`include "prim_assert.sv"

/**
 * OTBN alu block for the bignum instruction subset
 *
 * This ALU supports all of the 'plain' arithmetic and logic bignum instructions, BN.MULQACC is
 * implemented in a separate block.
 *
 * One barrel shifter and two adders (X and Y) are implemented along with the logic operators
 * (AND,OR,XOR,NOT).
 *
 * The adders have 256-bit operands with a carry_in and optional invert on the second operand. This
 * can be used to implement subtraction (a - b == a + ~b + 1). BN.SUBB/BN.ADDC are implemented by
 * feeding in the carry flag as carry in rather than a fixed 0 or 1.
 *
 * The shifter takes a 512-bit input (to implement BN.RSHI, concatenate and right shift) and shifts
 * right by up to 256-bits. The lower (256-bit) half of the input and output can be reversed to
 * allow left shift implementation.  There is no concatenate and left shift instruction so reversing
 * isn't required over the full width.
 *
 * The dataflow between the adders and shifter is in the diagram below. This arrangement allows the
 * implementation of the pseudo-mod (BN.ADDM/BN.SUBM) instructions in a single cycle whilst
 * minimising the critical path. The pseudo-mod instructions do not have a shifted input so X can
 * compute the initial add/sub and Y computes the pseudo-mod result. For all other add/sub
 * operations Y computes the operation with one of the inputs supplied by the shifter and the other
 * from operand_a.
 *
 * Both adder X and the shifter get supplied with operand_a and operand_b from the operation_i
 * input. In addition the shifter gets a shift amount (shift_amt) and can use 0 instead of
 * operand_a. The shifter concatenates operand_a (or 0) and operand_b together before shifting with
 * operand_a in the upper (256-bit) half {operand_a/0, operand_b}. This allows the shifter to pass
 * through operand_b simply by not performing a shift.
 *
 * Blanking is employed on the ALU data paths. This holds unused data paths to 0 to reduce side
 * channel leakage. The lower-case 'b' on the digram below indicates points in the data path that
 * get blanked. Note that Adder X is never used in isolation, it is always combined with Adder Y so
 * there is no need for blanking between Adder X and Adder Y.
 *
 *      A       B       A   B
 *      |       |       |   |
 *      b       b       b   b   shift_amt
 *      |       |       |   |   |
 *    +-----------+   +-----------+
 *    |  Adder X  |   |  Shifter  |
 *    +-----------+   +-----------+
 *          |               |
 *          |----+     +----|
 *          |    |     |    |
 *      X result |     | Shifter result
 *               |     |
 *             A |     |
 *             | |     |     +-----------+
 *             b |     b +---|  MOD WSR  |
 *             | |     | |   +-----------+
 *           \-----/ \-----/
 *            \---/   \---/
 *              |       |
 *              |       |
 *            +-----------+
 *            |  Adder Y  |
 *            +-----------+
 *                  |
 *              Y result
 */


module otbn_alu_bignum
  import otbn_pkg::*;
#(
  // Enabling PQC hardware support with vector ISA extension
  parameter bit OtbnPQCEn = 1'b1
) (
  input logic clk_i,
  input logic rst_ni,

  input  alu_bignum_operation_t operation_i,
  input  logic                  operation_valid_i,
  input  logic                  operation_commit_i, // used for SVAs only
  output logic [WLEN-1:0]       operation_result_o,
  output logic                  selection_flag_o,

  input  alu_predec_bignum_t  alu_predec_bignum_i,
  input  ispr_predec_bignum_t ispr_predec_bignum_i,

  input  ispr_e                       ispr_addr_i,
  input  logic [31:0]                 ispr_base_wdata_i,
  input  logic [BaseWordsPerWLEN-1:0] ispr_base_wr_en_i,
  input  logic [ExtWLEN-1:0]          ispr_bignum_wdata_intg_i,
  input  logic                        ispr_bignum_wr_en_i,
  input  logic [NFlagGroups-1:0]      ispr_flags_wr_i,
  input  logic                        ispr_wr_commit_i,
  input  logic                        ispr_init_i,
  output logic [ExtWLEN-1:0]          ispr_rdata_intg_o,
  input  logic                        ispr_rd_en_i,

  input  logic [ExtWLEN-1:0]          ispr_acc_intg_i,
  output logic [ExtWLEN-1:0]          ispr_acc_wr_data_intg_o,
  output logic                        ispr_acc_wr_en_o,

  input  logic [ExtWLEN-1:0]          ispr_acch_intg_i,
  output logic [ExtWLEN-1:0]          ispr_acch_wr_data_intg_o,
  output logic                        ispr_acch_wr_en_o,

  output logic                        reg_intg_violation_err_o,

  input  logic                        sec_wipe_mod_urnd_i,
  input  logic                        sec_wipe_kmac_regs_urnd_i,

  input  logic                        sec_wipe_running_i,
  output logic                        sec_wipe_err_o,

  input  flags_t                      mac_operation_flags_i,
  input  flags_t                      mac_operation_flags_en_i,

  input  logic [WLEN-1:0]             rnd_data_i,
  input  logic [WLEN-1:0]             urnd_data_i,

  input  logic [1:0][SideloadKeyWidth-1:0] sideload_key_shares_i,

  output logic alu_predec_error_o,
  output logic ispr_predec_error_o,

  output logic kmac_msg_write_ready_o,
  output logic kmac_msg_pending_write_o,
  output logic kmac_digest_valid_o,

  output kmac_pkg::app_req_t          kmac_app_req_o,
  input  kmac_pkg::app_rsp_t          kmac_app_rsp_i
);
  // Localparam net widths base on PQC enable
  localparam int ADDY_LEN = (OtbnPQCEn) ? WLEN-1 : WLEN+1;
  localparam int ADDER_MSB_IDX = (OtbnPQCEn) ? WLEN-1 : WLEN;
  localparam int ADDER_LSB_IDX = (OtbnPQCEn) ? 0 : 1;

  // Tie unused ports to '0
  generate
    if (!OtbnPQCEn) begin : gen_unused_outputs
      assign ispr_acch_wr_data_intg_o = '0;
      assign ispr_acch_wr_en_o        = '0;
      assign kmac_msg_write_ready_o   = '0;
      assign kmac_msg_pending_write_o = '0;
      assign kmac_digest_valid_o      = '0;
      assign kmac_app_req_o           = '0;
    end else begin : gen_unused_pqc_bits
      logic unused_pqc_bits;
    end
  endgenerate

  logic [WLEN-1:0] logical_res;
  logic [ADDY_LEN:0] adder_y_res;

  generate
    if (OtbnPQCEn) begin : gen_adder_y_res_pqc
      logic [15:0] adder_y_carry_out;
    end
  endgenerate

  ///////////
  // ISPRs //
  ///////////

  flags_t                              flags_d [NFlagGroups];
  flags_t                              flags_q [NFlagGroups];
  logic   [NFlagGroups*FlagsWidth-1:0] flags_flattened;
  flags_t                              selected_flags;
  flags_t                              adder_update_flags;
  logic                                adder_update_flags_en_raw;
  logic                                adder_carry;
  flags_t                              logic_update_flags [NFlagGroups];
  logic                                logic_update_flags_en_raw;
  flags_t                              mac_update_flags [NFlagGroups];
  logic [NFlagGroups-1:0]              mac_update_z_flag_en_blanked;
  flags_t                              ispr_update_flags [NFlagGroups];

  logic [NIspr-1:0] expected_ispr_rd_en_onehot;
  logic [NIspr-1:0] expected_ispr_wr_en_onehot;
  logic             ispr_wr_en;

  logic [NFlagGroups-1:0] expected_flag_group_sel;
  flags_t                 expected_flag_sel;
  logic [NFlagGroups-1:0] expected_flags_keep;
  logic [NFlagGroups-1:0] expected_flags_adder_update;
  logic [NFlagGroups-1:0] expected_flags_logic_update;
  logic [NFlagGroups-1:0] expected_flags_mac_update;
  logic [NFlagGroups-1:0] expected_flags_ispr_wr;

  /////////////////////
  // Flags Selection //
  /////////////////////

  always_comb begin
    expected_flag_group_sel = '0;
    expected_flag_group_sel[operation_i.flag_group] = 1'b1;
  end
  assign expected_flag_sel.C = operation_i.sel_flag == FlagC;
  assign expected_flag_sel.M = operation_i.sel_flag == FlagM;
  assign expected_flag_sel.L = operation_i.sel_flag == FlagL;
  assign expected_flag_sel.Z = operation_i.sel_flag == FlagZ;

  // SEC_CM: DATA_REG_SW.SCA
  prim_onehot_mux #(
    .Width(FlagsWidth),
    .Inputs(NFlagGroups)
  ) u_flags_q_mux (
    .clk_i,
    .rst_ni,
    .in_i  (flags_q),
    .sel_i (alu_predec_bignum_i.flag_group_sel),
    .out_o (selected_flags)
  );

  `ASSERT(BlankingSelectedFlags_A, expected_flag_group_sel == '0 |-> selected_flags == '0, clk_i,
    !rst_ni || alu_predec_error_o  || !operation_commit_i)


  logic                  flag_mux_in [FlagsWidth];
  logic [FlagsWidth-1:0] flag_mux_sel;
  assign flag_mux_in = '{selected_flags.C,
                         selected_flags.M,
                         selected_flags.L,
                         selected_flags.Z};
  assign flag_mux_sel = {alu_predec_bignum_i.flag_sel.Z,
                         alu_predec_bignum_i.flag_sel.L,
                         alu_predec_bignum_i.flag_sel.M,
                         alu_predec_bignum_i.flag_sel.C};

  // SEC_CM: DATA_REG_SW.SCA
  prim_onehot_mux #(
    .Width(1),
    .Inputs(FlagsWidth)
  ) u_flag_mux (
    .clk_i,
    .rst_ni,
    .in_i  (flag_mux_in),
    .sel_i (flag_mux_sel),
    .out_o (selection_flag_o)
  );

  `ASSERT(BlankingSelectionFlag_A, expected_flag_sel == '0 |-> selection_flag_o == '0, clk_i,
    !rst_ni || alu_predec_error_o  || !operation_commit_i)

  //////////////////
  // Flags Update //
  //////////////////

  // Note that the flag zeroing triggred by ispr_init_i and secure wipe is achieved by not
  // selecting any inputs in the one-hot muxes below. The instruction fetch/predecoder stage
  // is driving the selector inputs accordingly.

  always_comb begin
    expected_flags_adder_update = '0;
    expected_flags_logic_update = '0;
    expected_flags_mac_update   = '0;

    expected_flags_adder_update[operation_i.flag_group] = operation_i.alu_flag_en &
                                                          adder_update_flags_en_raw;
    expected_flags_logic_update[operation_i.flag_group] = operation_i.alu_flag_en &
                                                          logic_update_flags_en_raw;
    expected_flags_mac_update[operation_i.flag_group]   = operation_i.mac_flag_en;
  end
  assign expected_flags_ispr_wr = ispr_flags_wr_i;

  assign expected_flags_keep = ~(expected_flags_adder_update |
                                 expected_flags_logic_update |
                                 expected_flags_mac_update |
                                 expected_flags_ispr_wr);

  // Adder operations update all flags.
  generate
    if (OtbnPQCEn) begin : gen_adder_flags_pqc
      assign adder_carry = gen_adder_y_res_pqc.adder_y_carry_out[15];
    end else begin : gen_adder_flags
      assign adder_carry = adder_y_res[WLEN+1];
    end
  endgenerate

  assign adder_update_flags.C = (operation_i.op == AluOpBignumAdd ||
                                operation_i.op == AluOpBignumAddc) ? adder_carry : ~adder_carry;
  assign adder_update_flags.M = adder_y_res[ADDER_MSB_IDX];
  assign adder_update_flags.L = adder_y_res[ADDER_LSB_IDX];
  assign adder_update_flags.Z = ~|adder_y_res[ADDER_MSB_IDX:ADDER_LSB_IDX];

  for (genvar i_fg = 0; i_fg < NFlagGroups; i_fg++) begin : g_update_flag_groups

    // Logical operations only update M, L and Z; C must remain at its old value.
    assign logic_update_flags[i_fg].C = flags_q[i_fg].C;
    assign logic_update_flags[i_fg].M = logical_res[WLEN-1];
    assign logic_update_flags[i_fg].L = logical_res[0];
    assign logic_update_flags[i_fg].Z = ~|logical_res;

    ///////////////
    // MAC Flags //
    ///////////////

    // MAC operations don't update C.
    assign mac_update_flags[i_fg].C = flags_q[i_fg].C;

    // Tie off unused signals.
    logic unused_mac_operation_flags;
    assign unused_mac_operation_flags = mac_operation_flags_i.C ^ mac_operation_flags_en_i.C;

    // MAC operations update M and L depending on the operation. The individual enable signals for
    // M and L are generated from flopped instruction bits with minimal logic. They are not data
    // dependent.
    assign mac_update_flags[i_fg].M = mac_operation_flags_en_i.M ?
                                      mac_operation_flags_i.M : flags_q[i_fg].M;
    assign mac_update_flags[i_fg].L = mac_operation_flags_en_i.L ?
                                      mac_operation_flags_i.L : flags_q[i_fg].L;

    // MAC operations update Z depending on the operation and data. For BN.MULQACC.SO, already the
    // enable signal is data dependent (it depends on the lower half of the accumulator result). As
    // a result the enable signal might change back and forth during instruction execution which may
    // lead to SCA leakage. There is nothing that can really be done to avoid this other than
    // pipelining the flag computation which has a performance impact.
    //
    // By blanking the enable signal for the other flag group, we can at least avoid leakage related
    // to the other flag group, i.e., we give the programmer a way to control where the leakage
    // happens.
    // SEC_CM: DATA_REG_SW.SCA
    prim_blanker #(.Width(1)) u_mac_z_flag_en_blanker (
      .in_i (mac_operation_flags_en_i.Z),
      .en_i (alu_predec_bignum_i.flags_mac_update[i_fg]),
      .out_o(mac_update_z_flag_en_blanked[i_fg])
    );
    assign mac_update_flags[i_fg].Z = mac_update_z_flag_en_blanked[i_fg] ?
                                      mac_operation_flags_i.Z : flags_q[i_fg].Z;

    // For ISPR writes, we get the full write data from the base ALU and will select the relevant
    // parts using the blankers and one-hot muxes below.
    assign ispr_update_flags[i_fg] = ispr_base_wdata_i[i_fg*FlagsWidth+:FlagsWidth];
  end

  localparam int NFlagsSrcs = 5;
  for (genvar i_fg = 0; i_fg < NFlagGroups; i_fg++) begin : g_flag_groups

    flags_t                flags_d_mux_in [NFlagsSrcs];
    logic [NFlagsSrcs-1:0] flags_d_mux_sel;
    assign flags_d_mux_in = '{ispr_update_flags[i_fg],
                              mac_update_flags[i_fg],
                              logic_update_flags[i_fg],
                              adder_update_flags,
                              flags_q[i_fg]};
    assign flags_d_mux_sel = {alu_predec_bignum_i.flags_keep[i_fg],
                              alu_predec_bignum_i.flags_adder_update[i_fg],
                              alu_predec_bignum_i.flags_logic_update[i_fg],
                              alu_predec_bignum_i.flags_mac_update[i_fg],
                              alu_predec_bignum_i.flags_ispr_wr[i_fg]};

    // SEC_CM: DATA_REG_SW.SCA
    prim_onehot_mux #(
      .Width(FlagsWidth),
      .Inputs(NFlagsSrcs)
    ) u_flags_d_mux (
      .clk_i,
      .rst_ni,
      .in_i  (flags_d_mux_in),
      .sel_i (flags_d_mux_sel),
      .out_o (flags_d[i_fg])
    );

    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        flags_q[i_fg] <= '{Z : 1'b0, L : 1'b0, M : 1'b0, C : 1'b0};
      end else begin
        flags_q[i_fg] <= flags_d[i_fg];
      end
    end

    assign flags_flattened[i_fg*FlagsWidth+:FlagsWidth] = flags_q[i_fg];
  end

  /////////
  // MOD //
  /////////

  logic [ExtWLEN-1:0]          mod_intg_q;
  logic [ExtWLEN-1:0]          mod_intg_d;
  logic [BaseWordsPerWLEN-1:0] mod_ispr_wr_en;
  logic [BaseWordsPerWLEN-1:0] mod_wr_en;

  logic [ExtWLEN-1:0] ispr_mod_bignum_wdata_intg_blanked;

  // SEC_CM: DATA_REG_SW.SCA
  prim_blanker #(.Width(ExtWLEN)) u_ispr_mod_bignum_wdata_blanker (
    .in_i (ispr_bignum_wdata_intg_i),
    .en_i (ispr_predec_bignum_i.ispr_wr_en[IsprMod]),
    .out_o(ispr_mod_bignum_wdata_intg_blanked)
  );
  // If the blanker is enabled, the output will not carry the correct ECC bits.  This is not
  // a problem because a blanked value should never be written to the register.  If the blanked
  // value is written to the register nonetheless, an integrity error arises.

  logic [WLEN-1:0]                mod_no_intg_d;
  logic [WLEN-1:0]                mod_no_intg_q;
  logic [ExtWLEN-1:0]             mod_intg_calc;
  logic [2*BaseWordsPerWLEN-1:0]  mod_intg_err;
  for (genvar i_word = 0; i_word < BaseWordsPerWLEN; i_word++) begin : g_mod_words
    prim_secded_inv_39_32_enc i_secded_enc (
      .data_i (mod_no_intg_d[i_word*32+:32]),
      .data_o (mod_intg_calc[i_word*39+:39])
    );
    prim_secded_inv_39_32_dec i_secded_dec (
      .data_i     (mod_intg_q[i_word*39+:39]),
      .data_o     (/* unused because we abort on any integrity error */),
      .syndrome_o (/* unused */),
      .err_o      (mod_intg_err[i_word*2+:2])
    );
    assign mod_no_intg_q[i_word*32+:32] = mod_intg_q[i_word*39+:32];

    always_ff @(posedge clk_i) begin
      if (mod_wr_en[i_word]) begin
        mod_intg_q[i_word*39+:39] <= mod_intg_d[i_word*39+:39];
      end
    end

    always_comb begin
      mod_no_intg_d[i_word*32+:32] = '0;
      unique case (1'b1)
        // Non-encoded inputs have to be encoded before writing to the register.
        sec_wipe_mod_urnd_i: begin
          // In a secure wipe, `urnd_data_i` is written to the register before the zero word.  The
          // ECC bits should not matter between the two writes, but nonetheless we encode
          // `urnd_data_i` so there is no spurious integrity error.
          mod_no_intg_d[i_word*32+:32] = urnd_data_i[i_word*32+:32];
          mod_intg_d[i_word*39+:39]  = mod_intg_calc[i_word*39+:39];
        end
        // Pre-encoded inputs can directly be written to the register.
        default: mod_intg_d[i_word*39+:39] = ispr_mod_bignum_wdata_intg_blanked[i_word*39+:39];
      endcase

      unique case (1'b1)
        ispr_init_i: mod_intg_d[i_word*39+:39] = EccZeroWord;
        ispr_base_wr_en_i[i_word]: begin
          mod_no_intg_d[i_word*32+:32] = ispr_base_wdata_i;
          mod_intg_d[i_word*39+:39] = mod_intg_calc[i_word*39+:39];
        end
        default: ;
      endcase
    end

    `ASSERT(ModWrSelOneHot, $onehot0({ispr_init_i, ispr_base_wr_en_i[i_word]}))

    assign mod_ispr_wr_en[i_word] = (ispr_addr_i == IsprMod)                          &
                                    (ispr_base_wr_en_i[i_word] | ispr_bignum_wr_en_i) &
                                    ispr_wr_commit_i;

    assign mod_wr_en[i_word] = ispr_init_i            |
                               mod_ispr_wr_en[i_word] |
                               sec_wipe_mod_urnd_i;
  end

  //////////
  // KMAC //
  //////////
generate
  if (OtbnPQCEn) begin : gen_pqc_wsr
  // CFG
  logic [BaseIntgWidth-1:0] kmac_cfg_intg_q;
  logic [31:0]              kmac_cfg_no_intg_d;
  logic [BaseIntgWidth-1:0] kmac_cfg_intg_d;
  logic [BaseIntgWidth-1:0] kmac_cfg_intg_calc;
  logic                     kmac_cfg_ispr_wr_en;
  logic                     kmac_cfg_wr_en;
  logic [1:0]               kmac_cfg_intg_err;
  logic                     kmac_new_cfg_q;

  logic [ExtWLEN-1:0] ispr_kmac_cfg_bignum_wdata_intg_blanked;

  prim_secded_inv_39_32_enc u_kmac_cfg_secded_enc (
    .data_i (kmac_cfg_no_intg_d),
    .data_o (kmac_cfg_intg_calc)
  );

  prim_secded_inv_39_32_dec u_kmac_cfg_secded_dec (
    .data_i     (kmac_cfg_intg_q),
    .data_o     (/* unused because we abort on any integrity error */),
    .syndrome_o (/* unused */),
    .err_o      (kmac_cfg_intg_err)
  );

  prim_blanker #(.Width(ExtWLEN)) u_ispr_kmac_cfg_bignum_wdata_blanker (
    .in_i (ispr_bignum_wdata_intg_i),
    .en_i (ispr_predec_bignum_i.ispr_wr_en[IsprKmacCfg]),
    .out_o(ispr_kmac_cfg_bignum_wdata_intg_blanked)
  );

  // Index 0 because only first 32-bit word contains cfg
  assign kmac_cfg_ispr_wr_en = (ispr_addr_i == IsprKmacCfg) &
                               (ispr_base_wr_en_i[0] | ispr_bignum_wr_en_i) &
                               ispr_wr_commit_i;

  assign kmac_cfg_wr_en = (ispr_init_i | kmac_cfg_ispr_wr_en) & !kmac_app_rsp_i.error;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      kmac_cfg_intg_q <= '0;
    end else if (kmac_cfg_wr_en) begin
      kmac_cfg_intg_q <= kmac_cfg_intg_d;
    end
  end

  always_comb begin
    unique case (1'b1)
      ispr_init_i: begin
        kmac_cfg_no_intg_d  = 32'b0;
        kmac_cfg_intg_d     = kmac_cfg_intg_calc;
      end
      ispr_base_wr_en_i[0]: begin // Index 0 because only first 32-bit word contains cfg
        kmac_cfg_no_intg_d  = ispr_base_wdata_i;
        kmac_cfg_intg_d     = kmac_cfg_intg_calc;
      end
      default: begin
        kmac_cfg_no_intg_d  = 32'b0;
        kmac_cfg_intg_d     = ispr_kmac_cfg_bignum_wdata_intg_blanked[38:0];
      end
    endcase
  end

  `ASSERT(KmacCfgWrSelOneHot, $onehot0({ispr_init_i, ispr_base_wr_en_i[0]}))

  // PARTIAL WRITE
  logic [BaseIntgWidth-1:0] kmac_pw_intg_q;
  logic [31:0]              kmac_pw_no_intg_d;
  logic [BaseIntgWidth-1:0] kmac_pw_intg_d;
  logic [BaseIntgWidth-1:0] kmac_pw_intg_calc;
  logic                     kmac_pw_ispr_wr_en;
  logic                     kmac_pw_wr_en;
  logic [1:0]               kmac_pw_intg_err;
  logic [5:0]               kmac_pw_mask;

  // Nets from other blocks needed to reset the partial write
  logic                     kmac_msg_fifo_wvalid;
  logic                     kmac_msg_valid_q;
  logic                     kmac_sent_last;

  logic [ExtWLEN-1:0] ispr_kmac_pw_bignum_wdata_intg_blanked;

  prim_secded_inv_39_32_enc u_kmac_pw_secded_enc (
    .data_i (kmac_pw_no_intg_d),
    .data_o (kmac_pw_intg_calc)
  );

  prim_secded_inv_39_32_dec u_kmac_pw_secded_dec (
    .data_i     (kmac_pw_intg_q),
    .data_o     (/* unused because we abort on any integrity error */),
    .syndrome_o (/* unused */),
    .err_o      (kmac_pw_intg_err)
  );

  prim_blanker #(.Width(ExtWLEN)) u_ispr_kmac_pw_bignum_wdata_blanker (
    .in_i (ispr_bignum_wdata_intg_i),
    .en_i (ispr_predec_bignum_i.ispr_wr_en[IsprKmacPartialW]),
    .out_o(ispr_kmac_pw_bignum_wdata_intg_blanked)
  );

  // Index 0 because only first 32-bit word contains cfg
  assign kmac_pw_ispr_wr_en = (ispr_addr_i == IsprKmacPartialW) &
                              (ispr_base_wr_en_i[0] | ispr_bignum_wr_en_i) &
                              ispr_wr_commit_i;

  assign kmac_pw_wr_en = (ispr_init_i | kmac_pw_ispr_wr_en) & (~kmac_msg_valid_q | kmac_sent_last);

  always_ff @(posedge clk_i) begin
    if (kmac_pw_wr_en | kmac_new_cfg_q | kmac_msg_fifo_wvalid) begin
      kmac_pw_intg_q  <= kmac_pw_intg_d;
    end
  end

  always_comb begin
    unique case(1'b1)
      ispr_init_i: begin
        kmac_pw_no_intg_d = 32'b0;
        kmac_pw_intg_d    = kmac_pw_intg_calc;
      end
      ispr_base_wr_en_i[0] & !kmac_msg_pending_write_o: begin
        kmac_pw_no_intg_d = ispr_base_wdata_i;
        kmac_pw_intg_d    = kmac_pw_intg_calc;
      end
      kmac_new_cfg_q: begin
        kmac_pw_no_intg_d = 32'h20; // Set to full length at the start of cfg
        kmac_pw_intg_d    = kmac_pw_intg_calc;
      end
      kmac_msg_fifo_wvalid: begin // Reset the partial word at each write
        kmac_pw_no_intg_d = 32'h20;
        kmac_pw_intg_d    = kmac_pw_intg_calc;
      end
      default: begin
        kmac_pw_no_intg_d = 32'b0;
        kmac_pw_intg_d    = ispr_kmac_pw_bignum_wdata_intg_blanked[38:0];
      end
    endcase
  end

  assign kmac_pw_mask = kmac_pw_intg_q[5:0];

  `ASSERT(KmacPWWrSelOneHot, $onehot0({ispr_init_i, ispr_base_wr_en_i[0]}))

  // MSG
  logic [ExtWLEN-1:0]             kmac_msg_intg_q;
  logic [ExtWLEN-1:0]             kmac_msg_intg_d;
  logic [BaseWordsPerWLEN-1:0]    kmac_msg_ispr_wr_en;
  logic [BaseWordsPerWLEN-1:0]    kmac_msg_wr_en;
  logic [WLEN-1:0]                kmac_msg_no_intg_d;
  logic [WLEN-1:0]                kmac_msg_no_intg_q;
  logic [ExtWLEN-1:0]             kmac_msg_intg_calc;
  logic [2*BaseWordsPerWLEN-1:0]  kmac_msg_intg_err;

  logic                           kmac_msg_wr_stall;
  logic                           kmac_msg_write;

  logic [ExtWLEN-1:0] ispr_kmac_msg_bignum_wdata_intg_blanked;

  prim_blanker #(.Width(ExtWLEN)) u_ispr_kmac_msg_bignum_wdata_blanker (
    .in_i (ispr_bignum_wdata_intg_i),
    .en_i (ispr_predec_bignum_i.ispr_wr_en[IsprKmacMsg]),
    .out_o(ispr_kmac_msg_bignum_wdata_intg_blanked)
  );

  for (genvar i_word = 0; i_word < BaseWordsPerWLEN; i_word++) begin : g_kmac_msg_words
    prim_secded_inv_39_32_enc i_kmac_msg_secded_enc (
      .data_i (kmac_msg_no_intg_d[i_word*32+:32]),
      .data_o (kmac_msg_intg_calc[i_word*39+:39])
    );
    prim_secded_inv_39_32_dec i_kmac_msg_secded_dec (
      .data_i     (kmac_msg_intg_q[i_word*39+:39]),
      .data_o     (/* unused because we abort on any integrity error */),
      .syndrome_o (/* unused */),
      .err_o      (kmac_msg_intg_err[i_word*2+:2])
    );

    assign kmac_msg_ispr_wr_en[i_word] = (ispr_addr_i == IsprKmacMsg) &
                                         (ispr_base_wr_en_i[i_word] | ispr_bignum_wr_en_i) &
                                         ispr_wr_commit_i;

    assign kmac_msg_wr_en[i_word] = (ispr_init_i |
                                    (kmac_msg_ispr_wr_en[i_word] & kmac_msg_write_ready_o) |
                                    sec_wipe_kmac_regs_urnd_i) & ~kmac_msg_wr_stall;

    always_ff @(posedge clk_i) begin
      if (kmac_msg_wr_en[i_word]) begin
        kmac_msg_intg_q[i_word*39+:39] <= kmac_msg_intg_d[i_word*39+:39];
      end
    end
    assign kmac_msg_no_intg_q[i_word*32+:32] = kmac_msg_intg_q[i_word*39+:32];

    always_comb begin
      kmac_msg_no_intg_d[i_word*32+:32] = '0;
      kmac_msg_intg_d[i_word*39+:39] = '0;
      if (sec_wipe_kmac_regs_urnd_i) begin
        // Non-encoded inputs have to be encoded before writing to the register.
        kmac_msg_no_intg_d[i_word*32+:32] = urnd_data_i[i_word*32+:32];
        kmac_msg_intg_d[i_word*39+:39] = kmac_msg_intg_calc[i_word*39+:39];
      end else begin
        // Pre-encoded inputs can directly be written to the register.
        kmac_msg_intg_d[i_word*39+:39] = ispr_kmac_msg_bignum_wdata_intg_blanked[i_word*39+:39];
      end
    end

    `ASSERT(KmacMsgWrSelOneHot, $onehot0({ispr_init_i, ispr_base_wr_en_i[i_word]}))
  end

  assign kmac_msg_write = (ispr_addr_i == IsprKmacMsg) & ispr_wr_commit_i;

  // STATUS
  logic [BaseIntgWidth-1:0] kmac_status_intg_q;
  logic [BaseIntgWidth-1:0] kmac_status_intg_d;
  logic [31:0]              kmac_status_no_intg_d;
  logic [1:0]               kmac_status_intg_err;

  // Error handling status for undersized message
  logic kmac_undersized_req_err;
  logic kmac_undersized_req_err_latch;

  // Error handling status for oversized message
  logic kmac_oversized_req_err;
  logic kmac_oversized_req_err_latch;

  prim_secded_inv_39_32_enc u_kmac_status_secded_enc (
    .data_i (kmac_status_no_intg_d),
    .data_o (kmac_status_intg_d)
  );

  prim_secded_inv_39_32_dec u_kmac_status_secded_dec (
    .data_i     (kmac_status_intg_q),
    .data_o     (/* unused because we abort on any integrity error */),
    .syndrome_o (/* unused */),
    .err_o      (kmac_status_intg_err)
  );

  assign kmac_status_no_intg_d = kmac_new_cfg_q ? 32'b0 : {
    27'b0,
    kmac_undersized_req_err_latch,
    kmac_oversized_req_err_latch,
    kmac_app_rsp_i.error,
    kmac_app_rsp_i.ready,
    kmac_app_rsp_i.done
  };

  // If oversized err flag goes high at any point during transaction latch value into status reg
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      kmac_oversized_req_err_latch <= 1'b0;
    end else begin
      if (kmac_new_cfg_q) begin
        kmac_oversized_req_err_latch <= 1'b0;
      end else if (kmac_oversized_req_err) begin
        kmac_oversized_req_err_latch <= 1'b1;
      end
    end
  end

  // If undersized err flag goes high at any point during transaction latch value into status reg
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      kmac_undersized_req_err_latch <= 1'b0;
    end else begin
      if (kmac_new_cfg_q) begin
        kmac_undersized_req_err_latch <= 1'b0;
      end else if (kmac_undersized_req_err) begin
        kmac_undersized_req_err_latch <= 1'b1;
      end
    end
  end

  always_ff @(posedge clk_i) begin
    kmac_status_intg_q <= kmac_status_intg_d;
  end

  // DIGEST
  logic [kmac_pkg::AppDigestW-1:0]      unmasked_digest_share;
  logic [DigestRegLen-1:0]              kmac_digest_no_intg_d;
  logic [ExtDigestLen-1:0]              kmac_digest_intg_q;
  logic [ExtDigestLen-1:0]              kmac_digest_intg_d;
  logic [BaseWordsPerDigestLen-1:0]     kmac_digest_wr_en;
  logic [2*BaseWordsPerDigestLen-1:0]   kmac_digest_intg_err;
  logic                                 kmac_digest_rd_next;
  logic                                 kmac_digest_valid_q;
  logic [1:0]                           sha_digest_rsp_cnt;

  for (genvar i_word = 0; i_word < BaseWordsPerDigestLen; i_word++) begin : g_kmac_digest_words
    prim_secded_inv_39_32_enc i_kmac_digest_secded_enc (
      .data_i (kmac_digest_no_intg_d[i_word*32+:32]),
      .data_o (kmac_digest_intg_d[i_word*39+:39])
    );
    prim_secded_inv_39_32_dec i_kmac_digest_secded_dec (
      .data_i     (kmac_digest_intg_q[i_word*39+:39]),
      .data_o     (/* unused because we abort on any integrity error */),
      .syndrome_o (/* unused */),
      .err_o      (kmac_digest_intg_err[i_word*2+:2])
    );

    always_ff @(posedge clk_i) begin
      if (kmac_digest_wr_en[i_word]) begin
        kmac_digest_intg_q[i_word*39+:39] <= kmac_digest_intg_d[i_word*39+:39];
      end
    end

    assign kmac_digest_no_intg_d[i_word*32+:32] = sec_wipe_kmac_regs_urnd_i ?
        urnd_data_i[(i_word % BaseWordsPerDigestLen)*32+:32] :
        unmasked_digest_share[i_word*32+:32];

    assign kmac_digest_wr_en[i_word] = kmac_app_rsp_i.done | sec_wipe_kmac_regs_urnd_i;
  end

  assign kmac_digest_valid_o = kmac_digest_valid_q;
  assign kmac_digest_rd_next = kmac_digest_valid_q &&
                               ispr_predec_bignum_i.ispr_rd_en[IsprKmacDigest];

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      kmac_digest_valid_q <= 1'b0;
    end else if (kmac_digest_rd_next || kmac_new_cfg_q) begin
      kmac_digest_valid_q <= 1'b0;
    end else if (kmac_app_rsp_i.done) begin
      kmac_digest_valid_q <= 1'b1;
    end
  end

  // Only in SHA256 or SHA512 mode accumulate and limit the number of responses
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      sha_digest_rsp_cnt <= 2'b0;
    end else if (kmac_new_cfg_q) begin
      sha_digest_rsp_cnt <= 2'b0;
    end else if (sha3_pkg::sha3_mode_e'(kmac_cfg_intg_q[1:0]) == sha3_pkg::Sha3) begin
      if (ispr_predec_bignum_i.ispr_rd_en[IsprKmacDigest] && kmac_digest_valid_q) begin
        sha_digest_rsp_cnt <= sha_digest_rsp_cnt + 1'b1;
      end
    end
  end

  // Digest shares are xor'ed to get the unmasked share value
  // If KMAC is operating in unmasked mode then share1 is '0 and xor remains the unmasked val
  assign unmasked_digest_share = kmac_app_rsp_i.digest_share0 ^ kmac_app_rsp_i.digest_share1;

  // MSG INTERFACE
  sha3_pkg::sha3_mode_e           kmac_cfg_sha3_mode;
  sha3_pkg::keccak_strength_e     kmac_cfg_keccak_strength;
  logic [10:0]                    kmac_cfg_unused_msg_len;
  logic [14:0]                    kmac_cfg_msg_len;
  logic [11:0]                    kmac_cfg_msg_len_words;
  logic [2:0]                     kmac_cfg_msg_len_bytes;
  logic [11:0]                    kmac_msg_ctr;

  logic                           kmac_msg_err_clr;
  logic                           kmac_msg_err_clr_q;
  logic                           kmac_msg_fifo_wready;
  logic [WLEN-1:0]                kmac_msg_fifo_wdata;
  logic [WLEN-1:0]                kmac_msg_fifo_wdata_mask;
  logic                           kmac_msg_fifo_rvalid;
  logic                           kmac_msg_fifo_rready;
  logic [kmac_pkg::MsgWidth-1:0]  kmac_msg_fifo_rdata;
  logic [kmac_pkg::MsgWidth-1:0]  kmac_msg_fifo_rdata_mask;
  logic                           kmac_msg_fifo_flush;
  logic                           kmac_msg_fifo_clr;
  logic                           kmac_last_msg_all_bytes_valid;
  logic [kmac_pkg::MsgStrbW-1:0]  kmac_last_msg_strb;

  logic       packer_ctr_last;
  logic [7:0] packer_rdata_mask;
  logic [3:0] packer_rdata_mask_cnt;

  logic kmac_app_active;
  logic kmac_app_last;
  logic kmac_msg_active_q;
  logic kmac_cfg_active_q;
  logic kmac_write_cfg_to_app;
  logic kmac_msg_ctr_err;
  logic kmac_msg_last;
  logic kmac_idle_q;
  logic kmac_cfg_done;
  logic kmac_app_cfg_sent;

  // Oversized and undersized msg handling
  logic kmac_msg_req_err;
  logic kmac_pending_last;
  logic kmac_inject_last_err;
  logic kmac_undersized_req_err_q;
  logic kmac_undersized_req_err_pe;

  kmac_undersized_state_e kmac_err_st_d, kmac_err_st_q;
  // Oversized error flag if last has already been sent and there is an additional fifo valid
  // Need to add a case when the fifo rvalid mask is greater than the last word strb
  logic last_word_oversized;
  logic rw_after_last;
  logic write_during_last;
  logic not_full_word;
  logic packer_oversized_last;

  assign kmac_cfg_sha3_mode       = sha3_pkg::sha3_mode_e'(kmac_cfg_intg_q[1:0]);
  assign kmac_cfg_keccak_strength = sha3_pkg::keccak_strength_e'(kmac_cfg_intg_q[4:2]);
  assign kmac_cfg_done            = kmac_cfg_intg_q[31];
  assign kmac_cfg_msg_len         = kmac_cfg_intg_q[19:5];
  assign kmac_cfg_msg_len_words   = kmac_cfg_msg_len[14:3];
  assign kmac_cfg_msg_len_bytes   = kmac_cfg_msg_len[2:0];
  assign kmac_msg_err_clr         = kmac_app_rsp_i.error
                                    | sec_wipe_kmac_regs_urnd_i
                                    | kmac_msg_ctr_err;

  // We speculatively fetch the next digest but this is illegal for non XOF
  // modes. As such SHA will need to limit the speculative fetch based on strength.
  logic kmac_next_sha;

  always_comb begin
    unique case (kmac_cfg_sha3_mode)
      sha3_pkg::Sha3: begin
        if (kmac_cfg_keccak_strength == sha3_pkg::L256) begin
          kmac_next_sha = 1'b0; // There will never be a new read
        end else if (kmac_cfg_keccak_strength == sha3_pkg::L512) begin
          if (sha_digest_rsp_cnt < 1) begin
            kmac_next_sha = 1'b1;
          end else begin
            kmac_next_sha = 1'b0;
          end
        end
      end
      sha3_pkg::Shake: begin
        kmac_next_sha = 1'b1;
      end
      sha3_pkg::CShake: begin
        kmac_next_sha = 1'b1;
      end
      default: begin
        kmac_next_sha = 1'b0;
      end
    endcase
  end

  // Create the strb for the last word in msg request
  assign kmac_last_msg_all_bytes_valid = &(~kmac_cfg_msg_len_bytes);
  for (genvar i_bit = 1; i_bit < kmac_pkg::MsgStrbW+1; i_bit++) begin : gen_kmac_strb
    assign kmac_last_msg_strb[i_bit-1] = kmac_last_msg_all_bytes_valid
                                         | (i_bit <= kmac_cfg_msg_len_bytes);
  end

  // Set flag for a new KMAC cfg to indicate start/end of transaction
  // Used to ensure FIFO is flushed and set bounds of transaction
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      kmac_new_cfg_q <= 1'b0;
    end else if (kmac_cfg_wr_en & !sec_wipe_kmac_regs_urnd_i & !ispr_init_i) begin
      kmac_new_cfg_q <= 1'b1;
    end else begin
      kmac_new_cfg_q <= 1'b0;
    end
  end

  // If there is an error we need to flush the remainder of the FIFO under the assumption
  // that KMAC won't be asserting a ready signal to OTBN. Latch the error flag until a new
  // config is written to OTBN and use this to empty the FIFO and prepare for the next transaction.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      kmac_msg_err_clr_q <= 1'b0;
    end else if (kmac_cfg_wr_en) begin
      kmac_msg_err_clr_q <= 1'b0;
    end else if (kmac_msg_err_clr) begin
      kmac_msg_err_clr_q <= 1'b1;
    end
  end

  // Set cfg and msg status flags for transaction
  // CFG is active from start of config until end of transaction
  // MSG is active after the cfg word is sent
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      kmac_msg_active_q <= 1'b0;
      kmac_cfg_active_q <= 1'b0;
    end else if (kmac_new_cfg_q) begin
      kmac_msg_active_q <= 1'b0;
      kmac_cfg_active_q <= 1'b1;
    end else if (kmac_msg_err_clr || kmac_idle_q) begin
      kmac_msg_active_q <= 1'b0;
      kmac_cfg_active_q <= 1'b0;
    end else if (kmac_msg_fifo_wready) begin //kmac_app_cfg_sent
      kmac_msg_active_q <= kmac_cfg_active_q;
    end
  end

  // Message is valid when there is ISPR write to the MSG WSR
  // Value is held until it is written into the fifo at the first wready signal
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      kmac_msg_valid_q <= 1'b0;
    end else if (|(kmac_msg_wr_en) & !sec_wipe_kmac_regs_urnd_i & !ispr_init_i) begin
      kmac_msg_valid_q <= 1'b1;
    end else if (kmac_msg_fifo_wready) begin
      kmac_msg_valid_q <= 1'b0;
    end
  end

  // KMAC is idle when CFG WSR bit [31] is 1
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      kmac_idle_q <= 1'b1;
    end else if (kmac_cfg_done) begin
      kmac_idle_q <= 1'b1;
    end else begin
      kmac_idle_q <= 1'b0;
    end
  end

  // Internal status flag to track when the configuration word has been sent to KMAC
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      kmac_app_cfg_sent <= 1'b0;
    end else if (kmac_cfg_active_q) begin
      if (kmac_app_rsp_i.ready) begin
        kmac_app_cfg_sent <= 1'b1;
      end
    end else begin
      kmac_app_cfg_sent <= 1'b0;
    end
  end

  // Translates the 5-bit decimal mask from PW WSR to 256-bit bit wise mask for APP FIFO
  always_comb begin
    kmac_msg_fifo_wdata_mask = '0;
    if (kmac_pw_mask == 0) begin
      kmac_msg_fifo_wdata_mask = 256'b0;
    end else begin
      kmac_msg_fifo_wdata_mask = ~({256{1'b1}} << (kmac_pw_mask * 8));
    end
  end

  // Convert the number of 1's in byte mask to decimal value for comparison
  // with CFG WSR partial word byte field
  always_comb begin
    packer_rdata_mask_cnt = '0;
    for (int i = 0; i < kmac_pkg::MsgStrbW; i++) begin
      // collapse each 8-bit chunk into one strb bit
      packer_rdata_mask[i] = |kmac_msg_fifo_rdata_mask[i*8 +: 8];
    end
    foreach (packer_rdata_mask[i]) begin
      packer_rdata_mask_cnt += {3'b0, packer_rdata_mask[i]};
    end
  end

  // Internal copy of otbn_controller stall signal to determine pending msg writes
  assign kmac_msg_wr_stall = (kmac_msg_write & (~kmac_msg_fifo_wready));

  // When reading the return digest the message has already been sent and any remainder is cleared
  assign kmac_msg_fifo_clr = kmac_sent_last && (ispr_addr_i == IsprKmacDigest) &&
                             !kmac_msg_pending_write_o;

  // Prim packer is used to send full words until the final word in msg request
  prim_packer #(
    .InW  (WLEN),
    .OutW (kmac_pkg::MsgWidth)
  ) u_kmac_msg_fifo (
    .clk_i,
    .rst_ni,

    .valid_i      (kmac_msg_fifo_wvalid),
    .data_i       (kmac_msg_fifo_wdata),
    .mask_i       (kmac_msg_fifo_wdata_mask),
    .ready_o      (kmac_msg_fifo_wready),

    .valid_o      (kmac_msg_fifo_rvalid),
    .data_o       (kmac_msg_fifo_rdata),
    .mask_o       (kmac_msg_fifo_rdata_mask),
    .ready_i      (kmac_msg_fifo_rready),

    // kmac_msg_err_clr is for internal OTBN error to empty the FIFO
    // kmac_msg_fifo_flush reads a partial word at the end of the msg
    // kmac_msg_fifo_clr ensures the fifo is empty outside of an active msg
    .flush_i      (kmac_msg_err_clr || kmac_msg_fifo_flush || kmac_msg_fifo_clr),
    .flush_done_o (),

    .err_o        ()
  );

  // Prim counter is used to keep track of the message size sent
  prim_count #(
    .Width (12),
    .EnableAlertTriggerSVA('0)
  ) u_kmac_msg_ctr (
    .clk_i,
    .rst_ni,

    .clr_i              (kmac_msg_err_clr || kmac_new_cfg_q || kmac_sent_last),
    .set_i              (1'b0),
    .set_cnt_i          ({(12){1'b0}}),
    .incr_en_i          (kmac_msg_fifo_rvalid & kmac_app_rsp_i.ready & kmac_msg_fifo_rready),
    .decr_en_i          (1'b0),
    .step_i             ({{(11){1'b0}}, {1'b1}}),
    .commit_i           (1'b1),
    .cnt_o              (kmac_msg_ctr),
    .cnt_after_commit_o (/* unused */),
    .err_o              (kmac_msg_ctr_err)
  );

  // Ensure that the read mask is at least the size of the cfg before asserting last
  assign packer_ctr_last       = (packer_rdata_mask_cnt >= {1'b0, kmac_cfg_msg_len_bytes});

  // If it is time for the final word and there is a partial word we need to flush it out
  assign kmac_msg_fifo_flush   = (kmac_msg_last && (kmac_cfg_msg_len_bytes != 3'h0) &&
                                 ~kmac_msg_fifo_rvalid);

  assign kmac_write_cfg_to_app =  kmac_cfg_active_q && (~kmac_msg_active_q | ~kmac_app_cfg_sent) &&
                                  ~kmac_idle_q;

  // fifo write iface
  assign kmac_msg_fifo_wdata  = kmac_msg_no_intg_q;
  assign kmac_msg_fifo_wvalid = kmac_cfg_active_q && kmac_msg_valid_q && kmac_msg_fifo_wready &&
                                ~kmac_msg_fifo_flush && ~kmac_sent_last && (~kmac_msg_last);

  assign kmac_msg_write_ready_o   = kmac_msg_fifo_wready;
  assign kmac_msg_pending_write_o = kmac_msg_valid_q && ~kmac_sent_last;

  // fifo read iface
  assign kmac_msg_fifo_rready = (kmac_app_rsp_i.ready & ~kmac_write_cfg_to_app) |
                                (kmac_sent_last | kmac_msg_err_clr_q);

  assign kmac_msg_last = (kmac_cfg_msg_len_bytes == 3'h0) ?
                        (kmac_msg_ctr >= kmac_cfg_msg_len_words - 1) && kmac_msg_fifo_rvalid :
                        ((kmac_msg_ctr >= kmac_cfg_msg_len_words) && packer_ctr_last);

  // Compute the assignment for kmac_app_req_o.hold
  assign kmac_app_active = kmac_cfg_active_q & ~kmac_new_cfg_q & ~kmac_cfg_done;

  // Compute the assignment for kmac_app_req_o.last
  assign kmac_app_last = kmac_inject_last_err | (kmac_msg_fifo_rvalid & kmac_msg_last);

  // When there is an undersized message we artificially inject a last valid to finish the message
  assign kmac_app_req_o.valid = (kmac_write_cfg_to_app || kmac_inject_last_err) ?
                                1'b1 : kmac_msg_fifo_rvalid && ~kmac_new_cfg_q &&
                                      ~kmac_sent_last && ~kmac_msg_err_clr_q;

  // The first word contains the cfg otherwise send the body
  assign kmac_app_req_o.data  = kmac_write_cfg_to_app ?
                                {59'b0, kmac_cfg_keccak_strength, kmac_cfg_sha3_mode} :
                                kmac_msg_fifo_rdata;

  // The strb will always be 8'hFF except for the CFG and last word
  assign kmac_app_req_o.strb  = kmac_write_cfg_to_app ?
                                8'h01 : kmac_app_last ?
                                kmac_last_msg_strb : {(kmac_pkg::MsgStrbW){1'b1}};

  // When there is an undersized message we artifically inject a last signal to finish the message
  assign kmac_app_req_o.last  = kmac_app_last;

  // If we request an additional digest send a next to KMAC
  assign kmac_app_req_o.next  = kmac_digest_valid_o
                                & ispr_predec_bignum_i.ispr_rd_en[IsprKmacDigest]
                                & kmac_next_sha;

  // Hold will remain active for duration of transaction unless an internal error occurs
  assign kmac_app_req_o.hold  = kmac_app_active;

  // check for incomplete msg with pending digest
  // Latch for last in current transaction
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      kmac_pending_last <= 1'b0;
      kmac_sent_last <= 1'b0;
    end else begin
      // Either we observed a valid last or we artificially created a last
      if ((kmac_msg_fifo_rvalid & kmac_msg_last) | kmac_inject_last_err) begin
        kmac_pending_last <= 1'b1; // Prepared to send the final word
        if (kmac_app_rsp_i.ready) begin
          kmac_sent_last <= 1'b1;
        end
      end else if (kmac_cfg_wr_en) begin
        // Clear any last flags after a new cfg is written
        kmac_pending_last <= 1'b0;
        kmac_sent_last <= 1'b0;
      end
    end
  end

  // If current instruction is KMAC Digest check if KMAC received all data
  // There should be no outstanding transactions to write into the FIFO
  // There should not be any new words being written or read to/from the FIFO
  // The FIFO should not be in a flush cycle
  always_comb begin
    kmac_msg_req_err = 1'b0;
    if (ispr_addr_i == IsprKmacDigest && kmac_app_active) begin
      kmac_msg_req_err = (!kmac_msg_pending_write_o && !kmac_msg_fifo_rvalid
                        && !kmac_msg_fifo_flush && !kmac_msg_fifo_wvalid);
    end
  end

  // If we have not received a last see if there is an error
  assign kmac_undersized_req_err = kmac_msg_req_err & ~kmac_pending_last;

  // Register the undersized req err to compute a posedge
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      kmac_undersized_req_err_q <= 1'b0;
    end else begin
      kmac_undersized_req_err_q <= kmac_undersized_req_err;
    end
  end

  // Posedge of undersize kmac req err
  assign kmac_undersized_req_err_pe = ~kmac_undersized_req_err_q && kmac_undersized_req_err;

  // Combinatorial state machine for oversized message computation
  always_comb begin
    kmac_err_st_d = kmac_err_st_q;
    kmac_inject_last_err = 1'b0;
    unique case (kmac_err_st_q)
      StIdle: begin
        // At the first appearance of an undersized message during a tranasaction
        // set a flag to inject an artificial last word and wait until KMAC is ready
        if (kmac_undersized_req_err_pe) begin
          kmac_inject_last_err = 1'b1;
          if (~kmac_app_rsp_i.ready) begin
            kmac_err_st_d = StPendingReady;
          end
        end
      end
      StPendingReady: begin
        // Continue holding last word until acknowledgement from KMAC
        kmac_inject_last_err = 1'b1;
        if (kmac_app_rsp_i.ready) begin
          kmac_err_st_d = StIdle;
        end
      end
      default: begin
        kmac_err_st_d = StIdle;
        kmac_inject_last_err = 1'b0;
      end
    endcase
  end

  // Register the state
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      kmac_err_st_q <= StIdle;
    end else begin
      kmac_err_st_q <= kmac_err_st_d;
    end
  end

  // The cfg reads 0 when it is a full word which means the mask is 8 so we must skip evaluation
  // at these sizes, otherwise check if mask is greater than the cfg
  assign not_full_word         = ~(packer_rdata_mask_cnt == 4'h8 & kmac_cfg_msg_len_bytes == 3'h0);
  assign packer_oversized_last =
      not_full_word & (packer_rdata_mask_cnt > {1'b0, kmac_cfg_msg_len_bytes});

  assign last_word_oversized    = kmac_msg_last & packer_oversized_last;
  // Read or write to/from FIFO that occurs after last
  assign rw_after_last          = kmac_sent_last & (kmac_msg_fifo_rvalid | kmac_msg_valid_q);
  // There is still a pending write to the FIFO while last is being asserted after flush
  assign write_during_last      = kmac_app_last & kmac_msg_valid_q;
  // Injecting an artificial last may impact the write_during_last flag so we check that the
  // message isn't undersized before raising this flag
  assign kmac_oversized_req_err = (rw_after_last | write_during_last)
                                  & ~kmac_undersized_req_err_latch | last_word_oversized;
  end
endgenerate

  /////////
  // ACC //
  /////////

  assign ispr_acc_wr_en_o   =
    ((ispr_addr_i == IsprAcc) & ispr_bignum_wr_en_i & ispr_wr_commit_i) | ispr_init_i;


  logic [ExtWLEN-1:0] ispr_acc_bignum_wdata_intg_blanked;

  // SEC_CM: DATA_REG_SW.SCA
  prim_blanker #(.Width(ExtWLEN)) u_ispr_acc_bignum_wdata_intg_blanker (
    .in_i (ispr_bignum_wdata_intg_i),
    .en_i (ispr_predec_bignum_i.ispr_wr_en[IsprAcc]),
    .out_o(ispr_acc_bignum_wdata_intg_blanked)
  );
  // If the blanker is enabled, the output will not carry the correct ECC bits.  This is not
  // a problem because a blanked value should never be used.  If the blanked value is used
  // nonetheless, an integrity error arises.

  assign ispr_acc_wr_data_intg_o = ispr_init_i ? EccWideZeroWord
                                               : ispr_acc_bignum_wdata_intg_blanked;

  //////////
  // ACCH //
  //////////
  generate
    if (OtbnPQCEn) begin : gen_acch_wsr
      assign ispr_acch_wr_en_o =
          ((ispr_addr_i == IsprAccH) & ispr_bignum_wr_en_i & ispr_wr_commit_i) | ispr_init_i;

      logic [ExtWLEN-1:0] ispr_acch_bignum_wdata_intg_blanked;

      // SEC_CM: DATA_REG_SW.SCA
      prim_blanker #(.Width(ExtWLEN)) u_ispr_acch_bignum_wdata_intg_blanker (
        .in_i (ispr_bignum_wdata_intg_i),
        .en_i (ispr_predec_bignum_i.ispr_wr_en[IsprAccH]),
        .out_o(ispr_acch_bignum_wdata_intg_blanked)
      );
      // If the blanker is enabled, the output will not carry the correct ECC bits.  This is not
      // a problem because a blanked value should never be used.  If the blanked value is used
      // nonetheless, an integrity error arises.

      assign ispr_acch_wr_data_intg_o = ispr_init_i ? EccWideZeroWord
                                                  : ispr_acch_bignum_wdata_intg_blanked;
    end
  endgenerate

  // ISPR read data is muxed out in two stages:
  // 1. Select amongst the ISPRs that have no integrity bits. The output has integrity calculated
  //    for it.
  // 2. Select between the ISPRs that have integrity bits and the result of the first stage.

  // IDs fpr ISPRs with integrity
  localparam int IsprModIntg        = 0;
  localparam int IsprAccIntg        = 1;
  generate
    if (OtbnPQCEn) begin : gen_ispr_ids_pqc
      localparam int IsprKmacMsgIntg    = 2;
      localparam int IsprKmacDigestIntg = 3;
      localparam int IsprAccHIntg       = 4;
    end
  endgenerate

  // ID representing all ISPRs with no integrity
  localparam int IsprNoIntg = OtbnPQCEn ? 5 : 2;
  // Number of ISPRs that have integrity protection
  localparam int NIntgIspr  = OtbnPQCEn ? 5 : 2;

  logic [NIntgIspr:0] ispr_rdata_intg_mux_sel;
  logic [ExtWLEN-1:0] ispr_rdata_intg_mux_in    [NIntgIspr+1];
  logic [WLEN-1:0]    ispr_rdata_no_intg_mux_in [NIspr];

  // First stage
  // MOD, ACC, KMAC_MSG and KMAC_DIGEST supply their own integrity so these values are unused
  assign ispr_rdata_no_intg_mux_in[IsprMod]         = 0;
  assign ispr_rdata_no_intg_mux_in[IsprAcc]         = 0;
  generate
    if (OtbnPQCEn) begin : gen_ispr_no_intg_mux_pqc
      assign ispr_rdata_no_intg_mux_in[IsprKmacMsg] = 0;

      assign ispr_rdata_no_intg_mux_in[IsprKmacCfg] =
          {224'b0, gen_pqc_wsr.kmac_cfg_intg_q[31:0]};

      assign ispr_rdata_no_intg_mux_in[IsprKmacStatus] =
          {224'b0, gen_pqc_wsr.kmac_status_intg_q[31:0]};

      assign ispr_rdata_no_intg_mux_in[IsprKmacDigest] = 0;
      assign ispr_rdata_no_intg_mux_in[IsprAccH]       = 0;
    end
  endgenerate

  assign ispr_rdata_no_intg_mux_in[IsprRnd]    = rnd_data_i;
  assign ispr_rdata_no_intg_mux_in[IsprUrnd]   = urnd_data_i;
  assign ispr_rdata_no_intg_mux_in[IsprFlags]  = {{(WLEN - (NFlagGroups * FlagsWidth)){1'b0}},
                                                flags_flattened};
  // SEC_CM: KEY.SIDELOAD
  assign ispr_rdata_no_intg_mux_in[IsprKeyS0L] = sideload_key_shares_i[0][255:0];
  assign ispr_rdata_no_intg_mux_in[IsprKeyS0H] = {{(WLEN - (SideloadKeyWidth - 256)){1'b0}},
                                                 sideload_key_shares_i[0][SideloadKeyWidth-1:256]};
  assign ispr_rdata_no_intg_mux_in[IsprKeyS1L] = sideload_key_shares_i[1][255:0];
  assign ispr_rdata_no_intg_mux_in[IsprKeyS1H] = {{(WLEN - (SideloadKeyWidth - 256)){1'b0}},
                                                 sideload_key_shares_i[1][SideloadKeyWidth-1:256]};

  logic [WLEN-1:0]    ispr_rdata_no_intg;
  logic [ExtWLEN-1:0] ispr_rdata_intg_calc;

  // SEC_CM: DATA_REG_SW.SCA
  prim_onehot_mux #(
    .Width  (WLEN),
    .Inputs (NIspr)
  ) u_ispr_rdata_no_intg_mux (
    .clk_i,
    .rst_ni,
    .in_i  (ispr_rdata_no_intg_mux_in),
    .sel_i (ispr_predec_bignum_i.ispr_rd_en),
    .out_o (ispr_rdata_no_intg)
  );

  for (genvar i_word = 0; i_word < BaseWordsPerWLEN; i_word++) begin : g_rdata_enc
    prim_secded_inv_39_32_enc i_secded_enc (
      .data_i(ispr_rdata_no_intg[i_word * 32 +: 32]),
      .data_o(ispr_rdata_intg_calc[i_word * 39 +: 39])
    );
  end

  // Second stage
  assign ispr_rdata_intg_mux_in[IsprModIntg]        = mod_intg_q;
  assign ispr_rdata_intg_mux_in[IsprAccIntg]        = ispr_acc_intg_i;
  assign ispr_rdata_intg_mux_in[IsprNoIntg]         = ispr_rdata_intg_calc;

  generate
    if (OtbnPQCEn) begin : gen_ispr_intg_mux_pqc
      assign ispr_rdata_intg_mux_in[gen_ispr_ids_pqc.IsprKmacMsgIntg]    =
          gen_pqc_wsr.kmac_msg_intg_q;
      assign ispr_rdata_intg_mux_in[gen_ispr_ids_pqc.IsprKmacDigestIntg] =
          gen_pqc_wsr.kmac_digest_intg_q;
      assign ispr_rdata_intg_mux_in[gen_ispr_ids_pqc.IsprAccHIntg]       = ispr_acch_intg_i;
    end
  endgenerate

  assign ispr_rdata_intg_mux_sel[IsprModIntg]         = ispr_predec_bignum_i.ispr_rd_en[IsprMod];
  assign ispr_rdata_intg_mux_sel[IsprAccIntg]         = ispr_predec_bignum_i.ispr_rd_en[IsprAcc];

  generate
    if (OtbnPQCEn) begin : gen_ispr_intg_mux_sel_pqc
      assign ispr_rdata_intg_mux_sel[gen_ispr_ids_pqc.IsprKmacMsgIntg]    =
          ispr_predec_bignum_i.ispr_rd_en[IsprKmacMsg];
      assign ispr_rdata_intg_mux_sel[gen_ispr_ids_pqc.IsprKmacDigestIntg] =
          ispr_predec_bignum_i.ispr_rd_en[IsprKmacDigest];
      assign ispr_rdata_intg_mux_sel[gen_ispr_ids_pqc.IsprAccHIntg]       =
          ispr_predec_bignum_i.ispr_rd_en[IsprAccH];
    end
  endgenerate

  generate
    if (OtbnPQCEn) begin : gen_ispr_intg_mux_sel_cat_pqc
      assign ispr_rdata_intg_mux_sel[IsprNoIntg]  =
        |{ispr_predec_bignum_i.ispr_rd_en[IsprKeyS1H:IsprKeyS0L],
          ispr_predec_bignum_i.ispr_rd_en[IsprUrnd],
          ispr_predec_bignum_i.ispr_rd_en[IsprFlags],
          ispr_predec_bignum_i.ispr_rd_en[IsprRnd],
          ispr_predec_bignum_i.ispr_rd_en[IsprKmacCfg],
          ispr_predec_bignum_i.ispr_rd_en[IsprKmacPartialW],
          ispr_predec_bignum_i.ispr_rd_en[IsprKmacStatus]};
    end else begin : gen_ispr_intg_mux_sel_cat
      assign ispr_rdata_intg_mux_sel[IsprNoIntg]  =
        |{ispr_predec_bignum_i.ispr_rd_en[IsprKeyS1H:IsprKeyS0L],
          ispr_predec_bignum_i.ispr_rd_en[IsprUrnd],
          ispr_predec_bignum_i.ispr_rd_en[IsprFlags],
          ispr_predec_bignum_i.ispr_rd_en[IsprRnd]};
    end
  endgenerate

  // If we're reading from an ISPR we must be using the ispr_rdata_intg_mux
  `ASSERT(IsprRDataIntgMuxSelIfIsprRd_A,
    |ispr_predec_bignum_i.ispr_rd_en |-> |ispr_rdata_intg_mux_sel)

  // If we're reading from MOD or ACC we must not take the read data from the calculated integrity
  // path
  `ASSERT(IsprModMustTakeIntg_A,
    ispr_predec_bignum_i.ispr_rd_en[IsprMod] |-> !ispr_rdata_intg_mux_sel[IsprNoIntg])

  `ASSERT(IsprAccMustTakeIntg_A,
    ispr_predec_bignum_i.ispr_rd_en[IsprAcc] |-> !ispr_rdata_intg_mux_sel[IsprNoIntg])

  generate
    if (OtbnPQCEn) begin : gen_acch_intg_assert
      `ASSERT(IsprAccHMustTakeIntg_A,
        ispr_predec_bignum_i.ispr_rd_en[IsprAccH] |-> !ispr_rdata_intg_mux_sel[IsprNoIntg])
    end
  endgenerate

  prim_onehot_mux #(
    .Width  (ExtWLEN),
    .Inputs (NIntgIspr+1)
  ) u_ispr_rdata_intg_mux (
    .clk_i,
    .rst_ni,
    .in_i  (ispr_rdata_intg_mux_in),
    .sel_i (ispr_rdata_intg_mux_sel),
    .out_o (ispr_rdata_intg_o)
  );

  prim_onehot_enc #(
    .OneHotWidth (NIspr)
  ) u_expected_ispr_rd_en_enc (
    .in_i(ispr_addr_i),
    .en_i (ispr_rd_en_i),
    .out_o (expected_ispr_rd_en_onehot)
  );

  assign ispr_wr_en = |{ispr_bignum_wr_en_i, ispr_base_wr_en_i};

  prim_onehot_enc #(
    .OneHotWidth (NIspr)
  ) u_expected_ispr_wr_en_enc (
    .in_i(ispr_addr_i),
    .en_i (ispr_wr_en),
    .out_o (expected_ispr_wr_en_onehot)
  );

  // SEC_CM: CTRL.REDUN
  assign ispr_predec_error_o =
    |{expected_ispr_rd_en_onehot != ispr_predec_bignum_i.ispr_rd_en,
      expected_ispr_wr_en_onehot != ispr_predec_bignum_i.ispr_wr_en};

  /////////////
  // Shifter //
  /////////////

  logic [WLEN-1:0]   shifter_operand_a_blanked;
  logic [WLEN-1:0]   shifter_operand_b_blanked;
  logic [WLEN-1:0]   shifter_res, unused_shifter_out_upper;

  // SEC_CM: DATA_REG_SW.SCA
  prim_blanker #(.Width(WLEN)) u_shifter_operand_a_blanker (
    .in_i (operation_i.operand_a),
    .en_i (alu_predec_bignum_i.shifter_a_en),
    .out_o(shifter_operand_a_blanked)
  );

  // SEC_CM: DATA_REG_SW.SCA
  prim_blanker #(.Width(WLEN)) u_shifter_operand_b_blanker (
    .in_i (operation_i.operand_b),
    .en_i (alu_predec_bignum_i.shifter_b_en),
    .out_o(shifter_operand_b_blanked)
  );

generate
  if (OtbnPQCEn) begin : gen_shifter_pqc
    logic [WLEN-1:0]   shifter_bignum_in_upper, shifter_bignum_in_lower;
    logic [WLEN-1:0]   shifter_bignum_in_lower_reverse;
    logic [WLEN*2-1:0] shifter_bignum_in;
    logic [WLEN*2-1:0] shifter_bignum_out;
    logic [WLEN-1:0]   shifter_bignum_out_lower_reverse;
    logic [WLEN-1:0]   shifter_bignum_res;
    logic [15:0]       shifter_vec_in [17];
    logic [15:0]       shifter_vec_in_orig [16];
    logic [15:0]       shifter_vec_in_reverse [16];
    logic [15:0]       shifter_vec_out [16];
    logic [31:0]       shifter_vec_tmp [16];
    logic [31:0]       shifter_vec_tmp_shifted [16];
    logic [15:0]       shifter_vec_out_reverse [16];
    logic [WLEN-1:0]   shifter_vec_res;
    logic              shifter_selvector_i;

    // BIGNUM SHIFTER
    // Operand A is only used for BN.RSHI, otherwise the upper input is 0. For all insns other
    // than BN.RHSI alu_predec_bignum_i.shifter_a_en will be 0, resulting in 0 for the upper input.
    assign shifter_bignum_in_upper = shifter_operand_a_blanked;
    assign shifter_bignum_in_lower = shifter_operand_b_blanked;

    for (genvar i = 0; i < WLEN; i++) begin : g_shifter_bignum_in_lower_reverse
      assign shifter_bignum_in_lower_reverse[i] = shifter_bignum_in_lower[WLEN-i-1];
    end

    assign shifter_bignum_in = {shifter_bignum_in_upper,
        alu_predec_bignum_i.shift_right ? shifter_bignum_in_lower
                                        : shifter_bignum_in_lower_reverse};

    assign shifter_bignum_out = shifter_bignum_in >> alu_predec_bignum_i.shift_amt;

      for (genvar i = 0; i < WLEN; i++) begin : g_shifter_bignum_out_lower_reverse
        assign shifter_bignum_out_lower_reverse[i] = shifter_bignum_out[WLEN-i-1];
      end

      assign shifter_bignum_res =
          alu_predec_bignum_i.shift_right ? shifter_bignum_out[WLEN-1:0]
                                          : shifter_bignum_out_lower_reverse;

      // VECTOR SHIFTER
      assign shifter_selvector_i = operation_i.vector_type[0];
      assign shifter_vec_in[16] = '0;
      // split into 16-bit chunks for vectorized shift
      for (genvar i=0; i<16; ++i) begin : g_shifter_vec
        assign shifter_vec_in_orig[i] = shifter_operand_b_blanked[i*16+:16];
        for (genvar j=0; j<WLEN/16; ++j) begin : g_shifter_vec_reverse_input
          assign shifter_vec_in_reverse[i][j] = shifter_vec_in_orig[i][WLEN/16-j-1];
        end
        assign shifter_vec_in[i] =
            alu_predec_bignum_i.shift_right ? shifter_vec_in_orig[i] : shifter_selvector_i ?
                shifter_vec_in_reverse[i] : (i % 2 == 1) ?
                    shifter_vec_in_reverse[i-1] : shifter_vec_in_reverse[i+1];

        // Shifter below either shifts as 16 or 32 bit vectors
        assign shifter_vec_tmp[i] = {shifter_vec_in[i+1], shifter_vec_in[i]};
        assign shifter_vec_tmp_shifted[i] = shifter_vec_tmp[i] >> alu_predec_bignum_i.shift_amt;
        assign shifter_vec_out[i] =
            (shifter_selvector_i | (i % 2 == 1)) ?
            (shifter_vec_in[i] >> alu_predec_bignum_i.shift_amt) :
            shifter_vec_tmp_shifted[i][15:0];

        for (genvar j=0; j<WLEN/16; ++j) begin : g_shifter_vec_reverse_output
          assign shifter_vec_out_reverse[i][j] =
              shifter_selvector_i ? shifter_vec_out[i][WLEN/16-j-1] : (i % 2 == 1) ?
                  shifter_vec_out[i-1][WLEN/16-j-1] : shifter_vec_out[i+1][WLEN/16-j-1];
        end
        assign shifter_vec_res[i*16+:16] =
            alu_predec_bignum_i.shift_right ? shifter_vec_out[i] : shifter_vec_out_reverse[i];
      end

      // SHIFTER RESULT
      assign shifter_res = (operation_i.op == otbn_pkg::AluOpBignumShv) ? shifter_vec_res
                                                                        : shifter_bignum_res;

      // Only the lower WLEN bits of the shift result are returned.
      assign unused_shifter_out_upper = shifter_bignum_out[WLEN*2-1:WLEN];

    end else begin : gen_shifter
      logic [WLEN-1:0]   shifter_in_upper, shifter_in_lower, shifter_in_lower_reverse;
      logic [WLEN*2-1:0] shifter_in;
      logic [WLEN*2-1:0] shifter_out;
      logic [WLEN-1:0]   shifter_out_lower_reverse;

      // BIGNUM SHIFTER
      // Operand A is only used for BN.RSHI, otherwise the upper input is 0. For all instructions other
      // than BN.RHSI alu_predec_bignum_i.shifter_a_en will be 0, resulting in 0 for the upper input.
      assign shifter_in_upper = shifter_operand_a_blanked;
      assign shifter_in_lower = shifter_operand_b_blanked;

      for (genvar i = 0; i < WLEN; i++) begin : g_shifter_in_lower_reverse
        assign shifter_in_lower_reverse[i] = shifter_in_lower[WLEN-i-1];
      end

      assign shifter_in = {shifter_in_upper,
          alu_predec_bignum_i.shift_right ? shifter_in_lower : shifter_in_lower_reverse};

      assign shifter_out = shifter_in >> alu_predec_bignum_i.shift_amt;

      for (genvar i = 0; i < WLEN; i++) begin : g_shifter_out_lower_reverse
        assign shifter_out_lower_reverse[i] = shifter_out[WLEN-i-1];
      end

      assign shifter_res =
          alu_predec_bignum_i.shift_right ? shifter_out[WLEN-1:0] : shifter_out_lower_reverse;

      // Only the lower WLEN bits of the shift result are returned.
      assign unused_shifter_out_upper = shifter_out[WLEN*2-1:WLEN];

    end
  endgenerate

  ///////////////
  // Transpose //
  ///////////////
  generate
    if (OtbnPQCEn) begin : gen_trn_pqc
      logic [WLEN/16-1:0] trn_op0_16h [16];
      logic [WLEN/8-1:0]  trn_op0_8s  [8];
      logic [WLEN/4-1:0]  trn_op0_4d  [4];
      logic [WLEN/2-1:0]  trn_op0_2q  [2];

      logic [WLEN/16-1:0] trn_op1_16h [16];
      logic [WLEN/8-1:0]  trn_op1_8s  [8];
      logic [WLEN/4-1:0]  trn_op1_4d  [4];
      logic [WLEN/2-1:0]  trn_op1_2q  [2];

      logic [WLEN-1:0]    trn_res;

      for (genvar i=0; i<16; ++i) begin : g_trn_16h
        assign trn_op0_16h[i] = operation_i.operand_a[i*16+:16];
        assign trn_op1_16h[i] = operation_i.operand_b[i*16+:16];
      end

      for (genvar i=0; i<8; ++i) begin : g_trn_8s
        assign trn_op0_8s[i] = operation_i.operand_a[i*32+:32];
        assign trn_op1_8s[i] = operation_i.operand_b[i*32+:32];
      end

      for (genvar i=0; i<4; ++i) begin : g_trn_4d
        assign trn_op0_4d[i] = operation_i.operand_a[i*64+:64];
        assign trn_op1_4d[i] = operation_i.operand_b[i*64+:64];
      end

      for (genvar i=0; i<2; ++i) begin : g_trn_2q
        assign trn_op0_2q[i] = operation_i.operand_a[i*128+:128];
        assign trn_op1_2q[i] = operation_i.operand_b[i*128+:128];
      end

      always_comb begin
        case (operation_i.trn_type)
          trn1_16h: begin
            for (int i=0; i<8; ++i) begin
              trn_res[i*32+:32] = {trn_op1_16h[2*i],trn_op0_16h[2*i]};
            end
          end

          trn1_8s: begin
            for (int i=0; i<4; ++i) begin
              trn_res[i*64+:64] = {trn_op1_8s[2*i],trn_op0_8s[2*i]};
            end
          end

          trn1_4d: begin
            for (int i=0; i<2; ++i) begin
              trn_res[i*128+:128] = {trn_op1_4d[2*i],trn_op0_4d[2*i]};
            end
          end

          trn1_2q: begin
            for (int i=0; i<1; ++i) begin
              trn_res[i*256+:256] = {trn_op1_2q[2*i],trn_op0_2q[2*i]};
            end
          end

          trn2_16h: begin
            for (int i=0; i<8; ++i) begin
              trn_res[i*32+:32] = {trn_op1_16h[2*i+1],trn_op0_16h[2*i+1]};
            end
          end

          trn2_8s: begin
            for (int i=0; i<4; ++i) begin
              trn_res[i*64+:64] = {trn_op1_8s[2*i+1],trn_op0_8s[2*i+1]};
            end
          end

          trn2_4d: begin
            for (int i=0; i<2; ++i) begin
              trn_res[i*128+:128] = {trn_op1_4d[2*i+1],trn_op0_4d[2*i+1]};
            end
          end

          trn2_2q: begin
            for (int i=0; i<1; ++i) begin
              trn_res[i*256+:256] = {trn_op1_2q[2*i+1],trn_op0_2q[2*i+1]};
            end
          end

          default: begin
            for (int i=0; i<8; ++i) begin
              trn_res[i*32+:32] = {trn_op1_16h[2*i],trn_op0_16h[2*i]};
            end
          end
        endcase
      end
    end
  endgenerate

  //////////////////
  // Adders X & Y //
  //////////////////

  // The LSB of the adder results are unused.
  logic unused_adder_x_res_lsb, unused_adder_y_res_lsb;

  // Shared adder control signals
  logic            adder_x_carry_in;
  logic            adder_x_op_b_invert;
  logic            adder_y_carry_in;
  logic            adder_y_op_b_invert;
  logic [WLEN-1:0] adder_y_op_a_blanked;
  logic [WLEN-1:0] adder_y_op_shifter_res_blanked;

  logic [WLEN-1:0] shift_mod_mux_out;
  logic [WLEN-1:0] x_res_operand_a_mux_out;

  generate
    if (OtbnPQCEn) begin : gen_adder_pqc
      // ADDER X logic
      logic [WLEN-1:0] adder_x_op_a_blanked, adder_x_op_b, adder_x_op_b_blanked;
      logic [WLEN-1:0] adder_x_res;
      logic [15:0]     adder_x_carry_out;

      // ADDER Y logic
      logic [WLEN-1:0]  adder_y_op_a, adder_y_op_b;

      vec_type_e mode;
      assign mode = operation_i.vector_sel ?
                    (operation_i.vector_type[0] == 1'b0 ? VecType_s32 : VecType_h16) :
                    VecType_v256;

      // SEC_CM: DATA_REG_SW.SCA
      prim_blanker #(.Width(WLEN)) u_adder_x_op_a_blanked (
        .in_i (operation_i.operand_a),
        .en_i (alu_predec_bignum_i.adder_x_en),
        .out_o(adder_x_op_a_blanked)
      );

      assign adder_x_op_b = adder_x_op_b_invert ? ~operation_i.operand_b : operation_i.operand_b;

      // SEC_CM: DATA_REG_SW.SCA
      prim_blanker #(.Width(WLEN)) u_adder_x_op_b_blanked (
        .in_i (adder_x_op_b),
        .en_i (alu_predec_bignum_i.adder_x_en),
        .out_o(adder_x_op_b_blanked)
      );

      buffer_bit adder_x (
        .A        (adder_x_op_a_blanked),
        .B        (adder_x_op_b_blanked),
        .word_mode(mode),
        .cin      (adder_x_carry_in),
        .res      (adder_x_res),
        .cout     (adder_x_carry_out)
      );

      // SEC_CM: DATA_REG_SW.SCA
      prim_blanker #(.Width(WLEN)) u_adder_y_op_a_blanked (
        .in_i (operation_i.operand_a),
        .en_i (alu_predec_bignum_i.adder_y_op_a_en),
        .out_o(adder_y_op_a_blanked)
      );

      assign x_res_operand_a_mux_out =
          alu_predec_bignum_i.x_res_operand_a_sel ? adder_x_res : adder_y_op_a_blanked;

      // SEC_CM: DATA_REG_SW.SCA
      prim_blanker #(.Width(WLEN)) u_adder_y_op_shifter_blanked (
        .in_i (shifter_res),
        .en_i (alu_predec_bignum_i.adder_y_op_shifter_en),
        .out_o(adder_y_op_shifter_res_blanked)
      );

      assign shift_mod_mux_out =
          alu_predec_bignum_i.shift_mod_sel ? adder_y_op_shifter_res_blanked :
          (mode == VecType_h16) ? {16 {mod_no_intg_q[15:0]}} :
          (mode == VecType_s32) ? { 8 {mod_no_intg_q[31:0]}} :
          mod_no_intg_q;

      assign adder_y_op_a = x_res_operand_a_mux_out;
      assign adder_y_op_b = adder_y_op_b_invert ? ~shift_mod_mux_out : shift_mod_mux_out;

      buffer_bit adder_y (
        .A        (adder_y_op_a),
        .B        (adder_y_op_b),
        .word_mode(mode),
        .cin      (adder_y_carry_in),
        .res      (adder_y_res),
        .cout     (gen_adder_y_res_pqc.adder_y_carry_out)
      );

      assign unused_adder_x_res_lsb = adder_x_res[0];
      assign unused_adder_y_res_lsb = adder_y_res[0];

    end else begin : gen_adder
      logic [WLEN:0]   adder_x_op_a_blanked, adder_x_op_b, adder_x_op_b_blanked;
      logic [WLEN+1:0] adder_x_res;

      logic [WLEN:0]   adder_y_op_a, adder_y_op_b;

      // SEC_CM: DATA_REG_SW.SCA
      prim_blanker #(.Width(WLEN+1)) u_adder_x_op_a_blanked (
        .in_i ({operation_i.operand_a, 1'b1}),
        .en_i (alu_predec_bignum_i.adder_x_en),
        .out_o(adder_x_op_a_blanked)
      );

      assign adder_x_op_b = {adder_x_op_b_invert ? ~operation_i.operand_b : operation_i.operand_b,
                            adder_x_carry_in};

      // SEC_CM: DATA_REG_SW.SCA
      prim_blanker #(.Width(WLEN+1)) u_adder_x_op_b_blanked (
        .in_i (adder_x_op_b),
        .en_i (alu_predec_bignum_i.adder_x_en),
        .out_o(adder_x_op_b_blanked)
      );

      assign adder_x_res = adder_x_op_a_blanked + adder_x_op_b_blanked;

      // SEC_CM: DATA_REG_SW.SCA
      prim_blanker #(.Width(WLEN)) u_adder_y_op_a_blanked (
        .in_i (operation_i.operand_a),
        .en_i (alu_predec_bignum_i.adder_y_op_a_en),
        .out_o(adder_y_op_a_blanked)
      );

      assign x_res_operand_a_mux_out =
          alu_predec_bignum_i.x_res_operand_a_sel ? adder_x_res[WLEN:1] : adder_y_op_a_blanked;

      // SEC_CM: DATA_REG_SW.SCA
      prim_blanker #(.Width(WLEN)) u_adder_y_op_shifter_blanked (
        .in_i (shifter_res),
        .en_i (alu_predec_bignum_i.adder_y_op_shifter_en),
        .out_o(adder_y_op_shifter_res_blanked)
      );

      assign shift_mod_mux_out =
          alu_predec_bignum_i.shift_mod_sel ? adder_y_op_shifter_res_blanked : mod_no_intg_q;

      assign adder_y_op_a = {x_res_operand_a_mux_out, 1'b1};
      assign adder_y_op_b = {adder_y_op_b_invert ? ~shift_mod_mux_out : shift_mod_mux_out,
                            adder_y_carry_in};

      assign adder_y_res = adder_y_op_a + adder_y_op_b;

      assign unused_adder_x_res_lsb = adder_x_res[0];
      assign unused_adder_y_res_lsb = adder_y_res[0];
    end
  endgenerate

  //////////////////////////////
  // Shifter & Adders control //
  //////////////////////////////
  logic expected_adder_x_en;
  logic expected_x_res_operand_a_sel;
  logic expected_adder_y_op_a_en;
  logic expected_adder_y_op_shifter_en;
  logic expected_shifter_a_en;
  logic expected_shifter_b_en;
  logic expected_shift_right;
  logic expected_shift_mod_sel;
  logic expected_logic_a_en;
  logic expected_logic_shifter_en;
  logic [3:0] expected_logic_res_sel;

  generate
    if (OtbnPQCEn) begin : gen_shift_add_ctrl_pqc
      alu_vector_type_t expected_vector_type;
      alu_trn_type_t    expected_trn_type;
      logic             expected_vector_sel;

      always_comb begin
        adder_x_carry_in          = 1'b0;
        adder_x_op_b_invert       = 1'b0;
        adder_y_carry_in          = 1'b0;
        adder_y_op_b_invert       = 1'b0;
        adder_update_flags_en_raw = 1'b0;
        logic_update_flags_en_raw = 1'b0;

        expected_vector_type            = alu_8s;
        expected_trn_type               = alu_trn_type_t'('0);
        expected_vector_sel             = 1'b0;
        expected_adder_x_en             = 1'b0;
        expected_x_res_operand_a_sel    = 1'b0;
        expected_adder_y_op_a_en        = 1'b0;
        expected_adder_y_op_shifter_en  = 1'b0;
        expected_shifter_a_en           = 1'b0;
        expected_shifter_b_en           = 1'b0;
        expected_shift_right            = 1'b0;
        expected_shift_mod_sel          = 1'b1;
        expected_logic_a_en             = 1'b0;
        expected_logic_shifter_en       = 1'b0;
        expected_logic_res_sel          = '0;

        unique case (operation_i.op)
          AluOpBignumAdd: begin
            // Shifter computes B [>>|<<] shift_amt
            // Y computes A + shifter_res
            // X ignored
            adder_y_carry_in               = 1'b0;
            adder_y_op_b_invert            = 1'b0;
            adder_update_flags_en_raw      = 1'b1;
            expected_adder_y_op_shifter_en = 1'b1;

            expected_adder_y_op_a_en = 1'b1;
            expected_shifter_b_en    = 1'b1;
            expected_shift_right     = operation_i.shift_right;
          end
          AluOpBignumAddc: begin
            // Shifter computes B [>>|<<] shift_amt
            // Y computes A + shifter_res + flags.C
            // X ignored
            adder_y_carry_in               = selected_flags.C;
            adder_y_op_b_invert            = 1'b0;
            adder_update_flags_en_raw      = 1'b1;
            expected_adder_y_op_shifter_en = 1'b1;

            expected_adder_y_op_a_en = 1'b1;
            expected_shifter_b_en    = 1'b1;
            expected_shift_right     = operation_i.shift_right;
          end
          AluOpBignumAddm: begin
            // X computes A + B
            // Y computes adder_x_res - mod = adder_x_res + ~mod + 1
            // Shifter ignored
            // Output mux chooses result based on top bit of X result (whether mod subtraction in
            // Y should be applied or not)
            adder_x_carry_in    = 1'b0;
            adder_x_op_b_invert = 1'b0;
            adder_y_carry_in    = 1'b1;
            adder_y_op_b_invert = 1'b1;

            expected_adder_x_en          = 1'b1;
            expected_x_res_operand_a_sel = 1'b1;
            expected_shift_mod_sel       = 1'b0;
          end
          AluOpBignumAddv: begin
            // X computes A + B
            // Y computes adder_x_res - mod = adder_x_res + ~mod + 1
            // Shifter ignored
            // Output mux chooses result based on top bit of X result (whether mod subtraction in
            // Y should be applied or not)
            adder_x_carry_in    = 1'b0;
            adder_x_op_b_invert = 1'b0;

            expected_adder_x_en          = 1'b1;
            expected_x_res_operand_a_sel = 1'b1;
            expected_shift_mod_sel       = 1'b0;
            expected_vector_type         = operation_i.vector_type;
            expected_vector_sel          = operation_i.vector_sel;
          end
          AluOpBignumAddvm: begin
            // X computes A + B
            // Y computes adder_x_res - mod = adder_x_res + ~mod + 1
            // Shifter ignored
            // Output mux chooses result based on top bit of X result (whether mod subtraction in
            // Y should be applied or not)
            adder_x_carry_in    = 1'b0;
            adder_x_op_b_invert = 1'b0;
            adder_y_carry_in    = 1'b1;
            adder_y_op_b_invert = 1'b1;

            expected_adder_x_en          = 1'b1;
            expected_x_res_operand_a_sel = 1'b1;
            expected_shift_mod_sel       = 1'b0;
            expected_vector_type         = operation_i.vector_type;
            expected_vector_sel          = operation_i.vector_sel;
          end
          AluOpBignumSub: begin
            // Shifter computes B [>>|<<] shift_amt
            // Y computes A - shifter_res = A + ~shifter_res + 1
            // X ignored
            adder_y_carry_in               = 1'b1;
            adder_y_op_b_invert            = 1'b1;
            adder_update_flags_en_raw      = 1'b1;
            expected_adder_y_op_shifter_en = 1'b1;

            expected_adder_y_op_a_en = 1'b1;
            expected_shifter_b_en    = 1'b1;
            expected_shift_right     = operation_i.shift_right;
          end
          AluOpBignumSubb: begin
            // Shifter computes B [>>|<<] shift_amt
            // Y computes A - shifter_res + ~flags.C = A + ~shifter_res + flags.C
            // X ignored
            adder_y_carry_in               = ~selected_flags.C;
            adder_y_op_b_invert            = 1'b1;
            adder_update_flags_en_raw      = 1'b1;
            expected_adder_y_op_shifter_en = 1'b1;

            expected_adder_y_op_a_en = 1'b1;
            expected_shifter_b_en    = 1'b1;
            expected_shift_right     = operation_i.shift_right;
          end
          AluOpBignumSubm: begin
            // X computes A - B = A + ~B + 1
            // Y computes adder_x_res + mod
            // Shifter ignored
            // Output mux chooses result based on top bit of X result (whether subtraction in Y should
            // be applied or not)
            adder_x_carry_in    = 1'b1;
            adder_x_op_b_invert = 1'b1;
            adder_y_carry_in    = 1'b0;
            adder_y_op_b_invert = 1'b0;

            expected_adder_x_en          = 1'b1;
            expected_x_res_operand_a_sel = 1'b1;
            expected_shift_mod_sel       = 1'b0;
          end
          AluOpBignumSubv: begin
            // X computes A - B = A + ~B + 1
            // Y computes adder_x_res + mod
            // Shifter ignored
            // Output mux chooses result based on top bit of X result (whether subtraction in Y should
            // be applied or not)
            adder_x_carry_in    = 1'b1;
            adder_x_op_b_invert = 1'b1;

            expected_adder_x_en          = 1'b1;
            expected_x_res_operand_a_sel = 1'b1;
            expected_shift_mod_sel       = 1'b0;
            expected_vector_type         = operation_i.vector_type;
            expected_vector_sel          = operation_i.vector_sel;
          end
          AluOpBignumSubvm: begin
            // X computes A - B = A + ~B + 1
            // Y computes adder_x_res + mod
            // Shifter ignored
            // Output mux chooses result based on top bit of X result (whether subtraction in Y should
            // be applied or not)
            adder_x_carry_in    = 1'b1;
            adder_x_op_b_invert = 1'b1;
            adder_y_carry_in    = 1'b0;
            adder_y_op_b_invert = 1'b0;

            expected_adder_x_en          = 1'b1;
            expected_x_res_operand_a_sel = 1'b1;
            expected_shift_mod_sel       = 1'b0;
            expected_vector_type         = operation_i.vector_type;
            expected_vector_sel          = operation_i.vector_sel;
          end
          AluOpBignumRshi: begin
            // Shifter computes {A, B} >> shift_amt
            // X, Y ignored
            // Feed blanked shifter output (adder_y_op_shifter_res_blanked) to Y to avoid undesired
            // leakage in the zero flag computation.

            expected_shifter_a_en = 1'b1;
            expected_shifter_b_en = 1'b1;
            expected_shift_right  = 1'b1;
          end
          AluOpBignumXor,
          AluOpBignumOr,
          AluOpBignumAnd,
          AluOpBignumNot: begin
            // Shift computes one operand for the logical operation
            // X & Y ignored
            // Feed blanked shifter output (adder_y_op_shifter_res_blanked) to Y to avoid undesired
            // leakage in the zero flag computation.
            logic_update_flags_en_raw             = 1'b1;

            expected_shifter_b_en                 = 1'b1;
            expected_shift_right                  = operation_i.shift_right;
            expected_logic_a_en                   = operation_i.op != AluOpBignumNot;
            expected_logic_shifter_en             = 1'b1;
            expected_logic_res_sel[AluOpLogicXor] = operation_i.op == AluOpBignumXor;
            expected_logic_res_sel[AluOpLogicOr]  = operation_i.op == AluOpBignumOr;
            expected_logic_res_sel[AluOpLogicAnd] = operation_i.op == AluOpBignumAnd;
            expected_logic_res_sel[AluOpLogicNot] = operation_i.op == AluOpBignumNot;
          end
          AluOpBignumShv: begin
            expected_vector_type            = operation_i.vector_type;
            expected_vector_sel             = operation_i.vector_sel;
            expected_shifter_b_en           = 1'b1;
            expected_shift_right            = operation_i.shift_right;
            expected_logic_shifter_en       = 1'b1;
            expected_logic_res_sel          = '0;
          end
          AluOpBignumTrn: begin
            expected_trn_type = operation_i.trn_type;
          end
          // No operation, do nothing.
          AluOpBignumNone: ;
          default: ;
        endcase
      end
    end else begin : gen_shift_add_ctrl
      always_comb begin
        adder_x_carry_in          = 1'b0;
        adder_x_op_b_invert       = 1'b0;
        adder_y_carry_in          = 1'b0;
        adder_y_op_b_invert       = 1'b0;
        adder_update_flags_en_raw = 1'b0;
        logic_update_flags_en_raw = 1'b0;

        expected_adder_x_en             = 1'b0;
        expected_x_res_operand_a_sel    = 1'b0;
        expected_adder_y_op_a_en        = 1'b0;
        expected_adder_y_op_shifter_en  = 1'b0;
        expected_shifter_a_en           = 1'b0;
        expected_shifter_b_en           = 1'b0;
        expected_shift_right            = 1'b0;
        expected_shift_mod_sel          = 1'b1;
        expected_logic_a_en             = 1'b0;
        expected_logic_shifter_en       = 1'b0;
        expected_logic_res_sel          = '0;

        unique case (operation_i.op)
          AluOpBignumAdd: begin
            // Shifter computes B [>>|<<] shift_amt
            // Y computes A + shifter_res
            // X ignored
            adder_y_carry_in               = 1'b0;
            adder_y_op_b_invert            = 1'b0;
            adder_update_flags_en_raw      = 1'b1;
            expected_adder_y_op_shifter_en = 1'b1;

            expected_adder_y_op_a_en = 1'b1;
            expected_shifter_b_en    = 1'b1;
            expected_shift_right     = operation_i.shift_right;
          end
          AluOpBignumAddc: begin
            // Shifter computes B [>>|<<] shift_amt
            // Y computes A + shifter_res + flags.C
            // X ignored
            adder_y_carry_in               = selected_flags.C;
            adder_y_op_b_invert            = 1'b0;
            adder_update_flags_en_raw      = 1'b1;
            expected_adder_y_op_shifter_en = 1'b1;

            expected_adder_y_op_a_en = 1'b1;
            expected_shifter_b_en    = 1'b1;
            expected_shift_right     = operation_i.shift_right;
          end
          AluOpBignumAddm: begin
            // X computes A + B
            // Y computes adder_x_res - mod = adder_x_res + ~mod + 1
            // Shifter ignored
            // Output mux chooses result based on top bit of X result (whether mod subtraction in
            // Y should be applied or not)
            adder_x_carry_in    = 1'b0;
            adder_x_op_b_invert = 1'b0;
            adder_y_carry_in    = 1'b1;
            adder_y_op_b_invert = 1'b1;

            expected_adder_x_en          = 1'b1;
            expected_x_res_operand_a_sel = 1'b1;
            expected_shift_mod_sel       = 1'b0;
          end
          AluOpBignumSub: begin
            // Shifter computes B [>>|<<] shift_amt
            // Y computes A - shifter_res = A + ~shifter_res + 1
            // X ignored
            adder_y_carry_in               = 1'b1;
            adder_y_op_b_invert            = 1'b1;
            adder_update_flags_en_raw      = 1'b1;
            expected_adder_y_op_shifter_en = 1'b1;

            expected_adder_y_op_a_en = 1'b1;
            expected_shifter_b_en    = 1'b1;
            expected_shift_right     = operation_i.shift_right;
          end
          AluOpBignumSubb: begin
            // Shifter computes B [>>|<<] shift_amt
            // Y computes A - shifter_res + ~flags.C = A + ~shifter_res + flags.C
            // X ignored
            adder_y_carry_in               = ~selected_flags.C;
            adder_y_op_b_invert            = 1'b1;
            adder_update_flags_en_raw      = 1'b1;
            expected_adder_y_op_shifter_en = 1'b1;

            expected_adder_y_op_a_en = 1'b1;
            expected_shifter_b_en    = 1'b1;
            expected_shift_right     = operation_i.shift_right;
          end
          AluOpBignumSubm: begin
            // X computes A - B = A + ~B + 1
            // Y computes adder_x_res + mod
            // Shifter ignored
            // Output mux chooses result based on top bit of X result (whether subtraction in Y should
            // be applied or not)
            adder_x_carry_in    = 1'b1;
            adder_x_op_b_invert = 1'b1;
            adder_y_carry_in    = 1'b0;
            adder_y_op_b_invert = 1'b0;

            expected_adder_x_en          = 1'b1;
            expected_x_res_operand_a_sel = 1'b1;
            expected_shift_mod_sel       = 1'b0;
          end
          AluOpBignumRshi: begin
            // Shifter computes {A, B} >> shift_amt
            // X, Y ignored
            // Feed blanked shifter output (adder_y_op_shifter_res_blanked) to Y to avoid undesired
            // leakage in the zero flag computation.

            expected_shifter_a_en = 1'b1;
            expected_shifter_b_en = 1'b1;
            expected_shift_right  = 1'b1;
          end
          AluOpBignumXor,
          AluOpBignumOr,
          AluOpBignumAnd,
          AluOpBignumNot: begin
            // Shift computes one operand for the logical operation
            // X & Y ignored
            // Feed blanked shifter output (adder_y_op_shifter_res_blanked) to Y to avoid undesired
            // leakage in the zero flag computation.
            logic_update_flags_en_raw             = 1'b1;

            expected_shifter_b_en                 = 1'b1;
            expected_shift_right                  = operation_i.shift_right;
            expected_logic_a_en                   = operation_i.op != AluOpBignumNot;
            expected_logic_shifter_en             = 1'b1;
            expected_logic_res_sel[AluOpLogicXor] = operation_i.op == AluOpBignumXor;
            expected_logic_res_sel[AluOpLogicOr]  = operation_i.op == AluOpBignumOr;
            expected_logic_res_sel[AluOpLogicAnd] = operation_i.op == AluOpBignumAnd;
            expected_logic_res_sel[AluOpLogicNot] = operation_i.op == AluOpBignumNot;
          end
          // No operation, do nothing.
          AluOpBignumNone: ;
          default: ;
        endcase
      end
    end
  endgenerate

  logic [$clog2(WLEN)-1:0] expected_shift_amt;
  assign expected_shift_amt = operation_i.shift_amt;

  // SEC_CM: CTRL.REDUN
  generate
    if (OtbnPQCEn) begin : gen_alu_predec_error_pqc
      assign alu_predec_error_o =
        |{expected_adder_x_en != alu_predec_bignum_i.adder_x_en,
          expected_x_res_operand_a_sel != alu_predec_bignum_i.x_res_operand_a_sel,
          expected_adder_y_op_a_en != alu_predec_bignum_i.adder_y_op_a_en,
          expected_adder_y_op_shifter_en != alu_predec_bignum_i.adder_y_op_shifter_en,
          expected_shifter_a_en != alu_predec_bignum_i.shifter_a_en,
          expected_shifter_b_en != alu_predec_bignum_i.shifter_b_en,
          expected_shift_right != alu_predec_bignum_i.shift_right,
          gen_shift_add_ctrl_pqc.expected_vector_type != alu_predec_bignum_i.vector_type,
          gen_shift_add_ctrl_pqc.expected_trn_type != alu_predec_bignum_i.trn_type,
          gen_shift_add_ctrl_pqc.expected_vector_sel != alu_predec_bignum_i.vector_sel,
          expected_shift_amt != alu_predec_bignum_i.shift_amt,
          expected_shift_mod_sel != alu_predec_bignum_i.shift_mod_sel,
          expected_logic_a_en != alu_predec_bignum_i.logic_a_en,
          expected_logic_shifter_en != alu_predec_bignum_i.logic_shifter_en,
          expected_logic_res_sel != alu_predec_bignum_i.logic_res_sel,
          expected_flag_group_sel != alu_predec_bignum_i.flag_group_sel,
          expected_flag_sel != alu_predec_bignum_i.flag_sel,
          expected_flags_keep != alu_predec_bignum_i.flags_keep,
          expected_flags_adder_update != alu_predec_bignum_i.flags_adder_update,
          expected_flags_logic_update != alu_predec_bignum_i.flags_logic_update,
          expected_flags_mac_update != alu_predec_bignum_i.flags_mac_update,
          expected_flags_ispr_wr != alu_predec_bignum_i.flags_ispr_wr};
    end else begin : gen_alu_predec_error
      assign alu_predec_error_o =
        |{expected_adder_x_en != alu_predec_bignum_i.adder_x_en,
          expected_x_res_operand_a_sel != alu_predec_bignum_i.x_res_operand_a_sel,
          expected_adder_y_op_a_en != alu_predec_bignum_i.adder_y_op_a_en,
          expected_adder_y_op_shifter_en != alu_predec_bignum_i.adder_y_op_shifter_en,
          expected_shifter_a_en != alu_predec_bignum_i.shifter_a_en,
          expected_shifter_b_en != alu_predec_bignum_i.shifter_b_en,
          expected_shift_right != alu_predec_bignum_i.shift_right,
          expected_shift_amt != alu_predec_bignum_i.shift_amt,
          expected_shift_mod_sel != alu_predec_bignum_i.shift_mod_sel,
          expected_logic_a_en != alu_predec_bignum_i.logic_a_en,
          expected_logic_shifter_en != alu_predec_bignum_i.logic_shifter_en,
          expected_logic_res_sel != alu_predec_bignum_i.logic_res_sel,
          expected_flag_group_sel != alu_predec_bignum_i.flag_group_sel,
          expected_flag_sel != alu_predec_bignum_i.flag_sel,
          expected_flags_keep != alu_predec_bignum_i.flags_keep,
          expected_flags_adder_update != alu_predec_bignum_i.flags_adder_update,
          expected_flags_logic_update != alu_predec_bignum_i.flags_logic_update,
          expected_flags_mac_update != alu_predec_bignum_i.flags_mac_update,
          expected_flags_ispr_wr != alu_predec_bignum_i.flags_ispr_wr};
    end
  endgenerate

  ////////////////////////
  // Logical operations //
  ////////////////////////

  logic [WLEN-1:0] logical_res_mux_in [4];
  logic [WLEN-1:0] logical_op_a_blanked;
  logic [WLEN-1:0] logical_op_shifter_res_blanked;

  // SEC_CM: DATA_REG_SW.SCA
  prim_blanker #(.Width(WLEN)) u_logical_op_a_blanker (
    .in_i (operation_i.operand_a),
    .en_i (alu_predec_bignum_i.logic_a_en),
    .out_o(logical_op_a_blanked)
  );

  // SEC_CM: DATA_REG_SW.SCA
  prim_blanker #(.Width(WLEN)) u_logical_op_shifter_res_blanker (
    .in_i (shifter_res),
    .en_i (alu_predec_bignum_i.logic_shifter_en),
    .out_o(logical_op_shifter_res_blanked)
  );

  assign logical_res_mux_in[AluOpLogicXor] = logical_op_a_blanked ^ logical_op_shifter_res_blanked;
  assign logical_res_mux_in[AluOpLogicOr]  = logical_op_a_blanked | logical_op_shifter_res_blanked;
  assign logical_res_mux_in[AluOpLogicAnd] = logical_op_a_blanked & logical_op_shifter_res_blanked;
  assign logical_res_mux_in[AluOpLogicNot] = ~logical_op_shifter_res_blanked;

  // SEC_CM: DATA_REG_SW.SCA
  prim_onehot_mux #(
    .Width (WLEN),
    .Inputs(4)
  ) u_logical_res_mux (
    .clk_i,
    .rst_ni,
    .in_i  (logical_res_mux_in),
    .sel_i (alu_predec_bignum_i.logic_res_sel),
    .out_o (logical_res)
  );

  ////////////////////////
  // Output multiplexer //
  ////////////////////////

  logic adder_y_res_used;

  generate
    if (OtbnPQCEn) begin : gen_output_mux_pqc
      always_comb begin
        operation_result_o = adder_y_res;
        adder_y_res_used = 1'b1;
        unique case (operation_i.op)
          AluOpBignumAdd,
          AluOpBignumAddc,
          AluOpBignumSub,
          AluOpBignumSubb: begin
            operation_result_o = adder_y_res;
            adder_y_res_used = 1'b1;
          end

          // For pseudo-mod operations the result depends upon initial a + b / a - b result that is
          // computed in X. Operation to add/subtract mod (X + mod / X - mod) is computed in Y.
          // Subtraction is computed using in the X & Y adders as a - b == a + ~b + 1. Note that
          // for a - b the top bit of the result will be set if a - b >= 0 and otherwise clear.

          // BN.ADDM - X = a + b, Y = X - mod, subtract mod if a + b >= mod
          // * If X generates carry a + b > mod (as mod is 256-bit) - Select Y result
          // * If Y generates carry X - mod == (a + b) - mod >= 0 hence a + b >= mod, note this is
          // only valid if X does not generate carry - Select Y result
          // * If neither happen a + b < mod - Select X result
          AluOpBignumAddm: begin
            // `adder_y_res` is always used: either as condition in the following `if` statement
            // or, if the `if` statement short-circuits, in the body of the `if` statement.
            adder_y_res_used = 1'b1;
            if (gen_adder_pqc.adder_x_carry_out[15] || gen_adder_y_res_pqc.adder_y_carry_out[15])
            begin
              operation_result_o = adder_y_res;
            end else begin
              operation_result_o = gen_adder_pqc.adder_x_res;
            end
          end

          AluOpBignumAddv: begin
            operation_result_o = gen_adder_pqc.adder_x_res;
          end

          AluOpBignumAddvm: begin
            // `adder_y_res` is always used: either as condition in the following `if` statement
            // or, if the `if` statement short-circuits, in the body of the `if` statement.
            adder_y_res_used = 1'b1;

            for (int i = 0; i < 16; i += 2) begin
              operation_result_o[i*16 +: 16] = ((operation_i.vector_type[0]) ?
                (gen_adder_pqc.adder_x_carry_out[i] || gen_adder_y_res_pqc.adder_y_carry_out[i]) :
                (gen_adder_pqc.adder_x_carry_out[i + 1]
                || gen_adder_y_res_pqc.adder_y_carry_out[i + 1])) ?
                adder_y_res[i*16 +: 16] : gen_adder_pqc.adder_x_res[i*16 +: 16];
              operation_result_o[(i + 1)* 16 +: 16] =
                (gen_adder_pqc.adder_x_carry_out[i + 1]
                || gen_adder_y_res_pqc.adder_y_carry_out[i + 1]) ?
                adder_y_res[(i + 1)*16 +: 16] : gen_adder_pqc.adder_x_res[(i + 1)*16 +: 16];
            end
          end

          // BN.SUBM - X = a - b, Y = X + mod, add mod if a - b < 0
          // * If X generates carry a - b >= 0 - Select X result
          // * Otherwise select Y result
          AluOpBignumSubm: begin
            if (gen_adder_pqc.adder_x_carry_out[15]) begin
              operation_result_o = gen_adder_pqc.adder_x_res;
              adder_y_res_used = 1'b0;
            end else begin
              operation_result_o = adder_y_res;
              adder_y_res_used = 1'b1;
            end
          end

          AluOpBignumSubv: begin
            operation_result_o = gen_adder_pqc.adder_x_res;
          end
          AluOpBignumSubvm: begin
            adder_y_res_used = 1'b1;

            for (int i = 0; i < 16; i += 2) begin
              operation_result_o[i*16 +: 16] = ((operation_i.vector_type[0]) ?
                  gen_adder_pqc.adder_x_carry_out[i] : gen_adder_pqc.adder_x_carry_out[i + 1]) ?
                      gen_adder_pqc.adder_x_res[i*16 +: 16] : adder_y_res[i*16 +: 16];
              operation_result_o[(i + 1)* 16 +: 16] = gen_adder_pqc.adder_x_carry_out[i + 1] ?
                    gen_adder_pqc.adder_x_res[(i + 1)*16 +: 16] : adder_y_res[(i + 1)*16 +: 16];
            end
          end

          AluOpBignumRshi,AluOpBignumShv: begin
            operation_result_o = shifter_res[WLEN-1:0];
            adder_y_res_used = 1'b0;
          end

          AluOpBignumTrn: begin
            operation_result_o = gen_trn_pqc.trn_res;
            adder_y_res_used = 1'b0;
          end

          AluOpBignumXor,
          AluOpBignumOr,
          AluOpBignumAnd,
          AluOpBignumNot: begin
            operation_result_o = logical_res;
            adder_y_res_used = 1'b0;
          end
          default: ;
        endcase
      end
    end else begin : gen_output_mux
      always_comb begin
        operation_result_o = adder_y_res[WLEN:1];
        adder_y_res_used = 1'b1;
        unique case (operation_i.op)
          AluOpBignumAdd,
          AluOpBignumAddc,
          AluOpBignumSub,
          AluOpBignumSubb: begin
            operation_result_o = adder_y_res[WLEN:1];
            adder_y_res_used = 1'b1;
          end

          // For pseudo-mod operations the result depends upon initial a + b / a - b result that is
          // computed in X. Operation to add/subtract mod (X + mod / X - mod) is computed in Y.
          // Subtraction is computed using in the X & Y adders as a - b == a + ~b + 1. Note that
          // for a - b the top bit of the result will be set if a - b >= 0 and otherwise clear.

          // BN.ADDM - X = a + b, Y = X - mod, subtract mod if a + b >= mod
          // * If X generates carry a + b > mod (as mod is 256-bit) - Select Y result
          // * If Y generates carry X - mod == (a + b) - mod >= 0 hence a + b >= mod, note this is
          // only valid if X does not generate carry - Select Y result
          // * If neither happen a + b < mod - Select X result
          AluOpBignumAddm: begin
            // `adder_y_res` is always used: either as condition in the following `if` statement
            // or, if the `if` statement short-circuits, in the body of the `if` statement.
            adder_y_res_used = 1'b1;
            if (gen_adder.adder_x_res[WLEN+1] || adder_y_res[WLEN+1]) begin
              operation_result_o = adder_y_res[WLEN:1];
            end else begin
              operation_result_o = gen_adder.adder_x_res[WLEN:1];
            end
          end

          // BN.SUBM - X = a - b, Y = X + mod, add mod if a - b < 0
          // * If X generates carry a - b >= 0 - Select X result
          // * Otherwise select Y result
          AluOpBignumSubm: begin
            if (gen_adder.adder_x_res[WLEN+1]) begin
              operation_result_o = gen_adder.adder_x_res[WLEN:1];
              adder_y_res_used = 1'b0;
            end else begin
              operation_result_o = adder_y_res[WLEN:1];
              adder_y_res_used = 1'b1;
            end
          end

          AluOpBignumRshi: begin
            operation_result_o = shifter_res[WLEN-1:0];
            adder_y_res_used = 1'b0;
          end

          AluOpBignumXor,
          AluOpBignumOr,
          AluOpBignumAnd,
          AluOpBignumNot: begin
            operation_result_o = logical_res;
            adder_y_res_used = 1'b0;
          end
          default: ;
        endcase
      end
    end
  endgenerate

  // Tie off unused signals.
  logic unused_operation_commit;
  assign unused_operation_commit = operation_commit_i;

  // Tie off unused bits from pqc signals
  generate
    if (OtbnPQCEn) begin : gen_tie_pqc_bits
      assign gen_unused_pqc_bits.unused_pqc_bits =
          ^{gen_pqc_wsr.ispr_kmac_cfg_bignum_wdata_intg_blanked[311:39],
            gen_pqc_wsr.ispr_kmac_pw_bignum_wdata_intg_blanked[311:39],
            gen_pqc_wsr.kmac_pw_intg_err,
            gen_pqc_wsr.unmasked_digest_share[383:256]};
    end
  endgenerate

  // Determine if `mod_intg_q` is used.  The control signals are only valid if `operation_i.op` is
  // not none. If `shift_mod_sel` is low, `mod_intg_q` flows into `adder_y_op_b` and from there
  // into `adder_y_res`.  In this case, `mod_intg_q` is used iff  `adder_y_res` flows into
  // `operation_result_o`.
  logic mod_used;
  assign mod_used = operation_valid_i & (operation_i.op != AluOpBignumNone)
                    & !alu_predec_bignum_i.shift_mod_sel & adder_y_res_used;

  `ASSERT_KNOWN(ModUsed_A, mod_used)

  generate
    if (OtbnPQCEn) begin : gen_reg_intg_err_pqc
      logic kmac_used;
      assign kmac_used = operation_valid_i & (operation_i.op != AluOpBignumNone) &
                         ( |(ispr_predec_bignum_i.ispr_rd_en[IsprKmacMsg])    |
                           |(ispr_predec_bignum_i.ispr_rd_en[IsprKmacDigest]) |
                           |(ispr_predec_bignum_i.ispr_rd_en[IsprKmacCfg])    |
                           |(ispr_predec_bignum_i.ispr_rd_en[IsprKmacStatus]) );
      `ASSERT_KNOWN(KmacUsed_A, kmac_used)

      // Raise a register integrity violation error iff `mod_intg_q` is used
      // and (at least partially) invalid.
      assign reg_intg_violation_err_o = (mod_used & |(mod_intg_err)) |
                                        (kmac_used & ( |(gen_pqc_wsr.kmac_msg_intg_err)    |
                                                       |(gen_pqc_wsr.kmac_cfg_intg_err)    |
                                                       |(gen_pqc_wsr.kmac_status_intg_err) |
                                                       |(gen_pqc_wsr.kmac_digest_intg_err) ));

      // Detect and signal unexpected secure wipe signals.
      assign sec_wipe_err_o = (sec_wipe_kmac_regs_urnd_i | sec_wipe_mod_urnd_i)
                              & ~sec_wipe_running_i;
    end else begin : gen_reg_intg_err
      // Raise a register integrity violation error iff `mod_intg_q` is used
      // and (at least partially)invalid.
      assign reg_intg_violation_err_o = mod_used & |(mod_intg_err);

      // Detect and signal unexpected secure wipe signals.
      assign sec_wipe_err_o = sec_wipe_mod_urnd_i & ~sec_wipe_running_i;
    end
  endgenerate

  `ASSERT_KNOWN(RegIntgErrKnown_A, reg_intg_violation_err_o)

  // Blanking Assertions
  // All blanking assertions are reset with predec_error or overall error in the whole system
  // -indicated by operation_commit_i port- as OTBN does not guarantee blanking in the case
  // of an error.

  // adder_x_res related blanking
  generate
    if (OtbnPQCEn) begin : gen_blanking_x_res_pqc
      `ASSERT(BlankingBignumAluXOp_A,
              !expected_adder_x_en |->
              {gen_adder_pqc.adder_x_op_a_blanked, gen_adder_pqc.adder_x_op_b_blanked,
               gen_adder_pqc.adder_x_res} == '0,
              clk_i, !rst_ni || alu_predec_error_o || !operation_commit_i)
    end else begin : gen_blanking_x_res
      `ASSERT(BlankingBignumAluXOp_A,
              !expected_adder_x_en |->
              {gen_adder.adder_x_op_a_blanked, gen_adder.adder_x_op_b_blanked,
               gen_adder.adder_x_res} == '0,
              clk_i, !rst_ni || alu_predec_error_o || !operation_commit_i)
    end
  endgenerate

  // adder_y_res related blanking
  `ASSERT(BlankingBignumAluYOpA_A,
          !expected_adder_y_op_a_en |-> adder_y_op_a_blanked == '0,
          clk_i, !rst_ni || alu_predec_error_o || !operation_commit_i)
  `ASSERT(BlankingBignumAluYOpShft_A,
          !expected_adder_y_op_shifter_en |-> adder_y_op_shifter_res_blanked == '0,
          clk_i, !rst_ni || alu_predec_error_o || !operation_commit_i)

  // Adder Y must be blanked when its result is not used, with one exception: For `BN.SUBM` with
  // `a >= b` (thus the result of Adder X has the carry bit set), the result of Adder Y is not used
  // but it cannot be blanked solely based on the carry bit.
  generate
    if (OtbnPQCEn) begin : gen_blanking_alu_y_res_pqc
      `ASSERT(BlankingBignumAluYResUsed_A,
              !adder_y_res_used
              && !(operation_i.op == AluOpBignumSubm && gen_adder_pqc.adder_x_res[WLEN+1])
              |-> {x_res_operand_a_mux_out, gen_adder_pqc.adder_y_op_b} == '0,
              clk_i, !rst_ni || alu_predec_error_o || !operation_commit_i)
    end else begin : gen_blanking_alu_y_res
      `ASSERT(BlankingBignumAluYResUsed_A,
              !adder_y_res_used
              && !(operation_i.op == AluOpBignumSubm && gen_adder.adder_x_res[WLEN+1])
              |-> {x_res_operand_a_mux_out, gen_adder.adder_y_op_b} == '0,
              clk_i, !rst_ni || alu_predec_error_o || !operation_commit_i)
    end
  endgenerate

  // shifter_res related blanking
  `ASSERT(BlankingBignumAluShftA_A,
          !expected_shifter_a_en |-> shifter_operand_a_blanked == '0,
          clk_i, !rst_ni || alu_predec_error_o || !operation_commit_i)

  `ASSERT(BlankingBignumAluShftB_A,
          !expected_shifter_b_en |-> shifter_operand_b_blanked == '0,
          clk_i, !rst_ni || alu_predec_error_o || !operation_commit_i)

  `ASSERT(BlankingBignumAluShftRes_A,
          !(expected_shifter_a_en || expected_shifter_b_en) |-> shifter_res == '0,
          clk_i, !rst_ni || alu_predec_error_o || !operation_commit_i)

  // logical_res related blanking
  `ASSERT(BlankingBignumAluLogicOpA_A,
          !expected_logic_a_en |-> logical_op_a_blanked == '0,
          clk_i, !rst_ni || alu_predec_error_o  || !operation_commit_i)

  `ASSERT(BlankingBignumAluLogicShft_A,
          !expected_logic_shifter_en |-> logical_op_shifter_res_blanked == '0,
          clk_i, !rst_ni || alu_predec_error_o || !operation_commit_i)

  `ASSERT(BlankingBignumAluLogicRes_A,
          !(expected_logic_a_en || expected_logic_shifter_en) |-> logical_res == '0,
          clk_i, !rst_ni || alu_predec_error_o || !operation_commit_i)


  // MOD ISPR Blanking
  `ASSERT(BlankingIsprMod_A,
          !(|mod_wr_en) |-> ispr_mod_bignum_wdata_intg_blanked == '0,
          clk_i, !rst_ni || ispr_predec_error_o || alu_predec_error_o || !operation_commit_i)

  generate
    if (OtbnPQCEn) begin : gen_kmac_ispr_blanking
      // KMAC CFG ISPR Blanking
      `ASSERT(BlankingIsprKmacCfg_A,
              !(|gen_pqc_wsr.kmac_cfg_wr_en) |->
              gen_pqc_wsr.ispr_kmac_cfg_bignum_wdata_intg_blanked == '0,
              clk_i, !rst_ni || ispr_predec_error_o || alu_predec_error_o || !operation_commit_i)

      // KMAC MSG ISPR Blanking
      `ASSERT(BlankingIsprKmacMsgA,
              !((|gen_pqc_wsr.kmac_msg_wr_en) | ispr_predec_bignum_i.ispr_wr_en[IsprKmacMsg]) |->
              gen_pqc_wsr.ispr_kmac_msg_bignum_wdata_intg_blanked == '0,
              clk_i, !rst_ni || ispr_predec_error_o || alu_predec_error_o || !operation_commit_i)
    end
  endgenerate

  // ACC ISPR Blanking
  `ASSERT(BlankingIsprACC_A,
          !(|ispr_acc_wr_en_o) |-> ispr_acc_bignum_wdata_intg_blanked == '0,
          clk_i, !rst_ni || ispr_predec_error_o || alu_predec_error_o || !operation_commit_i)


endmodule
