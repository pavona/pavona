// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Modified by Ruben Niederhagen and Hoang Nguyen Hien Pham - authors of
// "Improving ML-KEM & ML-DSA on OpenTitan - Efficient Multiplication Vector Instructions for OTBN"
// (https://eprint.iacr.org/2025/2028).
// Copyright Ruben Niederhagen and Hoang Nguyen Hien Pham.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`ifndef SYNTHESIS

/**
 * Tracer module for ACC. This produces a multi-line string as trace output at most once every
 * cycle and provides it to the simulation environment via a DPI call. It uses `acc_trace_if` to
 * get the information it needs. For further information see `hw/ip/acc/dv/tracer/README.md`.
 */
module acc_tracer #(
  parameter bit AccPQCEn = acc_pqc_env_pkg::AccPQCEn
) (
  input  logic  clk_i,
  input  logic  rst_ni,

  acc_trace_if acc_trace
);
  import acc_pkg::*;

  // Prefixes used in trace lines. Formats are documented in `hw/ip/acc/dv/tracer/README.md`
  parameter string InsnExecutePrefix = "E";
  parameter string InsnStallPrefix = "S";
  parameter string WipeInProgressPrefix = "U";
  parameter string WipeCompletePrefix = "V";
  parameter string StrayChangePrefix = "Z";
  parameter string RegReadPrefix = "<";
  parameter string RegWritePrefix = ">";
  parameter string MemWritePrefix = "W";
  parameter string MemReadPrefix = "R";

  logic [31:0] cycle_count;

  // Given a WLEN size word output a hex string with the data split into 32-bit chunks separated
  // with '_'. WLEN must be a multiple of 32.
  function automatic string acc_wlen_data_str(logic [WLEN-1:0] data);
    string data_str;

    assert ((WLEN % 32) == 0) else $error("WLEN must be a multiple of 32 in acc_wlen_data_str");

    for (int i = WLEN; i > 0; i-= 32) begin
      if (i != WLEN) begin
        data_str = $sformatf("%s_", data_str);
      end else begin
        data_str = "0x";
      end

      data_str = $sformatf("%s%08x", data_str, data[i-1 -: 32]);
    end

    return data_str;
  endfunction

  // Produce trace output string for dmem writes. For a 256-bit write, the address and full data is
  // output. For 32-bit writes (determined by looking at the mask) only the relevant 32-bit chunk is
  // output along with the address modified so it refers to that chunk.
  function automatic string acc_dmem_write_str(logic [31:0] addr,
                                                logic [WLEN-1:0] data,
                                                logic [WLEN-1:0] wmask);

    logic [WLEN-1:0] cur_base_mask;

    // For a full WLEN write output all of the data.
    if (wmask == '1) begin
      return $sformatf("[0x%08x]: %s", addr, acc_wlen_data_str(data));
    end

    // Iterate through the possible 32-bit chunks
    cur_base_mask = {{(WLEN-32){1'b0}}, 32'hFFFF_FFFF};

    for (int i = 0; i < WLEN; i += 32) begin
      // If mask matches current chunk alone output trace indicating a single 32-bit write.
      if (wmask == cur_base_mask) begin
        return $sformatf("[0x%08x]: 0x%08x", addr + (i / 8), data[i*32 +: 32]);
      end

      cur_base_mask = cur_base_mask << 32;
    end

    // Fallback where mask isn't as expected, indicate ERR in the trace and provide both full mask
    // and data.
    return $sformatf("[0x%08x]: Mask ERR Mask: %s Data: %s", addr, acc_wlen_data_str(wmask),
      acc_wlen_data_str(data));
  endfunction

  // Determine name for an ISPR
  function automatic string acc_ispr_name_str(ispr_e ispr);
    unique case (ispr)
      IsprMod: return "MOD";
      IsprAcc: return "ACC";
      IsprAccH: begin
        if (AccPQCEn) begin
          return "ACCH";
        end
      end
      IsprKmacMsg: begin
        if (AccPQCEn) begin
          return "KMAC_MSG";
        end
      end
      IsprKmacCfg: begin
        if (AccPQCEn) begin
          return "KMAC_CFG";
        end
      end
      IsprKmacPartialW: begin
        if (AccPQCEn) begin
          return "KMAC_PARTIAL_WRITE";
        end
      end
      IsprRnd: return "RND";
      IsprFlags: return "FLAGS";
      IsprUrnd: return "URND";
      default: return "UNKNOWN_ISPR";
    endcase
  endfunction

  // Format flag information into a string
  function automatic string acc_flags_str(flags_t f);
    return $sformatf("{C: %d, M: %d, L: %d, Z: %d}", f.C, f.M, f.L, f.Z);
  endfunction

  // Called by other trace functions to append their trace lines to the output buffer
  function automatic string output_trace(string work, string prefix, string trace_line);
    return $sformatf("%s%s %s\n", work, prefix, trace_line);
  endfunction

  // Called by some trace functions to prepend their trace lines to the output buffer
  function automatic string prepend_trace(string work, string prefix, string trace_line);
    return $sformatf("%s %s\n%s", prefix, trace_line, work);
  endfunction

  function automatic string trace_base_rf(string work);
    if (acc_trace.rf_base_rd_en_a) begin
      work = output_trace(work, RegReadPrefix,
                          $sformatf("x%02d: 0x%08x", acc_trace.rf_base_rd_addr_a,
                                    acc_trace.rf_base_rd_data_a));
    end

    if (acc_trace.rf_base_rd_en_b) begin
      work = output_trace(work, RegReadPrefix,
                          $sformatf("x%02d: 0x%08x", acc_trace.rf_base_rd_addr_b,
                                    acc_trace.rf_base_rd_data_b));
    end

    if (|acc_trace.rf_base_wr_en && acc_trace.rf_base_wr_commit &&
        acc_trace.rf_base_wr_addr != '0) begin
      work = output_trace(work, RegWritePrefix,
                          $sformatf("x%02d: 0x%08x", acc_trace.rf_base_wr_addr,
                                    acc_trace.rf_base_wr_data));
    end

    return work;
  endfunction

  function automatic string trace_bignum_rf(string work);
    if (acc_trace.rf_bignum_rd_en_a) begin
      work = output_trace(work, RegReadPrefix,
                          $sformatf("w%02d: %s", acc_trace.rf_bignum_rd_addr_a,
                                    acc_wlen_data_str(acc_trace.rf_bignum_rd_data_a)));
    end

    if (acc_trace.rf_bignum_rd_en_b) begin
      work = output_trace(work, RegReadPrefix,
                          $sformatf("w%02d: %s", acc_trace.rf_bignum_rd_addr_b,
                                    acc_wlen_data_str(acc_trace.rf_bignum_rd_data_b)));
    end

    if (|acc_trace.rf_bignum_wr_en & acc_trace.rf_bignum_wr_commit) begin
      work = output_trace(work, RegWritePrefix,
                          $sformatf("w%02d: %s", acc_trace.rf_bignum_wr_addr,
                                    acc_wlen_data_str(acc_trace.rf_bignum_wr_data)));
    end

    return work;
  endfunction

  function automatic string trace_bignum_mem(string work);
    if (acc_trace.dmem_write) begin
      work = output_trace(work, MemWritePrefix,
                          acc_dmem_write_str(acc_trace.dmem_write_addr,
                                              acc_trace.dmem_write_data,
                                              acc_trace.dmem_write_mask));
    end

    if (acc_trace.dmem_read) begin
      work = output_trace(work, MemReadPrefix,
                          $sformatf("[0x%08x]: %s", acc_trace.dmem_read_addr,
                                    acc_wlen_data_str(acc_trace.dmem_read_data)));
    end

    return work;
  endfunction

  function automatic string trace_ispr_accesses(string work);
    // Iterate through all ISPRs outputting reg reads and writes where ISPR accesses have occurred
    for (int i_ispr = 0; i_ispr < NIspr; i_ispr++) begin
      if (ispr_e'(i_ispr) == IsprFlags) begin
        // Special handling for flags ISPR to provide per flag field output
        for (int i_fg = 0; i_fg < NFlagGroups; i_fg++) begin
          if (acc_trace.flags_read[i_fg]) begin
            work = output_trace(work, RegReadPrefix,
                                $sformatf("%s%1d: %s", acc_ispr_name_str(ispr_e'(i_ispr)), i_fg,
                                          acc_flags_str(acc_trace.flags_read_data[i_fg])));
          end

          if (acc_trace.flags_write[i_fg]) begin
            work = output_trace(work, RegWritePrefix,
                                $sformatf("%s%1d: %s", acc_ispr_name_str(ispr_e'(i_ispr)), i_fg,
                                          acc_flags_str(acc_trace.flags_write_data[i_fg])));
          end
        end
      end else begin
        // For all other ISPRs just dump out the full 256-bits of data being read/written
        if (acc_trace.ispr_read[i_ispr]) begin
          work = output_trace(work, RegReadPrefix,
                              $sformatf("%s: %s", acc_ispr_name_str(ispr_e'(i_ispr)),
                                        acc_wlen_data_str(acc_trace.ispr_read_data[i_ispr])));
        end

        if (acc_trace.ispr_write[i_ispr]) begin
          work = output_trace(work, RegWritePrefix,
                              $sformatf("%s: %s", acc_ispr_name_str(ispr_e'(i_ispr)),
                                        acc_wlen_data_str(acc_trace.ispr_write_data[i_ispr])));
        end
      end
    end
    return work;
  endfunction

  function automatic string prepend_trace_header(string work);
    bit added_header = 1'b0;

    if (acc_trace.secure_wipe_ack_r) begin
      work = prepend_trace(work, WipeCompletePrefix, "");
      added_header = 1'b1;
    end else if (acc_trace.secure_wipe_req || !acc_trace.initial_secure_wipe_done) begin
      work = prepend_trace(work, WipeInProgressPrefix, "");
      added_header = 1'b1;
    end

    if (acc_trace.insn_valid) begin
      if (acc_trace.insn_fetch_err) begin
        // This means that we've seen an IMEM integrity error. Squash the reported instruction bits
        // and ignore any stall: this will be the last cycle of the instruction either way.
        work = prepend_trace(work, InsnExecutePrefix,
                             $sformatf("PC: 0x%08x, insn: ??", acc_trace.insn_addr));
      end else begin
        // We have a valid instruction, either stalled or completing its execution
        work = prepend_trace(work, acc_trace.insn_stall ? InsnStallPrefix : InsnExecutePrefix,
                             $sformatf("PC: 0x%08x, insn: 0x%08x", acc_trace.insn_addr,
                                       acc_trace.insn_data));
      end
      added_header = 1'b1;
    end

    if (work != "" && !added_header) begin
      work = prepend_trace(work, StrayChangePrefix, "");
    end

    return work;
  endfunction

  import "DPI-C" function void accept_acc_trace_string(string trace, int unsigned cycle_count);

  function automatic void do_trace();
    string work;

    work = trace_bignum_rf(work);
    work = trace_base_rf(work);
    work = trace_bignum_mem(work);
    work = trace_ispr_accesses(work);

    work = prepend_trace_header(work);

    if (work != "") begin
      accept_acc_trace_string(work, cycle_count);
    end
  endfunction

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      cycle_count <= '0;
    end else begin
      cycle_count <= cycle_count + 1'b1;
      do_trace();
    end
  end

endmodule

`endif // SYNTHESIS
