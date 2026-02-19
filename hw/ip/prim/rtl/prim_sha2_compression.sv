// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// SHA-256/384/512 configurable mode engine (64-bit word datapath)

`include "prim_assert.sv"

module prim_sha2_compression import prim_sha2_pkg::*;
#(
  parameter bit MultimodeEn = 0, // assert to enable multi-mode digest feature

  localparam int unsigned RndWidth256 = $clog2(NumRound256),
  localparam int unsigned RndWidth512 = $clog2(NumRound512),
  localparam sha_word64_t ZeroWord    = '0,
  localparam int unsigned BlockW      = (MultimodeEn) ? 1024 : 512
 ) (
  input clk_i,
  input rst_ni,

  input               wipe_secret_i,
  input sha_word32_t  wipe_v_i,

  // control signals and message words input for direct block size load
  input  logic [BlockW-1:0] msg_block_data_i,  // full block size input for compression only
  input  logic              msg_block_valid_i, // valid signal for the block input
  input  logic              msg_block_done_i,  // signal all blocks have been sent
  output logic              msg_block_ready_o, // Ready for next block

  // control signals
  input               sha_en_i,   // if disabled, it clears internal content
  input               hash_start_i, // start hashing: initialize data counter to zero and clear
                                    // digest

  input               hash_continue_i, // continue hashing: set data counter to `message_length_i`
                                       // and use current digest
  input digest_mode_e digest_mode_i,

  // Hash output signals
  output logic              hash_done_o,
  output sha_word64_t [7:0] hash_o,

  // Digest input/output signals
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
  // control signals - shared for both modes
  logic update_w_from_fifo, calculate_next_w;
  logic init_hash, run_hash, one_chunk_done;
  logic update_digest, clear_digest;
  logic hash_done_next; // to meet the phase with digest value
  logic hash_go;

  // datapath signals - shared for both modes
  logic [RndWidth512-1:0] round_d, round_q;
  digest_mode_e           digest_mode_flag_d, digest_mode_flag_q;

  // tie off unused input ports and signals slices
  if (!MultimodeEn) begin : gen_tie_unused
    logic [7:0] unused_digest_upper;
    for (genvar i = 0; i < 8; i++) begin : gen_unused_digest_upper
      assign unused_digest_upper[i] = ^digest_i[i][63:32];
    end
    logic unused_signals;
    assign unused_signals = ^{unused_digest_upper};
  end

  // Most operations and control signals are identical no matter if we are starting or continuing
  // to hash.
  assign hash_go = hash_start_i | hash_continue_i;

  assign digest_mode_flag_d = hash_go     ? digest_mode_i   :    // latch in configured mode
                              hash_done_o ? SHA2_None       :    // clear
                                            digest_mode_flag_q;  // keep

  if (MultimodeEn) begin : gen_multimode
    // datapath signal definitions for multi-mode
    sha_word64_t [7:0]  hash_d, hash_q; // a,b,c,d,e,f,g,h
    sha_word64_t [15:0] w_d, w_q;
    sha_word64_t [7:0]  digest_d, digest_q;

    // compute w
    always_comb begin : compute_w_multimode
      w_d = w_q;
      if (wipe_secret_i) begin
        w_d = {32{wipe_v_i}};
      end else if (!sha_en_i || hash_go) begin
        w_d = '0;
      end else if (!run_hash && update_w_from_fifo) begin
        // this logic runs at the first stage of SHA: hash not running yet, filling block
          w_d = msg_block_data_i;
      end else if (calculate_next_w) begin // message scheduling/derivation for last 48/64 rounds
        if (digest_mode_flag_q == SHA2_256) begin
          // this computes the next w[16] and shifts out w[0] into compression below
          w_d = {{32'b0, calc_w_256(w_q[0][31:0], w_q[1][31:0], w_q[9][31:0],
                w_q[14][31:0])}, w_q[15:1]};
        end else if ((digest_mode_flag_q == SHA2_384) || (digest_mode_flag_q == SHA2_512)) begin
          w_d = {calc_w_512(w_q[0], w_q[1], w_q[9], w_q[14]), w_q[15:1]};
        end
      end else if (run_hash) begin
        // just shift-out the words as they get consumed. There's no incoming data.
        w_d = {ZeroWord, w_q[15:1]};
      end
    end : compute_w_multimode

    // update w
    always_ff @(posedge clk_i or negedge rst_ni) begin : update_w_multimode
      if (!rst_ni)            w_q <= '0;
      else if (MultimodeEn)   w_q <= w_d;
    end : update_w_multimode

    // compute hash
    always_comb begin : compression_multimode
      hash_d = hash_q;
      if (wipe_secret_i) begin
        hash_d = {16{wipe_v_i}};
      end else if (init_hash) begin
        hash_d = digest_q;
      end else if (run_hash) begin
        if (digest_mode_flag_q == SHA2_256) begin
          hash_d = compress_multi_256(w_q[0][31:0],
                   CubicRootPrime256[round_q[RndWidth256-1:0]], hash_q);
        end else begin // SHA384 || SHA512
          hash_d = compress_512(w_q[0], CubicRootPrime512[round_q], hash_q);
        end
      end
    end : compression_multimode

    // update hash
    always_ff @(posedge clk_i or negedge rst_ni) begin : update_hash_multimode
      if (!rst_ni)  hash_q <= '0;
      else          hash_q <= hash_d;
    end : update_hash_multimode

    // assign hash to output
    assign hash_o = hash_q;

    // compute digest
    always_comb begin : compute_digest_multimode
      digest_d = digest_q;
      if (wipe_secret_i) begin
        digest_d = {16{wipe_v_i}};
      end else if (hash_start_i) begin
        for (int i = 0 ; i < 8 ; i++) begin
          if (digest_mode_i == SHA2_256) begin
            digest_d[i] = {32'b0, InitHash_256[i]};
          end else if (digest_mode_i == SHA2_384) begin
            digest_d[i] = InitHash_384[i];
          end else if (digest_mode_i == SHA2_512) begin
            digest_d[i] = InitHash_512[i];
          end
        end
      end else if (clear_digest) begin
        digest_d = '0;
      end else if (!sha_en_i) begin
        for (int i = 0; i < 8; i++) begin
          digest_d[i] = digest_we_i[i] ? digest_i[i] : digest_q[i];
        end
      end else if (update_digest) begin
        for (int i = 0 ; i < 8 ; i++) begin
          digest_d[i] = digest_q[i] + hash_q[i];
        end
      end
    end : compute_digest_multimode

    // update digest
    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni)  digest_q <= '0;
      else          digest_q <= digest_d;
    end

    // assign digest to output
    assign digest_o = digest_q;

    // When wipe_secret is high, sensitive internal variables are cleared by extending the wipe
    // value specified in the register
    `ASSERT(WipeHashAssert,
            wipe_secret_i |=> (hash_q == {($bits(hash_q)/$bits(wipe_v_i)){$past(wipe_v_i)}}))
    `ASSERT(WipeMsgSchArrAssert,
            wipe_secret_i |=> (w_q == {($bits(w_q)/$bits(wipe_v_i)){$past(wipe_v_i)}}))
    `ASSERT(WipeDigestAssert,
            wipe_secret_i |=> (digest_q == {($bits(digest_q)/$bits(wipe_v_i)){$past(wipe_v_i)}}))
  end else begin : gen_256 // MultimodeEn = 0
    // datapath signal definitions for SHA-2 256 only
    sha_word32_t [7:0]  hash256_d, hash256_q; // a,b,c,d,e,f,g,h
    sha_word32_t [15:0] w256_d, w256_q;
    sha_word32_t [7:0]  digest256_d, digest256_q;

    always_comb begin : compute_w_256
      // ~MultimodeEn
      w256_d = w256_q;
      if (wipe_secret_i) begin
        w256_d = {16{wipe_v_i}};
      end else if (!sha_en_i || hash_go) begin
        w256_d = '0;
      end else if (!run_hash && update_w_from_fifo) begin
        // this logic runs at the first stage of SHA: hash not running yet, filling block
        w256_d = msg_block_data_i;
      end else if (calculate_next_w) begin // message scheduling/derivation for last 48/64 rounds
        w256_d = {calc_w_256(w256_q[0][31:0], w256_q[1][31:0], w256_q[9][31:0],
                 w256_q[14][31:0]), w256_q[15:1]};
      end else if (run_hash) begin
        // just shift-out the words as they get consumed. There's no incoming data.
        w256_d = {ZeroWord[31:0], w256_q[15:1]};
      end
    end : compute_w_256

    // update w_256
    always_ff @(posedge clk_i or negedge rst_ni) begin : update_w_256
      if (!rst_ni)            w256_q <= '0;
      else if (!MultimodeEn)  w256_q <= w256_d;
    end : update_w_256

    // compute hash_256
    always_comb begin : compression_256
      hash256_d = hash256_q;
      if (wipe_secret_i) begin
        hash256_d = {8{wipe_v_i}};
      end else if (init_hash) begin
        hash256_d = digest256_q;
      end else if (run_hash) begin
        hash256_d = compress_256(w256_q[0], CubicRootPrime256[round_q[RndWidth256-1:0]], hash256_q);
      end
    end : compression_256

    // update hash_256
    always_ff @(posedge clk_i or negedge rst_ni) begin : update_hash256
      if (!rst_ni) hash256_q <= '0;
      else         hash256_q <= hash256_d;
    end : update_hash256

    // assign hash to output
    for (genvar i = 0; i < 8; i++) begin  : gen_assign_hash_256
      assign hash_o[i][31:0]  = hash256_q[i];
      assign hash_o[i][63:32] = 32'b0;
    end

    // compute digest_256
    always_comb begin : compute_digest_256
      digest256_d = digest256_q;
      if (wipe_secret_i) begin
        digest256_d = {8{wipe_v_i}};
      end else if (hash_start_i) begin
        for (int i = 0 ; i < 8 ; i++) begin
            digest256_d[i] = InitHash_256[i];
        end
      end else if (clear_digest) begin
        digest256_d = '0;
      end else if (!sha_en_i) begin
        for (int i = 0; i < 8; i++) begin
          digest256_d[i] = digest_we_i[i] ? digest_i[i][31:0] : digest256_q[i];
        end
      end else if (update_digest) begin
        for (int i = 0 ; i < 8 ; i++) begin
          digest256_d[i] = digest256_q[i] + hash256_q[i];
        end
      end
    end : compute_digest_256

    // update digest_256
    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni)  digest256_q <= '0;
      else          digest256_q <= digest256_d;
    end

    // assign digest to output
    for (genvar i = 0; i < 8; i++) begin  : gen_assign_digest_256
      assign digest_o[i][31:0]  = digest256_q[i];
      assign digest_o[i][63:32] = 32'b0;
    end

    // When wipe_secret is high, sensitive internal variables are cleared by extending the wipe
    // value specifed in the register
    `ASSERT(WipeHashAssert,
      wipe_secret_i |=> (hash256_q == {($bits(hash256_q)/$bits(wipe_v_i)){$past(wipe_v_i)}}))
    `ASSERT(WipeMsgSchArrAssert,
      wipe_secret_i |=> (w256_q == {($bits(w256_q)/$bits(wipe_v_i)){$past(wipe_v_i)}}))
    `ASSERT(WipeDigestAssert,
      wipe_secret_i |=> (digest256_q == {($bits(digest256_q)/$bits(wipe_v_i)){$past(wipe_v_i)}}))
  end

  // compute round counter (shared)
  always_comb begin : round_counter
    round_d = round_q;
    if (!sha_en_i || hash_go) begin
      round_d = '0;
    end else if (run_hash) begin
      if (((round_q[RndWidth256-1:0] == RndWidth256'(unsigned'(NumRound256-1))) &&
         (digest_mode_flag_q == SHA2_256 || !MultimodeEn)) ||
         ((round_q == RndWidth512'(unsigned'(NumRound512-1))) &&
         ((digest_mode_flag_q == SHA2_384) || (digest_mode_flag_q == SHA2_512)))) begin
        round_d = '0;
      end else begin
        round_d = round_q + RndWidth512'(1);
      end
    end
  end

  // update round counter (shared)
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) round_q <= '0;
    else         round_q <= round_d;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) hash_done_o <= 1'b0;
    else         hash_done_o <= hash_done_next;
  end

  logic msg_block_complete;

  // Whenever the msg_block_done has been received we will get the result digest
  // at the end of the next hashing cycle. Done can be sent when all blocks of the
  // message have been sent, or we are told to stop from the padding module.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      msg_block_complete <= 1'b0;
    end else if (hash_done_o | hash_go) begin
      msg_block_complete <= 1'b0;
    end else if (msg_block_done_i) begin
      msg_block_complete <= msg_block_done_i;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) digest_mode_flag_q <= SHA2_None;
    else         digest_mode_flag_q <= digest_mode_flag_d;
  end

  sha_st_e sha_st_q, sha_st_d;

  assign sha_st_o = sha_st_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) sha_st_q <= ShaIdle;
    else         sha_st_q <= sha_st_d;
  end

  logic sha_en_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) sha_en_q <= 1'b0;
    else         sha_en_q <= sha_en_i;
  end

  assign clear_digest = hash_start_i | (~sha_en_i & sha_en_q);

  always_comb begin
    update_digest    = 1'b0;
    calculate_next_w = 1'b0;
    init_hash        = 1'b0;
    run_hash         = 1'b0;

    msg_block_ready_o  = 1'b0;
    hash_done_next     = 1'b0;
    update_w_from_fifo = 1'b0;

    sha_st_d         = sha_st_q;

    unique case (sha_st_q)
      ShaIdle: begin
        // We wait in idle until a signal to start hashing
        if (hash_go) sha_st_d = ShaLoad;
      end

      ShaLoad: begin
        // During load state we fill the internal block size with data
        // from the direct load interface. Interface ready is asserted
        // until the 512-bits are available and valid.
        msg_block_ready_o = 1'b1;
        if (!msg_block_valid_i) begin
          update_w_from_fifo = 1'b0;
          // msg_block_complete originates from the msg_block_done_i input
          // to indicate there are no more message blocks to be hashed.
          if (msg_block_complete) begin
            sha_st_d       = ShaIdle;
            hash_done_next  = 1'b1;
          end
        end else begin
          sha_st_d          = ShaInit;
          update_w_from_fifo = 1'b1;
        end

      end

      ShaInit: begin
        // Initialize the hash with the previous/starting digest
        sha_st_d  = ShaCompress;
        init_hash = 1'b1;
      end

      ShaCompress: begin
        run_hash = 1'b1;
        if (((digest_mode_flag_q == SHA2_256 || ~MultimodeEn) && round_q < 48) ||
           (((digest_mode_flag_q == SHA2_384) ||
           (digest_mode_flag_q == SHA2_512)) && round_q < 64)) begin
          calculate_next_w = 1'b1;
        end else if (one_chunk_done) begin
          sha_st_d = ShaUpdateDigest;
          // If the block we just finished hashing was the final block then we
          // assert that the resulting digest will be the valid output.
          if (msg_block_complete) begin
            hash_done_next = 1'b1;
          end
        end
      end

      ShaUpdateDigest: begin
        update_digest = 1'b1;
        // While there is more data in the message to hash we return to the Load state to
        // get more data from the direct load interface. It is also possible to load the
        // next block on the transition of this state, if the next block is ready, go directly
        // to the init state instead of load.
        if (!msg_block_complete | !hash_done_o) begin
          sha_st_d  = ShaLoad;
          msg_block_ready_o = 1'b1;
          if (msg_block_valid_i) begin
            sha_st_d          = ShaInit;
            update_w_from_fifo = 1'b1;
          end
        end else begin
          sha_st_d  = ShaIdle;
        end
      end

      default: begin
        sha_st_d = ShaIdle;
      end
    endcase

    if ((!sha_en_i || hash_go) && (sha_st_q != ShaIdle)) sha_st_d  = ShaIdle;

  end

  logic update_digest_q, update_digest_d;

  // Determine whether a digest is being computed for a complete block: when `update_digest` is set,
  // this module is not waiting for more data from the FIFO, and `message_length_i` is zero modulo a
  // complete block (512 bit for SHA2_256 and 1024 bit for SHA2_384 and SHA2_512).
  assign digest_on_blk_o = (update_digest || update_digest_q) && (sha_st_d == ShaIdle) && (
      (digest_mode_flag_q == SHA2_256                 && message_length_i[8:0] == '0) ||
      (digest_mode_flag_q inside {SHA2_384, SHA2_512} && message_length_i[9:0] == '0));

  assign update_digest_d = digest_on_blk_o ? 1'b0 :
                           update_digest   ? 1'b1 : update_digest_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      update_digest_q <= 1'b0;
    end else begin
      update_digest_q <= update_digest_d;
    end
  end

  assign one_chunk_done = ((digest_mode_flag_q == SHA2_256 || ~MultimodeEn)
                          && (round_q == 7'd63)) ? 1'b1 :
                          (((digest_mode_flag_q == SHA2_384) || (digest_mode_flag_q == SHA2_512))
                          && (round_q == 7'd79)) ? 1'b1 : 1'b0;

  assign hash_running_o = init_hash | run_hash | update_digest;

  // Idle
  assign idle_o = (sha_st_q == ShaIdle) && !hash_go;

  ////////////////
  // Assertions //
  ////////////////

  `ASSERT(ValidDigestModeFlag_A, run_hash |->
    digest_mode_flag_q inside {SHA2_256, SHA2_384, SHA2_512})

endmodule : prim_sha2_compression
