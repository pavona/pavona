// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// SHA-256/384/512 configurable mode engine (64-bit word datapath)

`include "prim_assert.sv"

module prim_sha2 import prim_sha2_pkg::*;
#(
  parameter bit MultimodeEn = 0, // assert to enable multi-mode digest feature

  localparam int unsigned RndWidth256 = $clog2(NumRound256),
  localparam int unsigned RndWidth512 = $clog2(NumRound512),
  localparam sha_word64_t ZeroWord    = '0
 ) (
  input clk_i,
  input rst_ni,

  input               wipe_secret_i,
  input sha_word32_t  wipe_v_i,
  // control signals and message words input to the message FIFO
  input               fifo_rvalid_i, // indicates that the message FIFO (prim_sync_fifo) has words
                                     // ready to write into the SHA-2 padding buffer
  input  sha_fifo64_t fifo_rdata_i,
  output logic        fifo_rready_o, // indicates the internal padding buffer is ready to receive
                                     // words from the message FIFO

  // control signals
  input               sha_en_i,   // if disabled, it clears internal content
  input               hash_start_i, // start hashing: initialize data counter to zero and clear
                                    // digest
  input               hash_stop_i, // stop hashing: after all data up to message length has been
                                   // hashed, stop without padding
  input               hash_continue_i, // continue hashing: set data counter to `message_length_i`
                                       // and use current digest
  input digest_mode_e digest_mode_i,
  input               hash_process_i,
  output logic        hash_done_o,

  input  [63:0]             message_length_i, // bits but byte based
  input  sha_word64_t [7:0] digest_i,
  input  logic [7:0]        digest_we_i,
  output sha_word64_t [7:0] digest_o, // tie off unused port slice when MultimodeEn = 0
  output logic digest_on_blk_o, // digest being computed for a complete block
  output sha_st_e sha_st_o,
  output logic hash_running_o, // `1` iff hash computation is active (as opposed to `idle_o`, which
                               // is also `0` and thus 'busy' when waiting for a FIFO input)
  output logic idle_o
);
  // signal definitions shared for both 256-bit and multi-mode
  logic hash_go;

  // Most operations and control signals are identical no matter if we are starting or re-starting
  // to hash.
  assign hash_go = hash_start_i | hash_continue_i;

  sha_word64_t [15:0] word_buffer_d, word_buffer_q;
  logic [3:0]   w_index_d, w_index_q;
  logic         word_part_inc;
  logic         msg_feed_complete;

  // padding module fifo interface data and control signals
  sha_word64_t  shaf_rdata;
  logic         shaf_rvalid;
  logic         shaf_rready;

  // msg block interface control signals
  logic         msg_block_valid;
  logic         msg_block_done;
  logic         msg_block_ready;

  always_comb begin
    word_part_inc   = 1'b0;
    shaf_rready     = 1'b0;
    msg_block_valid = 1'b0;
    msg_block_done  = 1'b0;

    // assign word_buffer
    if (!sha_en_i || hash_go) word_buffer_d = 0;
    else                      word_buffer_d = word_buffer_q;

    if ((sha_st_o == ShaLoad | sha_st_o == ShaUpdateDigest) && msg_block_ready) begin
      if (sha_en_i && shaf_rvalid) begin // valid incoming word part and SHA engine is enabled
        // shift in the new data from the padding block
        word_buffer_d = {shaf_rdata, word_buffer_q[15:1]};
        word_part_inc = 1'b1;
        shaf_rready   = 1'b1;
        if (w_index_q == 15) begin
          msg_block_valid = 1'b1;
        end
      end
    end

    // Message feed complete comes after the last data has been sent
    if (msg_feed_complete) begin
      msg_block_done = 1'b1;
    end

    // assign w_index_d
    if ((hash_go || !sha_en_i)) begin
      w_index_d = '0;
    end else if (word_part_inc) begin
      w_index_d = w_index_q + 1'b1;
    end else begin
      w_index_d = w_index_q;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni)  w_index_q <= '0;
    else          w_index_q <= w_index_d;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni)  word_buffer_q <= 0;
    else          word_buffer_q <= word_buffer_d;
  end

  prim_sha2_compression #(
    .MultimodeEn(MultimodeEn)
  ) u_sha2_compression (
    .clk_i (clk_i),
    .rst_ni (rst_ni),
    .wipe_secret_i      (wipe_secret_i),
    .wipe_v_i           (wipe_v_i),

    .msg_block_data_i(word_buffer_d),
    .msg_block_valid_i(msg_block_valid),
    .msg_block_done_i(msg_block_done),
    .msg_block_ready_o(msg_block_ready),

    .sha_en_i           (sha_en_i),
    .hash_start_i       (hash_start_i),
    .hash_continue_i    (hash_continue_i),
    .digest_mode_i      (digest_mode_i),
    .hash_done_o        (hash_done_o),
    .message_length_i   (message_length_i),
    .digest_i           (digest_i),
    .digest_we_i        (digest_we_i),
    .digest_o           (digest_o),
    .digest_on_blk_o    (digest_on_blk_o),
    .sha_st_o           (sha_st_o),
    .hash_running_o     (hash_running_o),
    .idle_o             (idle_o)
  );

  prim_sha2_pad #(
      .MultimodeEn(MultimodeEn)
    ) u_pad (
    .clk_i,
    .rst_ni,
    .fifo_rvalid_i,
    .fifo_rdata_i,
    .fifo_rready_o,
    .shaf_rvalid_o (shaf_rvalid), // is set when the 512-bit chunk is ready in the padding buffer
    .shaf_rdata_o  (shaf_rdata),
    .shaf_rready_i (shaf_rready), // indicates that w is ready for more words from padding buffer
    .sha_en_i,
    .hash_start_i,
    .hash_stop_i,
    .hash_continue_i,
    .digest_mode_i,
    .hash_process_i,
    .hash_done_i (hash_done_o),
    .message_length_i ({64'b0, message_length_i}), // 128-bit message length per NIST-FIPS-180-4
    .msg_feed_complete_o (msg_feed_complete)
  );

endmodule
