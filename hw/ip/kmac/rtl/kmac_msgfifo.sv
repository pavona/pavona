// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// KMAC MSG_FIFO
//
// This module converts TL-UL interface into MSG_FIFO interface used in KMAC.

`include "prim_assert.sv"

module kmac_msgfifo
  import kmac_pkg::*;
#(
  // OutWidth is MsgFIFO data width. prim_packer converts InW to OutW prior to
  // pushing to MsgFIFO
  parameter int OutWidth = 64,

  parameter bit EnMasking = 1'b 1,

  // Internal MsgFIFO Entry count
  parameter  int MsgDepth = 9,
  localparam int MsgDepthW = $clog2(MsgDepth+1), // derived parameter
  localparam int Share = (EnMasking) ? 2 : 1     // derived parameter
) (
  input clk_i,
  input rst_ni,

  // from REG or KeyMgr Intf input
  input  logic                fifo_valid_i [Share],
  input  logic [OutWidth-1:0] fifo_data_i  [Share],
  input  logic [OutWidth-1:0] fifo_mask_i,
  output logic                fifo_ready_o [Share],

  // MSG interface
  output logic                  msg_valid_o [Share],
  output logic [OutWidth-1:0]   msg_data_o  [Share],
  output logic [OutWidth/8-1:0] msg_strb_o  [Share],
  input  logic                  msg_ready_i,

  output logic                  fifo_empty_o [Share],
  output logic                  fifo_full_o  [Share],
  output logic [MsgDepthW-1:0]  fifo_depth_o [Share],

  // Control
  input prim_mubi_pkg::mubi4_t clear_i,

  // process_i --> process_o
  // process_o asserted after all internal messages are flushed out to MSG interface
  input        process_i,
  output logic process_o,

  err_t err_o
);

  /////////////////
  // Definitions //
  /////////////////
  typedef struct packed {
    logic [OutWidth-1:0]   data;
    logic [OutWidth/8-1:0] strb; // one bit per byte
  } fifo_t;

  typedef enum logic [1:0] {
    // In Idle, it checks if process input received or not.
    // If received, the signal goes to packer and flush internal pending data
    FlushIdle,

    // In Packer state, it waits the packer flush operation completes.
    // The flush_done signal do nothing but after this, it is assumed that
    // MSG FIFO received the request.
    FlushPacker,

    // In Fifo, it waits until MsgFifo is empty. Then asserts process_o
    FlushFifo,

    // After flushing, it waits the done (clear) signal. It is assumed that
    // no incoming messages are transmitted between `process_i` and `clear_i`
    FlushClear
  } flush_st_e;

  /////////////
  // Signals //
  /////////////

  // Packer write path
  logic                packer_wvalid [Share];
  logic [OutWidth-1:0] packer_wdata  [Share];
  logic [OutWidth-1:0] packer_wmask  [Share];
  logic                packer_wready [Share];

  // Message FIFO signals
  logic  fifo_wvalid [Share];
  fifo_t fifo_wdata  [Share];
  logic  fifo_wready [Share];
  logic  fifo_rvalid [Share];
  fifo_t fifo_rdata  [Share];
  logic  fifo_rready [Share];

  logic [Share-1:0] fifo_err; // FIFO dup. counter error

  // packer flush to msg_fifo, then msg_fifo empty out the internals
  // then assert msgfifo_flush_done
  logic [Share-1:0] packer_flush_done;
  logic [Share-1:0] packer_flush_all_q;
  logic             packer_flush_all;
  logic             clear_packer_flush;
  logic             msgfifo_empty_all;
  logic             msgfifo_flush_done;

  logic [Share-1:0] packer_err;

  // SEC_CM: PACKER.CTR.REDUN
  prim_packer #(
    .InW          (OutWidth),
    .OutW         (OutWidth),
    .HintByteData (1),

    // Turn on dup counter when EnMasking is set
    .EnProtection (EnMasking)
  ) u_packer_share0 (
    .clk_i,
    .rst_ni,

    .valid_i      (fifo_valid_i[0]),
    .data_i       (fifo_data_i[0] ),
    .mask_i       (fifo_mask_i    ),
    .ready_o      (fifo_ready_o[0]),

    .valid_o      (packer_wvalid[0]),
    .data_o       (packer_wdata[0] ),
    .mask_o       (packer_wmask[0] ),
    .ready_i      (packer_wready[0]),

    .flush_i      (process_i),
    .flush_done_o (packer_flush_done[0]),

    .err_o (packer_err[0])
  );

  // Assign packer wdata and wmask to FIFO struct
  // In contrast to HMAC case, KMAC SHA3 operates in little-endian. MSG fifo is
  // converted into 3-D form so the endianness here is not a problem.
  assign fifo_wdata[0].data = packer_wdata[0];
  always_comb begin
    fifo_wdata[0].strb = '0;
    for (int i = 0 ; i < OutWidth/8 ; i++) begin
      fifo_wdata[0].strb[i] = packer_wmask[0][8*i];
    end
  end

  // MsgFIFO
  prim_fifo_sync #(
    .Width  ($bits(fifo_t)),
    .Pass   (1'b 1),
    .Depth  (MsgDepth),
    .Secure (EnMasking)
  ) u_msgfifo_share0 (
    .clk_i,
    .rst_ni,
    .clr_i   (prim_mubi_pkg::mubi4_test_true_strict(clear_i)),

    .wvalid_i(fifo_wvalid[0]),
    .wready_o(fifo_wready[0]),
    .wdata_i (fifo_wdata[0] ),

    .rvalid_o (fifo_rvalid[0]),
    .rready_i (fifo_rready[0]),
    .rdata_o  (fifo_rdata[0] ),

    .full_o  (fifo_full_o[0] ),
    .depth_o (fifo_depth_o[0]),
    .err_o   (fifo_err[0]    )

  );

  assign fifo_wvalid[0] = packer_wvalid[0];
  assign packer_wready[0] = fifo_wready[0];

  assign msg_valid_o[0] = fifo_rvalid[0];
  assign fifo_rready[0] = msg_ready_i;
  assign msg_data_o[0]  = fifo_rdata[0].data;
  assign msg_strb_o[0]  = fifo_rdata[0].strb;

  assign fifo_empty_o[0] = !fifo_rvalid[0];

  generate
    if (EnMasking) begin : g_masked_msgfifo_share1
      // SEC_CM: PACKER.CTR.REDUN
      prim_packer #(
        .InW          (OutWidth),
        .OutW         (OutWidth),
        .HintByteData (1),

        // Turn on dup counter when EnMasking is set
        .EnProtection (EnMasking)
      ) u_packer_share1 (
        .clk_i,
        .rst_ni,

        .valid_i      (fifo_valid_i[1]),
        .data_i       (fifo_data_i[1] ),
        .mask_i       (fifo_mask_i    ),
        .ready_o      (fifo_ready_o[1]),

        .valid_o      (packer_wvalid[1]),
        .data_o       (packer_wdata[1] ),
        .mask_o       (packer_wmask[1] ),
        .ready_i      (packer_wready[1]),

        .flush_i      (process_i),
        .flush_done_o (packer_flush_done[1]),

        .err_o (packer_err[1])
      );

      // Assign packer wdata and wmask to FIFO struct
      // In contrast to HMAC case, KMAC SHA3 operates in little-endian. MSG fifo is
      // converted into 3-D form so the endianness here is not a problem.
      assign fifo_wdata[1].data = packer_wdata[1];
      always_comb begin
        fifo_wdata[1].strb = '0;
        for (int i = 0 ; i < OutWidth/8 ; i++) begin
          fifo_wdata[1].strb[i] = packer_wmask[1][8*i];
        end
      end

      // MsgFIFO
      prim_fifo_sync #(
        .Width  ($bits(fifo_t)),
        .Pass   (1'b 1),
        .Depth  (MsgDepth),
        .Secure (EnMasking)
      ) u_msgfifo_share1 (
        .clk_i,
        .rst_ni,
        .clr_i   (prim_mubi_pkg::mubi4_test_true_strict(clear_i)),

        .wvalid_i(fifo_wvalid[1]),
        .wready_o(fifo_wready[1]),
        .wdata_i (fifo_wdata[1] ),

        .rvalid_o (fifo_rvalid[1]),
        .rready_i (fifo_rready[1]),
        .rdata_o  (fifo_rdata[1] ),

        .full_o  (fifo_full_o[1] ),
        .depth_o (fifo_depth_o[1]),
        .err_o   (fifo_err[1]    )

      );

      assign fifo_wvalid[1] = packer_wvalid[1];
      assign packer_wready[1] = fifo_wready[1];

      assign msg_valid_o[1] = fifo_rvalid[1];
      assign fifo_rready[1] = msg_ready_i;
      assign msg_data_o[1]  = fifo_rdata[1].data;
      assign msg_strb_o[1]  = fifo_rdata[1].strb;

      assign fifo_empty_o[1] = !fifo_rvalid[1];
    end else begin : g_unmasked_msgfifo_share1
    end
  endgenerate

  // Flush (process from outside) handling
  flush_st_e flush_st, flush_st_d;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      flush_st <= FlushIdle;
    end else begin
      flush_st <= flush_st_d;
    end
  end

  always_comb begin
    msgfifo_empty_all = 1'b1;
    foreach (fifo_empty_o[i]) begin : g_fifo_empty_loop
      msgfifo_empty_all &= fifo_empty_o[i];
    end
  end

  // Packers may be finished flushing at different times due to either
  // a FI attack or due to an unmasked input message in masked mode
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      packer_flush_all_q <= '0;
    end else if (clear_packer_flush) begin
      packer_flush_all_q <= '0;
    end else begin
      foreach (packer_flush_done[i]) begin : g_packer_flush_ff_loop
        if (packer_flush_done[i]) begin
          packer_flush_all_q[i] <= packer_flush_done[i];
        end
      end
    end
  end

  // Flush state FSM can transition same cycle as flush done
  // Once all packers are flushed we can continue
  always_comb begin
    packer_flush_all = 1'b1;
    foreach (packer_flush_done[i]) begin : g_packer_flush_loop
      packer_flush_all &= packer_flush_all_q[i] | packer_flush_done[i];
    end
  end

  always_comb begin
    flush_st_d = flush_st;

    msgfifo_flush_done = 1'b 0;
    clear_packer_flush = 1'b 0;

    unique case (flush_st)
      FlushIdle: begin
        if (process_i) begin
          flush_st_d = FlushPacker;
          clear_packer_flush = 1'b 1;
        end else begin
          flush_st_d = FlushIdle;
        end
      end

      FlushPacker: begin
        if (packer_flush_all) begin
          flush_st_d = FlushFifo;
          clear_packer_flush = 1'b 0; // Reset packer flush for next msg
        end else begin
          flush_st_d = FlushPacker;
        end
      end

      FlushFifo: begin
        if (msgfifo_empty_all) begin
          flush_st_d = FlushClear;

          msgfifo_flush_done = 1'b 1;
        end else begin
          flush_st_d = FlushFifo;
        end
      end

      FlushClear: begin
        if (prim_mubi_pkg::mubi4_test_true_strict(clear_i)) begin
          flush_st_d = FlushIdle;
        end else begin
          flush_st_d = FlushClear;
        end
      end

      default: begin
        flush_st_d = FlushIdle;
      end
    endcase
  end

  assign process_o = msgfifo_flush_done;

  err_t error;
  assign err_o = error;

  // Error assign
  always_comb begin : error_logic
    error = '{
      valid: 1'b 0,
      code: kmac_pkg::ErrNone,
      info: '0
    };

    // Priority case -> if .. else if
    if (|(packer_err)) begin
      error = '{
        // If EnProtection is 0, packer_err is tied to 0
        valid: 1'b 1,
        code:  kmac_pkg::ErrPackerIntegrity,
        info:  kmac_pkg::ErrInfoW'(flush_st)
      };
    end else if (|(fifo_err)) begin
      error = '{
        valid: 1'b 1,
        code:  kmac_pkg::ErrMsgFifoIntegrity,
        info:  kmac_pkg::ErrInfoW'(flush_st)
      };
    end
  end : error_logic

  ////////////////
  // Assertions //
  ////////////////

  // Flush state known checker
  `ASSERT(FlushStInValid_A, flush_st inside {FlushIdle, FlushPacker, FlushFifo, FlushClear})

  // Packer done signal is asserted at least one cycle later
  `ASSERT(PackerDoneDelay_A, $onehot0({process_i, packer_flush_done[0]}))

  // process_i not asserted during the flush operation
  `ASSUME(PackerDoneValid_a, process_i |-> flush_st == FlushIdle)

  // No messages in between `process_i` and `clear_i`
  `ASSUME(MessageValid_a, fifo_valid_i[0] |-> flush_st == FlushIdle)

  generate
    if (EnMasking) begin : g_masking_share1_asserts
      // Packer done signal is asserted at least one cycle later
      `ASSERT(PackerDoneDelay_A, $onehot0({process_i, packer_flush_done[1]}))
      // No messages in between `process_i` and `clear_i`
      `ASSUME(MessageValid_a, fifo_valid_i[1] |-> flush_st == FlushIdle)
    end
  endgenerate

endmodule
